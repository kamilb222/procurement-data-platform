# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Repository scaffolding: directory layout, Docker Compose (Postgres 16 with
  healthcheck + named volume), `pyproject.toml` (uv-managed, ruff configured),
  pre-commit hooks (ruff, detect-secrets, hygiene checks), GitHub Actions CI
  (ruff + pytest), `.env.example`, and manual data-download instructions.
- MIT license.
- Data profiling (`scripts/profile_raw.py`, `pdp.profiling`): per-column
  null%, distinct counts, min/max, top-10 values, and evidence-based anomaly
  detection (whitespace, embedded newlines, mojibake, mixed date formats,
  currency/accounting-negative formatting), run against the real 344,504-row
  dataset (`docs/data_profile.md`).
- `docs/cleaning_rules.md`: cleaning and modeling rules agreed with the
  project owner from the profiling findings, spec for the staging/transform/
  marts layers.
- Load + staging layers (`sql/00_init`, `sql/10_staging`,
  `src/pdp/pipeline/`, `scripts/run_pipeline.py`): schemas, a verbatim
  `raw.purchase_orders` (snake_case columns, audited CSV-header mapping),
  typed `staging.purchase_orders` with a per-column hard/soft cast-error
  policy and `staging.rejected_rows`, truncate-and-reload idempotency, and
  a reconciliation check enforced at load time.
- Transform layer (`sql/20_transform`, new `transform` schema): row-level
  enrichment flags (`is_credit`, `is_zero_price`, `is_price_outlier` at the
  dynamic 99.9th percentile, `price_consistency_flag`, `is_exact_duplicate`
  + `dup_occurrence`, `fiscal_year_mismatch`, `purchase_date_out_of_range`),
  canonical supplier names, a UNION-sourced UNSPSC code dimension with
  digit-derived hierarchy and majority-vote titles, and an exploded
  classification-code bridge source (distinct per line/code). Verified
  against the real dataset (e.g. 3,392 exact duplicates, 0 bridge orphans)
  and the synthetic fixture via a shared testcontainers integration test.
- Marts layer (`sql/30_marts`): star schema — `dim_date` (CA fiscal-year
  attributes), `dim_department`, `dim_supplier` (enriched with per-code
  zip/centroid), `dim_unspsc` (family/segment titles majority-voted at
  their own grain), `fact_purchase_orders` (mixed natural/surrogate keys,
  NULL-FK policy for out-of-coverage purchase dates), a bridge to all
  UNSPSC classification codes, and five analytical views (spend by
  department/quarter, fiscal year, top suppliers, acquisition method, and
  UNSPSC segment). Verified end-to-end (344,504 fact rows, 0 dangling FKs).

### Fixed

- Staging load now `TRUNCATE`s `staging.purchase_orders` with `CASCADE`, so
  the pipeline stays idempotent on re-run once the transform/marts layers
  carry FKs back to staging (Postgres refuses to truncate a referenced
  table otherwise).
