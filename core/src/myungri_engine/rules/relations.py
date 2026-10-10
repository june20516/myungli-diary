"""합·충·형과 탐합망충 (spec 7.6). 오늘 일진 대 원국의 관계만 판정한다."""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from enum import Enum, auto

from myungri_engine.chart.positions import Position
from myungri_engine.constants.relations import (
    BRANCH_CHUNG,
    BRANCH_HAP,
    BRANCH_HYEONG_GROUPS,
    BRANCH_HYEONG_PAIRS,
    SELF_HYEONG,
    STEM_HAP,
)
from myungri_engine.domain.enums import Branch
from myungri_engine.domain.models import FourPillars, Pillar


class RelationKind(Enum):
    STEM_HAP = auto()
    BRANCH_HAP = auto()
    CHUNG = auto()
    HYEONG = auto()


@dataclass(frozen=True, slots=True)
class Relation:
    kind: RelationKind
    natal_position: Position
    suppressed_by: RelationKind | None


def find_relations(natal: FourPillars, day: Pillar) -> tuple[Relation, ...]:
    """원국 자리 순서(연→시)로, 같은 자리 안에서는 RelationKind 순서로 낸다."""
    natal_slots = (
        (Position.YEAR_STEM, Position.YEAR_BRANCH, natal.year),
        (Position.MONTH_STEM, Position.MONTH_BRANCH, natal.month),
        (Position.DAY_STEM, Position.DAY_BRANCH, natal.day),
        (Position.HOUR_STEM, Position.HOUR_BRANCH, natal.hour),
    )
    # 탐합망충: 오늘 지지가 합하는 원국 자리가 하나라도 있으면 다른 자리와의 충은 무효
    has_branch_hap = any(
        pillar is not None and _is_branch_hap(day.branch, pillar.branch) for _, _, pillar in natal_slots
    )

    relations: list[Relation] = []
    for stem_position, branch_position, pillar in natal_slots:
        if pillar is None:
            continue
        if frozenset({day.stem, pillar.stem}) in STEM_HAP:
            relations.append(Relation(RelationKind.STEM_HAP, stem_position, None))
        if _is_branch_hap(day.branch, pillar.branch):
            relations.append(Relation(RelationKind.BRANCH_HAP, branch_position, None))
        if frozenset({day.branch, pillar.branch}) in BRANCH_CHUNG:
            suppressed_by = RelationKind.BRANCH_HAP if has_branch_hap else None
            relations.append(Relation(RelationKind.CHUNG, branch_position, suppressed_by))
        if _is_hyeong(day.branch, pillar.branch):
            relations.append(Relation(RelationKind.HYEONG, branch_position, None))
    return tuple(relations)


def active(rels: Iterable[Relation]) -> tuple[Relation, ...]:
    return tuple(rel for rel in rels if rel.suppressed_by is None)


def _is_branch_hap(first: Branch, second: Branch) -> bool:
    return frozenset({first, second}) in BRANCH_HAP


def _is_hyeong(first: Branch, second: Branch) -> bool:
    if first == second:
        return first in SELF_HYEONG
    pair = frozenset({first, second})
    return pair in BRANCH_HYEONG_PAIRS or any(pair <= group for group in BRANCH_HYEONG_GROUPS)
