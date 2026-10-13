"""신강·신약 점수와 오행 분포 (spec 6.1)."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from types import MappingProxyType

from myungli_engine.calendar_core.lunar_adapter import hidden_stems
from myungli_engine.constants.calibration import STRENGTH_THRESHOLDS
from myungli_engine.domain.elements import generated_by
from myungli_engine.domain.enums import Element, Stem, StrengthLevel
from myungli_engine.domain.models import FourPillars, Pillar

STEM_WEIGHT = 1.0
BRANCH_WEIGHT = 1.5
MONTH_BRANCH_WEIGHT = 3.0

# 지장간 개수별 (정기, 중기, 여기) 비율. 첫 항목이 정기다.
_HIDDEN_STEM_RATIOS: Mapping[int, tuple[float, ...]] = MappingProxyType(
    {1: (1.0,), 2: (0.7, 0.3), 3: (0.6, 0.3, 0.1)}
)


@dataclass(frozen=True, slots=True)
class StrengthResult:
    score: float
    level: StrengthLevel
    element_weights: Mapping[Element, float]


def element_weights(pillars: FourPillars) -> Mapping[Element, float]:
    """일간 자신을 뺀 오행별 가중 합. 시주가 없으면 시주 두 자리를 뺀다."""
    weights = dict.fromkeys(Element, 0.0)

    def add_stem(stem: Stem) -> None:
        weights[stem.element] += STEM_WEIGHT

    def add_branch(pillar: Pillar, branch_weight: float) -> None:
        stems = hidden_stems(pillar.branch)
        for stem, ratio in zip(stems, _HIDDEN_STEM_RATIOS[len(stems)], strict=True):
            weights[stem.element] += branch_weight * ratio

    add_stem(pillars.year.stem)
    add_stem(pillars.month.stem)
    add_branch(pillars.year, BRANCH_WEIGHT)
    add_branch(pillars.month, MONTH_BRANCH_WEIGHT)
    add_branch(pillars.day, BRANCH_WEIGHT)
    if pillars.hour is not None:
        add_stem(pillars.hour.stem)
        add_branch(pillars.hour, BRANCH_WEIGHT)
    return MappingProxyType(weights)


def strength_score(pillars: FourPillars, weights: Mapping[Element, float] | None = None) -> float:
    """100 x (일간과 같은 오행 + 일간을 생하는 오행의 가중 합) / 전체 가중 합."""
    weights = element_weights(pillars) if weights is None else weights
    day_element = pillars.day.stem.element
    support = weights[day_element] + weights[generated_by(day_element)]
    return 100 * support / sum(weights.values())


def level_for_score(score: float) -> StrengthLevel:
    """score < T1 이면 VERY_WEAK ... 경계값 자체는 더 높은 등급에 속한다."""
    t1, t2, t3, t4 = STRENGTH_THRESHOLDS
    if score < t1:
        return StrengthLevel.VERY_WEAK
    if score < t2:
        return StrengthLevel.WEAK
    if score < t3:
        return StrengthLevel.NEUTRAL
    if score < t4:
        return StrengthLevel.STRONG
    return StrengthLevel.VERY_STRONG


def compute_strength(pillars: FourPillars) -> StrengthResult:
    weights = element_weights(pillars)
    score = strength_score(pillars, weights)
    return StrengthResult(score=score, level=level_for_score(score), element_weights=weights)
