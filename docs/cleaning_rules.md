# Cleaning & modeling rules — agreed after Stage 1 profiling

These rules were agreed with the project owner after reviewing
[`data_profile.md`](data_profile.md) (see that file for the underlying
evidence — every rule below traces back to a specific, verified finding, not
an assumption). They are the spec for the staging (`sql/10_staging`),
transform (`sql/20_transform`), and marts (`sql/30_marts`) layers.

If reality diverges from a rule below once the SQL is actually written,
say so and propose an alternative before implementing something else —
don't silently deviate.

## Dropped columns

### `REMOVE AMERISOURCE`

- **Finding:** 100% null (344,504 / 344,504 rows).
- **Decision:** Drop in `sql/10_staging`. This is a recorded finding, not a
  silent decision: the staging SQL file that drops it must say so in its
  header comment, and `docs/data_quality_report.md` (step 7) must list it
  as a dropped-column finding.

## a. Dates

- `Creation Date`: one consistent `M/D/YYYY` format (confirmed in profiling
  — no mixed formats detected, unlike some other government CSV exports).
  Parse it directly; cast failures go to `staging.rejected_rows` with a
  reason, per the standard staging rule.
- `Purchase Date`: 5.1% null and ranges back to 2007 — both are legitimate
  (a purchase can predate its entry into SCPRS). Parse it, allow null, and
  do **not** reject dates before 2012.
- AGENTS.md's validation rule "date ranges within FY2012–2015" is narrowed
  to **`Creation Date` only** (hard check). A separate **soft check**
  (`fiscal_year_mismatch` in `transform.purchase_orders_enriched`) compares
  `creation_date`'s CA fiscal year (Jul–Jun) to the `Fiscal Year` column.
  **Verified: 0 mismatches** — the `Fiscal Year` column is fully derivable
  from `creation_date` across all 344,504 rows (e.g. Aug 2013 and Jan 2014
  both → "2013-2014").
- `Purchase Date` gets sanity checks only, as flags, never rejections
  (`purchase_date_out_of_range`): before 2000-01-01, or more than one year
  after `creation_date`. **Verified: 447 rows flagged** — including the
  parsed extremes 1911-10-01 and **6070-12-10** (both valid `M/D/YYYY`
  strings, nonsensical years) that the staging cast accepts but this flag
  catches.

## b. Prices (`Unit Price`, `Total Price`)

- Canonical parser (staging SQL, mirroring `pdp.profiling.money_to_float`):
  strip `$` and `,`; treat accounting-style `(1,234.56)` as negative.
- Negative values are most likely credits/returns: **keep**, and add an
  `is_credit` flag in the transform layer.
- Zero prices (~7,500 rows): **keep**, flag `is_zero_price`.
- Outliers (e.g. the billion-dollar contracts, see finding in
  `data_profile.md`): **do not remove or clip**. Implemented in
  `transform.purchase_orders_enriched`:
  - `is_price_outlier` — `total_price` above the 99.9th percentile,
    computed dynamically each run via `percentile_cont(0.999)`. **Verified
    current value: $55,000,000, flagging 344 rows.** (Dynamic so the flag
    tracks the data if a future export shifts the distribution; the current
    value is recorded here for reference.)
  - `price_consistency_flag` — rows where
    `|quantity × unit_price − total_price| > 0.01 + 0.005 × |total_price|`
    (1 cent absolute + 0.5% relative tolerance), only when all three values
    are present. **Verified: 1,308 rows flagged.**
  - `is_credit` — `total_price < 0`. **Verified: 1,438 rows** (the same
    accounting-negative values from profiling).
  - `is_zero_price` — `total_price = 0`. **Verified: 7,511 rows.**

## c. Duplicate rows (3,392 exact duplicates, 0.98%)

- There is no line-item identifier in the source data, so a *technical*
  duplicate (re-extracted row) cannot be distinguished from a *legitimately*
  repeated order line.
- **Decision: do not delete.** Implemented in
  `transform.purchase_orders_enriched`:
  - `is_exact_duplicate` flag. **Verified: 3,392 rows** — the duplicate key
    is the full set of *raw* columns (detection joins back to
    `raw.purchase_orders`), so the count reproduces profiling's raw-CSV
    measurement exactly rather than drifting on staging's cleaned values.
  - `dup_occurrence` — 1-based `row_number()` within each identical group,
    ordered by `raw_row_id`. **Verified: 2,087 rows have occurrence > 1**
    (i.e. an analyst keeping only occurrence = 1 would drop 2,087 rows).
