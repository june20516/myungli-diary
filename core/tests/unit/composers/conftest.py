from datetime import date, time

import pytest

from myungri_engine.calendar_core.birth import BirthInput
from myungri_engine.domain.enums import CalendarType, Gender


def solar_birth(d: date, t: time | None, gender: Gender = Gender.MALE) -> BirthInput:
    return BirthInput(CalendarType.SOLAR, False, d, t, gender, "Asia/Seoul", None)


@pytest.fixture
def spring_birth() -> BirthInput:
    return solar_birth(date(1985, 3, 10), time(14, 30))


@pytest.fixture
def winter_birth() -> BirthInput:
    return solar_birth(date(1992, 11, 22), time(8, 0), Gender.FEMALE)


@pytest.fixture
def zi_hour_birth() -> BirthInput:
    """서울 00:10 출생 -> 보정 시각 23:40, 자시."""
    return solar_birth(date(1990, 5, 15), time(0, 10))


@pytest.fixture
def unknown_time_birth() -> BirthInput:
    return solar_birth(date(1978, 8, 3), None, Gender.FEMALE)
