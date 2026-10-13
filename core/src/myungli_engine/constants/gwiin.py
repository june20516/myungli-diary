"""천을귀인표 (07 위키 §5)."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Final

from myungli_engine.domain.enums import Branch, Stem

CHEONEUL_GWIIN: Final[Mapping[Stem, frozenset[Branch]]] = {
    Stem.GAP: frozenset({Branch.CHUK, Branch.MI}),
    Stem.MU: frozenset({Branch.CHUK, Branch.MI}),
    Stem.GYEONG: frozenset({Branch.CHUK, Branch.MI}),
    Stem.EUL: frozenset({Branch.JA, Branch.SHIN}),
    Stem.GI: frozenset({Branch.JA, Branch.SHIN}),
    Stem.BYEONG: frozenset({Branch.HAE, Branch.YU}),
    Stem.JEONG: frozenset({Branch.HAE, Branch.YU}),
    Stem.SIN: frozenset({Branch.IN, Branch.O}),
    Stem.IM: frozenset({Branch.SA, Branch.MYO}),
    Stem.GYE: frozenset({Branch.SA, Branch.MYO}),
}
