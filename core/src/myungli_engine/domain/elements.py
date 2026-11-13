"""오행 상생·상극 관계."""

from __future__ import annotations

from myungli_engine.domain.enums import Element, ElementRelation

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


def relation_to(base: Element, other: Element) -> ElementRelation:
    """바탕 오행(base)에서 본 other의 관계(D130)."""
    if other is base:
        return ElementRelation.SAME
    if other is generated_by(base):
        return ElementRelation.MO
    if other is generates(base):
        return ElementRelation.JA
    if other is controls(base):
        return ElementRelation.CHEO
    return ElementRelation.GWI
