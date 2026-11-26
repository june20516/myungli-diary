"""버전과 그 버전이 가리키는 산출물 해시를 함께 기록하고 대조한다 (spec 12).

기록 파일 한 개는 `version=<값>`, `sha256=<해시>` 두 줄이다.
산출물(회귀 스냅샷, 엔진 응답 표면)이 바뀌었는데 버전이 그대로면 실패시키고,
갱신 모드로도 그 실패를 우회할 수 없게 한다.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class VersionRecord:
    version: str
    sha256: str


@dataclass(frozen=True)
class RecordRule:
    """기록 하나의 안내 문구. bump_message는 버전을 올려야 할 때, update_hint는 기록을 다시 쓰는 방법."""

    file_name: str
    bump_message: str
    update_hint: str


def format_record(record: VersionRecord) -> str:
    return f"version={record.version}\nsha256={record.sha256}\n"


def parse_record(text: str, rule: RecordRule) -> VersionRecord:
    values = dict(line.split("=", 1) for line in text.splitlines() if "=" in line)
    missing = [key for key in ("version", "sha256") if key not in values]
    if missing:
        raise ValueError(f"{rule.file_name}에 {', '.join(missing)} 항목이 없습니다. {rule.update_hint}")
    return VersionRecord(version=values["version"], sha256=values["sha256"])


def _needs_bump(recorded: VersionRecord, current: VersionRecord) -> bool:
    return recorded.sha256 != current.sha256 and recorded.version == current.version


def check_record(recorded: VersionRecord, current: VersionRecord, rule: RecordRule) -> str | None:
    """어긋나면 실패 메시지, 맞으면 None."""
    if _needs_bump(recorded, current):
        return f"{rule.bump_message} {rule.update_hint}"
    if recorded != current:
        return f"버전 또는 해시가 {rule.file_name} 기록과 다릅니다. {rule.update_hint}"
    return None


def decide_update(recorded: VersionRecord | None, current: VersionRecord, rule: RecordRule) -> str | None:
    """갱신 모드에서 기록을 새로 써도 되는지 본다. 막아야 하면 실패 메시지, 써도 되면 None."""
    if recorded is not None and _needs_bump(recorded, current):
        return f"{rule.bump_message} {rule.update_hint}"
    return None


def verify_record(record_file: Path, current: VersionRecord, rule: RecordRule, update: bool) -> str | None:
    """기록 파일과 현재 값을 대조한다. update면 막을 이유가 없을 때 기록을 먼저 다시 쓴다.

    문제가 있으면 실패 메시지, 없으면 None.
    """
    recorded = parse_record(record_file.read_text(), rule) if record_file.exists() else None
    if update:
        blocked = decide_update(recorded, current, rule)
        if blocked is not None:
            return blocked
        record_file.write_text(format_record(current))
        return None
    if recorded is None:
        return f"{rule.file_name}가 없습니다. {rule.update_hint}"
    return check_record(recorded, current, rule)
