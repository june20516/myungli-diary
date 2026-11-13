"""데일리 view: 일진 x 원국 판정 (spec 4.4, 7, D13)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

from myungli_engine.calendar_core import korean_lunar, lunar_adapter
from myungli_engine.calendar_core.birth import BirthInput, validate_civil_date
from myungli_engine.calendar_core.korean_lunar import KoreanLunarDate
from myungli_engine.calendar_core.time_basis import load_zone
from myungli_engine.chart.shinsal import activated
from myungli_engine.composers.chart import prepare_natal
from myungli_engine.constants.message_keys import require
from myungli_engine.domain.elements import relation_to
from myungli_engine.domain.enums import DayKind, DayVirtue, TenGod
from myungli_engine.domain.models import Evidence, Judgment, Notice, Pillar
from myungli_engine.domain.ten_gods import ten_god
from myungli_engine.references.loader import FIVE_ELEMENTS_REF, FOCUS_TIME_REF
from myungli_engine.rules import messages
from myungli_engine.rules.color import ElementPick, lucky_colors
from myungli_engine.rules.day_kind import classify_day
from myungli_engine.rules.day_virtue import day_virtue_judgment, day_virtues
from myungli_engine.rules.direction import DirectionPick, lucky_direction
from myungli_engine.rules.focus_time import DayHours, FocusPick, pick_focus_times
from myungli_engine.rules.number import hado_pair, lucky_number
from myungli_engine.rules.relations import Relation, find_relations
from myungli_engine.rules.tags import TagResult, select_tags

DEITY_NONE = "NONE"


@dataclass(frozen=True, slots=True)
class DailyView:
    date: date
    day: Pillar
    kind: DayKind
    colors: tuple[tuple[ElementPick, Judgment], ...]  # 1~2장. 둘이면 (내 균형 기준, 원전 기준) (D119)
    direction: tuple[DirectionPick, Judgment]
    number: tuple[int, Judgment]
    focus: tuple[tuple[FocusPick, Judgment], ...]  # (낮, 밤) 1등 시진 (D122)
    relations: tuple[Relation, ...]
    tags: TagResult
    fortune: tuple[Judgment, ...]
    guide: Judgment
    notices: tuple[Notice, ...]
    day_stem_ten_god: TenGod
    guide_candidates: tuple[Judgment, ...]
    lunar: KoreanLunarDate  # 그날의 한국 음력 날짜(월간 캘린더와 같은 계산)
    day_virtues: tuple[tuple[DayVirtue, Judgment], ...]  # 택일 덕일(D124 ⑤), 천덕일 먼저


def compose_daily(birth: BirthInput, target: date, current_timezone: str) -> DailyView:
    validate_civil_date(target)
    load_zone(current_timezone)
    natal = prepare_natal(birth)
    natal_pillars = natal.chart.pillars
    yongsin = natal.yongsin

    day = lunar_adapter.day_pillar(target)
    kind = classify_day(day, yongsin, natal.gwiin)
    colors = lucky_colors(kind, yongsin, day)
    direction = lucky_direction(kind, day, yongsin, lunar_adapter.deity_directions(target))
    number = lucky_number(colors[0].element, day.stem)
    focus = pick_focus_times(
        _day_hours(target, current_timezone),
        _day_hours(target + timedelta(days=1), current_timezone),
        natal_pillars.year,
    )
    relations = find_relations(natal_pillars, day)
    tags = select_tags(
        natal_pillars,
        day,
        relations,
        activated(natal.shinsal_branches, day.branch),
        kind,
        yongsin_ref=yongsin.evidence[0].source_ref,
    )

    guides = messages.guide_candidates(
        day, natal_pillars.day.stem, tags.featured, tag_sources=tags.source_refs
    )
    return DailyView(
        date=target,
        day=day,
        kind=kind,
        colors=tuple((pick, _color_judgment(kind, pick, day, split=len(colors) > 1)) for pick in colors),
        direction=(direction, _direction_judgment(kind, direction, day)),
        number=(number, _number_judgment(kind, number, colors[0], day)),
        focus=tuple((pick, _focus_judgment(pick, natal_pillars.year)) for pick in focus),
        relations=relations,
        tags=tags,
        fortune=messages.fortune(
            kind, day, natal_pillars.day.stem, tags.featured, yongsin, tag_sources=tags.source_refs
        ),
        guide=guides[0],
        notices=natal.chart.notices,
        day_stem_ten_god=ten_god(natal_pillars.day.stem, day.stem),
        guide_candidates=guides,
        lunar=korean_lunar.solar_to_lunar(target),
        day_virtues=_day_virtues(target, day),
    )


def _day_virtues(target: date, day: Pillar) -> tuple[tuple[DayVirtue, Judgment], ...]:
    month_branch = lunar_adapter.day_month_branch(target)
    return tuple(
        (virtue, day_virtue_judgment(virtue, month_branch, day)) for virtue in day_virtues(month_branch, day)
    )


def _kind_key(kind: DayKind) -> str:
    return kind.name.lower()


def _color_judgment(kind: DayKind, pick: ElementPick, day: Pillar, *, split: bool) -> Judgment:
    """카드가 하나면 color.<날의 성격>, 둘이면 color.<기준>.<날의 성격> (D119)."""
    params = {
        "element": pick.element.name,
        "role": pick.role.name,
        "base_element": pick.base_element.name,
        "day_branch": day.branch.name,
        "shift": pick.shift.name,
        "twelve_stage": pick.stage.name,
        "relation": relation_to(pick.base_element, pick.element).name,
    }
    key = f"color.{pick.basis.name.lower()}.{_kind_key(kind)}" if split else f"color.{_kind_key(kind)}"
    return Judgment(message_key=require(key, params), params=params, evidence=pick.evidence)


def _direction_judgment(kind: DayKind, pick: DirectionPick, day: Pillar) -> Judgment:
    """귀인의 날은 오늘 일지, 그 밖은 방위를 정한 오행과 역할, 보통의 날은 길신 종류도 넣는다 (#970).

    보통의 날에 길신 방위가 없어 대표 방위로 돌아가면 deity는 NONE이다.
    귀인의 날이 아니면 바탕 오행과 방위 오행의 관계(희신이면 보통 MO)를 넣는다 (D130).
    """
    params: dict[str, str | int | float | bool] = {"direction": pick.direction.name, "rule_id": pick.rule_id}
    if kind is DayKind.GWIIN_DAY:
        params["day_branch"] = day.branch.name
    else:
        if pick.element is None or pick.role is None or pick.base_element is None:
            raise ValueError(f"방향 {pick.rule_id}에 오행, 역할, 바탕 오행이 없습니다")
        params |= {
            "element": pick.element.name,
            "role": pick.role,
            "base_element": pick.base_element.name,
            "relation": relation_to(pick.base_element, pick.element).name,
        }
        if kind is DayKind.ORDINARY_DAY:
            params["deity"] = pick.deity.name if pick.deity is not None else DEITY_NONE
    return Judgment(
        message_key=require(f"direction.day_kind.{_kind_key(kind).removesuffix('_day')}", params),
        params=params,
        evidence=pick.evidence,
    )


def _number_judgment(kind: DayKind, number: int, color: ElementPick, day: Pillar) -> Judgment:
    """숫자 오행은 첫째 색 카드의 오행이고, 홀짝은 오늘 일진 천간의 음양으로 정한다 (spec 7.4, D119).

    바탕 오행과 관계는 첫째 색 카드와 같다 (D130).
    """
    parity = "odd" if day.stem.is_yang else "even"
    evidence = Evidence(
        rule_id="number/hado",
        source_ref=FIVE_ELEMENTS_REF["number"],
        detail={
            "number": str(number),
            "element": color.element.name,
            "day_stem": day.stem.hanja,
            "parity": parity,
        },
    )
    params: dict[str, str | int | float | bool] = {
        "number": number,
        "element": color.element.name,
        "day_stem": day.stem.name,
        "parity": parity.upper(),
        "pair": hado_pair(color.element, number),
        "base_element": color.base_element.name,
        "relation": relation_to(color.base_element, color.element).name,
    }
    return Judgment(
        message_key=require(f"number.{_kind_key(kind)}", params),
        params=params,
        evidence=(evidence,),
    )


def _hanja(pillar: Pillar) -> str:
    return f"{pillar.stem.hanja}{pillar.branch.hanja}"


def _day_hours(civil_date: date, current_timezone: str) -> DayHours:
    return DayHours(
        date=civil_date,
        pillar=lunar_adapter.day_pillar(civil_date),
        slots=lunar_adapter.hour_slots(civil_date, current_timezone),
    )


def _focus_judgment(pick: FocusPick, birth_year: Pillar) -> Judgment:
    """낮이나 밤의 1등 시진 하나 (D122). 근거는 用時法(그날), 論相主(태어난 해), 黃道黑道(동점) 조목이다.

    매개변수와 detail에는 고른 시진, 그 시진이 속한 날의 일진, 태어난 해만 둔다. 등급과 순서는 내지 않는다(D121).
    밤의 자시~묘시는 다음 날 일진이다(#1008).
    """
    day = pick.grade.day
    hour_branch = pick.grade.slot.branch.name
    period = pick.period.name
    params: dict[str, str | int | float | bool] = {"hour_branch": hour_branch}
    evidence = (
        Evidence(
            rule_id="focus_time/day_relation",
            source_ref=FOCUS_TIME_REF["use_hour"],
            detail={"period": period, "hour_branch": hour_branch, "day_pillar": _hanja(day)},
        ),
        Evidence(
            rule_id="focus_time/birth_year",
            source_ref=FOCUS_TIME_REF["birth_year"],
            detail={"period": period, "hour_branch": hour_branch, "birth_year": _hanja(birth_year)},
        ),
        Evidence(
            rule_id="focus_time/huangdao",
            source_ref=FOCUS_TIME_REF["huangdao"],
            detail={
                "period": period,
                "hour_branch": hour_branch,
                "huangdao": "true" if pick.grade.slot.huangdao_lucky else "false",
            },
        ),
    )
    return Judgment(
        message_key=require(f"focus_time.{period.lower()}", params), params=params, evidence=evidence
    )
