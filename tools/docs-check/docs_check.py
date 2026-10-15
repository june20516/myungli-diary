"""저장소 문서 검사: 상대 링크, artifacts/index.json 형식, 결정 번호 중복, IA 계약, 아이디어 함, ja 근거 용어집.

실행: python3 -I tools/docs-check/docs_check.py [저장소 루트]
규칙 근거: docs/workflow.md §7, docs/specs/2026-10-10-collab-workflow-design.md §4.1,
          docs/specs/2026-10-11-ia-design.md §5·§9 (IA),
          아이디어 함 규칙은 비공개 내부 저장소의 ideas.md(D74). 공개 저장소에 docs/ideas.md가 없으면 건너뜁니다,
          docs/research/ja-terms/README.md (ja 근거 용어집, D70)
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

# 아이디어 표 파싱 규칙은 tools/product-map/build_map_data.py와 같습니다. 바꾸면 그쪽도 바꿉니다.
IDEAS_PATH = "docs/ideas.md"
IDEA_COLUMNS = ("id", "날짜", "아이디어", "출처", "범위", "수익", "상태", "메모")
IDEA_ID_PATTERN = re.compile(r"I[1-9]\d*")
IDEA_SOURCE_PATTERN = re.compile(r"사용자|조사|Issue #\d+")
IDEA_SCOPES = {"MVP", "Phase 2", "미정"}
IDEA_REVENUES = {"무관", "무료", "유료 후보", "미정"}
IDEA_STATUS_PATTERN = re.compile(r"대기|보류|기각|채택 (D\d+)|검토 (\S+)")
UNESCAPED_PIPE = re.compile(r"(?<!\\)\|")
TABLE_SEPARATOR = re.compile(r"\|(\s*:?-+:?\s*\|)+")
IDEA_DATE_PATTERN = re.compile(r"\d{4}-\d{2}-\d{2}")

# ja 근거 용어집(D70). 출처 종류별 등급과 신뢰도 규칙은 docs/research/ja-terms/README.md와 같습니다.
JA_TERMS_DIR = "docs/research/ja-terms"
GLOSSARY_PATH = "docs/identity/writing/slots/content/glossary.yaml"
GLOSSARY_KEY_PATTERN = re.compile(r"^\s+- ([a-z_]+\.[a-z_0-9]+)\s*$", re.MULTILINE)
JA_TERM_ID_PATTERN = re.compile(r"[a-z_]+\.[a-z_0-9]+")
JA_SOURCE_FIELDS = ("id", "kind", "publisher", "title", "url", "accessed")
JA_SOURCE_TIERS = {
    "dictionary": "A", "book": "A", "academic": "A",
    "school": "B", "software": "B", "app": "B",
    "media": "C", "wiki": "C", "blog": "C",
}


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
    body = line.strip()
    body = body[1:] if body.startswith("|") else body
    body = body[:-1] if body.endswith("|") and not body.endswith("\\|") else body
    return [cell.strip() for cell in UNESCAPED_PIPE.split(body)]


def _idea_rows(text: str) -> list[list[str]] | None:
    """머리가 IDEA_COLUMNS인 첫 표의 데이터 행. 표가 없으면 None."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.startswith("|") and tuple(_idea_cells(line)) == IDEA_COLUMNS:
            separator = lines[index + 1].strip() if index + 1 < len(lines) else ""
            if not TABLE_SEPARATOR.fullmatch(separator):
                continue
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
    idea_id, date, _, source, scope, revenue, status, memo = cells
    problems = []
    if not IDEA_ID_PATTERN.fullmatch(idea_id):
        problems.append("id 형식은 I<숫자>입니다")
    elif idea_id in seen:
        problems.append("id 중복")
    seen.add(idea_id)
    if not IDEA_DATE_PATTERN.fullmatch(date):
        problems.append(f"날짜 형식은 YYYY-MM-DD입니다: {date}")
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
    if status in ("보류", "기각") and not memo:
        problems.append("보류·기각은 메모에 이유를 적습니다")
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


def _glossary_keys(root: Path) -> set[str] | None:
    path = root / GLOSSARY_PATH
    if not path.exists():
        return None
    return set(GLOSSARY_KEY_PATTERN.findall(path.read_text(encoding="utf-8")))


def _ja_source_problems(source: object, seen: dict[str, dict]) -> list[str]:
    if not isinstance(source, dict):
        return ["출처 항목이 객체가 아닙니다"]
    source_id = source.get("id")
    label = f"출처 {source_id}"
    problems = [
        f"{label}: {field} 필드가 비었습니다"
        for field in JA_SOURCE_FIELDS
        if not _ia_text(source.get(field))
    ]
    if not isinstance(source_id, str) or not source_id:
        return problems
    if source_id in seen:
        problems.append(f"{label}: id가 중복입니다")
    if source.get("kind") not in JA_SOURCE_TIERS:
        problems.append(f"{label}: kind는 {', '.join(sorted(JA_SOURCE_TIERS))} 중 하나여야 합니다")
    if _ia_text(source.get("url")) and not EXTERNAL_PATTERN.match(source["url"]):
        problems.append(f"{label}: url이 주소가 아닙니다")
    if _ia_text(source.get("accessed")) and not IDEA_DATE_PATTERN.fullmatch(source["accessed"]):
        problems.append(f"{label}: accessed는 YYYY-MM-DD입니다")
    seen[source_id] = source
    return problems


