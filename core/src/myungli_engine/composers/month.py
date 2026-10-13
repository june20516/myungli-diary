"""월간 캘린더 view: 날짜별 일진 x 원국 길흉 (spec 8)."""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date

from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.calendar_core.birth import BirthInput, validate_civil_date
from myungli_engine.calendar_core.lunar_adapter import DayInfo
from myungli_engine.calendar_core.time_basis import load_zone
from myungli_engine.chart.shinsal import activated
from myungli_engine.composers.chart import NatalContext, merge_notices, prepare_natal
from myungli_engine.constants.message_keys import require
from myungli_engine.domain.enums import DayKind
from myungli_engine.domain.errors import InvalidInputError, OutOfRangeError
from myungli_engine.domain.models import Evidence, Judgment, Notice
from myungli_engine.references.loader import FIVE_ELEMENTS_REF
from myungli_engine.rules.calendar_luck import LuckScore, score_day
from myungli_engine.rules.day_kind import classify_day
from myungli_engine.rules.relations import find_relations
from myungli_engine.rules.tags import select_tags

FIRST_MONTH = 1
LAST_MONTH = 12


@dataclass(frozen=True, slots=True)
class MonthDay:
    info: DayInfo
    kind: DayKind
    luck: LuckScore
    featured_tag: str | None
    judgment: Judgment


@dataclass(frozen=True, slots=True)
class MonthView:
    days: tuple[MonthDay, ...]
    notices: tuple[Notice, ...]


def compose_month(birth: BirthInput, year: int, month: int, current_timezone: str) -> MonthView:
    _validate_month(year, month)
    load_zone(current_timezone)
    natal = prepare_natal(birth)
    days = tuple(_month_day(info, natal) for info in lunar_adapter.month_days(year, month, current_timezone))
    return MonthView(days=days, notices=merge_notices(natal.chart.notices))


def _validate_month(year: int, month: int) -> None:
    if not FIRST_MONTH <= month <= LAST_MONTH:
        raise InvalidInputError(f"월이 잘못되었습니다: {month}")
    try:
        first_day = date(year, month, 1)
        last_day = date(year, month, calendar.monthrange(year, month)[1])
    except ValueError as error:
        raise OutOfRangeError(f"지원 범위 밖의 연도입니다: {year}") from error
    validate_civil_date(first_day)
    validate_civil_date(last_day)


def _month_day(info: DayInfo, natal: NatalContext) -> MonthDay:
    natal_pillars = natal.chart.pillars
    kind = classify_day(info.pillar, natal.yongsin, natal.gwiin)
    relations = find_relations(natal_pillars, info.pillar)
    luck = score_day(kind, relations)
    tags = select_tags(
        natal_pillars,
        info.pillar,
        relations,
        activated(natal.shinsal_branches, info.pillar.branch),
        kind,
    )
    return MonthDay(
        info=info,
        kind=kind,
        luck=luck,
        featured_tag=tags.featured[0] if tags.featured else None,
        judgment=_luck_judgment(luck),
    )


def _luck_judgment(luck: LuckScore) -> Judgment:
    breakdown = ",".join(f"{name}:{points:+d}" for name, points in luck.breakdown)
    evidence = Evidence(
        rule_id="calendar/score",
        source_ref=FIVE_ELEMENTS_REF["balance_principle"],
        detail={"breakdown": breakdown, "score": str(luck.score)},
    )
    params = {"score": luck.score}
    return Judgment(
        message_key=require(f"calendar.{luck.level.name.lower()}", params),
        params=params,
        evidence=(evidence,),
    )
