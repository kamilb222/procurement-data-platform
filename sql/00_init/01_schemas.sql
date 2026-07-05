-- Purpose: create the three schemas that make up the pipeline's layers.
-- Inputs:  none.
-- Outputs: schemas `raw`, `staging`, `marts`.
-- Grain:   n/a (schema creation only).

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;

COMMENT ON SCHEMA raw IS
    'Verbatim copy of the source CSV: all-TEXT columns, no casts, no drops.';
COMMENT ON SCHEMA staging IS
    'Typed, cleaned copies of raw tables, plus staging.rejected_rows for rows that fail a hard cast.';
COMMENT ON SCHEMA marts IS
    'Star schema (fact + dims) and analytical views built from staging.';
