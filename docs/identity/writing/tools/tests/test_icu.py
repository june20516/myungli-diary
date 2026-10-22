"""ICU plural 파싱·펼치기 테스트."""

from pathlib import Path

import pytest

from mlw.icu import expand_entry, expand_plural, parse_plural, plural_problem
from mlw.model import Entry


def test_text_without_plural_is_returned_as_is() -> None:
    assert parse_plural("결과 {count}개") is None
    assert expand_plural("결과 {count}개") == ["결과 {count}개"]


def test_expand_keeps_prefix_and_suffix_on_every_form() -> None:
    text = "Found {count, plural, one{{count} city} other{{count} cities}}."
    assert expand_plural(text) == ["Found {count} city.", "Found {count} cities."]


def test_parse_reads_variable_and_forms() -> None:
    plural = parse_plural("{count, plural, one{{count} city} other{{count} cities}}")
    assert plural is not None
    assert plural.variable == "count"
    assert plural.forms == {"one": "{count} city", "other": "{count} cities"}
    assert (plural.prefix, plural.suffix) == ("", "")


@pytest.mark.parametrize(
    "text",
    [
        "{count, plural, other{a}",
        "{count, plural, other a}",
        "{count, plural, }",
        "{count, plural, other{a} other{b}}",
        "{a, plural, other{x}} {b, plural, other{y}}",
        "결과 {count, plural, other{{count}개}}}",
        "{결과 {count, plural, other{{count}개}}",
    ],
)
def test_bad_syntax_raises(text: str) -> None:
    with pytest.raises(ValueError):
        expand_plural(text)


def test_forms_must_match_language() -> None:
    assert plural_problem("{count, plural, other{{count}개}}", "ko") is None
    assert plural_problem("{count, plural, other{{count}件}}", "ja") is None
    assert plural_problem("{count, plural, one{a} other{b}}", "en") is None
    assert plural_problem("{count, plural, one{a} other{b}}", "ko") is not None
    assert plural_problem("{count, plural, other{b}}", "en") is not None
    assert plural_problem("{count, plural, others{b}}", "ja") is not None


def test_problem_reports_bad_syntax_and_ignores_plain_text() -> None:
    assert plural_problem("{count, plural, other{a}", "ko") is not None
    assert plural_problem("결과", "ko") is None


def test_problem_rejects_hash_and_nested_plural_in_form() -> None:
    assert plural_problem("{count, plural, other{#개}}", "ko") is not None
    assert plural_problem("{count, plural, other{{n, plural, other{x}}}}", "ko") is not None


SELECT = "{tJosa, select, final{이} rieul{이} none{가} other{이(가)}}"
PLURAL_WITH_JOSA = (
    "{count, plural, other{{count}{countJosa, select, final{이에요} rieul{이에요} none{예요} other{(이)에요}}}}"
)


def _entry(text: str) -> Entry:
    return Entry(Path("app_ko.arb"), 1, "", "k", None, 1, "ko", text)


def test_expand_entry_josa_select() -> None:
    forms = [form.text for form in expand_entry(_entry("{t}" + SELECT + " 내일"))]
    # 병기형(`other` 가지)은 server 콘텐츠 렌더와 같은 기계적 대체라 문장 검사에서 뺍니다(style.S1에 걸림).
    assert forms == ["{t}이 내일", "{t}이 내일", "{t}가 내일"]


def test_expand_entry_plural_with_josa() -> None:
    assert plural_problem(PLURAL_WITH_JOSA, "ko") is None
    forms = [form.text for form in expand_entry(_entry(PLURAL_WITH_JOSA))]
    assert forms == ["{count}이에요", "{count}이에요", "{count}예요"]
