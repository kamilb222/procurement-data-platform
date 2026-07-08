-- Purpose: many-to-many bridge between fact lines and all their UNSPSC
--          classification codes (a line's Classification Codes field can
--          list several codes; the fact keeps only the single
--          normalized_unspsc, this bridge keeps them all).
-- Inputs:  transform.po_classification.
-- Outputs: marts.bridge_po_classification.
-- Grain:   one row per (fact line, unspsc_code).
--
-- Both columns are FK-enforced: raw_row_id -> fact_purchase_orders and
-- unspsc_code -> dim_unspsc. The unspsc_code FK is why dim_unspsc is built
-- from the UNION of normalized and classification codes (transform step d)
-- -- otherwise the 3,305 code_only codes here would have no parent.

CREATE TABLE IF NOT EXISTS marts.bridge_po_classification (
    raw_row_id    BIGINT NOT NULL REFERENCES marts.fact_purchase_orders (raw_row_id) ON DELETE CASCADE,
    unspsc_code   TEXT NOT NULL REFERENCES marts.dim_unspsc (unspsc_code),
    PRIMARY KEY (raw_row_id, unspsc_code)
);

TRUNCATE TABLE marts.bridge_po_classification;

-- Only bridge lines that actually made it into the fact (all of them, since
-- the fact is 1:1 with staging and po_classification references staging).
INSERT INTO marts.bridge_po_classification (raw_row_id, unspsc_code)
SELECT pc.raw_row_id, pc.unspsc_code
FROM transform.po_classification pc
JOIN marts.fact_purchase_orders f USING (raw_row_id);

COMMENT ON TABLE marts.bridge_po_classification IS
    'Bridge: fact line -> each of its UNSPSC classification codes (multi-valued Classification Codes).';
