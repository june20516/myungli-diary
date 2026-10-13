"""스냅샷 변경과 RULESET_VERSION 연동 (spec 12, 13.7).

스냅샷이 바뀌면 출력이 바뀐 것이므로 RULESET_VERSION을 올려야 한다.
기록 파일 tests/snapshots/RULESET_HASH는 `UPDATE_RULESET_HASH=1 uv run pytest tests/unit/test_ruleset_version.py`로 갱신한다.
"""

import hashlib
import os
from pathlib import Path

import pytest

from myungli_engine.version import RULESET_VERSION

SNAPSHOT_DIR = Path(__file__).parent.parent / "snapshots" / "__snapshots__"
RECORD_FILE = Path(__file__).parent.parent / "snapshots" / "RULESET_HASH"
UPDATE_ENV = "UPDATE_RULESET_HASH"

BUMP_MESSAGE = "스냅샷이 바뀌었으면 version.RULESET_VERSION을 올리세요."
UPDATE_HINT = f"기록 갱신: `{UPDATE_ENV}=1 uv run pytest tests/unit/test_ruleset_version.py`"


def snapshot_hash(directory: Path) -> str:
    """파일 이름순으로 상대 경로와 바이트를 SHA-256에 먹인다."""
    digest = hashlib.sha256()
    for path in sorted(p for p in directory.rglob("*.ambr") if p.is_file()):
        digest.update(path.relative_to(directory).as_posix().encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def format_record(version: str, sha256: str) -> str:
    return f"version={version}\nsha256={sha256}\n"


def parse_record(text: str) -> tuple[str, str]:
    values = dict(line.split("=", 1) for line in text.splitlines() if "=" in line)
    missing = [key for key in ("version", "sha256") if key not in values]
    if missing:
        raise ValueError(f"{RECORD_FILE.name}에 {', '.join(missing)} 항목이 없습니다. {UPDATE_HINT}")
    return values["version"], values["sha256"]


def check_record(recorded: tuple[str, str], current_version: str, current_hash: str) -> str | None:
    """어긋나면 실패 메시지, 맞으면 None."""
    recorded_version, recorded_hash = recorded
    if recorded_hash != current_hash and recorded_version == current_version:
        return f"{BUMP_MESSAGE} {UPDATE_HINT}"
    if (recorded_hash, recorded_version) != (current_hash, current_version):
        return f"버전 또는 스냅샷이 기록과 다릅니다. {UPDATE_HINT}"
    return None


def decide_update(recorded: tuple[str, str] | None, current_version: str, current_hash: str) -> str | None:
    """갱신 모드에서 기록을 새로 써도 되는지 본다. 막아야 하면 실패 메시지, 써도 되면 None.

    스냅샷이 바뀌었는데 버전이 그대로면 갱신으로 우회할 수 없다 (spec 12).
    """
    if recorded is None:
        return None
    recorded_version, recorded_hash = recorded
    if recorded_hash != current_hash and recorded_version == current_version:
        return f"{BUMP_MESSAGE} {UPDATE_HINT}"
    return None


def test_snapshots_match_recorded_ruleset_version() -> None:
    current_hash = snapshot_hash(SNAPSHOT_DIR)
    recorded = parse_record(RECORD_FILE.read_text()) if RECORD_FILE.exists() else None
    if os.environ.get(UPDATE_ENV) == "1":
        blocked = decide_update(recorded, RULESET_VERSION, current_hash)
        assert blocked is None, blocked
        RECORD_FILE.write_text(format_record(RULESET_VERSION, current_hash))
        recorded = (RULESET_VERSION, current_hash)
    assert recorded is not None, f"{RECORD_FILE.name}가 없습니다. 스냅샷을 만든 뒤 기록하세요. {UPDATE_HINT}"
    problem = check_record(recorded, RULESET_VERSION, current_hash)
    assert problem is None, problem


@pytest.mark.parametrize(
    ("recorded", "version", "sha", "blocked"),
    [
        (None, "1", "aaa", False),
        (("1", "aaa"), "1", "aaa", False),
        (("1", "aaa"), "1", "bbb", True),
        (("1", "aaa"), "2", "bbb", False),
        (("1", "aaa"), "2", "aaa", False),
    ],
)
def test_update_mode_cannot_bypass_version_bump(
    recorded: tuple[str, str] | None, version: str, sha: str, blocked: bool
) -> None:
    problem = decide_update(recorded, version, sha)
    assert (problem is not None) is blocked
    if problem is not None:
        assert "version.RULESET_VERSION을 올리세요" in problem


def test_parse_record_reports_missing_key() -> None:
    with pytest.raises(ValueError, match="sha256"):
        parse_record("version=1\n")


def test_hash_ignores_non_snapshot_files(tmp_path: Path) -> None:
    (tmp_path / "a.ambr").write_text("one")
    before = snapshot_hash(tmp_path)
    (tmp_path / ".DS_Store").write_text("junk")
    assert snapshot_hash(tmp_path) == before


def test_hash_changes_when_snapshot_content_changes(tmp_path: Path) -> None:
    (tmp_path / "a.ambr").write_text("one")
    before = snapshot_hash(tmp_path)
    (tmp_path / "a.ambr").write_text("two")
    assert snapshot_hash(tmp_path) != before


def test_hash_changes_when_snapshot_file_renamed(tmp_path: Path) -> None:
    (tmp_path / "a.ambr").write_text("one")
    before = snapshot_hash(tmp_path)
    (tmp_path / "a.ambr").rename(tmp_path / "b.ambr")
    assert snapshot_hash(tmp_path) != before


@pytest.mark.parametrize(
    ("recorded", "version", "sha", "expected_fragment"),
    [
        (("1", "aaa"), "1", "aaa", None),
        (("1", "aaa"), "1", "bbb", "version.RULESET_VERSION을 올리세요"),
        (("1", "aaa"), "2", "bbb", UPDATE_ENV),
        (("1", "aaa"), "2", "aaa", UPDATE_ENV),
    ],
)
def test_check_record_decisions(
    recorded: tuple[str, str], version: str, sha: str, expected_fragment: str | None
) -> None:
    problem = check_record(recorded, version, sha)
    if expected_fragment is None:
        assert problem is None
    else:
        assert problem is not None
        assert expected_fragment in problem
