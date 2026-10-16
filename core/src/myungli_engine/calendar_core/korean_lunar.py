"""한국 음력: 한국 표준시 기준 합삭과 중기(中氣)로 달을 나누고, 무중치윤 규칙으로 윤달을 정한다.

lunar-python의 음력은 중국 음력(UTC+8)이라, 합삭이나 중기가 UTC+8 23시대에 들면 한국 음력(KASI)과
초하루·윤달이 달라진다. 이 모듈은 lunar-python의 천문 계산(ShouXingUtil, 寿星天文历 계열)만 빌려
날짜 경계를 한국 기준으로 다시 잡는다.

천문 계산
* ShouXingUtil.msaLonT(w): 달과 해의 황경 차가 w(라디안)가 되는 순간. J2000(2000-01-01 12:00 TT)부터의
  율리우스 세기(TT). w = n x 2pi이면 n번째 합삭이며 n = 0은 2000-01-06 합삭이다.
* ShouXingUtil.saLonT(w): 태양 시황경이 w(라디안, 춘분 = 0을 기준으로 누적)가 되는 순간. 단위는 위와 같다.
  중기는 황경 30도의 배수이므로 w = k x pi/6이다(k = 0은 1999년 춘분, k = 9는 1999년 동지).
* TT 일수 t에서 ShouXingUtil.dtT(t)(델타 T, 일)를 빼면 UT 일수다. lunar-python의 shuoHigh·qiHigh는 여기에
  8/24를 더해 베이징 시각으로 만들지만, 이 모듈은 더하지 않고 UTC로 쓴 뒤 아래 기준 시간대로 바꾼다.
  자정 근처의 판정 오류를 피하려고 저정밀 보정식(msaLonT2·saLonT2) 대신 정밀식(msaLonT·saLonT)만 쓴다.

날짜 경계 (KASI 음양력 1900-02~2050-12 매월 1·15일 3,622건과 대조해 정함, 채택 규칙의 불일치 0건)
* 1912-01-01 이후: UTC+9(동경 135도). 한국이 이날부터 이 표준시를 썼다. 서머타임은 쓰지 않는다.
* 1912-01-01 이전: UTC+8. 이 기간 KASI 음력은 베이징 기준 시헌력과 같다.
* 시험한 다른 후보와 불일치 건수: 전 구간 UTC+9 16건, 전 구간 UTC+8 125건, Asia/Seoul 표준 오프셋
  (1908 이전 지방평균시 +8:28, 1908-04~1911 +8:30) 10건, 1908-04 이전만 UTC+8 6건, 1912 이전 UTC+8:30 12건.
  경계는 합삭 1911-12-20 23:40(UTC+8, KASI는 UTC+8 날짜)과 1914-06-23 23:33(UTC+8, KASI는 UTC+9 날짜)
  사이에 있고, 1912-01-01로 둔다.
* 1954-03-21~1961-08-09(표준시 UTC+8:30)는 UTC+9로 계산한다. 이 기간에는 KST 00:00~00:30에 든 합삭이 없고,
  그 시간대에 든 중기 5건도 윤달 위치를 바꾸지 않아 UTC+8:30으로 계산해도 달력이 같다(두 규칙 모두 불일치 0건). 그래서 단순한 규칙을 택했다.

월 번호 (무중치윤): 동지가 든 달을 11월로 한다. 연속한 두 동지월 사이에 달이 13개면, 그 사이에서
처음으로 중기가 없는 달이 윤달이고 앞 달의 번호를 잇는다.
"""

from __future__ import annotations

import math
from bisect import bisect_left, bisect_right
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta, timezone
from functools import cache
from typing import Final

from lunar_python.util import ShouXingUtil

from myungli_engine.domain.errors import InvalidInputError, OutOfRangeError

MIN_SOLAR_DATE: Final = date(1900, 1, 31)  # 음력 1900년 1월 1일
MAX_SOLAR_DATE: Final = date(2099, 12, 31)
MIN_LUNAR_YEAR: Final = 1900
MAX_LUNAR_YEAR: Final = 2099
MONTHS_PER_YEAR: Final = 12
WINTER_SOLSTICE_MONTH: Final = 11

