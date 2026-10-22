"""나의 사주 view와 데일리·월간이 함께 쓰는 원국 준비 (spec 5, 6)."""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from datetime import date

from myungli_engine.calendar_core.birth import (
    BirthInput,
    BirthMoment,
    resolve_birth_moment,
    validate_civil_date,
)
from myungli_engine.calendar_core.lunar_adapter import hidden_stems
from myungli_engine.chart.luck_cycles import LuckCycles, build_luck_cycles
from myungli_engine.chart.personal_target import PersonalReading
from myungli_engine.chart.pillars import Chart, build_chart
from myungli_engine.chart.positions import BRANCH_POSITIONS, Position
from myungli_engine.chart.shinsal import shinsal_branches
from myungli_engine.constants.gwiin import CHEONEUL_GWIIN
from myungli_engine.constants.message_keys import require
from myungli_engine.domain.enums import Branch, PersonalTermKind, Shinsal
from myungli_engine.domain.errors import InvalidInputError
from myungli_engine.domain.models import FourPillars, Judgment, Notice, Pillar
from myungli_engine.rules import personal
from myungli_engine.rules.strength import StrengthResult, compute_strength
from myungli_engine.rules.yongsin import YongsinResult, determine_yongsin


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
    personal_readings: tuple[PersonalReading, ...]


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
    params = {
        "yongsin": yongsin.yongsin.name,
        "huisin": yongsin.huisin.name,
        "gisin": yongsin.gisin.name,
        "tonggwan": yongsin.tonggwan.name,
    }
    return Judgment(
        message_key=require(f"yongsin.method.{yongsin.method.name.lower()}", params),
        params=params,
        evidence=yongsin.evidence,
    )


def compose_chart(birth: BirthInput, as_of: date) -> ChartView:
    validate_civil_date(as_of)
    if birth.gender is None:  # 대운 순행·역행이 성별로 갈린다
        raise InvalidInputError("birth.gender가 없습니다.")
    natal = prepare_natal(birth)
    luck = build_luck_cycles(natal.moment, birth.gender, natal.chart.pillars, as_of)
    return ChartView(
        chart=natal.chart,
        strength=natal.strength,
        yongsin=natal.yongsin,
        yongsin_judgment=yongsin_judgment(natal.yongsin),
        luck=luck,
        notices=merge_notices(natal.chart.notices, luck.notices),
        personal_readings=_personal_readings(natal, luck, as_of),
    )


def _pillar_at(pillars: FourPillars, position: Position) -> Pillar:
    """자리에 해당하는 기둥. 시주가 없는 자리는 요청할 수 없다."""
    by_position = {
        Position.YEAR_STEM: pillars.year,
        Position.YEAR_BRANCH: pillars.year,
        Position.MONTH_STEM: pillars.month,
        Position.MONTH_BRANCH: pillars.month,
        Position.DAY_STEM: pillars.day,
        Position.DAY_BRANCH: pillars.day,
        Position.HOUR_STEM: pillars.hour,
        Position.HOUR_BRANCH: pillars.hour,
    }
    pillar = by_position[position]
    if pillar is None:
        raise ValueError(f"시주가 없어 {position.name} 자리를 찾을 수 없습니다")
    return pillar


def _personal_readings(natal: NatalContext, luck: LuckCycles, as_of: date) -> tuple[PersonalReading, ...]:
    """일간, 원국 십성, 지장간, 12운성, 신살, 대운, 세운 순서의 개인 해석 목록."""
    return (
        *_natal_readings(natal),
        *_daeun_readings(natal, luck, as_of),
        *_seun_readings(natal, luck, as_of),
    )


def _natal_readings(natal: NatalContext) -> tuple[PersonalReading, ...]:
    chart, strength, yongsin = natal.chart, natal.strength, natal.yongsin
    pillars = chart.pillars
    readings = [
        PersonalReading(
            PersonalTermKind.DAY_MASTER,
            Position.DAY_STEM,
            0,
            None,
            personal.day_master_reading(pillars.day.stem, strength, yongsin),
        )
    ]
    for position in Position:
        if position not in chart.ten_gods:
            continue
        pillar = _pillar_at(pillars, position)
        stem = pillar.stem if position not in BRANCH_POSITIONS else hidden_stems(pillar.branch)[0]
        judgment = personal.ten_god_reading(
            chart.ten_gods[position], position, False, stem, pillars, strength, yongsin
        )
        readings.append(PersonalReading(PersonalTermKind.TEN_GOD, position, 0, None, judgment))
    for position in BRANCH_POSITIONS:
        for index, (stem, god) in enumerate(chart.hidden_stems.get(position, ())):
            judgment = personal.ten_god_reading(god, position, True, stem, pillars, strength, yongsin)
            readings.append(PersonalReading(PersonalTermKind.HIDDEN_TEN_GOD, position, index, None, judgment))
    for position in BRANCH_POSITIONS:
        if position not in chart.twelve_stages:
            continue
        branch = _pillar_at(pillars, position).branch
        judgment = personal.twelve_stage_reading(
            chart.twelve_stages[position], position, branch, strength, yongsin
        )
        readings.append(PersonalReading(PersonalTermKind.TWELVE_STAGE, position, 0, None, judgment))
    for hit in chart.shinsal:
        branch = _pillar_at(pillars, hit.position).branch
        judgment = personal.shinsal_reading(hit.kind, hit.position, branch, yongsin)
        readings.append(PersonalReading(PersonalTermKind.SHINSAL, hit.position, 0, hit.kind, judgment))
    return tuple(readings)


def _daeun_readings(natal: NatalContext, luck: LuckCycles, as_of: date) -> tuple[PersonalReading, ...]:
    yongsin = natal.yongsin
    readings: list[PersonalReading] = []
    for index, period in enumerate(luck.periods):
        is_last = index + 1 == len(luck.periods)
        end_year = period.start_year + 10 if is_last else luck.periods[index + 1].start_year
        current = period.start_year <= as_of.year < end_year
        branch = period.pillar.branch
        readings.extend(
            (
                PersonalReading(
                    PersonalTermKind.DAEUN_STEM_TEN_GOD,
                    None,
                    index,
                    None,
                    personal.luck_ten_god_reading(
                        period.stem_ten_god, "DAEUN", "STEM", period.pillar.stem, current, yongsin
                    ),
                ),
                PersonalReading(
                    PersonalTermKind.DAEUN_BRANCH_TEN_GOD,
                    None,
                    index,
                    None,
                    personal.luck_ten_god_reading(
                        period.branch_ten_god, "DAEUN", "BRANCH", hidden_stems(branch)[0], current, yongsin
                    ),
                ),
                PersonalReading(
                    PersonalTermKind.DAEUN_TWELVE_STAGE,
                    None,
                    index,
                    None,
                    personal.luck_twelve_stage_reading(period.twelve_stage, branch, current, yongsin),
                ),
            )
        )
    return tuple(readings)


def _seun_readings(natal: NatalContext, luck: LuckCycles, as_of: date) -> tuple[PersonalReading, ...]:
    return tuple(
        PersonalReading(
            PersonalTermKind.SEUN_TEN_GOD,
            None,
            index,
            None,
            personal.luck_ten_god_reading(
                year_luck.ten_god,
                "SEUN",
                "STEM",
                year_luck.pillar.stem,
                year_luck.year == as_of.year,
                natal.yongsin,
            ),
        )
        for index, year_luck in enumerate(luck.years)
    )
