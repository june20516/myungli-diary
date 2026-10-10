"""원국의 여덟 자리."""

from __future__ import annotations

from enum import Enum, auto


class Position(Enum):
    YEAR_STEM = auto()
    YEAR_BRANCH = auto()
    MONTH_STEM = auto()
    MONTH_BRANCH = auto()
    DAY_STEM = auto()
    DAY_BRANCH = auto()
    HOUR_STEM = auto()
    HOUR_BRANCH = auto()


BRANCH_POSITIONS: tuple[Position, ...] = (
    Position.YEAR_BRANCH,
    Position.MONTH_BRANCH,
    Position.DAY_BRANCH,
    Position.HOUR_BRANCH,
)
