"""엔진 실행: `uv run python -m myungli_engine --port 50051`."""

from __future__ import annotations

import argparse
import logging
import signal
import threading
from types import FrameType

from myungli_engine.grpc_api.server import DEFAULT_PORT, start

SHUTDOWN_GRACE_SECONDS = 10.0

_logger = logging.getLogger("myungli_engine")


def main() -> None:
    parser = argparse.ArgumentParser(prog="myungli_engine", description="명리 엔진 gRPC 서버")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO)

    server, port = start(args.port)
    _logger.info("myungli engine listening on port %d", port)

    stop_requested = threading.Event()

    def request_stop(signum: int, _frame: FrameType | None) -> None:
        _logger.info("received signal %d, stopping", signum)
        stop_requested.set()

    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)

    stop_requested.wait()
    server.stop(grace=SHUTDOWN_GRACE_SECONDS).wait()


if __name__ == "__main__":
    main()
