"""스토어 등록정보 원고 테스트(#1201, D133)."""

import json
from pathlib import Path

from mlw.model import Entry, ParamKind, Slot
from mlw.store import is_store_slot, render_listing


def make_slot(slot_id: str, group: str, keys: tuple[str, ...]) -> Slot:
    params: dict[str, dict[str, ParamKind]] = {key: {} for key in keys}
    return Slot(
        id=slot_id,
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys=params,
        co_display=(),
        max_length={},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots") / group / "listing.yaml",
    )


def make_entry(slot: str, key: str, lang: str, text: str) -> Entry:
    return Entry(Path(f"content/{lang}/store.yaml"), 1, slot, key, None, 1, lang, text)


def test_is_store_slot_uses_directory() -> None:
    assert is_store_slot(make_slot("store.subtitle", "store", ("subtitle",)))
    assert not is_store_slot(make_slot("ui.x", "ui", ("x",)))


def test_listing_groups_by_language_then_slot_in_spec_order() -> None:
    """지휘가 API로 올릴 수 있게 언어, 슬롯, 키 순서로 나눕니다. 순서는 슬롯 명세 순서입니다."""
    slots = {
        slot.id: slot
        for slot in (
            make_slot("store.subtitle", "store", ("subtitle",)),
            make_slot("store.screenshot.caption", "store", ("today", "evidence")),
            make_slot("daily.color", "content", ("daily.color",)),
        )
    }
    entries = [
        make_entry("store.screenshot.caption", "evidence", "ko", "둘째\n줄"),
        make_entry("store.screenshot.caption", "today", "ko", "첫째"),
        make_entry("store.subtitle", "subtitle", "en", "Sub"),
        make_entry("store.subtitle", "subtitle", "ko", "부제"),
        make_entry("daily.color", "daily.color", "ko", "콘텐츠는 빠짐"),
    ]
    listing = json.loads(render_listing(slots, entries))
    assert list(listing) == ["ko", "en", "ja"]
    assert listing["ko"] == {
        "store.subtitle": {"subtitle": "부제"},
        "store.screenshot.caption": {"today": "첫째", "evidence": "둘째\n줄"},
    }
    assert list(listing["ko"]["store.screenshot.caption"]) == ["today", "evidence"]
    assert listing["en"] == {"store.subtitle": {"subtitle": "Sub"}}
    assert listing["ja"] == {}


def test_listing_is_stable_text() -> None:
    slots = {"store.subtitle": make_slot("store.subtitle", "store", ("subtitle",))}
    entries = [make_entry("store.subtitle", "subtitle", "ko", "부제")]
    text = render_listing(slots, entries)
    assert text.endswith("\n")
    assert text == render_listing(slots, list(reversed(entries)))
    assert "부제" in text  # ensure_ascii 없이 사람이 읽을 수 있게
