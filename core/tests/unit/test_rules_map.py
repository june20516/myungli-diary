"""계산 규칙 지도(#988)가 엔진과 어긋나지 않는지 본다. 규칙을 바꾸는 PR은 지도도 함께 고친다."""

from __future__ import annotations

import json
import re
import tomllib
from fnmatch import fnmatchcase
from pathlib import Path
from typing import Any

import pytest

from myungli_engine.constants.evidence_rules import RULE_DETAIL_KEYS
from myungli_engine.constants.message_keys import ALL_KEYS
from myungli_engine.references import loader

CORE_DIR = Path(__file__).resolve().parents[2]
REPO_DIR = CORE_DIR.parent
PACKAGE_DIR = CORE_DIR / "src" / "myungli_engine"
SOURCE = CORE_DIR / "docs" / "rules-map" / "rules_map.toml"
EXPORTED = CORE_DIR / "rules_map.json"

SOURCE_STATUSES = {"source", "interpretation", "none"}
RULE_KINDS = {"base", "added", "removed"}


@pytest.fixture(scope="module")
def rules_map() -> dict[str, Any]:
    with SOURCE.open("rb") as file:
        return tomllib.load(file)


@pytest.fixture(scope="module")
def items(rules_map: dict[str, Any]) -> list[dict[str, Any]]:
    return rules_map["items"]


@pytest.mark.contract
def test_exported_json_up_to_date(rules_map: dict[str, Any]) -> None:
    """원본을 고친 뒤 `uv run python tools/rules_map.py`로 다시 만든다."""
    assert json.loads(EXPORTED.read_text(encoding="utf-8")) == rules_map


def test_every_evidence_rule_in_exactly_one_item(items: list[dict[str, Any]]) -> None:
    listed = [rule for item in items for rule in item["evidence_rules"]]
    assert sorted(listed) == sorted(set(listed)), "한 근거 규칙이 두 항목에 있습니다"
    assert set(listed) == set(RULE_DETAIL_KEYS)


def test_every_message_key_covered(items: list[dict[str, Any]]) -> None:
    patterns = [pattern for item in items for pattern in item["message_keys"]]
    uncovered = sorted(key for key in ALL_KEYS if not any(fnmatchcase(key, p) for p in patterns))
    assert not uncovered
    unused = [p for p in patterns if not any(fnmatchcase(key, p) for key in ALL_KEYS)]
    assert not unused


def test_every_rule_module_listed_and_code_exists(items: list[dict[str, Any]]) -> None:
    listed = {path for item in items for path in item["code"]}
    for path in listed:
        assert (PACKAGE_DIR / path).is_file(), path
    modules = {
        f"rules/{path.name}" for path in (PACKAGE_DIR / "rules").glob("*.py") if path.name != "__init__.py"
    }
    assert modules <= listed, sorted(modules - listed)


def test_structure(rules_map: dict[str, Any], items: list[dict[str, Any]]) -> None:
    steps = [step["id"] for step in rules_map["framework"]]
    groups = {group["id"] for group in rules_map["groups"]}
    item_ids = [item["id"] for item in items]
    assert len(item_ids) == len(set(item_ids))
    assert set(rules_map["meta"]["source_status_labels"]) == SOURCE_STATUSES
    assert set(rules_map["meta"]["rule_kind_labels"]) == RULE_KINDS
    for item in items:
        assert item["group"] in groups, item["id"]
        assert list(item["steps"]) == steps, item["id"]
        assert item["source_status"] in SOURCE_STATUSES, item["id"]
        for rule in item["rules"]:
            assert rule["kind"] in RULE_KINDS, item["id"]
            assert rule["source_status"] in SOURCE_STATUSES, item["id"]
    assert groups == {item["group"] for item in items}, "항목이 없는 그룹"
    for entry in rules_map["inconsistencies"]:
        assert set(entry["items"]) <= set(item_ids), entry["id"]
    orders = [entry["order"] for entry in rules_map["background"]]
    assert orders == sorted(orders) == list(range(1, len(orders) + 1))


def _decision_ids(path: Path, prefix: str) -> set[str]:
    rows = re.findall(rf"^\| ({prefix}\d+) \|", path.read_text(encoding="utf-8"), flags=re.MULTILINE)
    return set(rows)


def test_decisions_exist(items: list[dict[str, Any]]) -> None:
    known = _decision_ids(REPO_DIR / "docs" / "decisions.md", "D") | _decision_ids(
        CORE_DIR / "docs" / "decisions.md", "C"
    )
    cited = {number for item in items for number in item["decisions"]}
    cited |= {number for item in items for rule in item["rules"] for number in rule["decisions"]}
    assert cited - known == set()


def test_source_refs_exist(items: list[dict[str, Any]]) -> None:
    refs = set(loader.all_refs())
    for item in items:
        for source in item.get("sources", []):
            assert any(fnmatchcase(ref, source["ref"]) for ref in refs), source["ref"]
