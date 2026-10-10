"""용신·희신·기신·통관 오행 판정 (spec 6.2)."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from types import MappingProxyType
from typing import Final

from myungri_engine.constants.calibration import JOHU_SUMMER_FIRE_SHARE, JOHU_WINTER_WATER_SHARE
from myungri_engine.constants.johu import JOHU_YONGSIN
from myungri_engine.domain.elements import controlled_by, controls, generated_by, generates
from myungri_engine.domain.enums import Branch, Element, Stem, StrengthLevel, YongsinMethod
from myungri_engine.domain.models import Evidence, FourPillars
from myungri_engine.references.loader import FIVE_ELEMENTS_REF, johu_ref
from myungri_engine.rules.strength import StrengthResult

# 조후를 우선하는 계절의 월지 -> (비중을 보는 오행, 기준 비중)
_JOHU_SEASONS: Final[Mapping[Branch, tuple[Element, float]]] = MappingProxyType(
    {
        **dict.fromkeys((Branch.SA, Branch.O, Branch.MI), (Element.FIRE, JOHU_SUMMER_FIRE_SHARE)),
        **dict.fromkeys((Branch.HAE, Branch.JA, Branch.CHUK), (Element.WATER, JOHU_WINTER_WATER_SHARE)),
    }
)

_WEAK_LEVELS: Final = (StrengthLevel.VERY_WEAK, StrengthLevel.WEAK)


@dataclass(frozen=True, slots=True)
class YongsinResult:
    yongsin: Element
    huisin: Element
    gisin: Element
    tonggwan: Element
    method: YongsinMethod
    johu_stem: Stem | None
    evidence: tuple[Evidence, ...]


def _johu_share(strength: StrengthResult, element: Element) -> float:
    return strength.element_weights[element] / sum(strength.element_weights.values())


def _is_johu_priority(month_branch: Branch, strength: StrengthResult) -> tuple[float, float] | None:
    """조후 우선 조건을 만족하면 (비중, 기준값), 아니면 None."""
    season = _JOHU_SEASONS.get(month_branch)
    if season is None:
        return None
    element, threshold = season
    share = _johu_share(strength, element)
    return (share, threshold) if share >= threshold else None


def _eokbu_yongsin(day_element: Element, strength: StrengthResult) -> Element:
    if strength.level in _WEAK_LEVELS:
        return generated_by(day_element)
    # 동점이면 식상 -> 재성 -> 관성 순 (min은 먼저 나온 값을 고른다)
    candidates = (generates(day_element), controls(day_element), controlled_by(day_element))
    return min(candidates, key=lambda element: strength.element_weights[element])


def _result(
    yongsin: Element, method: YongsinMethod, johu_stem: Stem | None, evidence: Evidence
) -> YongsinResult:
    huisin = generated_by(yongsin)
    return YongsinResult(
        yongsin=yongsin,
        huisin=huisin,
        gisin=controlled_by(yongsin),
        tonggwan=huisin,
        method=method,
        johu_stem=johu_stem,
        evidence=(evidence,),
    )


def determine_yongsin(pillars: FourPillars, strength: StrengthResult) -> YongsinResult:
    day_stem = pillars.day.stem
    month_branch = pillars.month.branch
    johu_ref_value = johu_ref(day_stem, month_branch)
    johu_stem = JOHU_YONGSIN[day_stem][month_branch][0]

    johu_condition = _is_johu_priority(month_branch, strength)
    if johu_condition is not None:
        share, threshold = johu_condition
        evidence = Evidence(
            "yongsin/johu",
            johu_ref_value,
            {"share": f"{share:.4f}", "threshold": f"{threshold:.4f}", "month_branch": month_branch.hanja},
        )
        return _result(johu_stem.element, YongsinMethod.JOHU, johu_stem, evidence)

    if strength.level is StrengthLevel.NEUTRAL:
        evidence = Evidence("yongsin/johu_neutral", johu_ref_value, {"strength_level": strength.level.name})
        return _result(johu_stem.element, YongsinMethod.JOHU_NEUTRAL, johu_stem, evidence)

    evidence = Evidence(
        "yongsin/eokbu",
        FIVE_ELEMENTS_REF["balance_principle"],
        {"strength_score": f"{strength.score:.4f}", "strength_level": strength.level.name},
    )
    return _result(_eokbu_yongsin(day_stem.element, strength), YongsinMethod.EOKBU, None, evidence)
