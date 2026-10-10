"""하도(河圖) 수 (spec §7.4)."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Final

from myungri_engine.domain.enums import Element

HADO: Final[Mapping[Element, tuple[int, int]]] = {
    Element.WATER: (1, 6),
    Element.FIRE: (2, 7),
    Element.WOOD: (3, 8),
    Element.METAL: (4, 9),
    Element.EARTH: (5, 10),
}