def ja_term_confidence(term: dict, sources: dict[str, dict]) -> str:
    """ja 표기를 뒷받침하는 근거의 발행처 수와 등급으로 신뢰도를 계산합니다(README의 규칙)."""
    if term.get("coined"):
        return "자체"
    ja = term.get("ja")
    if not ja:
        return "미정"
    publishers: set[str] = set()
    tiers: set[str] = set()
    for evidence in term.get("evidence") or []:
        source = sources.get(evidence.get("source")) if isinstance(evidence, dict) else None
        tier = JA_SOURCE_TIERS.get(source.get("kind")) if source else None
        if tier is None or evidence.get("form") != ja:
            continue
        publishers.add(source.get("publisher"))
        tiers.add(tier)
    if len(publishers) >= 2 and "A" in tiers:
        return "상"
    if len(publishers) >= 2 or "A" in tiers:
        return "중"
    return "하"


def _ja_term_problems(
    term: object, sources: dict[str, dict], glossary: set[str] | None, seen: set[str]
) -> list[str]:
    if not isinstance(term, dict):
        return ["용어 항목이 객체가 아닙니다"]
    term_id = term.get("id")
    label = f"용어 {term_id}"
    problems: list[str] = []
    if not isinstance(term_id, str) or not JA_TERM_ID_PATTERN.fullmatch(term_id):
        problems.append(f"{label}: id는 <범주>.<값> 소문자입니다")
    elif term_id in seen:
        problems.append(f"{label}: id가 중복입니다")
    else:
        seen.add(term_id)
    if not _ia_text(term.get("ko")):
        problems.append(f"{label}: ko가 비었습니다")
    key = term.get("glossary_key")
    if key is not None and glossary is not None and key not in glossary:
        problems.append(f"{label}: glossary_key {key}가 {GLOSSARY_PATH}에 없습니다")
    ja = term.get("ja")
    aliases = term.get("aliases") or []
    if not isinstance(aliases, list) or not all(_ia_text(a) for a in aliases):
        problems.append(f"{label}: aliases는 문자열 목록입니다")
        aliases = []
    if term.get("coined") and not (_ia_text(ja) and _ia_text(term.get("note"))):
        problems.append(f"{label}: 자체 용어(coined)는 ja와 note(만든 이유)가 필요합니다")
    for evidence in term.get("evidence") or []:
        if not isinstance(evidence, dict):
            problems.append(f"{label}: 근거 항목이 객체가 아닙니다")
            continue
        if evidence.get("source") not in sources:
            problems.append(f"{label}: 근거 출처 {evidence.get('source')}가 출처 목록에 없습니다")
        if not _ia_text(evidence.get("quote")):
            problems.append(f"{label}: 근거에 quote(출처 원문)가 없습니다")
        form = evidence.get("form")
        if form != ja and form not in aliases:
            problems.append(f"{label}: 근거 표기 {form}이(가) ja나 aliases에 없습니다")
    expected = ja_term_confidence(term, sources)
    if term.get("confidence") != expected:
        problems.append(f"{label}: confidence는 근거로 계산하면 {expected}입니다 (적힌 값: {term.get('confidence')})")
    return problems


def check_ja_terms(root: Path) -> list[str]:
    files = sorted((root / JA_TERMS_DIR).glob("*.json"))
    loaded: list[tuple[str, dict]] = []
    problems: list[str] = []
    for path in files:
        rel = path.relative_to(root).as_posix()
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            problems.append(f"{rel}: JSON이 아닙니다 ({error})")
            continue
        if not isinstance(data, dict) or not isinstance(data.get("sources"), list) or not isinstance(data.get("terms"), list):
            problems.append(f"{rel}: sources와 terms 목록이 필요합니다")
            continue
        loaded.append((rel, data))
    # 출처는 파일을 가리지 않고 함께 씁니다. 다른 파일의 출처를 근거로 걸 수 있습니다.
    sources: dict[str, dict] = {}
    for rel, data in loaded:
        problems += [f"{rel}: {p}" for s in data["sources"] for p in _ja_source_problems(s, sources)]
    glossary = _glossary_keys(root)
    seen_terms: set[str] = set()
    for rel, data in loaded:
        problems += [f"{rel}: {p}" for t in data["terms"] for p in _ja_term_problems(t, sources, glossary, seen_terms)]
    return problems


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path.cwd()
    problems = (
        check_links(root) + check_artifacts(root) + check_decision_ids(root) + check_ia(root)
        + check_ideas(root) + check_ja_terms(root)
    )
    if problems:
        print("\n".join(problems))
        return 1
    print("OK: docs 검사 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
