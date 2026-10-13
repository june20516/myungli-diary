"""엔진 실행: `uv run python -m myungli_engine --port 50051`.

포트는 --port 인자, PORT 환경 변수(Cloud Run이 넣어 준다), 기본값 순으로 정한다.
"""

from __future__ import annotations

import argparse
import logging
import os
import signal
import threading
from collections.abc import Mapping
from types import FrameType

from myungli_engine.grpc_api.server import DEFAULT_PORT, start

# Cloud Run은 SIGTERM 뒤 10초 안에 강제 종료하므로 그보다 짧게 둔다.
SHUTDOWN_GRACE_SECONDS = 8.0
PORT_ENV = "PORT"

_logger = logging.getLogger("myungli_engine")


def resolve_port(cli_port: int | None, env: Mapping[str, str]) -> int:
    if cli_port is not None:
        return cli_port
    env_port = env.get(PORT_ENV)
    if env_port is None:
        return DEFAULT_PORT
    if not env_port.isdigit():
        raise ValueError(f"{PORT_ENV} 환경 변수는 숫자여야 합니다: {env_port!r}")
    return int(env_port)


def main() -> None:
    parser = argparse.ArgumentParser(prog="myungli_engine", description="명리 엔진 gRPC 서버")
    parser.add_argument(
        "--port", type=int, default=None, help=f"기본: {PORT_ENV} 환경 변수, 없으면 {DEFAULT_PORT}"
    )
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO)

    running = start(resolve_port(args.port, os.environ))
    _logger.info("myungli engine listening on port %d", running.port)

    stop_requested = threading.Event()

    def request_stop(signum: int, _frame: FrameType | None) -> None:
        _logger.info("received signal %d, stopping", signum)
        stop_requested.set()

    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)

    stop_requested.wait()
    running.begin_shutdown()
    running.stop(grace=SHUTDOWN_GRACE_SECONDS)


if __name__ == "__main__":
    main()
