"""행운의 숫자 (spec 7.4)."""

from __future__ import annotations

from myungli_engine.constants.numbers import HADO
from myungli_engine.domain.enums import Element, Stem


def lucky_number(element: Element, day_stem: Stem) -> int:
    """하도 수 한 쌍에서 양간이면 홀수, 음간이면 짝수를 고른다."""
    odd, even = sorted(HADO[element], key=lambda number: number % 2 == 0)
    return odd if day_stem.is_yang else even


def hado_pair(element: Element, number: int) -> int:
    """하도 수 한 쌍에서 고른 수의 짝(다른 하나)."""
    return next(other for other in HADO[element] if other != number)
