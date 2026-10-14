"""IA 대조 검사: 슬롯 명세가 IA 계약(`docs/ia/screens.json`)의 슬롯을 빠짐없이, 맞는 자리에 담는지 봅니다.

* ui 슬롯은 id가 IA 슬롯 id 그대로입니다. IA 밖 공용 문구(`ui.*`)는 `components`로 자리를 적습니다.
* content 슬롯은 `ia`나 `components`로 자리를 적습니다.
* ui 슬롯의 키 이름은 `lowerCamelCase(IA id)` 뒤에 숫자나 대문자로 시작하는 상태 이름을 붙일 수 있습니다(#90).
"""

import json
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

import regex

from mlw.model import Finding, LoadError, Severity, Slot

RULE_LOAD = "load.json"
RULE_UNKNOWN = "ia.unknown"
RULE_SOURCE = "ia.source"
RULE_UNCOVERED = "ia.uncovered"
RULE_UNPLACED = "ia.unplaced"
RULE_KEY_NAME = "ia.key_name"
RULE_EMPTY_KEYS = "slot.empty_keys"

UI_GROUP = "ui"
CONTENT_GROUP = "content"
WORD_BOUNDARY = regex.compile(r"[.\-]")
# 키 이름 뒤에 붙일 수 있는 접미사: 변주 번호 또는 상태 이름입니다.
KEY_SUFFIX = r"(?:[0-9]+|[A-Z][A-Za-z0-9]*)?"


@dataclass(frozen=True)
class Ia:
    # IA 슬롯 id -> source(`ui` 또는 `content`). 화면 순서를 지킵니다.
    slots: dict[str, str]
    # IA 슬롯 id -> 한 줄 역할
    roles: dict[str, str]
    components: frozenset[str]
    file: Path


def _load_error(path: Path, message: str) -> LoadError:
    return LoadError([Finding(path, 1, RULE_LOAD, "error", message)])


def load_ia(path: Path) -> Ia:
    """IA 계약 파일을 읽습니다. 없거나 구조가 맞지 않으면 `LoadError`입니다."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise _load_error(path, f"IA 파일을 읽을 수 없습니다: {error}") from error
    try:
        slots = {
            slot["id"]: slot["source"] for screen in data["screens"] for slot in screen.get("slots", [])
        }
        roles = {slot["id"]: slot.get("role", "") for screen in data["screens"] for slot in screen.get("slots", [])}
        components = frozenset(component["id"] for component in data["components"])
    except (KeyError, TypeError) as error:
        raise _load_error(path, f"IA 파일 구조가 맞지 않습니다: {error}") from error
    return Ia(slots=slots, roles=roles, components=components, file=path)


def camel(ia_id: str) -> str:
    """IA 슬롯 id를 lowerCamelCase로 바꿉니다. 점과 하이픈이 단어 경계입니다."""
    first, *rest = WORD_BOUNDARY.split(ia_id)
    return first + "".join(word[:1].upper() + word[1:] for word in rest)


def is_ui_slot(slot: Slot) -> bool:
    return slot.file.parent.name == UI_GROUP


def placements(slot: Slot, ia: Ia) -> tuple[str, ...]:
    """슬롯이 담는 IA 슬롯 id입니다. IA id를 그대로 쓰는 ui 슬롯은 자기 자리입니다."""
    if is_ui_slot(slot) and slot.id in ia.slots:
        return (slot.id, *slot.ia)
    return slot.ia


def _finding(slot: Slot, rule_id: str, message: str, severity: Severity = "error") -> Finding:
    return Finding(slot.file, slot.line, rule_id, severity, message)


def _slot_findings(slot: Slot, ia: Ia) -> list[Finding]:
    findings: list[Finding] = []
    group = UI_GROUP if is_ui_slot(slot) else CONTENT_GROUP
    for ia_id in slot.ia:
        if ia_id not in ia.slots:
            findings.append(_finding(slot, RULE_UNKNOWN, f"ia의 '{ia_id}'가 IA에 없습니다"))
        elif ia.slots[ia_id] != group:
            message = f"{group} 슬롯이 {ia.slots[ia_id]} IA 슬롯 '{ia_id}'를 담을 수 없습니다"
            findings.append(_finding(slot, RULE_SOURCE, message))
    for component in slot.components:
        if component not in ia.components:
            findings.append(_finding(slot, RULE_UNKNOWN, f"components의 '{component}'가 IA에 없습니다"))
    own_id = is_ui_slot(slot) and slot.id in ia.slots
    if own_id and ia.slots[slot.id] != UI_GROUP:
        message = f"ui 슬롯 id '{slot.id}'는 {ia.slots[slot.id]} IA 슬롯입니다"
        findings.append(_finding(slot, RULE_SOURCE, message))
    if not own_id and not slot.ia and not slot.components:
        findings.append(_finding(slot, RULE_UNPLACED, f"슬롯 '{slot.id}'의 자리(ia·components)가 없습니다"))
    if own_id:
        pattern = regex.compile(regex.escape(camel(slot.id)) + KEY_SUFFIX)
        for key in slot.keys:
            if pattern.fullmatch(key) is None:
                message = f"키 '{key}'는 '{camel(slot.id)}' 뒤에 숫자나 대문자로 시작하는 상태 이름만 붙일 수 있습니다"
                findings.append(_finding(slot, RULE_KEY_NAME, message))
    if not slot.keys:
        message = f"슬롯 '{slot.id}'에 키가 없습니다. 상대 자료를 기다리는 틀이면 그대로 둡니다"
        findings.append(_finding(slot, RULE_EMPTY_KEYS, message, "warn"))
    return findings


def check_ia(slots: Mapping[str, Slot], ia: Ia) -> list[Finding]:
    """IA 대조 문제를 모두 돌려줍니다. 키 없는 슬롯만 warn이고 나머지는 error입니다."""
    findings = [finding for slot in slots.values() for finding in _slot_findings(slot, ia)]
    covered = {ia_id for slot in slots.values() for ia_id in placements(slot, ia)}
    for ia_id, source in ia.slots.items():
        if ia_id not in covered:
            message = f"IA {source} 슬롯 '{ia_id}'를 담는 writing 슬롯이 없습니다"
            findings.append(Finding(ia.file, 1, RULE_UNCOVERED, "error", message))
    return findings
