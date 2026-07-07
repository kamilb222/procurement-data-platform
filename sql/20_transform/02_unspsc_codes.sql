-- Purpose: canonical UNSPSC code dimension source (cleaning_rules.md rule d).
--          Built from the UNION of two code sources so the classification
--          bridge always has a valid parent:
--            1. normalized_unspsc  (the canonical single code per line), and
--            2. every distinct code split out of Classification Codes
--               (verified: 3,249 of these 8-digit codes never appear as a
--               normalized_unspsc, so a normalized-only dimension would leave
--               the bridge with 3,249 orphans).
--
--          Hierarchy (segment/family/class) is derived from the code digits,
--          which profiling verified is reliable: class and segment truncations
--          match the provided columns with 0 mismatches; family with only 28
--          of 343,469. Note not every code is 8 digits -- 17 are 6-digit and 1
--          is 7-digit in normalized_unspsc -- so hierarchy is only derived for
--          full 8-digit codes (is_full_code), NULL otherwise.
--
--          Titles are resolved by majority vote (mode) per code. Empirically
--          this only changes anything for family_title (3 of 409 families
--          carry a second, truncated title such as "lized trade construction
--          and maintenance services"); commodity/class/segment titles are
--          already 1:1 with their code. Codes that only appear via
--          Classification Codes have no title columns in the source and get
--          NULL titles with title_source = 'code_only'.
-- Inputs:  staging.purchase_orders.
-- Outputs: transform.unspsc_codes.
-- Grain:   one row per distinct UNSPSC code (from either source).

CREATE TABLE IF NOT EXISTS transform.unspsc_codes (
    unspsc_code         TEXT PRIMARY KEY,
    code_length         INT NOT NULL,
    is_full_code        BOOLEAN NOT NULL,   -- true for an 8-digit commodity code
    segment_code        TEXT,               -- derived from digits; NULL unless is_full_code
    family_code         TEXT,
    class_code          TEXT,
    commodity_title     TEXT,
    class_title         TEXT,
    family_title        TEXT,
    segment_title       TEXT,
    title_source        TEXT NOT NULL,      -- 'from_normalized' | 'code_only'
    title_has_majority  BOOLEAN             -- NULL for code_only; else true if titles were unambiguous
);

TRUNCATE TABLE transform.unspsc_codes;

WITH normalized AS (
    SELECT
        normalized_unspsc AS code,
        commodity_title,
        class_title,
        family_title,
        segment_title
    FROM staging.purchase_orders
    WHERE normalized_unspsc IS NOT NULL
),
titles AS (
    SELECT
        code,
        mode() WITHIN GROUP (ORDER BY commodity_title) AS commodity_title,
        mode() WITHIN GROUP (ORDER BY class_title) AS class_title,
        mode() WITHIN GROUP (ORDER BY family_title) AS family_title,
        mode() WITHIN GROUP (ORDER BY segment_title) AS segment_title,
        GREATEST(
            count(DISTINCT commodity_title),
            count(DISTINCT class_title),
            count(DISTINCT family_title),
            count(DISTINCT segment_title)
        ) <= 1 AS title_has_majority
    FROM normalized
    GROUP BY code
),
classification_codes AS (
    SELECT DISTINCT btrim(unnest(string_to_array(classification_codes_raw, chr(10)))) AS code
    FROM staging.purchase_orders
    WHERE classification_codes_raw IS NOT NULL
),
all_codes AS (
    SELECT code FROM titles
    UNION
    SELECT code FROM classification_codes WHERE code <> ''
)
INSERT INTO transform.unspsc_codes (
    unspsc_code, code_length, is_full_code, segment_code, family_code, class_code,
    commodity_title, class_title, family_title, segment_title, title_source, title_has_majority
)
SELECT
    ac.code,
    length(ac.code),
    ac.code ~ '^\d{8}$',
    CASE WHEN ac.code ~ '^\d{8}$' THEN substr(ac.code, 1, 2) || '000000' END,
    CASE WHEN ac.code ~ '^\d{8}$' THEN substr(ac.code, 1, 4) || '0000' END,
    CASE WHEN ac.code ~ '^\d{8}$' THEN substr(ac.code, 1, 6) || '00' END,
    t.commodity_title,
    t.class_title,
    t.family_title,
    t.segment_title,
    CASE WHEN t.code IS NOT NULL THEN 'from_normalized' ELSE 'code_only' END,
    t.title_has_majority
FROM all_codes ac
LEFT JOIN titles t ON t.code = ac.code;

COMMENT ON TABLE transform.unspsc_codes IS
    'Distinct UNSPSC codes (union of normalized_unspsc + Classification Codes) with derived hierarchy and majority-vote titles.';
