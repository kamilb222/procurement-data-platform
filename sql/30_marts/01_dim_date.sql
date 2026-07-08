-- Purpose: calendar date dimension for the star schema.
-- Inputs:  none (generated from a fixed range).
-- Outputs: marts.dim_date.
-- Grain:   one row per calendar date.
--
-- Coverage: 2000-01-01 .. 2016-06-30. This spans every creation_date
-- (2012-07-02 .. 2015-06-30) plus purchase-date history back to ~2007
-- (seen in profiling) with a margin to the end of CA fiscal year 2015-2016.
-- Purchase dates outside this range (the parsed 1911 and 6070 values, 282
-- rows) get a NULL purchase_date_key in the fact -- see fact header for the
-- FK policy. CA state fiscal year runs Jul 1 - Jun 30; fiscal_year is
-- labelled "<start>-<end>" to match the source Fiscal Year column.

CREATE TABLE IF NOT EXISTS marts.dim_date (
    date_key        DATE PRIMARY KEY,
    year            INT NOT NULL,
    quarter         INT NOT NULL,
    quarter_label   TEXT NOT NULL,   -- e.g. "2013-Q3"
    month           INT NOT NULL,
    month_name      TEXT NOT NULL,
    day             INT NOT NULL,
    day_of_week     INT NOT NULL,    -- 0 = Sunday .. 6 = Saturday
    day_name        TEXT NOT NULL,
    is_weekend      BOOLEAN NOT NULL,
    fiscal_year     TEXT NOT NULL,   -- CA fiscal year (Jul-Jun), e.g. "2013-2014"
    fiscal_quarter  INT NOT NULL     -- 1 = Jul-Sep .. 4 = Apr-Jun
);

TRUNCATE TABLE marts.dim_date CASCADE;

INSERT INTO marts.dim_date (
    date_key, year, quarter, quarter_label, month, month_name, day,
    day_of_week, day_name, is_weekend, fiscal_year, fiscal_quarter
)
SELECT
    d::DATE,
    extract(YEAR FROM d)::INT,
    extract(QUARTER FROM d)::INT,
    extract(YEAR FROM d)::INT || '-Q' || extract(QUARTER FROM d)::INT,
    extract(MONTH FROM d)::INT,
    trim(to_char(d, 'Month')),
    extract(DAY FROM d)::INT,
    extract(DOW FROM d)::INT,
    trim(to_char(d, 'Day')),
    extract(ISODOW FROM d) IN (6, 7),
    CASE WHEN extract(MONTH FROM d) >= 7
         THEN extract(YEAR FROM d)::INT ELSE extract(YEAR FROM d)::INT - 1 END::TEXT
    || '-' ||
    CASE WHEN extract(MONTH FROM d) >= 7
         THEN extract(YEAR FROM d)::INT + 1 ELSE extract(YEAR FROM d)::INT END::TEXT,
    CASE
        WHEN extract(MONTH FROM d) BETWEEN 7 AND 9 THEN 1
        WHEN extract(MONTH FROM d) BETWEEN 10 AND 12 THEN 2
        WHEN extract(MONTH FROM d) BETWEEN 1 AND 3 THEN 3
        ELSE 4
    END
FROM generate_series(DATE '2000-01-01', DATE '2016-06-30', INTERVAL '1 day') AS g(d);

COMMENT ON TABLE marts.dim_date IS
    'Calendar date dimension, 2000-01-01 to 2016-06-30, with CA fiscal-year (Jul-Jun) attributes.';
