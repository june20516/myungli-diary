"""ARB 검사 테스트."""

import json
from dataclasses import replace
from pathlib import Path

import pytest

from mlw.arb import check_arb
from mlw.loader import load_rules, load_slots
from mlw.model import UNBOUNDED, LoadError, RuleSet, Slot
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


def test_arb_slot_allowed_skips_rule(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    depth_slot = next(slot for slot in slots.values() if "depthExplain" in slot.keys)
    allowing = {**slots, depth_slot.id: replace(depth_slot, allowed=frozenset({"slop.P8"}))}
    path = write_arb(tmp_path, {"@@locale": "ko", "depthExplain": "반가워요!"})
    assert check_arb([path], allowing, rules) == []


def test_arb_plural_passes(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "citySearchResults": "결과 {count, plural, other{{count}개}}"})
    assert check_arb([path], slots, rules) == []


def test_arb_plural_forms_must_match_language(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "citySearchResults": "{count, plural, one{{count}개} other{{count}개}}"})
    assert [f.rule_id for f in check_arb([path], slots, rules)] == ["icu.plural"]


def test_arb_plural_syntax_error_is_finding(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "citySearchResults": "{count, plural, other{{count}개}"})
    assert [f.rule_id for f in check_arb([path], slots, rules)] == ["icu.plural"]


def test_arb_uses_key_max_length(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    slot = replace(
        slots["ui.action.button"],
        max_length={"ko": 3, "en": None, "ja": None},
        key_max_length={"actionClose": {"ko": UNBOUNDED}},
    )
    custom = {**slots, slot.id: slot}
    arb = write_arb(tmp_path, {"@@locale": "ko", "actionClose": "가나다라마바", "actionConfirm": "가나다라마바"})
    findings = [finding for finding in check_arb([arb], custom, rules) if finding.rule_id == "style.length"]
    assert len(findings) == 1
    assert findings[0].line == 4


JOSA_SELECT = "{tJosa, select, final{이} rieul{이} none{가} other{이(가)}}"


def test_arb_josa_select_passes(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "notice": "{t}" + JOSA_SELECT + " 내일이에요"})
    assert check_arb([path], slots, rules) == []


def test_arb_josa_orphan(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "notice": JOSA_SELECT + " 내일이에요"})
    assert [finding.rule_id for finding in check_arb([path], slots, rules)] == ["arb.josa_orphan"]


def test_arb_josa_orphan_needs_adjacent_param(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = write_arb(tmp_path, {"@@locale": "ko", "notice": "{t} 와 " + JOSA_SELECT + " 내일이에요"})
    assert [finding.rule_id for finding in check_arb([path], slots, rules)] == ["arb.josa_orphan"]
