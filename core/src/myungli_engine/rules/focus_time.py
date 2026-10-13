"""집중하기 좋은 시간 (spec 7.5). 진시~술시 중 원국과 충하지 않는 시진을 점수로 고른다."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Final

from myungli_engine.calendar_core.lunar_adapter import HourSlot
from myungli_engine.constants.relations import BRANCH_CHUNG, BRANCH_HAP
from myungli_engine.domain.enums import Branch
from myungli_engine.domain.models import Evidence, FourPillars
from myungli_engine.references.loader import FIVE_ELEMENTS_REF
from myungli_engine.rules.yongsin import YongsinResult

CANDIDATE_BRANCHES: Final[frozenset[Branch]] = frozenset(
    {Branch.JIN, Branch.SA, Branch.O, Branch.MI, Branch.SHIN, Branch.YU, Branch.SUL}
)
MAX_PICKS: Final = 2
GWIIN_SCORE: Final = 3
YONGSIN_SCORE: Final = 2
HUISIN_SCORE: Final = 1
HAP_SCORE: Final = 1

REASON_GWIIN: Final = "gwiin"
REASON_YONGSIN: Final = "yongsin"
REASON_HUISIN: Final = "huisin"
REASON_HAP: Final = "hap"


@dataclass(frozen=True, slots=True)
class ScoredSlot:
    slot: HourSlot
    score: int
    reasons: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class FocusResult:
    picks: tuple[ScoredSlot, ...]
    fallback: bool
    evidence: tuple[Evidence, ...]


def _natal_branches(natal: FourPillars) -> tuple[Branch, ...]:
    """시간 모름이면 시지를 뺀다."""
    pillars = [natal.year, natal.month, natal.day]
    if natal.hour is not None:
        pillars.append(natal.hour)
    return tuple(pillar.branch for pillar in pillars)


def _clashes_with_natal(slot: HourSlot, natal: FourPillars) -> bool:
    return any(frozenset({slot.branch, branch}) in BRANCH_CHUNG for branch in _natal_branches(natal))


def score_slot(
    slot: HourSlot, natal: FourPillars, yongsin: YongsinResult, gwiin: frozenset[Branch]
) -> ScoredSlot:
    """귀인 +3, 용신 +2, 희신 +1, 원국과 육합 +1. 이유는 이 순서로 담는다."""
    slot_elements = {slot.pillar.stem.element, slot.pillar.branch.element}
    score = 0
    reasons: list[str] = []
    if slot.branch in gwiin:
        score += GWIIN_SCORE
        reasons.append(REASON_GWIIN)
    if yongsin.yongsin in slot_elements:
        score += YONGSIN_SCORE
        reasons.append(REASON_YONGSIN)
    if yongsin.huisin in slot_elements:
        score += HUISIN_SCORE
        reasons.append(REASON_HUISIN)
    if any(frozenset({slot.branch, branch}) in BRANCH_HAP for branch in _natal_branches(natal)):
        score += HAP_SCORE
        reasons.append(REASON_HAP)
    return ScoredSlot(slot=slot, score=score, reasons=tuple(reasons))


def _evidence(picks: tuple[ScoredSlot, ...], *, fallback: bool) -> Evidence:
    summary = ";".join(f"{pick.slot.branch.name}:{pick.score}:{'+'.join(pick.reasons)}" for pick in picks)
    return Evidence(
        rule_id="focus_time/fallback" if fallback else "focus_time/score",
        source_ref=FIVE_ELEMENTS_REF["balance_principle"],
        detail={"picks": summary},
    )


def pick_focus_times(
    slots: Sequence[HourSlot], natal: FourPillars, yongsin: YongsinResult, gwiin: frozenset[Branch]
) -> FocusResult:
    """점수 1등 시진 1개를 고르되, 2등이 같은 점수면 2개까지 낸다.

    모든 후보가 원국과 충이면 제외 전 후보 중 황도길시 첫 시진(없으면 첫 후보)을 fallback으로 낸다.
    """
    candidates = [
        score_slot(slot, natal, yongsin, gwiin) for slot in slots if slot.branch in CANDIDATE_BRANCHES
    ]
    if not candidates:
        raise ValueError("진시~술시 시진이 하나도 없습니다")

    allowed = [scored for scored in candidates if not _clashes_with_natal(scored.slot, natal)]
    if not allowed:
        first_lucky = next((scored for scored in candidates if scored.slot.huangdao_lucky), candidates[0])
        picks: tuple[ScoredSlot, ...] = (first_lucky,)
        return FocusResult(
            picks=picks, fallback=True, evidence=(_evidence(picks, fallback=True), *yongsin.evidence)
        )

    # sorted는 안정 정렬이므로 같은 키에서는 입력 순서(이른 시진)가 유지된다.
    ranked = sorted(allowed, key=lambda scored: (-scored.score, not scored.slot.huangdao_lucky))
    picks = (
        tuple(ranked[:MAX_PICKS]) if len(ranked) > 1 and ranked[1].score == ranked[0].score else (ranked[0],)
    )
    return FocusResult(
        picks=picks, fallback=False, evidence=(_evidence(picks, fallback=False), *yongsin.evidence)
    )
