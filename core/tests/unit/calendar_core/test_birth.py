from datetime import UTC, date, datetime, time

import pytest

from myungri_engine.calendar_core.birth import (
    BirthInput,
    BirthMoment,
    resolve_birth_moment,
    validate_civil_date,
)
from myungri_engine.domain.enums import CalendarType, Gender, NoticeCode
from myungri_engine.domain.errors import InvalidInputError, OutOfRangeError


def seoul(
    d: date, t: time | None = None, tz: str = "Asia/Seoul", lon: float | None = None
) -> BirthInput:
    return BirthInput(CalendarType.SOLAR, False, d, t, Gender.MALE, tz, lon)


def codes(m: BirthMoment) -> set[NoticeCode]:
    return {n.code for n in m.notices}


def utc_of(m: BirthMoment) -> datetime:
    assert m.utc is not None
    return m.utc


def test_modern_seoul_offset_and_lmt() -> None:
    m = resolve_birth_moment(seoul(date(2024, 3, 15), time(23, 40)))
    assert m.utc == datetime(2024, 3, 15, 14, 40, tzinfo=UTC)
    assert m.solar_term_wallclock == datetime(2024, 3, 15, 22, 40)  # UTC+8
    assert m.corrected_local == datetime(2024, 3, 15, 23, 10)  # UTC+8:30 (= KST-30분)
    assert NoticeCode.ZI_HOUR_NEXT_DAY in codes(m)


@pytest.mark.parametrize(
    "d,t,utc_hour_min",
    [
        (date(1956, 7, 1), time(12, 0), (2, 30)),  # UTC+8:30 + 서머타임 = +9:30
        (date(1958, 1, 1), time(12, 0), (3, 30)),  # UTC+8:30
        (date(1987, 7, 1), time(12, 0), (2, 0)),  # UTC+9 + 서머타임 = +10
    ],
)
def test_historical_offsets(d: date, t: time, utc_hour_min: tuple[int, int]) -> None:
    m = resolve_birth_moment(seoul(d, t))
    assert (utc_of(m).hour, utc_of(m).minute) == utc_hour_min


def test_dst_gap_shifts_forward_with_notice() -> None:
    m = resolve_birth_moment(seoul(date(1987, 5, 10), time(2, 30)))
    assert NoticeCode.NONEXISTENT_LOCAL_TIME in codes(m)
    assert m.utc == datetime(1987, 5, 9, 17, 30, tzinfo=UTC)  # 03:30 KDT로 해석


def test_dst_overlap_uses_first_with_notice() -> None:
    m = resolve_birth_moment(seoul(date(1987, 10, 11), time(2, 30)))
    assert NoticeCode.AMBIGUOUS_LOCAL_TIME in codes(m)
    assert m.utc == datetime(1987, 10, 10, 16, 30, tzinfo=UTC)  # 서머타임(+10) 쪽


def test_explicit_longitude_overrides_representative() -> None:
    m = resolve_birth_moment(seoul(date(2024, 3, 15), time(12, 0), tz="Asia/Tokyo", lon=139.7))
    assert m.corrected_local == datetime(2024, 3, 15, 12, 18, 48)  # UTC+9:18:48


def test_other_timezone_uses_standard_meridian_ignoring_dst() -> None:
    # 뉴욕 서머타임(UTC-4)이어도 표준 자오선 75W(UTC-5)로 보정: 벽시계 12:00 -> 보정 11:00
    m = resolve_birth_moment(seoul(date(2024, 7, 1), time(12, 0), tz="America/New_York"))
    assert m.corrected_local == datetime(2024, 7, 1, 11, 0)
    assert m.solar_term_wallclock == datetime(2024, 7, 2, 0, 0)  # 16:00 UTC -> UTC+8


def test_time_unknown() -> None:
    m = resolve_birth_moment(seoul(date(2024, 3, 15)))
    assert m.time_known is False and m.utc is None and NoticeCode.TIME_UNKNOWN in codes(m)
    assert m.solar_term_wallclock == datetime(2024, 3, 15, 11, 0)  # 정오 KST = 03:00 UTC
    assert m.corrected_local == datetime(2024, 3, 15, 11, 30)
    assert NoticeCode.ZI_HOUR_NEXT_DAY not in codes(m)


def test_normal_time_has_no_notices() -> None:
    assert resolve_birth_moment(seoul(date(2024, 3, 15), time(12, 0))).notices == ()


def test_zi_hour_boundaries_use_corrected_time() -> None:
    # KST 23:29 -> 보정 22:59 (자시 아님), KST 23:30 -> 보정 23:00 (자시)
    assert NoticeCode.ZI_HOUR_NEXT_DAY not in codes(resolve_birth_moment(seoul(date(2024, 3, 15), time(23, 29))))
    assert NoticeCode.ZI_HOUR_NEXT_DAY in codes(resolve_birth_moment(seoul(date(2024, 3, 15), time(23, 30))))
    # KST 01:29 -> 보정 00:59 (자시), KST 01:30 -> 01:00 (축시)
    assert NoticeCode.ZI_HOUR_NEXT_DAY in codes(resolve_birth_moment(seoul(date(2024, 3, 15), time(1, 29))))
    assert NoticeCode.ZI_HOUR_NEXT_DAY not in codes(resolve_birth_moment(seoul(date(2024, 3, 15), time(1, 30))))


@pytest.mark.parametrize("d", [date(1900, 1, 30), date(2100, 1, 1)])
def test_birth_out_of_range(d: date) -> None:
    with pytest.raises(OutOfRangeError):
        resolve_birth_moment(seoul(d, time(12, 0)))


def test_birth_range_edges_accepted() -> None:
    resolve_birth_moment(seoul(date(1900, 1, 31), time(12, 0)))
    resolve_birth_moment(seoul(date(2099, 12, 31), time(12, 0)))


@pytest.mark.parametrize("tz", ["Mars/Base", "", "../etc/passwd", "Asia/Seoul\x00"])
def test_unknown_timezone(tz: str) -> None:
    with pytest.raises(InvalidInputError):
        resolve_birth_moment(seoul(date(2024, 3, 15), time(12, 0), tz=tz))


def test_lunar_not_implemented_yet() -> None:
    birth = BirthInput(CalendarType.LUNAR, False, date(2024, 2, 5), None, Gender.FEMALE, "Asia/Seoul", None)
    with pytest.raises(NotImplementedError):
        resolve_birth_moment(birth)


def test_civil_date_range() -> None:
    validate_civil_date(date(1900, 1, 31))
    validate_civil_date(date(2099, 12, 31))
    with pytest.raises(OutOfRangeError):
        validate_civil_date(date(2100, 1, 1))
    with pytest.raises(OutOfRangeError):
        validate_civil_date(date(1900, 1, 30))
