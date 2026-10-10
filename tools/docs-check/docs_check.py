"""저장소 문서 검사: 상대 링크, artifacts/index.json 형식, 결정 번호 중복.

실행: python3 -I tools/docs-check/docs_check.py [저장소 루트]
규칙 근거: docs/workflow.md §7, docs/specs/2026-10-10-collab-workflow-design.md §4.1
"""

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote

SKIPPED_DIRS = {".git", ".suberpowers", ".venv", "node_modules"}
LINK_PATTERN = re.compile(r'\]\(([^)\s]+?)(?:\s+"[^"]*")?\)')
EXTERNAL_PATTERN = re.compile(r"[a-z]+://")
DECISION_ROW_PATTERN = re.compile(r"^\| ([DCSAWV]\d+) \|", re.MULTILINE)
FENCED_CODE_PATTERN = re.compile(r"^[ \t]{0,3}(```|~~~).*?^[ \t]{0,3}\1", re.MULTILINE | re.DOTALL)
INLINE_CODE_PATTERN = re.compile(r"`[^`\n]*`")

ARTIFACT_FIELDS = (
    "id", "title", "kind", "file", "date", "milestone",
    "screens", "decisions", "status", "note",
)
ARTIFACT_KINDS = {"concept", "mockup", "component", "screenshot", "token-sheet", "copy-sample"}
ARTIFACT_STATUSES = {"draft", "chosen", "rejected", "superseded"}


def _files(root: Path, pattern: str) -> list[Path]:
    return sorted(
        path for path in root.rglob(pattern)
        if not SKIPPED_DIRS.intersection(path.relative_to(root).parts)
    )


def check_links(root: Path) -> list[str]:
    problems = []
    for md in _files(root, "*.md"):
        text = md.read_text(encoding="utf-8")
        prose = INLINE_CODE_PATTERN.sub("", FENCED_CODE_PATTERN.sub("", text))
        for raw in LINK_PATTERN.findall(prose):
            if EXTERNAL_PATTERN.match(raw) or raw.startswith("mailto:"):
                continue
            target = unquote(raw.split("#", 1)[0])
            if not target:
                continue
            base = root if target.startswith("/") else md.parent
            if not (base / target.lstrip("/")).exists():
                problems.append(f"{md.relative_to(root)}: {target}")
    return problems


def _check_artifact_entry(entry: dict[str, object], index_dir: Path) -> list[str]:
    reasons = [f"{field} 필드 없음" for field in ARTIFACT_FIELDS if field not in entry]
    for field, allowed in (("kind", ARTIFACT_KINDS), ("status", ARTIFACT_STATUSES)):
        value = entry.get(field)
        if field in entry and (not isinstance(value, str) or value not in allowed):
            reasons.append(f"{field} 값 오류: {value!r}")
    if "id" in entry and not isinstance(entry["id"], str):
        reasons.append(f"id 값은 문자열이어야 합니다: {entry['id']!r}")
    for field in ("file", "source"):
        if field not in entry:
            continue
        name = entry[field]
        if not isinstance(name, str) or not name:
            reasons.append(f"{field} 값은 비어 있지 않은 문자열이어야 합니다")
        elif not (index_dir / name).is_file():
            reasons.append(f"{field} 파일 없음: {name}")
    for field in ("screens", "decisions"):
        if field in entry and not isinstance(entry[field], list):
            reasons.append(f"{field} 값은 배열이어야 합니다")
    return reasons


def check_artifacts(root: Path) -> list[str]:
    problems = []
    for index in _files(root, "index.json"):
        if index.parent.name != "artifacts":
            continue
        label = index.relative_to(root)
        try:
            entries = json.loads(index.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            problems.append(f"{label}: JSON 형식 오류 ({error})")
            continue
        if not isinstance(entries, list):
            problems.append(f"{label}: 최상위는 배열이어야 합니다")
            continue
        seen: set[str] = set()
        for entry in entries:
            if not isinstance(entry, dict):
                problems.append(f"{label} [?]: 항목은 객체여야 합니다")
                continue
            raw_id = entry.get("id", "?")
            entry_id = raw_id if isinstance(raw_id, str) else repr(raw_id)
            if isinstance(raw_id, str):
                if entry_id in seen:
                    problems.append(f"{label} [{entry_id}]: id 중복")
                seen.add(entry_id)
            problems.extend(
                f"{label} [{entry_id}]: {reason}"
                for reason in _check_artifact_entry(entry, index.parent)
            )
    return problems


def check_decision_ids(root: Path) -> list[str]:
    problems = []
    for log in _files(root, "decisions.md"):
        seen: set[str] = set()
        for decision_id in DECISION_ROW_PATTERN.findall(log.read_text(encoding="utf-8")):
            if decision_id in seen:
                problems.append(f"{log.relative_to(root)}: {decision_id} 중복")
            seen.add(decision_id)
    return problems


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path.cwd()
    problems = check_links(root) + check_artifacts(root) + check_decision_ids(root)
    if problems:
        print("\n".join(problems))
        return 1
    print("OK: docs 검사 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
