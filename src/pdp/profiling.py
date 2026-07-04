"""Profiling utilities for the raw purchase-orders CSV.

Pure, dataset-agnostic functions: load the CSV as strings (no type
inference), compute per-column statistics, run heuristic anomaly checks, and
render everything as a markdown report. Used by scripts/profile_raw.py.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import pandas as pd

CURRENCY_CHARS_PATTERN = r"[$,]"
PAREN_NEGATIVE_PATTERN = re.compile(r"^\(.*\)$")
# Heuristic only: matches common UTF-8-read-as-Latin-1 mangling (e.g. "Ã¢ÂÂ"),
# but the same characters appear in legitimate accented text (e.g. "Château").
# A hit is a prompt to eyeball the top values, not a confirmed defect.
MOJIBAKE_PATTERN = r"[ÃÂâ]"
DATE_FORMAT_PATTERNS: dict[str, re.Pattern[str]] = {
    "M/D/YYYY": re.compile(r"^\d{1,2}/\d{1,2}/\d{4}$"),
    "M/D/YYYY H:MM": re.compile(r"^\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}$"),
    "YYYY-MM-DD": re.compile(r"^\d{4}-\d{2}-\d{2}$"),
}


def load_raw(path: Path) -> pd.DataFrame:
    """Load the raw CSV as all-string columns, with no type inference."""
    return pd.read_csv(path, dtype=str, keep_default_na=True, on_bad_lines="warn")


def raw_line_count(path: Path) -> int:
    """Count physical newlines in the file.

    Differs from the logical row count when fields embed newlines themselves
    (quoted multi-line values are valid CSV but throw off naive line counts).
    """
    with path.open("rb") as f:
        return sum(1 for _ in f)


@dataclass
class ColumnProfile:
    """Summary statistics and anomaly flags for one raw column."""

    name: str
    non_null: int
    null_count: int
    null_pct: float
    distinct: int
    min_value: str | None
    max_value: str | None
    top_values: list[tuple[str, int]]
    anomalies: list[str]


def _date_format_anomalies(values: pd.Series) -> list[str]:
    """Report how many values match each known date pattern, and how many match none."""
    hits = {label: int(values.str.match(pat).sum()) for label, pat in DATE_FORMAT_PATTERNS.items()}
    matched_formats = {label: n for label, n in hits.items() if n}
    unmatched = len(values) - sum(matched_formats.values())
    if len(matched_formats) <= 1 and not unmatched:
        return []
    detail = ", ".join(f"{label}: {n:,}" for label, n in matched_formats.items())
    return [f"mixed/unrecognized date formats — {detail}; unrecognized: {unmatched:,}"]


def detect_column_anomalies(name: str, values: pd.Series) -> list[str]:
    """Heuristic, evidence-based anomaly flags for a column's non-null values.

    Note: the mojibake check is a heuristic and can false-positive on
    legitimate accented characters (e.g. "Château") — treat it as a prompt
    to look at the top values, not a guaranteed defect.
    """
    anomalies: list[str] = []
    if values.empty:
        return anomalies

    whitespace_mismatch = int((values != values.str.strip()).sum())
    if whitespace_mismatch:
        anomalies.append(f"{whitespace_mismatch:,} value(s) with leading/trailing whitespace")

    newline_count = int(values.str.contains(r"[\r\n]", regex=True).sum())
    if newline_count:
        anomalies.append(f"{newline_count:,} value(s) contain an embedded newline/carriage return")

    mojibake_count = int(values.str.contains(MOJIBAKE_PATTERN, regex=True).sum())
    if mojibake_count:
        anomalies.append(
            f"{mojibake_count:,} value(s) show possible mojibake (double-encoded text, e.g. "
            f"'Ã¢ÂÂ'; heuristic — may include false positives on legitimate accented characters)"
        )

    lname = name.lower()
    if "price" in lname or lname == "quantity":
        currency_like = int(values.str.contains(CURRENCY_CHARS_PATTERN, regex=True).sum())
        if currency_like:
            anomalies.append(f"{currency_like:,} value(s) contain `$` or a thousands separator")

        paren_negative = int(values.str.match(PAREN_NEGATIVE_PATTERN).sum())
        if paren_negative:
            anomalies.append(
                f"{paren_negative:,} value(s) use accounting-style parentheses for negative "
                f'amounts (e.g. "($7.00)")'
            )

    if "date" in lname:
        anomalies.extend(_date_format_anomalies(values))

    return anomalies


def profile_column(series: pd.Series) -> ColumnProfile:
    """Compute null%, distinct count, min/max, top-10 values, and anomalies for one column."""
    non_null = series.dropna()
    total = len(series)
    null_count = total - len(non_null)
    return ColumnProfile(
        name=str(series.name),
        non_null=len(non_null),
        null_count=null_count,
        null_pct=(null_count / total * 100) if total else 0.0,
        distinct=int(non_null.nunique()),
        min_value=non_null.min() if not non_null.empty else None,
        max_value=non_null.max() if not non_null.empty else None,
        top_values=list(non_null.value_counts().head(10).items()),
        anomalies=detect_column_anomalies(str(series.name), non_null),
    )


def money_to_float(values: pd.Series) -> pd.Series:
    """Best-effort parse of `$1,234.56` and accounting-style `($1,234.56)` strings to float.

    For reporting only — this is not the canonical cleaning rule, just enough
    parsing to report a realistic range/zero/negative count during profiling.
    """
    stripped = values.str.strip()
    is_paren_negative = stripped.str.match(PAREN_NEGATIVE_PATTERN)
    cleaned = stripped.str.replace(r"[()$,]", "", regex=True)
    magnitude = pd.to_numeric(cleaned, errors="coerce")
    return magnitude.mask(is_paren_negative, -magnitude)


def price_sanity_report(
    df: pd.DataFrame, columns: tuple[str, ...] = ("Unit Price", "Total Price")
) -> list[str]:
    """Report unparseable, zero, negative counts and the parsed range for each price column."""
    lines = []
    for col in columns:
        present = df[col].dropna()
        parsed = money_to_float(present)
        valid = parsed.dropna()
        value_range = f"{valid.min():,.2f} to {valid.max():,.2f}" if not valid.empty else "n/a"
        unparseable, zero, negative = (
            int(parsed.isna().sum()),
            int((parsed == 0).sum()),
            int((parsed < 0).sum()),
        )
        lines.append(
            f"- **{col}**: {unparseable:,} unparseable, {zero:,} zero, {negative:,} negative "
            f"out of {len(present):,} non-null values (parsed range: {value_range})"
        )
    return lines


def supplier_name_variants_report(df: pd.DataFrame, top_n: int = 5) -> list[str]:
    """Report how many Supplier Codes map to more than one distinct Supplier Name."""
    pairs = df[["Supplier Code", "Supplier Name"]].dropna()
    variants_per_code = pairs.groupby("Supplier Code")["Supplier Name"].nunique()
    offenders = variants_per_code[variants_per_code > 1].sort_values(ascending=False)
    lines = [
        f"- {len(offenders):,} of {variants_per_code.size:,} supplier codes have more than one "
        f"distinct Supplier Name."
    ]
    for code, count in offenders.head(top_n).items():
        names = sorted(pairs.loc[pairs["Supplier Code"] == code, "Supplier Name"].unique())
        lines.append(f"  - `{code}`: {count} variants — {', '.join(names)}")
    return lines


def duplicate_rows_report(df: pd.DataFrame) -> list[str]:
    """Report exact full-row duplicate counts."""
    dup_count = int(df.duplicated(keep=False).sum())
    pct = dup_count / len(df) * 100 if len(df) else 0.0
    return [f"- {dup_count:,} rows ({pct:.2f}%) are exact full-row duplicates."]


def _columns_with_embedded_newlines(df: pd.DataFrame) -> list[str]:
    """Return column names with at least one non-null value containing a newline/carriage return."""
    return [col for col in df.columns if df[col].dropna().str.contains(r"[\r\n]", regex=True).any()]


def _format_value(value: str, limit: int = 60) -> str:
    """Escape newlines/pipes and truncate long values for safe markdown table cells."""
    flat = value.replace("\n", "\\n").replace("\r", "\\r").replace("|", "\\|")
    return flat if len(flat) <= limit else flat[: limit - 1] + "…"


def _render_summary_table(profiles: list[ColumnProfile]) -> str:
    header = "| Column | Null % | Distinct | Min | Max |\n|---|---|---|---|---|"
    rows = [
        f"| {p.name} | {p.null_pct:.1f}% | {p.distinct:,} | "
        f"{_format_value(p.min_value) if p.min_value is not None else '—'} | "
        f"{_format_value(p.max_value) if p.max_value is not None else '—'} |"
        for p in profiles
    ]
    return "\n".join([header, *rows])


def _render_column_detail(p: ColumnProfile) -> str:
    lines = [
        f"### {p.name}",
        "",
        f"- Non-null: {p.non_null:,} | Null: {p.null_count:,} ({p.null_pct:.1f}%) | "
        f"Distinct: {p.distinct:,}",
    ]
    if p.anomalies:
        lines.append("- **Anomalies:**")
        lines.extend(f"  - {a}" for a in p.anomalies)
    else:
        lines.append("- Anomalies: none detected")
    if p.top_values:
        lines.extend(["", "| Value | Count |", "|---|---|"])
        lines.extend(f"| {_format_value(v)} | {c:,} |" for v, c in p.top_values)
    lines.append("")
    return "\n".join(lines)


def build_report(df: pd.DataFrame, source: Path, raw_lines: int) -> str:
    """Assemble the full markdown profile for the given raw dataframe."""
    profiles = [profile_column(df[col]) for col in df.columns]
    generated = datetime.now(UTC).strftime("%Y-%m-%d %H:%M UTC")

    row_count_note = ""
    if raw_lines != len(df):
        newline_cols = _columns_with_embedded_newlines(df)
        if newline_cols:
            cols_list = ", ".join(f"`{c}`" for c in newline_cols)
            row_count_note = (
                f"  (differs from row count — embedded newlines detected in: {cols_list})"
            )
        else:
            row_count_note = (
                "  (differs from row count — cause not identified by the embedded-newline scan)"
            )

    parts = [
        "# Data Profile — purchase_orders.csv",
        "",
        f"- Generated: {generated}",
        f"- Source file: `{source}`",
        f"- Logical rows parsed: {len(df):,}",
        f"- Raw physical lines in file: {raw_lines:,}{row_count_note}",
        f"- Columns: {len(df.columns)}",
        "",
        "## Summary",
        "",
        "_Min/Max are lexicographic comparisons of the raw strings, not chronological or numeric "
        'ordering — e.g. a "min" date sorting after a "max" date just reflects string sort order._',
        "",
        _render_summary_table(profiles),
        "",
        "## Cross-column checks",
        "",
        "### Duplicate rows",
        *duplicate_rows_report(df),
        "",
        "### Supplier name consistency (same Supplier Code, different Supplier Name)",
        *supplier_name_variants_report(df),
        "",
        "### Price sanity (Unit Price / Total Price)",
        *price_sanity_report(df),
        "",
        "## Per-column detail",
        "",
        *[_render_column_detail(p) for p in profiles],
    ]
    return "\n".join(parts)
