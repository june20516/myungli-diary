from collections.abc import Callable
from dataclasses import replace
from datetime import date, datetime, timedelta, timezone

from myungli_engine.calendar_core import lunar_adapter as la
from myungli_engine.calendar_core.lunar_adapter import HourSlot
from myungli_engine.domain.enums import Branch
from myungli_engine.domain.models import Evidence, FourPillars, Pillar
from myungli_engine.references import loader
from myungli_engine.references.loader import FIVE_ELEMENTS_REF
from myungli_engine.rules.focus_time import pick_focus_times, score_slot
from myungli_engine.rules.yongsin import YongsinResult

PillarOf = Callable[[str], Pillar]
CANDIDATE_BRANCHES = {Branch.JIN, Branch.SA, Branch.O, Branch.MI, Branch.SHIN, Branch.YU, Branch.SUL}
SEOUL = timezone(timedelta(hours=9))


def make_slot(pillar_of: PillarOf, ganzhi: str, *, lucky: bool = False) -> HourSlot:
    pillar = pillar_of(ganzhi)
    start = datetime(2026, 10, 10, pillar.branch.index * 2 - 1 if pillar.branch.index else 0, tzinfo=SEOUL)
    return HourSlot(
        branch=pillar.branch, pillar=pillar, start=start, end=start + timedelta(hours=2), huangdao_lucky=lucky
    )


def make_natal(pillar_of: PillarOf, ganzhi: str, hour: str | None = None) -> FourPillars:
    """네 기둥의 지지가 모두 같은 원국. 일지만 바꿔 충·합을 확인하기 위해 쓴다."""
    return FourPillars(
        year=pillar_of(ganzhi),
        month=pillar_of(ganzhi),
        day=pillar_of(ganzhi),
        hour=pillar_of(hour) if hour else None,
    )


def test_candidates_are_jin_to_sul(
    winter_gap: YongsinResult, gwiin_branches: frozenset[Branch], pillar_of: PillarOf
) -> None:
    slots = la.hour_slots(date(2026, 10, 10), "Asia/Seoul")
    result = pick_focus_times(slots, make_natal(pillar_of, "甲寅"), winter_gap, gwiin_branches)
    assert result.picks
    assert all(pick.slot.branch in CANDIDATE_BRANCHES for pick in result.picks)


def test_chung_with_natal_excluded(winter_gap: YongsinResult, pillar_of: PillarOf) -> None:
    slots = la.hour_slots(date(2026, 10, 10), "Asia/Seoul")
    gwiin = frozenset({Branch.O})
    without_chung = pick_focus_times(slots, make_natal(pillar_of, "甲辰"), winter_gap, gwiin)
    assert without_chung.picks[0].slot.branch is Branch.O

    with_chung = pick_focus_times(slots, make_natal(pillar_of, "甲子"), winter_gap, gwiin)
    assert not with_chung.fallback
    assert all(pick.slot.branch is not Branch.O for pick in with_chung.picks)


def test_scores(winter_gap: YongsinResult, gwiin_branches: frozenset[Branch], pillar_of: PillarOf) -> None:
    natal = make_natal(pillar_of, "甲辰")
    # 未: 귀인 +3, 乙(목)은 희신 +1
    gwiin_slot = score_slot(make_slot(pillar_of, "乙未"), natal, winter_gap, gwiin_branches)
    assert (gwiin_slot.score, gwiin_slot.reasons) == (4, ("gwiin", "huisin"))
    # 午: 지지 화가 용신 +2 (천간 丙도 화지만 한 번만), 천간 乙 희신 +1
    both = score_slot(make_slot(pillar_of, "乙午"), natal, winter_gap, gwiin_branches)
    assert (both.score, both.reasons) == (3, ("yongsin", "huisin"))
    only_yongsin = score_slot(make_slot(pillar_of, "丙午"), natal, winter_gap, gwiin_branches)
    assert (only_yongsin.score, only_yongsin.reasons) == (2, ("yongsin",))
    # 酉: 원국 辰과 육합 +1 (庚·酉는 모두 금이라 용신·희신 아님)
    hap = score_slot(make_slot(pillar_of, "庚酉"), natal, winter_gap, gwiin_branches)
    assert (hap.score, hap.reasons) == (1, ("hap",))
    none = score_slot(make_slot(pillar_of, "戊戌"), natal, winter_gap, gwiin_branches)
    assert (none.score, none.reasons) == (0, ())