- Analytical views and docs must note that spend totals are computed over
  the *full* dataset by default; the flag lets an analyst deliberately
  exclude duplicates when that's the right call for their question.

## d. Classification Codes (multi-UNSPSC, 58,602 rows)

- The canonical single code for `fact_purchase_orders` is
  **`normalized_unspsc`**.
- `Classification Codes` (which packs several newline-separated UNSPSC
  codes into one field — confirmed up to 13 codes in one row) is exploded
  in `transform.po_classification` (line → code, **distinct per
  `(raw_row_id, code)`** so a code repeated within one field can't inflate
  bridge joins), feeding `marts.bridge_po_classification`. **Verified:
  539,420 (line, code) pairs across 16,709 distinct codes.**
- `transform.unspsc_codes` (source for `dim_unspsc`) is built from the
  **UNION** of `normalized_unspsc` and every code from `Classification
  Codes`, so the bridge always has a valid parent. **Verified: 16,710
  codes total (13,405 `from_normalized`, 3,305 `code_only`), 0 bridge
  orphans.** A normalized-only dimension would have orphaned the
  `code_only` codes.
- Hierarchy (segment/family/class) is **derived from the code digits**,
  which profiling verified is reliable (class/segment: 0 mismatches vs the
  provided columns; family: 28 of 343,469). Derived only for full 8-digit
  codes — **63 codes are not 8 digits** (18 short `normalized_unspsc`
  values + 45 short classification codes) and get NULL hierarchy, flagged
  by `is_full_code`.
- Titles are resolved by **majority vote (`mode()`) per code**. **Verified
  nuance:** at the 8-digit commodity-code grain every title is already
  unambiguous (`title_has_majority` is true for all codes) — the truncated
  garbage (e.g. "lized trade construction and maintenance services") is a
  disagreement *between* codes sharing a `family_code`, not *within* a
  code. So the majority vote actually matters when `dim_unspsc` picks a
  single `family_title`/`segment_title` per `family_code`/`segment_code`
  (step 6), and only for the 3 affected families.

## e. Location (`zip\n(lat, lon)`) and `Supplier Zip Code`

- **Verified finding:** `Supplier Zip Code` and `Location` are redundant.
  Checked row-for-row on the real dataset:
  - Of the 274,424 rows where both are present, the zip embedded in
    `Location` matches `Supplier Zip Code` **exactly, in all 274,424
    rows** (0 mismatches).
  - Every distinct zip maps to exactly **one** `(lat, lon)` pair (0 of
    3,993 zips have more than one) — `Location`'s coordinates are a
    deterministic **zip-code centroid lookup**, not a per-supplier
    geocoded address.
  - The two columns are null/non-null in perfect lockstep (0 rows have
    one present and the other missing).
  - **Implication for Power BI (Stage 2):** any map built from these
    coordinates plots zip-code centroids, not actual supplier locations —
    multiple suppliers in the same zip will stack on identical points.
    Document this caveat on any map visual.
- `Location` is split in staging into `location_zip`, `location_lat`,
  `location_lon` — a plain split of the composite field, no extra
  normalization applied.
- Separately, `supplier_zip_code` (the authoritative source, given the
  finding above) is normalized to 5 digits into `supplier_zip5` (stripping
  any ZIP+4 suffix); the raw value is kept alongside it as
  `supplier_zip_code_raw`.
- Values that don't match the US zip pattern (e.g. the Canadian `n6b1y8`
  seen in profiling) are legitimate foreign addresses: flag
  `is_foreign_zip`, never reject. The flag is computed explicitly per row
  in the staging load (`!~ '^\d{5}(-\d{4})?$'`); the column's `DEFAULT
  false` is only a safety net for hypothetical future manual inserts, not
  the mechanism that sets the value.

## f. Mojibake (double-encoded UTF-8)

- Repair in staging using plain Postgres:
  `convert_from(convert_to(col, 'LATIN1'), 'UTF8')`, applied **only** to
  values matching the mojibake pattern, wrapped in a function with a
  fallback to the original value if the conversion errors.
- **Verified finding:** some values are **double-encoded** (the mistake
  happened twice upstream, e.g. `17.25Ã¢Â\x80Â\x9d` for the intended
  `17.25"`). A single round-trip only peels off one layer and leaves a
  still-mangled result, so `staging.repair_mojibake` iterates the
  round-trip until the pattern stops matching or the result stops
  changing, capped at 5 iterations.
