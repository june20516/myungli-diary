from collections.abc import Callable

import pytest

from myungri_engine.calendar_core.lunar_adapter import DeityKind
from myungri_engine.domain.enums import Branch, DayKind, Direction8, Element
from myungri_engine.domain.models import Pillar
from myungri_engine.references import loader
from myungri_engine.rules.day_kind import classify_day
from myungri_engine.rules.direction import lucky_direction
from myungri_engine.rules.yongsin import YongsinResult

D = Direction8
Deities = tuple[tuple[DeityKind, Direction8], ...]


@pytest.mark.parametrize(
    ("ganzhi", "kind", "direction"),
    [
        ("丁巳", DayKind.YONGSIN_DAY, D.S),
        ("戊午", DayKind.YONGSIN_DAY, D.S),
        ("己未", DayKind.GWIIN_DAY, D.SW),
        ("庚申", DayKind.ORDINARY_DAY, D.S),  # 양귀 正南(화=용신)이 희신보다 우선
        ("辛酉", DayKind.ORDINARY_DAY, D.S),
        ("壬戌", DayKind.GISIN_DAY, D.E),
        ("癸亥", DayKind.GISIN_DAY, D.E),
    ],
)
def test_week_simulation(
    ganzhi: str,
    kind: DayKind,
    direction: Direction8,
    winter_gap: YongsinResult,
    gwiin_branches: frozenset[Branch],
    deities_for: Callable[[str], Deities],
    pillar_of: Callable[[str], Pillar],
) -> None:
    day = pillar_of(ganzhi)
    assert classify_day(day, winter_gap, gwiin_branches) is kind
    pick = lucky_direction(kind, day, winter_gap, deities_for(ganzhi))
    assert pick.direction is direction
    assert pick.evidence
    assert all(e.rule_id == pick.rule_id for e in pick.evidence)
    loader.validate_refs(e.source_ref for e in pick.evidence)


@pytest.mark.parametrize(
    ("ganzhi", "kind", "rule_id"),
    [
        ("己未", DayKind.GWIIN_DAY, "direction/gwiin_branch"),
        ("丁巳", DayKind.YONGSIN_DAY, "direction/yongsin"),
        ("壬戌", DayKind.GISIN_DAY, "direction/tonggwan"),
        ("庚申", DayKind.ORDINARY_DAY, "direction/ordinary_deity_yongsin"),
    ],
)
def test_rule_ids(
    ganzhi: str,
    kind: DayKind,
    rule_id: str,
    winter_gap: YongsinResult,
    deities_for: Callable[[str], Deities],
    pillar_of: Callable[[str], Pillar],
) -> None:
    assert lucky_direction(kind, pillar_of(ganzhi), winter_gap, deities_for(ganzhi)).rule_id == rule_id


@pytest.mark.parametrize(
    ("ganzhi", "expected"),
    [("乙未", D.SW), ("乙丑", D.NE), ("甲子", D.NE), ("甲寅", D.NE), ("甲申", D.SW)],
)
def test_earth_direction(
    ganzhi: str,
    expected: Direction8,
    winter_gap: YongsinResult,
    pillar_of: Callable[[str], Pillar],
) -> None:
    """용신 토: 未(丑과 충)·申(寅과 충) -> 남서, 丑·寅(未·申과 충)·그 밖 -> 북동."""
    earth = YongsinResult(
        yongsin=Element.EARTH,
        huisin=winter_gap.huisin,
        gisin=winter_gap.gisin,
        tonggwan=winter_gap.tonggwan,
        method=winter_gap.method,
        johu_stem=None,
        evidence=(),
    )
    pick = lucky_direction(DayKind.YONGSIN_DAY, pillar_of(ganzhi), earth, ())
    assert pick.direction is expected


def test_ordinary_huisin_when_no_yongsin_direction(
    winter_gap: YongsinResult, pillar_of: Callable[[str], Pillar]
) -> None:
    deities = ((DeityKind.XI, D.N), (DeityKind.FU, D.SE), (DeityKind.CAI, D.E))
    pick = lucky_direction(DayKind.ORDINARY_DAY, pillar_of("庚申"), winter_gap, deities)
    assert (pick.direction, pick.rule_id) == (D.SE, "direction/ordinary_deity_huisin")


def test_ordinary_fallback_to_yongsin(winter_gap: YongsinResult, pillar_of: Callable[[str], Pillar]) -> None:
    deities = ((DeityKind.XI, D.N), (DeityKind.FU, D.W), (DeityKind.CAI, D.NW))
    pick = lucky_direction(DayKind.ORDINARY_DAY, pillar_of("庚申"), winter_gap, deities)
    assert (pick.direction, pick.rule_id) == (D.S, "direction/ordinary_fallback")
