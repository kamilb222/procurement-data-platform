-- Purpose: hold whole rows that fail a hard cast anywhere in the staging
--          layer, so a bad row is never silently dropped. Shared across all
--          future staging tables (Stage 1 only populates it from
--          purchase_orders, but the grain is source-table-agnostic).
-- Inputs:  none (populated by sql/10_staging/03_purchase_orders_load.sql).
-- Outputs: staging.rejected_rows.
-- Grain:   one row per rejected source row (not one row per failing
--          column) -- see docs/cleaning_rules.md, "Per-column cast error
--          policy".

CREATE TABLE IF NOT EXISTS staging.rejected_rows (
    id            BIGSERIAL PRIMARY KEY,
    raw_row_id    BIGINT NOT NULL REFERENCES raw.purchase_orders (raw_row_id) ON DELETE CASCADE,
    reason        TEXT NOT NULL,
    rejected_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE staging.rejected_rows IS
    'Rows excluded from a staging table by a hard cast failure, with a human-readable reason.';
