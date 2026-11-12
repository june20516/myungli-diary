from collections.abc import Callable
from datetime import date, datetime, timedelta, timezone

from myungli_engine.calendar_core import lunar_adapter as la
from myungli_engine.calendar_core.lunar_adapter import HourSlot
from myungli_engine.domain.enums import Branch
from myungli_engine.domain.models import Pillar
from myungli_engine.rules.focus_time import (
    NEXT_DAY_NIGHT_BRANCHES,
    PERIOD_BRANCHES,
    DayHours,
    FocusPeriod,
    grade_hour,
    pick_focus_times,
)

PillarOf = Callable[[str], Pillar]
SEOUL = timezone(timedelta(hours=9))
D = date(2026, 10, 10)


def make_slot(pillar_of: PillarOf, ganzhi: str, *, lucky: bool = False) -> HourSlot:
    pillar = pillar_of(ganzhi)
    start = datetime(2026, 10, 10, tzinfo=SEOUL) + timedelta(hours=2 * pillar.branch.index)
    return HourSlot(
        branch=pillar.branch, pillar=pillar, start=start, end=start + timedelta(hours=2), huangdao_lucky=lucky
    )


def test_day_clash_hour_is_excluded(pillar_of: PillarOf) -> None:
    """時破: 시지가 일지와 충이면 후보에서 뺀다(用時法 時破大凶)."""
    assert grade_hour(make_slot(pillar_of, "庚午"), pillar_of("甲子"), pillar_of("乙亥"), D) is None


def test_day_goods(pillar_of: PillarOf) -> None:
    day, year = pillar_of("甲子"), pillar_of("戊戌")
    goods = {
        ganzhi: grade_hour(make_slot(pillar_of, ganzhi), day, year, D)
        for ganzhi in ("甲子", "戊辰", "乙丑", "丙寅")
    }
    assert goods["甲子"].day_goods == ("build",)
    assert goods["戊辰"].day_goods == ("samhap",)
    assert goods["乙丑"].day_goods == ("yukhap", "gwiin")  # 子丑 육합, 甲의 귀인 丑
    assert goods["丙寅"].day_goods == ("rok", "ma")  # 甲의 녹 寅, 子의 역마 寅


def test_birth_year_goods_and_light_bads(pillar_of: PillarOf) -> None:
    year = pillar_of("乙亥")
    day = pillar_of("丙寅")
    grade = grade_hour(make_slot(pillar_of, "庚寅"), day, year, D)
    assert grade is not None
    assert "stem_hap" in grade.year_goods  # 乙庚 합(合官)
    jangsaeng = grade_hour(make_slot(pillar_of, "壬午"), day, year, D)
    assert jangsaeng is not None and "jangsaeng" in jangsaeng.year_goods  # 乙의 長生 午
    clash = grade_hour(make_slot(pillar_of, "辛巳"), day, year, D)
    assert clash is not None
    assert clash.light_bads == ("chung_myeong", "geuk_myeong")  # 巳亥 충, 辛은 乙의 七殺


def test_obulu_unless_hour_branch_generates_day(pillar_of: PillarOf) -> None:
    """五不遇: 시간이 일간을 극한다. 시지가 일간이나 일지를 생하면 아니다(卷七 按語)."""
    day, year = pillar_of("甲寅"), pillar_of("戊戌")
    obulu = grade_hour(make_slot(pillar_of, "庚午"), day, year, D)
    assert obulu is not None and "obulu" in obulu.second_bads
    rescued = grade_hour(make_slot(pillar_of, "庚子"), day, year, D)  # 子(수)가 甲(목)을 생함
    assert rescued is not None and "obulu" not in rescued.second_bads
    rescued = grade_hour(
        make_slot(pillar_of, "庚午"), pillar_of("甲辰"), year, D
    )  # 午(화)가 일지 辰(토)를 생함
    assert rescued is not None and "obulu" not in rescued.second_bads


def test_hyeong_is_second_bad(pillar_of: PillarOf) -> None:
    grade = grade_hour(make_slot(pillar_of, "丁卯"), pillar_of("甲子"), pillar_of("戊戌"), D)
    assert grade is not None and "hyeong" in grade.second_bads  # 子卯 형


