-- Purpose: analytical views over the star schema.
-- Inputs:  marts.fact_purchase_orders + dimensions.
-- Outputs: five marts.v_* views.
-- Grain:   stated per view below.
--
-- Spend convention: total_spend = SUM(total_price) over the full fact (net
-- of credits, duplicates included), per the agreed rule that spend is
-- computed over the whole dataset by default; the fact's flags
-- (is_credit, is_exact_duplicate, ...) let an analyst re-slice deliberately.
-- Time-based views key off creation_date (always present) rather than
-- purchase_date (nullable / sometimes out of range).

-- Total spend and line count per department per calendar quarter.
CREATE OR REPLACE VIEW marts.v_spend_by_department_quarter AS
SELECT
    dep.department_name,
    dt.year,
    dt.quarter,
    dt.quarter_label,
    sum(f.total_price) AS total_spend,
    count(*) AS line_count
FROM marts.fact_purchase_orders f
JOIN marts.dim_department dep USING (department_key)
JOIN marts.dim_date dt ON dt.date_key = f.creation_date_key
GROUP BY dep.department_name, dt.year, dt.quarter, dt.quarter_label;

-- Total spend and line count per California fiscal year (the headline trend).
CREATE OR REPLACE VIEW marts.v_spend_by_fiscal_year AS
SELECT
    dt.fiscal_year,
    sum(f.total_price) AS total_spend,
    count(*) AS line_count
FROM marts.fact_purchase_orders f
JOIN marts.dim_date dt ON dt.date_key = f.creation_date_key
GROUP BY dt.fiscal_year;

-- Suppliers ranked by total spend, with line count and distinct-PO count.
-- po_count is COUNT(DISTINCT purchase_order_number) -- distinct purchase
-- orders, not line items. Known suppliers only (excludes the 36 null-code lines).
CREATE OR REPLACE VIEW marts.v_top_suppliers AS
SELECT
    sup.supplier_code,
    sup.supplier_name,
    sum(f.total_price) AS total_spend,
    count(*) AS line_count,
    count(DISTINCT f.purchase_order_number) AS po_count
FROM marts.fact_purchase_orders f
JOIN marts.dim_supplier sup USING (supplier_code)
GROUP BY sup.supplier_code, sup.supplier_name
ORDER BY total_spend DESC NULLS LAST;

-- Spend and line count by acquisition method, with each method's share of total spend.
CREATE OR REPLACE VIEW marts.v_spend_by_acquisition_method AS
SELECT
    f.acquisition_method,
    sum(f.total_price) AS total_spend,
    count(*) AS line_count,
    sum(f.total_price) / nullif(sum(sum(f.total_price)) OVER (), 0) AS spend_share
FROM marts.fact_purchase_orders f
GROUP BY f.acquisition_method
ORDER BY total_spend DESC NULLS LAST;

-- Spend and line count rolled up to UNSPSC segment; lines with no UNSPSC
-- code are grouped as "(unclassified)".
CREATE OR REPLACE VIEW marts.v_spend_by_unspsc_segment AS
SELECT
    coalesce(u.segment_title, '(unclassified)') AS segment_title,
    sum(f.total_price) AS total_spend,
    count(*) AS line_count
FROM marts.fact_purchase_orders f
LEFT JOIN marts.dim_unspsc u USING (unspsc_code)
GROUP BY coalesce(u.segment_title, '(unclassified)')
ORDER BY total_spend DESC NULLS LAST;
