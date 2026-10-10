from datetime import date, time

from myungri_engine.calendar_core import lunar_adapter
from myungri_engine.calendar_core.birth import BirthInput, BirthMoment, resolve_birth_moment
from myungri_engine.chart.pillars import Position, build_chart
from myungri_engine.domain.enums import Branch as B
from myungri_engine.domain.enums import CalendarType, Gender, NoticeCode, TenGod, TwelveStage
from myungri_engine.domain.enums import Stem as S


def make_moment(d: date, t: time | None) -> BirthMoment:
    return resolve_birth_moment(BirthInput(CalendarType.SOLAR, False, d, t, Gender.MALE, "Asia/Seoul", None))


def test_chart_ten_gods_exclude_day_stem() -> None:
    chart = build_chart(make_moment(date(1990, 5, 17), time(10, 30)))
    assert Position.DAY_STEM not in chart.ten_gods
    assert Position.HOUR_STEM in chart.ten_gods and Position.DAY_BRANCH in chart.ten_gods


def test_time_unknown_has_no_hour_positions() -> None:
    chart = build_chart(make_moment(date(1990, 5, 17), None))
    hour_positions = {Position.HOUR_STEM, Position.HOUR_BRANCH}
    assert Position.HOUR_STEM not in chart.ten_gods and chart.pillars.hour is None
    for mapping in (chart.ten_gods, chart.hidden_stems, chart.twelve_stages):
        assert hour_positions.isdisjoint(mapping)
    assert all(hit.position not in hour_positions for hit in chart.shinsal)
    assert NoticeCode.TIME_UNKNOWN in {n.code for n in chart.notices}


def test_twelve_stage_known_value() -> None:
    assert lunar_adapter.twelve_stage(S.GAP, B.HAE) is TwelveStage.JANGSAENG


def test_chart_values_match_pillars() -> None:
    chart = build_chart(make_moment(date(1990, 5, 17), time(10, 30)))
    day = chart.pillars.day
    # 지장간 첫 항목이 정기이고 그 십성이 지지 십성과 같다
    for position in (Position.YEAR_BRANCH, Position.MONTH_BRANCH, Position.DAY_BRANCH, Position.HOUR_BRANCH):
        assert chart.hidden_stems[position][0][1] == chart.ten_gods[position]
    assert chart.twelve_stages[Position.DAY_BRANCH] is lunar_adapter.twelve_stage(day.stem, day.branch)
    assert chart.gongmang == lunar_adapter.day_gongmang(day)


def test_hidden_stems_carry_ten_gods() -> None:
    chart = build_chart(make_moment(date(1990, 5, 17), time(10, 30)))
    stems = [stem for stem, _ in chart.hidden_stems[Position.MONTH_BRANCH]]
    assert stems == list(lunar_adapter.hidden_stems(chart.pillars.month.branch))
    assert all(isinstance(god, TenGod) for _, god in chart.hidden_stems[Position.MONTH_BRANCH])
