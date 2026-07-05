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