def _hours(day: date) -> DayHours:
    return DayHours(date=day, pillar=la.day_pillar(day), slots=la.hour_slots(day, "Asia/Seoul"))


def test_one_pick_per_period_from_its_branches(pillar_of: PillarOf) -> None:
    today, tomorrow = _hours(D), _hours(D + timedelta(days=1))
    year = pillar_of("乙亥")
    picks = pick_focus_times(today, tomorrow, year)
    assert [pick.period for pick in picks] == [FocusPeriod.DAY, FocusPeriod.NIGHT]
    for pick in picks:
        assert pick.grade.slot.branch in PERIOD_BRANCHES[pick.period]


def test_night_hours_after_hae_belong_to_next_day(pillar_of: PillarOf) -> None:
    """밤은 그날 해시와 다음 날 자시~묘시이고, 시진마다 자기 날의 일진으로 판정한다(#1008)."""
    today, tomorrow = _hours(D), _hours(D + timedelta(days=1))
    year = pillar_of("乙亥")
    for start in range(60):
        today, tomorrow = _hours(D + timedelta(days=start)), _hours(D + timedelta(days=start + 1))
        night = pick_focus_times(today, tomorrow, year)[1].grade
        expected = tomorrow if night.slot.branch in NEXT_DAY_NIGHT_BRANCHES else today
        assert (night.day_date, night.day) == (expected.date, expected.pillar)
        assert night.slot in expected.slots
        assert grade_hour(night.slot, expected.pillar, year, expected.date) == night
    assert night.slot.start >= today.slots[-1].start  # 밤은 그날 해시 시작 뒤


def test_order_second_bad_then_goods_then_light_bad_then_huangdao(pillar_of: PillarOf) -> None:
    day, year = pillar_of("甲子"), pillar_of("戊戌")
    order = PERIOD_BRANCHES[FocusPeriod.DAY]
    grades = {g: grade_hour(make_slot(pillar_of, g), day, year, D) for g in ("戊辰", "乙巳", "庚午")}
    assert grades["庚午"] is None  # 時破
    samhap, plain = grades["戊辰"], grades["乙巳"]
    assert samhap is not None and plain is not None
    assert samhap.key(order) < plain.key(order)
    lucky = grade_hour(make_slot(pillar_of, "乙巳", lucky=True), day, year, D)
    assert lucky is not None and lucky.key(order) < plain.key(order)


def test_ties_start_from_jin_by_day_and_hae_by_night(pillar_of: PillarOf) -> None:
    assert PERIOD_BRANCHES[FocusPeriod.DAY][0] is Branch.JIN
    assert PERIOD_BRANCHES[FocusPeriod.NIGHT][0] is Branch.HAE
    assert set(PERIOD_BRANCHES[FocusPeriod.DAY]) | set(PERIOD_BRANCHES[FocusPeriod.NIGHT]) == set(Branch)


def test_period_hours_cover_whole_period_in_time_order(pillar_of: PillarOf) -> None:
    """구간 시진 전부(#1078): 낮 7개, 밤 5개가 시간 순으로 이어지고, 고른 시진은 그 안의 같은 값이다."""
    year = pillar_of("乙亥")
    for start in range(30):
        today, tomorrow = _hours(D + timedelta(days=start)), _hours(D + timedelta(days=start + 1))
        for pick in pick_focus_times(today, tomorrow, year):
            assert tuple(hour.slot.branch for hour in pick.hours) == PERIOD_BRANCHES[pick.period]
            for before, after in zip(pick.hours, pick.hours[1:], strict=False):
                assert before.slot.end == after.slot.start
            for hour in pick.hours:
                expected = tomorrow if pick.period is FocusPeriod.NIGHT and hour.slot.branch in NEXT_DAY_NIGHT_BRANCHES else today
                assert (hour.day_date, hour.day) == (expected.date, expected.pillar)
            chosen = next(hour for hour in pick.hours if hour.slot == pick.grade.slot)
            assert (chosen.day_date, chosen.day) == (pick.grade.day_date, pick.grade.day)