def test_tie_prefers_huangdao_then_earlier(winter_gap: YongsinResult, pillar_of: PillarOf) -> None:
    natal = make_natal(pillar_of, "壬子")
    slots = [
        make_slot(pillar_of, "戊辰", lucky=False),
        make_slot(pillar_of, "庚申", lucky=True),
        make_slot(pillar_of, "辛酉", lucky=True),
    ]
    result = pick_focus_times(slots, natal, winter_gap, frozenset())
    assert [pick.slot.branch for pick in result.picks] == [Branch.SHIN, Branch.YU]


def test_second_pick_only_on_equal_score(winter_gap: YongsinResult, pillar_of: PillarOf) -> None:
    natal = make_natal(pillar_of, "壬子")
    gwiin = frozenset({Branch.MI})
    higher_first = [make_slot(pillar_of, "己未"), make_slot(pillar_of, "戊辰")]
    assert len(pick_focus_times(higher_first, natal, winter_gap, gwiin).picks) == 1

    equal = [make_slot(pillar_of, "戊辰"), make_slot(pillar_of, "庚申"), make_slot(pillar_of, "辛酉")]
    assert len(pick_focus_times(equal, natal, winter_gap, frozenset()).picks) == 2


def test_all_excluded_fallback(winter_gap: YongsinResult, pillar_of: PillarOf) -> None:
    natal = FourPillars(pillar_of("甲子"), pillar_of("甲丑"), pillar_of("甲子"), None)
    slots = [
        make_slot(pillar_of, "甲子", lucky=True),  # 후보 밖이면 fallback 대상도 아니다
        make_slot(pillar_of, "丙午", lucky=False),
        make_slot(pillar_of, "己未", lucky=True),
    ]
    result = pick_focus_times(slots, natal, winter_gap, frozenset())
    assert result.fallback is True
    assert [pick.slot.branch for pick in result.picks] == [Branch.MI]
    assert result.picks[0].score == 0  # 점수는 계산값 그대로
    assert result.evidence[0].rule_id == "focus_time/fallback"

    no_lucky = [replace(slot, huangdao_lucky=False) for slot in slots]
    assert pick_focus_times(no_lucky, natal, winter_gap, frozenset()).picks[0].slot.branch is Branch.O


def test_time_unknown_ignores_hour_branch(winter_gap: YongsinResult, pillar_of: PillarOf) -> None:
    slots = [make_slot(pillar_of, "丙午", lucky=True)]
    with_hour = make_natal(pillar_of, "甲辰", hour="甲子")
    result = pick_focus_times(slots, with_hour, winter_gap, frozenset())
    assert result.fallback is True  # 시지 子와 午가 충

    time_unknown = replace(with_hour, hour=None)
    result = pick_focus_times(slots, time_unknown, winter_gap, frozenset())
    assert result.fallback is False
    assert result.picks[0].slot.branch is Branch.O


def test_evidence_includes_yongsin_evidence(winter_gap: YongsinResult, pillar_of: PillarOf) -> None:
    yongsin_evidence = Evidence(rule_id="yongsin/johu", source_ref=FIVE_ELEMENTS_REF["balance_principle"])
    yongsin = replace(winter_gap, evidence=(yongsin_evidence,))
    result = pick_focus_times(
        [make_slot(pillar_of, "丙午")], make_natal(pillar_of, "甲辰"), yongsin, frozenset()
    )
    assert result.evidence[0].rule_id == "focus_time/score"
    assert result.evidence[0].source_ref == FIVE_ELEMENTS_REF["balance_principle"]
    assert "O" in result.evidence[0].detail["picks"]
    assert yongsin_evidence in result.evidence
    loader.validate_refs(e.source_ref for e in result.evidence)
