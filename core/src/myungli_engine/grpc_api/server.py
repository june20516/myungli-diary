"""MyungliEngine gRPC 서버 (spec 9, 11)."""

from __future__ import annotations

from concurrent import futures
from dataclasses import dataclass
from typing import Final

import grpc
from grpc_health.v1 import health, health_pb2, health_pb2_grpc

from myungli_engine._gen.myungli.engine.v1 import engine_pb2 as pb
from myungli_engine._gen.myungli.engine.v1 import engine_pb2_grpc as pb_grpc
from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.calendar_core.birth import birth_hour
from myungli_engine.composers.chart import compose_chart
from myungli_engine.composers.daily import compose_daily
from myungli_engine.composers.month import compose_month
from myungli_engine.domain.errors import InvalidInputError
from myungli_engine.grpc_api import mapping
from myungli_engine.grpc_api.errors import run_or_abort
from myungli_engine.references import loader
from myungli_engine.version import ENGINE_VERSION, RULESET_VERSION

DEFAULT_PORT: Final = 50051
MAX_WORKERS: Final = 8
ENGINE_SERVICE_NAME: Final = pb.DESCRIPTOR.services_by_name["MyungliEngine"].full_name


class MyungliEngineServicer(pb_grpc.MyungliEngineServicer):
    def GetChart(self, request: pb.ChartRequest, context: grpc.ServicerContext) -> pb.ChartResponse:
        def compute() -> pb.ChartResponse:
            birth = mapping.birth_from_proto(_required_birth(request))
            as_of = mapping.date_from_proto(_required_date(request, "as_of"))
            return mapping.chart_to_proto(compose_chart(birth, as_of))

        return run_or_abort(context, compute)

    def GetDaily(self, request: pb.DailyRequest, context: grpc.ServicerContext) -> pb.DailyResponse:
        def compute() -> pb.DailyResponse:
            birth = mapping.birth_from_proto(_required_birth(request))
            target = mapping.date_from_proto(_required_date(request, "date"))
            current_timezone = mapping.timezone_from_proto(request.current_timezone)
            return mapping.daily_to_proto(compose_daily(birth, target, current_timezone))

        return run_or_abort(context, compute)

    def GetMonthCalendar(self, request: pb.MonthRequest, context: grpc.ServicerContext) -> pb.MonthResponse:
        def compute() -> pb.MonthResponse:
            birth = mapping.birth_from_proto(_required_birth(request))
            year = _required_scalar(request.year, "year")
            month = _required_scalar(request.month, "month")
            current_timezone = mapping.timezone_from_proto(request.current_timezone)
            return mapping.month_to_proto(compose_month(birth, year, month, current_timezone))

        return run_or_abort(context, compute)

    def GetBirthHour(
        self, request: pb.BirthHourRequest, context: grpc.ServicerContext
    ) -> pb.BirthHourResponse:
        def compute() -> pb.BirthHourResponse:
            birth = mapping.birth_from_proto(_required_birth(request), require_gender=False)
            return mapping.birth_hour_to_proto(birth_hour(birth))

        return run_or_abort(context, compute)

    def GetInfo(self, request: pb.InfoRequest, context: grpc.ServicerContext) -> pb.InfoResponse:
        def compute() -> pb.InfoResponse:
            return pb.InfoResponse(engine_version=ENGINE_VERSION, ruleset_version=RULESET_VERSION)

        return run_or_abort(context, compute)

    def ConvertLunarDate(
        self, request: pb.LunarDateRequest, context: grpc.ServicerContext
    ) -> pb.LunarDateResponse:
        def compute() -> pb.LunarDateResponse:
            lunar = _required_date(request, "date")
            solar = lunar_adapter.lunar_to_solar(lunar.year, lunar.month, lunar.day, request.is_leap_month)
            return mapping.lunar_conversion_to_proto(
                solar, lunar_adapter.month_has_leap(lunar.year, lunar.month)
            )

        return run_or_abort(context, compute)


def _required_birth(
    request: pb.ChartRequest | pb.DailyRequest | pb.MonthRequest | pb.BirthHourRequest,
) -> pb.BirthInfo:
    if not request.HasField("birth"):
        raise InvalidInputError("출생 정보가 없습니다.")
    return request.birth


def _required_date(
    request: pb.ChartRequest | pb.DailyRequest | pb.LunarDateRequest, field_name: str
) -> pb.LocalDate:
    """필수 날짜 필드. 없으면 필드 이름을 담은 InvalidInputError."""
    if not request.HasField(field_name):
        raise InvalidInputError(f"{field_name}가 없습니다.")
    value: pb.LocalDate = getattr(request, field_name)
    return value


def _required_scalar(value: int, field_name: str) -> int:
    """proto3 스칼라는 0이 값 없음이다. 0이면 필드 이름을 담은 InvalidInputError."""
    if value == 0:
        raise InvalidInputError(f"{field_name}가 없습니다.")
    return value


@dataclass(frozen=True)
class RunningEngine:
    """시작된 엔진 서버와 그 health 상태."""

    server: grpc.Server
    port: int
    health: health.HealthServicer

    def begin_shutdown(self) -> None:
        """health를 모두 NOT_SERVING으로 바꾼다. 이후 상태 변경은 무시된다."""
        self.health.enter_graceful_shutdown()

    def stop(self, grace: float | None) -> None:
        self.server.stop(grace=grace).wait()


def start(port: int = DEFAULT_PORT) -> RunningEngine:
    """근거 데이터를 검증하고 계산 캐시를 데운 뒤 서버를 시작한다.

    port=0이면 임의 포트에 바인딩하고, 실제 포트는 RunningEngine.port에 있다.
    근거 데이터에 없는 키가 있으면 KeyError로 시작하지 않는다(spec 11).
    준비가 끝난 뒤에만 health(전체 "", 엔진 서비스)를 SERVING으로 둔다.
    """
    loader.validate_refs(loader.all_refs())
    lunar_adapter.warm_up()
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=MAX_WORKERS))
    pb_grpc.add_MyungliEngineServicer_to_server(MyungliEngineServicer(), server)
    health_servicer = health.HealthServicer()
    health_pb2_grpc.add_HealthServicer_to_server(health_servicer, server)
    bound_port = server.add_insecure_port(f"[::]:{port}")
    server.start()
    for service in ("", ENGINE_SERVICE_NAME):
        health_servicer.set(service, health_pb2.HealthCheckResponse.SERVING)
    return RunningEngine(server=server, port=bound_port, health=health_servicer)
