from dataclasses import replace

import pytest

from myungli_engine.domain.enums import Branch, ColorBasis, ColorShift, DayKind, Element, Stem, TwelveStage
from myungli_engine.domain.models import Evidence, Pillar
from myungli_engine.references import loader
from myungli_engine.references.loader import COLOR_SHIFT_REF, FIVE_ELEMENTS_REF
from myungli_engine.rules.color import SHIFT_BY_STAGE, ElementRole, lucky_colors, lucky_element
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


def _with_evidence(yongsin: YongsinResult) -> YongsinResult:
    """균형 카드는 용신 근거의 원전을 쓰므로 근거가 있는 용신 결과가 필요하다."""
    evidence = Evidence(rule_id="yongsin/johu", source_ref=FIVE_ELEMENTS_REF["balance_principle"], detail={})
    return replace(yongsin, evidence=(evidence,))


@pytest.mark.parametrize(
    ("kind", "branch", "base", "stage"),
    [
        # 용신 화가 申에서 病 → 鬼色 수(기신)
        (DayKind.YONGSIN_DAY, "申", Element.FIRE, TwelveStage.BYEONG),
        # 기신의 날 통관 목이 午에서 死 → 母色 수(기신)
        (DayKind.GISIN_DAY, "午", Element.WOOD, TwelveStage.SA),
    ],
)
def test_two_cards_when_source_color_is_gisin(
    kind: DayKind, branch: str, base: Element, stage: TwelveStage, winter_gap: YongsinResult
) -> None:
    yongsin = _with_evidence(winter_gap)
    balance, source = lucky_colors(kind, yongsin, _day(branch))
    assert (balance.basis, balance.element) == (ColorBasis.BALANCE, base)
    assert (source.basis, source.element) == (ColorBasis.SOURCE, Element.WATER)
    for pick in (balance, source):
        assert (pick.base_element, pick.stage, pick.shift) == (base, stage, source.shift)
    assert [e.rule_id for e in source.evidence] == ["color/lucky_element", "color/shift"]
    assert [e.rule_id for e in balance.evidence] == ["color/lucky_element", "color/shift", "color/balance"]
    assert balance.evidence[-1].detail == {
        "element": base.name,
        "shifted_element": "WATER",
        "gisin": "WATER",
    }
    loader.validate_refs(e.source_ref for e in balance.evidence)


def test_one_card_when_source_color_is_not_gisin(winter_gap: YongsinResult) -> None:
    # 용신 화가 酉에서 死 → 母色 목(희신)
    (pick,) = lucky_colors(DayKind.YONGSIN_DAY, _with_evidence(winter_gap), _day("酉"))
    assert (pick.basis, pick.element) == (ColorBasis.SOURCE, Element.WOOD)


@pytest.mark.parametrize("kind", list(DayKind))
def test_split_days_are_exactly_gisin_colored(kind: DayKind, winter_gap: YongsinResult) -> None:
    yongsin = _with_evidence(winter_gap)
    for branch in Branch:
        cards = lucky_colors(kind, yongsin, _day(branch.hanja))
        source = cards[-1]
        assert source.basis is ColorBasis.SOURCE
        assert (len(cards) == 2) == (source.element is yongsin.gisin)
        assert all(card.element is not yongsin.gisin for card in cards[:-1])
