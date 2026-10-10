"""규칙 YAML 로더 테스트."""

from pathlib import Path

import pytest

from mlw.loader import load_rules
from mlw.model import Finding, LoadError
from mlw.paths import RULES_DIR
from mlw.yamlio import load_with_lines

BROKEN_DIR = Path(__file__).parent / "data" / "broken"


def copy_seed_rules(destination: Path) -> None:
    for source in RULES_DIR.glob("*.yaml"):
        (destination / source.name).write_text(source.read_text(encoding="utf-8"), encoding="utf-8")


def test_load_rules_reads_seed_files() -> None:
    rules = load_rules(RULES_DIR)
    for rule_id in ("P1", "P2", "P3", "P4a", "P4b", "P5", "P6", "P7", "P8"):
        assert f"slop.{rule_id}" in rules.slop
    assert "slop.P4" not in rules.slop
    assert rules.slop["slop.P8"].judge == "rule"
    assert rules.slop["slop.P4b"].judge == "llm"
    assert rules.slop["slop.P1"].exempt_purposes == frozenset({"care"})
    assert rules.slop["slop.P8"].detect is not None
    assert rules.slop["slop.P8"].detect.langs == frozenset()
    # 라운드 결과로 규칙이 늘어나므로 초기 규칙을 포함하는지만 확인합니다.
    assert {"limit.L1", "limit.L2", "limit.L3", "limit.L4", "limit.L5", "limit.L6", "limit.L7"} <= set(rules.limits)
    assert {"style.S1", "style.S2"} <= set(rules.style)


def test_load_with_lines_reports_item_start_lines() -> None:
    items = load_with_lines(BROKEN_DIR / "slop_missing_judge.yaml")
    assert [line for _, line in items] == [3]


def test_missing_field_reports_file_and_line(tmp_path: Path) -> None:
    copy_seed_rules(tmp_path)
    broken = tmp_path / "slop.yaml"
    broken.write_text((BROKEN_DIR / "slop_missing_judge.yaml").read_text(encoding="utf-8"), encoding="utf-8")
    with pytest.raises(LoadError) as raised:
        load_rules(tmp_path)
    findings: list[Finding] = raised.value.findings
    assert len(findings) == 1
    assert findings[0].file == broken
    assert findings[0].line == 3
    assert findings[0].rule_id == "load.schema"
    assert findings[0].severity == "error"
    assert "judge" in findings[0].message


def test_unknown_judge_value_is_error(tmp_path: Path) -> None:
    copy_seed_rules(tmp_path)
    broken = tmp_path / "slop.yaml"
    broken.write_text((BROKEN_DIR / "slop_unknown_judge.yaml").read_text(encoding="utf-8"), encoding="utf-8")
    with pytest.raises(LoadError) as raised:
        load_rules(tmp_path)
    findings = raised.value.findings
    assert len(findings) == 1
    assert findings[0].line == 3
    assert "judge" in findings[0].message
    assert "maybe" in findings[0].message


def test_all_problems_are_collected_at_once(tmp_path: Path) -> None:
    copy_seed_rules(tmp_path)
    (tmp_path / "slop.yaml").write_text(
        (BROKEN_DIR / "slop_two_problems.yaml").read_text(encoding="utf-8"), encoding="utf-8"
    )
    with pytest.raises(LoadError) as raised:
        load_rules(tmp_path)
    assert [finding.line for finding in raised.value.findings] == [3, 8]


def test_limit_max_int_expands_to_all_langs() -> None:
    rules = load_rules(RULES_DIR)
    assert rules.limits["limit.L1"].max == {"ko": 1, "en": 1, "ja": 1}
    assert rules.limits["limit.L1"].count.placeholder == "name"
    assert rules.limits["limit.L2"].max == {"ko": 2, "en": 2, "ja": 2}
    assert rules.limits["limit.L4"].max == {"en": 2}
    assert rules.limits["limit.L3"].count.type == "care"


def test_new_count_selectors_load() -> None:
    limits = load_rules(RULES_DIR).limits
    assert limits["limit.L5"].count.lexicon == ("고른다면",)
    assert limits["limit.L5"].max == {"ko": 1}
    assert limits["limit.L6"].count.token is True
    assert limits["limit.L7"].count.token_entries is True


@pytest.mark.parametrize(
    "count",
    [
        "{token: true, type: care}",
        '{lexicon: ["a"], token_entries: true}',
        "{token: false}",
        "{lexicon: []}",
        "{token_entries: 1}",
    ],
)
def test_count_must_fill_exactly_one(tmp_path: Path, count: str) -> None:
    copy_seed_rules(tmp_path)
    (tmp_path / "limits.yaml").write_text(
        f"- id: limit.X\n  name: 시험\n  scope: screen\n  count: {count}\n  max: 1\n  severity: error\n",
        encoding="utf-8",
    )
    with pytest.raises(LoadError) as raised:
        load_rules(tmp_path)
    assert [finding.rule_id for finding in raised.value.findings] == ["load.schema"]


def write_limit(directory: Path, scope: str, window_line: str) -> None:
    copy_seed_rules(directory)
    (directory / "limits.yaml").write_text(
        f"- id: limit.X\n  name: 시험\n  scope: {scope}\n{window_line}"
        '  count: {type: care}\n  max: 1\n  severity: warn\n',
        encoding="utf-8",
    )


def test_window_defaults_to_seven_and_loads_two() -> None:
    limits = load_rules(RULES_DIR).limits
    assert limits["limit.L3"].window == 7
    assert limits["limit.L8"].window == 2


def test_window_on_week_scope_loads(tmp_path: Path) -> None:
    write_limit(tmp_path, "week", "  window: 3\n")
    assert load_rules(tmp_path).limits["limit.X"].window == 3


@pytest.mark.parametrize(
    ("scope", "window"),
    [("day", "2"), ("week", "1"), ("week", "8"), ("week", "true")],
)
def test_invalid_window_is_schema_error(tmp_path: Path, scope: str, window: str) -> None:
    write_limit(tmp_path, scope, f"  window: {window}\n")
    with pytest.raises(LoadError) as raised:
        load_rules(tmp_path)
    assert [finding.rule_id for finding in raised.value.findings] == ["load.schema"]
