"""회귀 스냅샷 공용: 고정 샘플 원국 10개와 결정적 직렬화 (spec 13.7)."""

from collections.abc import Mapping
from dataclasses import fields, is_dataclass
from datetime import date, datetime, time
from enum import Enum

from myungri_engine.calendar_core.birth import BirthInput, LunarDate
from myungri_engine.domain.enums import CalendarType, Gender

SEOUL = "Asia/Seoul"


def _solar(d: date, t: time | None, gender: Gender) -> BirthInput:
    return BirthInput(CalendarType.SOLAR, False, d, t, gender, SEOUL, None)


SAMPLE_BIRTHS: dict[str, BirthInput] = {
    "zi_hour": _solar(date(1990, 5, 15), time(0, 10), Gender.MALE),
    "time_unknown": _solar(date(1978, 8, 3), None, Gender.FEMALE),
    "dst_1956": _solar(date(1956, 7, 15), time(15, 20), Gender.FEMALE),
    "utc_0830_1958": _solar(date(1958, 3, 10), time(9, 0), Gender.MALE),
    "before_ipchun": _solar(date(2024, 2, 4), time(17, 0), Gender.FEMALE),
    "lunar_leap_month": BirthInput(
        CalendarType.LUNAR, True, LunarDate(2023, 2, 15), time(10, 0), Gender.FEMALE, SEOUL, None
    ),
    "general_male_1": _solar(date(1985, 3, 10), time(14, 30), Gender.MALE),
    "general_female_1": _solar(date(1992, 11, 22), time(8, 0), Gender.FEMALE),
    "general_male_2": _solar(date(2001, 9, 9), time(21, 15), Gender.MALE),
    "general_female_2": _solar(date(1969, 12, 25), time(6, 45), Gender.FEMALE),
}


def to_plain(value: object) -> object:
    """결정적인 비교용 구조로 바꾼다. enum은 이름, 날짜·시각은 ISO 문자열, 매핑은 키 정렬."""
    if isinstance(value, Enum):
        return value.name
    if isinstance(value, datetime | date | time):
        return value.isoformat()
    if is_dataclass(value) and not isinstance(value, type):
        return {field.name: to_plain(getattr(value, field.name)) for field in fields(value)}
    if isinstance(value, Mapping):
        return {str(key): to_plain(value[key]) for key in sorted(value, key=str)}
    if isinstance(value, tuple | list):
        return [to_plain(item) for item in value]
    if isinstance(value, frozenset | set):
        return sorted((to_plain(item) for item in value), key=repr)
    if value is None or isinstance(value, str | int | float | bool):
        return value
    raise TypeError(f"직렬화할 수 없는 타입입니다: {type(value).__name__}")
