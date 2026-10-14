"""ui 원고에서 앱 ARB 파일을 만듭니다. app은 이 파일을 가져가 화면 문구로 씁니다(D59 ⑤).

* 키 순서는 슬롯 id 순서, 그 안에서는 슬롯 명세의 키 순서입니다.
* `@<키>` 메타데이터(설명, 자리표시자 타입)는 기준 언어(ko) 파일에만 둡니다.
* 원고가 없는 키는 그 언어 파일에서 뺍니다. 앱은 기준 언어 문구로 대신합니다.
"""

import json
from collections.abc import Mapping, Sequence

from mlw.ia import is_ui_slot
from mlw.model import Entry, ParamKind, Slot

TEMPLATE_LANG = "ko"
GENERATED_NOTE = "mlw gen-docs로 생성. 직접 고치지 않습니다 (원본 docs/identity/writing/content/<lang>/ui.yaml)"
PLACEHOLDER_TYPES: dict[str, str] = {"number": "int", "text": "String"}


def _placeholders(params: Mapping[str, ParamKind]) -> dict[str, dict[str, str]]:
    return {name: {"type": PLACEHOLDER_TYPES.get(kind.kind, "String")} for name, kind in params.items()}


def _description(slot: Slot, ia_roles: Mapping[str, str]) -> str:
    role = ia_roles.get(slot.id)
    return f"{slot.id}: {role}" if role is not None else slot.where


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
    return json.dumps(arb, ensure_ascii=False, indent=2) + "\n"
