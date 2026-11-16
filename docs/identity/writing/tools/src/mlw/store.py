"""스토어 등록정보 원고(#1201, D133): App Store와 Google Play에 올리는 소개 문구와 스크린샷 위 글.

슬롯은 `slots/store/`, 원고는 `content/<lang>/store.yaml`에 둡니다. 앱 화면 밖이라 IA 대조, ARB,
하루와 한 주 묶음 검사에서 빠지고, 문장 검사와 완결성 검사는 받습니다. `mlw gen-docs`가 지휘의 업로드용
`generated/store/listing.json`(언어 → 슬롯 → 키 → 글)을 만듭니다.
"""

import json
from collections.abc import Mapping, Sequence

from mlw.model import LANGS, Entry, Slot

STORE_GROUP = "store"
LISTING_FILE = "store/listing.json"


def is_store_slot(slot: Slot) -> bool:
    return slot.file.parent.name == STORE_GROUP


def render_listing(slots: Mapping[str, Slot], entries: Sequence[Entry]) -> str:
    """언어 → 슬롯 → 키 → 글인 JSON입니다. 순서는 언어 목록, 슬롯 명세 순서, 슬롯의 키 순서입니다."""
    texts = {(entry.lang, entry.slot, entry.key): entry.text for entry in entries}
    listing: dict[str, dict[str, dict[str, str]]] = {}
    for lang in LANGS:
        by_slot: dict[str, dict[str, str]] = {}
        for slot in slots.values():
            if not is_store_slot(slot):
                continue
            by_key = {key: texts[(lang, slot.id, key)] for key in slot.keys if (lang, slot.id, key) in texts}
            if by_key:
                by_slot[slot.id] = by_key
        listing[lang] = by_slot
    return json.dumps(listing, ensure_ascii=False, indent=2) + "\n"
