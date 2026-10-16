"""근거 슬롯과 core 근거 목록(`core/evidence_rules.json`, `core/evidence_sources.json`) 대조 테스트."""

from pathlib import Path

from mlw.evidence import (
    BASIS_SLOT,
    REASON_SLOT,
    RULE_EVIDENCE_MISSING,
    RULE_EVIDENCE_PARAM_MISMATCH,
    RULE_EVIDENCE_UNKNOWN,
    SOURCE_SLOT,
    check_evidence,
)
from mlw.model import ParamKind, Slot

RULES = {"color/lucky_element": ["element", "role"], "number/hado": ["number"]}
SOURCES = ["book/a#1", "book/b#2"]


def make_slot(slot_id: str, keys: dict[str, dict[str, ParamKind]]) -> Slot:
    return Slot(
        id=slot_id,
        where="시험",
        purpose="info",
        types=(),
        variants=1,
        keys=keys,
        co_display=(),
        max_length={"ko": None, "en": None, "ja": None},
        allowed=frozenset(),
        forbidden=frozenset(),
        examples={"good": [], "bad": []},
        line=3,
        file=Path("slots/content/evidence.yaml"),
    )


def none_params(*names: str) -> dict[str, ParamKind]:
    return {name: ParamKind("none") for name in names}


def complete_slots() -> dict[str, Slot]:
    slots = [
        make_slot(REASON_SLOT, {"reason.color/lucky_element": {}}),
        make_slot(
            BASIS_SLOT,
            {
                "basis.color/lucky_element": none_params("element", "role"),
                "basis.number/hado": none_params("number"),
            },
        ),
        make_slot(SOURCE_SLOT, {"source.book/a#1": {}, "source.book/b#2": {}}),
    ]
    return {slot.id: slot for slot in slots}


def rule_ids(slots: dict[str, Slot]) -> list[str]:
    return [finding.rule_id for finding in check_evidence(slots, RULES, SOURCES)]


def test_matching_slots_have_no_findings() -> None:
    assert check_evidence(complete_slots(), RULES, SOURCES) == []


def test_reason_may_cover_only_some_rules() -> None:
    slots = complete_slots()
    assert "reason.number/hado" not in slots[REASON_SLOT].keys
    assert rule_ids(slots) == []


def test_unknown_rule_or_source_is_reported() -> None:
    slots = complete_slots()
    slots[REASON_SLOT].keys["reason.gone/rule"] = {}
    slots[SOURCE_SLOT].keys["source.book/c#3"] = {}
    findings = check_evidence(slots, RULES, SOURCES)
    assert [finding.rule_id for finding in findings] == [RULE_EVIDENCE_UNKNOWN, RULE_EVIDENCE_UNKNOWN]
    assert "gone/rule" in findings[0].message
    assert "book/c#3" in findings[1].message


def test_key_without_prefix_is_unknown() -> None:
    slots = complete_slots()
    slots[BASIS_SLOT].keys["color/lucky_element"] = {}
    assert rule_ids(slots) == [RULE_EVIDENCE_UNKNOWN]


def test_basis_and_source_must_cover_every_entry() -> None:
    slots = complete_slots()
    del slots[BASIS_SLOT].keys["basis.number/hado"]
    del slots[SOURCE_SLOT].keys["source.book/b#2"]
    findings = check_evidence(slots, RULES, SOURCES)
    assert [finding.rule_id for finding in findings] == [RULE_EVIDENCE_MISSING, RULE_EVIDENCE_MISSING]
    assert "number/hado" in findings[0].message
    assert "book/b#2" in findings[1].message


def test_basis_params_must_match_detail_keys() -> None:
    slots = complete_slots()
    slots[BASIS_SLOT].keys["basis.color/lucky_element"] = none_params("element", "note")
    findings = check_evidence(slots, RULES, SOURCES)
    assert [finding.rule_id for finding in findings] == [RULE_EVIDENCE_PARAM_MISMATCH]
    assert "role" in findings[0].message
    assert "note" in findings[0].message


def test_missing_slots_are_skipped() -> None:
    assert check_evidence({}, RULES, SOURCES) == []
