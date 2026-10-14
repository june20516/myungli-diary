"""호칭 덩어리 위치(name.position)와 ui 표기(ui.markup) 검사 테스트."""

from pathlib import Path

import pytest

from mlw.markup import (
    RULE_NAME_POSITION,
    RULE_UI_MARKUP,
    check_name_position,
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


@pytest.mark.parametrize("text", ["{name}님, 안녕하세요", "일정 {count}(이)가 있어요", "[[편관]]이 들어요"])
def test_ui_markup_errors(text: str) -> None:
    assert [finding.rule_id for finding in check_ui_markup(entry(text))] == [RULE_UI_MARKUP]


def test_ui_markup_ok() -> None:
    assert check_ui_markup(entry("오늘 일정 {count}개")) == []


def test_name_position_rejects_extra_space_after_vocative() -> None:
    findings = check_name_position(entry("{name}님,  쉬어 가는 날이에요."), make_slot(vocative=True))
    assert [finding.rule_id for finding in findings] == [RULE_NAME_POSITION]
