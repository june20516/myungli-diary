"""proto 메시지와 도메인 값 사이의 변환 (spec 3, 9).

enum은 이름으로 매핑한다. proto 값 이름은 `<PROTO_ENUM_UPPER_SNAKE>_<도메인 멤버 이름>`이며,
0번 `<PREFIX>_UNSPECIFIED`는 요청에서 InvalidInputError다.
"""

from __future__ import annotations

import math
from collections.abc import Callable, Iterable, Mapping
from datetime import date, datetime, time
from enum import Enum

from google.protobuf.timestamp_pb2 import Timestamp

from myungli_engine._gen.myungli.engine.v1 import engine_pb2 as pb
from myungli_engine.calendar_core.birth import BirthHour, BirthInput, LunarDate
from myungli_engine.chart.personal_target import PersonalReading
from myungli_engine.chart.positions import Position
from myungli_engine.composers.chart import ChartView
from myungli_engine.composers.daily import DailyView
from myungli_engine.composers.month import MonthDay, MonthView
from myungli_engine.constants.evidence_rules import require_rule
from myungli_engine.domain.enums import CalendarType, Gender
from myungli_engine.domain.errors import InvalidInputError
from myungli_engine.domain.models import Evidence, FourPillars, Judgment, Notice, Pillar
from myungli_engine.rules.focus_time import ScoredSlot
from myungli_engine.rules.relations import Relation
from myungli_engine.version import ENGINE_VERSION, RULESET_VERSION

MIN_LONGITUDE = -180.0
MAX_LONGITUDE = 180.0

# 도메인 enum 이름 → proto enum 접두어
_PREFIX_ELEMENT = "ELEMENT"
_PREFIX_STEM = "STEM"
_PREFIX_BRANCH = "BRANCH"
_PREFIX_TEN_GOD = "TEN_GOD"
_PREFIX_TWELVE_STAGE = "TWELVE_STAGE"
_PREFIX_SHINSAL = "SHINSAL"
_PREFIX_POSITION = "POSITION"
_PREFIX_DIRECTION8 = "DIRECTION8"
_PREFIX_DAY_KIND = "DAY_KIND"
_PREFIX_STRENGTH_LEVEL = "STRENGTH_LEVEL"
_PREFIX_YONGSIN_METHOD = "YONGSIN_METHOD"
_PREFIX_LUCK_LEVEL = "LUCK_LEVEL"
_PREFIX_NOTICE_CODE = "NOTICE_CODE"
_PREFIX_RELATION_KIND = "RELATION_KIND"
_PREFIX_ELEMENT_ROLE = "ELEMENT_ROLE"
_PREFIX_CALENDAR_TYPE = "CALENDAR_TYPE"
_PREFIX_GENDER = "GENDER"
_PREFIX_SOLAR_TERM_KIND = "SOLAR_TERM_KIND"
_PREFIX_PERSONAL_TERM_KIND = "PERSONAL_TERM_KIND"
_UNSPECIFIED = "UNSPECIFIED"


# --- 요청 → 도메인 ---


def birth_from_proto(msg: pb.BirthInfo) -> BirthInput:
    calendar = _domain_enum(CalendarType, _PREFIX_CALENDAR_TYPE, pb.CalendarType.Name, msg.calendar)
    gender = _domain_enum(Gender, _PREFIX_GENDER, pb.Gender.Name, msg.gender)
    birth_date: date | LunarDate
    if calendar is CalendarType.LUNAR:
        # 음력 월일 범위(음력 30일 포함)는 calendar_core의 변환이 검증한다
        birth_date = LunarDate(msg.date.year, msg.date.month, msg.date.day)
    else:
        birth_date = date_from_proto(msg.date)
    return BirthInput(
        calendar=calendar,
        is_leap_month=msg.is_leap_month,
        date=birth_date,
        time=_time_from_proto(msg.time) if msg.HasField("time") else None,
        gender=gender,
        timezone=timezone_from_proto(msg.timezone),
        longitude=_longitude_from_proto(msg.longitude) if msg.HasField("longitude") else None,
    )


def date_from_proto(msg: pb.LocalDate) -> date:
    try:
        return date(msg.year, msg.month, msg.day)
    except ValueError as error:
        raise InvalidInputError(f"존재하지 않는 날짜입니다: {msg.year}-{msg.month}-{msg.day}") from error


