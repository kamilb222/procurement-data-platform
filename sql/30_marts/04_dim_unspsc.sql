-- Purpose: UNSPSC code dimension (commodity grain) with a consistent
--          hierarchy of titles.
-- Inputs:  transform.unspsc_codes, staging.purchase_orders.
-- Outputs: marts.dim_unspsc.
-- Grain:   one row per UNSPSC code (natural key = the code).
--
-- Title resolution: commodity_title and class_title come straight from
-- transform.unspsc_codes (verified unambiguous per code). family_title and
-- segment_title are re-resolved here by majority vote at the family_code /
-- segment_code grain, so every commodity code in a family shows the SAME
-- family title. This fixes the 3 families where a truncated title (e.g.
-- "lized trade construction and maintenance services") would otherwise
-- leak onto some commodity codes; segment titles had no disagreement but
-- are voted the same way for uniformity. A side benefit: code_only codes
-- (present only via Classification Codes, with no titles of their own)
-- inherit family/segment titles through their derived hierarchy codes.

CREATE TABLE IF NOT EXISTS marts.dim_unspsc (
    unspsc_code         TEXT PRIMARY KEY,
    code_length         INT NOT NULL,
    is_full_code        BOOLEAN NOT NULL,
    segment_code        TEXT,
    segment_title       TEXT,
    family_code         TEXT,
    family_title        TEXT,
    class_code          TEXT,
    class_title         TEXT,
    commodity_title     TEXT,
    title_source        TEXT NOT NULL,
    title_has_majority  BOOLEAN
);

TRUNCATE TABLE marts.dim_unspsc CASCADE;

WITH family_title_map AS (
    SELECT family AS family_code, mode() WITHIN GROUP (ORDER BY family_title) AS family_title
    FROM staging.purchase_orders
    WHERE family IS NOT NULL AND family_title IS NOT NULL
    GROUP BY family
),
segment_title_map AS (
    SELECT segment AS segment_code, mode() WITHIN GROUP (ORDER BY segment_title) AS segment_title
    FROM staging.purchase_orders
    WHERE segment IS NOT NULL AND segment_title IS NOT NULL
    GROUP BY segment
)
INSERT INTO marts.dim_unspsc (
    unspsc_code, code_length, is_full_code, segment_code, segment_title,
    family_code, family_title, class_code, class_title, commodity_title,
    title_source, title_has_majority
)
SELECT
    u.unspsc_code,
    u.code_length,
    u.is_full_code,
    u.segment_code,
    sm.segment_title,
    u.family_code,
    fm.family_title,
    u.class_code,
    u.class_title,
    u.commodity_title,
    u.title_source,
    u.title_has_majority
FROM transform.unspsc_codes u
LEFT JOIN family_title_map fm ON fm.family_code = u.family_code
LEFT JOIN segment_title_map sm ON sm.segment_code = u.segment_code;

COMMENT ON TABLE marts.dim_unspsc IS
    'UNSPSC code dimension; family/segment titles majority-voted at their own grain for consistency.';
