"""검수 수정안 판정과 원고 반영 테스트(#1283)."""

import shutil
from collections.abc import Callable
from pathlib import Path

import pytest
import yaml

from mlw.cli import collect_findings, default_check_inputs
from mlw.loader import load_content
from mlw.model import Entry, Finding
from mlw.paths import CONTENT_DIR
from mlw.review.apply import (
    Change,
    Outcome,
    apply_review,
    prejudge,
    replace_text_in_line,
    rewind_tokens,
    write_texts,
)
from mlw.review.export import row_id
from mlw.review.sheet import ReviewRow


def make_entry(text: str, key: str = "k") -> Entry:
    return Entry(Path("content/en/ui.yaml"), 3, "s", key, None, 1, "en", text)


def make_row(entry: Entry, suggestion: str, current: str | None = None, verdict: str = "") -> ReviewRow:
    return ReviewRow(
        id=row_id(entry),
        key=entry.key,
        bundle="ui",
        place="",
        source="",
        current=entry.text if current is None else current,
        example="",
        suggestion=suggestion,
        verdict=verdict,
    )


def reasons(rows: list[ReviewRow], entries: list[Entry]) -> dict[str, str]:
    _, outcomes = prejudge(rows, {row_id(entry): entry for entry in entries})
    return {outcome.row_id: outcome.reason for outcome in outcomes}


def test_outcome_text() -> None:
    assert Outcome("a", True).text == "반영함"
    assert Outcome("a", False, "변경 없음").text == "반영 안 함: 변경 없음"


def test_prejudge_reasons() -> None:
    base = make_entry("Hello {name}", key="base")
    verdict = make_entry("Keep", key="verdict")
    missing = make_entry("Gone", key="missing")
    stale = make_entry("New text", key="stale")
    placeholder = make_entry("See {date}", key="placeholder")
    term = make_entry("With [[Bigyeop|ten_god_group.bigyeop]] here", key="term")
    same = make_entry("Same", key="same")
    empty = make_entry("Untouched", key="empty")
    entries = [base, verdict, stale, placeholder, term, same, empty]
    rows = [
        make_row(base, "Hi {name}"),
        make_row(verdict, "Kept", verdict="tone is intended"),
        make_row(missing, "Whatever"),
        make_row(stale, "Better text", current="Old text"),
        make_row(placeholder, "See you"),
        make_row(term, "With Siksang here"),
        make_row(same, "Same"),
        make_row(empty, ""),
    ]
    changes, _ = prejudge(rows, {row_id(entry): entry for entry in entries})
    assert changes == {row_id(base): "Hi {name}"}
    assert reasons(rows, entries) == {
        row_id(verdict): "writing 판정: tone is intended",
        row_id(missing): "원고에 없는 줄",
        row_id(stale): "내보낸 뒤 원고가 바뀜, 다시 확인",
        row_id(placeholder): "자리표시자가 바뀜",
        row_id(term): "용어 표기가 바뀜, writing이 직접 반영",
        row_id(same): "변경 없음",
    }


def test_prejudge_duplicate_rows() -> None:
    entry = make_entry("Hello")
    rows = [make_row(entry, "Hi"), make_row(entry, "Hey")]
    changes, outcomes = prejudge(rows, {row_id(entry): entry})
    assert changes == {}
    assert [outcome.reason for outcome in outcomes] == ["같은 줄이 두 번"]


@pytest.mark.parametrize(
    ("suggestion", "ok"),
    [("{b} then {a}", True), ("{a} only", False), ("{a} {a} {b}", False), ("{a} and {b", False)],
)
def test_placeholder_multiset(suggestion: str, ok: bool) -> None:
    entry = make_entry("{a} and {b}")
    changes, _ = prejudge([make_row(entry, suggestion)], {row_id(entry): entry})
    assert (row_id(entry) in changes) is ok


def test_plural_structure_must_match() -> None:
    entry = make_entry("{count, plural, one{{count} day} other{{count} days}}")
    good = "{count, plural, one{{count} day left} other{{count} days left}}"
    bad = "{count} days left"
    for suggestion, ok in ((good, True), (bad, False)):
        changes, _ = prejudge([make_row(entry, suggestion)], {row_id(entry): entry})
        assert (row_id(entry) in changes) is ok


