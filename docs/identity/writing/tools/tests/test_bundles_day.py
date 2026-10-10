"""화면·하루 묶음 검사 테스트."""

from collections.abc import Sequence
from pathlib import Path
from typing import cast

from mlw.bundles import DayKeys, assemble, check_days, check_limits, enumerate_days
from mlw.model import CountSelector, Entry, Limit, Scope, Slot

HEAD_KEY = "fortune.ordinary_day.siksang"
TAG_KEY = "fortune.tag.clash"
GUIDE_KEY = "guide.clash"
FILE = Path("content/ko/daily.yaml")


def make_entry(
    slot: str, key: str, text: str, line: int, type_: str | None = None, variant: int = 1
) -> Entry:
    return Entry(FILE, line, slot, key, type_, variant, "ko", text)


def make_limit(limit_id: str, count: CountSelector, max_value: int | None, scope: str = "screen") -> Limit:
    max_by_lang = {"ko": max_value, "en": max_value, "ja": max_value}
    return Limit(limit_id, "시험", cast(Scope, scope), count, max_by_lang, "error", 1)


def make_slot(slot_id: str, variants: int) -> Slot:
    return Slot(
        id=slot_id,
        where="시험",
        purpose="guide",
        types=(),
        variants=variants,
        keys={},
        co_display=(),
        max_length={"ko": None, "en": None, "ja": None},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={"good": [], "bad": []},
        line=1,
        file=Path("slots/content/daily.yaml"),
    )


def index(entries: Sequence[Entry]) -> dict[tuple[str, str, str], list[Entry]]:
    result: dict[tuple[str, str, str], list[Entry]] = {}
    for entry in entries:
        result.setdefault((entry.slot, entry.key, entry.lang), []).append(entry)
    return result


def sample_day() -> DayKeys:
    return DayKeys(
        head=HEAD_KEY,
        tag_sentence=TAG_KEY,
        guide=GUIDE_KEY,
        color="color.ordinary_day",
        direction="direction.day_kind.ordinary",
        number="number.ordinary_day",
        focus="focus_time.hap",
        tag_label="tag.clash",
    )


def test_enumerate_days_respects_engine_rules() -> None:
    days = list(enumerate_days())
    assert days
    assert len(days) == len(set(days))
    for day in days:
        kind = day.head.split(".")[1]
        group = day.head.split(".")[2]
        assert day.color == f"color.{kind}"
        assert day.number == f"number.{kind}"
        assert day.direction == f"direction.day_kind.{kind.removesuffix('_day')}"
        assert day.focus.startswith("focus_time.")
        if day.tag_sentence is None:
            assert day.tag_label is None
            assert day.guide == f"guide.ten_god.{group}"
            continue
        suffix = day.tag_sentence.removeprefix("fortune.tag.")
        assert day.guide == f"guide.{suffix}"
        assert day.tag_label == f"tag.{suffix}"
        if suffix == "gwiin_day":
            assert kind == "gwiin_day"
        if suffix == "yongsin_day":
            assert kind == "yongsin_day"


def test_enumerate_days_counts() -> None:
    days = list(enumerate_days())
    assert len(days) == (15 + 15 + 14 + 14) * 5 * 5
    assert {day.focus for day in days} == {
        "focus_time.fallback",
        "focus_time.gwiin",
        "focus_time.hap",
        "focus_time.huisin",
        "focus_time.yongsin",
    }


def test_name_twice_on_screen_is_error() -> None:
    entries = [
        make_entry("daily.fortune.head", HEAD_KEY, "{name}님, 쉬어 가세요.", 10, "advice"),
        make_entry("daily.guide", GUIDE_KEY, "{name}님, 천천히 하세요.", 20),
    ]
    limit = make_limit("limit.L1", CountSelector(placeholder="name"), 1)
    findings = check_days({}, entries, [limit], ("ko",))
    l1 = [finding for finding in findings if finding.rule_id == "limit.L1"]
    assert len(l1) == 1
    assert (l1[0].file, l1[0].line) == (FILE, 20)


def test_null_limit_is_skipped() -> None:
    entries = [
        make_entry("daily.fortune.head", HEAD_KEY, "가", 10, type_) for type_ in ("advice", "state", "care")
    ]
    limit = make_limit("limit.L2", CountSelector(type="care"), None, scope="day")
    assert check_days({}, entries, [limit], ("ko",)) == []


def test_rotation_positions_all_checked() -> None:
    types = ("advice", "state", "care")
    entries = [make_entry("daily.fortune.head", HEAD_KEY, "가", 10 + i, t) for i, t in enumerate(types)]
    entries += [make_entry("daily.fortune.tag", TAG_KEY, "나", 20 + i, t) for i, t in enumerate(types)]
    by_key = index(entries)
    types_by_rotation = [
        [entry.type for entry in assemble(sample_day(), by_key, "ko", rotation, 1)] for rotation in range(3)
    ]
    assert types_by_rotation == [["advice", "advice"], ["state", "state"], ["care", "care"]]

    limit = make_limit("limit.L2", CountSelector(type="care"), 1, scope="day")
    findings = check_days({}, entries, [limit], ("ko",))
    assert [(finding.rule_id, finding.line) for finding in findings] == [("limit.L2", 22)]


def test_guide_variants_both_checked() -> None:
    entries = [
        make_entry("daily.fortune.head", HEAD_KEY, "{name}님", 10, "advice"),
        make_entry("daily.guide", GUIDE_KEY, "없음", 20, variant=1),
        make_entry("daily.guide", GUIDE_KEY, "{name}님", 21, variant=2),
    ]
    limit = make_limit("limit.L1", CountSelector(placeholder="name"), 1)
    findings = check_days({}, entries, [limit], ("ko",))
    assert [finding.line for finding in findings] == [21]


def test_guide_variant_count_comes_from_slot() -> None:
    entries = [
        make_entry("daily.fortune.head", HEAD_KEY, "{name}님", 10, "advice"),
        make_entry("daily.guide", GUIDE_KEY, "{name}님", 21, variant=2),
    ]
    limit = make_limit("limit.L1", CountSelector(placeholder="name"), 1)
    only_first = {"daily.guide": make_slot("daily.guide", 1)}
    assert check_days(only_first, entries, [limit], ("ko",)) == []


def test_check_limits_filters_by_scope_and_lang() -> None:
    entries = [make_entry("daily.fortune.head", HEAD_KEY, "{name} {name}", 10, "advice")]
    limit = make_limit("limit.L1", CountSelector(placeholder="name"), 1)
    assert len(check_limits(entries, [limit], "screen", "ko", "시험")) == 1
    assert check_limits(entries, [limit], "day", "ko", "시험") == []
    korean_only = Limit("limit.L1", "시험", "screen", limit.count, {"ko": 1, "ja": None}, "error", 1)
    assert check_limits(entries, [korean_only], "screen", "ja", "시험") == []
    assert check_limits(entries, [korean_only], "screen", "en", "시험") == []


def test_missing_entries_are_not_counted() -> None:
    limit = make_limit("limit.L1", CountSelector(placeholder="name"), 1)
    assert check_days({}, [], [limit], ("ko",)) == []
