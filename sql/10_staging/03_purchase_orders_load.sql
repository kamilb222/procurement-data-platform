-- Purpose: parse raw.purchase_orders into typed staging.purchase_orders,
--          routing hard-cast failures to staging.rejected_rows instead of
--          dropping them, then asserting raw = staging + rejected. See
--          docs/cleaning_rules.md for the per-column error policy,
--          idempotency, and reconciliation rules this file implements.
-- Inputs:  raw.purchase_orders.
-- Outputs: staging.purchase_orders, staging.rejected_rows.
-- Grain:   one row per raw.purchase_orders row, routed to exactly one of
--          the two output tables.
--
-- Hard-reject columns (row excluded, one row in rejected_rows instead):
-- creation_date (missing or not M/D/YYYY), calcard (missing or not in
-- {YES, NO}), and quantity/unit_price/total_price (present but
-- unparseable). Every other column is soft: null passes through.
-- purchase_date is soft-null but hard-rejects if present and unparseable.
-- creation_date/calcard additionally hard-reject on NULL (broader than
-- the agreed "non-null and invalid" wording) so a future data quirk
-- degrades to a clean row-level reject instead of crashing the whole load
-- on a NOT NULL violation -- profiling shows 0 such nulls today, so this
-- has no effect on the current dataset.

TRUNCATE TABLE staging.rejected_rows;
-- CASCADE because downstream layers (transform.*, marts.fact/bridge) carry
-- FKs back to staging.purchase_orders; a reload here invalidates them, so
-- clearing them in the same statement keeps the whole pipeline idempotent.
-- (TRUNCATE refuses on a referenced table even when the referrers are empty,
-- so CASCADE is required, not just tidy.)
TRUNCATE TABLE staging.purchase_orders CASCADE;

