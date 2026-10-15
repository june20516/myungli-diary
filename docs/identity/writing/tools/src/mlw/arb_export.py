"""ui 원고에서 앱 ARB 파일을 만듭니다. app은 이 파일을 가져가 화면 문구로 씁니다(D59 ⑤).

* 키 순서는 슬롯 id 순서, 그 안에서는 슬롯 명세의 키 순서입니다.
* `@<키>` 메타데이터(설명, 자리표시자 타입)는 기준 언어(ko) 파일에만 둡니다.
* 원고가 없는 키는 그 언어 파일에서 뺍니다. 앱은 기준 언어 문구로 대신합니다.
* glossary 이름 중 `ARB_TERM_CATEGORIES` 범주(지지, 날의 성격)도 ui 키 뒤에 냅니다. content 문장과 앱 화면이
  같은 이름을 쓰게 하기 위해서입니다(#143). 키는 용어 id의 lowerCamelCase입니다(`branch.in` → `branchIn`).
"""

import json
from collections.abc import Mapping, Sequence

import regex

from mlw.ia import is_ui_slot
from mlw.model import Entry, Finding, LoadError, ParamKind, Slot

TEMPLATE_LANG = "ko"
GENERATED_NOTE = "mlw gen-docs로 생성. 직접 고치지 않습니다 (원본 docs/identity/writing/content/<lang>/ui.yaml, glossary.yaml)"
PLACEHOLDER_TYPES: dict[str, str] = {"number": "int", "text": "String"}
GLOSSARY_SLOT = "glossary.value_name"
ARB_TERM_CATEGORIES = ("branch", "day_kind")
RULE_DUPLICATE_KEY = "arb.duplicate_key"
TERM_WORD_BOUNDARY = regex.compile(r"[._]")


def _placeholders(params: Mapping[str, ParamKind]) -> dict[str, dict[str, str]]:
    return {name: {"type": PLACEHOLDER_TYPES.get(kind.kind, "String")} for name, kind in params.items()}


def _description(slot: Slot, ia_roles: Mapping[str, str]) -> str:
    role = ia_roles.get(slot.id)
    return f"{slot.id}: {role}" if role is not None else slot.where


def term_arb_key(term_id: str) -> str:
    """용어 id를 ARB 키로 바꿉니다. 점과 밑줄이 단어 경계입니다(`day_kind.yongsin_day` → `dayKindYongsinDay`)."""
    first, *rest = TERM_WORD_BOUNDARY.split(term_id)
    return first + "".join(word[:1].upper() + word[1:] for word in rest)


def _term_messages(slots: Mapping[str, Slot], texts: Mapping[tuple[str, str], str]) -> list[tuple[str, str, str]]:
    """ARB로 내보낼 glossary 이름입니다. (ARB 키, 용어 id, 문장)을 glossary 슬롯 키 순서대로 돌려줍니다."""
    glossary = slots.get(GLOSSARY_SLOT)
    if glossary is None:
        return []
    messages: list[tuple[str, str, str]] = []
    for term_id in glossary.keys:
        text = texts.get((GLOSSARY_SLOT, term_id))
        if term_id.split(".")[0] in ARB_TERM_CATEGORIES and text is not None:
            messages.append((term_arb_key(term_id), term_id, text))
    return messages


def render_arb(slots: Mapping[str, Slot], entries: Sequence[Entry], lang: str, ia_roles: Mapping[str, str]) -> str:
    """한 언어의 ARB 파일 내용입니다. 같은 입력이면 항상 같은 결과입니다."""
    texts = {(entry.slot, entry.key): entry.text for entry in entries if entry.lang == lang}
    arb: dict[str, object] = {"@@locale": lang, "@@x-generated": GENERATED_NOTE}
    for slot_id in sorted(slots):
        slot = slots[slot_id]
        if not is_ui_slot(slot):
            continue
        for key, params in slot.keys.items():
            text = texts.get((slot.id, key))
            if text is None:
                continue
            arb[key] = text
            if lang != TEMPLATE_LANG:
                continue
            meta: dict[str, object] = {"description": _description(slot, ia_roles)}
            if params:
                meta["placeholders"] = _placeholders(params)
            arb[f"@{key}"] = meta
    ui_keys = {key for slot in slots.values() if is_ui_slot(slot) for key in slot.keys}
    for key, term_id, text in _term_messages(slots, texts):
        if key in ui_keys:
            glossary = slots[GLOSSARY_SLOT]
            message = f"glossary 이름 '{term_id}'의 ARB 키 '{key}'가 ui 키와 겹칩니다"
            raise LoadError([Finding(glossary.file, glossary.line, RULE_DUPLICATE_KEY, "error", message)])
        arb[key] = text
        if lang == TEMPLATE_LANG:
            arb[f"@{key}"] = {"description": f"{GLOSSARY_SLOT}: {term_id}"}
    return json.dumps(arb, ensure_ascii=False, indent=2) + "\n"
