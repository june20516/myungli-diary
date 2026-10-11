"""컴포넌트 명세(`components/`)가 IA·토큰·공통 요소·상호작용 패턴과 맞는지 검사합니다.

spec: docs/identity/design/specs/2026-10-11-components-design.md §2·§7

사용법 (저장소 루트에서):
    python3 docs/identity/design/tools/components.py    # 문제가 있으면 출력하고 종료 코드 1
"""
from __future__ import annotations

import json
import pathlib
import sys

from dtcg import REFERENCE, flatten
from tokens import DESIGN_DIR, TOKENS_DIR

COMPONENTS_DIR = DESIGN_DIR / "components"
IA_PATH = DESIGN_DIR.parent.parent / "ia" / "screens.json"
CONTRACT_VERSION = "1.0.0"
CONTRACT_LINE = f"컴포넌트 계약 {CONTRACT_VERSION}"

GROUPS = ("frame", "feedback", "input", "action", "sentence", "today", "calendar", "diary", "saju")
COMMON = ("interaction", "elements")
DOCUMENT_FIELDS = {"version", "group", "components"}
STATE_MAP_GROUP = "feedback"
COMMON_FIELDS = {"interaction": {"version", "patterns", "haptics"}, "elements": {"version", "elements"}}
COMPONENT_FIELDS = {"id", "summary", "uses", "variants", "parts", "states", "motion", "haptic", "a11y", "rules"}
PATTERN_REQUIRED = ("summary", "duration", "easing", "reduceMotion")

# 테마 조합 이름 → (색 모드 파일, 글자 언어 파일). primitive는 모든 조합에 들어갑니다.
THEMES = {
    "light-ko": ("color.light.tokens.json", "typography.tokens.json"),
    "light-ja": ("color.light.tokens.json", "typography.ja.tokens.json"),
    "dark-ko": ("color.dark.tokens.json", "typography.tokens.json"),
    "dark-ja": ("color.dark.tokens.json", "typography.ja.tokens.json"),
}


def load_documents(directory: pathlib.Path) -> dict[str, dict]:
    """파일 이름(확장자 뺀 것) → JSON 문서."""
    return {path.stem: json.loads(path.read_text(encoding="utf-8")) for path in sorted(directory.glob("*.json"))}


def token_names_by_theme(tokens_dir: pathlib.Path) -> dict[str, set[str]]:
    """테마 조합마다 쓸 수 있는 토큰 이름."""
    def names(file_name: str) -> set[str]:
        return set(flatten(json.loads((tokens_dir / file_name).read_text(encoding="utf-8"))))

    primitive = names("primitive.tokens.json")
    return {theme: primitive | names(color_file) | names(type_file)
            for theme, (color_file, type_file) in THEMES.items()}


def _walk(node: object, path: str):
    """(위치, 키, 값)을 깊이 순서로 내놓습니다. 위치는 `a.b[0].c` 표기입니다."""
    if isinstance(node, dict):
        for key, value in node.items():
            child = f"{path}.{key}" if path else str(key)
            yield child, key, value
            yield from _walk(value, child)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            child = f"{path}[{index}]"
            yield child, None, value
            yield from _walk(value, child)


def _references(document: dict) -> list[tuple[str, str]]:
    found = []
    for place, _, value in _walk(document, ""):
        if isinstance(value, str):
            match = REFERENCE.match(value)
            if match:
                found.append((place, match.group(1)))
    return found


def _field_problems(name: str, document: dict) -> list[str]:
    if name in COMMON:
        allowed = COMMON_FIELDS[name]
    elif name in GROUPS:
        allowed = DOCUMENT_FIELDS | ({"stateMap"} if name == STATE_MAP_GROUP else set())
    else:
        return [f"{name}.json: 알 수 없는 명세 파일 (묶음: {', '.join(GROUPS)}, 공통: {', '.join(COMMON)})"]
    problems = [f"{name}.json: 허용하지 않는 필드 {field}" for field in document if field not in allowed]
    if document.get("version") != CONTRACT_VERSION:
        problems.append(f"{name}.json: version이 {CONTRACT_VERSION}이 아님: {document.get('version')!r}")
    if name in GROUPS:
        if document.get("group") != name:
            problems.append(f"{name}.json: group이 파일 이름과 다름: {document.get('group')!r}")
        for index, component in enumerate(document.get("components", [])):
            label = component.get("id", f"components[{index}]")
            problems += [f"{name}.json: {label}: 허용하지 않는 필드 {field}"
                         for field in component if field not in COMPONENT_FIELDS]
            problems += [f"{name}.json: {label}: {field} 없음" for field in ("id", "summary") if field not in component]
    return problems