_J2000_UTC: Final = datetime(2000, 1, 1, 12, tzinfo=UTC)
_DAYS_PER_CENTURY: Final = 36525
_SYNODIC_MONTH_DAYS: Final = 29.530588
_TROPICAL_YEAR_DAYS: Final = 365.2422
_NEW_MOON_EPOCH: Final = date(2000, 1, 6)  # n = 0 합삭
_MAJOR_TERM_EPOCH: Final = date(1999, 3, 21)  # k = 0 중기(1999년 춘분)
_MAJOR_TERMS_PER_YEAR: Final = 12
_WINTER_SOLSTICE_INDEX_1999: Final = 9  # 1999년 동지 = k 9
# 계산 구간: 음력 1899년 11월(1900-01-31이 든 동지 주기)부터 2099년 동지 다음 동지월까지
_FIRST_CYCLE_YEAR: Final = 1899
_LAST_CYCLE_YEAR: Final = 2099
_SCAN_START: Final = date(1899, 10, 1)
_SCAN_END: Final = date(2101, 3, 1)

_KST: Final = timezone(timedelta(hours=9))
_BEIJING: Final = timezone(timedelta(hours=8))
_KST_CALENDAR_START: Final = datetime(1912, 1, 1, tzinfo=_KST)


@dataclass(frozen=True, slots=True)
class KoreanLunarDate:
    year: int
    month: int
    day: int
    is_leap_month: bool


@dataclass(frozen=True, slots=True)
class _LunarMonth:
    year: int
    month: int
    is_leap_month: bool
    start: date
    day_count: int


@dataclass(frozen=True, slots=True)
class _Calendar:
    months: tuple[_LunarMonth, ...]
    starts: tuple[date, ...]
    by_key: dict[tuple[int, int, bool], _LunarMonth]


def solar_to_lunar(solar_date: date) -> KoreanLunarDate:
    if not MIN_SOLAR_DATE <= solar_date <= MAX_SOLAR_DATE:
        raise OutOfRangeError(f"지원 범위 밖의 양력 날짜입니다: {solar_date}")
    calendar = _calendar()
    month = calendar.months[bisect_right(calendar.starts, solar_date) - 1]
    day = (solar_date - month.start).days + 1
    return KoreanLunarDate(month.year, month.month, day, month.is_leap_month)


def lunar_to_solar(year: int, month: int, day: int, is_leap_month: bool) -> date:
    """음력 날짜를 양력으로 바꾼다.

    그해에 없는 윤달이나 없는 날짜면 InvalidInputError, 양력이 지원 범위(D41) 밖이면 OutOfRangeError.
    """
    _validate_lunar_month(year, month)
    lunar_month = _calendar().by_key.get((year, month, is_leap_month))
    if lunar_month is None:
        raise InvalidInputError(f"음력 {year}년에는 윤{month}월이 없습니다.")
    if not 1 <= day <= lunar_month.day_count:
        raise InvalidInputError(f"음력 {year}년 {month}월은 {lunar_month.day_count}일까지입니다: {day}")
    solar_date = lunar_month.start + timedelta(days=day - 1)
    if not MIN_SOLAR_DATE <= solar_date <= MAX_SOLAR_DATE:
        raise OutOfRangeError(f"지원 범위 밖의 양력 날짜가 됩니다: 음력 {year}-{month}-{day} → {solar_date}")
    return solar_date


def month_has_leap(year: int, month: int) -> bool:
    """음력 year년 month월 뒤에 같은 이름의 윤달이 있는지."""
    _validate_lunar_month(year, month)
    return (year, month, True) in _calendar().by_key


def _validate_lunar_month(year: int, month: int) -> None:
    if not MIN_LUNAR_YEAR <= year <= MAX_LUNAR_YEAR:
        raise OutOfRangeError(f"지원 범위 밖의 음력 연도입니다: {year}")
    if not 1 <= month <= MONTHS_PER_YEAR:
        raise InvalidInputError(f"음력 월이 잘못되었습니다: {month}")


def warm_up() -> None:
    """1900~2099년 달력을 미리 만든다. 첫 변환 때 드는 생성 시간을 서버 시작 때 치른다."""
    _calendar()


# --- 달력 생성 ---


