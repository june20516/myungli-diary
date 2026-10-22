"""ui 원고에서 ARB를 만드는 테스트."""

import json
from pathlib import Path

import pytest

from mlw.arb_export import GENERATED_NOTE, render_arb, term_arb_key
from mlw.model import Entry, LoadError, ParamKind, Slot

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


GLOSSARY = make_slot("glossary.value_name", "content", {"element.wood": {}, "branch.in": {}, "day_kind.gwiin_day": {}})
TERM_ENTRIES = [
    entry("glossary.value_name", "element.wood", "ko", "목"),
    entry("glossary.value_name", "branch.in", "ko", "인"),
    entry("glossary.value_name", "day_kind.gwiin_day", "ko", "귀인의 날"),
    entry("glossary.value_name", "day_kind.gwiin_day", "en", "Helper day"),
]


def test_term_arb_key_is_lower_camel_case() -> None:
    assert term_arb_key("branch.in") == "branchIn"
    assert term_arb_key("day_kind.yongsin_day") == "dayKindYongsinDay"


def test_render_arb_exports_branch_and_day_kind_names() -> None:
    arb = json.loads(render_arb({**SLOTS, GLOSSARY.id: GLOSSARY}, [*ENTRIES, *TERM_ENTRIES], "ko", ROLES))
    assert arb["branchIn"] == "인"
    assert arb["@branchIn"] == {"description": "glossary.value_name: branch.in"}
    assert arb["dayKindGwiinDay"] == "귀인의 날"
    assert "elementWood" not in arb
    assert list(arb)[-4:] == ["branchIn", "@branchIn", "dayKindGwiinDay", "@dayKindGwiinDay"]


def test_render_arb_skips_term_names_missing_in_language() -> None:
    arb = json.loads(render_arb({**SLOTS, GLOSSARY.id: GLOSSARY}, [*ENTRIES, *TERM_ENTRIES], "en", ROLES))
    assert "branchIn" not in arb
    assert arb["dayKindGwiinDay"] == "Helper day"


def test_render_arb_rejects_term_key_used_by_ui_slot() -> None:
    clash = make_slot("ui.birth.option", "ui", {"branchIn": {}})
    slots = {**SLOTS, GLOSSARY.id: GLOSSARY, clash.id: clash}
    with pytest.raises(LoadError):
        render_arb(slots, [*ENTRIES, *TERM_ENTRIES, entry("ui.birth.option", "branchIn", "ko", "인")], "ko", ROLES)


def test_render_arb_rejects_term_key_even_without_ui_manuscript() -> None:
    clash = make_slot("ui.birth.option", "ui", {"branchIn": {}})
    with pytest.raises(LoadError):
        render_arb({**SLOTS, GLOSSARY.id: GLOSSARY, clash.id: clash}, [*ENTRIES, *TERM_ENTRIES], "ko", ROLES)


def test_render_arb_exports_direction_names() -> None:
    glossary = make_slot("glossary.value_name", "content", {"direction8.n": {}, "direction8.nw": {}})
    entries = [*ENTRIES, entry("glossary.value_name", "direction8.n", "ko", "북"), entry("glossary.value_name", "direction8.nw", "ko", "북서")]
    arb = json.loads(render_arb({**SLOTS, glossary.id: glossary}, entries, "ko", ROLES))
    assert (arb["direction8N"], arb["direction8Nw"]) == ("북", "북서")


NOTICE = make_slot("ui.notice", "ui", {"notice": {"title": ParamKind("text")}})


def test_render_arb_expands_josa_ko() -> None:
    entries = [entry("ui.notice", "notice", "ko", "{title}(이)가 내일이에요")]
    arb = json.loads(render_arb({NOTICE.id: NOTICE}, entries, "ko", {}))
    assert arb["notice"] == "{title}{titleJosa, select, final{이} rieul{이} none{가} other{이(가)}} 내일이에요"
    assert arb["@notice"]["placeholders"] == {
        "title": {"type": "String"},
        "titleJosa": {"type": "String", "description": "app이 josaClass(title)로 채움"},
    }


def test_render_arb_josa_not_in_en() -> None:
    entries = [entry("ui.notice", "notice", "en", "{title} is tomorrow")]
    arb = json.loads(render_arb({NOTICE.id: NOTICE}, entries, "en", {}))
    assert arb["notice"] == "{title} is tomorrow"
    assert "@notice" not in arb
