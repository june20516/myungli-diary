import unicodedata
from dataclasses import replace
from pathlib import Path

import pytest

from mlw.loader import load_rules
from mlw.model import Detect, Entry, Examples, RuleSet, SlopRule, StyleRule
from mlw.paths import RULES_DIR
from mlw.sentence import check_sentence, normalize_for_detection


def make_entry(text: str, *, sentence_type: str | None = None) -> Entry:
    return Entry(Path("a.yaml"), 3, "slot", "key", sentence_type, 1, "ko", text)


@pytest.fixture(scope="module")
def rules() -> RuleSet:
    return load_rules(RULES_DIR)


def with_banned_word_rule(rules: RuleSet) -> RuleSet:
    rule = StyleRule(
        id="style.T",
        name="테스트",
        severity="warn",
        detect=Detect(kind="lexicon", words=("금지어",)),
        exempt_purposes=frozenset({"care"}),
        examples=Examples(),
        line=1,
    )
    return replace(rules, slop={}, style={"style.T": rule})


def test_exempt_purpose_skips_rule(rules: RuleSet) -> None:
    custom = with_banned_word_rule(rules)
    entry = make_entry("금지어가 있어요.")
    assert check_sentence(entry, "care", custom, None, {}) == []
    assert [f.rule_id for f in check_sentence(entry, "info", custom, None, {})] == ["style.T"]


def test_care_type_uses_care_purpose(rules: RuleSet) -> None:
    custom = with_banned_word_rule(rules)
    assert check_sentence(make_entry("금지어", sentence_type="care"), "info", custom, None, {}) == []


def test_length_uses_longest_value(rules: RuleSet) -> None:
    entry = make_entry("{element:color}(이)가 좋아요")
    values = {"element:color": "청록색"}
    assert check_sentence(entry, "info", rules, 8, values) == []
    findings = check_sentence(entry, "info", rules, 7, values)
    assert [f.rule_id for f in findings] == ["style.length"]
    assert findings[0].severity == "error"


def test_length_skipped_without_value(rules: RuleSet) -> None:
    assert check_sentence(make_entry("{element:color}가 좋아요"), "info", rules, 1, {}) == []


def test_length_skipped_without_max(rules: RuleSet) -> None:
    assert check_sentence(make_entry("{name}님 좋아요"), "info", rules, None, {"name": "가" * 50}) == []


def test_bad_placeholder_syntax_reported(rules: RuleSet) -> None:
    findings = check_sentence(make_entry("{name님"), "info", rules, None, {})
    assert [(f.rule_id, f.severity) for f in findings] == [("placeholder.syntax", "error")]


def test_rule_detected_after_normalization(rules: RuleSet) -> None:
    findings = check_sentence(make_entry("{name}님, 좋은 날이에요!"), "info", rules, None, {})
    assert "slop.P8" in [f.rule_id for f in findings]


def test_token_brackets_removed_in_normalization() -> None:
    text = "[[인성]](이)가 들어와 무언가를 배우기 좋은 날이에요."
    assert normalize_for_detection(text) == "인성이 들어와 무언가를 배우기 좋은 날이에요."


def test_token_brackets_not_counted_in_length(rules: RuleSet) -> None:
    entry = make_entry("[[인성]]이 와요")
    assert check_sentence(entry, "info", rules, 6, {}) == []
    findings = check_sentence(entry, "info", rules, 5, {})
    assert [f.rule_id for f in findings] == ["style.length"]
    assert "6자" in findings[0].message


def test_bad_token_syntax_reported(rules: RuleSet) -> None:
    findings = check_sentence(make_entry("[[인성이 와요"), "info", rules, None, {})
    assert [(f.rule_id, f.severity) for f in findings] == [("token.syntax", "error")]
    findings = check_sentence(make_entry("[[]]가 와요"), "info", rules, None, {})
    assert [f.rule_id for f in findings] == ["token.syntax"]


def test_honorific_suffix_missing_is_error(rules: RuleSet) -> None:
    findings = check_sentence(make_entry("{name}의 오늘 하루는 어땠나요?"), "guide", rules, None, {})
    assert [(f.rule_id, f.severity) for f in findings] == [("style.S4", "error")]


def test_honorific_suffix_present_passes(rules: RuleSet) -> None:
    assert check_sentence(make_entry("{name}님의 오늘 하루는 어땠나요?"), "guide", rules, None, {}) == []


def test_honorific_suffix_ja_requires_san(rules: RuleSet) -> None:
    entry = replace(make_entry("{name}の一日はどうでしたか？"), lang="ja")
    assert [f.rule_id for f in check_sentence(entry, "guide", rules, None, {})] == ["style.S5"]
    ok = replace(make_entry("{name}さんの一日はどうでしたか？"), lang="ja")
    assert check_sentence(ok, "guide", rules, None, {}) == []


def test_honorific_suffix_not_required_in_english(rules: RuleSet) -> None:
    entry = replace(make_entry("How was your day, {name}?"), lang="en")
    assert check_sentence(entry, "guide", rules, None, {}) == []


def test_honorific_suffix_check_applies_nfc_to_raw_text(rules: RuleSet) -> None:
    nfd_text = unicodedata.normalize("NFD", "{name}님의 오늘 하루는 어땠나요?")
    assert nfd_text != "{name}님의 오늘 하루는 어땠나요?"
    assert check_sentence(make_entry(nfd_text), "guide", rules, None, {}) == []


def test_allowed_rule_is_skipped_in_slot(rules: RuleSet) -> None:
    custom = with_banned_word_rule(rules)
    entry = make_entry("금지어가 있어요.")
    assert check_sentence(entry, "info", custom, None, {}, allowed=frozenset({"style.T"})) == []


def test_forbidden_rule_ignores_exempt_purpose(rules: RuleSet) -> None:
    custom = with_banned_word_rule(rules)
    entry = make_entry("금지어가 있어요.", sentence_type="care")
    findings = check_sentence(entry, "care", custom, None, {}, forbidden=frozenset({"style.T"}))
    assert [f.rule_id for f in findings] == ["style.T"]


def test_llm_rule_with_detect_is_not_run(rules: RuleSet) -> None:
    llm_rule = SlopRule(
        id="slop.T",
        name="테스트",
        judge="llm",
        severity="warn",
        detect=Detect(kind="lexicon", words=("금지어",)),
        rubric="시험",
        exempt_purposes=frozenset(),
        examples=Examples(),
        line=1,
    )
    custom = replace(rules, slop={"slop.T": llm_rule}, style={})
    assert check_sentence(make_entry("금지어가 있어요."), "info", custom, None, {}) == []


@pytest.mark.parametrize("text", ["바쁜 날이니까 하나만 골라 해 보세요.", "몸이 무거우니까 천천히 가도 괜찮아요."])
def test_connective_nikka_is_not_formal_ending(rules: RuleSet, text: str) -> None:
    assert "style.S3" not in [f.rule_id for f in check_sentence(make_entry(text), "info", rules, None, {})]


def test_formal_ending_still_detected(rules: RuleSet) -> None:
    findings = check_sentence(make_entry("남색입니다. 좋습니까?"), "info", rules, None, {})
    assert "style.S3" in [f.rule_id for f in findings]


def test_dangsin_is_error(rules: RuleSet) -> None:
    entry = make_entry("재물의 흐름이 당신에게 어떤 의미로 다가왔나요?")
    findings = check_sentence(entry, "care", rules, None, {})
    assert ("style.S6", "error") in [(f.rule_id, f.severity) for f in findings]
