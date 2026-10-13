"""대운·세운 (spec 5.3)."""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date, timedelta

from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.calendar_core.birth import BirthMoment
from myungli_engine.domain.enums import Branch, Gender, NoticeCode, Stem, TenGod, TwelveStage
from myungli_engine.domain.models import FourPillars, Notice, Pillar
from myungli_engine.domain.ten_gods import ten_god
from myungli_engine.rules.relations import RelationKind, active, find_relations

PERIOD_YEARS = 10
KOREAN_AGE_OFFSET = 1
MONTHS_PER_YEAR = 12
# 1984년이 甲子년이므로 (연도 - 4)가 60갑자 순번이다
GANZHI_YEAR_OFFSET = 4


@dataclass(frozen=True, slots=True)
class LuckPeriod:
    """start_age는 만 나이 연수(시작 연수 + 10i, C5), start_year는 실제 시작 시점의 양력 연도,
    start_age_korean은 그 연도의 한국식(세는) 나이 = start_year - 출생 양력 연도 + 1이다."""

    pillar: Pillar
    start_age: int
    start_year: int
    start_age_korean: int
    stem_ten_god: TenGod
    branch_ten_god: TenGod
    twelve_stage: TwelveStage


@dataclass(frozen=True, slots=True)
class YearLuck:
    year: int
    pillar: Pillar
    ten_god: TenGod
    relations_with_natal: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class LuckCycles:
    forward: bool
    start_years: int
    start_months: int
    periods: tuple[LuckPeriod, ...]
    years: tuple[YearLuck, ...]
    notices: tuple[Notice, ...]


def build_luck_cycles(moment: BirthMoment, gender: Gender, natal: FourPillars, as_of: date) -> LuckCycles:
    day_stem = natal.day.stem
    forward = natal.year.stem.is_yang == (gender is Gender.MALE)
    raw = lunar_adapter.luck_cycles_raw(moment, gender)
    birth_year = moment.solar_date.year
    first_start_year = _add_period(moment.solar_date, raw.start_years, raw.start_months, raw.start_days).year

    periods = tuple(
        LuckPeriod(
            pillar=pillar,
            start_age=raw.start_years + PERIOD_YEARS * index,
            start_year=first_start_year + PERIOD_YEARS * index,
            start_age_korean=first_start_year + PERIOD_YEARS * index - birth_year + KOREAN_AGE_OFFSET,
            stem_ten_god=ten_god(day_stem, pillar.stem),
            branch_ten_god=ten_god(day_stem, lunar_adapter.hidden_stems(pillar.branch)[0]),
            twelve_stage=lunar_adapter.twelve_stage(day_stem, pillar.branch),
        )
        for index, pillar in enumerate(raw.pillars)
    )

    first_year = _period_first_year(periods, as_of.year)
    years = tuple(_year_luck(year, natal) for year in range(first_year, first_year + PERIOD_YEARS))

    notices = () if moment.time_known else (Notice(NoticeCode.DAYUN_START_APPROXIMATE),)
    return LuckCycles(forward, raw.start_years, raw.start_months, periods, years, notices)


def _add_period(birth_date: date, years: int, months: int, days: int) -> date:
    """출생일 + 연·개월·일. 그달에 없는 날짜(예: 2월 30일)는 그달 말일로 맞춘다."""
    total_months = birth_date.month - 1 + months
    year = birth_date.year + years + total_months // MONTHS_PER_YEAR
    month = total_months % MONTHS_PER_YEAR + 1
    day = min(birth_date.day, calendar.monthrange(year, month)[1])
    return date(year, month, day) + timedelta(days=days)


def _year_luck(year: int, natal: FourPillars) -> YearLuck:
    pillar = _year_pillar(year)
    return YearLuck(
        year=year,
        pillar=pillar,
        ten_god=ten_god(natal.day.stem, pillar.stem),
        relations_with_natal=_relation_names(natal, pillar),
    )


def _relation_names(natal: FourPillars, year_pillar: Pillar) -> tuple[str, ...]:
    """활성 관계 종류 이름. 중복 없이 RelationKind 정의 순서."""
    present = {rel.kind for rel in active(find_relations(natal, year_pillar))}
    return tuple(kind.name for kind in RelationKind if kind in present)


def _period_first_year(periods: tuple[LuckPeriod, ...], as_of_year: int) -> int:
    """as_of가 속한 대운 구간의 시작 연도. 첫 대운 전이면 첫 구간, 마지막 구간 뒤면 마지막 구간."""
    containing = [period.start_year for period in periods if period.start_year <= as_of_year]
    return containing[-1] if containing else periods[0].start_year


def _year_pillar(year: int) -> Pillar:
    """그해 입춘 이후의 연주."""
    offset = year - GANZHI_YEAR_OFFSET
    return Pillar(list(Stem)[offset % len(Stem)], list(Branch)[offset % len(Branch)])
