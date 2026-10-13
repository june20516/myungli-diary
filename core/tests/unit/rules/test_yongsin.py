import pytest

from myungli_engine.constants.calibration import JOHU_SUMMER_FIRE_SHARE, JOHU_WINTER_WATER_SHARE
from myungli_engine.domain.elements import controlled_by, generated_by
from myungli_engine.domain.enums import Branch as B
from myungli_engine.domain.enums import Element, StrengthLevel, YongsinMethod
from myungli_engine.domain.enums import Stem as S
from myungli_engine.domain.models import FourPillars, Pillar
from myungli_engine.references import loader
from myungli_engine.rules.strength import StrengthResult
from myungli_engine.rules.yongsin import determine_yongsin


def pillars(day_stem: S, month_branch: B) -> FourPillars:
    return FourPillars(
        year=Pillar(S.GAP, B.JA),
        month=Pillar(S.GAP, month_branch),
        day=Pillar(day_stem, B.IN),
        hour=None,
    )


def strength(level: StrengthLevel, weights: dict[Element, float]) -> StrengthResult:
    full = dict.fromkeys(Element, 0.0) | weights
    return StrengthResult(score=40.0, level=level, element_weights=full)


def test_summer_fire_heavy_uses_johu() -> None:
    fire_share = JOHU_SUMMER_FIRE_SHARE
    weights = {Element.FIRE: fire_share * 10, Element.WOOD: (1 - fire_share) * 10}
    result = determine_yongsin(pillars(S.BYEONG, B.O), strength(StrengthLevel.WEAK, weights))
    assert result.method is YongsinMethod.JOHU
    assert result.yongsin is Element.WATER
    assert result.johu_stem is S.IM
    assert result.evidence[0].source_ref == loader.johu_ref(S.BYEONG, B.O)
    assert result.evidence[0].rule_id == "yongsin/johu"
    loader.validate_refs(e.source_ref for e in result.evidence)


def test_winter_water_heavy_uses_johu() -> None:
    water_share = JOHU_WINTER_WATER_SHARE
    weights = {Element.WATER: water_share * 10, Element.WOOD: (1 - water_share) * 10}
    result = determine_yongsin(pillars(S.GAP, B.JA), strength(StrengthLevel.STRONG, weights))
    assert result.method is YongsinMethod.JOHU
    assert result.yongsin is Element.FIRE
    assert result.johu_stem is S.JEONG


def test_share_below_threshold_falls_through_to_eokbu() -> None:
    weights = {Element.FIRE: 2.9, Element.WOOD: 7.1}
    result = determine_yongsin(pillars(S.GAP, B.O), strength(StrengthLevel.WEAK, weights))
    assert result.method is YongsinMethod.EOKBU


def test_neutral_uses_johu_neutral() -> None:
    result = determine_yongsin(pillars(S.GAP, B.MYO), strength(StrengthLevel.NEUTRAL, {Element.WOOD: 5.0}))
    assert result.method is YongsinMethod.JOHU_NEUTRAL
    assert result.johu_stem is not None
    assert result.yongsin is result.johu_stem.element
    assert result.evidence[0].rule_id == "yongsin/johu_neutral"
    assert result.evidence[0].source_ref == loader.johu_ref(S.GAP, B.MYO)


def test_weak_uses_inseong() -> None:
    result = determine_yongsin(pillars(S.GAP, B.MYO), strength(StrengthLevel.WEAK, {Element.WOOD: 5.0}))
    assert result.yongsin is Element.WATER
    assert result.method is YongsinMethod.EOKBU
    assert result.johu_stem is None
    evidence = result.evidence[0]
    assert evidence.rule_id == "yongsin/eokbu"
    assert evidence.source_ref == loader.FIVE_ELEMENTS_REF["balance_principle"]
    assert evidence.detail["strength_level"] == "WEAK"
    assert evidence.detail["strength_score"] == "40.0000"
    loader.validate_refs([evidence.source_ref])


def test_very_weak_uses_inseong() -> None:
    result = determine_yongsin(pillars(S.GAP, B.MYO), strength(StrengthLevel.VERY_WEAK, {}))
    assert result.yongsin is Element.WATER


@pytest.mark.parametrize("level", [StrengthLevel.STRONG, StrengthLevel.VERY_STRONG])
def test_strong_uses_weakest_output(level: StrengthLevel) -> None:
    weights = {Element.FIRE: 3.0, Element.EARTH: 1.0, Element.METAL: 2.0}
    result = determine_yongsin(pillars(S.GAP, B.MYO), strength(level, weights))
    assert result.yongsin is Element.EARTH
    assert result.method is YongsinMethod.EOKBU


def test_strong_tie_order() -> None:
    weights = {Element.FIRE: 1.0, Element.EARTH: 1.0, Element.METAL: 1.0}
    result = determine_yongsin(pillars(S.GAP, B.MYO), strength(StrengthLevel.STRONG, weights))
    assert result.yongsin is Element.FIRE

    weights = {Element.FIRE: 2.0, Element.EARTH: 1.0, Element.METAL: 1.0}
    result = determine_yongsin(pillars(S.GAP, B.MYO), strength(StrengthLevel.STRONG, weights))
    assert result.yongsin is Element.EARTH


@pytest.mark.parametrize("level", list(StrengthLevel))
def test_derived_elements(level: StrengthLevel) -> None:
    result = determine_yongsin(pillars(S.GAP, B.MYO), strength(level, {Element.FIRE: 1.0}))
    assert result.huisin is generated_by(result.yongsin)
    assert result.gisin is controlled_by(result.yongsin)
    assert result.tonggwan is result.huisin
