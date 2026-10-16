"""한국 음력 (KST 합삭·무중치윤). 기댓값은 KASI 음양력 API로 확인한 값이다."""

from datetime import date

import pytest

from myungli_engine.calendar_core import korean_lunar as kl
from myungli_engine.domain.errors import InvalidInputError, OutOfRangeError


def test_solar_to_lunar_ordinary_and_leap_months() -> None:
    assert kl.solar_to_lunar(date(2024, 2, 10)) == kl.KoreanLunarDate(2024, 1, 1, False)
    assert kl.solar_to_lunar(date(2023, 4, 15)) == kl.KoreanLunarDate(2023, 2, 25, True)
    assert kl.solar_to_lunar(date(1900, 2, 1)) == kl.KoreanLunarDate(1900, 1, 2, False)
    assert kl.solar_to_lunar(date(2050, 12, 15)) == kl.KoreanLunarDate(2050, 11, 2, False)


def test_new_moon_late_in_utc8_starts_month_next_day_in_kst() -> None:
    # 합삭 2023-05-19 23:53(UTC+8) = 2023-05-20 00:53(KST): 한국 4월 초하루는 5월 20일
    assert kl.solar_to_lunar(date(2023, 5, 19)) == kl.KoreanLunarDate(2023, 3, 30, False)
    assert kl.solar_to_lunar(date(2023, 5, 20)) == kl.KoreanLunarDate(2023, 4, 1, False)


def test_2012_leap_month_is_third() -> None:
    # 한국 2012년 윤3월 (중국 음력은 윤4월)
    assert kl.solar_to_lunar(date(2012, 5, 1)) == kl.KoreanLunarDate(2012, 3, 11, True)
    assert kl.lunar_to_solar(2012, 3, 11, True) == date(2012, 5, 1)
    assert kl.lunar_to_solar(2012, 4, 12, False) == date(2012, 6, 1)
    with pytest.raises(InvalidInputError):
        kl.lunar_to_solar(2012, 4, 1, True)


def test_2017_leap_month_is_fifth() -> None:
    # 한국 2017년 윤5월 (중국 음력은 윤6월)
    assert kl.solar_to_lunar(date(2017, 7, 1)) == kl.KoreanLunarDate(2017, 5, 8, True)
    assert kl.lunar_to_solar(2017, 5, 8, True) == date(2017, 7, 1)
    assert kl.lunar_to_solar(2017, 6, 10, False) == date(2017, 8, 1)
    with pytest.raises(InvalidInputError):
        kl.lunar_to_solar(2017, 6, 1, True)


def test_month_length_follows_korean_calendar() -> None:
    # 한국 음력 1950년 4월은 30일까지 (중국 음력은 29일)
    assert kl.lunar_to_solar(1950, 4, 30, False) == date(1950, 6, 15)
    with pytest.raises(InvalidInputError):
        kl.lunar_to_solar(2024, 1, 30, False)  # 2024년 음력 1월은 29일까지


def test_invalid_and_out_of_range() -> None:
    with pytest.raises(InvalidInputError):
        kl.lunar_to_solar(2024, 2, 1, True)  # 2024년에는 윤달 없음
    with pytest.raises(InvalidInputError):
        kl.lunar_to_solar(2024, 13, 1, False)
    with pytest.raises(InvalidInputError):
        kl.lunar_to_solar(2024, 1, 0, False)
    with pytest.raises(OutOfRangeError):
        kl.lunar_to_solar(1899, 12, 1, False)
    with pytest.raises(OutOfRangeError):
        kl.solar_to_lunar(date(1900, 1, 30))
    with pytest.raises(OutOfRangeError):
        kl.solar_to_lunar(date(2100, 1, 1))


def test_supported_range_edges() -> None:
    assert kl.solar_to_lunar(date(1900, 1, 31)) == kl.KoreanLunarDate(1900, 1, 1, False)
    last = kl.solar_to_lunar(date(2099, 12, 31))
    assert kl.lunar_to_solar(last.year, last.month, last.day, last.is_leap_month) == date(2099, 12, 31)


def test_lunar_date_past_supported_solar_range_is_out_of_range() -> None:
    # 음력 2099년 12월 초하루는 양력 2100-01-10으로 지원 범위(D41) 밖
    with pytest.raises(OutOfRangeError):
        kl.lunar_to_solar(2099, 12, 1, False)


def test_month_has_leap_follows_korean_calendar() -> None:
    assert kl.month_has_leap(2012, 3) is True  # 한국 윤3월 (중국은 윤4월)
    assert kl.month_has_leap(2012, 4) is False
    assert kl.month_has_leap(2023, 2) is True
    assert kl.month_has_leap(2024, 2) is False


def test_month_has_leap_rejects_invalid_month_and_year() -> None:
    with pytest.raises(InvalidInputError):
        kl.month_has_leap(2024, 13)
    with pytest.raises(OutOfRangeError):
        kl.month_has_leap(1899, 1)
