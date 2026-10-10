from typing import cast

import pytest

from myungri_engine.domain.enums import Branch as B
from myungri_engine.domain.enums import Stem as S
from myungri_engine.references import loader


def test_resolve_johu_cell() -> None:
    cell = cast(dict[str, object], loader.resolve(loader.johu_ref(S.GAP, B.JA)))
    yongsin = cast(list[str], cell["yongsin"])
    assert yongsin[0] == "丁"
    assert cell["evidence_level"] == "month"


def test_resolve_five_elements() -> None:
    direction = cast(dict[str, object], loader.resolve(loader.FIVE_ELEMENTS_REF["direction"]))
    mapping = cast(dict[str, str], direction["mapping"])
    assert mapping["水"] == "北"


def test_every_five_elements_ref_resolvable() -> None:
    loader.validate_refs(loader.FIVE_ELEMENTS_REF.values())


def test_every_johu_cell_resolvable() -> None:
    loader.validate_refs(loader.johu_ref(s, b) for s in S for b in B)


def test_missing_ref_raises() -> None:
    with pytest.raises(KeyError):
        loader.resolve("gungtong-bogam/johu_evidence#甲.없음")


@pytest.mark.parametrize(
    "ref",
    ["gungtong-bogam/johu_evidence", "unknown/johu_evidence#甲", "gungtong-bogam/nothing#甲"],
)
def test_malformed_or_unknown_ref_raises(ref: str) -> None:
    with pytest.raises(KeyError):
        loader.resolve(ref)
