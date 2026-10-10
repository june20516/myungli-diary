from datetime import UTC, date, datetime, time, timedelta
from itertools import pairwise
from zoneinfo import ZoneInfo

import pytest

from myungri_engine.calendar_core import lunar_adapter as la
from myungri_engine.calendar_core.birth import BirthInput, BirthMoment, resolve_birth_moment
from myungri_engine.domain.enums import Branch as B
from myungri_engine.domain.enums import CalendarType, Gender, NoticeCode, TwelveStage
from myungri_engine.domain.enums import Direction8 as D
from myungri_engine.domain.enums import Stem as S
from myungri_engine.domain.errors import InvalidInputError, OutOfRangeError
from myungri_engine.domain.models import Pillar

SEOUL = ZoneInfo("Asia/Seoul")


def moment(
    d: date,
    t: time | None,
    cal: CalendarType = CalendarType.SOLAR,
    leap: bool = False,
    gender: Gender = Gender.MALE,
) -> BirthMoment:
    return resolve_birth_moment(BirthInput(cal, leap, d, t, gender, "Asia/Seoul", None))


def codes(m: BirthMoment) -> set[NoticeCode]:
    return {n.code for n in m.notices}


# --- 사주팔자 ---


def test_zi_hour_next_day_pillar() -> None:  # 보정 23:10 → 다음 날 己卯일 甲子시 (07 §6 실행 확인값)
    p = la.pillars_for(moment(date(2024, 3, 15), time(23, 40)))
    assert p.day == Pillar(S.GI, B.MYO) and p.hour == Pillar(S.GAP, B.JA)


def test_year_changes_at_ipchun_not_jan1() -> None:  # Review Focus 2. 2024 입춘 = KST 17:27
    assert la.pillars_for(moment(date(2024, 2, 4), time(17, 26))).year == Pillar(S.GYE, B.MYO)
    assert la.pillars_for(moment(date(2024, 2, 4), time(17, 28))).year == Pillar(S.GAP, B.JIN)


def test_month_changes_at_ipchun() -> None:
    assert la.pillars_for(moment(date(2024, 2, 4), time(17, 26))).month == Pillar(S.EUL, B.CHUK)
    assert la.pillars_for(moment(date(2024, 2, 4), time(17, 28))).month == Pillar(S.BYEONG, B.IN)


def test_time_unknown_has_no_hour_pillar() -> None:
    p = la.pillars_for(moment(date(2026, 10, 10), None))
    assert p.hour is None
    assert p.day == Pillar(S.JEONG, B.SA)


# --- 절입 안내 ---


def test_near_solar_term_notice() -> None:
    assert NoticeCode.NEAR_SOLAR_TERM in codes(moment(date(2024, 2, 4), time(18, 0)))


def test_near_solar_term_boundary_120_minutes() -> None:
    # 2024 입춘 = KST 17:27:xx. 15:30은 120분 안, 15:20은 밖
    assert NoticeCode.NEAR_SOLAR_TERM in codes(moment(date(2024, 2, 4), time(15, 30)))
    assert NoticeCode.NEAR_SOLAR_TERM not in codes(moment(date(2024, 2, 4), time(15, 20)))


def test_no_near_solar_term_notice_far_from_jie() -> None:
    assert NoticeCode.NEAR_SOLAR_TERM not in codes(moment(date(2024, 3, 15), time(12, 0)))


def test_near_solar_term_ignores_zhongqi() -> None:  # 2024 우수(雨水, 中氣) = KST 2024-02-19 13:13
    assert NoticeCode.NEAR_SOLAR_TERM not in codes(moment(date(2024, 2, 19), time(13, 0)))


def test_time_unknown_on_jie_day_gets_notice() -> None:
    assert NoticeCode.NEAR_SOLAR_TERM in codes(moment(date(2024, 2, 4), None))
    assert NoticeCode.NEAR_SOLAR_TERM not in codes(moment(date(2024, 2, 5), None))


def test_nearest_solar_term_minutes() -> None:
    utc = datetime(2024, 2, 4, 9, 0, tzinfo=UTC)  # KST 18:00, 입춘 17:27 이후 약 33분
    assert 32 <= la.nearest_solar_term_minutes(utc) <= 34


# --- 지장간·12운성·공망 ---


def test_hidden_stems_main_qi_first() -> None:
    assert la.hidden_stems(B.SA) == (S.BYEONG, S.GYEONG, S.MU)
    assert la.hidden_stems(B.JA) == (S.GYE,)
    assert all(la.hidden_stems(b)[0].element == b.element for b in B)


