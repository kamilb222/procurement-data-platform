"""Integration test for the transform layer, driven by the shared pipeline_conn
fixture (see conftest.py). Asserts the derived flags, canonical maps, UNSPSC
dimension source, and classification bridge on the synthetic fixture."""

import psycopg


def _one(conn: psycopg.Connection, sql: str, params: tuple = ()) -> tuple:
    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchone()


def _po_set(conn: psycopg.Connection, where: str) -> set[str]:
    """Return the set of purchase_order_numbers whose enriched row matches `where`."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT s.purchase_order_number "
            "FROM transform.purchase_orders_enriched e "
            "JOIN staging.purchase_orders s USING (raw_row_id) "
            f"WHERE {where}"
        )
        return {row[0] for row in cur.fetchall()}


def test_enriched_row_count_matches_staging(pipeline_conn: psycopg.Connection) -> None:
    (enriched,) = _one(pipeline_conn, "SELECT count(*) FROM transform.purchase_orders_enriched")
    (staging,) = _one(pipeline_conn, "SELECT count(*) FROM staging.purchase_orders")
    assert enriched == staging == 16


def test_is_credit_flags_the_accounting_negative_row(pipeline_conn: psycopg.Connection) -> None:
    assert _po_set(pipeline_conn, "e.is_credit") == {"PO-0018"}


def test_is_zero_price_flags_the_zero_row(pipeline_conn: psycopg.Connection) -> None:
    assert _po_set(pipeline_conn, "e.is_zero_price") == {"PO-0004"}


def test_exact_duplicate_pair_flagged_with_occurrence(pipeline_conn: psycopg.Connection) -> None:
    with pipeline_conn.cursor() as cur:
        cur.execute(
            "SELECT s.purchase_order_number, e.dup_occurrence "
            "FROM transform.purchase_orders_enriched e "
            "JOIN staging.purchase_orders s USING (raw_row_id) "
            "WHERE e.is_exact_duplicate ORDER BY s.purchase_order_number, e.dup_occurrence"
        )
        rows = cur.fetchall()
    # The fixture's PO-0005 appears twice; both are flagged, numbered 1 and 2.
    assert rows == [("PO-0005", 1), ("PO-0005", 2)]


def test_supplier_canonical_resolves_one_name_per_code(pipeline_conn: psycopg.Connection) -> None:
    (name,) = _one(
        pipeline_conn,
        "SELECT supplier_name FROM transform.supplier_canonical WHERE supplier_code = '1000'",
    )
    assert name == "Acme Inc"


def test_unspsc_hierarchy_derived_from_code_digits(pipeline_conn: psycopg.Connection) -> None:
    code, segment, family, class_, commodity, source = _one(
        pipeline_conn,
        "SELECT unspsc_code, segment_code, family_code, class_code, commodity_title, title_source "
        "FROM transform.unspsc_codes WHERE unspsc_code = '43211500'",
    )
    assert segment == "43000000"
    assert family == "43210000"
    assert class_ == "43211500"
    assert commodity == "Widgets"
    assert source == "from_normalized"


def test_bridge_explodes_classification_codes_with_no_orphans(
    pipeline_conn: psycopg.Connection,
) -> None:
    (orphans,) = _one(
        pipeline_conn,
        "SELECT count(*) FROM transform.po_classification b "
        "LEFT JOIN transform.unspsc_codes u ON u.unspsc_code = b.unspsc_code "
        "WHERE u.unspsc_code IS NULL",
    )
    assert orphans == 0

    # Every bridge code must exist in the UNSPSC dimension source (referential integrity).
    with pipeline_conn.cursor() as cur:
        cur.execute(
            "SELECT s.purchase_order_number, b.unspsc_code "
            "FROM transform.po_classification b "
            "JOIN staging.purchase_orders s USING (raw_row_id) "
            "ORDER BY s.purchase_order_number, b.unspsc_code"
        )
        pairs = cur.fetchall()
    assert pairs == [("PO-0001", "43211500"), ("PO-0007", "44103127")]
