"""CLI: run the SQL pipeline layers in order, logging row counts per step.

Usage:
    uv run python scripts/run_pipeline.py [--stage staging|transform|marts|all]

Each named stage runs everything up to and including it (init and the raw
load always run first); "transform" and "marts" are currently no-ops until
Stage 1 steps 5-6 add SQL files to those directories.
"""

from __future__ import annotations

import argparse
import logging
from pathlib import Path

from pdp.db import get_connection
from pdp.pipeline.runner import run_init, run_load, run_marts, run_staging, run_transform

logging.basicConfig(level=logging.INFO, format="%(message)s")


def parse_args() -> argparse.Namespace:
    """Parse --stage/--csv CLI arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=["staging", "transform", "marts", "all"], default="all")
    parser.add_argument("--csv", type=Path, default=Path("data/raw/purchase_orders.csv"))
    return parser.parse_args()


def main() -> None:
    """Run the pipeline up to the requested stage."""
    args = parse_args()
    with get_connection() as conn:
        run_init(conn)
        run_load(conn, args.csv)
        run_staging(conn)
        if args.stage in ("transform", "marts", "all"):
            run_transform(conn)
        if args.stage in ("marts", "all"):
            run_marts(conn)


if __name__ == "__main__":
    main()
