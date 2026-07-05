"""Unit tests for pdp.pipeline.load's header validation (no database needed)."""

from pathlib import Path

import pytest

from pdp.pipeline.load import COLUMN_MAPPING, HeaderMismatchError, assert_header_matches

FIXTURE = Path(__file__).resolve().parents[2] / "fixtures" / "sample_purchase_orders.csv"


def test_column_mapping_has_32_unique_source_and_dest_names() -> None:
    assert len(COLUMN_MAPPING) == 32
    assert len({source for source, _ in COLUMN_MAPPING}) == 32
    assert len({dest for _, dest in COLUMN_MAPPING}) == 32


def test_assert_header_matches_passes_for_known_good_fixture() -> None:
    assert_header_matches(FIXTURE)  # does not raise


def test_assert_header_matches_rejects_reordered_header(tmp_path: Path) -> None:
    header = [source for source, _ in COLUMN_MAPPING]
    header[0], header[1] = header[1], header[0]
    bad_csv = tmp_path / "bad_header.csv"
    bad_csv.write_text(",".join(header) + "\n", encoding="utf-8")

    with pytest.raises(HeaderMismatchError):
        assert_header_matches(bad_csv)


def test_assert_header_matches_rejects_missing_column(tmp_path: Path) -> None:
    header = [source for source, _ in COLUMN_MAPPING][:-1]  # drop the last column
    bad_csv = tmp_path / "short_header.csv"
    bad_csv.write_text(",".join(header) + "\n", encoding="utf-8")

    with pytest.raises(HeaderMismatchError):
        assert_header_matches(bad_csv)
