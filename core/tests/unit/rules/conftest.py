from collections.abc import Callable
from datetime import date

import pytest

from myungli_engine.calendar_core import lunar_adapter as la
from myungli_engine.domain.enums import Branch, Direction8, Element, Stem, YongsinMethod
from myungli_engine.domain.models import Pillar
from myungli_engine.rules.yongsin import YongsinResult


def pillar_of(ganzhi: str) -> Pillar:
    return Pillar(Stem.from_hanja(ganzhi[0]), Branch.from_hanja(ganzhi[1]))


@pytest.fixture(name="pillar_of")
def pillar_of_fixture() -> Callable[[str], Pillar]:
    return pillar_of


@pytest.fixture
def winter_gap() -> YongsinResult:
    """겨울생 甲 일간: 용신 화, 희신 목, 기신 수, 통관 목."""
    return YongsinResult(
        yongsin=Element.FIRE,
        huisin=Element.WOOD,
        gisin=Element.WATER,
        tonggwan=Element.WOOD,
        method=YongsinMethod.JOHU,
        johu_stem=Stem.BYEONG,
        evidence=(),
    )


@pytest.fixture
def gwiin_branches() -> frozenset[Branch]:
    return frozenset({Branch.CHUK, Branch.MI})


@pytest.fixture
def deities_for() -> Callable[[str], tuple[tuple[la.DeityKind, Direction8], ...]]:
    """2026-10-10~16 중 일진이 ganzhi인 날의 길신 방위."""

    def find(ganzhi: str) -> tuple[tuple[la.DeityKind, Direction8], ...]:
        target = pillar_of(ganzhi)
        for day in range(10, 17):
            civil = date(2026, 10, day)
            if la.day_pillar(civil) == target:
                return la.deity_directions(civil)
        raise AssertionError(f"2026-10-10~16에 {ganzhi}일이 없습니다")

    return find