@cache
def _calendar() -> _Calendar:
    new_moons = _new_moon_dates()
    major_terms = _major_term_dates()
    months: list[_LunarMonth] = []
    for cycle_year in range(_FIRST_CYCLE_YEAR, _LAST_CYCLE_YEAR + 1):
        months.extend(_solstice_cycle(cycle_year, new_moons, major_terms))
    return _Calendar(
        months=tuple(months),
        starts=tuple(month.start for month in months),
        by_key={(month.year, month.month, month.is_leap_month): month for month in months},
    )


def _solstice_cycle(
    cycle_year: int, new_moons: tuple[date, ...], major_terms: tuple[date, ...]
) -> list[_LunarMonth]:
    """cycle_year 동지가 든 달(11월)부터 다음 동지월 직전까지의 달들."""
    first = bisect_right(new_moons, _winter_solstice_date(cycle_year)) - 1
    last = bisect_right(new_moons, _winter_solstice_date(cycle_year + 1)) - 1
    starts = new_moons[first : last + 1]  # 마지막 항목은 다음 동지월의 시작(끝 경계)
    month_count = len(starts) - 1

    leap_index: int | None = None
    if month_count == MONTHS_PER_YEAR + 1:
        leap_index = next(
            index
            for index in range(1, month_count)
            if not _has_major_term(starts[index], starts[index + 1], major_terms)
        )

    months: list[_LunarMonth] = []
    year, number = cycle_year, WINTER_SOLSTICE_MONTH - 1
    for index in range(month_count):
        is_leap = index == leap_index
        if not is_leap:
            number = number % MONTHS_PER_YEAR + 1
            if number == 1:
                year += 1
        day_count = (starts[index + 1] - starts[index]).days
        months.append(_LunarMonth(year, number, is_leap, starts[index], day_count))
    return months


def _has_major_term(start: date, end: date, major_terms: tuple[date, ...]) -> bool:
    index = bisect_left(major_terms, start)
    return index < len(major_terms) and major_terms[index] < end


def _winter_solstice_date(year: int) -> date:
    index = _WINTER_SOLSTICE_INDEX_1999 + _MAJOR_TERMS_PER_YEAR * (year - 1999)
    return _calendar_date(_major_term_utc(index))


# --- 천문 시각 ---


def _new_moon_dates() -> tuple[date, ...]:
    first = math.floor((_SCAN_START - _NEW_MOON_EPOCH).days / _SYNODIC_MONTH_DAYS)
    last = math.ceil((_SCAN_END - _NEW_MOON_EPOCH).days / _SYNODIC_MONTH_DAYS)
    return tuple(_calendar_date(_new_moon_utc(n)) for n in range(first, last + 1))


def _major_term_dates() -> tuple[date, ...]:
    scale = _MAJOR_TERMS_PER_YEAR / _TROPICAL_YEAR_DAYS
    first = math.floor((_SCAN_START - _MAJOR_TERM_EPOCH).days * scale)
    last = math.ceil((_SCAN_END - _MAJOR_TERM_EPOCH).days * scale)
    return tuple(_calendar_date(_major_term_utc(k)) for k in range(first, last + 1))


def _new_moon_utc(index: int) -> datetime:
    """index번째 합삭(0 = 2000-01-06)의 UTC 시각."""
    centuries = float(ShouXingUtil.msaLonT(index * 2 * math.pi))
    return _terrestrial_centuries_to_utc(centuries)


def _major_term_utc(index: int) -> datetime:
    """index번째 중기(0 = 1999년 춘분, 황경 30도 간격)의 UTC 시각."""
    centuries = float(ShouXingUtil.saLonT(index * math.pi / 6))
    return _terrestrial_centuries_to_utc(centuries)


def _terrestrial_centuries_to_utc(centuries: float) -> datetime:
    terrestrial_days = centuries * _DAYS_PER_CENTURY
    universal_days = terrestrial_days - float(ShouXingUtil.dtT(terrestrial_days))
    return _J2000_UTC + timedelta(days=universal_days)


def _calendar_date(utc: datetime) -> date:
    """한국 음력의 날짜 경계로 본 날짜. 1912년부터 UTC+9, 그 전은 UTC+8 (모듈 docstring)."""
    zone = _KST if utc >= _KST_CALENDAR_START else _BEIJING
    return utc.astimezone(zone).date()
