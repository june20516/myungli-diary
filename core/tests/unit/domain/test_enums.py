import pytest

from myungri_engine.domain.enums import Branch, NoticeCode, Stem
from myungri_engine.domain.enums import Element as E


def test_stem_properties():
    assert Stem.from_hanja("甲") is Stem.GAP
    assert Stem.GAP.hanja == "甲" and Stem.GAP.element is E.WOOD and Stem.GAP.is_yang
    assert Stem.GYE.element is E.WATER and not Stem.GYE.is_yang
    assert [s.hanja for s in Stem] == list("甲乙丙丁戊己庚辛壬癸")


def test_branch_properties():
    assert [b.hanja for b in Branch] == list("子丑寅卯辰巳午未申酉戌亥")
    assert [b.element for b in Branch] == [
        E.WATER,
        E.EARTH,
        E.WOOD,
        E.WOOD,
        E.EARTH,
        E.FIRE,
        E.FIRE,
        E.EARTH,
        E.METAL,
        E.METAL,
        E.EARTH,
        E.WATER,
    ]
    assert {b.hanja for b in Branch if b.is_yang} == set("子寅辰午申戌")
    assert Branch.from_hanja("亥") is Branch.HAE


def test_from_hanja_rejects_unknown():
    with pytest.raises(ValueError):
        Stem.from_hanja("子")
    with pytest.raises(ValueError):
        Branch.from_hanja("甲")


def test_notice_codes():
    assert {c.name for c in NoticeCode} == {
        "AMBIGUOUS_LOCAL_TIME",
        "NONEXISTENT_LOCAL_TIME",
        "ZI_HOUR_NEXT_DAY",
        "TIME_UNKNOWN",
        "NEAR_SOLAR_TERM",
        "DAYUN_START_APPROXIMATE",
        "FOCUS_TIME_FALLBACK",
    }
