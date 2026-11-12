"""집중하기 좋은 시간 (spec 7.5, D122). 시진을 원문 등급으로 줄 세워 낮과 밤 각각 1등을 고른다.

날짜 d의 낮은 d 일진의 진시~술시, 밤은 d 일진의 해시와 d+1 일진의 자시~묘시(d 저녁부터 d+1 아침까지,
#1008)다. 시진마다 자기 날의 일진으로 판정한다.

원전은 『欽定協紀辨方書』 卷三十四 「用時法」(그날 일진을 돕는 시), 卷三十三 「論相主」(태어난 해 기준),
卷七 「黄道黒道」(동점)이다. 등급 사이 순서와 길끼리 같은 무게는 원문이 정하지 않아 명리일기가 정했다
(규칙 지도, core C36). 가중치 점수는 쓰지 않는다.

1. 時破(시지가 일지와 충, 大凶)는 뺀다.
2. 次凶(時刑, 五不遇)이 없는 시가 앞선다.
3. 길이 많은 시가 앞선다. 그날 기준: 建, 일지와 삼합, 육합, 일간의 귀인, 녹, 일지의 역마.
   태어난 해 기준: 연간과 천간합(合官, 合財), 比肩, 正印(印綬), 연간의 長生, 녹, 귀인, 연지의 역마.
4. 가벼운 흉(衝命: 연지와 충, 尅命: 시간이 연간의 七殺)이 적은 시가 앞선다.
5. 황도길시가 앞선다.
6. 그래도 같으면 이른 시진. 낮은 진시부터, 밤은 해시부터 센다.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from enum import Enum, auto
from typing import Final

from myungli_engine.calendar_core.lunar_adapter import HourSlot, twelve_stage
from myungli_engine.constants.gwiin import CHEONEUL_GWIIN
from myungli_engine.constants.relations import (
    BRANCH_CHUNG,
    BRANCH_HAP,
    BRANCH_HYEONG_GROUPS,
    BRANCH_HYEONG_PAIRS,
    SELF_HYEONG,
    STEM_HAP,
)
from myungli_engine.constants.shinsal import YEOKMA
from myungli_engine.domain.elements import controls, generates
from myungli_engine.domain.enums import Branch, Stem, TenGod, TwelveStage
from myungli_engine.domain.models import Pillar
from myungli_engine.domain.ten_gods import ten_god


class FocusPeriod(Enum):
    DAY = auto()  # d 진시~술시 (D21 ① 활동 시간대)
    NIGHT = auto()  # d 해시 + d+1 자시~묘시 (#1008)


# 마지막 동점은 이 순서로 이른 시진이 앞선다(D122).
PERIOD_BRANCHES: Final[dict[FocusPeriod, tuple[Branch, ...]]] = {
    FocusPeriod.DAY: (Branch.JIN, Branch.SA, Branch.O, Branch.MI, Branch.SHIN, Branch.YU, Branch.SUL),
    FocusPeriod.NIGHT: (Branch.HAE, Branch.JA, Branch.CHUK, Branch.IN, Branch.MYO),
}
# 밤 가운데 다음 날(d+1) 일진에 속하는 시진. 해시만 그날(d) 일진이다.
NEXT_DAY_NIGHT_BRANCHES: Final = frozenset({Branch.JA, Branch.CHUK, Branch.IN, Branch.MYO})


@dataclass(frozen=True, slots=True)
class DayHours:
    """하루 일진과 그날의 12시진."""

    date: date
    pillar: Pillar
    slots: tuple[HourSlot, ...]

# 녹(祿): 천간이 臨官하는 지지.
ROK: Final[dict[Stem, Branch]] = {
    Stem.GAP: Branch.IN,
    Stem.EUL: Branch.MYO,
    Stem.BYEONG: Branch.SA,
    Stem.JEONG: Branch.O,
    Stem.MU: Branch.SA,
    Stem.GI: Branch.O,
    Stem.GYEONG: Branch.SHIN,
    Stem.SIN: Branch.YU,
    Stem.IM: Branch.HAE,
    Stem.GYE: Branch.JA,
}
_SAMHAP: Final = (
    frozenset({Branch.SHIN, Branch.JA, Branch.JIN}),
    frozenset({Branch.IN, Branch.O, Branch.SUL}),
    frozenset({Branch.SA, Branch.YU, Branch.CHUK}),
    frozenset({Branch.HAE, Branch.MYO, Branch.MI}),
)


@dataclass(frozen=True, slots=True)
class HourGrade:
    """시진 하나의 등급. 키가 작을수록 앞선다."""

    slot: HourSlot
    day_date: date  # 이 시진이 속한 일진의 날짜
    day: Pillar  # 이 시진을 판정한 일진
    day_goods: tuple[str, ...]  # 그날 기준 길: build, samhap, yukhap, gwiin, rok, ma
    year_goods: tuple[str, ...]  # 태어난 해 기준 길: stem_hap, bigyeon, jeongin, jangsaeng, rok, gwiin, ma
    second_bads: tuple[str, ...]  # 次凶: hyeong, obulu
    light_bads: tuple[str, ...]  # 가벼운 흉: chung_myeong, geuk_myeong

    def key(self, order: tuple[Branch, ...]) -> tuple[bool, int, int, bool, int]:
        return (
            bool(self.second_bads),
            -(len(self.day_goods) + len(self.year_goods)),
            len(self.light_bads),
            not self.slot.huangdao_lucky,
            order.index(self.slot.branch),
        )


@dataclass(frozen=True, slots=True)
class PeriodHour:
    """구간 안의 시진 하나와 그 시진이 속한 일진(#1078). 時破로 후보에서 빠진 시진도 들어 있다."""

    slot: HourSlot
    day_date: date
    day: Pillar


@dataclass(frozen=True, slots=True)
class FocusPick:
    period: FocusPeriod
    grade: HourGrade
    # 이 구간의 시진 전부, 시간 순. 밤 칩 전환 시각과 24시간 띠가 쓴다(#1078).
    hours: tuple[PeriodHour, ...]


def _pair(first: Branch, second: Branch) -> frozenset[Branch]:
    return frozenset({first, second})


def _hyeong(day_branch: Branch, hour_branch: Branch) -> bool:
    if day_branch is hour_branch:
        return day_branch in SELF_HYEONG
    pair = _pair(day_branch, hour_branch)
    return pair in BRANCH_HYEONG_PAIRS or any(pair <= group for group in BRANCH_HYEONG_GROUPS)


def _samhap(day_branch: Branch, hour_branch: Branch) -> bool:
    return day_branch is not hour_branch and any(_pair(day_branch, hour_branch) <= group for group in _SAMHAP)


def _obulu(day: Pillar, hour: Pillar) -> bool:
    """五不遇: 시간이 일간을 극한다. 시지가 일간이나 일지를 생하면 五不遇가 아니다(卷七 按語).

    시지는 정기 오행으로 본다(지장간을 보지 않는 것은 명리일기 해석).
    """
    if controls(hour.stem.element) is not day.stem.element:
        return False
    return generates(hour.branch.element) not in (day.stem.element, day.branch.element)


def grade_hour(slot: HourSlot, day: Pillar, birth_year: Pillar, day_date: date) -> HourGrade | None:
    """時破면 None(후보에서 뺌). day는 이 시진이 속한 날의 일진이다."""
    hour = slot.pillar
    if _pair(day.branch, hour.branch) in BRANCH_CHUNG:
        return None
    day_goods = (
        ("build", hour.branch is day.branch),
        ("samhap", _samhap(day.branch, hour.branch)),
        ("yukhap", _pair(day.branch, hour.branch) in BRANCH_HAP),
        ("gwiin", hour.branch in CHEONEUL_GWIIN[day.stem]),
        ("rok", hour.branch is ROK[day.stem]),
        ("ma", hour.branch is YEOKMA[day.branch]),
    )
    god = ten_god(birth_year.stem, hour.stem)
    year_goods = (
        ("stem_hap", frozenset({birth_year.stem, hour.stem}) in STEM_HAP),
        ("bigyeon", god is TenGod.BIGYEON),
        ("jeongin", god is TenGod.JEONGIN),
        ("jangsaeng", twelve_stage(birth_year.stem, hour.branch) is TwelveStage.JANGSAENG),
        ("rok", hour.branch is ROK[birth_year.stem]),
        ("gwiin", hour.branch in CHEONEUL_GWIIN[birth_year.stem]),
        ("ma", hour.branch is YEOKMA[birth_year.branch]),
    )
    second_bads = (("hyeong", _hyeong(day.branch, hour.branch)), ("obulu", _obulu(day, hour)))
    light_bads = (
        ("chung_myeong", _pair(birth_year.branch, hour.branch) in BRANCH_CHUNG),
        ("geuk_myeong", god is TenGod.PYEONGWAN),
    )
    return HourGrade(
        slot=slot,
        day_date=day_date,
        day=day,
        day_goods=tuple(name for name, hit in day_goods if hit),
        year_goods=tuple(name for name, hit in year_goods if hit),
        second_bads=tuple(name for name, hit in second_bads if hit),
        light_bads=tuple(name for name, hit in light_bads if hit),
    )


def _candidates(period: FocusPeriod, today: DayHours, tomorrow: DayHours) -> list[tuple[HourSlot, DayHours]]:
    order = PERIOD_BRANCHES[period]
    if period is FocusPeriod.DAY:
        return [(slot, today) for slot in today.slots if slot.branch in order]
    tonight = [(slot, today) for slot in today.slots if slot.branch is Branch.HAE]
    return tonight + [(slot, tomorrow) for slot in tomorrow.slots if slot.branch in NEXT_DAY_NIGHT_BRANCHES]


def pick_focus_times(today: DayHours, tomorrow: DayHours, birth_year: Pillar) -> tuple[FocusPick, ...]:
    """(낮 1등, 밤 1등). tomorrow는 today 다음 날이다. 時破는 날마다 시진 하나만 빼므로 두 구간 모두 후보가 남는다."""
    picks: list[FocusPick] = []
    for period, order in PERIOD_BRANCHES.items():
        period_hours = tuple(
            sorted(
                (PeriodHour(slot, hours.date, hours.pillar) for slot, hours in _candidates(period, today, tomorrow)),
                key=lambda hour: hour.slot.start,
            )
        )
        grades = [grade_hour(hour.slot, hour.day, birth_year, hour.day_date) for hour in period_hours]
        candidates = [grade for grade in grades if grade is not None]
        if not candidates:
            raise ValueError(f"{period.name} 시진 후보가 없습니다")
        best = min(candidates, key=lambda grade: grade.key(order))
        picks.append(FocusPick(period, best, period_hours))
    return tuple(picks)
