"""Load layer: copy the raw CSV verbatim into raw.purchase_orders.

Column names are renamed to snake_case at the raw layer (see
sql/00_init/02_raw_purchase_orders.sql for the audited mapping table);
COLUMN_MAPPING here is the executable source of truth for that mapping and
must be kept in sync with the SQL file's comment. The CSV header is
verified against it before copying, so a silent column reorder in a future
export fails loudly instead of mis-mapping data into the wrong columns.
"""

from __future__ import annotations

import csv
from pathlib import Path

import psycopg

COLUMN_MAPPING: tuple[tuple[str, str], ...] = (
    ("Creation Date", "creation_date"),
    ("Purchase Date", "purchase_date"),
    ("Fiscal Year", "fiscal_year"),
    ("LPA Number", "lpa_number"),
    ("Purchase Order Number", "purchase_order_number"),
    ("Requisition Number", "requisition_number"),
    ("Acquisition Type", "acquisition_type"),
    ("Sub-Acquisition Type", "sub_acquisition_type"),
    ("Acquisition Method", "acquisition_method"),
    ("Sub-Acquisition Method", "sub_acquisition_method"),
    ("Department Name", "department_name"),
    ("Supplier Code", "supplier_code"),
    ("Supplier Name", "supplier_name"),
    ("Supplier Qualifications", "supplier_qualifications"),
    ("Supplier Zip Code", "supplier_zip_code"),
    ("CalCard", "calcard"),
    ("Item Name", "item_name"),
    ("Item Description", "item_description"),
    ("Quantity", "quantity"),
    ("Unit Price", "unit_price"),
    ("Total Price", "total_price"),
    ("Classification Codes", "classification_codes"),
    ("Normalized UNSPSC", "normalized_unspsc"),
    ("Commodity Title", "commodity_title"),
    ("Class", "class"),
    ("Class Title", "class_title"),
    ("Family", "family"),
    ("Family Title", "family_title"),
    ("Segment", "segment"),
    ("Segment Title", "segment_title"),
    ("Location", "location"),
    ("REMOVE AMERISOURCE", "remove_amerisource"),
)


class HeaderMismatchError(ValueError):
    """Raised when a CSV's header doesn't match the expected COLUMN_MAPPING order."""


def assert_header_matches(csv_path: Path) -> None:
    """Fail loudly if the CSV header doesn't match COLUMN_MAPPING, never silently mismap columns."""
    with csv_path.open(newline="", encoding="utf-8") as f:
        header = next(csv.reader(f))
    expected = [source for source, _ in COLUMN_MAPPING]
    if header != expected:
        raise HeaderMismatchError(
            f"CSV header does not match the expected columns.\nExpected: {expected}\nGot: {header}"
        )


def load_raw_purchase_orders(csv_path: Path, conn: psycopg.Connection) -> int:
    """Truncate and reload raw.purchase_orders verbatim from the CSV. Returns the row count."""
    assert_header_matches(csv_path)
    columns = ", ".join(name for _, name in COLUMN_MAPPING)

    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE raw.purchase_orders RESTART IDENTITY CASCADE")
        with (
            cur.copy(
                f"COPY raw.purchase_orders ({columns}) FROM STDIN WITH (FORMAT csv, HEADER true)"
            ) as copy,
            csv_path.open("rb") as f,
        ):
            while chunk := f.read(1024 * 1024):
                copy.write(chunk)
        cur.execute("SELECT count(*) FROM raw.purchase_orders")
        (row_count,) = cur.fetchone()

    conn.commit()
    return row_count
