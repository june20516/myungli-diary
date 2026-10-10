"""출생 현지 시각을 UTC, 절기 비교용 시각, 시주·일주용 보정 시각으로 바꾼다 (spec 4.1, 4.2)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from myungri_engine.constants.longitudes import representative_longitude
from myungri_engine.domain.enums import CalendarType, Gender, NoticeCode
from myungri_engine.domain.errors import InvalidInputError, OutOfRangeError
from myungri_engine.domain.models import Notice

SUPPORTED_MIN_DATE = date(1900, 1, 31)
SUPPORTED_MAX_DATE = date(2099, 12, 31)

SOLAR_TERM_TIMEZONE = timezone(timedelta(hours=8))  # lunar-python 절기 시각 기준
UNKNOWN_TIME_FALLBACK = time(12, 0)
SECONDS_PER_DEGREE = 240  # 경도 1도 = 시간 4분
ZI_HOUR_START_HOUR = 23
ZI_HOUR_END_HOUR = 0


@dataclass(frozen=True, slots=True)
class BirthInput:
    """출생 입력. 음력이면 date의 연·월·일을 음력 값으로 해석한다."""

    calendar: CalendarType
    is_leap_month: bool
    date: date
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


def validate_civil_date(d: date) -> None:
    if not SUPPORTED_MIN_DATE <= d <= SUPPORTED_MAX_DATE:
        raise OutOfRangeError(f"지원 범위(1900-01-31 ~ 2099-12-31) 밖의 날짜입니다: {d.isoformat()}")


def resolve_birth_moment(birth: BirthInput) -> BirthMoment:
    if birth.calendar is CalendarType.LUNAR:
        raise NotImplementedError("음력 입력은 Task 5에서 lunar_to_solar와 함께 연결합니다.")

    validate_civil_date(birth.date)
    zone = _load_zone(birth.timezone)
    time_known = birth.time is not None
    local_time = birth.time if birth.time is not None else UNKNOWN_TIME_FALLBACK
    local_naive = datetime.combine(birth.date, local_time)

    utc, local_notices = _local_to_utc(local_naive, zone)
    standard_offset = _standard_offset_hours(utc, zone)
    longitude = (
        birth.longitude
        if birth.longitude is not None
        else representative_longitude(birth.timezone, standard_offset)
    )

    solar_term_wallclock = utc.astimezone(SOLAR_TERM_TIMEZONE).replace(tzinfo=None)
    corrected_local = utc.replace(tzinfo=None) + timedelta(seconds=round(longitude * SECONDS_PER_DEGREE))

    notices: list[Notice] = []
    if time_known:
        notices.extend(local_notices)
        if corrected_local.hour in (ZI_HOUR_START_HOUR, ZI_HOUR_END_HOUR):
            notices.append(Notice(NoticeCode.ZI_HOUR_NEXT_DAY))
    else:
        notices.append(Notice(NoticeCode.TIME_UNKNOWN))

    return BirthMoment(
        solar_date=birth.date,
        utc=utc if time_known else None,
        solar_term_wallclock=solar_term_wallclock,
        corrected_local=corrected_local,
        time_known=time_known,
        notices=tuple(notices),
    )


def _load_zone(name: str) -> ZoneInfo:
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError) as error:
        raise InvalidInputError(f"알 수 없는 시간대입니다: {name!r}") from error


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


def _standard_offset_hours(utc: datetime, zone: ZoneInfo) -> float:
    """출생 시점의 표준 오프셋(서머타임 제외)을 시간 단위로 돌려준다."""
    local = utc.astimezone(zone)
    offset = local.utcoffset()
    dst = local.dst() or timedelta(0)
    assert offset is not None
    return (offset - dst).total_seconds() / 3600
