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

## e. Location (`zip\n(lat, lon)`)

- Split in staging into `location_zip`, `location_lat`, `location_lon`.
- Zip codes are normalized to 5 digits into `supplier_zip5` (stripping any
  ZIP+4 suffix); the raw value is kept alongside it.
- Values that don't match the US zip pattern (e.g. the Canadian `n6b1y8`
  seen in profiling) are legitimate foreign addresses: flag
  `is_foreign_zip`, never reject.

## f. Mojibake (double-encoded UTF-8)

- Repair in staging using plain Postgres:
  `convert_from(convert_to(col, 'LATIN1'), 'UTF8')`, applied **only** to
  values matching the mojibake pattern, wrapped in a function with a
  fallback to the original value if the conversion errors.
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
