-- Purpose: typed, cleaned schema for purchase order line items.
--          "REMOVE AMERISOURCE" from raw.purchase_orders is intentionally
--          absent here: profiling found it 100% null (344,504/344,504
--          rows) -- see docs/data_profile.md and docs/cleaning_rules.md
--          ("Dropped columns" -> REMOVE AMERISOURCE). This is a recorded
--          finding, not a silent drop.
-- Inputs:  raw.purchase_orders (via sql/10_staging/03_purchase_orders_load.sql).
-- Outputs: staging.purchase_orders.
-- Grain:   one row per accepted source row, 1:1 with raw.purchase_orders
--          minus whatever staging.rejected_rows took (see
--          docs/cleaning_rules.md, "Per-column cast error policy").
--
-- NOT NULL is only used on creation_date and calcard, because those are
-- the only two columns the load's hard-reject logic actually guarantees
-- non-null for every accepted row. Profiling's "0.0%" in the summary table
-- rounds -- e.g. supplier_code/supplier_name each have 36 real nulls out
-- of 344,504 rows -- so every other column, including ones that currently
-- show 0 nulls (department_name, acquisition_type, ...), stays NULLable:
-- the agreed policy is that only 5 columns ever hard-reject (see
-- docs/cleaning_rules.md), everything else must degrade to NULL rather
-- than crash the load on a future data quirk.

CREATE TABLE IF NOT EXISTS staging.purchase_orders (
    raw_row_id                BIGINT PRIMARY KEY REFERENCES raw.purchase_orders (raw_row_id) ON DELETE CASCADE,

    -- Dates (rule a) -- creation_date is a hard-cast column (reject if
    -- missing or unparseable); purchase_date allows null but rejects on a
    -- non-null unparseable value.
    creation_date             DATE NOT NULL,
    purchase_date             DATE,

    -- Kept as text; the Creation-Date-vs-Fiscal-Year soft check is a
    -- validation-layer concern (step 7), not a staging cast.
    fiscal_year               TEXT,

    lpa_number                TEXT,
    purchase_order_number     TEXT,
    requisition_number        TEXT,
    acquisition_type          TEXT,
    sub_acquisition_type      TEXT,
    acquisition_method        TEXT,
    sub_acquisition_method    TEXT,
    department_name           TEXT,

    supplier_code             TEXT,
    supplier_name             TEXT,
    supplier_qualifications   TEXT,

    -- Zip / Location (rule e) -- supplier_zip_code is the authoritative
    -- source for supplier_zip5 (verified redundant with Location's
    -- embedded zip; see docs/cleaning_rules.md rule e).
    supplier_zip_code_raw     TEXT,
    supplier_zip5             TEXT,
    is_foreign_zip            BOOLEAN NOT NULL DEFAULT false,  -- computed explicitly per row in the load; DEFAULT is a safety net only

    -- calcard is hard-cast (reject if missing or not YES/NO).
    calcard                   BOOLEAN NOT NULL,

    item_name                 TEXT,
    item_description          TEXT,

    -- Prices (rule b) -- parsed only; is_credit / is_zero_price /
    -- is_price_outlier flags are a transform-layer concern (step 5).
    quantity                  NUMERIC,
    unit_price                NUMERIC,
    total_price               NUMERIC,

    -- UNSPSC (rule d) -- classification_codes_raw keeps the (possibly
    -- multi-code) raw string; the bridge_po_classification split and
    -- dim_unspsc majority-vote titles are transform/marts concerns.
    classification_codes_raw  TEXT,
    normalized_unspsc         TEXT,
    commodity_title           TEXT,
    class                     TEXT,
    class_title               TEXT,
    family                    TEXT,
    family_title              TEXT,
    segment                   TEXT,
    segment_title             TEXT,

    -- Location split (rule e) -- plain split of the composite field, no
    -- extra normalization.
    location_zip              TEXT,
    location_lat              NUMERIC,
    location_lon              NUMERIC
);

COMMENT ON TABLE staging.purchase_orders IS
    'Typed, cleaned purchase order line items. Grain: one row per accepted raw row.';
