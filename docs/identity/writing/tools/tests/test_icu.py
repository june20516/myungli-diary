"""ICU plural 파싱·펼치기 테스트."""

import pytest

from mlw.icu import expand_plural, parse_plural, plural_problem


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
