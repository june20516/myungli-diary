from dataclasses import FrozenInstanceError

import pytest

from myungri_engine.domain.enums import Branch, NoticeCode, Stem
from myungri_engine.domain.errors import InvalidInputError, OutOfRangeError
from myungri_engine.domain.models import Evidence, FourPillars, Judgment, Notice, Pillar


def test_pillar_is_frozen_and_hashable():
    p = Pillar(Stem.GAP, Branch.JA)
    assert hash(p) == hash(Pillar(Stem.GAP, Branch.JA))
    with pytest.raises(FrozenInstanceError):
        p.stem = Stem.EUL  # type: ignore[misc]


def test_four_pillars_hour_optional():
    p = Pillar(Stem.GAP, Branch.JA)
    assert FourPillars(p, p, p, None).hour is None


def test_judgment_and_notice_defaults():
    ev = Evidence("r1", "dir/file.json#a.b", {"k": "v"})
    j = Judgment("msg.key", {"n": 1}, (ev,))
    assert j.evidence[0].rule_id == "r1"
    assert Notice(NoticeCode.TIME_UNKNOWN).detail == {}


def test_errors_are_value_errors():
    assert issubclass(InvalidInputError, ValueError) and issubclass(OutOfRangeError, ValueError)
