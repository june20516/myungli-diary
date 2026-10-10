"""나의 사주 view와 데일리·월간이 함께 쓰는 원국 준비 (spec 5, 6)."""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from datetime import date

from myungri_engine.calendar_core.birth import (
    BirthInput,
    BirthMoment,
    resolve_birth_moment,
    validate_civil_date,
)
from myungri_engine.chart.luck_cycles import LuckCycles, build_luck_cycles
from myungri_engine.chart.pillars import Chart, build_chart
from myungri_engine.chart.shinsal import shinsal_branches
from myungri_engine.constants.gwiin import CHEONEUL_GWIIN
from myungri_engine.constants.message_keys import require
from myungri_engine.domain.enums import Branch, Shinsal
from myungri_engine.domain.models import Judgment, Notice
from myungri_engine.rules.strength import StrengthResult, compute_strength
from myungri_engine.rules.yongsin import YongsinResult, determine_yongsin


@dataclass(frozen=True, slots=True)
class NatalContext:
    """한 요청에서 한 번만 계산하는 원국·강약·용신·신살 지지 집합."""

    moment: BirthMoment
    chart: Chart
    strength: StrengthResult
    yongsin: YongsinResult
    gwiin: frozenset[Branch]
    shinsal_branches: Mapping[Shinsal, frozenset[Branch]]


@dataclass(frozen=True, slots=True)
class ChartView:
    chart: Chart
    strength: StrengthResult
    yongsin: YongsinResult
    yongsin_judgment: Judgment
    luck: LuckCycles
    notices: tuple[Notice, ...]


def prepare_natal(birth: BirthInput) -> NatalContext:
    moment = resolve_birth_moment(birth)
    chart = build_chart(moment)
    strength = compute_strength(chart.pillars)
    return NatalContext(
        moment=moment,
        chart=chart,
        strength=strength,
        yongsin=determine_yongsin(chart.pillars, strength),
        gwiin=CHEONEUL_GWIIN[chart.pillars.day.stem],
        shinsal_branches=shinsal_branches(chart.pillars),
    )


def merge_notices(*groups: Iterable[Notice]) -> tuple[Notice, ...]:
    """중복을 빼고 처음 나온 순서를 지킨다."""
    return tuple(dict.fromkeys(notice for group in groups for notice in group))


def yongsin_judgment(yongsin: YongsinResult) -> Judgment:
    return Judgment(
        message_key=require(f"yongsin.method.{yongsin.method.name.lower()}"),
        params={
            "yongsin": yongsin.yongsin.name,
            "huisin": yongsin.huisin.name,
            "gisin": yongsin.gisin.name,
            "tonggwan": yongsin.tonggwan.name,
        },
        evidence=yongsin.evidence,
    )


def compose_chart(birth: BirthInput, as_of: date) -> ChartView:
    validate_civil_date(as_of)
    natal = prepare_natal(birth)
    luck = build_luck_cycles(natal.moment, birth.gender, natal.chart.pillars, as_of)
    return ChartView(
        chart=natal.chart,
        strength=natal.strength,
        yongsin=natal.yongsin,
        yongsin_judgment=yongsin_judgment(natal.yongsin),
        luck=luck,
        notices=merge_notices(natal.chart.notices, luck.notices),
    )
