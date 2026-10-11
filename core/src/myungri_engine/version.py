"""엔진·규칙 버전 (spec 12)."""

from __future__ import annotations

from importlib.metadata import version
from typing import Final

ENGINE_VERSION: Final[str] = version("myungri-engine")
# 규칙·상수·근거 데이터가 바뀌어 출력이 달라질 때 올린다.
RULESET_VERSION: Final[str] = "2026.10.2"
