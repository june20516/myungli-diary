# in-process gRPC 서버와 실제 채널(임의 포트)로 엔진 진입점을 검사한다 (spec 9, 11, 12)
from collections.abc import Iterator
from datetime import datetime

import grpc
import pytest

from myungli_engine._gen.myungli.engine.v1 import engine_pb2 as pb
from myungli_engine._gen.myungli.engine.v1 import engine_pb2_grpc as pb_grpc
from myungli_engine.grpc_api import server as server_module
from myungli_engine.grpc_api.errors import INTERNAL_MESSAGE
from myungli_engine.version import ENGINE_VERSION, RULESET_VERSION

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
def stub() -> Iterator[pb_grpc.MyungliEngineStub]:
    running = server_module.start(0)
    channel = grpc.insecure_channel(f"localhost:{running.port}")
    try:
        yield pb_grpc.MyungliEngineStub(channel)
    finally:
        channel.close()
        running.stop(grace=None)


def status_of(call: grpc.RpcError) -> grpc.StatusCode:
    code: grpc.StatusCode = call.code()  # type: ignore[attr-defined]
    return code


# --- brief 필수 7개 ---


def test_get_chart_roundtrip(stub: pb_grpc.MyungliEngineStub) -> None:
    response = stub.GetChart(pb.ChartRequest(birth=solar_birth(1985, 3, 10), as_of=AS_OF))

    assert response.meta.ruleset_version == RULESET_VERSION == "2026.10.2"
    assert response.meta.engine_version == ENGINE_VERSION
    assert response.pillars.HasField("hour")
    assert response.pillars.hour.stem != pb.STEM_UNSPECIFIED
    assert len(response.daeun.periods) == 10
    assert len(response.seun) == 10
    assert response.yongsin.judgment.message_key.startswith("yongsin.method.")
    assert len(response.yongsin.judgment.evidence) >= 1
    assert len(response.gongmang) == 2


def test_daeun_start_year_matches_korean_age_and_solar_birth_year(stub: pb_grpc.MyungliEngineStub) -> None:
    # 음력 1984-12-20은 양력 1985년이다. 출생 양력 연도는 음력 연도가 아니라 변환한 양력 연도다(#378).
    lunar_date = pb.LocalDate(year=1984, month=12, day=20)
    solar = stub.ConvertLunarDate(pb.LunarDateRequest(date=lunar_date)).solar
    assert solar.year == 1985
    lunar_birth = pb.BirthInfo(
        calendar=pb.CALENDAR_TYPE_LUNAR, date=lunar_date, gender=pb.GENDER_FEMALE, timezone=SEOUL
    )
    births_with_solar_year = [(solar_birth(1990, 3, 10), 1990), (lunar_birth, solar.year)]

    for birth, birth_solar_year in births_with_solar_year:
        periods = stub.GetChart(pb.ChartRequest(birth=birth, as_of=AS_OF)).daeun.periods
        assert periods[0].start_year >= birth_solar_year
        assert [p.start_year - periods[0].start_year for p in periods] == list(range(0, 100, 10))
        assert all(p.start_age_korean == p.start_year - birth_solar_year + 1 for p in periods)


def test_chart_personal_readings(stub: pb_grpc.MyungliEngineStub) -> None:
    response = stub.GetChart(pb.ChartRequest(birth=solar_birth(1985, 3, 10), as_of=AS_OF))

    readings = response.personal_readings
    first = readings[0]
    assert first.kind == pb.PERSONAL_TERM_KIND_DAY_MASTER
    assert first.position == pb.POSITION_DAY_STEM
    assert first.judgment.message_key.startswith("personal.day_master.")
    assert len(first.judgment.evidence) >= 1

    seun = [reading for reading in readings if reading.kind == pb.PERSONAL_TERM_KIND_SEUN_TEN_GOD]
    assert len(seun) == len(response.seun)
    assert all(reading.position == pb.POSITION_UNSPECIFIED for reading in seun)

    shinsal = [reading for reading in readings if reading.kind == pb.PERSONAL_TERM_KIND_SHINSAL]
    assert shinsal
    assert all(reading.shinsal != pb.SHINSAL_UNSPECIFIED for reading in shinsal)
    assert all(
        reading.shinsal == pb.SHINSAL_UNSPECIFIED
        for reading in readings
        if reading.kind != pb.PERSONAL_TERM_KIND_SHINSAL
    )

    daeun_stem = [reading for reading in readings if reading.kind == pb.PERSONAL_TERM_KIND_DAEUN_STEM_TEN_GOD]
    assert [reading.index for reading in daeun_stem] == list(range(10))
    hidden = [reading for reading in readings if reading.kind == pb.PERSONAL_TERM_KIND_HIDDEN_TEN_GOD]
    assert hidden[0].index == 0


def test_get_daily_has_four_cards_and_tags(stub: pb_grpc.MyungliEngineStub) -> None:
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


