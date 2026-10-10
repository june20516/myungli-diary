from datetime import date

import pytest

from myungri_engine.calendar_core import lunar_adapter
from myungri_engine.calendar_core.birth import BirthInput
from myungri_engine.composers.chart import compose_chart
from myungri_engine.composers.daily import DailyView, compose_daily
from myungri_engine.composers.month import compose_month
from myungri_engine.constants.message_keys import ALL_KEYS
from myungri_engine.domain.enums import NoticeCode
from myungri_engine.domain.errors import InvalidInputError, OutOfRangeError
from myungri_engine.domain.models import Judgment
from myungri_engine.references import loader
from myungri_engine.rules import focus_time

TARGET = date(2026, 10, 10)
SEOUL = "Asia/Seoul"


def _daily_judgments(view: DailyView) -> list[Judgment]:
    return [
        view.color[1],
        view.direction[1],
        view.number[1],
        view.focus[1],
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
        loader.validate_refs(evidence.source_ref for evidence in judgment.evidence)


def test_daily_not_determined_by_day_alone(spring_birth: BirthInput, winter_birth: BirthInput) -> None:
    first = compose_daily(spring_birth, TARGET, SEOUL)
    second = compose_daily(winter_birth, TARGET, SEOUL)
    assert first.day == second.day
    assert (first.kind, first.color[0].element, first.direction[0].direction, first.tags.all_keys) != (
        second.kind,
        second.color[0].element,
        second.direction[0].direction,
        second.tags.all_keys,
    )


def test_daily_cards_follow_day_kind(spring_birth: BirthInput) -> None:
    view = compose_daily(spring_birth, TARGET, SEOUL)
    kind = view.kind.name.lower()
    assert view.day == lunar_adapter.day_pillar(TARGET)
    assert view.color[1].message_key == f"color.{kind}"
    assert view.direction[1].message_key == f"direction.day_kind.{kind.removesuffix('_day')}"
    assert view.number[1].message_key == f"number.{kind}"
    assert view.number[1].params["element"] == view.color[0].element.name
    assert view.number[1].params["number"] == view.number[0]


def test_daily_focus_key_is_top_reason_or_fallback(spring_birth: BirthInput) -> None:
    view = compose_daily(spring_birth, TARGET, SEOUL)
    result, judgment = view.focus
    top_reasons = result.picks[0].reasons
    expected = "fallback" if result.fallback or not top_reasons else top_reasons[0]
    assert judgment.message_key == f"focus_time.{expected}"
    assert judgment.evidence == result.evidence


def test_daily_focus_fallback_adds_notice(spring_birth: BirthInput, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(focus_time, "_clashes_with_natal", lambda slot, natal: True)
    view = compose_daily(spring_birth, TARGET, SEOUL)
    assert view.focus[0].fallback
    assert view.focus[1].message_key == "focus_time.fallback"
    assert NoticeCode.FOCUS_TIME_FALLBACK in {notice.code for notice in view.notices}


def test_daily_inherits_chart_notices(zi_hour_birth: BirthInput) -> None:
    view = compose_daily(zi_hour_birth, TARGET, SEOUL)
    assert NoticeCode.ZI_HOUR_NEXT_DAY in {notice.code for notice in view.notices}


def test_daily_target_out_of_range(spring_birth: BirthInput) -> None:
    with pytest.raises(OutOfRangeError):
        compose_daily(spring_birth, date(2100, 1, 1), SEOUL)


def test_daily_invalid_timezone(spring_birth: BirthInput) -> None:
    with pytest.raises(InvalidInputError):
        compose_daily(spring_birth, TARGET, "Mars/Olympus")
