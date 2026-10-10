# in-process gRPC 서버와 실제 채널(임의 포트)로 엔진 진입점을 검사한다 (spec 9, 11, 12)
from collections.abc import Iterator

import grpc
import pytest

from myungri_engine._gen.myungri.engine.v1 import engine_pb2 as pb
from myungri_engine._gen.myungri.engine.v1 import engine_pb2_grpc as pb_grpc
from myungri_engine.grpc_api import server as server_module
from myungri_engine.grpc_api.errors import INTERNAL_MESSAGE
from myungri_engine.version import ENGINE_VERSION, RULESET_VERSION

SEOUL = "Asia/Seoul"
AS_OF = pb.LocalDate(year=2026, month=10, day=10)


def solar_birth(
    year: int,
    month: int,
    day: int,
    hour: int | None = 14,
    minute: int = 30,
    gender: pb.Gender = pb.GENDER_MALE,
) -> pb.BirthInfo:
    birth = pb.BirthInfo(
        calendar=pb.CALENDAR_TYPE_SOLAR,
        date=pb.LocalDate(year=year, month=month, day=day),
        gender=gender,
        timezone=SEOUL,
    )
    if hour is not None:
        birth.time.CopyFrom(pb.LocalTime(hour=hour, minute=minute))
    return birth


@pytest.fixture(scope="module")
def stub() -> Iterator[pb_grpc.MyungriEngineStub]:
    running, port = server_module.start(0)
    channel = grpc.insecure_channel(f"localhost:{port}")
    try:
        yield pb_grpc.MyungriEngineStub(channel)
    finally:
        channel.close()
        running.stop(grace=None)


def status_of(call: grpc.RpcError) -> grpc.StatusCode:
    code: grpc.StatusCode = call.code()  # type: ignore[attr-defined]
    return code


# --- brief 필수 7개 ---


def test_get_chart_roundtrip(stub: pb_grpc.MyungriEngineStub) -> None:
    response = stub.GetChart(pb.ChartRequest(birth=solar_birth(1985, 3, 10), as_of=AS_OF))

    assert response.meta.ruleset_version == RULESET_VERSION == "2026.10.0"
    assert response.meta.engine_version == ENGINE_VERSION
    assert response.pillars.HasField("hour")
    assert response.pillars.hour.stem != pb.STEM_UNSPECIFIED
    assert len(response.daeun.periods) == 10
    assert len(response.seun) == 10
    assert response.yongsin.judgment.message_key.startswith("yongsin.method.")
    assert len(response.yongsin.judgment.evidence) >= 1
    assert len(response.gongmang) == 2


def test_get_daily_has_four_cards_and_tags(stub: pb_grpc.MyungriEngineStub) -> None:
    response = stub.GetDaily(
        pb.DailyRequest(
            birth=solar_birth(1985, 3, 10),
            date=pb.LocalDate(year=2026, month=10, day=10),
            current_timezone=SEOUL,
        )
    )

    for card in (response.color, response.direction, response.number, response.focus_time):
        assert card.judgment.message_key
        assert len(card.judgment.evidence) >= 1
    assert response.color.element != pb.ELEMENT_UNSPECIFIED
    assert response.direction.direction != pb.DIRECTION8_UNSPECIFIED
    assert 1 <= response.number.number <= 10
    assert response.number.judgment.params["number"].integer == response.number.number
    assert 1 <= len(response.focus_time.picks) <= 2
    for pick in response.focus_time.picks:
        assert pick.branch == pick.pillar.branch != pb.BRANCH_UNSPECIFIED
        assert pick.end.ToDatetime() > pick.start.ToDatetime()
    assert response.kind != pb.DAY_KIND_UNSPECIFIED
    assert len(response.all_tags) >= 1
    assert set(response.featured_tags) <= set(response.all_tags)
    assert len(response.fortune) >= 1
    assert response.guide.message_key


def test_get_month_calendar_day_count(stub: pb_grpc.MyungriEngineStub) -> None:
    response = stub.GetMonthCalendar(
        pb.MonthRequest(birth=solar_birth(1985, 3, 10), year=2026, month=2, current_timezone=SEOUL)
    )

    assert [day.date.day for day in response.days] == list(range(1, 29))
    assert all(day.luck_level != pb.LUCK_LEVEL_UNSPECIFIED for day in response.days)
    assert all(day.judgment.message_key.startswith("calendar.") for day in response.days)
    assert sum(day.HasField("solar_term") for day in response.days) >= 1


