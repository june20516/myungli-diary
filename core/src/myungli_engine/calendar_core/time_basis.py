"""calendar_core 모듈들이 함께 쓰는 시각 기초: 절기 기준 시간대, 경도 보정, 시간대 로딩 (spec 4.1, 4.2)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from myungli_engine.domain.errors import InvalidInputError

SOLAR_TERM_TIMEZONE = timezone(timedelta(hours=8))  # lunar-python 절기 시각 기준
SECONDS_PER_DEGREE = 240  # 경도 1도 = 시간 4분
MAX_ECHOED_NAME_LENGTH = 64  # 오류 메시지에 되돌리는 시간대 이름의 최대 길이


def load_zone(name: str) -> ZoneInfo:
    """IANA 이름으로 시간대를 연다. 없는 이름이나 열 수 없는 이름(파일 이름 한도 초과 등)은 InvalidInputError."""
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError, OSError) as error:
        raise InvalidInputError(f"알 수 없는 시간대입니다: {_shortened(name)!r}") from error


def _shortened(name: str) -> str:
    if len(name) <= MAX_ECHOED_NAME_LENGTH:
        return name
    return f"{name[:MAX_ECHOED_NAME_LENGTH]}..."


def standard_offset_hours(utc: datetime, zone: ZoneInfo) -> float:
    """그 시점의 표준 오프셋(서머타임 제외)을 시간 단위로 돌려준다."""
    local = utc.astimezone(zone)
    offset = local.utcoffset()
    dst = local.dst() or timedelta(0)
    assert offset is not None
    return (offset - dst).total_seconds() / 3600


def longitude_correction(longitude: float) -> timedelta:
    """보정 시각 = UTC + 이 값 (경도 x 4분)."""
    return timedelta(seconds=round(longitude * SECONDS_PER_DEGREE))
