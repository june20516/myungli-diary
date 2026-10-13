from myungli_engine.chart.positions import Position
from myungli_engine.chart.shinsal import ShinsalHit, activated, natal_shinsal, shinsal_branches
from myungli_engine.domain.enums import Branch as B
from myungli_engine.domain.enums import Shinsal
from myungli_engine.domain.enums import Stem as S
from myungli_engine.domain.models import FourPillars, Pillar


def pillars(year: Pillar, month: Pillar, day: Pillar, hour: Pillar | None) -> FourPillars:
    return FourPillars(year=year, month=month, day=day, hour=hour)


GAP_JA = Pillar(S.GAP, B.JA)


def test_natal_shinsal_dohwa() -> None:  # 일지 申, 연지 子 → 도화 酉. 시지 酉에 있다.
    chart = pillars(Pillar(S.GAP, B.JA), Pillar(S.BYEONG, B.IN), Pillar(S.GAP, B.SHIN), Pillar(S.SIN, B.YU))
    assert ShinsalHit(Shinsal.DOHWA, Position.HOUR_BRANCH) in natal_shinsal(chart)


def test_natal_shinsal_only_existing_positions() -> None:
    chart = pillars(Pillar(S.GAP, B.JA), Pillar(S.BYEONG, B.IN), Pillar(S.GAP, B.SHIN), None)
    hits = natal_shinsal(chart)
    assert not any(h.kind is Shinsal.DOHWA for h in hits)  # 酉 없음
    assert ShinsalHit(Shinsal.YEOKMA, Position.MONTH_BRANCH) in hits  # 子·申 → 寅


def test_yeokma_hwagae_and_yangin() -> None:
    chart = pillars(Pillar(S.GAP, B.SUL), Pillar(S.BYEONG, B.MYO), Pillar(S.GAP, B.SHIN), Pillar(S.GAP, B.JIN))
    hits = natal_shinsal(chart)
    assert ShinsalHit(Shinsal.HWAGAE, Position.HOUR_BRANCH) in hits  # 申子辰 → 辰
    assert ShinsalHit(Shinsal.HWAGAE, Position.YEAR_BRANCH) in hits  # 寅午戌 → 戌
    assert ShinsalHit(Shinsal.YANGIN, Position.MONTH_BRANCH) in hits  # 甲 → 卯


def test_yangin_only_for_yang_stem() -> None:
    chart = pillars(GAP_JA, GAP_JA, Pillar(S.EUL, B.MYO), None)
    assert shinsal_branches(chart)[Shinsal.YANGIN] == frozenset()
    assert not any(h.kind is Shinsal.YANGIN for h in natal_shinsal(chart))


def test_gongmang_hits_natal_branch() -> None:  # 甲子일 공망 = 戌·亥
    chart = pillars(Pillar(S.GAP, B.SUL), GAP_JA, GAP_JA, None)
    assert shinsal_branches(chart)[Shinsal.GONGMANG] == frozenset({B.SUL, B.HAE})
    assert ShinsalHit(Shinsal.GONGMANG, Position.YEAR_BRANCH) in natal_shinsal(chart)


def test_activated_cheoneul() -> None:
    chart = pillars(GAP_JA, GAP_JA, GAP_JA, None)
    assert Shinsal.CHEONEUL_GWIIN in activated(shinsal_branches(chart), B.MI)
    assert Shinsal.CHEONEUL_GWIIN not in activated(shinsal_branches(chart), B.IN)


def test_activated_multiple_kinds() -> None:  # 연지·일지 子 → 도화 酉
    chart = pillars(GAP_JA, GAP_JA, GAP_JA, None)
    assert Shinsal.DOHWA in activated(shinsal_branches(chart), B.YU)
