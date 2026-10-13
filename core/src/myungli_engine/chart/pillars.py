"""원국: 사주팔자와 십성·지장간·12운성·신살·공망 (spec 5.1~5.2, 5.4)."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass

from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.calendar_core.birth import BirthMoment
from myungli_engine.chart.positions import Position
from myungli_engine.chart.shinsal import ShinsalHit, natal_shinsal
from myungli_engine.domain.enums import Branch, Stem, TenGod, TwelveStage
from myungli_engine.domain.models import FourPillars, Notice, Pillar
from myungli_engine.domain.ten_gods import ten_god

__all__ = ["Chart", "Position", "build_chart"]


@dataclass(frozen=True, slots=True)
class Chart:
    pillars: FourPillars
    ten_gods: Mapping[Position, TenGod]
    hidden_stems: Mapping[Position, tuple[tuple[Stem, TenGod], ...]]
    twelve_stages: Mapping[Position, TwelveStage]
    shinsal: tuple[ShinsalHit, ...]
    gongmang: frozenset[Branch]
    notices: tuple[Notice, ...]


def build_chart(moment: BirthMoment) -> Chart:
    pillars = lunar_adapter.pillars_for(moment)
    day_stem = pillars.day.stem

    ten_gods: dict[Position, TenGod] = {}
    hidden: dict[Position, tuple[tuple[Stem, TenGod], ...]] = {}
    stages: dict[Position, TwelveStage] = {}
    for stem_position, branch_position, pillar in _present_pillars(pillars):
        if stem_position is not Position.DAY_STEM:
            ten_gods[stem_position] = ten_god(day_stem, pillar.stem)
        branch_stems = lunar_adapter.hidden_stems(pillar.branch)
        hidden[branch_position] = tuple((stem, ten_god(day_stem, stem)) for stem in branch_stems)
        ten_gods[branch_position] = ten_god(day_stem, branch_stems[0])  # 정기
        stages[branch_position] = lunar_adapter.twelve_stage(day_stem, pillar.branch)

    return Chart(
        pillars=pillars,
        ten_gods=ten_gods,
        hidden_stems=hidden,
        twelve_stages=stages,
        shinsal=natal_shinsal(pillars),
        gongmang=lunar_adapter.day_gongmang(pillars.day),
        notices=moment.notices,
    )


def _present_pillars(pillars: FourPillars) -> tuple[tuple[Position, Position, Pillar], ...]:
    """시간 모름이면 시주를 뺀다."""
    entries = [
        (Position.YEAR_STEM, Position.YEAR_BRANCH, pillars.year),
        (Position.MONTH_STEM, Position.MONTH_BRANCH, pillars.month),
        (Position.DAY_STEM, Position.DAY_BRANCH, pillars.day),
    ]
    if pillars.hour is not None:
        entries.append((Position.HOUR_STEM, Position.HOUR_BRANCH, pillars.hour))
    return tuple(entries)
