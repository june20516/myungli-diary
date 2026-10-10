"""저장소 문서 검사: 상대 링크, artifacts/index.json 형식, 결정 번호 중복, IA 계약, 아이디어 함.

실행: python3 -I tools/docs-check/docs_check.py [저장소 루트]
규칙 근거: docs/workflow.md §7, docs/specs/2026-10-10-collab-workflow-design.md §4.1,
          docs/specs/2026-10-11-ia-design.md §5·§9 (IA),
          docs/specs/2026-10-11-m0-monetization-design.md §3.3·§3.6 (아이디어 함)
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

IA_PATH = "docs/ia/screens.json"
IA_ID_PATTERN = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
IA_SLOT_PATTERN = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+(-[a-z0-9]+)*){2,}")
IA_PRESENTATIONS = {"page", "half-sheet", "full-sheet", "system"}
IA_AUTHS = {"guest", "member", "any"}
IA_DEPTHS = {"surface", "explain", "evidence"}
IA_STATES = {"loading", "empty", "error", "offline", "draft", "time-unknown", "out-of-range"}
IA_SLOT_SOURCES = {"content", "ui"}
IA_ADDRESS_MARK = "호칭 자리"
IA_SCREEN_FIELDS = {
    "id": str, "title": str, "tab": (str, type(None)), "presentation": str, "auth": str,
    "purpose": str, "depths": list, "states": list, "slots": list,
    "components": list, "exits": list, "decisions": list,
}

IDEAS_PATH = "docs/ideas.md"
IDEA_COLUMNS = ("id", "날짜", "아이디어", "출처", "범위", "수익", "상태", "메모")
IDEA_ID_PATTERN = re.compile(r"I[1-9]\d*")
IDEA_SOURCE_PATTERN = re.compile(r"사용자|조사|Issue #\d+")
IDEA_SCOPES = {"MVP", "Phase 2", "미정"}
IDEA_REVENUES = {"무관", "무료", "유료 후보", "미정"}
IDEA_STATUS_PATTERN = re.compile(r"대기|보류|기각|채택 (D\d+)|검토 (\S+)")
UNESCAPED_PIPE = re.compile(r"(?<!\\)\|")


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


def _decision_ids(root: Path) -> set[str]:
    return {
        decision_id
        for log in _files(root, "decisions.md")
        for decision_id in DECISION_ROW_PATTERN.findall(log.read_text(encoding="utf-8"))
    }


def _ia_objects(items: object, label: str) -> tuple[list[dict], list[str]]:
    """목록에서 객체 항목만 고르고, 목록이 아니거나 객체가 아닌 항목은 문제로 돌려줍니다."""
    if not isinstance(items, list):
        return [], [f"{label}: 배열이어야 합니다"]
    objects = [item for item in items if isinstance(item, dict)]
    problems = [f"{label}: 항목은 객체여야 합니다"] * (len(items) - len(objects))
    return objects, problems


def _ia_known(value: object, allowed: set[str]) -> bool:
    """값이 문자열이고 허용 목록에 있는지. 리스트·dict 값도 예외 없이 거짓으로 봅니다."""
    return isinstance(value, str) and value in allowed


def _ia_text(value: object) -> bool:
    return isinstance(value, str) and value.strip() != ""


def _check_ia_catalog(items: object, name: str) -> tuple[list[dict], list[str]]:
    """tabs·components 공통: 객체 여부, id 형식·중복, 필수 문자열 필드."""
    required = ("id", "title", "root") if name == "tabs" else ("id", "role")
    objects, problems = _ia_objects(items, name)
    seen: set[str] = set()
    for item in objects:
        item_id = item.get("id")
        for field in required:
            if not _ia_text(item.get(field)):
                problems.append(f"{name} [{item_id}]: {field} 없음 또는 빈 문자열")
        if isinstance(item_id, str):
            if not IA_ID_PATTERN.fullmatch(item_id):
                problems.append(f"{name} [{item_id}]: id 형식")
            if item_id in seen:
                problems.append(f"{name} [{item_id}]: id 중복")
            seen.add(item_id)
    return objects, problems


def _check_ia_screen(
    screen: dict, tab_ids: set[str], component_ids: set[str],
    screen_ids: set[str], decision_ids: set[str], slot_ids: set[str],
) -> list[str]:
    problems = []
    for field, kind in IA_SCREEN_FIELDS.items():
        if field not in screen:
            problems.append(f"{field} 없음")
        elif not isinstance(screen[field], kind):
            problems.append(f"{field} 타입 오류")
    valid = {f for f, kind in IA_SCREEN_FIELDS.items() if f in screen and isinstance(screen[f], kind)}
    screen_id = screen.get("id") if "id" in valid else None

    if screen_id is not None and not IA_ID_PATTERN.fullmatch(screen_id):
        problems.append("id 형식")
    for field in ("title", "purpose"):
        if field in valid and not _ia_text(screen[field]):
            problems.append(f"{field} 빈 문자열")
    if "tab" in valid and screen["tab"] is not None and not _ia_known(screen["tab"], tab_ids):
        problems.append(f"없는 탭: {screen['tab']}")
    if "presentation" in valid and not _ia_known(screen["presentation"], IA_PRESENTATIONS):
        problems.append(f"presentation 값 오류: {screen['presentation']}")
    if "auth" in valid and not _ia_known(screen["auth"], IA_AUTHS):
        problems.append(f"auth 값 오류: {screen['auth']}")
    if "depths" in valid:
        problems.extend(f"depths 값 오류: {d}" for d in screen["depths"] if not _ia_known(d, IA_DEPTHS))
    if "states" in valid:
        states, state_problems = _ia_objects(screen["states"], "states")
        problems.extend(state_problems)
        problems.extend(
            f"states 값 오류: {state.get('id')}" for state in states if not _ia_known(state.get("id"), IA_STATES)
        )
    if "components" in valid:
        problems.extend(
            f"없는 컴포넌트: {c}" for c in screen["components"] if not _ia_known(c, component_ids)
        )
    if "decisions" in valid:
        problems.extend(
            f"결정 로그에 없는 ID: {d}" for d in screen["decisions"] if not _ia_known(d, decision_ids)
        )
    if "exits" in valid:
        exits, exit_problems = _ia_objects(screen["exits"], "exits")
        problems.extend(exit_problems)
        for exit_ in exits:
            if not _ia_known(exit_.get("to"), screen_ids):
                problems.append(f"exits의 없는 화면: {exit_.get('to')}")
            if not _ia_text(exit_.get("trigger")):
                problems.append(f"exits [{exit_.get('to')}]: trigger 없음")
    if "slots" in valid:
        slots, slot_problems = _ia_objects(screen["slots"], "slots")
        problems.extend(slot_problems)
        address_count = 0
        for slot in slots:
            slot_id = slot.get("id")
            if not isinstance(slot_id, str) or not IA_SLOT_PATTERN.fullmatch(slot_id):
                problems.append(f"슬롯 id 형식: {slot_id}")
            else:
                if screen_id is not None and not slot_id.startswith(f"{screen_id}."):
                    problems.append(f"슬롯 {slot_id}: 화면 id로 시작해야 합니다")
                if slot_id in slot_ids:
                    problems.append(f"슬롯 id 중복: {slot_id}")
                slot_ids.add(slot_id)
            if not _ia_known(slot.get("source"), IA_SLOT_SOURCES):
                problems.append(f"슬롯 {slot_id}: source 값 오류: {slot.get('source')}")
            role = slot.get("role")
            if not _ia_text(role):
                problems.append(f"슬롯 {slot_id}: role 없음")
            elif IA_ADDRESS_MARK in role:
                address_count += 1
        if address_count > 1:
            problems.append(f"{IA_ADDRESS_MARK}가 {address_count}곳입니다(많아야 한 곳)")
    return problems


def check_ia(root: Path) -> list[str]:
    path = root / IA_PATH
    if not path.exists():
        return []
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        return [f"{IA_PATH}: JSON 형식 오류 ({error})"]
    if not isinstance(doc, dict) or not {"version", "tabs", "components", "screens"} <= doc.keys():
        return [f"{IA_PATH}: 최상위는 객체여야 하고 version·tabs·components·screens가 있어야 합니다"]

    problems = []
    version = doc["version"]
    if type(version) is not int or version < 1:
        problems.append(f"version은 1 이상의 정수여야 합니다: {version!r}")
    tabs, tab_problems = _check_ia_catalog(doc["tabs"], "tabs")
    components, component_problems = _check_ia_catalog(doc["components"], "components")
    screens, screen_problems = _ia_objects(doc["screens"], "screens")
    problems += tab_problems + component_problems + screen_problems

    screen_ids: set[str] = set()
    for screen in screens:
        screen_id = screen.get("id")
        if isinstance(screen_id, str):
            if screen_id in screen_ids:
                problems.append(f"[{screen_id}]: 화면 id 중복")
            screen_ids.add(screen_id)
    problems.extend(
        f"tabs [{tab.get('id')}]: root가 없는 화면: {tab.get('root')}"
        for tab in tabs if not _ia_known(tab.get("root"), screen_ids)
    )

    tab_ids = {tab["id"] for tab in tabs if isinstance(tab.get("id"), str)}
    component_ids = {c["id"] for c in components if isinstance(c.get("id"), str)}
    decision_ids = _decision_ids(root)
    slot_ids: set[str] = set()
    for screen in screens:
        label = f"[{screen.get('id', '?')}]"
        problems.extend(
            f"{label}: {reason}"
            for reason in _check_ia_screen(
                screen, tab_ids, component_ids, screen_ids, decision_ids, slot_ids
            )
        )
    return [p if p.startswith(IA_PATH) else f"{IA_PATH} {p}" for p in problems]


def _idea_cells(line: str) -> list[str]:
    return [cell.strip() for cell in UNESCAPED_PIPE.split(line.strip().strip("|"))]


def _idea_rows(text: str) -> list[list[str]] | None:
    """머리가 IDEA_COLUMNS인 첫 표의 데이터 행. 표가 없으면 None."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.startswith("|") and tuple(_idea_cells(line)) == IDEA_COLUMNS:
            rows = []
            for row in lines[index + 2:]:
                if not row.startswith("|"):
                    break
                rows.append(_idea_cells(row))
            return rows
    return None


