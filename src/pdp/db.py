"""Postgres connection helpers built on psycopg v3."""

from collections.abc import Iterator
from contextlib import contextmanager

import psycopg

from pdp.config import get_settings


@contextmanager
def get_connection() -> Iterator[psycopg.Connection]:
    """Yield a psycopg connection to the configured database, closing it on exit."""
    conn = psycopg.connect(get_settings().database_url)
    try:
        yield conn
    finally:
        conn.close()
