"""완결성 검사: 슬롯 명세 기준으로 원고가 빠짐없이, 허용된 범위 안에서 있는지 확인합니다.

키 x 언어 x 유형 x 변주가 모두 있는지, 원고의 키·유형·변주·매개변수가 명세 안에 있는지 봅니다.
"""

from collections import Counter
from collections.abc import Mapping, Sequence
from pathlib import Path

from google.protobuf.internal.enum_type_wrapper import EnumTypeWrapper

from mlw._gen.myungri.engine.v1 import engine_pb2
from mlw.model import Entry, Finding, Slot
from mlw.placeholders import parse

RULE_MISSING = "complete.missing"
RULE_UNKNOWN_SLOT = "complete.unknown_slot"
RULE_UNKNOWN_KEY = "complete.unknown_key"
RULE_UNKNOWN_LANG = "complete.unknown_lang"
RULE_BAD_TYPE = "complete.bad_type"
RULE_BAD_VARIANT = "complete.bad_variant"
RULE_DUPLICATE = "complete.duplicate"
RULE_UNKNOWN_PARAM = "complete.unknown_param"
RULE_UNKNOWN_CATEGORY = "complete.unknown_category"
RULE_UNSLOTTED_KEY = "complete.unslotted_key"

# 어느 슬롯에서나 쓸 수 있는 매개변수입니다(호칭).
ALWAYS_ALLOWED_PARAMS = frozenset({"name"})
MESSAGE_KEYS_FILE = Path("core/message_keys.json")
# proto enum이 아니라서 여기서 직접 정하는 십성 그룹 값입니다.
TEN_GOD_GROUPS: tuple[str, ...] = ("bigyeop", "siksang", "jaeseong", "gwanseong", "inseong")


def _enum_value_names(enum: EnumTypeWrapper) -> tuple[str, ...]:
    """`<ENUM>_UNSPECIFIED`를 빼고 접두어를 뗀 소문자 값 이름입니다."""
    names = list(enum.keys())
    prefix = names[0].removesuffix("UNSPECIFIED")
    return tuple(name.removeprefix(prefix).lower() for name in names[1:])


def glossary_values() -> dict[str, tuple[str, ...]]:
    """값 이름 사전의 범주별 값 목록입니다. `color`는 `element`와 같은 값 집합입니다."""
    elements = _enum_value_names(engine_pb2.Element)
    return {
        "element": elements,
        "color": elements,
        "stem": _enum_value_names(engine_pb2.Stem),
        "branch": _enum_value_names(engine_pb2.Branch),
        "ten_god": _enum_value_names(engine_pb2.TenGod),
        "ten_god_group": TEN_GOD_GROUPS,
        "direction8": _enum_value_names(engine_pb2.Direction8),
        "shinsal": _enum_value_names(engine_pb2.Shinsal),
        "day_kind": _enum_value_names(engine_pb2.DayKind),
        "relation": _enum_value_names(engine_pb2.RelationKind),
    }


def _entry_finding(entry: Entry, rule_id: str, message: str) -> Finding:
    return Finding(entry.file, entry.line, rule_id, "error", message)


def _check_placeholders(entry: Entry, slot: Slot, categories: frozenset[str]) -> list[Finding]:
    try:
        placeholders = parse(entry.text)
    except ValueError:
        # 문법 오류는 문장 단위 검사가 보고합니다.
        return []
    allowed = ALWAYS_ALLOWED_PARAMS | set(slot.keys[entry.key])
    findings: list[Finding] = []
    for placeholder in placeholders:
        if placeholder.name not in allowed:
            allowed_text = ", ".join(sorted(allowed))
            message = f"키 '{entry.key}'에 없는 매개변수 '{{{placeholder.name}}}'입니다. 허용: {allowed_text}"
            findings.append(_entry_finding(entry, RULE_UNKNOWN_PARAM, message))
        if placeholder.category is not None and placeholder.category not in categories:
            message = f"알 수 없는 범주 '{placeholder.category}'입니다. 허용: {', '.join(sorted(categories))}"
            findings.append(_entry_finding(entry, RULE_UNKNOWN_CATEGORY, message))
    return findings


