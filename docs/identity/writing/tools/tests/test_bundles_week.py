"""한 주 묶음 검사 테스트."""

import json
from dataclasses import asdict
from pathlib import Path

import pytest

from mlw.bundles import SLOT_GUIDE, DayKeys, _rotate, check_weeks, week_windows
from mlw.josa import default_josa_data
from mlw.model import SENTENCE_TYPES, CountSelector, Entry, Limit, RuleSet

HEAD_KEY = "fortune.ordinary_day.siksang"
FILE = Path("content/ko/daily.yaml")
RULES = RuleSet({}, {}, {}, default_josa_data())
MESSAGE_KEYS = [
    HEAD_KEY,
    "guide.ten_god.siksang",
    "color.ordinary_day",
    "direction.day_kind.ordinary",
    "number.ordinary_day",
    "focus_time.hap",
]
FIXTURE_PATH = Path("fixtures/week_samples.json")
TOOLS_DIR = Path(__file__).parent.parent


def day_keys(head: str = HEAD_KEY) -> DayKeys:
    return DayKeys(
        head=head,
        tag_sentence=None,
        guide="guide.ten_god.siksang",
        color="color.ordinary_day",
        direction="direction.day_kind.ordinary",
        number="number.ordinary_day",
        focus="focus_time.hap",
        tag_label=None,
    )


def fixture_of(days: list[DayKeys]) -> dict[str, object]:
    return {
        "engine_version": "0",
        "ruleset_version": "0",
        "start": "2026-11-02",
        "samples": [{"birth_id": "t01", "days": [asdict(day) for day in days]}],
    }


def head_entries() -> list[Entry]:
    return [
        Entry(FILE, 10 + index, "daily.fortune.head", HEAD_KEY, type_, 1, "ko", "문장")
        for index, type_ in enumerate(("advice", "state", "care"))
    ]


def care_limit(max_value: int) -> Limit:
    max_by_lang: dict[str, int | None] = {"ko": max_value, "en": max_value, "ja": max_value}
    return Limit("limit.test_care", "돌봄 빈도", "week", CountSelector(type="care"), max_by_lang, "warn", 1)


def test_week_care_limit() -> None:
    fixture = fixture_of([day_keys()] * 7)
    findings = check_weeks({}, head_entries(), [care_limit(2)], ["ko"], RULES, fixture, MESSAGE_KEYS)
    assert [finding.rule_id for finding in findings] == ["limit.test_care"]
    assert findings[0].severity == "warn"


def test_week_within_limit_is_clean() -> None:
    fixture = fixture_of([day_keys()] * 7)
    assert check_weeks({}, head_entries(), [care_limit(3)], ["ko"], RULES, fixture, MESSAGE_KEYS) == []


def test_fixture_unknown_key_is_error() -> None:
    fixture = fixture_of([day_keys("fortune.unknown")] * 7)
    findings = check_weeks(
        {}, head_entries(), [care_limit(2)], ["ko"], RULES, fixture, MESSAGE_KEYS, fixture_path=FIXTURE_PATH
    )
    stale = [finding for finding in findings if finding.rule_id == "week.fixture_stale"]
    assert len(stale) == 1
    assert stale[0].severity == "error"
    assert stale[0].file == FIXTURE_PATH
    assert stale[0].line == 1


def test_windows_slide() -> None:
    windows = week_windows(list(range(28)), 7)
    assert len(windows) == 22
    assert windows[0] == list(range(7))
    assert windows[-1] == list(range(21, 28))


@pytest.mark.contract
def test_real_fixture_has_no_stale_keys() -> None:
    fixture = json.loads((TOOLS_DIR / "fixtures" / "week_samples.json").read_text(encoding="utf-8"))
    keys = json.loads((TOOLS_DIR.parents[3] / "core" / "message_keys.json").read_text(encoding="utf-8"))
    assert check_weeks({}, [], [], ["ko"], RULES, fixture, keys) == []


TAG_KEY = "fortune.tag.clash"
GUIDE_KEY = "guide.ten_god.siksang"


def typed_entries(slot: str, key: str, first_line: int) -> list[Entry]:
    return [
        Entry(FILE, first_line + index, slot, key, type_, 1, "ko", "문장")
        for index, type_ in enumerate(("advice", "state", "care"))
    ]


def test_rotation_continues_across_windows() -> None:
    days = [day_keys()] * 14
    entries_by = {("daily.fortune.head", HEAD_KEY, "ko"): head_entries()}
    per_day = _rotate(days, entries_by, "ko", 0, 0, 2)
    types = [picked[0].type for picked in per_day]
    assert types == [SENTENCE_TYPES[index % 3] for index in range(14)]


def test_head_and_tag_rotate_independently() -> None:
    plain = day_keys()
    tagged = DayKeys(plain.head, TAG_KEY, plain.guide, plain.color, plain.direction, plain.number, plain.focus, None)
    days = [tagged if index % 2 else plain for index in range(8)]
    entries_by = {
        ("daily.fortune.head", HEAD_KEY, "ko"): head_entries(),
        ("daily.fortune.tag", TAG_KEY, "ko"): typed_entries("daily.fortune.tag", TAG_KEY, 30),
    }
    per_day = _rotate(days, entries_by, "ko", 0, 0, 2)
    head_types = [picked[0].type for picked in per_day]
    tag_types = [picked[1].type for index, picked in enumerate(per_day) if index % 2]
    assert head_types == [SENTENCE_TYPES[index % 3] for index in range(8)]
    assert tag_types == [SENTENCE_TYPES[index % 3] for index in range(4)]


