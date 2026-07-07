-- Purpose: supplier dimension.
-- Inputs:  transform.supplier_canonical, staging.purchase_orders.
-- Outputs: marts.dim_supplier.
-- Grain:   one row per supplier_code.
--
-- Natural key: supplier_code is already a compact, stable, traceable key,
-- so it doubles as the PK and the fact FK (no surrogate).
--
-- Enriched with zip/location: profiling verified supplier_zip5,
-- is_foreign_zip, location_lat and location_lon are each single-valued per
-- supplier_code (0 codes carry more than one), so they belong on the
-- supplier rather than being repeated on every fact row. Aggregates below
-- collapse the (single) value per code. supplier_qualifications is NOT
-- here -- it genuinely varies within a code (1,231 codes have >1 value) and
-- stays a line-level attribute on the fact. The 36 rows with a NULL
-- supplier_code carry no zip/location at all, so nothing is lost by moving
-- these attributes off the fact.

CREATE TABLE IF NOT EXISTS marts.dim_supplier (
    supplier_code   TEXT PRIMARY KEY,
    supplier_name   TEXT NOT NULL,
    supplier_zip5   TEXT,
    is_foreign_zip  BOOLEAN,
    location_lat    NUMERIC,
    location_lon    NUMERIC
);

TRUNCATE TABLE marts.dim_supplier CASCADE;

INSERT INTO marts.dim_supplier (
    supplier_code, supplier_name, supplier_zip5, is_foreign_zip, location_lat, location_lon
)
SELECT
    sc.supplier_code,
    sc.supplier_name,
    agg.supplier_zip5,
    agg.is_foreign_zip,
    agg.location_lat,
    agg.location_lon
FROM transform.supplier_canonical sc
JOIN (
    -- Single-valued per code (verified), so max()/bool_or() just pick that one value.
    SELECT
        supplier_code,
        max(supplier_zip5) AS supplier_zip5,
        bool_or(is_foreign_zip) AS is_foreign_zip,
        max(location_lat) AS location_lat,
        max(location_lon) AS location_lon
    FROM staging.purchase_orders
    WHERE supplier_code IS NOT NULL
    GROUP BY supplier_code
) agg USING (supplier_code);

COMMENT ON TABLE marts.dim_supplier IS
    'Supplier dimension keyed on supplier_code; enriched with per-code zip5/foreign-flag/centroid coordinates.';
