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
  to **`Creation Date` only** (hard check). Add a separate **soft check**
  that `Creation Date`'s year is consistent with the `Fiscal Year` column.
- `Purchase Date` gets sanity checks only, as flags, never rejections: not
  before 2000, and not after `Creation Date` plus a tolerance. Deviations
  are flagged, not dropped.

## b. Prices (`Unit Price`, `Total Price`)

- Canonical parser (staging SQL, mirroring `pdp.profiling.money_to_float`):
  strip `$` and `,`; treat accounting-style `(1,234.56)` as negative.
- Negative values are most likely credits/returns: **keep**, and add an
  `is_credit` flag in the transform layer.
- Zero prices (~7,500 rows): **keep**, flag `is_zero_price`.
- Outliers (e.g. the billion-dollar contracts, see finding in
  `data_profile.md`): **do not remove or clip**. In transform, add:
  - `is_price_outlier` — `Total Price` above the 99.9th percentile.
  - A consistency check flagging rows where
    `|Quantity × Unit Price − Total Price|` exceeds a tolerance.
  - Once step 5 implements this, record the exact percentile cutoff and
    tolerance value used here.

## c. Duplicate rows (3,392 exact duplicates, 0.98%)

- There is no line-item identifier in the source data, so a *technical*
  duplicate (re-extracted row) cannot be distinguished from a *legitimately*
  repeated order line.
- **Decision: do not delete.** In transform, add:
  - `is_exact_duplicate` flag.
  - An occurrence number (`row_number()` over the set of identical rows).
- Analytical views and docs must note that spend totals are computed over
  the *full* dataset by default; the flag lets an analyst deliberately
  exclude duplicates when that's the right call for their question.

## d. Classification Codes (multi-UNSPSC, 58,602 rows)

- The canonical single code for `fact_purchase_orders` / `dim_unspsc` is
  **`Normalized UNSPSC`**.
- `Classification Codes` (which packs several newline-separated UNSPSC
  codes into one field — confirmed up to 13 codes in one row) is split
  into a bridge table `bridge_po_classification` (fact line → code), so
  the extra codes aren't discarded.
- `dim_unspsc`'s hierarchy (segment/family/class/commodity) is built from
  the codes; titles are resolved by **majority vote** per code (the raw
  title columns contain truncated garbage in some rows, e.g. "lized trade
  construction and maintenance services" — majority vote fixes most of
  these). Codes with no clear majority are flagged.

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

- Grain: **`Supplier Code`**.
- Known limitation to document: profiling confirms **438 of 24,728**
  distinct Supplier Names map to more than one Supplier Code (e.g. "Pitney
  Bowes" appears under 7 different codes) — almost certainly the same
  real-world supplier registered multiple times. (The owner recalled this
  as "~500"; 438 is the verified count from this dataset.)
  Fuzzy deduplication across codes is explicitly **out of scope** for
  Stage 1.

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
- **staging:** `TRUNCATE staging.purchase_orders, staging.rejected_rows`
  at the top of `03_purchase_orders_load.sql` regardless (belt-and-suspenders
  — makes the staging script correctly idempotent even if run on its own,
  without depending on the raw step having just run).
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
