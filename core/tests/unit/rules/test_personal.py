import pytest

from myungri_engine.chart.positions import Position
from myungri_engine.constants.message_keys import require
from myungri_engine.domain.enums import (
    Branch,
    Element,
    Shinsal,
    Stem,
    StrengthLevel,
    TenGod,
    TwelveStage,
    YongsinMethod,
)
from myungri_engine.domain.models import Evidence, FourPillars, Pillar
from myungri_engine.references.loader import FIVE_ELEMENTS_REF
from myungri_engine.rules.personal import (
    PersonalRole,
    _judgment,
    day_master_reading,
    element_role,
    luck_ten_god_reading,
    luck_twelve_stage_reading,
    shinsal_reading,
    ten_god_reading,
    twelve_stage_reading,
)
from myungri_engine.rules.strength import StrengthResult
from myungri_engine.rules.yongsin import YongsinResult

YONGSIN_EVIDENCE = (Evidence(rule_id="yongsin/test", source_ref="ref", detail={"k": "v"}),)


def make_yongsin() -> YongsinResult:
    return YongsinResult(
        yongsin=Element.FIRE,
        huisin=Element.WOOD,
        gisin=Element.WATER,
        tonggwan=Element.WOOD,
        method=YongsinMethod.JOHU,
        johu_stem=Stem.BYEONG,
        evidence=YONGSIN_EVIDENCE,
    )


def make_strength(level: StrengthLevel = StrengthLevel.STRONG) -> StrengthResult:
    return StrengthResult(score=1.0, level=level, element_weights=dict.fromkeys(Element, 1.0))


# 일간 甲: 식상 묶음은 천간 丙·丙과 午 정기 丁으로 3개
NATAL = FourPillars(
    year=Pillar(Stem.GAP, Branch.JA),
    month=Pillar(Stem.BYEONG, Branch.IN),
    day=Pillar(Stem.GAP, Branch.O),
    hour=Pillar(Stem.BYEONG, Branch.MYO),
)


def test_element_role_priority():
    yongsin = make_yongsin()
    assert element_role(Element.FIRE, yongsin) is PersonalRole.YONGSIN
    assert element_role(Element.WOOD, yongsin) is PersonalRole.HUISIN
    assert element_role(Element.WATER, yongsin) is PersonalRole.GISIN
    assert element_role(Element.EARTH, yongsin) is PersonalRole.NEUTRAL
    assert element_role(Element.METAL, yongsin) is PersonalRole.NEUTRAL


def test_element_role_yongsin_wins_over_later_roles():
    overlapping = YongsinResult(
        yongsin=Element.FIRE,
        huisin=Element.FIRE,
        gisin=Element.FIRE,
        tonggwan=Element.FIRE,
        method=YongsinMethod.JOHU,
        johu_stem=None,
        evidence=(),
    )
    assert element_role(Element.FIRE, overlapping) is PersonalRole.YONGSIN


def test_day_master_reading_key_and_params():
    judgment = day_master_reading(Stem.GAP, make_strength(), make_yongsin())
    assert judgment.message_key == "personal.day_master.gap"
    assert judgment.params == {"strength": "STRONG", "yongsin": "FIRE", "gisin": "WATER"}
    require(judgment.message_key, judgment.params)


def test_ten_god_reading_key_and_params():
    judgment = ten_god_reading(
        TenGod.SIKSIN, Position.MONTH_STEM, False, Stem.BYEONG, NATAL, make_strength(), make_yongsin()
    )
    assert judgment.message_key == "personal.ten_god.siksin"
    assert judgment.params == {
        "place": "MONTH_STEM",
        "element": "FIRE",
        "role": "YONGSIN",
        "group_count": 3,
        "strength": "STRONG",
    }
    require(judgment.message_key, judgment.params)


def test_hidden_place_suffix():
    judgment = ten_god_reading(
        TenGod.SIKSIN, Position.MONTH_BRANCH, True, Stem.BYEONG, NATAL, make_strength(), make_yongsin()
    )
    assert judgment.params["place"] == "MONTH_BRANCH_HIDDEN"


