"""완결성 검사 테스트."""

from pathlib import Path

from mlw.completeness import check_completeness, glossary_values
from mlw.model import Entry, Finding, Slot

FILE = Path("slots/content/daily.yaml")
KEY = "fortune.yongsin_day.siksang"
OTHER_KEY = "fortune.yongsin_day.jaeseong"
LANGS = ("ko",)


def make_slot(
    slot_id: str = "daily.fortune.head",
    keys: dict[str, tuple[str, ...]] | None = None,
    types: tuple[str, ...] = ("advice", "state", "care"),
    variants: int = 1,
) -> Slot:
    return Slot(
        id=slot_id,
        where="시험",
        purpose="info",
        types=types,
        variants=variants,
        keys=keys if keys is not None else {KEY: ("element", "name")},
        co_display=(),
        max_length={"ko": None, "en": None, "ja": None},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={"good": [], "bad": []},
        line=3,
        file=FILE,
    )


def make_entry(
    key: str = KEY,
    type_: str | None = "advice",
    text: str = "오늘은 쉬어 가세요.",
    slot: str = "daily.fortune.head",
    variant: int = 1,
    lang: str = "ko",
    line: int = 1,
) -> Entry:
    return Entry(Path("content/ko/a.yaml"), line, slot, key, type_, variant, lang, text)


def check(slot: Slot, entries: list[Entry], message_keys: tuple[str, ...] = (KEY,)) -> list[Finding]:
    return check_completeness({slot.id: slot}, entries, message_keys, LANGS)


def rule_ids(findings: list[Finding]) -> list[str]:
    return [finding.rule_id for finding in findings]


def test_complete_content_has_no_findings() -> None:
    entries = [make_entry(type_=type_) for type_ in ("advice", "state", "care")]
    assert check(make_slot(), entries) == []


def test_missing_type_reported() -> None:
    entries = [make_entry(type_="advice"), make_entry(type_="state")]
    [finding] = check(make_slot(), entries)
    assert finding.rule_id == "complete.missing"
    assert finding.severity == "error"
    assert KEY in finding.message
    assert "care" in finding.message
    assert "ko" in finding.message
    assert (finding.file, finding.line) == (FILE, 3)


def test_missing_language_and_variant_reported() -> None:
    slot = make_slot(types=(), variants=2)
    entries = [make_entry(type_=None, variant=1)]
    findings = check_completeness({slot.id: slot}, entries, (KEY,), ("ko", "en"))
    assert rule_ids(findings) == ["complete.missing"] * 3
    messages = " ".join(finding.message for finding in findings)
    assert "변주 2" in messages and "언어 en" in messages


def test_placeholder_not_in_params() -> None:
    entries = [
        make_entry(type_=type_, text="{direction}쪽이 좋아요.") for type_ in ("advice", "state", "care")
    ]
    findings = check(make_slot(), entries)
    assert rule_ids(findings) == ["complete.unknown_param"] * 3
    assert "direction" in findings[0].message


def test_name_is_always_allowed() -> None:
    slot = make_slot(keys={KEY: ()})
    entries = [make_entry(type_=type_, text="{name}님, 쉬세요.") for type_ in ("advice", "state", "care")]
    assert check(slot, entries) == []


def test_placeholder_category_must_be_glossary_category() -> None:
    entries = [
        make_entry(type_=type_, text="{element:colour}이(가) 좋아요.")
        for type_ in ("advice", "state", "care")
    ]
    assert rule_ids(check(make_slot(), entries)) == ["complete.unknown_category"] * 3


def test_known_category_passes() -> None:
    entries = [
        make_entry(type_=type_, text="{element:color}(이)가 좋아요.") for type_ in ("advice", "state", "care")
    ]
    assert check(make_slot(), entries) == []


def test_unknown_key_in_content() -> None:
    entries = [make_entry(type_=type_) for type_ in ("advice", "state", "care")]
    entries.append(make_entry(key="fortune.nowhere.x"))
    findings = check(make_slot(), entries)
    assert rule_ids(findings) == ["complete.unknown_key"]
    assert findings[0].line == 1


def test_unknown_slot_in_content() -> None:
    findings = check(make_slot(), [make_entry(slot="nowhere.slot")])
    assert "complete.unknown_slot" in rule_ids(findings)


def test_type_rules() -> None:
    typed = make_slot()
    findings = check(typed, [make_entry(type_=None)])
    assert "complete.bad_type" in rule_ids(findings)
    untyped = make_slot(types=())
    assert rule_ids(check(untyped, [make_entry(type_="advice")]))[0] == "complete.bad_type"


def test_variant_out_of_range_and_duplicate() -> None:
    slot = make_slot(types=())
    out_of_range = check(slot, [make_entry(type_=None, variant=2)])
    assert "complete.bad_variant" in rule_ids(out_of_range)
    duplicate = check(slot, [make_entry(type_=None), make_entry(type_=None, line=9)])
    assert rule_ids(duplicate) == ["complete.duplicate"]
    assert duplicate[0].line == 9


def test_unknown_language() -> None:
    slot = make_slot(types=())
    assert "complete.unknown_lang" in rule_ids(check(slot, [make_entry(type_=None, lang="fr")]))


def test_message_key_without_slot_reported() -> None:
    slot = make_slot(types=())
    findings = check(slot, [make_entry(type_=None)], message_keys=(KEY, OTHER_KEY))
    [finding] = findings
    assert finding.rule_id == "complete.unslotted_key"
    assert OTHER_KEY in finding.message


def test_malformed_placeholder_is_left_to_sentence_check() -> None:
    slot = make_slot(types=())
    assert check(slot, [make_entry(type_=None, text="{element")]) == []


def test_glossary_values_names() -> None:
    values = glossary_values()
    assert values["element"] == ("wood", "fire", "earth", "metal", "water")
    assert values["day_kind"] == ("gwiin_day", "yongsin_day", "gisin_day", "ordinary_day")
    assert values["stem"][0] == "gap"
