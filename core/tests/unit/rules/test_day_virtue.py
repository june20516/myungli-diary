from datetime import date, timedelta

from myungli_engine.calendar_core import lunar_adapter
from myungli_engine.domain.enums import Branch as B
from myungli_engine.domain.enums import DayVirtue
from myungli_engine.domain.enums import Stem as S
from myungli_engine.domain.models import Pillar
from myungli_engine.references.loader import resolve
from myungli_engine.rules.day_virtue import day_virtue_judgment, day_virtues


def test_cheondeok_and_woldeok_by_month() -> None:
    assert day_virtues(B.IN, Pillar(S.JEONG, B.MYO)) == (DayVirtue.CHEONDEOK_DAY,)  # 正月丁
    assert day_virtues(B.IN, Pillar(S.BYEONG, B.IN)) == (DayVirtue.WOLDEOK_DAY,)  # 正五九月在丙
    assert day_virtues(B.IN, Pillar(S.GAP, B.JA)) == ()


def test_both_on_same_day_cheondeok_first() -> None:
    assert day_virtues(B.CHUK, Pillar(S.GYEONG, B.JIN)) == (DayVirtue.CHEONDEOK_DAY, DayVirtue.WOLDEOK_DAY)


def test_no_cheondeok_day_in_trigram_months() -> None:
    """子午卯酉月의 천덕은 괘(坤乾艮巽)라 날이 없다. 지지로 바꿔 읽지 않는다(D124 ⑤)."""
    for month in (B.JA, B.O, B.MYO, B.YU):
        for stem in S:
            for branch in (B.SHIN, B.HAE, B.IN, B.SA):
                assert DayVirtue.CHEONDEOK_DAY not in day_virtues(month, Pillar(stem, branch))


def test_judgment_cites_xieji_volume_five() -> None:
    judgment = day_virtue_judgment(DayVirtue.WOLDEOK_DAY, B.IN, Pillar(S.BYEONG, B.IN))
    assert judgment.message_key == "day_virtue.woldeok"
    assert judgment.params == {"month_branch": "IN", "day_stem": "BYEONG"}
    evidence = judgment.evidence[0]
    assert (evidence.rule_id, evidence.source_ref) == ("day_virtue/woldeok", "xieji-bianfang/days#yuede")
    resolve(evidence.source_ref)


def test_about_one_in_eight_days_in_2026() -> None:
    """조사 측정(2026년 47일, 12.9%)과 같은지 본다. 달은 그 날짜 정오의 월건."""
    days = [date(2026, 1, 1) + timedelta(days=offset) for offset in range(365)]
    found = [day for day in days if day_virtues(lunar_adapter.day_month_branch(day), lunar_adapter.day_pillar(day))]
    assert len(found) == 47
