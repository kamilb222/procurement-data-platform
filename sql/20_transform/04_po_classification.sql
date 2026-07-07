-- Purpose: explode the multi-code Classification Codes field into one row per
--          (line, code), preserving every UNSPSC code instead of collapsing to
--          the single normalized_unspsc (cleaning_rules.md rule d). This is the
--          source for marts.bridge_po_classification.
--
--          DISTINCT per (raw_row_id, code): a single Classification Codes value
--          can list the same code twice; without DISTINCT the duplicate pair
--          would inflate any JOIN through the bridge. Blank fragments (from
--          trailing separators) are dropped.
-- Inputs:  staging.purchase_orders.
-- Outputs: transform.po_classification.
-- Grain:   one row per distinct (raw_row_id, unspsc_code).

CREATE TABLE IF NOT EXISTS transform.po_classification (
    raw_row_id    BIGINT NOT NULL REFERENCES staging.purchase_orders (raw_row_id) ON DELETE CASCADE,
    unspsc_code   TEXT NOT NULL,
    PRIMARY KEY (raw_row_id, unspsc_code)
);

TRUNCATE TABLE transform.po_classification;

INSERT INTO transform.po_classification (raw_row_id, unspsc_code)
SELECT DISTINCT
    raw_row_id,
    btrim(code) AS unspsc_code
FROM staging.purchase_orders,
     unnest(string_to_array(classification_codes_raw, chr(10))) AS code
WHERE classification_codes_raw IS NOT NULL
  AND btrim(code) <> '';

COMMENT ON TABLE transform.po_classification IS
    'Exploded (line -> UNSPSC code) mapping from Classification Codes; distinct per (raw_row_id, code).';