def test_twelve_stage_reading_uses_branch_element():
    judgment = twelve_stage_reading(
        TwelveStage.JEWANG, Position.DAY_BRANCH, Branch.O, make_strength(), make_yongsin()
    )
    assert judgment.message_key == "personal.twelve_stage.jewang"
    assert judgment.params == {
        "place": "DAY_BRANCH",
        "element": "FIRE",
        "role": "YONGSIN",
        "strength": "STRONG",
    }
    require(judgment.message_key, judgment.params)


def test_shinsal_reading():
    judgment = shinsal_reading(Shinsal.DOHWA, Position.YEAR_BRANCH, Branch.JA, make_yongsin())
    assert judgment.message_key == "personal.shinsal.dohwa"
    assert judgment.params == {"place": "YEAR_BRANCH", "element": "WATER", "role": "GISIN"}
    require(judgment.message_key, judgment.params)


def test_luck_reading_current_flag():
    current = luck_ten_god_reading(TenGod.PYEONGWAN, "DAEUN", "STEM", Stem.GYEONG, True, make_yongsin())
    other = luck_ten_god_reading(TenGod.PYEONGWAN, "DAEUN", "STEM", Stem.GYEONG, False, make_yongsin())
    assert current.message_key == "personal.luck.ten_god.pyeongwan"
    assert current.params == {
        "luck": "DAEUN",
        "part": "STEM",
        "element": "METAL",
        "role": "NEUTRAL",
        "current": True,
    }
    assert current.params["current"] is True
    assert other.params["current"] is False
    require(current.message_key, current.params)


def test_luck_twelve_stage_reading():
    judgment = luck_twelve_stage_reading(TwelveStage.MYO, Branch.SUL, False, make_yongsin())
    assert judgment.message_key == "personal.luck.twelve_stage.myo"
    assert judgment.params == {"element": "EARTH", "role": "NEUTRAL", "current": False}
    require(judgment.message_key, judgment.params)


def test_every_reading_has_balance_and_yongsin_evidence():
    yongsin = make_yongsin()
    strength = make_strength()
    readings = {
        "day_master": day_master_reading(Stem.GAP, strength, yongsin),
        "ten_god": ten_god_reading(
            TenGod.SIKSIN, Position.MONTH_STEM, False, Stem.BYEONG, NATAL, strength, yongsin
        ),
        "twelve_stage": twelve_stage_reading(
            TwelveStage.JEWANG, Position.DAY_BRANCH, Branch.O, strength, yongsin
        ),
        "shinsal": shinsal_reading(Shinsal.DOHWA, Position.YEAR_BRANCH, Branch.JA, yongsin),
        "luck_ten_god": luck_ten_god_reading(TenGod.PYEONGWAN, "SEUN", "BRANCH", Stem.GYEONG, True, yongsin),
        "luck_twelve_stage": luck_twelve_stage_reading(TwelveStage.MYO, Branch.SUL, False, yongsin),
    }
    for bundle, judgment in readings.items():
        first = judgment.evidence[0]
        assert first.rule_id == f"personal/{bundle}"
        assert first.source_ref == FIVE_ELEMENTS_REF["balance_principle"]
        assert dict(first.detail) == {
            k: str(v).lower() if isinstance(v, bool) else str(v) for k, v in judgment.params.items()
        }
        assert judgment.evidence[1:] == yongsin.evidence


def test_judgment_rejects_params_differing_from_declaration():
    with pytest.raises(KeyError):
        _judgment("day_master", "personal.day_master.gap", {"strength": "STRONG"}, make_yongsin())


def test_day_master_reading_passes_non_strong_level_name():
    judgment = day_master_reading(Stem.GAP, make_strength(StrengthLevel.VERY_WEAK), make_yongsin())
    assert judgment.params["strength"] == "VERY_WEAK"
