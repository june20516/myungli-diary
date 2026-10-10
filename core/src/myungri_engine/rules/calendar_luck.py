"""월간 캘린더의 날짜별 길흉 점수와 수준 (spec 8). 각 항목은 해당하면 한 번만 더한다."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

from myungri_engine.chart.positions import Position
from myungri_engine.domain.enums import DayKind, LuckLevel
from myungri_engine.rules.relations import Relation, RelationKind, active

GOOD_THRESHOLD = 2
CAUTION_THRESHOLD = -2

DAY_KIND_SCORES: dict[DayKind, tuple[str, int]] = {
    DayKind.GWIIN_DAY: ("gwiin_day", 2),
    DayKind.YONGSIN_DAY: ("yongsin_day", 2),
    DayKind.GISIN_DAY: ("gisin_day", -1),
}
HAP_SCORE = 1
CHUNG_DAY_OR_MONTH_SCORE = -2
CHUNG_OTHER_SCORE = -1
HYEONG_SCORE = -1
DAY_OR_MONTH_BRANCH = frozenset({Position.DAY_BRANCH, Position.MONTH_BRANCH})


@dataclass(frozen=True, slots=True)
class LuckScore:
    score: int
    level: LuckLevel
    breakdown: tuple[tuple[str, int], ...]


def score_day(kind: DayKind, relations: Sequence[Relation]) -> LuckScore:
    live = active(relations)
    kinds = {relation.kind for relation in live}
    chung_positions = {relation.natal_position for relation in live if relation.kind == RelationKind.CHUNG}

    breakdown: list[tuple[str, int]] = []
    if kind in DAY_KIND_SCORES:
        breakdown.append(DAY_KIND_SCORES[kind])
    if kinds & {RelationKind.STEM_HAP, RelationKind.BRANCH_HAP}:
        breakdown.append(("hap", HAP_SCORE))
    if chung_positions & DAY_OR_MONTH_BRANCH:
        breakdown.append(("chung_day_or_month", CHUNG_DAY_OR_MONTH_SCORE))
    if chung_positions - DAY_OR_MONTH_BRANCH:
        breakdown.append(("chung_other", CHUNG_OTHER_SCORE))
    if RelationKind.HYEONG in kinds:
        breakdown.append(("hyeong", HYEONG_SCORE))

    total = sum(points for _, points in breakdown)
    return LuckScore(total, _level_of(total), tuple(breakdown))


def _level_of(total: int) -> LuckLevel:
    if total >= GOOD_THRESHOLD:
        return LuckLevel.GOOD
    if total <= CAUTION_THRESHOLD:
        return LuckLevel.CAUTION
    return LuckLevel.NEUTRAL
