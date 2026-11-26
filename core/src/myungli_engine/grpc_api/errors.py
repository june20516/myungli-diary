"""도메인 예외를 gRPC 상태 코드로 바꾼다 (spec 9)."""

from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Final

import grpc

from myungli_engine.domain.errors import InvalidInputError, OutOfRangeError

INTERNAL_MESSAGE: Final[str] = "internal engine error"
# 상태 상세에 담는 도메인 오류 메시지의 최대 길이. 입력값을 담는 메시지가 응답 metadata를 키우지 않게 한다.
MAX_DETAIL_LENGTH: Final[int] = 256
_ELLIPSIS: Final[str] = "..."

_logger = logging.getLogger(__name__)


def status_for(error: Exception) -> tuple[grpc.StatusCode, str]:
    """도메인 오류는 그 메시지를, 그 밖은 내부 정보가 없는 고정 메시지를 쓴다."""
    if isinstance(error, InvalidInputError):
        return grpc.StatusCode.INVALID_ARGUMENT, _limited(str(error))
    if isinstance(error, OutOfRangeError):
        return grpc.StatusCode.OUT_OF_RANGE, _limited(str(error))
    return grpc.StatusCode.INTERNAL, INTERNAL_MESSAGE


def _limited(message: str) -> str:
    if len(message) <= MAX_DETAIL_LENGTH:
        return message
    return message[: MAX_DETAIL_LENGTH - len(_ELLIPSIS)] + _ELLIPSIS


def run_or_abort[T](context: grpc.ServicerContext, compute: Callable[[], T]) -> T:
    """compute를 실행하고, 예외면 상태 코드로 RPC를 끝낸다. 예상 못 한 예외는 서버 로그에만 남긴다."""
    try:
        return compute()
    except Exception as error:
        code, message = status_for(error)
        if code is grpc.StatusCode.INTERNAL:
            _logger.exception("unexpected engine error")
        context.abort(code, message)
