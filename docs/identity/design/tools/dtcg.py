"""DTCG(Design Tokens Format Module 2025.10) 토큰 문서를 펼치고, 참조를 풀고, 형식 문제를 찾습니다.

spec: docs/identity/design/specs/2026-10-11-design-tokens-design.md §6·§7
이 저장소가 쓰는 타입과 규칙(px 단위, srgb 색)만 검사합니다. 규격 전체를 검사하지는 않습니다.
"""
from __future__ import annotations

import re

ALLOWED_TYPES = {"color", "dimension", "fontFamily", "typography", "gradient"}
TYPOGRAPHY_KEYS = ("fontFamily", "fontSize", "fontWeight", "letterSpacing", "lineHeight")
REFERENCE = re.compile(r"^\{([^{}]+)\}$")
HEX = re.compile(r"^#[0-9a-f]{6}$")


def flatten(document: dict) -> dict[str, dict]:
    """점으로 이은 토큰 이름 → 토큰 객체. `$`로 시작하는 키는 그룹 속성이라 건너뜁니다."""
    tokens: dict[str, dict] = {}

    def walk(node: dict, path: list[str]) -> None:
        if "$value" in node:
            tokens[".".join(path)] = node
            return
        for key, child in node.items():
            if not key.startswith("$") and isinstance(child, dict):
                walk(child, path + [key])

    walk(document, [])
    return tokens


def _reference_target(value: object) -> str | None:
    if isinstance(value, str):
        match = REFERENCE.match(value)
        if match:
            return match.group(1)
    return None


def resolve(name: str, tokens: dict[str, dict]) -> object:
    """참조를 끝까지 따라가 `$value`를 돌려줍니다. 없는 이름이나 순환이면 KeyError."""
    seen: set[str] = set()
    while True:
        if name in seen:
            raise KeyError(f"순환 참조: {name}")
        seen.add(name)
        value = tokens[name]["$value"]
        target = _reference_target(value)
        if target is None:
            return value
        name = target


def _color_problems(value: object) -> list[str]:
    if not isinstance(value, dict):
        return ["색 값이 객체가 아님"]
    problems = []
    hex_color = value.get("hex")
    if value.get("colorSpace") != "srgb":
        problems.append("colorSpace가 srgb가 아님")
    if not isinstance(hex_color, str) or not HEX.match(hex_color):
        problems.append(f"hex 형식 오류: {hex_color!r}")
    else:
        expected = [round(int(hex_color[index:index + 2], 16) / 255, 4) for index in (1, 3, 5)]
        if value.get("components") != expected:
            problems.append(f"components {value.get('components')}가 hex {hex_color}와 다름")
    if "alpha" in value:
        alpha = value["alpha"]
        if isinstance(alpha, bool) or not isinstance(alpha, (int, float)) or not 0 <= alpha <= 1:
            problems.append(f"alpha가 0~1 숫자가 아님: {alpha!r}")
    return problems


def _dimension_problems(value: object) -> list[str]:
    if not isinstance(value, dict):
        return ["치수 값이 객체가 아님"]
    problems = []
    number = value.get("value")
    if isinstance(number, bool) or not isinstance(number, (int, float)):
        problems.append(f"치수 value가 숫자가 아님: {number!r}")
    if value.get("unit") != "px":
        problems.append(f"치수 단위가 px가 아님: {value.get('unit')!r}")
    return problems


def _font_family_problems(value: object) -> list[str]:
    if isinstance(value, str) or (isinstance(value, list) and value and all(isinstance(item, str) for item in value)):
        return []
    return [f"fontFamily 값 오류: {value!r}"]


