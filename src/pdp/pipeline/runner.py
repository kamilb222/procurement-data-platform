"""Pipeline runner: executes sql/ layers in order, logging row counts per step."""

from __future__ import annotations

import logging
from pathlib import Path

import psycopg

from pdp.pipeline.load import load_raw_purchase_orders

logger = logging.getLogger(__name__)

SQL_ROOT = Path(__file__).resolve().parents[3] / "sql"


def run_sql_dir(conn: psycopg.Connection, directory: Path) -> None:
    """Execute every .sql file in a directory, in filename order, each as its own transaction."""
    for sql_file in sorted(directory.glob("*.sql")):
        logger.info("Running %s", sql_file.relative_to(SQL_ROOT.parent))
        sql = sql_file.read_text(encoding="utf-8")
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()


def run_init(conn: psycopg.Connection) -> None:
    """Create schemas and tables (sql/00_init)."""
    run_sql_dir(conn, SQL_ROOT / "00_init")


def run_load(conn: psycopg.Connection, csv_path: Path) -> int:
    """Copy the raw CSV into raw.purchase_orders. Returns the row count."""
    row_count = load_raw_purchase_orders(csv_path, conn)
    logger.info("raw.purchase_orders: %s rows", f"{row_count:,}")
    return row_count


def run_staging(conn: psycopg.Connection) -> tuple[int, int]:
    """Run sql/10_staging. Returns (staging row count, rejected row count)."""
    run_sql_dir(conn, SQL_ROOT / "10_staging")
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM staging.purchase_orders")
        (staging_count,) = cur.fetchone()
        cur.execute("SELECT count(*) FROM staging.rejected_rows")
        (rejected_count,) = cur.fetchone()
    logger.info("staging.purchase_orders: %s rows", f"{staging_count:,}")
    logger.info("staging.rejected_rows: %s rows", f"{rejected_count:,}")
    return staging_count, rejected_count


def run_transform(conn: psycopg.Connection) -> None:
    """Run sql/20_transform (currently empty -- a no-op until Stage 1 step 5 lands)."""
    run_sql_dir(conn, SQL_ROOT / "20_transform")


def run_marts(conn: psycopg.Connection) -> None:
    """Run sql/30_marts (currently empty -- a no-op until Stage 1 step 6 lands)."""
    run_sql_dir(conn, SQL_ROOT / "30_marts")
