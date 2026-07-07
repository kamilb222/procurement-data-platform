-- Purpose: one canonical supplier name per supplier code (cleaning_rules.md
--          rule h). AGENTS.md step 5 specifies "most frequent variant" as the
--          normalization strategy; we implement it with mode(), but note it is
--          empirically a no-op on this dataset -- profiling verified 0 of
--          25,235 supplier codes carry more than one distinct name, so each
--          code already maps to exactly one name.
--
--          No fabricated labels: supplier_code '0' is NOT relabelled by us --
--          it legitimately carries the real name "Unknown" in the source data
--          (verified: all 4,473 rows with code '0' have name "Unknown"). No
--          code in the data has only-null names, so a fallback label is never
--          needed. The 36 rows with a NULL supplier_code have no dimension row
--          here and get a NULL supplier FK in the fact -- again, nothing
--          invented.
-- Inputs:  staging.purchase_orders.
-- Outputs: transform.supplier_canonical.
-- Grain:   one row per non-null supplier_code.

CREATE TABLE IF NOT EXISTS transform.supplier_canonical (
    supplier_code   TEXT PRIMARY KEY,
    supplier_name   TEXT NOT NULL
);

TRUNCATE TABLE transform.supplier_canonical;

INSERT INTO transform.supplier_canonical (supplier_code, supplier_name)
SELECT
    supplier_code,
    mode() WITHIN GROUP (ORDER BY supplier_name) AS supplier_name
FROM staging.purchase_orders
WHERE supplier_code IS NOT NULL
  AND supplier_name IS NOT NULL
GROUP BY supplier_code;

COMMENT ON TABLE transform.supplier_canonical IS
    'One canonical supplier name per supplier_code (most-frequent variant; a no-op given 1 name per code).';
