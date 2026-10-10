import pytest

from myungri_engine.domain.enums import Stem as S
from myungri_engine.domain.enums import TenGod as T
from myungri_engine.domain.enums import TenGodGroup as G
from myungri_engine.domain.ten_gods import ten_god


@pytest.mark.parametrize(
    "other,expected",
    [
        (S.GAP, T.BIGYEON),
        (S.EUL, T.GEOPJAE),
        (S.BYEONG, T.SIKSIN),
        (S.JEONG, T.SANGGWAN),
        (S.MU, T.PYEONJAE),
        (S.GI, T.JEONGJAE),
        (S.GYEONG, T.PYEONGWAN),
        (S.SIN, T.JEONGGWAN),
        (S.IM, T.PYEONIN),
        (S.GYE, T.JEONGIN),
    ],
)
def test_ten_gods_for_gap_day_master(other: S, expected: T) -> None:
    assert ten_god(S.GAP, other) == expected


def test_yin_day_master():
    assert ten_god(S.EUL, S.GAP) == T.GEOPJAE and ten_god(S.EUL, S.GYEONG) == T.JEONGGWAN


def test_groups():
    assert T.PYEONGWAN.group == G.GWANSEONG and T.JEONGIN.group == G.INSEONG
