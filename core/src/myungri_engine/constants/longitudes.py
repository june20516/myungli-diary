"""대표 경도 (spec §4.2)."""

from __future__ import annotations

SEOUL_TIMEZONE = "Asia/Seoul"
SEOUL_REPRESENTATIVE_LONGITUDE = 127.5
DEGREES_PER_HOUR = 15.0


def representative_longitude(timezone: str, standard_offset_hours: float) -> float:
    """Asia/Seoul은 127.5도, 그 밖은 표준 오프셋의 표준 자오선(오프셋 시간 x 15도)."""
    if timezone == SEOUL_TIMEZONE:
        return SEOUL_REPRESENTATIVE_LONGITUDE
    return standard_offset_hours * DEGREES_PER_HOUR
