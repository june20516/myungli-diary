"""불변 조건 (spec 13.4): 임의 입력에서도 지켜져야 하는 성질."""

from datetime import date, time, timedelta

from hypothesis import given, settings
from hypothesis import strategies as st

from myungri_engine.calendar_core import lunar_adapter
from myungri_engine.calendar_core.birth import BirthInput
from myungri_engine.composers.daily import DailyView, compose_daily
from myungri_engine.constants.message_keys import ALL_KEYS
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
@given(birth=birth_inputs, target=daily_dates)
def test_focus_slots_within_candidates(birth: BirthInput, target: date) -> None:
    focus = compose_daily(birth, target, SEOUL).focus[0]
    assert focus.picks
    assert {pick.slot.branch for pick in focus.picks} <= FOCUS_CANDIDATES
