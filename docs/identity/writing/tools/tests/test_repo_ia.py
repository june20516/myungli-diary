"""저장소 실제 슬롯 명세가 IA 계약을 담는지 보는 테스트."""

import json

import pytest

from mlw.completeness import RULE_MISSING, check_completeness
from mlw.glossary import term_ids
from mlw.ia import RULE_UNCOVERED, Ia, check_ia, load_ia
from mlw.loader import load_content, load_rules, load_slots
from mlw.model import LANGS, ParamKind, RuleSet, Slot
from mlw.paths import CONTENT_DIR, IA_FILE, MESSAGE_KEYS_FILE, RULES_DIR, SLOTS_DIR


@pytest.fixture(scope="module")
def rules() -> RuleSet:
    return load_rules(RULES_DIR)


@pytest.fixture(scope="module")
def slots(rules: RuleSet) -> dict[str, Slot]:
    return load_slots(SLOTS_DIR, rules)


@pytest.fixture(scope="module")
def ia() -> Ia:
    return load_ia(IA_FILE)


def test_content_ia_covered(slots: dict[str, Slot], ia: Ia) -> None:
    uncovered = [
        finding.message
        for finding in check_ia(slots, ia)
        if finding.rule_id == RULE_UNCOVERED and "content 슬롯" in finding.message
    ]
    assert uncovered == []


def test_content_slots_have_no_ia_errors(slots: dict[str, Slot], ia: Ia) -> None:
    errors = [
        finding.format()
        for finding in check_ia(slots, ia)
        if finding.severity == "error" and finding.rule_id != RULE_UNCOVERED and finding.file.parent.name == "content"
    ]
    assert errors == []


def test_term_meaning_keys(slots: dict[str, Slot]) -> None:
    tags = [key for key in json.loads(MESSAGE_KEYS_FILE.read_text(encoding="utf-8")) if key.startswith("tag.")]
    assert set(slots["term.meaning"].keys) == {f"term.{term}" for term in term_ids(tags)}


def test_vocative_slots(slots: dict[str, Slot]) -> None:
    assert {slot.id for slot in slots.values() if slot.vocative} == {"daily.fortune.head", "chart.ilgan_head"}


def test_new_content_slot_keys(slots: dict[str, Slot]) -> None:
    stems = ("gap", "eul", "byeong", "jeong", "mu", "gi", "gyeong", "sin", "im", "gye")
    assert set(slots["character.reason"].keys) == {
        f"character.reason.{kind}" for kind in ("gwiin_day", "yongsin_day", "gisin_day", "ordinary_day")
    }
    assert set(slots["chart.ilgan_head"].keys) == {f"ilgan.head.{stem}" for stem in stems}
    assert set(slots["chart.ilgan_body"].keys) == {f"ilgan.body.{stem}" for stem in stems}
    assert slots["chart.yongsin_summary"].keys == {
        "yongsin.summary": {"yongsin": ParamKind("glossary", ("element", "color"))}
    }
    assert slots["onboard.hour_confirm"].keys == {
        "hour.confirm": {
            "branch": ParamKind("glossary", ("branch",)),
            "start": ParamKind("text"),
            "end": ParamKind("text"),
        }
    }
    assert set(slots["system.apple_return"].keys) == {
        f"apple_return.{part}" for part in ("title", "body", "open", "install")
    }
    for slot_id in ("explain.today_reason", "evidence.basis", "evidence.source"):
        assert slots[slot_id].keys == {}
        assert slots[slot_id].select


def test_all_ia_covered(slots: dict[str, Slot], ia: Ia) -> None:
    assert [finding.message for finding in check_ia(slots, ia) if finding.rule_id == RULE_UNCOVERED] == []


def test_ui_keys_named(slots: dict[str, Slot], ia: Ia) -> None:
    errors = [finding.format() for finding in check_ia(slots, ia) if finding.severity == "error"]
    assert errors == []
    assert sum(1 for slot in slots.values() if slot.file.parent.name == "ui" and slot.id in ia.slots) == 90


def test_ui_manuscripts_complete(slots: dict[str, Slot]) -> None:
    ui_slots = {slot_id: slot for slot_id, slot in slots.items() if slot.file.parent.name == "ui"}
    entries = [entry for entry in load_content(CONTENT_DIR) if entry.slot in ui_slots]
    missing = [
        finding.message
        for finding in check_completeness(ui_slots, entries, [], LANGS)
        if finding.rule_id == RULE_MISSING
    ]
    assert missing == []


def test_new_content_manuscripts_complete(slots: dict[str, Slot]) -> None:
    targets = {slot_id: slots[slot_id] for slot_id in ("system.apple_return", "onboard.hour_confirm", "calendar.solar_term")}
    entries = [entry for entry in load_content(CONTENT_DIR) if entry.slot in targets]
    assert [f.message for f in check_completeness(targets, entries, [], LANGS) if f.rule_id == RULE_MISSING] == []


def test_solar_term_en_short() -> None:
    texts = [entry.text for entry in load_content(CONTENT_DIR) if entry.slot == "calendar.solar_term" and entry.lang == "en"]
    assert len(texts) == 24
    assert all(len(text) <= 6 for text in texts)
    assert len(set(texts)) == 24
