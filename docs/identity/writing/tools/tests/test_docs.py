"""생성 문서 테스트."""

from pathlib import Path

import pytest

from mlw.cli import main
from mlw.docs import render_docs, stale_docs, write_docs
from mlw.loader import load_rules, load_slots
from mlw.model import RuleSet, Slot
from mlw.paths import RULES_DIR, SLOTS_DIR, WRITING_DIR

HEADER = "<!-- mlw gen-docs로 생성. 직접 고치지 않습니다 -->"
FILES = {"slop-patterns.md", "slot-catalog.md", "josa-table.md"}


@pytest.fixture(scope="module")
def rules() -> RuleSet:
    return load_rules(RULES_DIR)


@pytest.fixture(scope="module")
def slots(rules: RuleSet) -> dict[str, Slot]:
    return load_slots(SLOTS_DIR, rules)


def test_render_is_deterministic(rules: RuleSet, slots: dict[str, Slot]) -> None:
    assert render_docs(rules, slots) == render_docs(rules, slots)
    assert set(render_docs(rules, slots)) == FILES


def test_slop_doc_lists_every_rule(rules: RuleSet, slots: dict[str, Slot]) -> None:
    lines = render_docs(rules, slots)["slop-patterns.md"].splitlines()
    for rule_id in rules.slop:
        assert sum(1 for line in lines if line.startswith(f"| {rule_id} |")) == 1


def test_slot_doc_lists_every_slot(rules: RuleSet, slots: dict[str, Slot]) -> None:
    lines = render_docs(rules, slots)["slot-catalog.md"].splitlines()
    for slot_id in slots:
        assert sum(1 for line in lines if line.startswith(f"| {slot_id} |")) == 1


def test_slot_doc_shows_param_kinds(rules: RuleSet, slots: dict[str, Slot]) -> None:
    lines = render_docs(rules, slots)["slot-catalog.md"].splitlines()
    [focus] = [line for line in lines if line.startswith("| daily.focus_time |")]
    assert "`branches`: list:branch" in focus
    assert "`score`: number" in focus
    [color] = [line for line in lines if line.startswith("| daily.color |")]
    assert "`element`: element, color" in color
    assert "`role`: none" in color


def test_header_warns_generated(rules: RuleSet, slots: dict[str, Slot]) -> None:
    for content in render_docs(rules, slots).values():
        assert content.splitlines()[0] == HEADER


def test_generated_files_are_current(rules: RuleSet, slots: dict[str, Slot]) -> None:
    assert stale_docs(WRITING_DIR / "generated", render_docs(rules, slots)) == []


def test_stale_docs_and_write(tmp_path: Path) -> None:
    docs = {"a.md": "새 내용\n", "b.md": "같음\n"}
    (tmp_path / "b.md").write_text("같음\n", encoding="utf-8")
    assert stale_docs(tmp_path, docs) == ["a.md"]
    write_docs(tmp_path, docs)
    assert stale_docs(tmp_path, docs) == []


def test_cli_gen_docs(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    out = tmp_path / "generated"
    assert main(["gen-docs", "--check", "--out-dir", str(out)]) == 1
    lines = capsys.readouterr().out.splitlines()
    assert len(lines) == 3
    assert all(" docs.stale error " in line and ":1 " in line for line in lines)
    assert main(["gen-docs", "--out-dir", str(out)]) == 0
    assert main(["gen-docs", "--check", "--out-dir", str(out)]) == 0
