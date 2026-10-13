from datetime import date

import pytest

from myungli_engine.calendar_core.birth import BirthInput
from myungli_engine.chart.personal_target import PersonalReading
from myungli_engine.chart.positions import BRANCH_POSITIONS, Position
from myungli_engine.composers.chart import ChartView, compose_chart
from myungli_engine.domain.enums import NoticeCode, PersonalTermKind, Shinsal
from myungli_engine.domain.errors import OutOfRangeError


def test_chart_notices_propagated(zi_hour_birth: BirthInput) -> None:
    view = compose_chart(zi_hour_birth, date(2026, 10, 10))
    assert NoticeCode.ZI_HOUR_NEXT_DAY in {notice.code for notice in view.notices}


def test_chart_notices_merge_luck_notices_without_duplicates(unknown_time_birth: BirthInput) -> None:
    view = compose_chart(unknown_time_birth, date(2026, 10, 10))
    codes = [notice.code for notice in view.notices]
    assert NoticeCode.TIME_UNKNOWN in codes
    assert NoticeCode.DAYUN_START_APPROXIMATE in codes
    assert len(codes) == len(set(view.notices))


def test_yongsin_judgment_key_follows_method(spring_birth: BirthInput) -> None:
    view = compose_chart(spring_birth, date(2026, 10, 10))
    assert view.yongsin_judgment.message_key == f"yongsin.method.{view.yongsin.method.name.lower()}"
    assert view.yongsin_judgment.params["yongsin"] == view.yongsin.yongsin.name
    assert view.yongsin_judgment.evidence == view.yongsin.evidence


def test_chart_as_of_out_of_range(spring_birth: BirthInput) -> None:
    with pytest.raises(OutOfRangeError):
        compose_chart(spring_birth, date(2100, 1, 1))


def _readings_of(view: ChartView, kind: PersonalTermKind) -> list[PersonalReading]:
    return [reading for reading in view.personal_readings if reading.kind is kind]


def test_personal_readings_cover_every_natal_term(spring_birth: BirthInput) -> None:
    view = compose_chart(spring_birth, date(2026, 10, 10))
    hidden_total = sum(len(stems) for stems in view.chart.hidden_stems.values())
    assert view.personal_readings[0].kind is PersonalTermKind.DAY_MASTER
    assert len(_readings_of(view, PersonalTermKind.DAY_MASTER)) == 1
    assert len(_readings_of(view, PersonalTermKind.TEN_GOD)) == len(view.chart.ten_gods)
    assert len(_readings_of(view, PersonalTermKind.HIDDEN_TEN_GOD)) == hidden_total
    assert len(_readings_of(view, PersonalTermKind.TWELVE_STAGE)) == 4
    assert len(_readings_of(view, PersonalTermKind.SHINSAL)) == len(view.chart.shinsal)


def test_hidden_readings_index_follows_hidden_stem_order(spring_birth: BirthInput) -> None:
    view = compose_chart(spring_birth, date(2026, 10, 10))
    hidden = _readings_of(view, PersonalTermKind.HIDDEN_TEN_GOD)
    expected = [
        (position, index)
        for position in BRANCH_POSITIONS
        for index in range(len(view.chart.hidden_stems[position]))
    ]
    assert [(reading.position, reading.index) for reading in hidden] == expected


def test_personal_readings_cover_luck_tables(spring_birth: BirthInput) -> None:
    view = compose_chart(spring_birth, date(2026, 10, 10))
    for kind in (
        PersonalTermKind.DAEUN_STEM_TEN_GOD,
        PersonalTermKind.DAEUN_BRANCH_TEN_GOD,
        PersonalTermKind.DAEUN_TWELVE_STAGE,
    ):
        assert [reading.index for reading in _readings_of(view, kind)] == list(range(10))
    seun = _readings_of(view, PersonalTermKind.SEUN_TEN_GOD)
    assert [reading.index for reading in seun] == list(range(len(view.luck.years)))
    assert all(reading.position is None and reading.shinsal is None for reading in seun)


def test_unknown_time_has_no_hour_readings(unknown_time_birth: BirthInput) -> None:
    view = compose_chart(unknown_time_birth, date(2026, 10, 10))
    hour_positions = {Position.HOUR_STEM, Position.HOUR_BRANCH}
    assert not [reading for reading in view.personal_readings if reading.position in hour_positions]


