"""Unit tests for pdp.profiling, exercised against the synthetic fixture CSV."""

from pathlib import Path

import pandas as pd

from pdp.profiling import (
    build_report,
    detect_column_anomalies,
    duplicate_rows_report,
    load_raw,
    money_to_float,
    price_sanity_report,
    profile_column,
    raw_line_count,
    supplier_name_variants_report,
)

FIXTURE = Path(__file__).resolve().parent.parent / "fixtures" / "sample_purchase_orders.csv"


def test_load_raw_parses_logical_rows_not_physical_lines() -> None:
    df = load_raw(FIXTURE)
    assert len(df) == 20
    assert len(df.columns) == 32
    assert raw_line_count(FIXTURE) > len(
        df
    )  # the embedded-newline Location value inflates line count


def test_profile_column_computes_null_pct_and_distinct() -> None:
    series = pd.Series(["a", "b", "a", None, None], name="col")
    profile = profile_column(series)
    assert profile.non_null == 3
    assert profile.null_count == 2
    assert profile.null_pct == 40.0
    assert profile.distinct == 2
    assert profile.min_value == "a"
    assert profile.max_value == "b"
    assert profile.top_values[0] == ("a", 2)


def test_profile_column_handles_all_null() -> None:
    profile = profile_column(pd.Series([None, None], name="empty"))
    assert profile.non_null == 0
    assert profile.null_pct == 100.0
    assert profile.min_value is None
    assert profile.top_values == []
    assert profile.anomalies == []


def test_detect_anomalies_flags_whitespace() -> None:
    values = pd.Series([" padded", "clean"])
    anomalies = detect_column_anomalies("Department Name", values)
    assert any("whitespace" in a for a in anomalies)


def test_detect_anomalies_flags_embedded_newline() -> None:
    values = pd.Series(["90001\n(1.0, 2.0)", "90002"])
    anomalies = detect_column_anomalies("Location", values)
    assert any("newline" in a for a in anomalies)


def test_detect_anomalies_flags_currency_in_price_columns() -> None:
    values = pd.Series(["$1,234.56", "$5.00"])
    anomalies = detect_column_anomalies("Unit Price", values)
    assert any("thousands separator" in a for a in anomalies)


def test_detect_anomalies_ignores_currency_outside_price_columns() -> None:
    values = pd.Series(["$1,234.56", "$5.00"])
    anomalies = detect_column_anomalies("Item Description", values)
    assert anomalies == []


def test_detect_anomalies_flags_accounting_style_negative_parens() -> None:
    values = pd.Series(["($7.00)", "$5.00"])
    anomalies = detect_column_anomalies("Unit Price", values)
    assert any("parentheses for negative amounts" in a for a in anomalies)


def test_detect_anomalies_flags_mojibake() -> None:
    values = pd.Series(["Ã¢ÂÂiMac", "clean value"])
    anomalies = detect_column_anomalies("Item Name", values)
    assert any("mojibake" in a for a in anomalies)


def test_detect_anomalies_flags_mixed_date_formats() -> None:
    values = pd.Series(["1/2/2013", "2013-01-02", "3/4/2013"])
    anomalies = detect_column_anomalies("Creation Date", values)
    assert any("mixed/unrecognized date formats" in a for a in anomalies)


def test_detect_anomalies_single_consistent_format_is_clean() -> None:
    values = pd.Series(["1/2/2013", "3/4/2013"])
    anomalies = detect_column_anomalies("Creation Date", values)
    assert anomalies == []


def test_money_to_float_strips_currency_formatting() -> None:
    parsed = money_to_float(pd.Series(["$1,234.56", "-10.00", "$0.00"]))
    assert parsed.tolist() == [1234.56, -10.00, 0.00]


def test_money_to_float_treats_parens_as_negative() -> None:
    parsed = money_to_float(pd.Series(["($7.00)", "($1,234.56)"]))
    assert parsed.tolist() == [-7.00, -1234.56]


def test_price_sanity_report_flags_zero_and_negative() -> None:
    df = pd.DataFrame(
        {"Unit Price": ["$0.00", "-10.00", "$5.00"], "Total Price": ["$0.00", "-10.00", "$5.00"]}
    )
    lines = price_sanity_report(df)
    assert any("1 zero" in line and "1 negative" in line for line in lines)


def test_price_sanity_report_counts_paren_negative_as_negative_not_unparseable() -> None:
    df = pd.DataFrame({"Unit Price": ["($7.00)", "$5.00"], "Total Price": ["($7.00)", "$5.00"]})
    lines = price_sanity_report(df)
    assert any("0 unparseable" in line and "1 negative" in line for line in lines)


def test_supplier_name_variants_report_detects_same_code_different_name() -> None:
    df = pd.DataFrame(
        {
            "Supplier Code": ["1000", "1000", "1001"],
            "Supplier Name": ["Acme Inc", "ACME, INC.", "Beta Supplies"],
        }
    )
    lines = supplier_name_variants_report(df)
    assert "1 of 2" in lines[0]
    assert any("1000" in line for line in lines[1:])


def test_duplicate_rows_report_counts_exact_duplicates() -> None:
    df = pd.DataFrame({"a": [1, 1, 2], "b": ["x", "x", "y"]})
    lines = duplicate_rows_report(df)
    assert "2 rows" in lines[0]


def test_build_report_end_to_end_surfaces_known_issues() -> None:
    df = load_raw(FIXTURE)
    report = build_report(df, source=FIXTURE, raw_lines=raw_line_count(FIXTURE))

    assert "Logical rows parsed: 20" in report
    assert "embedded newline" in report
    assert "variants" in report
    assert "full-row duplicates" in report
    assert "thousands separator" in report
    assert "mixed/unrecognized date formats" in report
    assert "parentheses for negative amounts" in report
    assert "mojibake" in report


def test_build_report_row_count_note_when_mismatch_has_no_newline_cause() -> None:
    df = pd.DataFrame(
        {
            "Supplier Code": ["1", "2"],
            "Supplier Name": ["A", "B"],
            "Unit Price": ["$1.00", "$2.00"],
            "Total Price": ["$1.00", "$2.00"],
        }
    )
    report = build_report(df, source=Path("dummy.csv"), raw_lines=5)
    assert "cause not identified" in report
