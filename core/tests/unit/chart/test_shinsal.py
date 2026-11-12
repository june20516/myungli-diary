from myungli_engine.chart.positions import Position
from myungli_engine.chart.shinsal import (
    DAILY_SHINSAL,
    ShinsalHit,
    activated,
    gugyo_part,
    natal_shinsal,
    shinsal_branches,
)
from myungli_engine.domain.enums import Branch as B
from myungli_engine.domain.enums import Gender, Shinsal
from myungli_engine.domain.enums import Stem as S
from myungli_engine.domain.models import FourPillars, Pillar


def pillars(year: Pillar, month: Pillar, day: Pillar, hour: Pillar | None) -> FourPillars:
    return FourPillars(year=year, month=month, day=day, hour=hour)


GAP_JA = Pillar(S.GAP, B.JA)


def hit(kind: Shinsal, position: Position) -> ShinsalHit:
    """한 글자 신살: 걸친 자리가 대표 자리 하나다."""
    return ShinsalHit(kind, position, (position,))


def test_natal_shinsal_dohwa() -> None:  # 일지 申, 연지 子 → 도화 酉. 시지 酉에 있다.
    chart = pillars(Pillar(S.GAP, B.JA), Pillar(S.BYEONG, B.IN), Pillar(S.GAP, B.SHIN), Pillar(S.SIN, B.YU))
    assert hit(Shinsal.DOHWA, Position.HOUR_BRANCH) in natal_shinsal(chart)


def test_natal_shinsal_only_existing_positions() -> None:
    chart = pillars(Pillar(S.GAP, B.JA), Pillar(S.BYEONG, B.IN), Pillar(S.GAP, B.SHIN), None)
    hits = natal_shinsal(chart)
    assert not any(h.kind is Shinsal.DOHWA for h in hits)  # 酉 없음
    assert hit(Shinsal.YEOKMA, Position.MONTH_BRANCH) in hits  # 子·申 → 寅


def test_yeokma_hwagae_and_yangin() -> None:
    chart = pillars(Pillar(S.GAP, B.SUL), Pillar(S.BYEONG, B.MYO), Pillar(S.GAP, B.SHIN), Pillar(S.GAP, B.JIN))
    hits = natal_shinsal(chart)
    assert hit(Shinsal.HWAGAE, Position.HOUR_BRANCH) in hits  # 申子辰 → 辰
    assert hit(Shinsal.HWAGAE, Position.YEAR_BRANCH) in hits  # 寅午戌 → 戌
    assert hit(Shinsal.YANGIN, Position.MONTH_BRANCH) in hits  # 甲 → 卯


def test_yangin_only_for_yang_stem() -> None:
    chart = pillars(GAP_JA, GAP_JA, Pillar(S.EUL, B.MYO), None)
    assert shinsal_branches(chart)[Shinsal.YANGIN] == frozenset()
    assert not any(h.kind is Shinsal.YANGIN for h in natal_shinsal(chart))


def test_gongmang_hits_natal_branch() -> None:  # 甲子일 공망 = 戌·亥
    chart = pillars(Pillar(S.GAP, B.SUL), GAP_JA, GAP_JA, None)
    assert shinsal_branches(chart)[Shinsal.GONGMANG] == frozenset({B.SUL, B.HAE})
    assert hit(Shinsal.GONGMANG, Position.YEAR_BRANCH) in natal_shinsal(chart)


def test_activated_cheoneul() -> None:
    chart = pillars(GAP_JA, GAP_JA, GAP_JA, None)
    assert Shinsal.CHEONEUL_GWIIN in activated(shinsal_branches(chart), B.MI)
    assert Shinsal.CHEONEUL_GWIIN not in activated(shinsal_branches(chart), B.IN)


def test_activated_multiple_kinds() -> None:  # 연지·일지 子 → 도화 酉
    chart = pillars(GAP_JA, GAP_JA, GAP_JA, None)
    assert Shinsal.DOHWA in activated(shinsal_branches(chart), B.YU)


# --- D124 (#1028) ---


def test_cheondeok_stem_and_trigram_branch() -> None:
    # 寅월 천덕 丁(시간), 卯월 천덕 坤 = 申(일지)
    by_stem = pillars(GAP_JA, Pillar(S.BYEONG, B.IN), GAP_JA, Pillar(S.JEONG, B.MYO))
    assert hit(Shinsal.CHEONDEOK, Position.HOUR_STEM) in natal_shinsal(by_stem)
    by_branch = pillars(GAP_JA, Pillar(S.JEONG, B.MYO), Pillar(S.GAP, B.SHIN), None)
    assert hit(Shinsal.CHEONDEOK, Position.DAY_BRANCH) in natal_shinsal(by_branch)


def test_woldeok_geumyeo_amrok_from_year_stem() -> None:
    # 午월 월덕 丙(연간). 연간 甲: 금여 辰(일지), 암록 亥(시지)
    chart = pillars(Pillar(S.GAP, B.JA), Pillar(S.BYEONG, B.O), Pillar(S.GYEONG, B.JIN), Pillar(S.EUL, B.HAE))
    hits = natal_shinsal(chart)
    assert hit(Shinsal.WOLDEOK, Position.MONTH_STEM) in hits
    assert hit(Shinsal.GEUMYEO, Position.DAY_BRANCH) in hits
    assert hit(Shinsal.AMROK, Position.HOUR_BRANCH) in hits


