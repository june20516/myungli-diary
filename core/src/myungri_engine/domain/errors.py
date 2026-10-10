"""엔진 도메인 오류."""

from __future__ import annotations


class InvalidInputError(ValueError):
    """형식이 잘못되었거나 모순되는 입력."""


class OutOfRangeError(ValueError):
    """지원 범위(양력 1900-01-31 ~ 2099-12-31) 밖의 입력."""
