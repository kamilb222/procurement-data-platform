"""Shared fixtures for pipeline integration tests.

One throwaway Postgres container per test session runs the whole pipeline
(init + load + staging + transform) against the synthetic fixture, so the
staging and transform test modules share a single container. Uses
testcontainers, so nothing here touches the docker-compose dev database or
requires the real dataset.
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


@pytest.fixture(scope="session")
def pipeline_conn() -> Iterator[psycopg.Connection]:
    """Run init + load + staging + transform against the fixture in a fresh container."""
    with PostgresContainer("postgres:16-alpine", driver=None) as pg:
        conn = psycopg.connect(pg.get_connection_url())
        run_sql_dir(conn, SQL_ROOT / "00_init")
        load_raw_purchase_orders(FIXTURE, conn)
        run_sql_dir(conn, SQL_ROOT / "10_staging")
        run_sql_dir(conn, SQL_ROOT / "20_transform")
        yield conn
        conn.close()
