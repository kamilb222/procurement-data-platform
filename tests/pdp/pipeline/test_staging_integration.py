"""Integration test: init + load + staging against a real, throwaway Postgres.

Uses testcontainers so this never touches the docker-compose dev database
and needs nothing beyond a working Docker daemon -- no live services, no
network calls, consistent with "tests must not require the real dataset."
"""

from collections.abc import Iterator
from pathlib import Path

import psycopg
import pytest
from testcontainers.postgres import PostgresContainer

from pdp.pipeline.load import load_raw_purchase_orders
from pdp.pipeline.runner import run_sql_dir

FIXTURE = Path(__file__).resolve().parents[2] / "fixtures" / "sample_purchase_orders.csv"
SQL_ROOT = Path(__file__).resolve().parents[3] / "sql"


@pytest.fixture(scope="module")
def loaded_conn() -> Iterator[psycopg.Connection]:
    """Run init + load + staging against the synthetic fixture in a fresh container."""
    with PostgresContainer("postgres:16-alpine", driver=None) as pg:
        conn = psycopg.connect(pg.get_connection_url())
        run_sql_dir(conn, SQL_ROOT / "00_init")
        load_raw_purchase_orders(FIXTURE, conn)
        run_sql_dir(conn, SQL_ROOT / "10_staging")
        yield conn
        conn.close()


def _one(conn: psycopg.Connection, sql: str, params: tuple = ()) -> tuple:
    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchone()


def test_reconciliation_holds(loaded_conn: psycopg.Connection) -> None:
    (raw_count,) = _one(loaded_conn, "SELECT count(*) FROM raw.purchase_orders")
    (staging_count,) = _one(loaded_conn, "SELECT count(*) FROM staging.purchase_orders")
    (rejected_count,) = _one(loaded_conn, "SELECT count(*) FROM staging.rejected_rows")

    assert raw_count == 20
    # 4 fixture rows are deliberately malformed to exercise the profiler's
    # anomaly detection (ISO-formatted creation dates, a date+time value, a
    # null CalCard) -- staging's hard-reject rules correctly catch all 4.
    assert staging_count == 16
    assert rejected_count == 4
    assert raw_count == staging_count + rejected_count


def test_rejected_rows_have_the_expected_reasons(loaded_conn: psycopg.Connection) -> None:
    with loaded_conn.cursor() as cur:
        cur.execute(
            "SELECT r.purchase_order_number, rr.reason FROM staging.rejected_rows rr "
            "JOIN raw.purchase_orders r USING (raw_row_id) ORDER BY r.purchase_order_number"
        )
        rejected = dict(cur.fetchall())

    assert set(rejected) == {"PO-0002", "PO-0003", "PO-0006", "PO-0013"}
    assert "creation_date unparseable" in rejected["PO-0002"]  # ISO date "2013-09-05"
    assert "calcard not in" in rejected["PO-0003"]  # null CalCard
    assert "creation_date unparseable" in rejected["PO-0006"]  # "9/20/2013 0:00" (date+time)
    assert "creation_date unparseable" in rejected["PO-0013"]  # ISO date "2013-10-08"


def test_remove_amerisource_column_is_dropped(loaded_conn: psycopg.Connection) -> None:
    rows = _one(
        loaded_conn,
        """
        SELECT count(*) FROM information_schema.columns
        WHERE table_schema = 'staging' AND table_name = 'purchase_orders'
          AND column_name ILIKE %s
        """,
        ("%amerisource%",),
    )
    assert rows == (0,)


def test_accounting_negative_price_is_parsed(loaded_conn: psycopg.Connection) -> None:
    (unit_price,) = _one(
        loaded_conn,
        "SELECT unit_price FROM staging.purchase_orders WHERE purchase_order_number = 'PO-0018'",
    )
    assert unit_price == -25.00


def test_mojibake_is_repaired(loaded_conn: psycopg.Connection) -> None:
    (item_name,) = _one(
        loaded_conn,
        "SELECT item_name FROM staging.purchase_orders WHERE purchase_order_number = 'PO-0019'",
    )
    assert item_name == "Pentel®:EnerGel RTX Roller Ball Retractable Gel Pen, Blue Ink, Medium"


def test_location_is_split_into_zip_lat_lon(loaded_conn: psycopg.Connection) -> None:
    zip_, lat, lon = _one(
        loaded_conn,
        "SELECT location_zip, location_lat, location_lon FROM staging.purchase_orders "
        "WHERE purchase_order_number = 'PO-0001'",
    )
    assert zip_ == "90001"
    assert float(lat) == pytest.approx(34.052235)
    assert float(lon) == pytest.approx(-118.243683)


def test_duplicate_rows_are_not_deduplicated_in_staging(loaded_conn: psycopg.Connection) -> None:
    (count,) = _one(
        loaded_conn,
        "SELECT count(*) FROM staging.purchase_orders WHERE purchase_order_number = 'PO-0005'",
    )
    assert count == 2  # the fixture's exact-duplicate pair both survive staging


def test_supplier_code_1000_has_one_valid_row_and_two_rejected(
    loaded_conn: psycopg.Connection,
) -> None:
    """Of the 3 fixture rows sharing Supplier Code 1000, 2 (PO-0002, PO-0013) use an
    ISO creation date and are hard-rejected -- only PO-0001 reaches staging. Supplier
    name normalization ("Acme Inc" vs "ACME, INC.") is a transform-layer concern, not
    tested here.
    """
    (count,) = _one(
        loaded_conn,
        "SELECT count(*) FROM staging.purchase_orders WHERE supplier_code = '1000'",
    )
    assert count == 1
