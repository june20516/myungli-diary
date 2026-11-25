"""웹 페이지 원고(#1329, D146): `myungli-diary.app` 랜딩처럼 web 단위가 내는 페이지의 문구.

슬롯은 `slots/web/`, 원고는 `content/<lang>/web.yaml`에 둡니다. IA는 `docs/ia/site.json`이고 슬롯은
`source: content`라 `ia`로 자리를 적습니다. server 시드(`slots/content/`만 읽음)와 ARB, 하루와 한 주
묶음 검사에서 빠지고, IA 대조, 문장 검사, 완결성 검사는 받습니다. `mlw gen-docs`가 web이 읽을
`generated/web/<lang>.json`(슬롯 → 키 → 글)을 만듭니다.
"""

import json
from collections.abc import Mapping, Sequence

from mlw.model import LANGS, Entry, Slot

WEB_GROUP = "web"
WEB_DIR = "web"


def is_web_slot(slot: Slot) -> bool:
    return slot.file.parent.name == WEB_GROUP


def web_file(lang: str) -> str:
    """생성 디렉터리 기준 언어별 웹 원고 파일 이름입니다."""
    return f"{WEB_DIR}/{lang}.json"


def render_web(slots: Mapping[str, Slot], entries: Sequence[Entry], lang: str) -> str:
    """한 언어의 슬롯 → 키 → 글 JSON입니다. 순서는 슬롯 명세 순서와 슬롯의 키 순서입니다."""
    texts = {(entry.slot, entry.key): entry.text for entry in entries if entry.lang == lang}
    by_slot: dict[str, dict[str, str]] = {}
    for slot in slots.values():
        if not is_web_slot(slot):
            continue
        by_key = {key: texts[(slot.id, key)] for key in slot.keys if (slot.id, key) in texts}
        if by_key:
            by_slot[slot.id] = by_key
    return json.dumps(by_slot, ensure_ascii=False, indent=2) + "\n"


def render_web_files(slots: Mapping[str, Slot], entries: Sequence[Entry]) -> dict[str, str]:
    """언어마다 `web/<lang>.json` 하나입니다."""
    return {web_file(lang): render_web(slots, entries, lang) for lang in LANGS}
