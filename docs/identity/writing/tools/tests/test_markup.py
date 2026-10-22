"""호칭 덩어리 위치(name.position)와 ui 표기(ui.markup) 검사 테스트."""

from pathlib import Path

import pytest

from mlw.markup import (
    RULE_NAME_POSITION,
    RULE_UI_JOSA_LITERAL,
    RULE_UI_JOSA_NAME_CLASH,
    RULE_UI_JOSA_POSITION,
    RULE_UI_MARKUP,
    check_name_position,
    check_ui_josa,
    check_ui_markup,
    strip_vocative,
)
from mlw.model import Entry, ParamKind, Slot


def make_slot(vocative: bool, params: dict[str, ParamKind] | None = None) -> Slot:
    return Slot(
        id="s.slot",
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys={"k": params or {}},
        co_display=(),
        max_length={},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots/content/test.yaml"),
        vocative=vocative,
    )


def entry(text: str, lang: str = "ko") -> Entry:
    return Entry(Path(f"content/{lang}/test.yaml"), 3, "s.slot", "k", None, 1, lang, text)


def test_strip_vocative() -> None:
    assert strip_vocative("{name}님, 오늘은 맑아요.", "ko") == "오늘은 맑아요."
    assert strip_vocative("{name}さん、今日は晴れです。", "ja") == "今日は晴れです。"
    assert strip_vocative("{name}, today is clear.", "en") == "today is clear."
    assert strip_vocative("오늘은 맑아요.", "ko") is None


@pytest.mark.parametrize(
    ("lang", "text"),
    [("ko", "{name}님, 오늘은 맑아요."), ("ja", "{name}さん、今日は晴れです。"), ("en", "{name}, today is clear.")],
)
def test_name_position_ok(lang: str, text: str) -> None:
    assert check_name_position(entry(text, lang), make_slot(vocative=True)) == []


def test_text_without_name_is_ok_anywhere() -> None:
    assert check_name_position(entry("오늘은 맑아요."), make_slot(vocative=False)) == []


@pytest.mark.parametrize(
    ("vocative", "text"),
    [
        (True, "{name}님 오늘은 맑아요."),
        (True, "오늘은 {name}님, 좋아요."),
        (False, "{name}님, 좋아요."),
        (True, "{name}님, {name}님, 좋아요."),
    ],
)
def test_name_position_errors(vocative: bool, text: str) -> None:
    findings = check_name_position(entry(text), make_slot(vocative=vocative))
    assert [finding.rule_id for finding in findings] == [RULE_NAME_POSITION]


@pytest.mark.parametrize(
    ("lang", "text"),
    [("ko", "{name}님, 안녕하세요"), ("en", "{count}(이)가 events"), ("ko", "[[편관]]이 들어요")],
)
def test_ui_markup_errors(lang: str, text: str) -> None:
    assert [finding.rule_id for finding in check_ui_markup(entry(text, lang))] == [RULE_UI_MARKUP]


def test_ui_markup_ok() -> None:
    assert check_ui_markup(entry("오늘 일정 {count}개")) == []


def test_name_position_rejects_extra_space_after_vocative() -> None:
    findings = check_name_position(entry("{name}님,  쉬어 가는 날이에요."), make_slot(vocative=True))
    assert [finding.rule_id for finding in findings] == [RULE_NAME_POSITION]


TEXT = ParamKind("text")


def test_ui_markup_allows_josa_in_ko() -> None:
    assert check_ui_markup(entry("{title}(이)가 내일이에요")) == []
    assert [finding.rule_id for finding in check_ui_markup(entry("{title}(이)가 내일이에요", "en"))] == [RULE_UI_MARKUP]


@pytest.mark.parametrize(
    ("text", "params"),
    [("오늘(은)는 쉬어요", {}), ("{role}(이)가 있어요", {"role": ParamKind("none")})],
)
def test_ui_josa_position_errors(text: str, params: dict[str, ParamKind]) -> None:
    assert [finding.rule_id for finding in check_ui_josa(entry(text), params)] == [RULE_UI_JOSA_POSITION]


@pytest.mark.parametrize(
    "text",
    [
        "{provider}로 로그인해요",
        "{title}이 내일이에요",
        "{title}가",
        "{title}가…",
        "{title}이)",
        '{title}이"',
        "{title}가: 내일",
        "{provider}로는 로그인할 수 없어요",
        "{provider}으로도 돼요",
        "{title}은요?",
        "{title}와의 약속",
        "‘{title}’이 내일이에요",
    ],
)
def test_ui_josa_literal_errors(text: str) -> None:
    params = {"provider": TEXT, "title": TEXT}
    assert [finding.rule_id for finding in check_ui_josa(entry(text), params)] == [RULE_UI_JOSA_LITERAL]


def test_ui_josa_category_placeholder_is_position_error() -> None:
    findings = check_ui_josa(entry("{p:cat}(이)가 있어요"), {"p": TEXT})
    assert [finding.rule_id for finding in findings] == [RULE_UI_JOSA_POSITION]


@pytest.mark.parametrize(
    "text",
    ["{date}이후", "{count}개", "{end}에 태어났어요", "{tag} 태그", "{title}(이)가", "{count}(은)는 많아요", "{date}이나 내일"],
)
def test_ui_josa_literal_ok(text: str) -> None:
    params = {"date": TEXT, "count": ParamKind("number"), "end": TEXT, "tag": TEXT, "title": TEXT}
    assert check_ui_josa(entry(text), params) == []


def test_ui_josa_name_clash() -> None:
    findings = check_ui_josa(entry("{title}(이)가 {titleJosa}"), {"title": TEXT, "titleJosa": TEXT})
    assert [finding.rule_id for finding in findings] == [RULE_UI_JOSA_NAME_CLASH]


def test_ui_josa_skips_other_languages() -> None:
    assert check_ui_josa(entry("{title}이 내일", "en"), {"title": TEXT}) == []
