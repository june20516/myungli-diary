"""한 주 묶음 검사 테스트."""

import json
from dataclasses import asdict
from pathlib import Path

from mlw.bundles import DayKeys, check_weeks, week_windows
from mlw.josa import default_josa_data
from mlw.model import CountSelector, Entry, Limit, RuleSet

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
    return Limit("limit.L3", "돌봄 빈도", "week", CountSelector(type="care"), max_by_lang, "warn", 1)


def test_week_care_limit() -> None:
    fixture = fixture_of([day_keys()] * 7)
    findings = check_weeks({}, head_entries(), [care_limit(2)], ["ko"], RULES, fixture, MESSAGE_KEYS)
    assert [finding.rule_id for finding in findings] == ["limit.L3"]
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


def test_real_fixture_has_no_stale_keys() -> None:
    fixture = json.loads((TOOLS_DIR / "fixtures" / "week_samples.json").read_text(encoding="utf-8"))
    keys = json.loads((TOOLS_DIR.parents[3] / "core" / "message_keys.json").read_text(encoding="utf-8"))
    assert check_weeks({}, [], [], ["ko"], RULES, fixture, keys) == []
