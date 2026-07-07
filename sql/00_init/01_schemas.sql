-- Purpose: create the four schemas that make up the pipeline's layers.
-- Inputs:  none.
-- Outputs: schemas `raw`, `staging`, `transform`, `marts`.
-- Grain:   n/a (schema creation only).
--
-- Note: AGENTS.md section 4 originally listed three schemas (raw/staging/
-- marts). `transform` was added in Stage 1 step 5 as the home for the
-- intermediate enrichment layer (row-level flags, deduplication markers,
-- supplier/UNSPSC canonical maps, the classification-code bridge source),
-- keeping staging as a clean "typed + cleaned" mirror and marts as a pure
-- dimensional model. This deviation was agreed with the project owner.

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS transform;
CREATE SCHEMA IF NOT EXISTS marts;

COMMENT ON SCHEMA raw IS
    'Verbatim copy of the source CSV: all-TEXT columns, no casts, no drops.';
COMMENT ON SCHEMA staging IS
    'Typed, cleaned copies of raw tables, plus staging.rejected_rows for rows that fail a hard cast.';
COMMENT ON SCHEMA transform IS
    'Intermediate enrichment: row-level flags, dedup markers, canonical supplier/UNSPSC maps, bridge source.';
COMMENT ON SCHEMA marts IS
    'Star schema (fact + dims) and analytical views built from staging + transform.';