def test_type_and_guide_variant_starts_are_combined() -> None:
    """유형 시작 2 x 가이드 변주 시작 2의 조합에서만 {name}이 7회가 됩니다."""
    entries = [
        Entry(FILE, 10, "daily.fortune.head", HEAD_KEY, "advice", 1, "ko", "문장"),
        Entry(FILE, 11, "daily.fortune.head", HEAD_KEY, "state", 1, "ko", "문장"),
        Entry(FILE, 12, "daily.fortune.head", HEAD_KEY, "care", 1, "ko", "{name}님"),
        Entry(FILE, 20, "daily.guide", GUIDE_KEY, None, 1, "ko", "안내"),
        Entry(FILE, 21, "daily.guide", GUIDE_KEY, None, 2, "ko", "{name}님 안내"),
    ]
    max_by_lang: dict[str, int | None] = {"ko": 6, "en": 6, "ja": 6}
    limit = Limit("limit.L4", "호칭", "week", CountSelector(placeholder="name"), max_by_lang, "warn", 1)
    findings = check_weeks({}, entries, [limit], ["ko"], RULES, fixture_of([day_keys()] * 7), MESSAGE_KEYS)
    assert [finding.rule_id for finding in findings] == ["limit.L4"]


OK_KEY = "fortune.ordinary_day.biggeop"
PLAIN_KEY = "fortune.ordinary_day.jaesung"
OTHER_KEYS = [OK_KEY, PLAIN_KEY, "fortune.ordinary_day.gwansal"]


def two_day_limit() -> Limit:
    return Limit(
        "limit.L8",
        "괜찮아요 연속 이틀",
        "week",
        CountSelector(lexicon=("괜찮아요",)),
        {"ko": 1},
        "warn",
        1,
        window=2,
    )


def phrase_entries(key: str, text: str, first_line: int) -> list[Entry]:
    return [
        Entry(FILE, first_line + index, "daily.fortune.head", key, type_, 1, "ko", text if index == 0 else "다른 말")
        for index, type_ in enumerate(("advice", "state", "care"))
    ]


def phrase_fixture(order: list[str]) -> dict[str, object]:
    return fixture_of([day_keys(key) for key in order])


def phrase_entries_all() -> list[Entry]:
    return (
        phrase_entries(OTHER_KEYS[0], "괜찮아요", 10)
        + phrase_entries(OTHER_KEYS[1], "괜찮아요", 20)
        + phrase_entries(OTHER_KEYS[2], "다른 말", 30)
    )


def test_two_day_window_catches_consecutive_days() -> None:
    fixture = phrase_fixture([OTHER_KEYS[0], OTHER_KEYS[1], OTHER_KEYS[2]])
    keys = MESSAGE_KEYS + OTHER_KEYS
    findings = check_weeks({}, phrase_entries_all(), [two_day_limit()], ["ko"], RULES, fixture, keys)
    assert [finding.rule_id for finding in findings] == ["limit.L8"]
    assert "2026-11-02부터 2일" in findings[0].message


def test_two_day_window_ignores_separated_days() -> None:
    fixture = phrase_fixture([OTHER_KEYS[0], OTHER_KEYS[2], OTHER_KEYS[1]])
    keys = MESSAGE_KEYS + OTHER_KEYS
    assert check_weeks({}, phrase_entries_all(), [two_day_limit()], ["ko"], RULES, fixture, keys) == []


def seven_day_limit() -> Limit:
    return Limit(
        "limit.L9",
        "괜찮아요 한 주",
        "week",
        CountSelector(lexicon=("괜찮아요",)),
        {"ko": 1},
        "warn",
        2,
    )


def test_each_limit_uses_its_own_window() -> None:
    third = "fortune.ordinary_day.extra"
    plain = OTHER_KEYS[2]
    entries = phrase_entries_all() + phrase_entries(third, "괜찮아요", 40)
    # 괜찮아요가 1·3·5일째에만 나와 이틀 연속은 없지만 7일 안에는 3번 있습니다.
    order = [OTHER_KEYS[0], plain, OTHER_KEYS[1], plain, third, plain, plain]
    keys = MESSAGE_KEYS + OTHER_KEYS + [third]
    limits = [two_day_limit(), seven_day_limit()]
    findings = check_weeks({}, entries, limits, ["ko"], RULES, phrase_fixture(order), keys)
    assert {finding.rule_id for finding in findings} == {"limit.L9"}


def test_two_day_window_counts_two_entries_of_one_day() -> None:
    guide = Entry(FILE, 50, SLOT_GUIDE, GUIDE_KEY, "advice", 1, "ko", "괜찮아요")
    entries = phrase_entries(OTHER_KEYS[0], "괜찮아요", 10) + [guide]
    fixture = phrase_fixture([OTHER_KEYS[0], OTHER_KEYS[2]])
    keys = MESSAGE_KEYS + OTHER_KEYS
    findings = check_weeks({}, entries, [two_day_limit()], ["ko"], RULES, fixture, keys)
    assert {finding.rule_id for finding in findings} == {"limit.L8"}
