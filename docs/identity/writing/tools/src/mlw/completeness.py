"""완결성 검사: 슬롯 명세 기준으로 원고가 빠짐없이, 허용된 범위 안에서 있는지 확인합니다.

키 x 언어 x 유형 x 변주가 모두 있는지, 원고의 키·유형·변주·매개변수가 명세 안에 있는지 봅니다.
"""

from collections import Counter
from collections.abc import Mapping, Sequence
from pathlib import Path

from mlw.model import Entry, Finding, ParamKind, Slot
from mlw.placeholders import Placeholder, parse

RULE_MISSING = "complete.missing"
RULE_UNKNOWN_SLOT = "complete.unknown_slot"
RULE_UNKNOWN_KEY = "complete.unknown_key"
RULE_UNKNOWN_LANG = "complete.unknown_lang"
RULE_BAD_TYPE = "complete.bad_type"
RULE_BAD_VARIANT = "complete.bad_variant"
RULE_DUPLICATE = "complete.duplicate"
RULE_UNKNOWN_PARAM = "complete.unknown_param"
RULE_BAD_CATEGORY = "complete.bad_category"
RULE_UNRENDERABLE_PARAM = "complete.unrenderable_param"
RULE_UNSLOTTED_KEY = "complete.unslotted_key"
RULE_PARAM_MISMATCH = "complete.param_mismatch"

# 어느 슬롯에서나 쓸 수 있는 매개변수입니다(호칭). 범주를 붙이지 않습니다.
NAME_PARAM = "name"
MESSAGE_KEYS_FILE = Path("core/message_keys.json")


def _entry_finding(entry: Entry, rule_id: str, message: str) -> Finding:
    return Finding(entry.file, entry.line, rule_id, "error", message)


def _category_problem(placeholder: Placeholder, kind: ParamKind | None) -> str | None:
    """`{p:cat}`의 범주가 그 매개변수에 허용되지 않으면 이유를 돌려줍니다. `kind`가 None이면 호칭입니다."""
    if placeholder.category is None:
        return None
    if kind is not None and kind.kind == "glossary":
        if placeholder.category in kind.categories:
            return None
        allowed = ", ".join(kind.categories)
        return f"'{{{placeholder.name}}}'에 쓸 수 없는 범주 '{placeholder.category}'입니다. 허용: {allowed}"
    return f"'{{{placeholder.name}}}'에는 범주를 붙일 수 없습니다 (현재 '{placeholder.category}')"


def _check_placeholders(entry: Entry, slot: Slot) -> list[Finding]:
    try:
        placeholders = parse(entry.text)
    except ValueError:
        # 문법 오류는 문장 단위 검사가 보고합니다.
        return []
    params = slot.keys[entry.key]
    findings: list[Finding] = []
    for placeholder in placeholders:
        kind = params.get(placeholder.name)
        if placeholder.name != NAME_PARAM and kind is None:
            allowed_text = ", ".join(sorted({NAME_PARAM, *params}))
            message = f"키 '{entry.key}'에 없는 매개변수 '{{{placeholder.name}}}'입니다. 허용: {allowed_text}"
            findings.append(_entry_finding(entry, RULE_UNKNOWN_PARAM, message))
            continue
        if kind is not None and kind.kind == "none":
            message = f"'{{{placeholder.name}}}'은(는) 문장에 쓸 수 없는 값입니다(값 종류 none)"
            findings.append(_entry_finding(entry, RULE_UNRENDERABLE_PARAM, message))
            continue
        problem = _category_problem(placeholder, kind)
        if problem is not None:
            findings.append(_entry_finding(entry, RULE_BAD_CATEGORY, problem))
    return findings


def _check_entry(entry: Entry, slots: Mapping[str, Slot], langs: Sequence[str]) -> tuple[list[Finding], bool]:
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
        findings.extend(_check_placeholders(entry, slot))
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


def check_params(slots: Mapping[str, Slot], message_params: Mapping[str, Sequence[str]]) -> list[Finding]:
    """슬롯 명세 `params`가 core의 키별 매개변수(`core/message_params.json`)와 같은지 봅니다.

    `name`(호칭)은 엔진 매개변수가 아니라 비교하지 않습니다. 슬롯에 없는 키는 `complete.unslotted_key`가 맡습니다.
    """
    findings: list[Finding] = []
    for slot in slots.values():
        for key, params in slot.keys.items():
            if key not in message_params:
                continue
            core_only = sorted(set(message_params[key]) - set(params))
            spec_only = sorted(set(params) - set(message_params[key]))
            if not core_only and not spec_only:
                continue
            message = (
                f"메시지 키 '{key}'의 매개변수가 core와 다릅니다: "
                f"core에만 {core_only or '없음'}, 명세에만 {spec_only or '없음'}"
            )
            findings.append(Finding(slot.file, slot.line, RULE_PARAM_MISMATCH, "error", message))
    return findings


def check_completeness(
    slots: Mapping[str, Slot],
    entries: Sequence[Entry],
    message_keys: Sequence[str],
    langs: Sequence[str],
    message_params: Mapping[str, Sequence[str]] | None = None,
) -> list[Finding]:
    """완결성 문제를 모두 돌려줍니다. 모두 `error`입니다.

    `message_params`가 None이면 매개변수 대조(`check_params`)를 건너뜁니다.
    """
    findings: list[Finding] = []
    present: set[tuple[str, str, str | None, int, str]] = set()
    seen: Counter[tuple[str, str, str | None, int, str]] = Counter()
    for entry in entries:
        entry_findings, placed = _check_entry(entry, slots, langs)
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
    if message_params is not None:
        findings.extend(check_params(slots, message_params))
    return findings
