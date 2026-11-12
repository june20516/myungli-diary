"""신살 판정 (spec 5.4, D124). 원국 표시용 자리와 데일리 발동 판정용 지지 집합을 만든다."""

from __future__ import annotations

from collections.abc import Iterator, Mapping
from dataclasses import dataclass
from typing import Final

from myungli_engine.calendar_core.lunar_adapter import day_gongmang
from myungli_engine.chart.positions import BRANCH_POSITIONS, Position
from myungli_engine.constants import shinsal as table
from myungli_engine.constants.gwiin import CHEONEUL_GWIIN
from myungli_engine.domain.enums import Branch, Gender, Shinsal, Stem
from myungli_engine.domain.models import FourPillars, Pillar

# 연지·일지 각각을 기준으로 삼는 삼합 계열 신살
_GROUP_BASED_SHINSAL: dict[Shinsal, Mapping[Branch, Branch]] = {
    Shinsal.DOHWA: table.DOHWA,
    Shinsal.YEOKMA: table.YEOKMA,
    Shinsal.HWAGAE: table.HWAGAE,
}
# 오늘 일진 지지가 그 자리에 오면 발동하는 신살(오늘 태그). 고신, 과숙, 원진은 D124 ②.
DAILY_SHINSAL: Final = (
    Shinsal.CHEONEUL_GWIIN,
    Shinsal.DOHWA,
    Shinsal.YEOKMA,
    Shinsal.HWAGAE,
    Shinsal.YANGIN,
    Shinsal.GONGMANG,
    Shinsal.GOSIN,
    Shinsal.GWASUK,
    Shinsal.WONJIN,
)
STEM_POSITIONS: Final = (Position.YEAR_STEM, Position.MONTH_STEM, Position.DAY_STEM, Position.HOUR_STEM)
_DAY_PILLAR_POSITIONS: Final = (Position.DAY_STEM, Position.DAY_BRANCH)
# 삼기를 보는 세 천간 구간: 연월일, 월일시(「論三奇」 "天干年月日時順布", "太歲不帶而月日時帶者").
_SAMGI_WINDOWS: Final = (
    (Position.YEAR_STEM, Position.MONTH_STEM, Position.DAY_STEM),
    (Position.MONTH_STEM, Position.DAY_STEM, Position.HOUR_STEM),
)
_DAY_PILLAR_SHINSAL: Final[Mapping[Shinsal, frozenset[tuple[Stem, Branch]]]] = {
    Shinsal.GOEGANG: table.GOEGANG,
    Shinsal.SIPAK_DAEPAE: table.SIPAK_DAEPAE,
    Shinsal.EUMCHAK_YANGCHA: table.EUMCHAK_YANGCHA,
}


@dataclass(frozen=True, slots=True)
class ShinsalHit:
    """원국 신살 하나. positions는 신살이 걸친 자리 전부이고 position은 그 대표 자리다.

    한 글자 신살은 그 글자 자리 하나, 일주 신살은 일간과 일지(대표 일지), 삼기는 세 천간(대표 첫 자리)이다.
    """

    kind: Shinsal
    position: Position
    positions: tuple[Position, ...]


def shinsal_branches(pillars: FourPillars) -> Mapping[Shinsal, frozenset[Branch]]:
    """오늘 태그로 쓰는 신살마다 해당하는 지지 집합. 오늘 지지가 여기에 들면 발동이다 (D13, D124 ②)."""
    day_stem = pillars.day.stem
    year_branch = pillars.year.branch
    result: dict[Shinsal, frozenset[Branch]] = {
        Shinsal.CHEONEUL_GWIIN: CHEONEUL_GWIIN[day_stem],
        Shinsal.YANGIN: frozenset({table.YANGIN[day_stem]}) if day_stem in table.YANGIN else frozenset(),
        Shinsal.GONGMANG: day_gongmang(pillars.day),
        Shinsal.GOSIN: table.GOSIN[year_branch],
        Shinsal.GWASUK: table.GWASUK[year_branch],
        Shinsal.WONJIN: table.WONJIN[year_branch],
    }
    base_branches = (pillars.year.branch, pillars.day.branch)
    for kind, group_table in _GROUP_BASED_SHINSAL.items():
        result[kind] = frozenset(group_table[base] for base in base_branches)
    return {kind: result[kind] for kind in DAILY_SHINSAL}


def gugyo_branches(year_branch: Branch) -> frozenset[Branch]:
    """구교: 태어난 해 지지의 앞뒤 세 자리. 어느 칸이 勾이고 絞인지는 성별로 갈린다(personal 참고)."""
    branches = tuple(Branch)  # 子부터 亥까지, index와 같은 순서
    steps = (table.GUGYO_OFFSET, -table.GUGYO_OFFSET)
    return frozenset(branches[(year_branch.index + step) % len(branches)] for step in steps)


def gugyo_part(year: Pillar, branch: Branch, gender: Gender) -> str:
    """구교 자리 하나가 勾(GOU)인지 絞(JIAO)인지. 「論勾絞」 "陽男陰女命前三辰為勾命後三辰為絞陰男陽女命前三辰為絞命後三辰為勾".

    命은 태어난 해(연간의 음양과 연지)로 본다. 성별을 모르면 UNKNOWN.
    """
    if gender not in (Gender.MALE, Gender.FEMALE):
        return "UNKNOWN"
    branches = tuple(Branch)
    ahead = branches[(year.branch.index + table.GUGYO_OFFSET) % len(branches)] is branch
    yang_male_or_yin_female = year.stem.is_yang == (gender is Gender.MALE)
    return "GOU" if ahead == yang_male_or_yin_female else "JIAO"


