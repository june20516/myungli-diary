from collections.abc import Callable

import pytest

from myungli_engine.domain.enums import Branch, DayKind
from myungli_engine.domain.models import Pillar
from myungli_engine.rules.day_kind import classify_day
from myungli_engine.rules.yongsin import YongsinResult


@pytest.mark.parametrize(
    ("ganzhi", "kind"),
    [
        ("己未", DayKind.GWIIN_DAY),
        ("丁巳", DayKind.YONGSIN_DAY),
        ("戊午", DayKind.YONGSIN_DAY),
        ("壬戌", DayKind.GISIN_DAY),
        ("庚申", DayKind.ORDINARY_DAY),
    ],
)
def test_classify(
    ganzhi: str,
    kind: DayKind,
    winter_gap: YongsinResult,
    gwiin_branches: frozenset[Branch],
    pillar_of: Callable[[str], Pillar],
) -> None:
    assert classify_day(pillar_of(ganzhi), winter_gap, gwiin_branches) is kind


def test_gisin_overrides_yongsin(
    winter_gap: YongsinResult, gwiin_branches: frozenset[Branch], pillar_of: Callable[[str], Pillar]
) -> None:
    assert classify_day(pillar_of("丙子"), winter_gap, gwiin_branches) is DayKind.GISIN_DAY


def test_gwiin_takes_priority_over_gisin(
    winter_gap: YongsinResult, pillar_of: Callable[[str], Pillar]
) -> None:
    assert classify_day(pillar_of("壬子"), winter_gap, frozenset({Branch.JA})) is DayKind.GWIIN_DAY
