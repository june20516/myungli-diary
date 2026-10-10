"""대운·세운 (spec 5.3)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from myungri_engine.calendar_core import lunar_adapter
from myungri_engine.calendar_core.birth import BirthMoment
from myungri_engine.domain.enums import Branch, Gender, NoticeCode, Stem, TenGod, TwelveStage
from myungri_engine.domain.models import FourPillars, Notice, Pillar
from myungri_engine.domain.ten_gods import ten_god

PERIOD_YEARS = 10
KOREAN_AGE_OFFSET = 1
# 1984년이 甲子년이므로 (연도 - 4)가 60갑자 순번이다
GANZHI_YEAR_OFFSET = 4


@dataclass(frozen=True, slots=True)
class LuckPeriod:
    pillar: Pillar
    start_age: int
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
    start_years, start_months, cycle_pillars = lunar_adapter.luck_cycles_raw(moment, gender)

    periods = tuple(
        LuckPeriod(
            pillar=pillar,
            start_age=start_years + PERIOD_YEARS * index,
            start_age_korean=start_years + PERIOD_YEARS * index + KOREAN_AGE_OFFSET,
            stem_ten_god=ten_god(day_stem, pillar.stem),
            branch_ten_god=ten_god(day_stem, lunar_adapter.hidden_stems(pillar.branch)[0]),
            twelve_stage=lunar_adapter.twelve_stage(day_stem, pillar.branch),
        )
        for index, pillar in enumerate(cycle_pillars)
    )

    first_year = _period_first_year(moment.solar_date.year, start_years, as_of.year, len(periods))
    years = tuple(
        YearLuck(
            year=year,
            pillar=_year_pillar(year),
            ten_god=ten_god(day_stem, _year_pillar(year).stem),
            relations_with_natal=(),
        )
        for year in range(first_year, first_year + PERIOD_YEARS)
    )

    notices = () if moment.time_known else (Notice(NoticeCode.DAYUN_START_APPROXIMATE),)
    return LuckCycles(forward, start_years, start_months, periods, years, notices)


def _period_first_year(birth_year: int, start_years: int, as_of_year: int, period_count: int) -> int:
    """as_of가 속한 대운 구간의 시작 연도. 첫 대운 전이면 첫 구간, 마지막 구간 뒤면 마지막 구간."""
    elapsed = as_of_year - (birth_year + start_years)
    index = min(max(elapsed // PERIOD_YEARS, 0), period_count - 1)
    return birth_year + start_years + PERIOD_YEARS * index


def _year_pillar(year: int) -> Pillar:
    """그해 입춘 이후의 연주."""
    offset = year - GANZHI_YEAR_OFFSET
    return Pillar(list(Stem)[offset % len(Stem)], list(Branch)[offset % len(Branch)])
