-- Purpose: row-level derived flags for each accepted purchase-order line
--          (cleaning_rules.md rules a, b, c). One row per staging row; the
--          fact table joins this to staging on raw_row_id. No source values
--          are altered here -- these are additive analytical flags only.
--
--          Flags:
--            is_credit                  total_price < 0 (returns/credits; keep, don't drop)
--            is_zero_price              total_price = 0
--            is_price_outlier           total_price above the 99.9th percentile,
--                                       computed dynamically (current value ~$55,000,000,
--                                       ~344 rows; recorded in cleaning_rules.md)
--            price_consistency_flag     |quantity*unit_price - total_price| beyond
--                                       tolerance 0.01 + 0.005*|total_price| (1 cent
--                                       plus 0.5%); only when all three are present
--            is_exact_duplicate /       exact full-row duplicate over the RAW columns
--            dup_occurrence             (faithful to the 3,392 figure from profiling,
--                                       which was measured on the raw CSV); occurrence
--                                       is 1-based within each identical group. Rows are
--                                       flagged, never deleted -- there is no line-item
--                                       key to tell a technical duplicate from a
--                                       legitimately repeated order line.
--            fiscal_year_mismatch       creation_date's CA fiscal year (Jul-Jun) disagrees
--                                       with the Fiscal Year column
--            purchase_date_out_of_range purchase_date before 2000-01-01 or more than one
--                                       year after creation_date (catches the parsed 1911
--                                       and 6070 values); flagged, never rejected
-- Inputs:  staging.purchase_orders, raw.purchase_orders.
-- Outputs: transform.purchase_orders_enriched.
-- Grain:   one row per staging.purchase_orders row.

CREATE TABLE IF NOT EXISTS transform.purchase_orders_enriched (
    raw_row_id                  BIGINT PRIMARY KEY
                                    REFERENCES staging.purchase_orders (raw_row_id) ON DELETE CASCADE,
    is_credit                   BOOLEAN NOT NULL,
    is_zero_price               BOOLEAN NOT NULL,
    is_price_outlier            BOOLEAN NOT NULL,
    price_consistency_flag      BOOLEAN NOT NULL,
    is_exact_duplicate          BOOLEAN NOT NULL,
    dup_occurrence              INT NOT NULL,
    fiscal_year_mismatch        BOOLEAN NOT NULL,
    purchase_date_out_of_range  BOOLEAN NOT NULL
);

TRUNCATE TABLE transform.purchase_orders_enriched;

WITH outlier_threshold AS (
    SELECT percentile_cont(0.999) WITHIN GROUP (ORDER BY total_price) AS p999
    FROM staging.purchase_orders
    WHERE total_price IS NOT NULL
),
-- Duplicate detection over the raw columns (all of them except the surrogate
-- raw_row_id), so the count matches profiling's raw-CSV measurement exactly.
duplicates AS (
    SELECT
        s.raw_row_id,
        count(*) OVER w > 1 AS is_exact_duplicate,
        row_number() OVER (
            PARTITION BY (to_jsonb(r) - 'raw_row_id')
            ORDER BY r.raw_row_id
        ) AS dup_occurrence
    FROM staging.purchase_orders s
    JOIN raw.purchase_orders r USING (raw_row_id)
    WINDOW w AS (PARTITION BY (to_jsonb(r) - 'raw_row_id'))
),
-- CA state fiscal year runs Jul 1 - Jun 30; FY label is "<start>-<end>".
fiscal AS (
    SELECT
        raw_row_id,
        CASE
            WHEN extract(MONTH FROM creation_date) >= 7
                THEN extract(YEAR FROM creation_date)::INT
            ELSE extract(YEAR FROM creation_date)::INT - 1
        END AS fy_start
    FROM staging.purchase_orders
)
INSERT INTO transform.purchase_orders_enriched (
    raw_row_id, is_credit, is_zero_price, is_price_outlier, price_consistency_flag,
    is_exact_duplicate, dup_occurrence, fiscal_year_mismatch, purchase_date_out_of_range
)
SELECT
    s.raw_row_id,
    coalesce(s.total_price < 0, false),
    coalesce(s.total_price = 0, false),
    coalesce(s.total_price > ot.p999, false),
    (
        s.quantity IS NOT NULL AND s.unit_price IS NOT NULL AND s.total_price IS NOT NULL
        AND abs(s.quantity * s.unit_price - s.total_price) > 0.01 + 0.005 * abs(s.total_price)
    ),
    d.is_exact_duplicate,
    d.dup_occurrence,
    (
        s.fiscal_year IS NOT NULL
        AND s.fiscal_year <> (f.fy_start::TEXT || '-' || (f.fy_start + 1)::TEXT)
    ),
    (
        s.purchase_date IS NOT NULL
        AND (s.purchase_date < DATE '2000-01-01' OR s.purchase_date > s.creation_date + INTERVAL '1 year')
    )
FROM staging.purchase_orders s
CROSS JOIN outlier_threshold ot
JOIN duplicates d USING (raw_row_id)
JOIN fiscal f USING (raw_row_id);

COMMENT ON TABLE transform.purchase_orders_enriched IS
    'Additive row-level flags (credit/zero/outlier/consistency/duplicate/FY/date) per accepted PO line.';
