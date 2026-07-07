-- Purpose: verbatim landing table for the source CSV. Every column is TEXT;
--          no casting, trimming, or dropping happens here (see
--          docs/cleaning_rules.md — "REMOVE AMERISOURCE" is dropped in
--          staging, not here, precisely so raw stays a truthful mirror).
-- Inputs:  data/raw/purchase_orders.csv (loaded by src/pdp/pipeline/load.py).
-- Outputs: raw.purchase_orders.
-- Grain:   one row per logical CSV row (raw_row_id = 1-indexed row position
--          in the source file, reset on every reload — see
--          docs/cleaning_rules.md, "Idempotency: truncate-and-reload").
--
-- Column mapping (CSV header -> raw column name). This table is the
-- audit trail for the snake_case rename; the Python loader's
-- COLUMN_MAPPING in src/pdp/pipeline/load.py is the executable source of
-- truth and must be kept in sync with it — the loader asserts the CSV
-- header matches this exact order before copying, so a silent column
-- reorder in a future export fails loudly instead of mis-mapping data.
--
--  CSV header                | raw column
--  --------------------------|-------------------------
--  Creation Date             | creation_date
--  Purchase Date             | purchase_date
--  Fiscal Year               | fiscal_year
--  LPA Number                | lpa_number
--  Purchase Order Number     | purchase_order_number
--  Requisition Number        | requisition_number
--  Acquisition Type          | acquisition_type
--  Sub-Acquisition Type      | sub_acquisition_type
--  Acquisition Method        | acquisition_method
--  Sub-Acquisition Method    | sub_acquisition_method
--  Department Name           | department_name
--  Supplier Code             | supplier_code
--  Supplier Name             | supplier_name
--  Supplier Qualifications   | supplier_qualifications
--  Supplier Zip Code         | supplier_zip_code
--  CalCard                   | calcard
--  Item Name                 | item_name
--  Item Description          | item_description
--  Quantity                  | quantity
--  Unit Price                | unit_price
--  Total Price               | total_price
--  Classification Codes      | classification_codes
--  Normalized UNSPSC         | normalized_unspsc
--  Commodity Title           | commodity_title
--  Class                     | class
--  Class Title               | class_title
--  Family                    | family
--  Family Title              | family_title
--  Segment                   | segment
--  Segment Title             | segment_title
--  Location                  | location
--  REMOVE AMERISOURCE        | remove_amerisource

CREATE TABLE IF NOT EXISTS raw.purchase_orders (
    raw_row_id               BIGSERIAL PRIMARY KEY,
    creation_date            TEXT,
    purchase_date            TEXT,
    fiscal_year              TEXT,
    lpa_number               TEXT,
    purchase_order_number    TEXT,
    requisition_number       TEXT,
    acquisition_type         TEXT,
    sub_acquisition_type     TEXT,
    acquisition_method       TEXT,
    sub_acquisition_method   TEXT,
    department_name          TEXT,
    supplier_code            TEXT,
    supplier_name            TEXT,
    supplier_qualifications  TEXT,
    supplier_zip_code        TEXT,
    calcard                  TEXT,
    item_name                TEXT,
    item_description         TEXT,
    quantity                 TEXT,
    unit_price               TEXT,
    total_price              TEXT,
    classification_codes     TEXT,
    normalized_unspsc        TEXT,
    commodity_title          TEXT,
    class                    TEXT,
    class_title              TEXT,
    family                   TEXT,
    family_title             TEXT,
    segment                  TEXT,
    segment_title            TEXT,
    location                 TEXT,
    remove_amerisource       TEXT
);

COMMENT ON TABLE raw.purchase_orders IS
    'Verbatim landing table for the SCPRS purchase-order CSV. All-TEXT, no cleaning applied.';
