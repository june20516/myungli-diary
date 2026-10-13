"""데일리 view: 일진 x 원국 판정 (spec 4.4, 7, D13)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.calendar_core.birth import BirthInput, validate_civil_date
from myungli_engine.calendar_core.time_basis import load_zone
from myungli_engine.chart.shinsal import activated
from myungli_engine.composers.chart import merge_notices, prepare_natal
from myungli_engine.constants.message_keys import require
from myungli_engine.domain.enums import DayKind, NoticeCode
from myungli_engine.domain.models import Evidence, Judgment, Notice, Pillar
from myungli_engine.references.loader import FIVE_ELEMENTS_REF
from myungli_engine.rules import messages
from myungli_engine.rules.color import ElementPick, lucky_element
from myungli_engine.rules.day_kind import classify_day
from myungli_engine.rules.direction import DirectionPick, lucky_direction
from myungli_engine.rules.focus_time import FocusResult, pick_focus_times
from myungli_engine.rules.number import lucky_number
from myungli_engine.rules.relations import Relation, find_relations
from myungli_engine.rules.tags import TagResult, select_tags

FOCUS_FALLBACK_REASON = "fallback"


@dataclass(frozen=True, slots=True)
class DailyView:
    date: date
    day: Pillar
    kind: DayKind
    color: tuple[ElementPick, Judgment]
    direction: tuple[DirectionPick, Judgment]
    number: tuple[int, Judgment]
    focus: tuple[FocusResult, Judgment]
    relations: tuple[Relation, ...]
    tags: TagResult
    fortune: tuple[Judgment, ...]
    guide: Judgment
    notices: tuple[Notice, ...]


def compose_daily(birth: BirthInput, target: date, current_timezone: str) -> DailyView:
    validate_civil_date(target)
    load_zone(current_timezone)
    natal = prepare_natal(birth)
    natal_pillars = natal.chart.pillars
    yongsin = natal.yongsin

    day = lunar_adapter.day_pillar(target)
    kind = classify_day(day, yongsin, natal.gwiin)
    color = lucky_element(kind, yongsin)
    direction = lucky_direction(kind, day, yongsin, lunar_adapter.deity_directions(target))
    number = lucky_number(color.element, day.stem)
    focus = pick_focus_times(
        lunar_adapter.hour_slots(target, current_timezone), natal_pillars, yongsin, natal.gwiin
    )
    relations = find_relations(natal_pillars, day)
    tags = select_tags(natal_pillars, day, relations, activated(natal.shinsal_branches, day.branch), kind)

    fallback_notices = (Notice(NoticeCode.FOCUS_TIME_FALLBACK),) if focus.fallback else ()
    return DailyView(
        date=target,
        day=day,
        kind=kind,
        color=(color, _color_judgment(kind, color)),
        direction=(direction, _direction_judgment(kind, direction)),
        number=(number, _number_judgment(kind, number, color, day)),
        focus=(focus, _focus_judgment(focus)),
        relations=relations,
        tags=tags,
        fortune=messages.fortune(kind, day, natal_pillars.day.stem, tags.featured, yongsin),
        guide=messages.guide_question(day, natal_pillars.day.stem, tags.featured),
        notices=merge_notices(natal.chart.notices, fallback_notices),
    )


def _kind_key(kind: DayKind) -> str:
    return kind.name.lower()


def _color_judgment(kind: DayKind, pick: ElementPick) -> Judgment:
    params = {"element": pick.element.name, "role": pick.role.name}
    return Judgment(
        message_key=require(f"color.{_kind_key(kind)}", params),
        params=params,
        evidence=pick.evidence,
    )


def _direction_judgment(kind: DayKind, pick: DirectionPick) -> Judgment:
    params = {"direction": pick.direction.name, "rule_id": pick.rule_id}
    return Judgment(
        message_key=require(f"direction.day_kind.{_kind_key(kind).removesuffix('_day')}", params),
        params=params,
        evidence=pick.evidence,
    )


def _number_judgment(kind: DayKind, number: int, color: ElementPick, day: Pillar) -> Judgment:
    """숫자 오행은 컬러와 같고, 홀짝은 오늘 일진 천간의 음양으로 정한다 (spec 7.4)."""
    evidence = Evidence(
        rule_id="number/hado",
        source_ref=FIVE_ELEMENTS_REF["number"],
        detail={
            "number": str(number),
            "element": color.element.name,
            "day_stem": day.stem.hanja,
            "parity": "odd" if day.stem.is_yang else "even",
        },
    )
    params: dict[str, str | int | float | bool] = {"number": number, "element": color.element.name}
    return Judgment(
        message_key=require(f"number.{_kind_key(kind)}", params),
        params=params,
        evidence=(evidence,),
    )


def _focus_judgment(focus: FocusResult) -> Judgment:
    """fallback이거나 1등 시진에 가점 사유가 없으면 fallback 키, 아니면 1등의 첫 사유 키."""
    top = focus.picks[0]
    reason = FOCUS_FALLBACK_REASON if focus.fallback or not top.reasons else top.reasons[0]
    params: dict[str, str | int | float | bool] = {
        "branches": ",".join(pick.slot.branch.name for pick in focus.picks),
        "score": top.score,
    }
    return Judgment(
        message_key=require(f"focus_time.{reason}", params),
        params=params,
        evidence=focus.evidence,
    )
