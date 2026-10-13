"""MyungriEngine gRPC 서버 (spec 9, 11)."""

from __future__ import annotations

from collections.abc import Iterator
from concurrent import futures
from typing import Final

import grpc

from myungri_engine._gen.myungri.engine.v1 import engine_pb2 as pb
from myungri_engine._gen.myungri.engine.v1 import engine_pb2_grpc as pb_grpc
from myungri_engine.calendar_core import lunar_adapter
from myungri_engine.calendar_core.birth import birth_hour
from myungri_engine.composers.chart import compose_chart
from myungri_engine.composers.daily import compose_daily
from myungri_engine.composers.month import compose_month
from myungri_engine.domain.enums import Branch, Stem
from myungri_engine.domain.errors import InvalidInputError
from myungri_engine.grpc_api import mapping
from myungri_engine.grpc_api.errors import run_or_abort
from myungri_engine.references import loader
from myungri_engine.version import ENGINE_VERSION, RULESET_VERSION

DEFAULT_PORT: Final = 50051
MAX_WORKERS: Final = 8


class MyungriEngineServicer(pb_grpc.MyungriEngineServicer):
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
            birth = mapping.birth_from_proto(_required_birth(request))
            return mapping.birth_hour_to_proto(birth_hour(birth))

        return run_or_abort(context, compute)

    def GetInfo(self, request: pb.InfoRequest, context: grpc.ServicerContext) -> pb.InfoResponse:
        def compute() -> pb.InfoResponse:
            return pb.InfoResponse(engine_version=ENGINE_VERSION, ruleset_version=RULESET_VERSION)

        return run_or_abort(context, compute)


def _required_birth(
    request: pb.ChartRequest | pb.DailyRequest | pb.MonthRequest | pb.BirthHourRequest,
) -> pb.BirthInfo:
    if not request.HasField("birth"):
        raise InvalidInputError("출생 정보가 없습니다.")
    return request.birth


def _required_date(request: pb.ChartRequest | pb.DailyRequest, field_name: str) -> pb.LocalDate:
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


def all_reference_refs() -> Iterator[str]:
    """엔진이 낼 수 있는 모든 source_ref: 조후 120칸과 오행 근거 전부."""
    yield from (loader.johu_ref(stem, branch) for stem in Stem for branch in Branch)
    yield from loader.FIVE_ELEMENTS_REF.values()


def start(port: int = DEFAULT_PORT) -> tuple[grpc.Server, int]:
    """근거 데이터를 검증하고 계산 캐시를 데운 뒤 서버를 시작해 (서버, 실제 바인딩 포트)를 돌려준다.

    port=0이면 임의 포트에 바인딩한다. 근거 데이터에 없는 키가 있으면 KeyError로 시작하지 않는다(spec 11).
    """
    loader.validate_refs(all_reference_refs())
    lunar_adapter.warm_up()
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=MAX_WORKERS))
    pb_grpc.add_MyungriEngineServicer_to_server(MyungriEngineServicer(), server)
    bound_port = server.add_insecure_port(f"[::]:{port}")
    server.start()
    return server, bound_port


def serve(port: int = DEFAULT_PORT) -> grpc.Server:
    server, _ = start(port)
    return server