WITH parsed AS (
    SELECT
        r.raw_row_id,

        r.creation_date AS creation_date_raw,
        CASE WHEN r.creation_date ~ '^\d{1,2}/\d{1,2}/\d{4}$'
             THEN to_date(r.creation_date, 'MM/DD/YYYY') END AS creation_date_parsed,
        (r.creation_date IS NULL
            OR r.creation_date !~ '^\d{1,2}/\d{1,2}/\d{4}$') AS creation_date_failed,

        r.purchase_date AS purchase_date_raw,
        CASE WHEN r.purchase_date IS NOT NULL AND r.purchase_date ~ '^\d{1,2}/\d{1,2}/\d{4}$'
             THEN to_date(r.purchase_date, 'MM/DD/YYYY') END AS purchase_date_parsed,
        (r.purchase_date IS NOT NULL
            AND r.purchase_date !~ '^\d{1,2}/\d{1,2}/\d{4}$') AS purchase_date_failed,

        btrim(r.fiscal_year) AS fiscal_year,
        btrim(r.lpa_number) AS lpa_number,
        btrim(r.purchase_order_number) AS purchase_order_number,
        btrim(r.requisition_number) AS requisition_number,
        btrim(r.acquisition_type) AS acquisition_type,
        btrim(r.sub_acquisition_type) AS sub_acquisition_type,
        btrim(r.acquisition_method) AS acquisition_method,
        btrim(r.sub_acquisition_method) AS sub_acquisition_method,
        btrim(r.department_name) AS department_name,

        btrim(r.supplier_code) AS supplier_code,
        staging.repair_mojibake(btrim(r.supplier_name)) AS supplier_name,
        btrim(r.supplier_qualifications) AS supplier_qualifications,

        -- Zip / Location (rule e): supplier_zip_code is the authoritative
        -- source for supplier_zip5 (verified redundant with Location).
        btrim(r.supplier_zip_code) AS supplier_zip_code_raw,
        CASE WHEN btrim(r.supplier_zip_code) ~ '^\d{5}'
             THEN substring(btrim(r.supplier_zip_code) FROM '^\d{5}') END AS supplier_zip5,
        (r.supplier_zip_code IS NOT NULL
            AND btrim(r.supplier_zip_code) !~ '^\d{5}(-\d{4})?$') AS is_foreign_zip,

        r.calcard AS calcard_raw,
        (r.calcard IS NULL OR r.calcard NOT IN ('YES', 'NO')) AS calcard_failed,
        (r.calcard = 'YES') AS calcard_parsed,

        staging.collapse_whitespace(staging.repair_mojibake(r.item_name)) AS item_name,
        staging.collapse_whitespace(staging.repair_mojibake(r.item_description)) AS item_description,

        r.quantity AS quantity_raw,
        staging.safe_numeric(r.quantity) AS quantity_parsed,
        (r.quantity IS NOT NULL AND staging.safe_numeric(r.quantity) IS NULL) AS quantity_failed,

        r.unit_price AS unit_price_raw,
        staging.parse_money(r.unit_price) AS unit_price_parsed,
        (r.unit_price IS NOT NULL AND staging.parse_money(r.unit_price) IS NULL) AS unit_price_failed,

        r.total_price AS total_price_raw,
        staging.parse_money(r.total_price) AS total_price_parsed,
        (r.total_price IS NOT NULL AND staging.parse_money(r.total_price) IS NULL) AS total_price_failed,

        -- UNSPSC (rule d): classification_codes_raw kept as-is (possibly
        -- multi-code); the bridge table and majority-vote titles are a
        -- transform-layer concern.
        btrim(r.classification_codes) AS classification_codes_raw,
        btrim(r.normalized_unspsc) AS normalized_unspsc,
        staging.repair_mojibake(btrim(r.commodity_title)) AS commodity_title,
        btrim(r.class) AS class,
        btrim(r.class_title) AS class_title,
        btrim(r.family) AS family,
        btrim(r.family_title) AS family_title,
        btrim(r.segment) AS segment,
        btrim(r.segment_title) AS segment_title,

        -- Location split (rule e): plain split, no extra normalization.
        NULLIF(btrim(split_part(r.location, chr(10), 1)), '') AS location_zip,
        staging.safe_numeric(
            split_part(regexp_replace(split_part(r.location, chr(10), 2), '[()]', '', 'g'), ',', 1)
        ) AS location_lat,
        staging.safe_numeric(
            split_part(regexp_replace(split_part(r.location, chr(10), 2), '[()]', '', 'g'), ',', 2)
        ) AS location_lon

    FROM raw.purchase_orders AS r
),
flagged AS (
    SELECT
        p.*,
        (p.creation_date_failed OR p.purchase_date_failed OR p.calcard_failed
            OR p.quantity_failed OR p.unit_price_failed OR p.total_price_failed) AS is_rejected,
        concat_ws('; ',
            CASE WHEN p.creation_date_failed THEN
                'creation_date unparseable: ' || COALESCE(p.creation_date_raw, '<null>') END,
            CASE WHEN p.purchase_date_failed THEN
                'purchase_date unparseable: ' || COALESCE(p.purchase_date_raw, '<null>') END,
            CASE WHEN p.calcard_failed THEN
                'calcard not in {YES,NO}: ' || COALESCE(p.calcard_raw, '<null>') END,
            CASE WHEN p.quantity_failed THEN
                'quantity unparseable: ' || COALESCE(p.quantity_raw, '<null>') END,
            CASE WHEN p.unit_price_failed THEN
                'unit_price unparseable: ' || COALESCE(p.unit_price_raw, '<null>') END,
            CASE WHEN p.total_price_failed THEN
                'total_price unparseable: ' || COALESCE(p.total_price_raw, '<null>') END
        ) AS reject_reason
    FROM parsed p
),
rejected_insert AS (
    INSERT INTO staging.rejected_rows (raw_row_id, reason)
    SELECT raw_row_id, reject_reason
    FROM flagged
    WHERE is_rejected
    RETURNING raw_row_id
)
INSERT INTO staging.purchase_orders (
    raw_row_id, creation_date, purchase_date, fiscal_year, lpa_number,
    purchase_order_number, requisition_number, acquisition_type,
    sub_acquisition_type, acquisition_method, sub_acquisition_method,
    department_name, supplier_code, supplier_name, supplier_qualifications,
    supplier_zip_code_raw, supplier_zip5, is_foreign_zip, calcard,
    item_name, item_description, quantity, unit_price, total_price,
    classification_codes_raw, normalized_unspsc, commodity_title, class,
    class_title, family, family_title, segment, segment_title,
    location_zip, location_lat, location_lon
)
SELECT
    raw_row_id, creation_date_parsed, purchase_date_parsed, fiscal_year, lpa_number,
    purchase_order_number, requisition_number, acquisition_type,
    sub_acquisition_type, acquisition_method, sub_acquisition_method,
    department_name, supplier_code, supplier_name, supplier_qualifications,
    supplier_zip_code_raw, supplier_zip5, is_foreign_zip, calcard_parsed,
    item_name, item_description, quantity_parsed, unit_price_parsed, total_price_parsed,
    classification_codes_raw, normalized_unspsc, commodity_title, class,
    class_title, family, family_title, segment, segment_title,
    location_zip, location_lat, location_lon
FROM flagged
WHERE NOT is_rejected;

-- Reconciliation, enforced here rather than waiting for step 7 validation
-- (see docs/cleaning_rules.md, "Reconciliation check, enforced at load time").
DO $$
DECLARE
    raw_count      BIGINT;
    staging_count  BIGINT;
    rejected_count BIGINT;
BEGIN
    SELECT count(*) INTO raw_count FROM raw.purchase_orders;
    SELECT count(*) INTO staging_count FROM staging.purchase_orders;
    SELECT count(*) INTO rejected_count FROM staging.rejected_rows;

    IF raw_count <> staging_count + rejected_count THEN
        RAISE EXCEPTION
            'Staging reconciliation failed: raw=% staging=% rejected=% (staging+rejected=%)',
            raw_count, staging_count, rejected_count, staging_count + rejected_count;
    END IF;

    RAISE NOTICE 'Staging reconciliation OK: raw=% staging=% rejected=%',
        raw_count, staging_count, rejected_count;
END $$;
