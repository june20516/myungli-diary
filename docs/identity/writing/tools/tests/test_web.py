"""웹 페이지 원고 테스트(#1329, D146)."""

import json
from pathlib import Path

from mlw.model import Entry, ParamKind, Slot
from mlw.web import is_web_slot, render_web, render_web_files


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
        file=Path("slots") / group / "landing.yaml",
    )


def make_entry(slot: str, key: str, lang: str, text: str) -> Entry:
    return Entry(Path(f"content/{lang}/web.yaml"), 1, slot, key, None, 1, lang, text)


SLOTS = {
    slot.id: slot
    for slot in (
        make_slot("web-landing.hero.tagline", "web", ("heroTagline",)),
        make_slot("web-landing.shots.alt", "web", ("today", "calendar")),
        make_slot("store.subtitle", "store", ("subtitle",)),
    )
}


def test_is_web_slot_uses_directory() -> None:
    assert is_web_slot(SLOTS["web-landing.hero.tagline"])
    assert not is_web_slot(SLOTS["store.subtitle"])


def test_render_web_keeps_spec_order_and_only_web_slots() -> None:
    entries = [
        make_entry("web-landing.shots.alt", "calendar", "ko", "달력"),
        make_entry("web-landing.shots.alt", "today", "ko", "오늘"),
        make_entry("web-landing.hero.tagline", "heroTagline", "ko", "소개"),
        make_entry("web-landing.hero.tagline", "heroTagline", "en", "Intro"),
        make_entry("store.subtitle", "subtitle", "ko", "스토어는 빠짐"),
    ]
    page = json.loads(render_web(SLOTS, entries, "ko"))
    assert page == {
        "web-landing.hero.tagline": {"heroTagline": "소개"},
        "web-landing.shots.alt": {"today": "오늘", "calendar": "달력"},
    }
    assert list(page["web-landing.shots.alt"]) == ["today", "calendar"]


def test_render_web_files_one_per_language() -> None:
    entries = [make_entry("web-landing.hero.tagline", "heroTagline", "ja", "紹介")]
    files = render_web_files(SLOTS, entries)
    assert list(files) == ["web/ko.json", "web/en.json", "web/ja.json"]
    assert json.loads(files["web/ja.json"]) == {"web-landing.hero.tagline": {"heroTagline": "紹介"}}
    assert files["web/ko.json"] == "{}\n"
    assert "紹介" in files["web/ja.json"]  # ensure_ascii 없이 사람이 읽을 수 있게
