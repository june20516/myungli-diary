"""ui 원고의 조사 표기를 ICU select로 펼치는 모듈 테스트(spec 2026-10-22-ui-josa §4)."""

import pytest

from mlw.josa import default_josa_data, render_josa
from mlw.josa_select import JOSA_BRANCHES, expand_josa, josa_param, select_forms


@pytest.mark.parametrize(
    ("marker", "final", "rieul", "none", "other"),
    [
        ("(이)가", "이", "이", "가", "이(가)"),
        ("(은)는", "은", "은", "는", "은(는)"),
        ("(을)를", "을", "을", "를", "을(를)"),
        ("(과)와", "과", "과", "와", "과(와)"),
        ("(으)로", "으로", "로", "로", "(으)로"),
        ("(이)에요", "이에요", "이에요", "예요", "(이)에요"),
    ],
)
def test_expand_each_pair(marker: str, final: str, rieul: str, none: str, other: str) -> None:
    select = f"{{tJosa, select, final{{{final}}} rieul{{{rieul}}} none{{{none}}} other{{{other}}}}}"
    assert expand_josa(f"{{t}}{marker}") == (f"{{t}}{select}", ["t"])


def test_branches_and_param_name() -> None:
    assert JOSA_BRANCHES == ("final", "rieul", "none", "other")
    assert josa_param("title") == "titleJosa"


def test_expand_same_param_twice() -> None:
    text, params = expand_josa("{p}(이)가 {p}(을)를")
    assert text == (
        "{p}{pJosa, select, final{이} rieul{이} none{가} other{이(가)}} "
        "{p}{pJosa, select, final{을} rieul{을} none{를} other{을(를)}}"
    )
    assert params == ["p"]


def test_expand_inside_plural() -> None:
    assert expand_josa("{count, plural, other{{count}(이)에요}}") == (
        "{count, plural, other{{count}{countJosa, select, final{이에요} rieul{이에요} none{예요} other{(이)에요}}}}",
        ["count"],
    )


def test_expand_without_josa_is_identity() -> None:
    assert expand_josa("{date} 일기 쓰기") == ("{date} 일기 쓰기", [])


def test_select_forms() -> None:
    expanded, _ = expand_josa("{t}(이)가 {u}(을)를")
    assert select_forms(expanded) == [
        "{t}이 {u}을",
        "{t}이 {u}을",
        "{t}가 {u}를",
        "{t}이(가) {u}을(를)",
    ]


def test_select_forms_without_select() -> None:
    assert select_forms("{date} 일기 쓰기") == ["{date} 일기 쓰기"]


def test_unknown_char_example() -> None:
    assert render_josa("♡(이)가") == "♡이(가)"


def test_josa_examples_include_fallback() -> None:
    fallbacks = {pair.fallback for pair in default_josa_data().pairs}
    examples = default_josa_data().examples
    # app·server가 같은 표로 ICU `other` 가지(병기형)까지 맞추려면 판정할 수 없는 예가 있어야 합니다.
    assert any(example.expected.endswith(tuple(fallbacks)) for example in examples)
