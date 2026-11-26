"""숫자, 자유 글 자리표시자의 가장 긴 값 테스트(W85)."""

from pathlib import Path

from mlw.cli import sentence_findings
from mlw.loader import load_rules, load_slots
from mlw.longest import (
    PARAM_SOURCES,
    SLOT_PARAM_SOURCES,
    Fixed,
    FromGlossary,
    FromKeys,
    LangValues,
    Unmeasured,
    lang_values,
    longest_param_value,
)
from mlw.model import Entry
from mlw.paths import RULES_DIR, SLOTS_DIR


def entry(slot: str, key: str, text: str, lang: str = "en") -> Entry:
    return Entry(Path(f"content/{lang}/ui.yaml"), 1, slot, key, None, 1, lang, text)


ENTRIES = [
    entry("glossary.value_name", "branch.myo", "Rabbit"),
    entry("glossary.value_name", "branch.yu", "Rooster"),
    entry("ui.login-methods.row", "loginProviderKakao", "Kakao"),
    entry("ui.login-methods.row", "loginProviderGoogle", "Google"),
    entry("ui.login-methods.row", "loginProviderGoogle", "구글", lang="ko"),
]


def values(lang: str = "en") -> LangValues:
    return lang_values(ENTRIES, lang)


def test_fixed_value_for_number() -> None:
    assert longest_param_value("ui.picker.item", "month", values()) == "12"


def test_fixed_value_by_lang() -> None:
    assert longest_param_value("calc-basis.longitude.body", "longitude", values()) == "127.5°E"
    assert longest_param_value("calc-basis.longitude.body", "longitude", values("ja")) == "東経127.5°"


def test_slot_override_wins() -> None:
    assert longest_param_value("ui.purchase.meta", "date", values()) == "12/31/2026"
    assert longest_param_value("today.date.solar", "date", values()) == "September 30"


def test_glossary_source_takes_longest_name() -> None:
    assert longest_param_value("onboard-time.hour.confirm", "branch", values()) == "Rooster"


def test_keys_source_takes_longest_text_of_same_lang() -> None:
    assert longest_param_value("login-methods.unlink.confirm", "provider", values()) == "Google"
    assert longest_param_value("login-methods.unlink.confirm", "provider", values("ko")) == "구글"


def test_values_asked_in_1362_are_measured() -> None:
    # design V138: 사주 줄과 구매 기간은 짧은 날짜(yMd), 문의 번호는 32자리 hex입니다.
    assert longest_param_value("ui.account-merge.saju", "date", values("ko")) == "2026. 12. 31."
    assert longest_param_value("ui.purchase.meta", "start", values("ko")) == "2026. 12. 31."
    assert longest_param_value("ui.purchase.meta", "end", values()) == "12/31/2026"
    trace = longest_param_value("ui.app.trace", "traceId", values("ja"))
    assert trace is not None and len(trace) == 32


def test_unmeasured_and_unknown_give_none() -> None:
    assert isinstance(PARAM_SOURCES["title"], Unmeasured)
    assert longest_param_value("today.event.summary", "title", values()) is None
    assert longest_param_value("x", "nowhere", values()) is None


def test_every_number_and_text_param_has_a_source() -> None:
    # 새 매개변수를 더하면 여기서 값 출처나 재지 않는 이유를 정하게 합니다.
    slots = load_slots(SLOTS_DIR, load_rules(RULES_DIR))
    missing = sorted(
        f"{slot.id}.{name}"
        for slot in slots.values()
        for params in slot.keys.values()
        for name, kind in params.items()
        if kind.kind in ("number", "text") and name not in PARAM_SOURCES and (slot.id, name) not in SLOT_PARAM_SOURCES
    )
    assert missing == []


def test_sources_have_values_for_every_lang() -> None:
    for source in [*PARAM_SOURCES.values(), *SLOT_PARAM_SOURCES.values()]:
        if isinstance(source, Fixed):
            assert "*" in source.by_lang or {"ko", "en", "ja"} <= source.by_lang.keys(), source
        elif isinstance(source, Unmeasured):
            assert source.reason
        else:
            assert isinstance(source, FromGlossary | FromKeys)


def test_length_check_measures_number_placeholder() -> None:
    rules = load_rules(RULES_DIR)
    slots = load_slots(SLOTS_DIR, rules)
    long = entry("ui.picker.item", "datePickerLeapMonthValue", "Leap month {month}")
    short = entry("ui.picker.item", "datePickerLeapMonthValue", "Leap {month}")
    assert [f.rule_id for f in sentence_findings(slots, [long], rules)] == ["style.length"]
    assert sentence_findings(slots, [short], rules) == []


def test_length_check_measures_text_placeholders_in_plural() -> None:
    rules = load_rules(RULES_DIR)
    slots = load_slots(SLOTS_DIR, rules)
    text = (
        "We remove the {dstMinutes}-minute daylight saving offset from your birth time, then subtract "
        "{minutes, plural, one{{minutes} minute} other{{minutes} minutes}} based on {longitude}. We don't use "
        "true solar time. If you were born within minutes of an hour boundary, your hour pillar may differ "
        "from other saju apps."
    )
    found = sentence_findings(slots, [entry("calc-basis.longitude.body", "calcBasisLongitudeBodyDstSubtract", text)], rules)
    # plural 형태(one, other)마다 길이가 달라 둘 다 넘습니다.
    assert {f.rule_id for f in found} == {"style.length"}
