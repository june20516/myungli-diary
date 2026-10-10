import pytest

from mlw.placeholders import Placeholder, parse


def test_parse() -> None:
    assert parse("{name}님, {element:color}(이)가 좋아요") == [
        Placeholder("name", None, None),
        Placeholder("element", "color", "(이)가"),
    ]


def test_parse_unclosed_raises() -> None:
    with pytest.raises(ValueError):
        parse("{name")