- **Known residual (5 rows, unrecoverable):** a handful of values contain
  a truncated/orphaned mojibake byte sequence (e.g. a lone `Â` with no
  continuation bytes, likely from a source-side field-length truncation).
  These can never round-trip back to valid UTF-8 — the function correctly
  leaves them unchanged rather than guessing at the lost bytes. This is a
  real, permanent data-quality limitation of the source file, not a repair
  bug; document it as a finding in `docs/data_quality_report.md`, not a
  silent gap.
- Count repaired rows and report them in `docs/data_quality_report.md`.
- Caveat carried over from profiling: the detection pattern is a heuristic
  and can false-positive on legitimate accented text (e.g. "Château") — the
  repair function must be safe to run on those too (falls back to the
  original on conversion failure rather than corrupting them further).

## g. General text fields (`Item Name`, `Item Description`)

- Trim, and collapse repeated whitespace/newlines.
- The original raw value is preserved in the `raw` schema, so this is
  lossless at the platform level.

## h. `dim_supplier`

- Grain: **`supplier_code`**. `transform.supplier_canonical` resolves one
  canonical name per code. AGENTS.md's "most frequent variant" strategy is
  implemented with `mode()` but is empirically a **no-op**: profiling
  verified 0 of 25,235 codes carry more than one distinct name.
- **No fabricated labels (verified).** `supplier_code` `'0'` is *not*
  relabelled by us — it legitimately carries the real name **"Unknown"** in
  the source (all 4,473 rows with code `'0'` have name "Unknown"). No code
  in the data has only-null names, so a fallback label is never invented.
  The **36 rows with a NULL `supplier_code`** get no `dim_supplier` row and
  a NULL supplier FK in the fact — again, nothing fabricated.
- Known limitation to document: profiling confirms **438 of 24,728**
  distinct Supplier Names map to more than one Supplier Code (e.g. "Pitney
  Bowes" appears under 7 different codes) — almost certainly the same
  real-world supplier registered multiple times. (The owner recalled this
  as "~500"; 438 is the verified count from this dataset.)
  Fuzzy deduplication across codes is explicitly **out of scope** for
  Stage 1.

## Transform layer (`sql/20_transform`) — schema and outputs

- A dedicated **`transform` schema** (added to `sql/00_init`) holds the
  intermediate enrichment, keeping `staging` a clean typed mirror and
  `marts` a pure dimensional model. This is a deliberate deviation from
  AGENTS.md section 4's three-schema list, agreed with the owner.
- Outputs (all truncate-and-reload, same idempotency contract as staging):
  - `transform.supplier_canonical` — code → canonical name (rule h).
  - `transform.unspsc_codes` — UNION-sourced code dimension with derived
    hierarchy and majority-vote titles (rule d).
  - `transform.purchase_orders_enriched` — additive row-level flags (rules
    a, b, c); one row per staging row, joined to the fact on `raw_row_id`.
  - `transform.po_classification` — exploded (line → code) bridge source
    (rule d).

## Marts layer (`sql/30_marts`) — star schema

Star schema built from staging + transform; all tables truncate-and-reload.
**Key strategy is mixed by column shape** (agreed): natural keys where they
are already compact (`supplier_code`, `unspsc_code`, dates), a surrogate
`department_key` for the long department name.

| Table | Grain | Notes |
|---|---|---|
| `dim_date` | one calendar date | 2000-01-01 … 2016-06-30; CA fiscal-year (Jul–Jun) attributes. **6,026 rows.** |
| `dim_department` | one department | surrogate `department_key`; **111 rows**, no null member. |
| `dim_supplier` | one `supplier_code` | enriched with `supplier_zip5`/`is_foreign_zip`/`location_lat`/`location_lon` (each verified single-valued per code). **25,235 rows.** |
| `dim_unspsc` | one UNSPSC code | `family_title`/`segment_title` majority-voted at `family_code`/`segment_code` grain (verified: 0 families with >1 title afterward). **16,710 rows.** |
| `fact_purchase_orders` | one accepted PO line (`raw_row_id`) | 1:1 with staging. **344,504 rows, 0 dangling FKs.** |
| `bridge_po_classification` | one (line, UNSPSC code) | FK to fact and `dim_unspsc`. **539,420 rows.** |

- **`supplier_qualifications` stays on the fact** (degenerate), not in
  `dim_supplier`: verified it varies within a `supplier_code` (1,231 codes
  have >1 value), unlike zip/location which are single-valued per code.
- **`purchase_date_key` FK policy:** NULL when `purchase_date` is NULL
  (17,421 rows) **or** falls outside `dim_date`'s coverage (300 rows, e.g.
  the parsed 1911 and 6070 dates) — **17,721 NULL keys total**. This is a
  coverage/join concern, distinct from the business flag
  `purchase_date_out_of_range` (447 rows) carried as a fact column; the
  300 out-of-coverage rows are a subset of the 447. `creation_date_key` is
  never NULL (2012–2015 is fully inside coverage).
