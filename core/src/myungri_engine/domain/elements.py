"""오행 상생·상극 관계."""

from __future__ import annotations

from myungri_engine.domain.enums import Element

_CYCLE: tuple[Element, ...] = (Element.WOOD, Element.FIRE, Element.EARTH, Element.METAL, Element.WATER)


def _shift(element: Element, steps: int) -> Element:
    return _CYCLE[(_CYCLE.index(element) + steps) % len(_CYCLE)]


def generates(element: Element) -> Element:
    """내가 생(生)하는 오행."""
    return _shift(element, 1)


def generated_by(element: Element) -> Element:
    """나를 생하는 오행."""
    return _shift(element, -1)


def controls(element: Element) -> Element:
    """내가 극(剋)하는 오행."""
    return _shift(element, 2)


def controlled_by(element: Element) -> Element:
    """나를 극하는 오행."""
    return _shift(element, -2)
