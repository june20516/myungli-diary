from dataclasses import replace

import pytest

from myungri_engine.domain.enums import DayKind, Element
from myungri_engine.references import loader
from myungri_engine.references.loader import FIVE_ELEMENTS_REF
from myungri_engine.rules.color import ElementRole, lucky_element
from myungri_engine.rules.yongsin import YongsinResult


@pytest.mark.parametrize(
    ("kind", "element", "role"),
    [
        (DayKind.GISIN_DAY, Element.WOOD, ElementRole.TONGGWAN),
        (DayKind.GWIIN_DAY, Element.FIRE, ElementRole.YONGSIN),
        (DayKind.YONGSIN_DAY, Element.FIRE, ElementRole.YONGSIN),
        (DayKind.ORDINARY_DAY, Element.FIRE, ElementRole.YONGSIN),
    ],
)
def test_color_roles(kind: DayKind, element: Element, role: ElementRole, winter_gap: YongsinResult) -> None:
    pick = lucky_element(kind, winter_gap)
    assert (pick.element, pick.role) == (element, role)
    assert pick.evidence[0].source_ref == FIVE_ELEMENTS_REF["color"]
    loader.validate_refs(e.source_ref for e in pick.evidence)


def test_metal_passes_source_note(winter_gap: YongsinResult) -> None:
    metal = replace(winter_gap, yongsin=Element.METAL)
    pick = lucky_element(DayKind.YONGSIN_DAY, metal)
    assert "金" in pick.evidence[0].detail["note"]
    assert "note" not in lucky_element(DayKind.YONGSIN_DAY, winter_gap).evidence[0].detail
