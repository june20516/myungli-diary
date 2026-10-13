from datetime import date, time

import pytest

from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.calendar_core.birth import BirthInput, BirthMoment, resolve_birth_moment
from myungli_engine.chart.luck_cycles import LuckCycles, build_luck_cycles
from myungli_engine.domain.enums import CalendarType, Gender, NoticeCode
from myungli_engine.rules.relations import RelationKind, active, find_relations


def make_moment(d: date, t: time | None, gender: Gender) -> BirthMoment:
    return resolve_birth_moment(BirthInput(CalendarType.SOLAR, False, d, t, gender, "Asia/Seoul", None))


def cycles(gender: Gender, t: time | None = time(10, 30), as_of: date = date(2026, 10, 10)) -> LuckCycles:
    moment = make_moment(date(1990, 5, 17), t, gender)  # 庚午년: 양간
    return build_luck_cycles(moment, gender, lunar_adapter.pillars_for(moment), as_of)


def test_luck_direction() -> None:
    assert cycles(Gender.MALE).forward is True
    assert cycles(Gender.FEMALE).forward is False


def test_luck_direction_yin_year_stem() -> None:
    moment = make_moment(date(1991, 5, 17), time(10, 30), Gender.MALE)  # 辛未년: 음간
    natal = lunar_adapter.pillars_for(moment)
    assert build_luck_cycles(moment, Gender.MALE, natal, date(2026, 1, 1)).forward is False
    assert build_luck_cycles(moment, Gender.FEMALE, natal, date(2026, 1, 1)).forward is True


def test_luck_periods_count_and_ages() -> None:
    result = cycles(Gender.MALE)
    assert len(result.periods) == 10
    ages = [p.start_age for p in result.periods]
    assert ages == [result.start_years + 10 * i for i in range(10)]
    birth_year = 1990
    assert all(p.start_age_korean == p.start_year - birth_year + 1 for p in result.periods)
    assert [p.start_year for p in result.periods] == [result.periods[0].start_year + 10 * i for i in range(10)]


# 기댓값: lunar-python DaYun.getStartYear()·getStartAge()(虚岁) (getDaYun(11)[1:]의 첫 대운)
@pytest.mark.parametrize(
    ("birth", "gender", "start", "first_start_year", "first_age_korean"),
    [
        # 3년 7개월 10일 → 1962-06-07 시작: 개월 수 때문에 해가 넘어간다
        (date(1958, 10, 28), Gender.MALE, (3, 7), 1962, 5),
        # 6년 5개월 → 1965-03-28 시작
        (date(1958, 10, 28), Gender.FEMALE, (6, 5), 1965, 8),
        # 4년 3개월 → 1990-02-20 시작
        (date(1985, 11, 20), Gender.MALE, (4, 3), 1990, 6),
        # 6년 7개월 10일 → 1996-12-27 시작: 해가 넘어가지 않는다
        (date(1990, 5, 17), Gender.MALE, (6, 7), 1996, 7),
    ],
)
def test_period_start_year_and_korean_age_match_lunar_python(
    birth: date, gender: Gender, start: tuple[int, int], first_start_year: int, first_age_korean: int
) -> None:
    hour = time(14, 0) if birth.year == 1985 else time(10, 30) if birth.year == 1990 else time(10, 0)
    moment = make_moment(birth, hour, gender)
    result = build_luck_cycles(moment, gender, lunar_adapter.pillars_for(moment), date(2026, 10, 10))
    assert (result.start_years, result.start_months) == start
    first = result.periods[0]
    assert first.start_age == start[0]
    assert first.start_age_korean == first_age_korean
    assert result.periods[1].start_age_korean == first_age_korean + 10
    assert (first.start_year, result.periods[1].start_year) == (first_start_year, first_start_year + 10)


def test_years_follow_actual_period_start_year() -> None:
    # 1985-11-20 남: 대운이 1990, 2000, ...년에 시작한다. 1999년은 아직 첫 대운 구간이다.
    moment = make_moment(date(1985, 11, 20), time(14, 0), Gender.MALE)
    natal = lunar_adapter.pillars_for(moment)
    assert build_luck_cycles(moment, Gender.MALE, natal, date(1999, 12, 31)).years[0].year == 1990
    assert build_luck_cycles(moment, Gender.MALE, natal, date(2000, 1, 1)).years[0].year == 2000


def test_time_unknown_luck_notice() -> None:
    codes = {n.code for n in cycles(Gender.MALE, t=None).notices}
    assert NoticeCode.DAYUN_START_APPROXIMATE in codes
    assert NoticeCode.DAYUN_START_APPROXIMATE not in {n.code for n in cycles(Gender.MALE).notices}


def test_years_cover_the_period_containing_as_of() -> None:
    result = cycles(Gender.MALE, as_of=date(2026, 10, 10))
    years = [y.year for y in result.years]
    assert len(years) == 10 and years == list(range(years[0], years[0] + 10))
    assert years[0] <= 2026 <= years[-1]
    first_start = result.periods[0].start_year
    assert years[0] == first_start + 10 * ((2026 - first_start) // 10)


def test_years_before_first_period_use_first_period() -> None:
    result = cycles(Gender.MALE, as_of=date(1990, 6, 1))
    assert result.years[0].year == result.periods[0].start_year


def test_year_pillar_and_ten_god_known_values() -> None:
    moment = make_moment(date(1990, 5, 17), time(10, 30), Gender.MALE)
    natal = lunar_adapter.pillars_for(moment)
    result = build_luck_cycles(moment, Gender.MALE, natal, date(2026, 10, 10))
    for year_luck in result.years:
        after_ipchun = make_moment(date(year_luck.year, 6, 1), time(12, 0), Gender.MALE)
        assert year_luck.pillar == lunar_adapter.pillars_for(after_ipchun).year


def test_period_ten_gods_and_stage() -> None:
    moment = make_moment(date(1990, 5, 17), time(10, 30), Gender.MALE)
    natal = lunar_adapter.pillars_for(moment)
    first = build_luck_cycles(moment, Gender.MALE, natal, date(2026, 10, 10)).periods[0]
    assert first.twelve_stage is lunar_adapter.twelve_stage(natal.day.stem, first.pillar.branch)


def test_year_luck_relations_filled() -> None:
    moment = make_moment(date(1990, 5, 17), time(10, 30), Gender.MALE)
    natal = lunar_adapter.pillars_for(moment)
    result = build_luck_cycles(moment, Gender.MALE, natal, date(2026, 10, 10))
    valid = {kind.name for kind in RelationKind}
    for year_luck in result.years:
        expected = {r.kind.name for r in active(find_relations(natal, year_luck.pillar))}
        assert set(year_luck.relations_with_natal) == expected
        assert len(year_luck.relations_with_natal) == len(expected) and expected <= valid
    assert any(y.relations_with_natal for y in result.years)
