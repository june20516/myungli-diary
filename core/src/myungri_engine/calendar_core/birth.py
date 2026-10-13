"""출생 현지 시각을 UTC, 절기 비교용 시각, 시주·일주용 보정 시각으로 바꾼다 (spec 4.1, 4.2)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from myungri_engine.calendar_core import lunar_adapter
from myungri_engine.calendar_core.time_basis import (
    SOLAR_TERM_TIMEZONE,
    load_zone,
    longitude_correction,
    standard_offset_hours,
)
from myungri_engine.constants.longitudes import representative_longitude
from myungri_engine.domain.enums import Branch, CalendarType, Gender, NoticeCode
from myungri_engine.domain.errors import InvalidInputError, OutOfRangeError
from myungri_engine.domain.models import Notice

SUPPORTED_MIN_DATE = date(1900, 1, 31)
SUPPORTED_MAX_DATE = date(2099, 12, 31)

UNKNOWN_TIME_FALLBACK = time(12, 0)
ZI_HOUR_START_HOUR = 23
ZI_HOUR_END_HOUR = 0
NEAR_SOLAR_TERM_MINUTES = 120  # 절입 전후 안내 범위 (spec 4.3, D32)
HOUR_BRANCH_SPAN = timedelta(hours=2)


@dataclass(frozen=True, slots=True)
class LunarDate:
    """음력 연·월·일. 양력 달력에 없는 월일(예: 음력 2월 30일)도 담을 수 있다."""

    year: int
    month: int
    day: int


@dataclass(frozen=True, slots=True)
class BirthInput:
    """출생 입력.

    SOLAR면 date는 양력 date여야 한다. LUNAR면 LunarDate 또는 date를 받으며, date면 그 연·월·일을
    음력 값으로 해석한다.
    """

    calendar: CalendarType
    is_leap_month: bool
    date: date | LunarDate
    time: time | None
    gender: Gender
    timezone: str
    longitude: float | None


@dataclass(frozen=True, slots=True)
class BirthMoment:
    """solar_term_wallclock: UTC+8 벽시계(naive), corrected_local: UTC + 경도x4분(naive).

    시간 모름이면 utc는 None이고 두 값은 출생일 현지 정오를 같은 방식으로 변환한 값이다.
    """

    solar_date: date
    utc: datetime | None
    solar_term_wallclock: datetime
    corrected_local: datetime
    time_known: bool
    notices: tuple[Notice, ...]


@dataclass(frozen=True, slots=True)
class BirthHour:
    """출생 시각이 속한 시진. start·end는 UTC 절대 시각이다(반열린 구간 [start, end))."""

    branch: Branch
    start: datetime
    end: datetime
    notices: tuple[Notice, ...]


def validate_civil_date(d: date) -> None:
    if not SUPPORTED_MIN_DATE <= d <= SUPPORTED_MAX_DATE:
        raise OutOfRangeError(f"지원 범위(1900-01-31 ~ 2099-12-31) 밖의 날짜입니다: {d.isoformat()}")


def resolve_birth_moment(birth: BirthInput) -> BirthMoment:
    solar_date = _solar_date_of(birth)
    validate_civil_date(solar_date)
    zone = load_zone(birth.timezone)
    time_known = birth.time is not None
    local_time = birth.time if birth.time is not None else UNKNOWN_TIME_FALLBACK
    local_naive = datetime.combine(solar_date, local_time)

    utc, local_notices = _local_to_utc(local_naive, zone)
    standard_offset = standard_offset_hours(utc, zone)
    longitude = (
        birth.longitude
        if birth.longitude is not None
        else representative_longitude(birth.timezone, standard_offset)
    )

    solar_term_wallclock = utc.astimezone(SOLAR_TERM_TIMEZONE).replace(tzinfo=None)
    corrected_local = utc.replace(tzinfo=None) + longitude_correction(longitude)

    notices: list[Notice] = []
    if time_known:
        notices.extend(local_notices)
        if corrected_local.hour in (ZI_HOUR_START_HOUR, ZI_HOUR_END_HOUR):
            notices.append(Notice(NoticeCode.ZI_HOUR_NEXT_DAY))
        if lunar_adapter.nearest_solar_term_minutes(utc) <= NEAR_SOLAR_TERM_MINUTES:
            notices.append(Notice(NoticeCode.NEAR_SOLAR_TERM))
    else:
        notices.append(Notice(NoticeCode.TIME_UNKNOWN))
        jie_dates = {jie.astimezone(zone).date() for jie in lunar_adapter.jie_times_around(utc)}
        if solar_date in jie_dates:
            notices.append(Notice(NoticeCode.NEAR_SOLAR_TERM))

    return BirthMoment(
        solar_date=solar_date,
        utc=utc if time_known else None,
        solar_term_wallclock=solar_term_wallclock,
        corrected_local=corrected_local,
        time_known=time_known,
        notices=tuple(notices),
    )


def _solar_date_of(birth: BirthInput) -> date:
    """음력 입력은 양력으로 바꾼다. 그해에 없는 윤달·날짜면 InvalidInputError (spec 3)."""
    if birth.calendar is CalendarType.SOLAR:
        if isinstance(birth.date, LunarDate):
            raise InvalidInputError("양력 입력에는 LunarDate를 쓸 수 없습니다.")
        return birth.date
    lunar = birth.date
    return lunar_adapter.lunar_to_solar(lunar.year, lunar.month, lunar.day, birth.is_leap_month)


def _local_to_utc(local_naive: datetime, zone: ZoneInfo) -> tuple[datetime, tuple[Notice, ...]]:
    """현지 벽시계를 UTC로 바꾼다. 공백이면 뒤로 밀어 해석하고, 중복이면 앞(fold=0)을 쓴다."""
    first = local_naive.replace(tzinfo=zone, fold=0)
    second = local_naive.replace(tzinfo=zone, fold=1)
    first_utc = first.astimezone(UTC)
    second_utc = second.astimezone(UTC)

    # fold=0은 전환 직전 오프셋을 쓰므로, 공백 시각은 UTC로 왕복하면 뒤로 밀린 벽시계가 된다.
    is_gap = first_utc.astimezone(zone).replace(tzinfo=None) != local_naive
    if is_gap:
        return first_utc, (Notice(NoticeCode.NONEXISTENT_LOCAL_TIME),)
    if first_utc != second_utc:
        return first_utc, (Notice(NoticeCode.AMBIGUOUS_LOCAL_TIME),)
    return first_utc, ()


def birth_hour(birth: BirthInput) -> BirthHour:
    """출생 시각의 시진과 그 절대 시각 구간을 구한다.

    원국과 같은 출생 시각 해석(resolve_birth_moment)을 쓴다. 시진 경계는 보정 시각의 홀수 정시이고,
    경도 보정을 거꾸로 빼서 절대 시각으로 바꾼다. 시간 모름은 날짜 범위 검사보다 먼저 거절한다.
    """
    if birth.time is None:
        raise InvalidInputError("birth.time가 없습니다.")
    moment = resolve_birth_moment(birth)
    if moment.utc is None:  # 시간 검사 뒤라 도달하지 않음, mypy 좁히기용
        raise InvalidInputError("birth.time가 없습니다.")

    correction = moment.corrected_local - moment.utc.replace(tzinfo=None)
    corrected = moment.corrected_local
    # 홀수 시각(23, 1, 3, ...)이 시진의 시작이므로 짝수 시각이면 한 시간 앞으로 당긴다.
    hours_since_start = 0 if corrected.hour % 2 == 1 else 1
    start_corrected = corrected.replace(minute=0, second=0, microsecond=0) - timedelta(
        hours=hours_since_start
    )
    branch = list(Branch)[((start_corrected.hour + 1) // 2) % len(Branch)]
    start_utc = (start_corrected - correction).replace(tzinfo=UTC)
    return BirthHour(branch, start_utc, start_utc + HOUR_BRANCH_SPAN, moment.notices)
