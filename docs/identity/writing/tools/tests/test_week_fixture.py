"""한 주 고정 자료 생성 테스트. 엔진 없이 손으로 만든 응답만 씁니다."""

from datetime import date

from mlw._gen.myungri.engine.v1 import engine_pb2
from mlw.bundles import DayKeys
from mlw.week_fixture import DAYS, SAMPLE_BIRTHS, START_DATE, day_keys_from_response


def make_response(fortune_keys: list[str], featured_tags: list[str]) -> engine_pb2.DailyResponse:
    return engine_pb2.DailyResponse(
        fortune=[engine_pb2.Judgment(message_key=key) for key in fortune_keys],
        guide=engine_pb2.Judgment(message_key="guide.dohwa"),
        color=engine_pb2.ColorCard(judgment=engine_pb2.Judgment(message_key="color.gwiin_day")),
        direction=engine_pb2.DirectionCard(
            judgment=engine_pb2.Judgment(message_key="direction.day_kind.gwiin")
        ),
        number=engine_pb2.NumberCard(judgment=engine_pb2.Judgment(message_key="number.gwiin_day")),
        focus_time=engine_pb2.FocusTimeCard(judgment=engine_pb2.Judgment(message_key="focus_time.gwiin")),
        featured_tags=featured_tags,
    )


def test_day_keys_from_response() -> None:
    response = make_response(["fortune.gwiin_day.siksang", "fortune.tag.dohwa"], ["tag.dohwa"])
    assert day_keys_from_response(response) == DayKeys(
        head="fortune.gwiin_day.siksang",
        tag_sentence="fortune.tag.dohwa",
        guide="guide.dohwa",
        color="color.gwiin_day",
        direction="direction.day_kind.gwiin",
        number="number.gwiin_day",
        focus="focus_time.gwiin",
        tag_label="tag.dohwa",
    )


def test_day_keys_without_tag() -> None:
    keys = day_keys_from_response(make_response(["fortune.ordinary_day.siksang"], []))
    assert keys.tag_sentence is None
    assert keys.tag_label is None


def test_sample_births_are_fixed() -> None:
    assert len(SAMPLE_BIRTHS) == 10
    assert len({sample.birth_id for sample in SAMPLE_BIRTHS}) == 10
    assert sum(sample.gender == "male" for sample in SAMPLE_BIRTHS) == 5
    assert sum(sample.hour is None for sample in SAMPLE_BIRTHS) == 1
    assert all(1970 <= sample.year <= 2005 for sample in SAMPLE_BIRTHS)
    assert START_DATE == date(2026, 11, 2)
    assert DAYS == 28
