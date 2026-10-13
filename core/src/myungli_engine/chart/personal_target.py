"""원국 개인 해석 한 건. 어떤 용어를 어느 자리에서 풀었는지와 판단을 묶는다."""

from __future__ import annotations

from dataclasses import dataclass

from myungli_engine.chart.positions import Position
from myungli_engine.domain.enums import PersonalTermKind, Shinsal
from myungli_engine.domain.models import Judgment


@dataclass(frozen=True, slots=True)
class PersonalReading:
    kind: PersonalTermKind
    position: Position | None
    index: int
    shinsal: Shinsal | None
    judgment: Judgment
