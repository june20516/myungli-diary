"""ui 원고에서 ARB를 만드는 테스트."""

import json
from pathlib import Path

from mlw.arb_export import GENERATED_NOTE, render_arb
from mlw.model import Entry, ParamKind, Slot

ROLES = {"today.event.summary": "오늘 일정 개수와 첫 일정"}


def make_slot(slot_id: str, group: str, keys: dict[str, dict[str, ParamKind]], where: str = "시험") -> Slot:
    return Slot(
        id=slot_id,
        where=where,
        purpose="info",
        types=(),
        variants=1,
        keys=keys,
        co_display=(),
        max_length={},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots") / group / "t.yaml",
    )


SUMMARY = make_slot(
    "today.event.summary",
    "ui",
    {"todayEventSummary": {"count": ParamKind("number"), "title": ParamKind("text")}, "todayEventSummaryDone": {}},
)
DEPTH = make_slot("ui.depth.surface", "ui", {"depthSurface": {}}, where="깊이 표면 단계 이름")
CONTENT = make_slot("daily.color", "content", {"color.gisin_day": {}})
SLOTS = {slot.id: slot for slot in (SUMMARY, DEPTH, CONTENT)}


def entry(slot: str, key: str, lang: str, text: str) -> Entry:
    return Entry(Path(f"content/{lang}/ui.yaml"), 1, slot, key, None, 1, lang, text)


ENTRIES = [
    entry("today.event.summary", "todayEventSummary", "ko", "오늘 일정 {count}개, 첫 일정은 {title}"),
    entry("today.event.summary", "todayEventSummaryDone", "ko", "오늘 일정이 모두 지났어요"),
    entry("ui.depth.surface", "depthSurface", "ko", "요약"),
    entry("daily.color", "color.gisin_day", "ko", "남색이 잘 맞아요."),
    entry("today.event.summary", "todayEventSummary", "en", "Events today: {count}. First: {title}"),
]


def test_render_arb_ko() -> None:
    assert json.loads(render_arb(SLOTS, ENTRIES, "ko", ROLES)) == {
        "@@locale": "ko",
        "@@x-generated": GENERATED_NOTE,
        "todayEventSummary": "오늘 일정 {count}개, 첫 일정은 {title}",
        "@todayEventSummary": {
            "description": "today.event.summary: 오늘 일정 개수와 첫 일정",
            "placeholders": {"count": {"type": "int"}, "title": {"type": "String"}},
        },
        "todayEventSummaryDone": "오늘 일정이 모두 지났어요",
        "@todayEventSummaryDone": {"description": "today.event.summary: 오늘 일정 개수와 첫 일정"},
        "depthSurface": "요약",
        "@depthSurface": {"description": "깊이 표면 단계 이름"},
    }


def test_render_arb_en_has_no_meta_and_skips_missing() -> None:
    assert json.loads(render_arb(SLOTS, ENTRIES, "en", ROLES)) == {
        "@@locale": "en",
        "@@x-generated": GENERATED_NOTE,
        "todayEventSummary": "Events today: {count}. First: {title}",
    }


def test_render_arb_is_stable_text() -> None:
    text = render_arb(SLOTS, ENTRIES, "ko", ROLES)
    assert text == render_arb(SLOTS, list(reversed(ENTRIES)), "ko", ROLES)
    assert text.endswith("}\n") and not text.endswith("\n\n")
    assert "\\u" not in text
    keys = list(json.loads(text))
    assert keys.index("depthSurface") > keys.index("todayEventSummaryDone")