def test_rewind_tokens() -> None:
    current = "With [[Bigyeop|ten_god_group.bigyeop]] here"
    assert rewind_tokens(current, "Bigyeop is here") == "[[Bigyeop|ten_god_group.bigyeop]] is here"
    kept = "[[Bigyeop|ten_god_group.bigyeop]] is here"
    assert rewind_tokens(current, kept) == kept
    assert rewind_tokens(current, "Nothing here") is None
    two = "[[Inseong|ten_god_group.inseong]] and [[Bigyeop|ten_god_group.bigyeop]]"
    assert rewind_tokens(two, "Bigyeop, Inseong") is None
    assert rewind_tokens(two, "Inseong with Bigyeop") == two.replace(" and ", " with ")
    assert rewind_tokens("Plain", "Still plain") == "Still plain"


@pytest.mark.parametrize("text", ['new "q" \\ x\ny', "ゆきさん、こんにちは", "50% off: {count}", "#tag"])
def test_replace_text_in_line(text: str) -> None:
    line = '- {slot: a, key: b, text: "old"}'
    replaced = replace_text_in_line(line, text)
    assert yaml.safe_load(replaced)[0]["text"] == text
    assert replaced.startswith('- {slot: a, key: b, text: "')


def test_replace_text_in_line_rejects_other_quotes() -> None:
    with pytest.raises(ValueError):
        replace_text_in_line("- {slot: a, key: b, text: 'x'}", "y")


def test_write_texts_preserves_file(tmp_path: Path) -> None:
    path = tmp_path / "en" / "ui.yaml"
    path.parent.mkdir()
    original = (
        "# comment one\n# comment two\n"
        '- {slot: a, key: one, text: "One"}\n'
        '- {slot: a, key: two, text: "Two"}\n'
        '- {slot: a, key: three, text: "Three"}\n'
    )
    path.write_text(original, encoding="utf-8")
    write_texts(tmp_path, [Change(Path("en/ui.yaml"), 3, "Uno"), Change(Path("en/ui.yaml"), 5, 'Tres "3"\nend')])
    lines = path.read_text(encoding="utf-8").splitlines()
    assert lines[:2] == ["# comment one", "# comment two"]
    assert lines[3] == '- {slot: a, key: two, text: "Two"}'
    assert len(lines) == 5
    texts = [item["text"] for item in yaml.safe_load(path.read_text(encoding="utf-8"))]
    assert texts == ["Uno", "Two", 'Tres "3"\nend']


def check(content_dir: Path) -> list[Finding]:
    return collect_findings(default_check_inputs(), content_dir)


def store_entries(content: Path) -> dict[str, Entry]:
    return {e.key: e for e in load_content(content) if e.lang == "en" and e.file.stem == "store"}


def test_apply_review_end_to_end(tmp_path: Path) -> None:
    content = tmp_path / "content"
    shutil.copytree(CONTENT_DIR, content)
    entries = store_entries(content)
    subtitle, promo = entries["subtitle"], entries["promotionalText"]
    good = "Daily readings for your chart"
    rows = [make_row(subtitle, good), make_row(promo, promo.text + " Calm·clear.")]
    store_file = content / "en" / "store.yaml"
    before = store_file.read_text(encoding="utf-8")

    dry = apply_review(content, rows, "en", check, dry_run=True)
    assert store_file.read_text(encoding="utf-8") == before
    outcomes = apply_review(content, rows, "en", check, dry_run=False)

    assert [outcome.applied for outcome in dry] == [outcome.applied for outcome in outcomes] == [True, False]
    assert outcomes[1].reason.startswith("검사: style.S9")
    after = {key: entry.text for key, entry in store_entries(content).items()}
    assert after["subtitle"] == good
    assert after["promotionalText"] == promo.text


# 최종 리뷰 지적 재현 테스트


@pytest.mark.parametrize(
    ("current", "suggestion"),
    [
        ("[[火|five_element.fire]]の気が強い日", "火曜日は火の気が強い日"),
        ("Your [[Fire|five_element.fire]] side", "Your Firefly side"),
    ],
)
def test_rewind_tokens_rejects_ambiguous_or_partial_match(current: str, suggestion: str) -> None:
    assert rewind_tokens(current, suggestion) is None


