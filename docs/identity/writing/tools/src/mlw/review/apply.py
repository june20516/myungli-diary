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
from mlw.placeholders import parse, parse_tokens, strip_token_marks
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
REASON_OTHER_LINE: Final = "다른 줄에 새 error"
REASON_CELL_FORMAT: Final = "Sheets가 셀 형식을 바꿈, 글자로 다시 입력"

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


def _occurrences(text: str, needle: str) -> list[int]:
    """`needle`이 나오는 위치입니다. 라틴 글자나 숫자로 시작하거나 끝나면 단어 경계에서만 셉니다(Fire ≠ Firefly)."""
    before = r"(?<![A-Za-z0-9])" if needle[:1].isascii() and needle[:1].isalnum() else ""
    after = r"(?![A-Za-z0-9])" if needle[-1:].isascii() and needle[-1:].isalnum() else ""
    return [match.start() for match in re.finditer(before + re.escape(needle) + after, text)]


def rewind_tokens(current: str, suggestion: str) -> str | None:
    """수정안의 용어 토큰을 현재 번역에 맞춥니다.

    수정안에 토큰이 있으면 용어 id 묶음이 같을 때만 그대로 돌려줍니다. 없으면 현재 번역의 토큰마다 같은 표기를
    앞에서부터 차례로 찾아 원래 토큰으로 감쌉니다. 표기가 나오는 횟수가 현재 번역과 다르면(다른 낱말 안의 글자,
    같은 글자의 다른 쓰임) 어느 것이 용어인지 알 수 없으므로 None입니다.
    """
    try:
        current_tokens = parse_tokens(current)
        suggested_tokens = parse_tokens(suggestion)
        plain_current = strip_token_marks(current)
    except ValueError:
        return None
    if suggested_tokens:
        same = Counter(_token_id(t.text, t.term) for t in suggested_tokens) == Counter(
            _token_id(t.text, t.term) for t in current_tokens
        )
        return suggestion if same else None
    for text in {token.text for token in current_tokens}:
        if len(_occurrences(suggestion, text)) != len(_occurrences(plain_current, text)):
            return None
    position = 0
    for token in current_tokens:
        found = next((start for start in _occurrences(suggestion, token.text) if start >= position), None)
        if found is None:
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
    if row.suggestion_format_changed:
        return None, REASON_CELL_FORMAT
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


def _read_lines(path: Path) -> list[str]:
    """줄 끝(LF, CRLF)을 그대로 붙인 줄 목록입니다."""
    with path.open(encoding="utf-8", newline="") as file:
        return file.read().splitlines(keepends=True)


def _split_ending(line: str) -> tuple[str, str]:
    body = line.rstrip("\r\n")
    return body, line[len(body) :]


def write_texts(content_dir: Path, changes: Sequence[Change]) -> None:
    """원고 파일의 지정한 줄만 바꿉니다. 다른 줄과 줄 끝은 바이트 그대로 둡니다."""
    by_file: dict[Path, list[Change]] = {}
    for change in changes:
        by_file.setdefault(change.path, []).append(change)
    for relative, file_changes in by_file.items():
        path = content_dir / relative
        lines = _read_lines(path)
        for change in file_changes:
            body, ending = _split_ending(lines[change.line - 1])
            lines[change.line - 1] = replace_text_in_line(body, change.text) + ending
        with path.open("w", encoding="utf-8", newline="") as file:
            file.write("".join(lines))


def _relative(path: Path, root: Path) -> Path | None:
    try:
        return path.resolve().relative_to(root.resolve())
    except ValueError:
        return None


_FindingKey = tuple[Path, int, str]


def _finding_keys(findings: Sequence[Finding], root: Path) -> dict[_FindingKey, Finding]:
    """원고 디렉터리 안 error의 (상대 경로, 줄, 규칙) -> finding입니다. 메시지는 수치가 바뀌므로 키에 넣지 않습니다."""
    keys: dict[_FindingKey, Finding] = {}
    for finding in findings:
        relative = _relative(finding.file, root)
        if finding.severity == "error" and relative is not None:
            keys.setdefault((relative, finding.line, finding.rule_id), finding)
    return keys


def _format_checked(change: Change, content_dir: Path) -> bool:
    body, _ = _split_ending(_read_lines(content_dir / change.path)[change.line - 1])
    try:
        replace_text_in_line(body, change.text)
    except ValueError:
        return False
    return True


@dataclass(frozen=True)
class _Trial:
    # 바뀐 줄에 새 error가 생긴 행 id -> 이유
    rejected: dict[str, str]
    # 바뀐 줄이 아닌 곳에 생긴 첫 새 error(묶음 상한처럼 다른 줄로 보고되는 것)
    elsewhere: Finding | None


def _try_changes(content_dir: Path, changes: Mapping[str, Change], check: Check, baseline: set[_FindingKey]) -> _Trial:
    """변경을 임시 사본에 쓰고 검사해, 반영 전에 없던 error를 찾습니다."""
    by_line = {(change.path, change.line): row for row, change in changes.items()}
    with tempfile.TemporaryDirectory() as tmp:
        copy = Path(tmp) / "content"
        shutil.copytree(content_dir, copy)
        write_texts(copy, list(changes.values()))
        found = _finding_keys(check(copy), copy)
    rejected: dict[str, str] = {}
    elsewhere: Finding | None = None
    for key in sorted(set(found) - baseline):
        finding = found[key]
        row = by_line.get((key[0], key[1]))
        if row is None:
            elsewhere = elsewhere or finding
        elif row not in rejected:
            rejected[row] = f"{REASON_CHECK}: {finding.rule_id} {finding.message}"
    return _Trial(rejected, elsewhere)


def _accept_one_by_one(
    content_dir: Path, changes: Mapping[str, Change], check: Check, baseline: set[_FindingKey]
) -> tuple[dict[str, Change], dict[str, str]]:
    """다른 줄에 새 error가 생길 때, 변경을 하나씩 더해 보며 그 error를 만든 변경을 찾아 뺍니다."""
    accepted: dict[str, Change] = {}
    rejected: dict[str, str] = {}
    for row, change in changes.items():
        trial = _try_changes(content_dir, {**accepted, row: change}, check, baseline)
        if row in trial.rejected:
            rejected[row] = trial.rejected[row]
        elif trial.rejected or trial.elsewhere is not None:
            finding = trial.elsewhere
            detail = f"{finding.rule_id} {finding.message}" if finding is not None else next(iter(trial.rejected.values()))
            rejected[row] = f"{REASON_CHECK}: {REASON_OTHER_LINE} {detail}"
        else:
            accepted[row] = change
    return accepted, rejected


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
        baseline = set(_finding_keys(check(content_dir), content_dir))
        while changes:
            trial = _try_changes(content_dir, changes, check, baseline)
            if trial.rejected:
                for row, reason in trial.rejected.items():
                    outcomes[row] = Outcome(row, False, reason)
                    del changes[row]
                continue
            if trial.elsewhere is not None:
                changes, rejected = _accept_one_by_one(content_dir, changes, check, baseline)
                for row, reason in rejected.items():
                    outcomes[row] = Outcome(row, False, reason)
            break
    for row in changes:
        outcomes[row] = Outcome(row, True)
    if not dry_run:
        write_texts(content_dir, list(changes.values()))
    order = list(dict.fromkeys(row.id for row in rows if row.suggestion))
    return [outcomes[row] for row in order if row in outcomes]
