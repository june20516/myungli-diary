"""신살 매핑 (spec §5.4). 삼합 그룹의 각 지지 → 신살 지지."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Final

from myungli_engine.domain.enums import Branch as B
from myungli_engine.domain.enums import Stem as S

_FIRE_GROUP: Final = (B.IN, B.O, B.SUL)
_WATER_GROUP: Final = (B.SHIN, B.JA, B.JIN)
_METAL_GROUP: Final = (B.SA, B.YU, B.CHUK)
_WOOD_GROUP: Final = (B.HAE, B.MYO, B.MI)


def _by_group(fire: B, water: B, metal: B, wood: B) -> Mapping[B, B]:
    mapping: dict[B, B] = {}
    for group, target in (
        (_FIRE_GROUP, fire),
        (_WATER_GROUP, water),
        (_METAL_GROUP, metal),
        (_WOOD_GROUP, wood),
    ):
        for branch in group:
            mapping[branch] = target
    return mapping


DOHWA: Final[Mapping[B, B]] = _by_group(fire=B.MYO, water=B.YU, metal=B.O, wood=B.JA)
YEOKMA: Final[Mapping[B, B]] = _by_group(fire=B.SHIN, water=B.IN, metal=B.HAE, wood=B.SA)
HWAGAE: Final[Mapping[B, B]] = _by_group(fire=B.SUL, water=B.JIN, metal=B.CHUK, wood=B.MI)

YANGIN: Final[Mapping[S, B]] = {S.GAP: B.MYO, S.BYEONG: B.O, S.MU: B.O, S.GYEONG: B.YU, S.IM: B.JA}