def test_rewind_tokens_word_boundary_ok() -> None:
    assert rewind_tokens("Your [[Fire|e.fire]] side", "Your Fire, then") == "Your [[Fire|e.fire]], then"
    assert rewind_tokens("Your [[Fire|e.fire]] side", "Your Firefly-like Fire side") == "Your Firefly-like [[Fire|e.fire]] side"
    assert rewind_tokens("[[火|e.fire]]の気", "強い火の気") == "強い[[火|e.fire]]の気"


def _seed(tmp_path: Path) -> tuple[Path, list[Entry]]:
    content = tmp_path / "content"
    (content / "en").mkdir(parents=True)
    (content / "en" / "ui.yaml").write_text(
        '- {slot: s, key: a, text: "Alpha"}\n- {slot: s, key: b, text: "Beta"}\n- {slot: s, key: c, text: "Gamma"}\n',
        encoding="utf-8",
    )
    return content, load_content(content)


def _fake_check(rule: Callable[[Path, str], list[Finding]]) -> Callable[[Path], list[Finding]]:
    def check(content_dir: Path) -> list[Finding]:
        path = content_dir / "en" / "ui.yaml"
        return rule(path, path.read_text(encoding="utf-8"))

    return check


def test_error_on_other_line_rejects_its_cause(tmp_path: Path) -> None:
    content, entries = _seed(tmp_path)
    by_key = {entry.key: entry for entry in entries}

    def rule(path: Path, text: str) -> list[Finding]:
        # 묶음 상한처럼, 앞 줄의 표현이 뒤 줄 위치로 보고됩니다.
        return [Finding(path, 3, "limit.L1", "error", "too many")] if "Bad" in text else []

    rows = [make_row(by_key["a"], "Bad alpha"), make_row(by_key["b"], "Better beta")]
    outcomes = apply_review(content, rows, "en", _fake_check(rule), dry_run=False)
    assert [(o.applied, o.reason) for o in outcomes] == [
        (False, "검사: 다른 줄에 새 error limit.L1 too many"),
        (True, ""),
    ]
    assert yaml.safe_load((content / "en" / "ui.yaml").read_text(encoding="utf-8"))[0]["text"] == "Alpha"


def test_existing_error_with_new_count_is_not_new(tmp_path: Path) -> None:
    content, entries = _seed(tmp_path)

    def rule(path: Path, text: str) -> list[Finding]:
        length = len(yaml.safe_load(text)[0]["text"])
        return [Finding(path, 1, "length.max", "error", f"{length}자")]

    outcomes = apply_review(content, [make_row(entries[0], "Alph")], "en", _fake_check(rule), dry_run=True)
    assert outcomes[0].applied


def test_apply_review_over_length(tmp_path: Path) -> None:
    content = tmp_path / "content"
    shutil.copytree(CONTENT_DIR, content)
    subtitle = store_entries(content)["subtitle"]
    outcomes = apply_review(content, [make_row(subtitle, "Daily readings for your own birth chart today")], "en", check, dry_run=True)
    assert not outcomes[0].applied
    assert outcomes[0].reason.startswith("검사: ")


def test_write_texts_keeps_crlf(tmp_path: Path) -> None:
    path = tmp_path / "en" / "ui.yaml"
    path.parent.mkdir()
    path.write_bytes(b'# c\r\n- {slot: a, key: one, text: "One"}\r\n')
    write_texts(tmp_path, [Change(Path("en/ui.yaml"), 2, "Uno")])
    assert path.read_bytes() == b'# c\r\n- {slot: a, key: one, text: "Uno"}\r\n'


def test_prejudge_rejects_changed_cell_format() -> None:
    entry = make_entry("Half")
    row = ReviewRow(**{**make_row(entry, "0.5").__dict__, "suggestion_format_changed": True})
    _, outcomes = prejudge([row], {row_id(entry): entry})
    assert outcomes[0].reason == "Sheets가 셀 형식을 바꿈, 글자로 다시 입력"