@pytest.mark.parametrize(
    "stem,branch,stage",
    [
        (S.GAP, B.HAE, TwelveStage.JANGSAENG),
        (S.GAP, B.MYO, TwelveStage.JEWANG),
        (S.GAP, B.IN, TwelveStage.GEONROK),
        (S.GAP, B.MI, TwelveStage.MYO),
        (S.EUL, B.O, TwelveStage.JANGSAENG),
        (S.EUL, B.HAE, TwelveStage.SA),
        (S.BYEONG, B.IN, TwelveStage.JANGSAENG),
        (S.GYEONG, B.SA, TwelveStage.JANGSAENG),
        (S.IM, B.SHIN, TwelveStage.JANGSAENG),
        (S.GYE, B.MYO, TwelveStage.JANGSAENG),
        (S.SIN, B.JA, TwelveStage.JANGSAENG),
        (S.GAP, B.YU, TwelveStage.TAE),
        (S.GAP, B.SUL, TwelveStage.YANG),
    ],
)
def test_twelve_stage(stem: S, branch: B, stage: TwelveStage) -> None:
    assert la.twelve_stage(stem, branch) is stage


def test_twelve_stage_cycle_covers_all_stages() -> None:
    for stem in S:
        assert {la.twelve_stage(stem, b) for b in B} == set(TwelveStage)


def test_day_gongmang() -> None:
    assert la.day_gongmang(Pillar(S.GAP, B.JA)) == frozenset({B.SUL, B.HAE})
    assert la.day_gongmang(Pillar(S.JEONG, B.SA)) == frozenset({B.JA, B.CHUK})  # 甲寅순


# --- 음력 변환 ---


def test_lunar_to_solar_and_invalid() -> None:  # Review Focus 1
    assert la.lunar_to_solar(2023, 2, 1, True) == date(2023, 3, 22)  # 2023년 윤2월 1일
    assert la.lunar_to_solar(2023, 2, 1, False) == date(2023, 2, 20)
    with pytest.raises(InvalidInputError):
        la.lunar_to_solar(2024, 2, 1, True)  # 2024년에는 윤2월 없음
    with pytest.raises(InvalidInputError):
        la.lunar_to_solar(2024, 1, 30, False)  # 2024년 음력 1월은 29일까지
    with pytest.raises(InvalidInputError):
        la.lunar_to_solar(2024, 13, 1, False)


def test_lunar_to_solar_out_of_range_year() -> None:
    with pytest.raises(OutOfRangeError):
        la.lunar_to_solar(1899, 12, 1, False)


def test_lunar_birth_input_converted() -> None:
    m = moment(date(2023, 2, 1), time(12, 0), cal=CalendarType.LUNAR, leap=True)
    assert m.solar_date == date(2023, 3, 22)


def test_lunar_birth_input_invalid_leap_month() -> None:
    with pytest.raises(InvalidInputError):
        moment(date(2024, 2, 1), time(12, 0), cal=CalendarType.LUNAR, leap=True)


# --- 일진·길신 방위 ---


def test_day_pillar_uses_local_noon() -> None:
    assert la.day_pillar(date(2026, 10, 10)) == Pillar(S.JEONG, B.SA)
    assert la.day_pillar(date(2024, 3, 16)) == Pillar(S.GI, B.MYO)


def test_day_deity_directions() -> None:  # 2026-10-10 丁巳 (07 대화 실행값)
    assert dict(la.deity_directions(date(2026, 10, 10)))[la.DeityKind.XI] == D.S


def test_deity_directions_order_and_values() -> None:
    assert la.deity_directions(date(2026, 10, 10)) == (
        (la.DeityKind.XI, D.S),
        (la.DeityKind.FU, D.SE),
        (la.DeityKind.CAI, D.SW),
        (la.DeityKind.YANG_GUI, D.NW),
        (la.DeityKind.YIN_GUI, D.W),
    )


# --- 시진 ---


def test_seoul_hour_slot_boundaries() -> None:
    slots = la.hour_slots(date(2026, 10, 13), "Asia/Seoul")
    jin = next(s for s in slots if s.branch == B.JIN)
    assert (jin.start.hour, jin.start.minute, jin.end.hour, jin.end.minute) == (7, 30, 9, 30)


