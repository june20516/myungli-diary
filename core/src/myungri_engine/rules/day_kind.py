"""날의 성격 4단계 판정 (spec 7.1)."""

from __future__ import annotations

from myungri_engine.domain.enums import Branch, DayKind
from myungri_engine.domain.models import Pillar
from myungri_engine.rules.yongsin import YongsinResult


def classify_day(day: Pillar, yongsin: YongsinResult, gwiin: frozenset[Branch]) -> DayKind:
    """귀인 > 용신(기신 없음) > 기신 > 평범 순으로 처음 해당하는 성격을 돌려준다."""
    if day.branch in gwiin:
        return DayKind.GWIIN_DAY
    day_elements = {day.stem.element, day.branch.element}
    if yongsin.gisin in day_elements:
        return DayKind.GISIN_DAY
    if yongsin.yongsin in day_elements:
        return DayKind.YONGSIN_DAY
    return DayKind.ORDINARY_DAY
