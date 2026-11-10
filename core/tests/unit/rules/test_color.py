from dataclasses import replace

import pytest

from myungli_engine.domain.enums import Branch, ColorShift, DayKind, Element, Stem, TwelveStage
from myungli_engine.domain.models import Pillar
from myungli_engine.references import loader
from myungli_engine.references.loader import COLOR_SHIFT_REF, FIVE_ELEMENTS_REF
from myungli_engine.rules.color import SHIFT_BY_STAGE, ElementRole, lucky_element
from myungli_engine.rules.yongsin import YongsinResult


def _day(branch: str) -> Pillar:
    return Pillar(stem=Stem.GAP, branch=Branch.from_hanja(branch))


@pytest.mark.parametrize(
    ("kind", "base", "role"),
    [
        (DayKind.GISIN_DAY, Element.WOOD, ElementRole.TONGGWAN),
        (DayKind.GWIIN_DAY, Element.FIRE, ElementRole.YONGSIN),
        (DayKind.YONGSIN_DAY, Element.FIRE, ElementRole.YONGSIN),
        (DayKind.ORDINARY_DAY, Element.FIRE, ElementRole.YONGSIN),
    ],
)
def test_base_element_by_day_kind(
    kind: DayKind, base: Element, role: ElementRole, winter_gap: YongsinResult
) -> None:
    pick = lucky_element(kind, winter_gap, _day("午"))
    assert (pick.base_element, pick.role) == (base, role)
    assert [e.rule_id for e in pick.evidence] == ["color/lucky_element", "color/shift"]
    assert [e.source_ref for e in pick.evidence] == [FIVE_ELEMENTS_REF["color"], COLOR_SHIFT_REF]
    loader.validate_refs(e.source_ref for e in pick.evidence)


# 용신 화(丙 기준 12운성): 寅 長生, 辰 冠帶, 未 衰, 申 病, 酉 死, 戌 墓
@pytest.mark.parametrize(
    ("branch", "stage", "shift", "element"),
    [
        ("寅", TwelveStage.JANGSAENG, ColorShift.JEONG, Element.FIRE),
        ("辰", TwelveStage.GWANDAE, ColorShift.CHEO, Element.METAL),
        ("未", TwelveStage.SOE, ColorShift.CHEO, Element.METAL),
        ("申", TwelveStage.BYEONG, ColorShift.GWI, Element.WATER),
        ("酉", TwelveStage.SA, ColorShift.MO, Element.WOOD),
        ("戌", TwelveStage.MYO, ColorShift.JA, Element.EARTH),
    ],
)
def test_color_follows_twelve_stage_of_base(
    branch: str, stage: TwelveStage, shift: ColorShift, element: Element, winter_gap: YongsinResult
) -> None:
    pick = lucky_element(DayKind.YONGSIN_DAY, winter_gap, _day(branch))
    assert (pick.stage, pick.shift, pick.element) == (stage, shift, element)
    assert pick.evidence[1].detail == {
        "base_element": "FIRE",
        "day_branch": branch,
        "twelve_stage": stage.name,
        "shift": shift.name,
        "element": element.name,
    }


def test_every_stage_has_a_shift() -> None:
    assert set(SHIFT_BY_STAGE) == set(TwelveStage)


@pytest.mark.parametrize("base", list(Element))
def test_twelve_branches_give_all_five_colors(base: Element, winter_gap: YongsinResult) -> None:
    yongsin = replace(winter_gap, yongsin=base)
    colors = {lucky_element(DayKind.YONGSIN_DAY, yongsin, _day(b.hanja)).element for b in Branch}
    assert colors == set(Element)


def test_metal_base_passes_source_note(winter_gap: YongsinResult) -> None:
    metal = replace(winter_gap, yongsin=Element.METAL)
    pick = lucky_element(DayKind.YONGSIN_DAY, metal, _day("午"))
    assert "金" in pick.evidence[0].detail["note"]
    assert "note" not in lucky_element(DayKind.YONGSIN_DAY, winter_gap, _day("午")).evidence[0].detail
    assert "note" not in pick.evidence[1].detail
