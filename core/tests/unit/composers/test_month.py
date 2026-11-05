import pytest

from myungli_engine.calendar_core.birth import BirthInput, BirthMoment
from myungli_engine.chart import pillars
from myungli_engine.composers import chart as chart_composer
from myungli_engine.composers.month import _luck_judgment, compose_month
from myungli_engine.domain.enums import LuckLevel, NoticeCode
from myungli_engine.domain.errors import InvalidInputError, OutOfRangeError
from myungli_engine.grpc_api import mapping
from myungli_engine.rules.calendar_luck import LuckScore

SEOUL = "Asia/Seoul"


def test_month_has_all_days(spring_birth: BirthInput) -> None:
    assert len(compose_month(spring_birth, 2026, 2, SEOUL).days) == 28
    assert len(compose_month(spring_birth, 2028, 2, SEOUL).days) == 29


def test_month_day_judgment_matches_luck(spring_birth: BirthInput) -> None:
    for day in compose_month(spring_birth, 2026, 10, SEOUL).days:
        assert day.judgment.message_key == f"calendar.{day.luck.level.name.lower()}"
        assert day.judgment.params["score"] == day.luck.score
        assert day.judgment.evidence[0].rule_id == "calendar/score"
        expected_detail = ",".join(f"{name}:{points:+d}" for name, points in day.luck.breakdown)
        assert day.judgment.evidence[0].detail["breakdown"] == expected_detail


def test_month_featured_tag_is_first_featured_or_none(spring_birth: BirthInput) -> None:
    days = compose_month(spring_birth, 2026, 10, SEOUL).days
    assert any(day.featured_tag is not None for day in days)
    for day in days:
        assert day.featured_tag is None or day.featured_tag.startswith("tag.")


def test_month_computes_chart_once(spring_birth: BirthInput, monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[BirthMoment] = []
    original = pillars.build_chart

    def counting_build_chart(moment: BirthMoment) -> pillars.Chart:
        calls.append(moment)
        return original(moment)

    monkeypatch.setattr(chart_composer, "build_chart", counting_build_chart)
    compose_month(spring_birth, 2026, 10, SEOUL)
    assert len(calls) == 1


def test_month_inherits_chart_notices(zi_hour_birth: BirthInput) -> None:
    view = compose_month(zi_hour_birth, 2026, 10, SEOUL)
    assert NoticeCode.ZI_HOUR_NEXT_DAY in {notice.code for notice in view.notices}


def test_month_out_of_range(spring_birth: BirthInput) -> None:
    with pytest.raises(OutOfRangeError):
        compose_month(spring_birth, 2100, 1, SEOUL)
    with pytest.raises(OutOfRangeError):
        compose_month(spring_birth, 1900, 1, SEOUL)


def test_month_invalid_inputs(spring_birth: BirthInput) -> None:
    with pytest.raises(InvalidInputError):
        compose_month(spring_birth, 2026, 13, SEOUL)
    with pytest.raises(InvalidInputError):
        compose_month(spring_birth, 2026, 10, "Mars/Olympus")


def test_very_good_day_uses_calendar_very_good_key() -> None:
    judgment = _luck_judgment(LuckScore(3, LuckLevel.VERY_GOOD, (("gwiin_day", 2), ("hap", 1))))
    assert judgment.message_key == "calendar.very_good"
    assert mapping.pb.LuckLevel.Value(mapping._name(mapping._PREFIX_LUCK_LEVEL, LuckLevel.VERY_GOOD)) == 4
