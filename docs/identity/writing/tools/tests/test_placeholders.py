import pytest

from mlw.placeholders import Placeholder, Token, parse, parse_tokens, substitute


def test_parse() -> None:
    assert parse("{name}님, {element:color}(이)가 좋아요") == [
        Placeholder("name", None, None),
        Placeholder("element", "color", "(이)가"),
    ]


def test_parse_unclosed_raises() -> None:
    with pytest.raises(ValueError):
        parse("{name")


def test_parse_tokens() -> None:
    text = "[[인성]]이 오고 [[{ten_god:ten_god_group}]](이)가 와요"
    assert parse_tokens(text) == [
        Token("인성", 0, 6),
        Token("{ten_god:ten_god_group}", 11, 38),
    ]


def test_parse_tokens_without_token_is_empty() -> None:
    assert parse_tokens("토큰이 없어요 {name}님") == []


def test_parse_finds_placeholder_inside_token() -> None:
    assert parse("[[{ten_god:ten_god_group}]](이)가") == [Placeholder("ten_god", "ten_god_group", "(이)가")]


@pytest.mark.parametrize("text", ["[[인성", "인성]]", "[[ [[인성]] ]]", "[[]]", "[[인성]] ]]"])
def test_parse_tokens_errors(text: str) -> None:
    with pytest.raises(ValueError):
        parse_tokens(text)


@pytest.mark.parametrize(("value", "expected"), [("보라", "보라가 와요"), ("남색", "남색이 와요")])
def test_substitute_josa_after_token_follows_value(value: str, expected: str) -> None:
    assert substitute("[[{x:cat}]](이)가 와요", lambda _placeholder: value) == expected
