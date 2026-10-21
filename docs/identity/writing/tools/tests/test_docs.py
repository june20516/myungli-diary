"""생성 문서 테스트."""

from dataclasses import replace as dataclass_replace
from pathlib import Path

import pytest

from mlw.cli import main
from mlw.docs import render_docs, stale_docs, write_docs
from mlw.ia import Ia, load_ia
from mlw.loader import load_content, load_rules, load_slots
from mlw.model import UNBOUNDED, RuleSet, Slot
from mlw.paths import CONTENT_DIR, IA_FILE, RULES_DIR, SLOTS_DIR, WRITING_DIR

HEADER = "<!-- mlw gen-docs로 생성. 직접 고치지 않습니다 -->"
FILES = {
    "slop-patterns.md",
    "slot-catalog.md",
    "josa-table.md",
    "ia-coverage.md",
    "arb/app_ko.arb",
    "arb/app_en.arb",
    "arb/app_ja.arb",
}


@pytest.fixture(scope="module")
def rules() -> RuleSet:
    return load_rules(RULES_DIR)


@pytest.fixture(scope="module")
def slots(rules: RuleSet) -> dict[str, Slot]:
    return load_slots(SLOTS_DIR, rules)


@pytest.fixture(scope="module")
def docs(rules: RuleSet, slots: dict[str, Slot]) -> dict[str, str]:
    return render_docs(rules, slots, load_ia(IA_FILE), load_content(CONTENT_DIR))


def test_render_is_deterministic(rules: RuleSet, slots: dict[str, Slot], docs: dict[str, str]) -> None:
    assert render_docs(rules, slots, load_ia(IA_FILE), load_content(CONTENT_DIR)) == docs
    assert set(docs) == FILES


def test_slop_doc_lists_every_rule(rules: RuleSet, slots: dict[str, Slot], docs: dict[str, str]) -> None:
    lines = docs["slop-patterns.md"].splitlines()
    for rule_id in rules.slop:
        assert sum(1 for line in lines if line.startswith(f"| {rule_id} |")) == 1


def test_slot_doc_lists_every_slot(rules: RuleSet, slots: dict[str, Slot], docs: dict[str, str]) -> None:
    lines = docs["slot-catalog.md"].splitlines()
    for slot_id in slots:
        assert sum(1 for line in lines if line.startswith(f"| {slot_id} |")) == 1


def test_slot_doc_shows_param_kinds(rules: RuleSet, slots: dict[str, Slot], docs: dict[str, str]) -> None:
    lines = docs["slot-catalog.md"].splitlines()
    [focus] = [line for line in lines if line.startswith("| daily.focus_time |")]
    assert "`branches`: list:branch" in focus
    assert "`score`: number" in focus
    [color] = [line for line in lines if line.startswith("| daily.color |")]
    assert "`element`: element, color" in color
    assert "`role`: none" in color


def test_header_warns_generated(rules: RuleSet, slots: dict[str, Slot], docs: dict[str, str]) -> None:
    for name, content in docs.items():
        if name.endswith(".md"):
            assert content.splitlines()[0] == HEADER


@pytest.mark.contract
def test_generated_files_are_current(rules: RuleSet, slots: dict[str, Slot], docs: dict[str, str]) -> None:
    assert stale_docs(WRITING_DIR / "generated", docs) == []


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
    assert len(lines) == len(FILES)
    assert all(" docs.stale error " in line and ":1 " in line for line in lines)
    assert main(["gen-docs", "--out-dir", str(out)]) == 0
    assert main(["gen-docs", "--check", "--out-dir", str(out)]) == 0


def test_ia_coverage_doc(tmp_path: Path, rules: RuleSet, slots: dict[str, Slot]) -> None:
    path = tmp_path / "screens.json"
    path.write_text(
        '{"components": [], "screens": [{"id": "a", "slots": ['
        '{"id": "a.b.c", "source": "content", "role": "r"}, {"id": "a.d.e", "source": "ui", "role": "r"}]}]}',
        encoding="utf-8",
    )
    ia: Ia = load_ia(path)
    one = next(iter(slots.values()))
    mapped = {"x.slot": dataclass_replace(one, id="x.slot", ia=("a.b.c",))}
    docs = render_docs(rules, mapped, ia, [])
    lines = docs["ia-coverage.md"].splitlines()
    assert "| a.b.c | content | x.slot |" in lines
    assert "| a.d.e | ui | - |" in lines
    [catalog_row] = [line for line in docs["slot-catalog.md"].splitlines() if line.startswith("| x.slot |")]
    assert "a.b.c" in catalog_row



def test_slot_doc_shows_unbounded_and_key_limits(rules: RuleSet, slots: dict[str, Slot]) -> None:
    slot = dataclass_replace(
        slots["ui.action.button"],
        max_length={"ko": 10, "en": UNBOUNDED, "ja": None},
        key_max_length={"actionClose": {"ko": 4}},
    )
    docs = render_docs(rules, {**slots, slot.id: slot}, load_ia(IA_FILE), load_content(CONTENT_DIR))
    [row] = [line for line in docs["slot-catalog.md"].splitlines() if line.startswith("| ui.action.button |")]
    assert "ko 10, en 상한 없음, ja -" in row
    assert "`actionClose` ko 4" in row
