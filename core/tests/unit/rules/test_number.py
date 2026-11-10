import pytest

from myungli_engine.domain.enums import Element, Stem
from myungli_engine.rules.number import hado_pair, lucky_number


@pytest.mark.parametrize(
    ("element", "stem", "expected"),
    [
        (Element.FIRE, Stem.BYEONG, 7),
        (Element.FIRE, Stem.JEONG, 2),
        (Element.WATER, Stem.IM, 1),
        (Element.WATER, Stem.GYE, 6),
        (Element.EARTH, Stem.MU, 5),
        (Element.EARTH, Stem.GI, 10),
    ],
)
def test_lucky_number(element: Element, stem: Stem, expected: int) -> None:
    assert lucky_number(element, stem) == expected


@pytest.mark.parametrize(
    ("element", "number", "pair"), [(Element.FIRE, 7, 2), (Element.FIRE, 2, 7), (Element.EARTH, 10, 5)]
)
def test_hado_pair(element: Element, number: int, pair: int) -> None:
    assert hado_pair(element, number) == pair