- **Analytical views** (`marts.v_*`), spend = `SUM(total_price)` over the
  full fact by default (net of credits, duplicates included; flags let an
  analyst re-slice): `v_spend_by_department_quarter`,
  `v_spend_by_fiscal_year`, `v_top_suppliers` (`po_count` =
  `COUNT(DISTINCT purchase_order_number)`, not line count),
  `v_spend_by_acquisition_method`, `v_spend_by_unspsc_segment`.

## Staging pipeline mechanics (agreed for `sql/00_init` / `sql/10_staging`)

### Per-column cast error policy

General rule: **null passes through; garbage gets rejected.** A row is a
**hard reject** (excluded from `staging.purchase_orders`, one row written to
`staging.rejected_rows` with a reason) only when one of these is true:

| Column | Hard reject when | Soft (never rejects) |
|---|---|---|
| `creation_date` | non-null and doesn't match `M/D/YYYY` | — (never null in source) |
| `purchase_date` | non-null and doesn't match `M/D/YYYY` | null |
| `calcard` | non-null and not in `{YES, NO}` | — (never null in source) |
| `quantity` | non-null and not numeric | null |
| `unit_price` | non-null and not parseable by `staging.parse_money` | null |
| `total_price` | non-null and not parseable by `staging.parse_money` | null |
| every other column (all descriptive/text fields) | never | anything, including null |

Profiling found ~0 rows that would actually trip these hard checks today —
the rule exists so a regression in a future data export (e.g. a genuinely
malformed date) is caught loudly instead of silently corrupting
`staging.purchase_orders`. If a rejected row fails more than one check, its
`reason` lists all of them (semicolon-joined), not just the first.

### Idempotency: truncate-and-reload

Re-running `python scripts/run_pipeline.py --stage all` against an existing
database must be deterministic, not additive:

- **raw:** `TRUNCATE raw.purchase_orders RESTART IDENTITY CASCADE` before
  `COPY`. `CASCADE` also empties `staging.purchase_orders` and
  `staging.rejected_rows` (they hold FKs to `raw_row_id`), so the raw
  reload can never fail on a stale FK from a previous staging run.
- **staging:** `TRUNCATE staging.purchase_orders CASCADE` (plus
  `staging.rejected_rows`) at the top of `03_purchase_orders_load.sql`
  regardless (belt-and-suspenders — makes the staging script correctly
  idempotent even if run on its own, without depending on the raw step
  having just run). **`CASCADE` is required, not just tidy:** once the
  transform and marts layers exist they carry FKs back to
  `staging.purchase_orders`, and Postgres refuses to `TRUNCATE` a
  referenced table even when the referrers are empty. The cascade
  re-clears the whole downstream chain, which is the correct behavior —
  a staging reload invalidates everything built on top of it.
- `raw_row_id` is a `BIGSERIAL` reset by `RESTART IDENTITY` on every raw
  reload, so it's stable and equal to the row's 1-indexed position in the
  current CSV (header excluded) across reruns of the same file.

### Reconciliation check, enforced at load time

`03_purchase_orders_load.sql` ends with a `DO $$ ... $$` block asserting
`count(raw.purchase_orders) = count(staging.purchase_orders) +
count(staging.rejected_rows)`, raising a Postgres exception (failing the
whole script) if it doesn't hold. This is the same invariant Stage 1 step 7
validation will check again at the reporting level — checking it here too
means an `INSERT ... SELECT` bug is caught the moment it's introduced, not
three steps later when the validation report runs.
