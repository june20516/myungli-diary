"""방위 상수 (spec §7.3). 토는 대표 방위가 없어 ELEMENT_DIRECTION에 넣지 않는다."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Final

from myungli_engine.domain.enums import Branch as B
from myungli_engine.domain.enums import Direction8 as D
from myungli_engine.domain.enums import Element as E

ELEMENT_DIRECTION: Final[Mapping[E, D]] = {E.WATER: D.N, E.FIRE: D.S, E.WOOD: D.E, E.METAL: D.W}

BAGUA_ELEMENT: Final[Mapping[D, E]] = {
    D.N: E.WATER,
    D.NE: E.EARTH,
    D.E: E.WOOD,
    D.SE: E.WOOD,
    D.S: E.FIRE,
    D.SW: E.EARTH,
    D.W: E.METAL,
    D.NW: E.METAL,
}

BRANCH_DIRECTION: Final[Mapping[B, D]] = {
    B.JA: D.N,
    B.CHUK: D.NE,
    B.IN: D.NE,
    B.MYO: D.E,
    B.JIN: D.SE,
    B.SA: D.SE,
    B.O: D.S,
    B.MI: D.SW,
    B.SHIN: D.SW,
    B.YU: D.W,
    B.SUL: D.NW,
    B.HAE: D.NW,
}
