"""IA 대조 검사 테스트."""

import json
from pathlib import Path

import pytest

from mlw.ia import (
    RULE_EMPTY_KEYS,
    RULE_KEY_NAME,
    RULE_SOURCE,
    RULE_UNCOVERED,
    RULE_UNKNOWN,
    RULE_UNPLACED,
    Ia,
    camel,
    check_ia,
    load_ia,
)
from mlw.model import Finding, LoadError, ParamKind, Slot

UI_ID = "a-b.c.d-e"
CONTENT_ID = "x.y.z"
IA_DATA = {
    "version": 1,
    "components": [{"id": "tag-chip", "role": "칩"}],
    "screens": [
        {"id": "a-b", "slots": [{"id": UI_ID, "source": "ui", "role": "버튼"}]},
        {"id": "x", "slots": [{"id": CONTENT_ID, "source": "content", "role": "문장"}]},
    ],
}


@pytest.fixture
def ia(tmp_path: Path) -> Ia:
    path = tmp_path / "screens.json"
    path.write_text(json.dumps(IA_DATA), encoding="utf-8")
    return load_ia(path)


def make_slot(
    slot_id: str,
    group: str,
    keys: tuple[str, ...] = ("k",),
    ia: tuple[str, ...] = (),
    components: tuple[str, ...] = (),
) -> Slot:
    params: dict[str, dict[str, ParamKind]] = {key: {} for key in keys}
    return Slot(
        id=slot_id,
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys=params,
        co_display=(),
        max_length={},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={},
        line=1,
        file=Path("slots") / group / "test.yaml",
        ia=ia,
        components=components,
    )


def covering_slots(*extra: Slot) -> dict[str, Slot]:
    """IA 두 자리를 모두 담는 슬롯에 `extra`를 더합니다."""
    slots = [make_slot(UI_ID, "ui", ("aBCDE",)), make_slot("x.slot", "content", ia=(CONTENT_ID,)), *extra]
    return {slot.id: slot for slot in slots}


def rule_ids(findings: list[Finding]) -> list[str]:
    return [finding.rule_id for finding in findings]


def test_camel() -> None:
    assert camel("day-sheet.diary.write-cta") == "daySheetDiaryWriteCta"
    assert camel("evidence-sheet.lock.cta") == "evidenceSheetLockCta"


def test_load_ia(ia: Ia) -> None:
    assert ia.slots == {UI_ID: "ui", CONTENT_ID: "content"}
    assert ia.roles[UI_ID] == "버튼"
    assert ia.components == frozenset({"tag-chip"})


def test_load_ia_broken(tmp_path: Path) -> None:
    path = tmp_path / "screens.json"
    path.write_text("{", encoding="utf-8")
    with pytest.raises(LoadError):
        load_ia(path)


def test_clean_mapping_has_no_findings(ia: Ia) -> None:
    assert check_ia(covering_slots(), ia) == []


@pytest.mark.parametrize("key", ["aBCDE", "aBCDE2", "aBCDESaved"])
def test_key_name_ok(ia: Ia, key: str) -> None:
    slots = covering_slots()
    slots[UI_ID] = make_slot(UI_ID, "ui", (key,))
    assert check_ia(slots, ia) == []


@pytest.mark.parametrize("key", ["aBCDEsaved", "other"])
def test_key_name_error(ia: Ia, key: str) -> None:
    slots = covering_slots()
    slots[UI_ID] = make_slot(UI_ID, "ui", (key,))
    findings = check_ia(slots, ia)
    assert rule_ids(findings) == [RULE_KEY_NAME]
    assert key in findings[0].message


def test_unknown_ia_and_component(ia: Ia) -> None:
    slots = covering_slots(
        make_slot("p.one", "content", ia=("nope",)),
        make_slot("p.two", "content", components=("nope",)),
    )
    assert rule_ids(check_ia(slots, ia)) == [RULE_UNKNOWN, RULE_UNKNOWN]


def test_unknown_ui_slot_id_without_components(ia: Ia) -> None:
    slots = covering_slots(make_slot("zz.unknown.slot", "ui", ("zzUnknownSlot",)))
    assert RULE_UNPLACED in rule_ids(check_ia(slots, ia))


def test_source_mismatch(ia: Ia) -> None:
    slots = covering_slots(
        make_slot("p.one", "content", ia=(UI_ID,)),
        make_slot("p.two", "ui", ("pTwo",), ia=(CONTENT_ID,), components=("tag-chip",)),
    )
    assert rule_ids(check_ia(slots, ia)) == [RULE_SOURCE, RULE_SOURCE]


def test_uncovered(ia: Ia) -> None:
    findings = check_ia({}, ia)
    assert rule_ids(findings) == [RULE_UNCOVERED, RULE_UNCOVERED]
    assert all(finding.severity == "error" for finding in findings)
    assert UI_ID in findings[0].message


def test_unplaced_content(ia: Ia) -> None:
    slots = covering_slots(make_slot("p.one", "content"))
    assert rule_ids(check_ia(slots, ia)) == [RULE_UNPLACED]


def test_unplaced_ui_outside_ia(ia: Ia) -> None:
    slots = covering_slots(make_slot("ui.depth.x", "ui", ("depthX",)))
    assert rule_ids(check_ia(slots, ia)) == [RULE_UNPLACED]


def test_ui_outside_ia_key_name_free(ia: Ia) -> None:
    slots = covering_slots(make_slot("ui.depth.x", "ui", ("depthX",), components=("tag-chip",)))
    assert check_ia(slots, ia) == []


def test_empty_keys_warn(ia: Ia) -> None:
    slots = covering_slots(make_slot("p.one", "content", (), ia=(CONTENT_ID,)))
    findings = check_ia(slots, ia)
    assert rule_ids(findings) == [RULE_EMPTY_KEYS]
    assert findings[0].severity == "warn"
