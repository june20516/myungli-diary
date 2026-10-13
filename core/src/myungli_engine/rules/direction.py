"""행운 방향 (spec 7.3)."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

from myungli_engine.calendar_core.lunar_adapter import DeityKind
from myungli_engine.constants.directions import BAGUA_ELEMENT, BRANCH_DIRECTION, ELEMENT_DIRECTION
from myungli_engine.constants.relations import BRANCH_CHUNG
from myungli_engine.domain.enums import Branch, DayKind, Direction8, Element
from myungli_engine.domain.models import Evidence, Pillar
from myungli_engine.references.loader import FIVE_ELEMENTS_REF
from myungli_engine.rules.yongsin import YongsinResult

_NORTHEAST_BRANCHES = (Branch.CHUK, Branch.IN)
_SOUTHWEST_BRANCHES = (Branch.MI, Branch.SHIN)


@dataclass(frozen=True, slots=True)
class DirectionPick:
    direction: Direction8
    rule_id: str
    evidence: tuple[Evidence, ...]


def _clashes_with_any(branch: Branch, others: tuple[Branch, ...]) -> bool:
    return any(frozenset({branch, other}) in BRANCH_CHUNG for other in others)


def _element_direction(element: Element, today_branch: Branch) -> Direction8:
    """오행의 대표 방위. 토는 오늘 지지와의 충으로 북동·남서 중에서 고른다."""
    if element is not Element.EARTH:
        return ELEMENT_DIRECTION[element]
    if _clashes_with_any(today_branch, _NORTHEAST_BRANCHES):
        return Direction8.SW
    if _clashes_with_any(today_branch, _SOUTHWEST_BRANCHES):
        return Direction8.NE
    return Direction8.NE


def _first_deity_direction(
    deities: Sequence[tuple[DeityKind, Direction8]], element: Element
) -> tuple[DeityKind, Direction8] | None:
    return next(
        ((kind, direction) for kind, direction in deities if BAGUA_ELEMENT[direction] is element), None
    )


def _pick(
    direction: Direction8, rule_id: str, kind: DayKind, day: Pillar, extra: dict[str, str] | None = None
) -> DirectionPick:
    detail = {"direction": direction.name, "day_kind": kind.name, "day_branch": day.branch.hanja} | (
        extra or {}
    )
    evidence = Evidence(rule_id=rule_id, source_ref=FIVE_ELEMENTS_REF["direction"], detail=detail)
    return DirectionPick(direction=direction, rule_id=rule_id, evidence=(evidence,))


def lucky_direction(
    kind: DayKind,
    day: Pillar,
    yongsin: YongsinResult,
    deities: Sequence[tuple[DeityKind, Direction8]],
) -> DirectionPick:
    if kind is DayKind.GWIIN_DAY:
        return _pick(BRANCH_DIRECTION[day.branch], "direction/gwiin_branch", kind, day)
    if kind is DayKind.YONGSIN_DAY:
        direction = _element_direction(yongsin.yongsin, day.branch)
        return _pick(direction, "direction/yongsin", kind, day, {"element": yongsin.yongsin.name})
    if kind is DayKind.GISIN_DAY:
        direction = _element_direction(yongsin.tonggwan, day.branch)
        return _pick(direction, "direction/tonggwan", kind, day, {"element": yongsin.tonggwan.name})

    for element, rule_id in (
        (yongsin.yongsin, "direction/ordinary_deity_yongsin"),
        (yongsin.huisin, "direction/ordinary_deity_huisin"),
    ):
        found = _first_deity_direction(deities, element)
        if found is not None:
            deity_kind, direction = found
            return _pick(direction, rule_id, kind, day, {"element": element.name, "deity": deity_kind.name})
    direction = _element_direction(yongsin.yongsin, day.branch)
    return _pick(direction, "direction/ordinary_fallback", kind, day, {"element": yongsin.yongsin.name})