def test_year_branch_based_shinsal() -> None:
    # 연지 子: 고신 寅, 과숙 戌, 원진 未, 구교 卯와 酉
    chart = pillars(GAP_JA, Pillar(S.BYEONG, B.IN), Pillar(S.GAP, B.SUL), Pillar(S.SIN, B.MI))
    hits = natal_shinsal(chart)
    assert hit(Shinsal.GOSIN, Position.MONTH_BRANCH) in hits
    assert hit(Shinsal.GWASUK, Position.DAY_BRANCH) in hits
    assert hit(Shinsal.WONJIN, Position.HOUR_BRANCH) in hits
    gugyo = pillars(GAP_JA, Pillar(S.JEONG, B.MYO), Pillar(S.GYE, B.YU), None)
    assert [h.position for h in natal_shinsal(gugyo) if h.kind is Shinsal.GUGYO] == [
        Position.MONTH_BRANCH,
        Position.DAY_BRANCH,
    ]


def test_cheonra_jimang_needs_partner_branch() -> None:
    assert hit(Shinsal.CHEONRA_JIMANG, Position.HOUR_BRANCH) in natal_shinsal(
        pillars(Pillar(S.GAP, B.SUL), GAP_JA, GAP_JA, Pillar(S.EUL, B.HAE))
    )
    assert not any(h.kind is Shinsal.CHEONRA_JIMANG for h in natal_shinsal(pillars(GAP_JA, GAP_JA, GAP_JA, None)))


def test_day_pillar_shinsal_span_day_stem_and_branch() -> None:
    goegang = natal_shinsal(pillars(GAP_JA, GAP_JA, Pillar(S.GYEONG, B.JIN), None))
    span = (Position.DAY_STEM, Position.DAY_BRANCH)
    assert ShinsalHit(Shinsal.GOEGANG, Position.DAY_BRANCH, span) in goegang
    assert ShinsalHit(Shinsal.SIPAK_DAEPAE, Position.DAY_BRANCH, span) in goegang  # 庚辰은 둘 다
    yangcha = natal_shinsal(pillars(GAP_JA, GAP_JA, Pillar(S.BYEONG, B.JA), None))
    assert ShinsalHit(Shinsal.EUMCHAK_YANGCHA, Position.DAY_BRANCH, span) in yangcha


def test_samgi_in_order_only() -> None:
    year_month_day = (Position.YEAR_STEM, Position.MONTH_STEM, Position.DAY_STEM)
    ordered = pillars(Pillar(S.EUL, B.CHUK), Pillar(S.BYEONG, B.IN), Pillar(S.JEONG, B.MYO), None)
    assert ShinsalHit(Shinsal.SAMGI, Position.YEAR_STEM, year_month_day) in natal_shinsal(ordered)
    month_day_hour = pillars(GAP_JA, Pillar(S.GAP, B.SUL), Pillar(S.MU, B.JA), Pillar(S.GYEONG, B.SHIN))
    assert ShinsalHit(
        Shinsal.SAMGI, Position.MONTH_STEM, (Position.MONTH_STEM, Position.DAY_STEM, Position.HOUR_STEM)
    ) in natal_shinsal(month_day_hour)
    reversed_order = pillars(Pillar(S.JEONG, B.MYO), Pillar(S.BYEONG, B.IN), Pillar(S.EUL, B.CHUK), None)
    assert not any(h.kind is Shinsal.SAMGI for h in natal_shinsal(reversed_order))
    no_source = pillars(Pillar(S.SIN, B.MYO), Pillar(S.IM, B.IN), Pillar(S.GYE, B.CHUK), None)  # 辛壬癸는 넣지 않음
    assert not any(h.kind is Shinsal.SAMGI for h in natal_shinsal(no_source))


def test_daily_shinsal_are_nine_with_gosin_gwasuk_wonjin() -> None:
    chart = pillars(GAP_JA, GAP_JA, GAP_JA, None)
    branches = shinsal_branches(chart)
    assert tuple(branches) == DAILY_SHINSAL
    assert Shinsal.CHEONDEOK not in branches
    assert Shinsal.GOSIN in activated(branches, B.IN)  # 子년 고신 寅(역마도 寅)
    assert Shinsal.WONJIN in activated(branches, B.MI)


def test_gugyo_part_follows_original_examples() -> None:
    """「論勾絞」 "甲子陽命人卯為勾酉為絞乙丑陰命人辰為絞戌為勾"."""
    gap_ja, eul_chuk = Pillar(S.GAP, B.JA), Pillar(S.EUL, B.CHUK)
    assert (gugyo_part(gap_ja, B.MYO, Gender.MALE), gugyo_part(gap_ja, B.YU, Gender.MALE)) == ("GOU", "JIAO")
    assert (gugyo_part(eul_chuk, B.JIN, Gender.MALE), gugyo_part(eul_chuk, B.SUL, Gender.MALE)) == ("JIAO", "GOU")
    assert gugyo_part(gap_ja, B.MYO, Gender.FEMALE) == "JIAO"  # 陽女는 陰男과 같다
    assert gugyo_part(gap_ja, B.MYO, None) == "UNKNOWN"
