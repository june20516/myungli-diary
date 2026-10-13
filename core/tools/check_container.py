"""실행 중인 엔진 컨테이너를 검사한다 (#34).

사용: uv run python tools/check_container.py localhost:8080

준비될 때까지 기다린 뒤 health(전체 "", 엔진 서비스)가 SERVING인지, GetInfo가 이 소스의 버전을 돌려주는지 본다.
실패하면 0이 아닌 코드로 끝난다.
"""

from __future__ import annotations

import sys

import grpc
from grpc_health.v1 import health_pb2, health_pb2_grpc

from myungli_engine._gen.myungli.engine.v1 import engine_pb2 as pb
from myungli_engine._gen.myungli.engine.v1 import engine_pb2_grpc as pb_grpc
from myungli_engine.grpc_api.server import ENGINE_SERVICE_NAME
from myungli_engine.version import ENGINE_VERSION, RULESET_VERSION

READY_TIMEOUT_SECONDS = 30.0
CALL_TIMEOUT_SECONDS = 5.0


def check(address: str) -> list[str]:
    """문제 목록을 돌려준다. 비어 있으면 통과."""
    problems: list[str] = []
    with grpc.insecure_channel(address) as channel:
        grpc.channel_ready_future(channel).result(timeout=READY_TIMEOUT_SECONDS)

        health = health_pb2_grpc.HealthStub(channel)
        for service in ("", ENGINE_SERVICE_NAME):
            request = health_pb2.HealthCheckRequest(service=service)
            status = health.Check(request, timeout=CALL_TIMEOUT_SECONDS).status
            if status != health_pb2.HealthCheckResponse.SERVING:
                problems.append(
                    f"health {service!r}: {health_pb2.HealthCheckResponse.ServingStatus.Name(status)}"
                )

        info = pb_grpc.MyungliEngineStub(channel).GetInfo(pb.InfoRequest(), timeout=CALL_TIMEOUT_SECONDS)
        if (info.engine_version, info.ruleset_version) != (ENGINE_VERSION, RULESET_VERSION):
            problems.append(f"GetInfo: {info.engine_version}/{info.ruleset_version}")
    return problems


def main() -> int:
    if len(sys.argv) != 2:
        print("사용: check_container.py <host:port>", file=sys.stderr)
        return 2
    problems = check(sys.argv[1])
    for problem in problems:
        print(problem, file=sys.stderr)
    if not problems:
        print(f"OK: {ENGINE_VERSION}/{RULESET_VERSION}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
