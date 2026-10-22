"""컴포넌트 명세(`components/`)가 IA·토큰·공통 요소·상호작용 패턴과 맞는지 검사합니다.

spec: docs/identity/design/specs/2026-10-11-components-design.md §2·§7

사용법 (저장소 루트에서):
    python3 docs/identity/design/tools/components.py    # 문제가 있으면 출력하고 종료 코드 1
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

from dtcg import REFERENCE, flatten
from tokens import DESIGN_DIR, TOKENS_DIR

COMPONENTS_DIR = DESIGN_DIR / "components"
IA_PATH = DESIGN_DIR.parent.parent / "ia" / "screens.json"
CONTRACT_VERSION = "3.0.0"
CONTRACT_LINE = f"컴포넌트 계약 {CONTRACT_VERSION}"

GROUPS = ("frame", "feedback", "input", "action", "sentence", "today", "calendar", "diary", "saju")
COMMON = ("interaction", "elements")
DOCUMENT_FIELDS = {"version", "group", "components"}
STATE_MAP_GROUP = "feedback"
COMMON_FIELDS = {"interaction": {"version", "patterns", "haptics", "fallbacks"}, "elements": {"version", "elements"}}
COMPONENT_FIELDS = {"id", "summary", "uses", "variants", "parts", "states", "motion", "haptic", "a11y", "rules"}
PATTERN_REQUIRED = ("summary", "duration", "easing", "reduceMotion")
REDUCE_MOTION_VALUES = ("opacity-only", "instant")
HAPTIC_STRENGTHS = ("selection", "light", "medium")
# 시간·곡선 키: duration, easing, 그리고 drawDuration처럼 Duration·Easing으로 끝나는 키
TIMING_KEY = re.compile(r"^(duration|easing)$|(Duration|Easing)$")
EMBEDDED_REFERENCE = re.compile(r"\{[a-z][\w.-]*\}")

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


def _component_list(document: dict) -> list[dict]:
    """모양이 맞는 컴포넌트만. 모양 문제는 _component_shape_problems가 알립니다."""
    components = document.get("components", [])
    if not isinstance(components, list):
        return []
    return [component for component in components if isinstance(component, dict)]


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
        for index, component in enumerate(_component_list(document)):
            label = component.get("id", f"components[{index}]")
            problems += [f"{name}.json: {label}: 허용하지 않는 필드 {field}"
                         for field in component if field not in COMPONENT_FIELDS]
            problems += [f"{name}.json: {label}: {field} 없음" for field in ("id", "summary") if field not in component]
    return problems


def _ia_problems(documents: dict[str, dict], ia: dict) -> list[str]:
    expected = {component["id"] for component in ia["components"]}
    owners: dict[str, list[str]] = {}
    for name in GROUPS:
        for component in _component_list(documents.get(name, {})):
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


def _embedded_reference_problems(documents: dict[str, dict]) -> list[str]:
    """`"1px {color.line}"`처럼 문자열 중간에 섞인 참조는 검사기가 풀 수 없으므로 문제로 봅니다."""
    problems = []
    for name, document in documents.items():
        for place, _, value in _walk(document, ""):
            if isinstance(value, str) and EMBEDDED_REFERENCE.search(value) and not REFERENCE.match(value):
                problems.append(f"{name}.json: {place}: 문자열 안에 섞인 토큰 참조 {value!r} (값 하나에 참조 하나만)")
    return problems


def _usage_problems(documents: dict[str, dict], ia: dict) -> list[str]:
    patterns = set(documents.get("interaction", {}).get("patterns", {}))
    elements = set(documents.get("elements", {}).get("elements", {}))
    components = {component["id"] for component in ia["components"]}
    problems = []
    for name, document in documents.items():
        for place, key, value in _walk(document, ""):
            if key == "uses":
                if not (isinstance(value, list) and all(isinstance(used, str) for used in value)):
                    problems.append(f"{name}.json: {place}: uses는 id 문자열 목록이어야 함: {value!r}")
                    continue
                for used in value:
                    if used not in patterns | elements:
                        problems.append(f"{name}.json: {place}: 없는 요소·패턴 {used!r}")
            elif key == "pattern" and (not isinstance(value, str) or value not in patterns):
                problems.append(f"{name}.json: {place}: 없는 패턴 {value!r} (pattern은 패턴 id 하나)")
            elif key == "component" and name in GROUPS and value not in components:
                problems.append(f"{name}.json: {place}: IA에 없는 컴포넌트 {value!r}")
            elif key == "element" and value not in elements:
                problems.append(f"{name}.json: {place}: 없는 요소 {value!r}")
    return problems


def _timing_problems(documents: dict[str, dict]) -> list[str]:
    """시간·곡선은 깊이와 관계없이 motion 토큰을 가리킵니다 (spec §3.1)."""
    problems = []
    for name, document in documents.items():
        for place, key, value in _walk(document, ""):
            if isinstance(key, str) and TIMING_KEY.search(key) and not (isinstance(value, str) and REFERENCE.match(value)):
                problems.append(f"{name}.json: {place}: 시간·곡선이 토큰 참조가 아님: {value!r}")
    return problems


def _component_shape_problems(documents: dict[str, dict]) -> list[str]:
    problems = []
    for name in GROUPS:
        document = documents.get(name)
        if document is None:
            continue
        components = document.get("components", [])
        if not isinstance(components, list) or not all(isinstance(component, dict) for component in components):
            problems.append(f"{name}.json: components는 컴포넌트 객체 목록이어야 함")
            continue
        for component in components:
            label = component.get("id", "?")
            variants = component.get("variants", [])
            if not isinstance(variants, list) or not all(isinstance(variant, dict) and "id" in variant for variant in variants):
                problems.append(f"{name}.json: {label}: variants는 id가 있는 객체 목록이어야 함")
                continue
            ids = [variant["id"] for variant in variants]
            problems += [f"{name}.json: {label}: 변형 {variant_id} 두 번 이상 나옴"
                         for variant_id in sorted({i for i in ids if ids.count(i) > 1})]
            haptic = component.get("haptic", [])
            if not isinstance(haptic, list):
                problems.append(f"{name}.json: {label}: haptic은 목록이어야 함")
                continue
            for moment in haptic:
                strength = moment.get("strength") if isinstance(moment, dict) else None
                if strength not in HAPTIC_STRENGTHS:
                    problems.append(f"{name}.json: {label}: 햅틱 세기 {strength!r}는 {', '.join(HAPTIC_STRENGTHS)} 밖")
    return problems


def _pattern_problems(documents: dict[str, dict]) -> list[str]:
    problems = []
    for pattern_id, pattern in documents.get("interaction", {}).get("patterns", {}).items():
        problems += [f"interaction.json: {pattern_id}: {field} 없음" for field in PATTERN_REQUIRED if field not in pattern]
        if "reduceMotion" in pattern and pattern["reduceMotion"] not in REDUCE_MOTION_VALUES:
            problems.append(f"interaction.json: {pattern_id}: reduceMotion {pattern['reduceMotion']!r}는 "
                            f"{', '.join(REDUCE_MOTION_VALUES)} 밖")
    return problems


def _state_map_problems(documents: dict[str, dict], ia: dict) -> list[str]:
    components = {component["id"] for component in ia["components"]}
    states = {state["id"] for screen in ia["screens"] for state in screen.get("states", [])}
    state_map = documents.get(STATE_MAP_GROUP, {}).get("stateMap", {})
    if not isinstance(state_map, dict):
        return [f"{STATE_MAP_GROUP}.json: stateMap은 상태 id → 컴포넌트 id 객체여야 함"]
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
    problems += _component_shape_problems(documents)
    problems += _ia_problems(documents, ia)
    problems += _reference_problems(documents, token_names)
    problems += _embedded_reference_problems(documents)
    problems += _usage_problems(documents, ia)
    problems += _timing_problems(documents)
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
