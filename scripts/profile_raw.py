"""CLI: profile the raw purchase-orders CSV and write a markdown report.

Usage:
    uv run python scripts/profile_raw.py
    uv run python scripts/profile_raw.py --input path/to.csv --output docs/data_profile.md
"""

from __future__ import annotations

import argparse
from pathlib import Path

from pdp.profiling import build_report, load_raw, raw_line_count


def parse_args() -> argparse.Namespace:
    """Parse --input/--output CLI arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path("data/raw/purchase_orders.csv"))
    parser.add_argument("--output", type=Path, default=Path("docs/data_profile.md"))
    return parser.parse_args()


def main() -> None:
    """Load the raw CSV, build the markdown profile, and write it to disk."""
    args = parse_args()
    df = load_raw(args.input)
    lines = raw_line_count(args.input)
    report = build_report(df, source=args.input, raw_lines=lines)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(report, encoding="utf-8")

    print(f"Parsed {len(df):,} rows x {len(df.columns)} columns from {args.input}")
    print(f"Wrote profile to {args.output}")


if __name__ == "__main__":
    main()
