"""Integration test for the marts layer, driven by the shared pipeline_conn
fixture (see conftest.py). Asserts the star schema's grain, referential
integrity, key/FK policy, and the analytical views on the synthetic fixture."""

import psycopg


def _one(conn: psycopg.Connection, sql: str, params: tuple = ()) -> tuple:
    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchone()


def test_fact_grain_matches_staging(pipeline_conn: psycopg.Connection) -> None:
    (fact,) = _one(pipeline_conn, "SELECT count(*) FROM marts.fact_purchase_orders")
    (staging,) = _one(pipeline_conn, "SELECT count(*) FROM staging.purchase_orders")
    assert fact == staging == 16


def test_dimension_counts(pipeline_conn: psycopg.Connection) -> None:
    assert _one(pipeline_conn, "SELECT count(*) FROM marts.dim_department") == (2,)
    assert _one(pipeline_conn, "SELECT count(*) FROM marts.dim_supplier") == (15,)
    assert _one(pipeline_conn, "SELECT count(*) FROM marts.dim_unspsc") == (2,)
    assert _one(pipeline_conn, "SELECT count(*) FROM marts.bridge_po_classification") == (2,)


def test_no_dangling_dimension_fks(pipeline_conn: psycopg.Connection) -> None:
    (bad_supplier,) = _one(
        pipeline_conn,
        "SELECT count(*) FROM marts.fact_purchase_orders f "
        "LEFT JOIN marts.dim_supplier d USING (supplier_code) "
        "WHERE f.supplier_code IS NOT NULL AND d.supplier_code IS NULL",
    )
    (bad_unspsc,) = _one(
        pipeline_conn,
        "SELECT count(*) FROM marts.fact_purchase_orders f "
        "LEFT JOIN marts.dim_unspsc d USING (unspsc_code) "
        "WHERE f.unspsc_code IS NOT NULL AND d.unspsc_code IS NULL",
    )
    assert bad_supplier == 0
    assert bad_unspsc == 0


def test_creation_date_key_always_populated(pipeline_conn: psycopg.Connection) -> None:
    (nulls,) = _one(
        pipeline_conn,
        "SELECT count(*) FROM marts.fact_purchase_orders WHERE creation_date_key IS NULL",
    )
    assert nulls == 0


def test_dim_supplier_carries_zip_enrichment(pipeline_conn: psycopg.Connection) -> None:
    zip5, is_foreign = _one(
        pipeline_conn,
        "SELECT supplier_zip5, is_foreign_zip FROM marts.dim_supplier WHERE supplier_code = '1000'",
    )
    assert zip5 == "90001"
    assert is_foreign is False


def test_top_suppliers_po_count_is_distinct_purchase_orders(
    pipeline_conn: psycopg.Connection,
) -> None:
    # Delta LLC's two fixture lines are the exact-duplicate PO-0005 pair: two
    # line items, one distinct purchase order. po_count must count the order,
    # not the lines.
    line_count, po_count = _one(
        pipeline_conn,
        "SELECT line_count, po_count FROM marts.v_top_suppliers WHERE supplier_name = 'Delta LLC'",
    )
    assert line_count == 2
    assert po_count == 1


def test_family_title_consistent_within_family(pipeline_conn: psycopg.Connection) -> None:
    (inconsistent,) = _one(
        pipeline_conn,
        "SELECT count(*) FROM ("
        "  SELECT family_code FROM marts.dim_unspsc "
        "  WHERE family_code IS NOT NULL AND family_title IS NOT NULL "
        "  GROUP BY family_code HAVING count(DISTINCT family_title) > 1"
        ") t",
    )
    assert inconsistent == 0


def test_spend_by_fiscal_year_view(pipeline_conn: psycopg.Connection) -> None:
    rows = []
    with pipeline_conn.cursor() as cur:
        cur.execute("SELECT fiscal_year, line_count FROM marts.v_spend_by_fiscal_year")
        rows = cur.fetchall()
    # All 16 accepted fixture rows fall in CA FY 2013-2014.
    assert rows == [("2013-2014", 16)]
