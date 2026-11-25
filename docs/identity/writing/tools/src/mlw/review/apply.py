"""돌아온 검수 시트의 수정안을 판정하고 원고에 반영합니다(#1283, spec §5)."""

import re
import shutil
import tempfile
from collections import Counter
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Final

import yaml

from mlw.icu import parse_plural
from mlw.loader import load_content
from mlw.model import Entry, Finding
from mlw.placeholders import parse, parse_tokens
from mlw.review.export import row_id
from mlw.review.sheet import ReviewRow

APPLIED: Final = "반영함"
NOT_APPLIED: Final = "반영 안 함"
REASON_VERDICT: Final = "writing 판정"
REASON_MISSING: Final = "원고에 없는 줄"
REASON_DUPLICATE: Final = "같은 줄이 두 번"
REASON_STALE: Final = "내보낸 뒤 원고가 바뀜, 다시 확인"
REASON_PLACEHOLDER: Final = "자리표시자가 바뀜"
REASON_TERM: Final = "용어 표기가 바뀜, writing이 직접 반영"
REASON_UNCHANGED: Final = "변경 없음"
REASON_FORMAT: Final = "원고 줄 형식을 바꿀 수 없음"
REASON_CHECK: Final = "검사"

# 한 줄 flow mapping 원고의 큰따옴표 `text` 값입니다.
_TEXT_FIELD: Final = re.compile(r'text: "(?:[^"\\]|\\.)*"')

Check = Callable[[Path], list[Finding]]


@dataclass(frozen=True)
class Outcome:
    row_id: str
    applied: bool
    reason: str = ""

    @property
    def text(self) -> str:
        """결과 시트 `반영 결과` 칸 값입니다."""
        return APPLIED if self.applied else f"{NOT_APPLIED}: {self.reason}"


@dataclass(frozen=True)
class Change:
    """원고 파일 한 줄의 `text`를 바꾸는 일입니다. `path`는 원고 디렉터리 기준 상대 경로입니다."""

    path: Path
    line: int
    text: str


def _token_id(text: str, term: str | None) -> str:
    return term if term is not None else text


def rewind_tokens(current: str, suggestion: str) -> str | None:
    """수정안의 용어 토큰을 현재 번역에 맞춥니다.

    수정안에 토큰이 있으면 용어 id 묶음이 같을 때만 그대로 돌려줍니다. 없으면 현재 번역의 토큰마다 같은 표기를
    앞에서부터 차례로 찾아 원래 토큰으로 감쌉니다. 맞출 수 없으면 None입니다.
    """
    try:
        current_tokens = parse_tokens(current)
        suggested_tokens = parse_tokens(suggestion)
    except ValueError:
        return None
    if suggested_tokens:
        same = Counter(_token_id(t.text, t.term) for t in suggested_tokens) == Counter(
            _token_id(t.text, t.term) for t in current_tokens
        )
        return suggestion if same else None
    position = 0
    for token in current_tokens:
        found = suggestion.find(token.text, position)
        if found < 0:
            return None
        mark = current[token.start : token.end]
        suggestion = suggestion[:found] + mark + suggestion[found + len(token.text) :]
        position = found + len(mark)
    return suggestion


def _placeholder_signature(text: str) -> tuple[object, ...]:
    """자리표시자와 복수형 구조의 비교용 값입니다. 문법이 틀리면 ValueError입니다."""
    plural = parse_plural(text)
    if plural is None:
        return ("plain", tuple(sorted(placeholder.key for placeholder in parse(text))))
    outside = sorted(placeholder.key for placeholder in parse(plural.prefix + plural.suffix))
    forms = tuple(
        (form, tuple(sorted(placeholder.key for placeholder in parse(sentence))))
        for form, sentence in sorted(plural.forms.items())
    )
    return ("plural", plural.variable, tuple(outside), forms)


def _same_placeholders(current: str, suggestion: str) -> bool:
    try:
        return _placeholder_signature(current) == _placeholder_signature(suggestion)
    except ValueError:
        return False


def _judge_row(row: ReviewRow, entry: Entry | None) -> tuple[str | None, str]:
    """(쓸 새 text, 이유)입니다. 새 text가 None이면 반영하지 않습니다."""
    if row.verdict:
        return None, f"{REASON_VERDICT}: {row.verdict}"
    if entry is None:
        return None, REASON_MISSING
    if row.current != entry.text:
        return None, REASON_STALE
    rewound = rewind_tokens(entry.text, row.suggestion)
    if rewound is None:
        return None, REASON_TERM
    if not _same_placeholders(entry.text, rewound):
        return None, REASON_PLACEHOLDER
    if rewound == entry.text:
        return None, REASON_UNCHANGED
    return rewound, ""