def natal_shinsal(pillars: FourPillars) -> tuple[ShinsalHit, ...]:
    """원국 안에 실제로 있는 신살과 그 자리. 시주가 없으면 시주 자리는 보지 않는다.

    순서는 Shinsal 선언 순서, 같은 신살 안은 자리 순서다.
    """
    hits = [*_base_hits(pillars), *_d124_hits(pillars)]
    order = {kind: index for index, kind in enumerate(Shinsal)}
    return tuple(sorted(hits, key=lambda hit: order[hit.kind]))


def activated(branches: Mapping[Shinsal, frozenset[Branch]], today: Branch) -> tuple[Shinsal, ...]:
    return tuple(kind for kind, targets in branches.items() if today in targets)


def _base_hits(pillars: FourPillars) -> Iterator[ShinsalHit]:
    """지금 6개(D124 이전). 기준 자리를 빼지 않고 원국 네 지지를 모두 본다."""
    daily = shinsal_branches(pillars)
    for kind in (
        Shinsal.CHEONEUL_GWIIN,
        Shinsal.DOHWA,
        Shinsal.YEOKMA,
        Shinsal.HWAGAE,
        Shinsal.YANGIN,
        Shinsal.GONGMANG,
    ):
        yield from _branch_hits(pillars, kind, daily[kind], BRANCH_POSITIONS)


def _d124_hits(pillars: FourPillars) -> Iterator[ShinsalHit]:
    year_stem, year_branch, month_branch = pillars.year.stem, pillars.year.branch, pillars.month.branch
    not_year = tuple(position for position in BRANCH_POSITIONS if position is not Position.YEAR_BRANCH)
    not_month = tuple(position for position in BRANCH_POSITIONS if position is not Position.MONTH_BRANCH)

    cheondeok = table.CHEONDEOK[month_branch]
    if isinstance(cheondeok, Stem):
        yield from _stem_hits(pillars, Shinsal.CHEONDEOK, cheondeok)
    else:
        yield from _branch_hits(pillars, Shinsal.CHEONDEOK, frozenset({cheondeok}), not_month)
    yield from _stem_hits(pillars, Shinsal.WOLDEOK, table.WOLDEOK[month_branch])
    yield from _branch_hits(pillars, Shinsal.GEUMYEO, frozenset({table.GEUMYEO[year_stem]}), BRANCH_POSITIONS)
    for kind, targets in (
        (Shinsal.GOSIN, table.GOSIN[year_branch]),
        (Shinsal.GWASUK, table.GWASUK[year_branch]),
        (Shinsal.WONJIN, table.WONJIN[year_branch]),
        (Shinsal.GUGYO, gugyo_branches(year_branch)),
        (Shinsal.CHEONRA_JIMANG, table.CHEONRA_JIMANG.get(year_branch, frozenset())),
    ):
        yield from _branch_hits(pillars, kind, targets, not_year)
    day = (pillars.day.stem, pillars.day.branch)
    for kind, members in _DAY_PILLAR_SHINSAL.items():
        if day in members:
            yield ShinsalHit(kind, Position.DAY_BRANCH, _DAY_PILLAR_POSITIONS)
    yield from _samgi_hits(pillars)
    yield from _branch_hits(pillars, Shinsal.AMROK, frozenset({table.AMROK[year_stem]}), BRANCH_POSITIONS)


def _branch_hits(
    pillars: FourPillars, kind: Shinsal, targets: frozenset[Branch], positions: tuple[Position, ...]
) -> Iterator[ShinsalHit]:
    for position in positions:
        pillar = pillar_at(pillars, position)
        if pillar is not None and pillar.branch in targets:
            yield ShinsalHit(kind, position, (position,))


def _stem_hits(pillars: FourPillars, kind: Shinsal, target: Stem) -> Iterator[ShinsalHit]:
    for position in STEM_POSITIONS:
        pillar = pillar_at(pillars, position)
        if pillar is not None and pillar.stem is target:
            yield ShinsalHit(kind, position, (position,))


def _samgi_hits(pillars: FourPillars) -> Iterator[ShinsalHit]:
    for window in _SAMGI_WINDOWS:
        found = [pillar_at(pillars, position) for position in window]
        stems = tuple(pillar.stem for pillar in found if pillar is not None)
        if stems in table.SAMGI:
            yield ShinsalHit(Shinsal.SAMGI, window[0], window)


def pillar_at(pillars: FourPillars, position: Position) -> Pillar | None:
    """자리가 속한 기둥. 시주가 없으면 시 자리는 None."""
    by_position = {
        Position.YEAR_STEM: pillars.year,
        Position.YEAR_BRANCH: pillars.year,
        Position.MONTH_STEM: pillars.month,
        Position.MONTH_BRANCH: pillars.month,
        Position.DAY_STEM: pillars.day,
        Position.DAY_BRANCH: pillars.day,
        Position.HOUR_STEM: pillars.hour,
        Position.HOUR_BRANCH: pillars.hour,
    }
    return by_position[position]