def _check_entry(
    entry: Entry, slots: Mapping[str, Slot], langs: Sequence[str], categories: frozenset[str]
) -> tuple[list[Finding], bool]:
    """원고 하나를 검사합니다. 두 번째 값은 명세 안의 (슬롯, 키, 유형, 변주)인지 여부입니다."""
    slot = slots.get(entry.slot)
    if slot is None:
        return [_entry_finding(entry, RULE_UNKNOWN_SLOT, f"슬롯 '{entry.slot}'이(가) 명세에 없습니다")], False
    findings: list[Finding] = []
    if entry.lang not in langs:
        message = f"언어 '{entry.lang}'은(는) 허용되지 않습니다. 허용: {', '.join(langs)}"
        findings.append(_entry_finding(entry, RULE_UNKNOWN_LANG, message))
    placed = True
    if entry.key not in slot.keys:
        message = f"슬롯 '{slot.id}'에 없는 키 '{entry.key}'입니다"
        findings.append(_entry_finding(entry, RULE_UNKNOWN_KEY, message))
        placed = False
    if slot.types and entry.type not in slot.types:
        message = f"슬롯 '{slot.id}'의 유형은 {', '.join(slot.types)} 중 하나여야 합니다 (현재 {entry.type})"
        findings.append(_entry_finding(entry, RULE_BAD_TYPE, message))
        placed = False
    if not slot.types and entry.type is not None:
        message = f"슬롯 '{slot.id}'은(는) 유형을 적용하지 않습니다 (현재 {entry.type})"
        findings.append(_entry_finding(entry, RULE_BAD_TYPE, message))
        placed = False
    if entry.variant > slot.variants:
        message = f"슬롯 '{slot.id}'의 변주는 {slot.variants}개까지입니다 (현재 {entry.variant})"
        findings.append(_entry_finding(entry, RULE_BAD_VARIANT, message))
        placed = False
    if entry.key in slot.keys:
        findings.extend(_check_placeholders(entry, slot, categories))
    return findings, placed


def _missing_findings(
    slots: Mapping[str, Slot], present: set[tuple[str, str, str | None, int, str]], langs: Sequence[str]
) -> list[Finding]:
    findings: list[Finding] = []
    for slot in slots.values():
        for key in slot.keys:
            for lang in langs:
                for type_ in slot.types or (None,):
                    for variant in range(1, slot.variants + 1):
                        if (slot.id, key, type_, variant, lang) in present:
                            continue
                        type_text = type_ if type_ is not None else "유형 없음"
                        message = f"원고가 없습니다: 슬롯 {slot.id}, 키 {key}, 유형 {type_text}, 변주 {variant}, 언어 {lang}"
                        findings.append(Finding(slot.file, slot.line, RULE_MISSING, "error", message))
    return findings


def check_completeness(
    slots: Mapping[str, Slot],
    entries: Sequence[Entry],
    message_keys: Sequence[str],
    langs: Sequence[str],
) -> list[Finding]:
    """완결성 문제를 모두 돌려줍니다. 모두 `error`입니다."""
    categories = frozenset(glossary_values())
    findings: list[Finding] = []
    present: set[tuple[str, str, str | None, int, str]] = set()
    seen: Counter[tuple[str, str, str | None, int, str]] = Counter()
    for entry in entries:
        entry_findings, placed = _check_entry(entry, slots, langs, categories)
        findings.extend(entry_findings)
        if not placed:
            continue
        identity = (entry.slot, entry.key, entry.type, entry.variant, entry.lang)
        seen[identity] += 1
        if seen[identity] > 1:
            message = f"같은 원고가 중복됩니다: 슬롯 {entry.slot}, 키 {entry.key}, 유형 {entry.type}, 변주 {entry.variant}"
            findings.append(_entry_finding(entry, RULE_DUPLICATE, message))
        present.add(identity)
    findings.extend(_missing_findings(slots, present, langs))
    slotted_keys = {key for slot in slots.values() for key in slot.keys}
    for key in message_keys:
        if key not in slotted_keys:
            message = f"메시지 키 '{key}'를 담는 슬롯이 없습니다"
            findings.append(Finding(MESSAGE_KEYS_FILE, 1, RULE_UNSLOTTED_KEY, "error", message))
    return findings