def prejudge(rows: Sequence[ReviewRow], entries_by_id: Mapping[str, Entry]) -> tuple[dict[str, str], list[Outcome]]:
    """원고를 쓰기 전에 판정합니다. (id -> 쓸 새 text, 미리 걸린 결과)이고, 수정안이 빈 행은 어느 쪽에도 없습니다."""
    counts = Counter(row.id for row in rows)
    changes: dict[str, str] = {}
    outcomes: list[Outcome] = []
    seen: set[str] = set()
    for row in rows:
        if not row.suggestion or row.id in seen:
            continue
        seen.add(row.id)
        if counts[row.id] > 1:
            outcomes.append(Outcome(row.id, False, REASON_DUPLICATE))
            continue
        text, reason = _judge_row(row, entries_by_id.get(row.id))
        if text is None:
            outcomes.append(Outcome(row.id, False, reason))
        else:
            changes[row.id] = text
    return changes, outcomes


def _quoted(text: str) -> str:
    dumped = yaml.dump(text, default_style='"', allow_unicode=True, width=10**9)
    return dumped.removesuffix("\n").removesuffix("\n...").rstrip("\n")


def replace_text_in_line(line: str, new_text: str) -> str:
    """한 줄 원고의 큰따옴표 `text` 값만 바꿉니다. 형식이 다르거나 다시 읽은 값이 다르면 ValueError입니다."""
    if len(_TEXT_FIELD.findall(line)) != 1:
        raise ValueError(f"{REASON_FORMAT}: {line!r}")
    replaced = _TEXT_FIELD.sub(lambda _: f"text: {_quoted(new_text)}", line)
    loaded = yaml.safe_load(replaced)
    if not isinstance(loaded, list) or not loaded or not isinstance(loaded[0], dict) or loaded[0].get("text") != new_text:
        raise ValueError(f"{REASON_FORMAT}: {line!r}")
    return replaced


def write_texts(content_dir: Path, changes: Sequence[Change]) -> None:
    """원고 파일의 지정한 줄만 바꿉니다. 다른 줄은 바이트 그대로 둡니다."""
    by_file: dict[Path, list[Change]] = {}
    for change in changes:
        by_file.setdefault(change.path, []).append(change)
    for relative, file_changes in by_file.items():
        path = content_dir / relative
        lines = path.read_text(encoding="utf-8").split("\n")
        for change in file_changes:
            lines[change.line - 1] = replace_text_in_line(lines[change.line - 1], change.text)
        path.write_text("\n".join(lines), encoding="utf-8")


def _relative(path: Path, root: Path) -> Path | None:
    try:
        return path.resolve().relative_to(root.resolve())
    except ValueError:
        return None


def _finding_keys(findings: Sequence[Finding], root: Path) -> set[tuple[Path, int, str, str]]:
    keys: set[tuple[Path, int, str, str]] = set()
    for finding in findings:
        relative = _relative(finding.file, root)
        if finding.severity == "error" and relative is not None:
            keys.add((relative, finding.line, finding.rule_id, finding.message))
    return keys


def _format_checked(change: Change, content_dir: Path) -> bool:
    line = (content_dir / change.path).read_text(encoding="utf-8").split("\n")[change.line - 1]
    try:
        replace_text_in_line(line, change.text)
    except ValueError:
        return False
    return True


def _new_errors(content_dir: Path, changes: Mapping[str, Change], check: Check, baseline: set[tuple[Path, int, str, str]]) -> dict[str, str]:
    """변경을 임시 사본에 쓰고 검사해, 바뀐 줄에 새로 생긴 error가 있는 행 id -> 이유입니다."""
    by_line = {(change.path, change.line): row for row, change in changes.items()}
    with tempfile.TemporaryDirectory() as tmp:
        copy = Path(tmp) / "content"
        shutil.copytree(content_dir, copy)
        write_texts(copy, list(changes.values()))
        found = _finding_keys(check(copy), copy)
    rejected: dict[str, str] = {}
    for path, line, rule_id, message in sorted(found - baseline):
        row = by_line.get((path, line))
        if row is not None and row not in rejected:
            rejected[row] = f"{REASON_CHECK}: {rule_id} {message}"
    return rejected


def apply_review(
    content_dir: Path, rows: Sequence[ReviewRow], lang: str, check: Check, *, dry_run: bool
) -> list[Outcome]:
    """수정안을 판정해 통과한 것만 원고에 씁니다. 결과는 수정안이 있는 행마다 하나, 시트 행 순서입니다."""
    entries = {row_id(entry): entry for entry in load_content(content_dir) if entry.lang == lang}
    texts, early = prejudge(rows, entries)
    outcomes = {outcome.row_id: outcome for outcome in early}
    changes: dict[str, Change] = {}
    for row, text in texts.items():
        entry = entries[row]
        change = Change(entry.file.resolve().relative_to(content_dir.resolve()), entry.line, text)
        if _format_checked(change, content_dir):
            changes[row] = change
        else:
            outcomes[row] = Outcome(row, False, REASON_FORMAT)
    if changes:
        baseline = _finding_keys(check(content_dir), content_dir)
        while changes:
            rejected = _new_errors(content_dir, changes, check, baseline)
            if not rejected:
                break
            for row, reason in rejected.items():
                outcomes[row] = Outcome(row, False, reason)
                del changes[row]
    for row in changes:
        outcomes[row] = Outcome(row, True)
    if not dry_run:
        write_texts(content_dir, list(changes.values()))
    order = list(dict.fromkeys(row.id for row in rows if row.suggestion))
    return [outcomes[row] for row in order if row in outcomes]