def timezone_from_proto(name: str) -> str:
    """빈 문자열만 여기서 막는다. 알 수 없는 IANA 이름은 calendar_core가 InvalidInputError로 막는다."""
    if not name:
        raise InvalidInputError("시간대가 비어 있습니다.")
    return name


def _time_from_proto(msg: pb.LocalTime) -> time:
    try:
        return time(msg.hour, msg.minute)
    except ValueError as error:
        raise InvalidInputError(f"존재하지 않는 시각입니다: {msg.hour}:{msg.minute}") from error


def _longitude_from_proto(longitude: float) -> float:
    if not math.isfinite(longitude) or not MIN_LONGITUDE <= longitude <= MAX_LONGITUDE:
        raise InvalidInputError(f"경도는 -180~180 사이의 유한한 값이어야 합니다: {longitude}")
    return longitude


def _domain_enum[E: Enum](
    enum_type: type[E], prefix: str, proto_name_of: Callable[[int], str], number: int
) -> E:
    """proto enum 값을 같은 이름의 도메인 멤버로. UNSPECIFIED나 proto에 없는 번호면 InvalidInputError."""
    try:
        proto_name = proto_name_of(number)
    except ValueError as error:
        raise InvalidInputError(f"알 수 없는 {prefix} 값입니다: {number}") from error
    member_name = proto_name.removeprefix(f"{prefix}_")
    if member_name == _UNSPECIFIED or member_name not in enum_type.__members__:
        raise InvalidInputError(f"값을 지정해야 합니다: {proto_name}")
    return enum_type[member_name]


# --- 도메인 → 응답 ---


def chart_to_proto(view: ChartView) -> pb.ChartResponse:
    chart = view.chart
    yongsin = view.yongsin
    luck = view.luck
    return pb.ChartResponse(
        pillars=_four_pillars(chart.pillars),
        ten_gods=[
            pb.PositionTenGod(position=_name(_PREFIX_POSITION, position), ten_god=_name(_PREFIX_TEN_GOD, god))
            for position, god in _by_position(chart.ten_gods)
        ],
        hidden_stems=[
            pb.PositionHiddenStems(
                position=_name(_PREFIX_POSITION, position),
                stems=[
                    pb.HiddenStem(stem=_name(_PREFIX_STEM, stem), ten_god=_name(_PREFIX_TEN_GOD, god))
                    for stem, god in stems
                ],
            )
            for position, stems in _by_position(chart.hidden_stems)
        ],
        twelve_stages=[
            pb.PositionTwelveStage(
                position=_name(_PREFIX_POSITION, position),
                twelve_stage=_name(_PREFIX_TWELVE_STAGE, stage),
            )
            for position, stage in _by_position(chart.twelve_stages)
        ],
        shinsal=[
            pb.ShinsalHit(kind=_name(_PREFIX_SHINSAL, hit.kind), position=_name(_PREFIX_POSITION, hit.position))
            for hit in chart.shinsal
        ],
        gongmang=[_name(_PREFIX_BRANCH, branch) for branch in sorted(chart.gongmang, key=lambda b: b.index)],
        element_weights=[
            pb.ElementWeight(element=_name(_PREFIX_ELEMENT, element), weight=weight)
            for element, weight in view.strength.element_weights.items()
        ],
        strength=pb.Strength(
            score=view.strength.score, level=_name(_PREFIX_STRENGTH_LEVEL, view.strength.level)
        ),
        yongsin=pb.YongsinInfo(
            yongsin=_name(_PREFIX_ELEMENT, yongsin.yongsin),
            huisin=_name(_PREFIX_ELEMENT, yongsin.huisin),
            gisin=_name(_PREFIX_ELEMENT, yongsin.gisin),
            tonggwan=_name(_PREFIX_ELEMENT, yongsin.tonggwan),
            method=_name(_PREFIX_YONGSIN_METHOD, yongsin.method),
            johu_stem=_optional_name(_PREFIX_STEM, yongsin.johu_stem),
            judgment=_judgment(view.yongsin_judgment),
        ),
        daeun=pb.DaeunTable(
            forward=luck.forward,
            start_years=luck.start_years,
            start_months=luck.start_months,
            periods=[
                pb.LuckPeriod(
                    pillar=_pillar(period.pillar),
                    start_age=period.start_age,
                    start_age_korean=period.start_age_korean,
                    stem_ten_god=_name(_PREFIX_TEN_GOD, period.stem_ten_god),
                    branch_ten_god=_name(_PREFIX_TEN_GOD, period.branch_ten_god),
                    twelve_stage=_name(_PREFIX_TWELVE_STAGE, period.twelve_stage),
                )
                for period in luck.periods
            ],
        ),
        seun=[
            pb.YearLuck(
                year=year.year,
                pillar=_pillar(year.pillar),
                ten_god=_name(_PREFIX_TEN_GOD, year.ten_god),
                # 도메인은 RelationKind 멤버 이름(str)으로 담는다
                relations_with_natal=[f"{_PREFIX_RELATION_KIND}_{kind}" for kind in year.relations_with_natal],
            )
            for year in luck.years
        ],
        meta=_meta(view.notices),
        personal_readings=[_personal_reading(reading) for reading in view.personal_readings],
    )


