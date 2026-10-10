"""일간 기준 십성 판정."""

from __future__ import annotations

from myungri_engine.domain.elements import controlled_by, controls, generated_by, generates
from myungri_engine.domain.enums import Stem, TenGod

# (같은 음양, 다른 음양) 순서
_BY_RELATION: dict[str, tuple[TenGod, TenGod]] = {
    "same": (TenGod.BIGYEON, TenGod.GEOPJAE),
    "output": (TenGod.SIKSIN, TenGod.SANGGWAN),
    "wealth": (TenGod.PYEONJAE, TenGod.JEONGJAE),
    "officer": (TenGod.PYEONGWAN, TenGod.JEONGGWAN),
    "resource": (TenGod.PYEONIN, TenGod.JEONGIN),
}


def ten_god(day_stem: Stem, other: Stem) -> TenGod:
    me, you = day_stem.element, other.element
    if you == me:
        relation = "same"
    elif you == generates(me):
        relation = "output"
    elif you == controls(me):
        relation = "wealth"
    elif you == controlled_by(me):
        relation = "officer"
    else:
        assert you == generated_by(me)
        relation = "resource"
    same_polarity, other_polarity = _BY_RELATION[relation]
    return same_polarity if day_stem.is_yang == other.is_yang else other_polarity
