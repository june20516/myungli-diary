"""행운 컬러의 오행과 역할 (spec 7.2). 색 이름·값은 앱이 정한다."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, auto

from myungri_engine.domain.enums import DayKind, Element
from myungri_engine.domain.models import Evidence
from myungri_engine.references import loader
from myungri_engine.references.loader import FIVE_ELEMENTS_REF
from myungri_engine.rules.yongsin import YongsinResult


class ElementRole(Enum):
    YONGSIN = auto()
    TONGGWAN = auto()


@dataclass(frozen=True, slots=True)
class ElementPick:
    element: Element
    role: ElementRole
    evidence: tuple[Evidence, ...]


def _color_note() -> str:
    color = loader.resolve(FIVE_ELEMENTS_REF["color"])
    if not isinstance(color, dict) or not isinstance(color.get("note"), str):
        raise KeyError("five_elements#color에 note가 없습니다")
    return str(color["note"])


def lucky_element(kind: DayKind, yongsin: YongsinResult) -> ElementPick:
    """기신의 날은 통관 오행, 그 밖은 용신 오행."""
    if kind is DayKind.GISIN_DAY:
        element, role = yongsin.tonggwan, ElementRole.TONGGWAN
    else:
        element, role = yongsin.yongsin, ElementRole.YONGSIN

    detail = {"element": element.name, "role": role.name, "day_kind": kind.name}
    if element is Element.METAL:
        detail["note"] = _color_note()
    evidence = Evidence(rule_id="color/lucky_element", source_ref=FIVE_ELEMENTS_REF["color"], detail=detail)
    return ElementPick(element=element, role=role, evidence=(evidence,))
