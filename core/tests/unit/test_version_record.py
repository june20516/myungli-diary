"""버전과 해시 기록의 대조 규칙 (tools/version_record.py)."""

from pathlib import Path

import pytest
from version_record import (
    RecordRule,
    VersionRecord,
    check_record,
    decide_update,
    format_record,
    parse_record,
    verify_record,
)

RULE = RecordRule(file_name="HASH", bump_message="버전을 올리세요.", update_hint="UPDATE=1")


def record(version: str, sha: str) -> VersionRecord:
    return VersionRecord(version=version, sha256=sha)


@pytest.mark.parametrize(
    ("recorded", "current", "blocked"),
    [
        (None, record("1", "aaa"), False),
        (record("1", "aaa"), record("1", "aaa"), False),
        (record("1", "aaa"), record("1", "bbb"), True),
        (record("1", "aaa"), record("2", "bbb"), False),
        (record("1", "aaa"), record("2", "aaa"), False),
    ],
)
def test_update_mode_cannot_bypass_version_bump(
    recorded: VersionRecord | None, current: VersionRecord, blocked: bool
) -> None:
    problem = decide_update(recorded, current, RULE)
    assert (problem is not None) is blocked
    if problem is not None:
        assert "버전을 올리세요" in problem


@pytest.mark.parametrize(
    ("recorded", "current", "expected_fragment"),
    [
        (record("1", "aaa"), record("1", "aaa"), None),
        (record("1", "aaa"), record("1", "bbb"), "버전을 올리세요"),
        (record("1", "aaa"), record("2", "bbb"), "UPDATE=1"),
        (record("1", "aaa"), record("2", "aaa"), "UPDATE=1"),
    ],
)
def test_check_record_decisions(
    recorded: VersionRecord, current: VersionRecord, expected_fragment: str | None
) -> None:
    problem = check_record(recorded, current, RULE)
    if expected_fragment is None:
        assert problem is None
    else:
        assert problem is not None
        assert expected_fragment in problem


def test_parse_record_reports_missing_key() -> None:
    with pytest.raises(ValueError, match="sha256"):
        parse_record("version=1\n", RULE)


def test_format_and_parse_round_trip() -> None:
    assert parse_record(format_record(record("0.2.0", "abc")), RULE) == record("0.2.0", "abc")


def test_verify_writes_record_in_update_mode(tmp_path: Path) -> None:
    path = tmp_path / "HASH"
    assert verify_record(path, record("1", "aaa"), RULE, update=True) is None
    assert verify_record(path, record("1", "aaa"), RULE, update=False) is None


def test_verify_refuses_update_without_bump(tmp_path: Path) -> None:
    path = tmp_path / "HASH"
    path.write_text(format_record(record("1", "aaa")))
    problem = verify_record(path, record("1", "bbb"), RULE, update=True)
    assert problem is not None and "버전을 올리세요" in problem
    assert parse_record(path.read_text(), RULE) == record("1", "aaa")


def test_verify_reports_missing_record(tmp_path: Path) -> None:
    problem = verify_record(tmp_path / "HASH", record("1", "aaa"), RULE, update=False)
    assert problem is not None and "HASH가 없습니다" in problem
