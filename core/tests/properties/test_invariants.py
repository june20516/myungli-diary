"""불변 조건 (spec 13.4): 임의 입력에서도 지켜져야 하는 성질."""

import itertools
from datetime import date, time, timedelta

from hypothesis import given, settings
from hypothesis import strategies as st

from myungri_engine.calendar_core import lunar_adapter
from myungri_engine.calendar_core.birth import BirthInput, birth_hour, resolve_birth_moment
from myungri_engine.chart.pillars import build_chart
from myungri_engine.composers.chart import compose_chart
from myungri_engine.composers.daily import DailyView, compose_daily
from myungri_engine.constants.message_keys import ALL_KEYS, require
from myungri_engine.domain.enums import Branch, CalendarType, Gender
from myungri_engine.domain.models import Judgment, Pillar
from myungri_engine.references import loader

SEOUL = "Asia/Seoul"
PROPERTY_SETTINGS = settings(max_examples=300, deadline=None, derandomize=True)
CYCLE_LENGTH = 60
# 진시~술시 (spec 7.5). 구현 상수를 재사용하지 않고 독립적으로 적는다.
FOCUS_CANDIDATES = frozenset({Branch.JIN, Branch.SA, Branch.O, Branch.MI, Branch.SHIN, Branch.YU, Branch.SUL})

birth_dates = st.dates(min_value=date(1900, 2, 1), max_value=date(2099, 12, 31))
daily_dates = st.dates(min_value=date(1950, 1, 1), max_value=date(2090, 12, 31))
birth_times = st.one_of(st.none(), st.times().map(lambda t: time(t.hour, t.minute)))
birth_inputs = st.builds(
    BirthInput,
    calendar=st.just(CalendarType.SOLAR),
    is_leap_month=st.just(False),
    date=birth_dates,
    time=birth_times,
    gender=st.sampled_from(Gender),
    timezone=st.sampled_from([SEOUL, SEOUL, SEOUL, "America/New_York"]),
    longitude=st.none(),
)


@PROPERTY_SETTINGS
@given(birth=birth_inputs.filter(lambda b: b.time is not None))
def test_birth_hour_branch_matches_chart_hour_pillar(birth: BirthInput) -> None:
    assert birth_hour(birth).branch == build_chart(resolve_birth_moment(birth)).pillars.hour.branch


def _cycle_index(pillar: Pillar) -> int:
    """60갑자 인덱스: 천간 순번(mod 10)과 지지 순번(mod 12)이 모두 맞는 0~59."""
    matches = [
        n for n in range(CYCLE_LENGTH) if n % 10 == pillar.stem.index and n % 12 == pillar.branch.index
    ]
    assert len(matches) == 1, pillar  # 음양이 맞지 않는 조합이면 60갑자에 없다
    return matches[0]


def _judgments(view: DailyView) -> list[Judgment]:
    return [view.color[1], view.direction[1], view.number[1], view.focus[1], *view.fortune, view.guide]


@PROPERTY_SETTINGS
@given(d=daily_dates)
def test_day_pillar_advances_one_step(d: date) -> None:
    today = _cycle_index(lunar_adapter.day_pillar(d))
    tomorrow = _cycle_index(lunar_adapter.day_pillar(d + timedelta(days=1)))
    assert tomorrow == (today + 1) % CYCLE_LENGTH


@PROPERTY_SETTINGS
@given(birth=birth_inputs, target=daily_dates)
def test_deterministic(birth: BirthInput, target: date) -> None:
    assert compose_daily(birth, target, SEOUL) == compose_daily(birth, target, SEOUL)


@PROPERTY_SETTINGS
@given(birth=birth_inputs, target=daily_dates)
def test_all_judgments_have_evidence(birth: BirthInput, target: date) -> None:
    for judgment in _judgments(compose_daily(birth, target, SEOUL)):
        assert judgment.message_key in ALL_KEYS
        assert judgment.evidence, judgment.message_key
        loader.validate_refs(evidence.source_ref for evidence in judgment.evidence)


@PROPERTY_SETTINGS
@given(birth=birth_inputs, as_of=daily_dates)
def test_all_personal_readings_have_evidence(birth: BirthInput, as_of: date) -> None:
    readings = compose_chart(birth, as_of).personal_readings
    for reading in readings:
        judgment = reading.judgment
        assert judgment.message_key in ALL_KEYS
        require(judgment.message_key, judgment.params)  # 매개변수 이름까지 선언과 같아야 한다
        assert judgment.evidence, judgment.message_key
        loader.validate_refs(evidence.source_ref for evidence in judgment.evidence)
    identities = [(r.kind, r.position, r.index, r.shinsal) for r in readings]
    assert len(identities) == len(set(identities))


def _evidence_fingerprint(view: DailyView) -> tuple[object, ...]:
    """판정 결과와 근거(detail 포함)를 비교 가능한 값으로 만든다."""
    evidence = tuple(
        (e.rule_id, e.source_ref, tuple(sorted(e.detail.items())))
        for judgment in _judgments(view)
        for e in judgment.evidence
    )
    return (view.kind, view.color[0].element, view.direction[0].direction, view.tags.all_keys, evidence)


def _solar(d: date, t: time | None, gender: Gender) -> BirthInput:
    return BirthInput(CalendarType.SOLAR, False, d, t, gender, SEOUL, None)


# 연·월·일주가 모두 다른 원국들. 같은 날의 결과가 일진만으로 정해지는지 본다.
DISTINCT_NATALS = (
    _solar(date(1985, 3, 10), time(14, 30), Gender.MALE),
    _solar(date(1992, 11, 22), time(8, 0), Gender.FEMALE),
    _solar(date(1978, 8, 3), None, Gender.FEMALE),
    _solar(date(2001, 9, 9), time(21, 15), Gender.MALE),
    _solar(date(1969, 12, 25), time(6, 45), Gender.FEMALE),
)
NATAL_PAIRS = list(itertools.combinations(DISTINCT_NATALS, 2))


@PROPERTY_SETTINGS
@given(pair=st.sampled_from(NATAL_PAIRS), target=daily_dates)
def test_daily_not_determined_by_day_alone(pair: tuple[BirthInput, BirthInput], target: date) -> None:
    """같은 날 서로 다른 원국 두 개의 결과는 판정 근거 수준에서 구분된다 (spec 13.4)."""
    first, second = pair
    assert _evidence_fingerprint(compose_daily(first, target, SEOUL)) != _evidence_fingerprint(
        compose_daily(second, target, SEOUL)
    )


@PROPERTY_SETTINGS
@given(birth=birth_inputs, target=daily_dates)
def test_focus_slots_within_candidates(birth: BirthInput, target: date) -> None:
    focus = compose_daily(birth, target, SEOUL).focus[0]
    assert focus.picks
    assert {pick.slot.branch for pick in focus.picks} <= FOCUS_CANDIDATES
