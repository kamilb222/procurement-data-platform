-- Purpose: department dimension.
-- Inputs:  staging.purchase_orders.
-- Outputs: marts.dim_department.
-- Grain:   one row per distinct department_name.
--
-- Uses a small surrogate key (department_key) rather than the long
-- department name as the fact FK, to keep the fact narrow. Profiling
-- verified department_name is never null (0 of 344,504 rows) and has 111
-- distinct values, so no "unknown department" member is needed.

CREATE TABLE IF NOT EXISTS marts.dim_department (
    department_key   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_name  TEXT NOT NULL UNIQUE
);

TRUNCATE TABLE marts.dim_department RESTART IDENTITY CASCADE;

INSERT INTO marts.dim_department (department_name)
SELECT DISTINCT department_name
FROM staging.purchase_orders
WHERE department_name IS NOT NULL
ORDER BY department_name;

COMMENT ON TABLE marts.dim_department IS
    'Department dimension (111 rows); surrogate key keeps the fact narrow.';