def _ia_problems(documents: dict[str, dict], ia: dict) -> list[str]:
    expected = {component["id"] for component in ia["components"]}
    owners: dict[str, list[str]] = {}
    for name in GROUPS:
        for component in documents.get(name, {}).get("components", []):
            if "id" in component:
                owners.setdefault(component["id"], []).append(name)
    problems = [f"{component_id}: IA 컴포넌트인데 명세가 없음" for component_id in sorted(expected - set(owners))]
    for component_id, groups in sorted(owners.items()):
        if component_id not in expected:
            problems.append(f"{component_id}: IA에 없는 컴포넌트 ({', '.join(groups)}.json)")
        if len(groups) > 1:
            problems.append(f"{component_id}: 두 번 이상 나옴 ({', '.join(groups)})")
    return problems


def _reference_problems(documents: dict[str, dict], token_names: dict[str, set[str]]) -> list[str]:
    problems = []
    for name, document in documents.items():
        for place, target in _references(document):
            missing = [theme for theme, names in token_names.items() if target not in names]
            if missing:
                problems.append(f"{name}.json: {place}: {{{target}}} 토큰이 {', '.join(missing)}에 없음")
    return problems


def _usage_problems(documents: dict[str, dict]) -> list[str]:
    patterns = set(documents.get("interaction", {}).get("patterns", {}))
    elements = set(documents.get("elements", {}).get("elements", {}))
    problems = []
    for name, document in documents.items():
        for place, key, value in _walk(document, ""):
            if key == "uses":
                for used in value if isinstance(value, list) else [value]:
                    if used not in patterns | elements:
                        problems.append(f"{name}.json: {place}: 없는 요소·패턴 {used!r}")
            elif key == "pattern" and value not in patterns:
                problems.append(f"{name}.json: {place}: 없는 패턴 {value!r}")
    return problems


def _pattern_problems(documents: dict[str, dict]) -> list[str]:
    problems = []
    for pattern_id, pattern in documents.get("interaction", {}).get("patterns", {}).items():
        problems += [f"interaction.json: {pattern_id}: {field} 없음" for field in PATTERN_REQUIRED if field not in pattern]
        for field in ("duration", "easing"):
            value = pattern.get(field)
            if field in pattern and not (isinstance(value, str) and REFERENCE.match(value)):
                problems.append(f"interaction.json: {pattern_id}: {field}가 토큰 참조가 아님: {value!r}")
    return problems


def _state_map_problems(documents: dict[str, dict], ia: dict) -> list[str]:
    components = {component["id"] for component in ia["components"]}
    states = {state["id"] for screen in ia["screens"] for state in screen.get("states", [])}
    state_map = documents.get(STATE_MAP_GROUP, {}).get("stateMap", {})
    problems = [f"{STATE_MAP_GROUP}.json: stateMap에 IA 상태 {state} 없음" for state in sorted(states - set(state_map))]
    for state, targets in state_map.items():
        if state not in states:
            problems.append(f"{STATE_MAP_GROUP}.json: stateMap의 {state}는 IA 화면 상태가 아님")
        for target in targets if isinstance(targets, list) else [targets]:
            if target not in components:
                problems.append(f"{STATE_MAP_GROUP}.json: stateMap {state} → IA에 없는 컴포넌트 {target!r}")
    return problems


def _file_problems(documents: dict[str, dict], directory: pathlib.Path) -> list[str]:
    problems = [f"{name}.md 없음 ({name}.json의 설명)" for name in documents if not (directory / f"{name}.md").exists()]
    readme_path = directory / "README.md"
    if not readme_path.exists():
        return problems + ["README.md 없음"]
    readme = readme_path.read_text(encoding="utf-8")
    if CONTRACT_LINE not in readme:
        problems.append(f"README.md에 '{CONTRACT_LINE}' 없음")
    problems += [f"README.md가 {name}.json을 적지 않음" for name in documents if f"{name}.json" not in readme]
    return problems


def find_problems(documents: dict[str, dict], ia: dict, token_names: dict[str, set[str]],
                  directory: pathlib.Path | None = None) -> list[str]:
    """문제를 한 줄씩 돌려줍니다. 빈 목록이면 통과입니다. directory가 있으면 짝 .md와 README도 봅니다."""
    problems: list[str] = []
    for name, document in documents.items():
        problems += _field_problems(name, document)
    problems += _ia_problems(documents, ia)
    problems += _reference_problems(documents, token_names)
    problems += _usage_problems(documents)
    problems += _pattern_problems(documents)
    problems += _state_map_problems(documents, ia)
    if directory is not None:
        problems += _file_problems(documents, directory)
    return problems


def main() -> int:
    documents = load_documents(COMPONENTS_DIR)
    ia = json.loads(IA_PATH.read_text(encoding="utf-8"))
    problems = find_problems(documents, ia, token_names_by_theme(TOKENS_DIR), COMPONENTS_DIR)
    for problem in problems:
        print(problem)
    if problems:
        print(f"\n문제 {len(problems)}개")
        return 1
    count = sum(len(documents[name].get("components", [])) for name in GROUPS if name in documents)
    print(f"OK: 명세 파일 {len(documents)}개, 컴포넌트 {count}개")
    return 0


if __name__ == "__main__":
    sys.exit(main())
