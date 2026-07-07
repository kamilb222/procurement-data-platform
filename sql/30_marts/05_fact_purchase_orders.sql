-- Purpose: central fact of the star schema -- one accepted purchase-order
--          line, with dimension FKs, measures, and the transform flags.
-- Inputs:  staging.purchase_orders, transform.purchase_orders_enriched,
--          marts.dim_department, marts.dim_date.
-- Outputs: marts.fact_purchase_orders.
-- Grain:   one row per accepted PO line (raw_row_id), 1:1 with staging.
--
-- Keys (mixed, by column shape):
--   * supplier_code   natural FK -> dim_supplier   (NULL for the 36 rows with no supplier code)
--   * unspsc_code     natural FK -> dim_unspsc      (NULL for the 1,017 rows with no normalized_unspsc)
--   * department_key  surrogate FK -> dim_department (always present)
--   * creation_date_key DATE FK -> dim_date          (always present; 2012-2015 is inside coverage)
--   * purchase_date_key DATE FK -> dim_date          (NULL when purchase_date is NULL, OR when it
--                                                      falls outside dim_date's 2000-2016 coverage --
--                                                      282 rows, e.g. the parsed 1911 and 6070 dates)
--
-- The NULL purchase_date_key is a coverage/join concern and is distinct
-- from the business flag purchase_date_out_of_range (447 rows, carried as a
-- column below): the 282 NULL-key rows are a subset of the 447 flagged.
--
-- supplier_qualifications stays here as a degenerate dimension because it
-- varies within a supplier_code (1,231 codes have >1 value); zip/location
-- moved to dim_supplier (single-valued per code).

CREATE TABLE IF NOT EXISTS marts.fact_purchase_orders (
    raw_row_id                  BIGINT PRIMARY KEY
                                    REFERENCES staging.purchase_orders (raw_row_id) ON DELETE CASCADE,

    -- Dimension keys
    supplier_code               TEXT REFERENCES marts.dim_supplier (supplier_code),
    department_key              SMALLINT NOT NULL REFERENCES marts.dim_department (department_key),
    unspsc_code                 TEXT REFERENCES marts.dim_unspsc (unspsc_code),
    creation_date_key           DATE NOT NULL REFERENCES marts.dim_date (date_key),
    purchase_date_key           DATE REFERENCES marts.dim_date (date_key),

    -- Degenerate dimensions (line-level attributes with no dimension of their own)
    purchase_order_number       TEXT,
    requisition_number          TEXT,
    lpa_number                  TEXT,
    acquisition_type            TEXT,
    sub_acquisition_type        TEXT,
    acquisition_method          TEXT,
    sub_acquisition_method      TEXT,
    calcard                     BOOLEAN,
    item_name                   TEXT,
    item_description            TEXT,
    supplier_qualifications     TEXT,

    -- Measures
    quantity                    NUMERIC,
    unit_price                  NUMERIC,
    total_price                 NUMERIC,

    -- Flags carried from transform.purchase_orders_enriched
    is_credit                   BOOLEAN NOT NULL,
    is_zero_price               BOOLEAN NOT NULL,
    is_price_outlier            BOOLEAN NOT NULL,
    price_consistency_flag      BOOLEAN NOT NULL,
    is_exact_duplicate          BOOLEAN NOT NULL,
    dup_occurrence              INT NOT NULL,
    fiscal_year_mismatch        BOOLEAN NOT NULL,
    purchase_date_out_of_range  BOOLEAN NOT NULL
);

TRUNCATE TABLE marts.fact_purchase_orders CASCADE;

INSERT INTO marts.fact_purchase_orders (
    raw_row_id, supplier_code, department_key, unspsc_code, creation_date_key, purchase_date_key,
    purchase_order_number, requisition_number, lpa_number, acquisition_type, sub_acquisition_type,
    acquisition_method, sub_acquisition_method, calcard, item_name, item_description,
    supplier_qualifications, quantity, unit_price, total_price,
    is_credit, is_zero_price, is_price_outlier, price_consistency_flag,
    is_exact_duplicate, dup_occurrence, fiscal_year_mismatch, purchase_date_out_of_range
)
SELECT
    s.raw_row_id,
    s.supplier_code,
    dd.department_key,
    s.normalized_unspsc,
    s.creation_date,
    pdate.date_key,   -- NULL when purchase_date is out of dim_date coverage
    s.purchase_order_number,
    s.requisition_number,
    s.lpa_number,
    s.acquisition_type,
    s.sub_acquisition_type,
    s.acquisition_method,
    s.sub_acquisition_method,
    s.calcard,
    s.item_name,
    s.item_description,
    s.supplier_qualifications,
    s.quantity,
    s.unit_price,
    s.total_price,
    e.is_credit,
    e.is_zero_price,
    e.is_price_outlier,
    e.price_consistency_flag,
    e.is_exact_duplicate,
    e.dup_occurrence,
    e.fiscal_year_mismatch,
    e.purchase_date_out_of_range
FROM staging.purchase_orders s
JOIN transform.purchase_orders_enriched e USING (raw_row_id)
JOIN marts.dim_department dd ON dd.department_name = s.department_name
LEFT JOIN marts.dim_date pdate ON pdate.date_key = s.purchase_date;

COMMENT ON TABLE marts.fact_purchase_orders IS
    'Purchase-order line fact; one row per accepted staging row, with dimension FKs, measures, and flags.';
