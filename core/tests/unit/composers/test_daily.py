from datetime import date

import pytest

from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.calendar_core.birth import BirthInput
from myungli_engine.composers.chart import compose_chart
from myungli_engine.composers.daily import DailyView, compose_daily
from myungli_engine.composers.month import compose_month
from myungli_engine.constants.message_keys import ALL_KEYS
from myungli_engine.constants.numbers import HADO
from myungli_engine.domain.elements import relation_to
from myungli_engine.domain.enums import NoticeCode
from myungli_engine.domain.errors import InvalidInputError, OutOfRangeError
from myungli_engine.domain.models import Judgment
from myungli_engine.references import loader
from myungli_engine.references.loader import FOCUS_TIME_REF
from myungli_engine.rules.focus_time import FocusPeriod

TARGET = date(2026, 10, 10)
SEOUL = "Asia/Seoul"


def _daily_judgments(view: DailyView) -> list[Judgment]:
    return [
        *(judgment for _, judgment in view.colors),
        view.direction[1],
        view.number[1],
        *(judgment for _, judgment in view.focus),
        *view.fortune,
        view.guide,
    ]


def test_every_judgment_has_resolvable_evidence(
    spring_birth: BirthInput, winter_birth: BirthInput, unknown_time_birth: BirthInput
) -> None:
    judgments: list[Judgment] = []
    for birth in (spring_birth, winter_birth, unknown_time_birth):
        judgments.append(compose_chart(birth, TARGET).yongsin_judgment)
        for offset in range(7):
            judgments.extend(_daily_judgments(compose_daily(birth, date(2026, 10, 10 + offset), SEOUL)))
        judgments.extend(day.judgment for day in compose_month(birth, 2026, 10, SEOUL).days)

    for judgment in judgments:
        assert judgment.message_key in ALL_KEYS
        assert judgment.evidence, judgment.message_key
        loader.validate_evidence_refs(judgment.evidence)


def test_daily_not_determined_by_day_alone(spring_birth: BirthInput, winter_birth: BirthInput) -> None:
    first = compose_daily(spring_birth, TARGET, SEOUL)
    second = compose_daily(winter_birth, TARGET, SEOUL)
    assert first.day == second.day
    assert (first.kind, first.colors[0][0].element, first.direction[0].direction, first.tags.all_keys) != (
        second.kind,
        second.colors[0][0].element,
        second.direction[0].direction,
        second.tags.all_keys,
    )


def test_daily_cards_follow_day_kind(spring_birth: BirthInput) -> None:
    view = compose_daily(spring_birth, TARGET, SEOUL)
    kind = view.kind.name.lower()
    assert view.day == lunar_adapter.day_pillar(TARGET)
    assert [judgment.message_key for _, judgment in view.colors] == [f"color.{kind}"]
    assert view.direction[1].message_key == f"direction.day_kind.{kind.removesuffix('_day')}"
    assert view.number[1].message_key == f"number.{kind}"
    assert view.number[1].params["element"] == view.colors[0][0].element.name
    assert view.number[1].params["number"] == view.number[0]


def test_daily_focus_day_and_night(spring_birth: BirthInput) -> None:
    """낮과 밤 각각 1등 하나, 근거는 用時法, 論相主, 黃道黑道 조목(D122)."""
    view = compose_daily(spring_birth, TARGET, SEOUL)
    assert [pick.period for pick, _ in view.focus] == [FocusPeriod.DAY, FocusPeriod.NIGHT]
    for pick, judgment in view.focus:
        assert judgment.message_key == f"focus_time.{pick.period.name.lower()}"
        assert judgment.params == {"hour_branch": pick.grade.slot.branch.name}
        assert [e.source_ref for e in judgment.evidence] == [
            FOCUS_TIME_REF["use_hour"],
            FOCUS_TIME_REF["birth_year"],
            FOCUS_TIME_REF["huangdao"],
        ]
    assert NoticeCode.FOCUS_TIME_FALLBACK not in {notice.code for notice in view.notices}


def test_daily_inherits_chart_notices(zi_hour_birth: BirthInput) -> None:
    view = compose_daily(zi_hour_birth, TARGET, SEOUL)
    assert NoticeCode.ZI_HOUR_NEXT_DAY in {notice.code for notice in view.notices}


def test_daily_target_out_of_range(spring_birth: BirthInput) -> None:
    with pytest.raises(OutOfRangeError):
        compose_daily(spring_birth, date(2100, 1, 1), SEOUL)


def test_daily_invalid_timezone(spring_birth: BirthInput) -> None:
    with pytest.raises(InvalidInputError):
        compose_daily(spring_birth, TARGET, "Mars/Olympus")


def _first_split_day(birth: BirthInput) -> DailyView:
    """원전 기준 색이 기신이라 색 카드가 둘인 첫 날(2026-10-10부터 60일 안)."""
    for offset in range(60):
        view = compose_daily(birth, date.fromordinal(TARGET.toordinal() + offset), SEOUL)
        if len(view.colors) == 2:
            return view
    raise AssertionError("60일 안에 색 카드가 둘인 날이 없습니다")


def test_daily_split_colors_have_own_keys_and_number_follows_first(spring_birth: BirthInput) -> None:
    view = _first_split_day(spring_birth)
    kind = view.kind.name.lower()
    (balance, balance_judgment), (source, source_judgment) = view.colors
    assert balance_judgment.message_key == f"color.balance.{kind}"
    assert source_judgment.message_key == f"color.source.{kind}"
    assert balance.element is balance.base_element is not source.element
    assert balance_judgment.evidence != source_judgment.evidence
    assert view.number[1].params["element"] == balance.element.name


def test_daily_number_params(spring_birth: BirthInput) -> None:
    view = compose_daily(spring_birth, TARGET, SEOUL)
    params = view.number[1].params
    assert params["day_stem"] == view.day.stem.name
    assert params["parity"] == ("ODD" if view.day.stem.is_yang else "EVEN")
    assert {params["number"], params["pair"]} == set(HADO[view.colors[0][0].element])


def test_lucky_params_carry_base_element_and_relation(spring_birth: BirthInput) -> None:
    """D130: 색, 방위, 숫자는 바탕 오행과 결과 오행(element)의 관계를 매개변수로 낸다(#1131)."""
    seen: set[str] = set()
    for offset in range(60):
        view = compose_daily(spring_birth, date.fromordinal(TARGET.toordinal() + offset), SEOUL)
        first_color, first_judgment = view.colors[0]
        base = first_color.base_element
        for pick, judgment in view.colors:
            assert judgment.params["base_element"] == base.name
            assert judgment.params["relation"] == relation_to(base, pick.element).name
        number = view.number[1].params
        assert number["base_element"] == base.name
        assert number["relation"] == first_judgment.params["relation"]
        direction_pick, direction = view.direction
        if direction_pick.element is None:
            assert "base_element" not in direction.params and "relation" not in direction.params
            continue
        assert direction.params["base_element"] == base.name
        assert direction.params["relation"] == relation_to(base, direction_pick.element).name
        seen.add(str(direction.params["relation"]))
    assert "SAME" in seen