def _review_doc_exists(root: Path, relative: str) -> bool:
    if Path(relative).is_absolute():
        return False
    target = (root / relative).resolve()
    return target.is_relative_to(root.resolve()) and target.is_file()


def _check_idea_row(
    cells: list[str], root: Path, decision_ids: set[str], seen: set[str]
) -> list[str]:
    if len(cells) != len(IDEA_COLUMNS):
        return [f"칸 수가 {len(IDEA_COLUMNS)}이 아닙니다 ({len(cells)})"]
    idea_id, _, _, source, scope, revenue, status, _ = cells
    problems = []
    if not IDEA_ID_PATTERN.fullmatch(idea_id):
        problems.append("id 형식은 I<숫자>입니다")
    elif idea_id in seen:
        problems.append("id 중복")
    seen.add(idea_id)
    if not IDEA_SOURCE_PATTERN.fullmatch(source):
        problems.append(f"출처 값이 아닙니다: {source}")
    if scope not in IDEA_SCOPES:
        problems.append(f"범위 값이 아닙니다: {scope}")
    if revenue not in IDEA_REVENUES:
        problems.append(f"수익 값이 아닙니다: {revenue}")
    match = IDEA_STATUS_PATTERN.fullmatch(status)
    if not match:
        problems.append(f"상태 값이 아닙니다: {status}")
    elif match.group(1) and match.group(1) not in decision_ids:
        problems.append(f"없는 결정: {match.group(1)}")
    elif match.group(2) and not _review_doc_exists(root, match.group(2)):
        problems.append(f"검토 문서가 없습니다: {match.group(2)}")
    return problems


def check_ideas(root: Path) -> list[str]:
    path = root / IDEAS_PATH
    if not path.exists():
        return []
    rows = _idea_rows(path.read_text(encoding="utf-8"))
    if rows is None:
        return [f"{IDEAS_PATH}: 아이디어 표가 없습니다 (머리: {' | '.join(IDEA_COLUMNS)})"]
    decision_ids = _decision_ids(root)
    seen: set[str] = set()
    return [
        f"{IDEAS_PATH} [{cells[0]}]: {reason}"
        for cells in rows
        for reason in _check_idea_row(cells, root, decision_ids, seen)
    ]


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path.cwd()
    problems = (
        check_links(root) + check_artifacts(root) + check_decision_ids(root) + check_ia(root)
        + check_ideas(root)
    )
    if problems:
        print("\n".join(problems))
        return 1
    print("OK: docs 검사 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
