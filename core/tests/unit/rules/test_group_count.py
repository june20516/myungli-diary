from collections.abc import Callable
from unittest.mock import patch

from myungri_engine.domain.enums import TenGodGroup
from myungri_engine.domain.models import FourPillars, Pillar
from myungri_engine.rules import tags
from myungri_engine.rules.group_count import natal_group_count

PillarOf = Callable[[str], Pillar]


def _natal(pillar_of: PillarOf, *, with_hour: bool = True) -> FourPillars:
    """甲 일간, 연 甲子 월 丙寅 일 甲辰 시 庚午."""
    return FourPillars(
        year=pillar_of("甲子"),
        month=pillar_of("丙寅"),
        day=pillar_of("甲辰"),
        hour=pillar_of("庚午") if with_hour else None,
    )


def test_counts_stems_and_branch_main_stems_without_day_stem(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of)
    # 비겁: 연간 甲 + 월지 寅 정기 甲 (일간 甲은 제외)
    assert natal_group_count(natal, TenGodGroup.BIGYEOP) == 2
    # 식상: 월간 丙 + 시지 午 정기 丁
    assert natal_group_count(natal, TenGodGroup.SIKSANG) == 2


def test_unknown_hour_excluded(pillar_of: PillarOf) -> None:
    natal = _natal(pillar_of, with_hour=False)
    assert natal_group_count(natal, TenGodGroup.SIKSANG) == 1
    assert natal_group_count(natal, TenGodGroup.GWANSEONG) == 0


def test_matches_tag_rush_rule(pillar_of: PillarOf) -> None:
    """tags._rush_tags가 공용 함수의 개수로 쏠림을 판단한다."""
    natal = _natal(pillar_of)
    day = pillar_of("甲寅")  # 천간·지지 정기 모두 비겁, 원국 비겁 2개
    assert tags._rush_tags(natal, day) == (tags.rush_tag_key(TenGodGroup.BIGYEOP),)
    with patch.object(tags, "natal_group_count", return_value=1) as spy:
        assert tags._rush_tags(natal, day) == ()
    spy.assert_called_once_with(natal, TenGodGroup.BIGYEOP)