def test_seoul_hour_slots_cover_day_from_previous_zi() -> None:
    slots = la.hour_slots(date(2026, 10, 13), "Asia/Seoul")
    assert [s.branch for s in slots] == list(B)
    assert slots[0].start == datetime(2026, 10, 12, 23, 30, tzinfo=SEOUL)
    assert slots[-1].end == datetime(2026, 10, 13, 23, 30, tzinfo=SEOUL)
    assert all(a.end == b.start for a, b in pairwise(slots))


def test_hour_slot_pillars_follow_day_stem() -> None:
    slots = la.hour_slots(date(2024, 3, 16), "Asia/Seoul")  # 己卯일 → 甲子시부터
    assert slots[0].pillar == Pillar(S.GAP, B.JA)
    assert slots[-1].pillar == Pillar(S.EUL, B.HAE)
    assert all(s.pillar.branch == s.branch for s in slots)


def test_hour_slots_huangdao() -> None:
    # 卯일의 황도 시진: 子(司命)·寅(青龙)·卯(明堂)·午(金匮)·未(天德)·酉(玉堂)
    slots = la.hour_slots(date(2024, 3, 16), "Asia/Seoul")
    lucky = {s.branch for s in slots if s.huangdao_lucky}
    assert lucky == {B.JA, B.IN, B.MYO, B.O, B.MI, B.YU}


def test_dst_start_day_slots_ordered() -> None:  # Review Focus 3
    slots = la.hour_slots(date(2026, 3, 8), "America/New_York")
    assert len(slots) == 12 and all(a.end <= b.start for a, b in pairwise(slots))


def test_dst_start_day_slot_spans_real_two_hours() -> None:
    slots = la.hour_slots(date(2026, 3, 8), "America/New_York")
    # 같은 tzinfo끼리 빼면 벽시계 차이가 나오므로 UTC로 바꿔 실제 경과 시간을 비교한다.
    assert all(s.end.astimezone(UTC) - s.start.astimezone(UTC) == timedelta(hours=2) for s in slots)
    chuk = slots[1]
    assert (chuk.start.hour, chuk.end.hour) == (1, 4)  # 01:00 EST ~ 04:00 EDT


# --- 월간 정보 ---


def test_month_days_seoul_february_2024() -> None:
    days = la.month_days(2024, 2, "Asia/Seoul")
    assert len(days) == 29
    assert days[0].date == date(2024, 2, 1)
    ipchun = days[3]
    assert ipchun.solar_term is not None
    name, at = ipchun.solar_term
    assert name == "立春"
    assert (at.date(), at.hour, at.minute) == (date(2024, 2, 4), 17, 27)
    assert at.utcoffset() == timedelta(hours=9)
    assert days[18].solar_term is not None and days[18].solar_term[0] == "雨水"
    assert sum(1 for d in days if d.solar_term is not None) == 2
    assert days[9].lunar_month == 1 and days[9].lunar_day == 1  # 2024-02-10 설날
    assert days[9].pillar == la.day_pillar(date(2024, 2, 10))


def test_month_days_leap_month() -> None:
    days = la.month_days(2023, 3, "Asia/Seoul")
    d22 = days[21]
    assert (d22.lunar_month, d22.lunar_day, d22.is_leap_month) == (2, 1, True)


def test_month_days_term_date_shifts_with_timezone() -> None:
    # 2024 입춘 = UTC 2024-02-04 08:27 → 하와이(UTC-10)에서는 2월 3일
    days = la.month_days(2024, 2, "Pacific/Honolulu")
    assert days[2].solar_term is not None and days[2].solar_term[0] == "立春"
    assert days[3].solar_term is None


# --- 대운 ---


def test_luck_cycles_raw_forward_male_yang_year() -> None:
    m = moment(date(2024, 3, 15), time(12, 0))  # 甲辰년 丁卯월, 양년 남성 → 순행
    years, months, cycles = la.luck_cycles_raw(m, Gender.MALE)
    assert len(cycles) == 10
    assert cycles[0] == Pillar(S.MU, B.JIN)
    assert cycles[1] == Pillar(S.GI, B.SA)
    assert 0 <= years <= 10 and 0 <= months < 12


def test_luck_cycles_raw_backward_female_yang_year() -> None:
    m = moment(date(2024, 3, 15), time(12, 0), gender=Gender.FEMALE)
    _, _, cycles = la.luck_cycles_raw(m, Gender.FEMALE)
    assert cycles[0] == Pillar(S.BYEONG, B.IN)
