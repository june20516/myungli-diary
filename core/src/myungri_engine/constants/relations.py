"""합·충·형 매핑 (07 위키 §5, spec §7.6). 키는 순서 없는 frozenset."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Final

from myungri_engine.domain.enums import Branch as B
from myungri_engine.domain.enums import Element as E
from myungri_engine.domain.enums import Stem as S

STEM_HAP: Final[Mapping[frozenset[S], E]] = {
    frozenset({S.GAP, S.GI}): E.EARTH,
    frozenset({S.EUL, S.GYEONG}): E.METAL,
    frozenset({S.BYEONG, S.SIN}): E.WATER,
    frozenset({S.JEONG, S.IM}): E.WOOD,
    frozenset({S.MU, S.GYE}): E.FIRE,
}

BRANCH_HAP: Final[Mapping[frozenset[B], E]] = {
    frozenset({B.JA, B.CHUK}): E.EARTH,
    frozenset({B.IN, B.HAE}): E.WOOD,
    frozenset({B.MYO, B.SUL}): E.FIRE,
    frozenset({B.JIN, B.YU}): E.METAL,
    frozenset({B.SA, B.SHIN}): E.WATER,
    frozenset({B.O, B.MI}): E.FIRE,  # 오미합화는 火로 엔진 통일
}

BRANCH_CHUNG: Final[frozenset[frozenset[B]]] = frozenset(
    {
        frozenset({B.JA, B.O}),
        frozenset({B.CHUK, B.MI}),
        frozenset({B.IN, B.SHIN}),
        frozenset({B.MYO, B.YU}),
        frozenset({B.JIN, B.SUL}),
        frozenset({B.SA, B.HAE}),
    }
)

BRANCH_HYEONG_GROUPS: Final[tuple[frozenset[B], ...]] = (
    frozenset({B.IN, B.SA, B.SHIN}),
    frozenset({B.CHUK, B.SUL, B.MI}),
)

BRANCH_HYEONG_PAIRS: Final[frozenset[frozenset[B]]] = frozenset({frozenset({B.JA, B.MYO})})

SELF_HYEONG: Final[frozenset[B]] = frozenset({B.JIN, B.O, B.YU, B.HAE})
