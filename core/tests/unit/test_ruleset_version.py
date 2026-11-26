"""스냅샷 변경과 RULESET_VERSION 연동 (spec 12, 13.7).

스냅샷이 바뀌면 출력이 바뀐 것이므로 RULESET_VERSION을 올려야 한다.
기록 파일 tests/snapshots/RULESET_HASH는 `UPDATE_RULESET_HASH=1 uv run pytest tests/unit/test_ruleset_version.py`로 갱신한다.
"""

import hashlib
import os
from pathlib import Path

from version_record import RecordRule, VersionRecord, verify_record

from myungli_engine.version import RULESET_VERSION

SNAPSHOT_DIR = Path(__file__).parent.parent / "snapshots" / "__snapshots__"
RECORD_FILE = Path(__file__).parent.parent / "snapshots" / "RULESET_HASH"
UPDATE_ENV = "UPDATE_RULESET_HASH"
RULE = RecordRule(
    file_name=RECORD_FILE.name,
    bump_message="스냅샷이 바뀌었으면 version.RULESET_VERSION을 올리세요.",
    update_hint=f"기록 갱신: `{UPDATE_ENV}=1 uv run pytest tests/unit/test_ruleset_version.py`",
)


def snapshot_hash(directory: Path) -> str:
    """파일 이름순으로 상대 경로와 바이트를 SHA-256에 먹인다."""
    digest = hashlib.sha256()
    for path in sorted(p for p in directory.rglob("*.ambr") if p.is_file()):
        digest.update(path.relative_to(directory).as_posix().encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def test_snapshots_match_recorded_ruleset_version() -> None:
    current = VersionRecord(version=RULESET_VERSION, sha256=snapshot_hash(SNAPSHOT_DIR))
    problem = verify_record(RECORD_FILE, current, RULE, update=os.environ.get(UPDATE_ENV) == "1")
    assert problem is None, problem


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