def daily_to_proto(view: DailyView) -> pb.DailyResponse:
    color, color_judgment = view.color
    direction, direction_judgment = view.direction
    number, number_judgment = view.number
    focus, focus_judgment = view.focus
    return pb.DailyResponse(
        day=_pillar(view.day),
        kind=_name(_PREFIX_DAY_KIND, view.kind),
        color=pb.ColorCard(
            judgment=_judgment(color_judgment),
            element=_name(_PREFIX_ELEMENT, color.element),
            role=_name(_PREFIX_ELEMENT_ROLE, color.role),
        ),
        direction=pb.DirectionCard(
            judgment=_judgment(direction_judgment),
            direction=_name(_PREFIX_DIRECTION8, direction.direction),
            rule_id=direction.rule_id,
        ),
        number=pb.NumberCard(judgment=_judgment(number_judgment), number=number),
        focus_time=pb.FocusTimeCard(
            judgment=_judgment(focus_judgment),
            picks=[_focus_slot(pick) for pick in focus.picks],
            fallback=focus.fallback,
        ),
        relations=[_relation(relation) for relation in view.relations],
        featured_tags=view.tags.featured,
        all_tags=view.tags.all_keys,
        tag_evidence=[evidence_to_proto(evidence) for evidence in view.tags.evidence],
        fortune=[_judgment(judgment) for judgment in view.fortune],
        guide=_judgment(view.guide),
        meta=_meta(view.notices),
    )


def birth_hour_to_proto(hour: BirthHour) -> pb.BirthHourResponse:
    return pb.BirthHourResponse(
        branch=_name(_PREFIX_BRANCH, hour.branch),
        start=_timestamp(hour.start),
        end=_timestamp(hour.end),
        meta=_meta(hour.notices),
    )


def lunar_conversion_to_proto(solar: date, month_has_leap: bool) -> pb.LunarDateResponse:
    return pb.LunarDateResponse(
        solar=pb.LocalDate(year=solar.year, month=solar.month, day=solar.day),
        month_has_leap=month_has_leap,
        meta=_meta(()),
    )


def month_to_proto(view: MonthView) -> pb.MonthResponse:
    return pb.MonthResponse(days=[_month_day(day) for day in view.days], meta=_meta(view.notices))


def _month_day(day: MonthDay) -> pb.MonthDay:
    info = day.info
    message = pb.MonthDay(
        date=pb.LocalDate(year=info.date.year, month=info.date.month, day=info.date.day),
        pillar=_pillar(info.pillar),
        lunar_month=info.lunar_month,
        lunar_day=info.lunar_day,
        is_leap_month=info.is_leap_month,
        kind=_name(_PREFIX_DAY_KIND, day.kind),
        luck_level=_name(_PREFIX_LUCK_LEVEL, day.luck.level),
        score=day.luck.score,
        score_items=[pb.ScoreItem(id=item_id, score=points) for item_id, points in day.luck.breakdown],
        judgment=_judgment(day.judgment),
    )
    if info.solar_term is not None:
        term = info.solar_term
        message.solar_term.CopyFrom(
            pb.SolarTerm(
                name=term.name,
                at=_timestamp(term.at),
                kind=_name(_PREFIX_SOLAR_TERM_KIND, term.kind),
            )
        )
    if day.featured_tag is not None:
        message.featured_tag = day.featured_tag
    return message


