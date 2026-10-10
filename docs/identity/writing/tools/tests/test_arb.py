"""ARB 검사 테스트."""

import json
from pathlib import Path

import pytest

from mlw.arb import check_arb
from mlw.loader import load_rules, load_slots
from mlw.model import LoadError, RuleSet, Slot
from mlw.paths import RULES_DIR, SLOTS_DIR


@pytest.fixture(scope="module")
def rules() -> RuleSet:
    return load_rules(RULES_DIR)


@pytest.fixture(scope="module")
def slots(rules: RuleSet) -> dict[str, Slot]:
    return load_slots(SLOTS_DIR, rules)


def write_arb(tmp_path: Path, body: dict[str, str], name: str = "app_ko.arb") -> Path:
    path = tmp_path / name
    path.write_text(json.dumps(body, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def test_arb_exclamation(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "hello": "반가워요!"})
    findings = check_arb([path], slots, rules)
    assert [(f.rule_id, f.severity, f.file, f.line) for f in findings] == [("slop.P8", "error", path, 3)]


def test_arb_metadata_keys_ignored(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "@hello": "반가워요!", "hello": "반가워요"})
    assert check_arb([path], slots, rules) == []


def test_arb_placeholder_is_normalized(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "greet": "{color}(이)가 왔어요"})
    assert check_arb([path], slots, rules) == []


def test_arb_slot_key_is_checked(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "depthSurface": "반가워요!"})
    assert [f.rule_id for f in check_arb([path], slots, rules)] == ["slop.P8"]


def test_arb_invalid_json_is_load_error(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = tmp_path / "app_ko.arb"
    path.write_text("{ not json", encoding="utf-8")
    with pytest.raises(LoadError):
        check_arb([path], slots, rules)