def test_invalid_solar_date_is_invalid_argument(stub: pb_grpc.MyungriEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=solar_birth(2023, 2, 29), as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_out_of_range_is_out_of_range(stub: pb_grpc.MyungriEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=solar_birth(1899, 6, 1), as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.OUT_OF_RANGE


def test_unspecified_gender_rejected(stub: pb_grpc.MyungriEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(
            pb.ChartRequest(birth=solar_birth(1985, 3, 10, gender=pb.GENDER_UNSPECIFIED), as_of=AS_OF)
        )
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_notices_mapped(stub: pb_grpc.MyungriEngineStub) -> None:
    # 서울 00:10 출생 -> 보정 시각 23:40, 자시
    response = stub.GetChart(pb.ChartRequest(birth=solar_birth(1990, 5, 15, 0, 10), as_of=AS_OF))
    assert pb.NOTICE_CODE_ZI_HOUR_NEXT_DAY in [notice.code for notice in response.meta.notices]


# --- 음력 30일 입력 ---


def test_lunar_thirtieth_day_accepted(stub: pb_grpc.MyungriEngineStub) -> None:
    birth = pb.BirthInfo(
        calendar=pb.CALENDAR_TYPE_LUNAR,
        date=pb.LocalDate(year=2024, month=2, day=30),
        time=pb.LocalTime(hour=9, minute=0),
        gender=pb.GENDER_FEMALE,
        timezone=SEOUL,
    )
    response = stub.GetChart(pb.ChartRequest(birth=birth, as_of=AS_OF))
    assert response.pillars.day.stem != pb.STEM_UNSPECIFIED


# --- 입력 검증과 오류 매핑 ---


def test_time_unknown_has_no_hour_pillar(stub: pb_grpc.MyungriEngineStub) -> None:
    response = stub.GetChart(pb.ChartRequest(birth=solar_birth(1978, 8, 3, hour=None), as_of=AS_OF))
    assert not response.pillars.HasField("hour")
    assert pb.NOTICE_CODE_TIME_UNKNOWN in [notice.code for notice in response.meta.notices]


@pytest.mark.parametrize(
    "birth",
    [
        solar_birth(1985, 3, 10, hour=24, minute=0),
        solar_birth(1985, 3, 10, hour=10, minute=60),
        pb.BirthInfo(
            calendar=pb.CALENDAR_TYPE_UNSPECIFIED,
            date=pb.LocalDate(year=1985, month=3, day=10),
            gender=pb.GENDER_MALE,
            timezone=SEOUL,
        ),
        pb.BirthInfo(
            calendar=pb.CALENDAR_TYPE_SOLAR,
            date=pb.LocalDate(year=1985, month=3, day=10),
            gender=pb.GENDER_MALE,
            timezone="",
        ),
        pb.BirthInfo(
            calendar=pb.CALENDAR_TYPE_SOLAR,
            date=pb.LocalDate(year=1985, month=3, day=10),
            gender=pb.GENDER_MALE,
            timezone=SEOUL,
            longitude=181.0,
        ),
        pb.BirthInfo(
            calendar=pb.CALENDAR_TYPE_SOLAR,
            date=pb.LocalDate(year=1985, month=3, day=10),
            gender=pb.GENDER_MALE,
            timezone=SEOUL,
            longitude=float("nan"),
        ),
        pb.BirthInfo(
            calendar=pb.CALENDAR_TYPE_LUNAR,
            date=pb.LocalDate(year=2023, month=3, day=1),
            is_leap_month=True,
            gender=pb.GENDER_MALE,
            timezone=SEOUL,
        ),
    ],
    ids=["hour-24", "minute-60", "calendar-unspecified", "empty-timezone", "longitude-181", "longitude-nan",
         "missing-leap-month"],
)
def test_invalid_birth_is_invalid_argument(stub: pb_grpc.MyungriEngineStub, birth: pb.BirthInfo) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=birth, as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_unknown_enum_number_is_invalid_argument(stub: pb_grpc.MyungriEngineStub) -> None:
    birth = solar_birth(1985, 3, 10)
    birth.calendar = 99  # type: ignore[assignment]
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=birth, as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_missing_birth_is_invalid_argument(stub: pb_grpc.MyungriEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_daily_request_fields_validated(stub: pb_grpc.MyungriEngineStub) -> None:
    birth = solar_birth(1985, 3, 10)
    bad_requests = [
        pb.DailyRequest(birth=birth, date=pb.LocalDate(year=2026, month=2, day=30), current_timezone=SEOUL),
        pb.DailyRequest(birth=birth, date=pb.LocalDate(year=2026, month=10, day=10), current_timezone=""),
        pb.DailyRequest(birth=birth, date=pb.LocalDate(year=2026, month=10, day=10), current_timezone="Mars/X"),
    ]
    for request in bad_requests:
        with pytest.raises(grpc.RpcError) as caught:
            stub.GetDaily(request)
        assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_month_request_fields_validated(stub: pb_grpc.MyungriEngineStub) -> None:
    birth = solar_birth(1985, 3, 10)
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetMonthCalendar(pb.MonthRequest(birth=birth, year=2026, month=13, current_timezone=SEOUL))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT

    with pytest.raises(grpc.RpcError) as caught:
        stub.GetMonthCalendar(pb.MonthRequest(birth=birth, year=2026, month=10, current_timezone=""))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT

    with pytest.raises(grpc.RpcError) as caught:
        stub.GetMonthCalendar(pb.MonthRequest(birth=birth, year=2100, month=1, current_timezone=SEOUL))
    assert status_of(caught.value) == grpc.StatusCode.OUT_OF_RANGE


def test_unexpected_error_is_internal_without_details(
    stub: pb_grpc.MyungriEngineStub, monkeypatch: pytest.MonkeyPatch
) -> None:
    def explode(*_args: object) -> object:
        raise RuntimeError("/secret/path/engine.py line 42")

    monkeypatch.setattr(server_module, "compose_chart", explode)
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=solar_birth(1985, 3, 10), as_of=AS_OF))

    assert status_of(caught.value) == grpc.StatusCode.INTERNAL
    assert caught.value.details() == INTERNAL_MESSAGE  # type: ignore[attr-defined]
    assert "secret" not in INTERNAL_MESSAGE


def test_start_refuses_when_reference_data_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    def fail(_refs: object) -> None:
        raise KeyError("source_ref를 찾을 수 없습니다")

    monkeypatch.setattr(server_module.loader, "validate_refs", fail)
    with pytest.raises(KeyError):
        server_module.start(0)
