"""도메인 예외의 gRPC 상태 변환 (spec 9, Q1 core-Q1-2)."""

import grpc

from myungli_engine.domain.errors import InvalidInputError, OutOfRangeError
from myungli_engine.grpc_api.errors import INTERNAL_MESSAGE, MAX_DETAIL_LENGTH, status_for


def test_domain_error_keeps_short_message() -> None:
    assert status_for(InvalidInputError("시간대가 비어 있습니다.")) == (
        grpc.StatusCode.INVALID_ARGUMENT,
        "시간대가 비어 있습니다.",
    )


def test_long_domain_message_is_cut_to_limit() -> None:
    for error_type, code in ((InvalidInputError, grpc.StatusCode.INVALID_ARGUMENT),
                             (OutOfRangeError, grpc.StatusCode.OUT_OF_RANGE)):
        got_code, message = status_for(error_type("x" * 10_000))
        assert got_code == code
        assert len(message) <= MAX_DETAIL_LENGTH
        assert message.endswith("...")


def test_unexpected_error_uses_fixed_message() -> None:
    assert status_for(RuntimeError("/secret")) == (grpc.StatusCode.INTERNAL, INTERNAL_MESSAGE)
