from datetime import date, time

from myungri_engine.calendar_core import lunar_adapter
from myungri_engine.calendar_core.birth import BirthInput, BirthMoment, resolve_birth_moment
from myungri_engine.chart.luck_cycles import LuckCycles, build_luck_cycles
from myungri_engine.domain.enums import CalendarType, Gender, NoticeCode
from myungri_engine.rules.relations import RelationKind, active, find_relations


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
    assert all(p.start_age_korean == p.start_age + 1 for p in result.periods)


def test_time_unknown_luck_notice() -> None:
    codes = {n.code for n in cycles(Gender.MALE, t=None).notices}
    assert NoticeCode.DAYUN_START_APPROXIMATE in codes
    assert NoticeCode.DAYUN_START_APPROXIMATE not in {n.code for n in cycles(Gender.MALE).notices}


def test_years_cover_the_period_containing_as_of() -> None:
    result = cycles(Gender.MALE, as_of=date(2026, 10, 10))
    years = [y.year for y in result.years]
    assert len(years) == 10 and years == list(range(years[0], years[0] + 10))
    assert years[0] <= 2026 <= years[-1]
    assert years[0] == 1990 + result.start_years + 10 * ((2026 - 1990 - result.start_years) // 10)


def test_years_before_first_period_use_first_period() -> None:
    result = cycles(Gender.MALE, as_of=date(1990, 6, 1))
    assert result.years[0].year == 1990 + result.start_years


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