def _check_value(token_type: str, value: object, references: list[str]) -> list[str]:
    """값을 검사하고, 발견한 참조 이름을 references에 모읍니다."""
    target = _reference_target(value)
    if target is not None:
        references.append(target)
        return []
    if token_type == "color":
        return _color_problems(value)
    if token_type == "dimension":
        return _dimension_problems(value)
    if token_type == "fontFamily":
        return _font_family_problems(value)
    if token_type == "typography":
        if not isinstance(value, dict):
            return ["typography 값이 객체가 아님"]
        problems = [f"typography에 {key} 없음" for key in TYPOGRAPHY_KEYS if key not in value]
        sub_types = {"fontFamily": "fontFamily", "fontSize": "dimension", "letterSpacing": "dimension"}
        for key, sub_type in sub_types.items():
            if key in value:
                problems += [f"{key}: {problem}" for problem in _check_value(sub_type, value[key], references)]
        for key in ("fontWeight", "lineHeight"):
            item = value.get(key)
            if key in value and _reference_target(item) is not None:
                references.append(_reference_target(item))
            elif key in value and (isinstance(item, bool) or not isinstance(item, (int, float))):
                problems.append(f"{key}가 숫자가 아님: {item!r}")
        return problems
    if token_type == "gradient":
        if not isinstance(value, list) or not value:
            return ["gradient 값이 비어 있지 않은 배열이 아님"]
        problems = []
        for index, stop in enumerate(value):
            if not isinstance(stop, dict) or "color" not in stop or "position" not in stop:
                problems.append(f"stop[{index}]에 color·position 없음")
                continue
            problems += [f"stop[{index}] {problem}" for problem in _check_value("color", stop["color"], references)]
            position = stop["position"]
            if isinstance(position, bool) or not isinstance(position, (int, float)) or not 0 <= position <= 1:
                problems.append(f"stop[{index}] position이 0~1 숫자가 아님: {position!r}")
        return problems
    return []


def _nested_token_names(document: dict) -> list[str]:
    """`$value`가 있으면서 하위 토큰·그룹도 가진 이름(토큰이면서 그룹)."""
    names = []

    def walk(node: dict, path: list[str]) -> None:
        children = {key: child for key, child in node.items() if not key.startswith("$") and isinstance(child, dict)}
        if "$value" in node and children:
            names.append(".".join(path))
        for key, child in children.items():
            walk(child, path + [key])

    walk(document, [])
    return names


def find_problems(documents: dict[str, dict]) -> list[str]:
    """파일 이름 → 문서를 받아 문제를 한 줄씩 돌려줍니다. 빈 목록이면 통과입니다."""
    problems: list[str] = []
    owner: dict[str, str] = {}
    all_tokens: dict[str, dict] = {}
    for file_name, document in documents.items():
        for name in _nested_token_names(document):
            problems.append(f"{file_name}: {name}: 토큰이면서 그룹임")
        for name, token in flatten(document).items():
            if name in owner:
                problems.append(f"{name}: {owner[name]}와 {file_name}에 모두 정의됨")
                continue
            owner[name] = file_name
            all_tokens[name] = token

    # 파일을 넘나드는 경우: 한 파일의 토큰 이름이 다른 파일에서 그룹으로 쓰이면 합칠 때 충돌합니다.
    for name in all_tokens:
        children = [other for other in all_tokens if other.startswith(name + ".") and owner[other] != owner[name]]
        if children:
            problems.append(f"{owner[name]}: {name}: 토큰이면서 그룹임 ({owner[children[0]]}의 {children[0]})")

    for name, token in all_tokens.items():
        token_type = token.get("$type")
        if token_type is None:
            problems.append(f"{owner[name]}: {name}: $type 없음")
            continue
        if token_type not in ALLOWED_TYPES:
            problems.append(f"{owner[name]}: {name}: 허용하지 않는 $type {token_type}")
            continue
        references: list[str] = []
        problems += [f"{owner[name]}: {name}: {problem}" for problem in _check_value(token_type, token["$value"], references)]
        for target in references:
            if target not in all_tokens:
                problems.append(f"{owner[name]}: {name}: 깨진 참조 {{{target}}}")
    return problems