def test_get_month_calendar_day_count(stub: pb_grpc.MyungliEngineStub) -> None:
    response = stub.GetMonthCalendar(
        pb.MonthRequest(birth=solar_birth(1985, 3, 10), year=2026, month=2, current_timezone=SEOUL)
    )

    assert [day.date.day for day in response.days] == list(range(1, 29))
    assert all(day.luck_level != pb.LUCK_LEVEL_UNSPECIFIED for day in response.days)
    assert all(day.judgment.message_key.startswith("calendar.") for day in response.days)
    assert sum(day.HasField("solar_term") for day in response.days) >= 1
    # 2026-02: 입춘(2/4), 우수(2/19)
    terms = [(day.date.day, day.solar_term.kind) for day in response.days if day.HasField("solar_term")]
    assert terms == [(4, pb.SOLAR_TERM_KIND_IPCHUN), (19, pb.SOLAR_TERM_KIND_USU)]


def test_invalid_solar_date_is_invalid_argument(stub: pb_grpc.MyungliEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=solar_birth(2023, 2, 29), as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_out_of_range_is_out_of_range(stub: pb_grpc.MyungliEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=solar_birth(1899, 6, 1), as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.OUT_OF_RANGE


@pytest.mark.parametrize("rpc", ["GetChart", "GetDaily", "GetMonthCalendar"])
def test_unspecified_gender_rejected(stub: pb_grpc.MyungliEngineStub, rpc: str) -> None:
    birth = solar_birth(1985, 3, 10, gender=pb.GENDER_UNSPECIFIED)
    requests = {
        "GetChart": pb.ChartRequest(birth=birth, as_of=AS_OF),
        "GetDaily": pb.DailyRequest(birth=birth, date=AS_OF, current_timezone=SEOUL),
        "GetMonthCalendar": pb.MonthRequest(birth=birth, year=2026, month=10, current_timezone=SEOUL),
    }
    with pytest.raises(grpc.RpcError) as caught:
        getattr(stub, rpc)(requests[rpc])
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT
    assert "GENDER_UNSPECIFIED" in details_of(caught.value)


def test_notices_mapped(stub: pb_grpc.MyungliEngineStub) -> None:
    # 서울 00:10 출생 -> 보정 시각 23:40, 자시
    response = stub.GetChart(pb.ChartRequest(birth=solar_birth(1990, 5, 15, 0, 10), as_of=AS_OF))
    assert pb.NOTICE_CODE_ZI_HOUR_NEXT_DAY in [notice.code for notice in response.meta.notices]


# --- 음력 30일 입력 ---


def test_lunar_thirtieth_day_accepted(stub: pb_grpc.MyungliEngineStub) -> None:
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


def test_time_unknown_has_no_hour_pillar(stub: pb_grpc.MyungliEngineStub) -> None:
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
def test_invalid_birth_is_invalid_argument(stub: pb_grpc.MyungliEngineStub, birth: pb.BirthInfo) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=birth, as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_unknown_enum_number_is_invalid_argument(stub: pb_grpc.MyungliEngineStub) -> None:
    birth = solar_birth(1985, 3, 10)
    birth.calendar = 99  # type: ignore[assignment]
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=birth, as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_missing_birth_is_invalid_argument(stub: pb_grpc.MyungliEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(as_of=AS_OF))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def details_of(call: grpc.RpcError) -> str:
    details: str = call.details()  # type: ignore[attr-defined]
    return details


def test_missing_required_fields_are_invalid_argument_with_field_name(stub: pb_grpc.MyungliEngineStub) -> None:
    birth = solar_birth(1985, 3, 10)
    calls = [
        ("as_of", lambda: stub.GetChart(pb.ChartRequest(birth=birth))),
        ("date", lambda: stub.GetDaily(pb.DailyRequest(birth=birth, current_timezone=SEOUL))),
        ("year", lambda: stub.GetMonthCalendar(pb.MonthRequest(birth=birth, month=10, current_timezone=SEOUL))),
        ("month", lambda: stub.GetMonthCalendar(pb.MonthRequest(birth=birth, year=2026, current_timezone=SEOUL))),
    ]
    for field_name, call in calls:
        with pytest.raises(grpc.RpcError) as caught:
            call()
        assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT, field_name
        assert details_of(caught.value) == f"{field_name}가 없습니다."


def test_daily_request_fields_validated(stub: pb_grpc.MyungliEngineStub) -> None:
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


def test_month_request_fields_validated(stub: pb_grpc.MyungliEngineStub) -> None:
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
    stub: pb_grpc.MyungliEngineStub, monkeypatch: pytest.MonkeyPatch
) -> None:
    def explode(*_args: object) -> object:
        raise RuntimeError("/secret/path/engine.py line 42")

    monkeypatch.setattr(server_module, "compose_chart", explode)
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetChart(pb.ChartRequest(birth=solar_birth(1985, 3, 10), as_of=AS_OF))

    assert status_of(caught.value) == grpc.StatusCode.INTERNAL
    assert caught.value.details() == INTERNAL_MESSAGE  # type: ignore[attr-defined]
    assert "secret" not in INTERNAL_MESSAGE


def test_start_validates_refs_then_warms_up_caches(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[str] = []
    monkeypatch.setattr(server_module.loader, "validate_refs", lambda _refs: calls.append("validate_refs"))
    monkeypatch.setattr(server_module.lunar_adapter, "warm_up", lambda: calls.append("warm_up"))
    running = server_module.start(0)
    running.stop(grace=None)
    assert calls == ["validate_refs", "warm_up"]


def test_start_refuses_when_reference_data_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    def fail(_refs: object) -> None:
        raise KeyError("source_ref를 찾을 수 없습니다")

    monkeypatch.setattr(server_module.loader, "validate_refs", fail)
    with pytest.raises(KeyError):
        server_module.start(0)


def test_get_birth_hour(stub: pb_grpc.MyungliEngineStub) -> None:
    response = stub.GetBirthHour(pb.BirthHourRequest(birth=solar_birth(1990, 5, 5, 4, 0)))
    assert response.branch == pb.BRANCH_IN
    assert response.start.ToDatetime() == datetime(1990, 5, 4, 18, 30)  # KST 03:30
    assert response.end.ToDatetime() == datetime(1990, 5, 4, 20, 30)  # KST 05:30
    assert response.meta.engine_version == ENGINE_VERSION


def test_get_birth_hour_ignores_gender(stub: pb_grpc.MyungliEngineStub) -> None:
    """시진은 출생 시각·시간대·경도로만 정해지므로 성별 미지정도 받는다 (#304)."""
    unspecified = stub.GetBirthHour(
        pb.BirthHourRequest(birth=solar_birth(1990, 5, 15, 0, 10, gender=pb.GENDER_UNSPECIFIED))
    )
    male = stub.GetBirthHour(pb.BirthHourRequest(birth=solar_birth(1990, 5, 15, 0, 10)))
    assert unspecified == male


def test_get_birth_hour_without_time_is_invalid_argument(stub: pb_grpc.MyungliEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetBirthHour(pb.BirthHourRequest(birth=solar_birth(1990, 5, 5, hour=None)))
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT
    assert "birth.time" in details_of(caught.value)


def test_get_birth_hour_out_of_range_date(stub: pb_grpc.MyungliEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.GetBirthHour(pb.BirthHourRequest(birth=solar_birth(1899, 6, 1)))
    assert status_of(caught.value) == grpc.StatusCode.OUT_OF_RANGE


def test_get_info(stub: pb_grpc.MyungliEngineStub) -> None:
    response = stub.GetInfo(pb.InfoRequest())
    assert response.engine_version == ENGINE_VERSION
    assert response.ruleset_version == RULESET_VERSION


def lunar_request(year: int, month: int, day: int, is_leap_month: bool = False) -> pb.LunarDateRequest:
    return pb.LunarDateRequest(
        date=pb.LocalDate(year=year, month=month, day=day), is_leap_month=is_leap_month
    )


def test_convert_lunar_date(stub: pb_grpc.MyungliEngineStub) -> None:
    response = stub.ConvertLunarDate(lunar_request(2012, 3, 11, is_leap_month=True))
    assert response.solar == pb.LocalDate(year=2012, month=5, day=1)
    assert response.month_has_leap is True
    assert response.meta.ruleset_version == RULESET_VERSION


def test_convert_lunar_date_month_without_leap(stub: pb_grpc.MyungliEngineStub) -> None:
    response = stub.ConvertLunarDate(lunar_request(2024, 1, 1))
    assert response.solar == pb.LocalDate(year=2024, month=2, day=10)
    assert response.month_has_leap is False


@pytest.mark.parametrize(
    "request_message",
    [
        lunar_request(2024, 2, 1, is_leap_month=True),  # 2024년에는 윤2월이 없음
        lunar_request(2024, 1, 30),  # 2024년 음력 1월은 29일까지
        lunar_request(2024, 13, 1),
    ],
)
def test_convert_lunar_date_nonexistent_is_invalid_argument(
    stub: pb_grpc.MyungliEngineStub, request_message: pb.LunarDateRequest
) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.ConvertLunarDate(request_message)
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT


def test_convert_lunar_date_without_date_is_invalid_argument(stub: pb_grpc.MyungliEngineStub) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.ConvertLunarDate(pb.LunarDateRequest())
    assert status_of(caught.value) == grpc.StatusCode.INVALID_ARGUMENT
    assert "date" in details_of(caught.value)


@pytest.mark.parametrize("request_message", [lunar_request(1899, 12, 1), lunar_request(2099, 12, 1)])
def test_convert_lunar_date_out_of_range(
    stub: pb_grpc.MyungliEngineStub, request_message: pb.LunarDateRequest
) -> None:
    with pytest.raises(grpc.RpcError) as caught:
        stub.ConvertLunarDate(request_message)
    assert status_of(caught.value) == grpc.StatusCode.OUT_OF_RANGE