def _focus_slot(pick: ScoredSlot) -> pb.FocusSlot:
    slot = pick.slot
    return pb.FocusSlot(
        branch=_name(_PREFIX_BRANCH, slot.branch),
        pillar=_pillar(slot.pillar),
        start=_timestamp(slot.start),
        end=_timestamp(slot.end),
        huangdao_lucky=slot.huangdao_lucky,
        score=pick.score,
        reasons=pick.reasons,
    )


def _relation(relation: Relation) -> pb.Relation:
    return pb.Relation(
        kind=_name(_PREFIX_RELATION_KIND, relation.kind),
        natal_position=_name(_PREFIX_POSITION, relation.natal_position),
        suppressed_by=_optional_name(_PREFIX_RELATION_KIND, relation.suppressed_by),
    )


def _four_pillars(pillars: FourPillars) -> pb.FourPillars:
    message = pb.FourPillars(
        year=_pillar(pillars.year), month=_pillar(pillars.month), day=_pillar(pillars.day)
    )
    if pillars.hour is not None:
        message.hour.CopyFrom(_pillar(pillars.hour))
    return message


def _pillar(pillar: Pillar) -> pb.Pillar:
    return pb.Pillar(stem=_name(_PREFIX_STEM, pillar.stem), branch=_name(_PREFIX_BRANCH, pillar.branch))


def _personal_reading(reading: PersonalReading) -> pb.PersonalReading:
    return pb.PersonalReading(
        kind=_name(_PREFIX_PERSONAL_TERM_KIND, reading.kind),
        position=_optional_name(_PREFIX_POSITION, reading.position),
        index=reading.index,
        shinsal=_optional_name(_PREFIX_SHINSAL, reading.shinsal),
        judgment=_judgment(reading.judgment),
    )


def _judgment(judgment: Judgment) -> pb.Judgment:
    return pb.Judgment(
        message_key=judgment.message_key,
        params={key: _param(value) for key, value in judgment.params.items()},
        evidence=[evidence_to_proto(evidence) for evidence in judgment.evidence],
    )


def _param(value: str | float | bool) -> pb.Param:
    """Judgment.params 값(str/int/float/bool)을 Param oneof로. int는 float 표기에 포함된다(PEP 484)."""
    # bool은 int의 하위 타입이므로 먼저 본다
    if isinstance(value, bool):
        return pb.Param(flag=value)
    if isinstance(value, int):
        return pb.Param(integer=value)
    if isinstance(value, float):
        return pb.Param(number=value)
    return pb.Param(text=value)


def evidence_to_proto(evidence: Evidence) -> pb.Evidence:
    """등록된 rule_id와 detail 키만 계약으로 내보낸다(evidence_rules). 어긋나면 KeyError."""
    return pb.Evidence(
        rule_id=require_rule(evidence.rule_id, evidence.detail),
        source_ref=evidence.source_ref,
        detail=dict(evidence.detail),
    )


def _meta(notices: Iterable[Notice]) -> pb.ResponseMeta:
    return pb.ResponseMeta(
        engine_version=ENGINE_VERSION,
        ruleset_version=RULESET_VERSION,
        notices=[
            pb.Notice(code=_name(_PREFIX_NOTICE_CODE, notice.code), detail=dict(notice.detail))
            for notice in notices
        ],
    )


def _timestamp(moment: datetime) -> Timestamp:
    """시간대가 붙은 시각을 절대 시각으로 담는다."""
    if moment.tzinfo is None:
        raise ValueError("시간대가 없는 시각은 절대 시각으로 바꿀 수 없습니다.")
    stamp = Timestamp()
    stamp.FromDatetime(moment)
    return stamp


def _by_position[V](values: Mapping[Position, V]) -> list[tuple[Position, V]]:
    """자리 순서(연간→시지)로 정렬한다."""
    return sorted(values.items(), key=lambda item: list(Position).index(item[0]))


def _name(prefix: str, member: Enum) -> str:
    return f"{prefix}_{member.name}"


def _optional_name(prefix: str, member: Enum | None) -> str:
    return f"{prefix}_{_UNSPECIFIED}" if member is None else _name(prefix, member)