def test_current_flags_follow_as_of(spring_birth: BirthInput) -> None:
    view = compose_chart(spring_birth, date(2026, 10, 10))
    for kind in (
        PersonalTermKind.DAEUN_STEM_TEN_GOD,
        PersonalTermKind.DAEUN_BRANCH_TEN_GOD,
        PersonalTermKind.DAEUN_TWELVE_STAGE,
    ):
        flags = [reading.judgment.params["current"] for reading in _readings_of(view, kind)]
        assert flags.count(True) == 1
    current_seun = [
        view.luck.years[reading.index].year
        for reading in _readings_of(view, PersonalTermKind.SEUN_TEN_GOD)
        if reading.judgment.params["current"]
    ]
    assert current_seun == [2026]


def test_no_current_before_first_period(spring_birth: BirthInput) -> None:
    birth_year = spring_birth.date.year
    view = compose_chart(spring_birth, date(birth_year, 12, 31))
    assert view.luck.periods[0].start_year > birth_year
    current = [
        reading
        for reading in view.personal_readings
        if reading.kind is not PersonalTermKind.SEUN_TEN_GOD
        and reading.judgment.params.get("current") is True
    ]
    assert not current
    assert not [
        reading
        for reading in _readings_of(view, PersonalTermKind.SEUN_TEN_GOD)
        if reading.judgment.params["current"]
    ]


def test_multiple_shinsal_at_one_position_are_distinct(spring_birth: BirthInput) -> None:
    view = compose_chart(spring_birth, date(2026, 10, 10))
    year_branch_kinds = {
        reading.shinsal
        for reading in _readings_of(view, PersonalTermKind.SHINSAL)
        if reading.position is Position.YEAR_BRANCH
    }
    assert {Shinsal.CHEONEUL_GWIIN, Shinsal.HWAGAE} <= year_branch_kinds
    pairs = [(reading.position, reading.shinsal) for reading in _readings_of(view, PersonalTermKind.SHINSAL)]
    assert len(pairs) == len(set(pairs))


DAEUN_KINDS = (
    PersonalTermKind.DAEUN_STEM_TEN_GOD,
    PersonalTermKind.DAEUN_BRANCH_TEN_GOD,
    PersonalTermKind.DAEUN_TWELVE_STAGE,
)


def _current_daeun_indexes(view: ChartView) -> set[int]:
    return {
        reading.index
        for kind in DAEUN_KINDS
        for reading in _readings_of(view, kind)
        if reading.judgment.params["current"]
    }


def test_current_boundary_switches_at_next_start_year(spring_birth: BirthInput) -> None:
    periods = compose_chart(spring_birth, date(2026, 10, 10)).luck.periods
    boundary_year = periods[1].start_year
    on_boundary = compose_chart(spring_birth, date(boundary_year, 6, 1))
    before_boundary = compose_chart(spring_birth, date(boundary_year - 1, 6, 1))
    assert _current_daeun_indexes(on_boundary) == {1}
    assert _current_daeun_indexes(before_boundary) == {0}


def test_last_period_is_current_only_for_ten_years(spring_birth: BirthInput) -> None:
    periods = compose_chart(spring_birth, date(2026, 10, 10)).luck.periods
    last_start = periods[-1].start_year
    assert _current_daeun_indexes(compose_chart(spring_birth, date(last_start, 6, 1))) == {len(periods) - 1}
    assert _current_daeun_indexes(compose_chart(spring_birth, date(last_start + 10, 6, 1))) == set()


def test_personal_readings_kind_order(spring_birth: BirthInput) -> None:
    view = compose_chart(spring_birth, date(2026, 10, 10))
    kinds = [reading.kind for reading in view.personal_readings]
    periods = len(view.luck.periods)
    expected = (
        [PersonalTermKind.DAY_MASTER]
        + [PersonalTermKind.TEN_GOD] * len(_readings_of(view, PersonalTermKind.TEN_GOD))
        + [PersonalTermKind.HIDDEN_TEN_GOD] * len(_readings_of(view, PersonalTermKind.HIDDEN_TEN_GOD))
        + [PersonalTermKind.TWELVE_STAGE] * len(_readings_of(view, PersonalTermKind.TWELVE_STAGE))
        + [PersonalTermKind.SHINSAL] * len(_readings_of(view, PersonalTermKind.SHINSAL))
        + list(DAEUN_KINDS) * periods
        + [PersonalTermKind.SEUN_TEN_GOD] * len(view.luck.years)
    )
    assert kinds == expected
