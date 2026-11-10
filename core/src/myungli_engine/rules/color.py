"""행운 컬러의 오행과 역할 (spec 7.2). 색 이름·값은 앱이 정한다.

1. 바탕 오행: 기신의 날은 통관 오행, 그 밖은 용신 오행(D19).
2. 변역(變易): 바탕 오행이 그날 일지에서 놓인 12운성 자리에 따라 제 색, 母色, 妻色, 鬼色, 子色 중
   하나를 따른다(『三命通會』 「論五行」, #937, C33). 최종 색 오행이 행운 색이다.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from enum import Enum, auto
from typing import Final

from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.domain.elements import controlled_by, controls, generated_by, generates
from myungli_engine.domain.enums import ColorShift, DayKind, Element, Stem, TwelveStage
from myungli_engine.domain.models import Evidence, Pillar
from myungli_engine.references import loader
from myungli_engine.references.loader import COLOR_SHIFT_REF, FIVE_ELEMENTS_REF
from myungli_engine.rules.yongsin import YongsinResult


class ElementRole(Enum):
    YONGSIN = auto()
    TONGGWAN = auto()


# 오행의 12운성은 그 오행의 양간으로 본다(土는 戊, 火와 같은 자리).
_YANG_STEM: Final[dict[Element, Stem]] = {
    Element.WOOD: Stem.GAP,
    Element.FIRE: Stem.BYEONG,
    Element.EARTH: Stem.MU,
    Element.METAL: Stem.GYEONG,
    Element.WATER: Stem.IM,
}

# 生旺從正色，死絶從母色，成形冠帶從妻色，病敗從鬼色，旺墓從子色.
# 원문에 없는 臨官, 胎와 두 번 걸린 帝旺, 주로 정한 衰는 명리일기의 해석이다(C33, 근거 note).
SHIFT_BY_STAGE: Final[dict[TwelveStage, ColorShift]] = {
    TwelveStage.JANGSAENG: ColorShift.JEONG,
    TwelveStage.GEONROK: ColorShift.JEONG,
    TwelveStage.JEWANG: ColorShift.JEONG,
    TwelveStage.SA: ColorShift.MO,
    TwelveStage.JEOL: ColorShift.MO,
    TwelveStage.TAE: ColorShift.CHEO,
    TwelveStage.YANG: ColorShift.CHEO,
    TwelveStage.GWANDAE: ColorShift.CHEO,
    TwelveStage.SOE: ColorShift.CHEO,
    TwelveStage.MOKYOK: ColorShift.GWI,
    TwelveStage.BYEONG: ColorShift.GWI,
    TwelveStage.MYO: ColorShift.JA,
}

_SHIFTED: Final[dict[ColorShift, Callable[[Element], Element]]] = {
    ColorShift.JEONG: lambda element: element,
    ColorShift.MO: generated_by,
    ColorShift.CHEO: controls,
    ColorShift.GWI: controlled_by,
    ColorShift.JA: generates,
}


@dataclass(frozen=True, slots=True)
class ElementPick:
    """element는 행운 색 오행(변역 뒤), base_element는 날의 성격으로 고른 바탕 오행."""

    element: Element
    role: ElementRole
    base_element: Element
    stage: TwelveStage
    shift: ColorShift
    evidence: tuple[Evidence, ...]


def _color_note() -> str:
    color = loader.resolve(FIVE_ELEMENTS_REF["color"])
    if not isinstance(color, dict) or not isinstance(color.get("note"), str):
        raise KeyError("five_elements#color에 note가 없습니다")
    return str(color["note"])


def base_element(kind: DayKind, yongsin: YongsinResult) -> tuple[Element, ElementRole]:
    """기신의 날은 통관 오행, 그 밖은 용신 오행."""
    if kind is DayKind.GISIN_DAY:
        return yongsin.tonggwan, ElementRole.TONGGWAN
    return yongsin.yongsin, ElementRole.YONGSIN


def element_stage(element: Element, day: Pillar) -> TwelveStage:
    """오행이 그날 일지에서 놓인 12운성 자리."""
    return lunar_adapter.twelve_stage(_YANG_STEM[element], day.branch)


def lucky_element(kind: DayKind, yongsin: YongsinResult, day: Pillar) -> ElementPick:
    base, role = base_element(kind, yongsin)
    stage = element_stage(base, day)
    shift = SHIFT_BY_STAGE[stage]
    element = _SHIFTED[shift](base)

    base_detail = {"element": base.name, "role": role.name, "day_kind": kind.name}
    if base is Element.METAL:
        base_detail["note"] = _color_note()
    shift_detail = {
        "base_element": base.name,
        "day_branch": day.branch.hanja,
        "twelve_stage": stage.name,
        "shift": shift.name,
        "element": element.name,
    }
    evidence = (
        Evidence(rule_id="color/lucky_element", source_ref=FIVE_ELEMENTS_REF["color"], detail=base_detail),
        Evidence(rule_id="color/shift", source_ref=COLOR_SHIFT_REF, detail=shift_detail),
    )
    return ElementPick(
        element=element, role=role, base_element=base, stage=stage, shift=shift, evidence=evidence
    )
