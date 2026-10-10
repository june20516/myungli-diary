"""신살 판정 (spec 5.4). 원국 표시용 자리와 데일리 발동 판정용 지지 집합을 만든다."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass

from myungri_engine.calendar_core.lunar_adapter import day_gongmang
from myungri_engine.chart.positions import BRANCH_POSITIONS, Position
from myungri_engine.constants.gwiin import CHEONEUL_GWIIN
from myungri_engine.constants.shinsal import DOHWA, HWAGAE, YANGIN, YEOKMA
from myungri_engine.domain.enums import Branch, Shinsal
from myungri_engine.domain.models import FourPillars

# 연지·일지 각각을 기준으로 삼는 삼합 계열 신살
_GROUP_BASED_SHINSAL: dict[Shinsal, Mapping[Branch, Branch]] = {
    Shinsal.DOHWA: DOHWA,
    Shinsal.YEOKMA: YEOKMA,
    Shinsal.HWAGAE: HWAGAE,
}


@dataclass(frozen=True, slots=True)
class ShinsalHit:
    kind: Shinsal
    position: Position


def shinsal_branches(pillars: FourPillars) -> Mapping[Shinsal, frozenset[Branch]]:
    """신살마다 해당하는 지지 집합. 오늘 지지가 여기에 들면 발동이다 (D13)."""
    day_stem = pillars.day.stem
    result: dict[Shinsal, frozenset[Branch]] = {
        Shinsal.CHEONEUL_GWIIN: CHEONEUL_GWIIN[day_stem],
        Shinsal.YANGIN: frozenset({YANGIN[day_stem]}) if day_stem in YANGIN else frozenset(),
        Shinsal.GONGMANG: day_gongmang(pillars.day),
    }
    base_branches = (pillars.year.branch, pillars.day.branch)
    for kind, table in _GROUP_BASED_SHINSAL.items():
        result[kind] = frozenset(table[base] for base in base_branches)
    return {kind: result[kind] for kind in Shinsal}


def natal_shinsal(pillars: FourPillars) -> tuple[ShinsalHit, ...]:
    """원국 안에 실제로 있는 신살과 그 자리. 시주가 없으면 시지 자리는 보지 않는다."""
    target_branches = shinsal_branches(pillars)
    present = {position: _branch_at(pillars, position) for position in BRANCH_POSITIONS}
    return tuple(
        ShinsalHit(kind, position)
        for kind, targets in target_branches.items()
        for position, branch in present.items()
        if branch is not None and branch in targets
    )


def activated(branches: Mapping[Shinsal, frozenset[Branch]], today: Branch) -> tuple[Shinsal, ...]:
    return tuple(kind for kind, targets in branches.items() if today in targets)


def _branch_at(pillars: FourPillars, position: Position) -> Branch | None:
    by_position = {
        Position.YEAR_BRANCH: pillars.year.branch,
        Position.MONTH_BRANCH: pillars.month.branch,
        Position.DAY_BRANCH: pillars.day.branch,
        Position.HOUR_BRANCH: pillars.hour.branch if pillars.hour else None,
    }
    return by_position[position]
