"""컴포넌트 명세의 간격과 크기 값을 전수 점검합니다 (DS1, #801).

명세 JSON을 모두 걸으며 토큰 참조(`{space.16}`)와 직접 쓴 px 값을 모으고,
규칙에 어긋나는 곳(간격에 토큰이 아닌 값, 이유 없이 다른 위아래 여백)을 찾습니다.

    python3 docs/identity/design/tools/rules_audit.py --out docs/identity/design/specs/2026-11-05-ds1-audit.md
"""
from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
from typing import Iterator, NamedTuple

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
COMPONENTS_DIR = TOOLS_DIR.parent / "components"

TOKEN_PATTERN = re.compile(r"^\{([a-z0-9.\-]+)\}$")
SPACING_KEY = re.compile(r"^(padding|margin|gap|inset)", re.IGNORECASE)
VERTICAL_PAIRS = (("paddingTop", "paddingBottom"), ("marginTop", "marginBottom"))


class Measure(NamedTuple):
    component: str
    path: str
    key: str
    value: str
    is_token: bool
    has_note: bool = False  # 같은 부품에 이유(`note`)가 적혀 있는지


def _measure_value(value: object) -> tuple[str, bool] | None:
    """토큰 참조나 px 값이면 (값, 토큰 여부)를, 아니면 None을 돌려줍니다."""
    if isinstance(value, str):
        match = TOKEN_PATTERN.match(value)
        return (match.group(1), True) if match else None
    if isinstance(value, dict) and value.get("unit") == "px" and isinstance(value.get("value"), (int, float)):
        number = value["value"]
        return (str(int(number)) if float(number).is_integer() else str(number), False)
    return None


def _walk(node: object, component: str, path: str) -> Iterator[Measure]:
    if isinstance(node, dict):
        for key, value in node.items():
            if key.startswith("$"):
                continue
            measured = _measure_value(value)
            if measured is not None:
                yield Measure(component, path, key, measured[0], measured[1], "note" in node)
            elif isinstance(value, (dict, list)):
                yield from _walk(value, component, f"{path}.{key}" if path else key)
    elif isinstance(node, list):
        for index, item in enumerate(node):
            label = item.get("id", str(index)) if isinstance(item, dict) else str(index)
            yield from _walk(item, component, f"{path}.{label}")


def collect_measures(components_dir: pathlib.Path = COMPONENTS_DIR) -> list[Measure]:
    """명세 JSON마다 최상위 목록의 항목(`id`가 있는 것)과 요소 묶음(`elements`의 이름별 항목)을 단위로 값을 모읍니다."""
    measures: list[Measure] = []
    for file in sorted(components_dir.glob("*.json")):
        document = json.loads(file.read_text(encoding="utf-8"))
        for top_value in document.values():
            if not isinstance(top_value, list):
                continue
            for item in top_value:
                if isinstance(item, dict) and "id" in item:
                    measures.extend(_walk(item, item["id"], ""))
        for name, element in document.get("elements", {}).items():
            measures.extend(_walk(element, name, ""))
    return measures


def _raw_spacing_problems(measures: list[Measure]) -> list[str]:
    return [
        f"{m.component} {m.path + '.' if m.path else ''}{m.key}: 간격에 토큰이 아닌 값 {m.value}"
        for m in measures
        if not m.is_token and SPACING_KEY.match(m.key) and m.value != "0"
    ]


def _asymmetry_problems(measures: list[Measure]) -> list[str]:
    by_part: dict[tuple[str, str], dict[str, Measure]] = collections.defaultdict(dict)
    for m in measures:
        by_part[(m.component, m.path)][m.key] = m
    problems: list[str] = []
    for (component, path), keys in by_part.items():
        for top, bottom in VERTICAL_PAIRS:
            if top in keys and bottom in keys and not keys[top].has_note and keys[top].value != keys[bottom].value:
                problems.append(
                    f"{component} {path}: 위아래 여백이 다름 ({top} {keys[top].value}, {bottom} {keys[bottom].value})"
                )
    return problems


def find_problems(measures: list[Measure]) -> list[str]:
    """규칙 위반 목록: 간격에 토큰이 아닌 값, 이유(`note`) 없이 다른 위아래 여백."""
    return _raw_spacing_problems(measures) + _asymmetry_problems(measures)


def render_markdown(measures: list[Measure], problems: list[str]) -> str:
    token_counts = collections.Counter(m.value for m in measures if m.is_token and m.value.startswith("space."))
    raw = collections.Counter((m.key, m.value) for m in measures if not m.is_token)
    lines = [
        "# DS1 규칙 전수 점검 결과",
        "",
        "`tools/rules_audit.py`가 만든 파일입니다. 손으로 고치지 않습니다.",
        "",
        "## 간격 토큰 쓰임",
        "| 토큰 | 쓰인 수 |",
        "| --- | --- |",
        *[f"| `{name}` | {count} |" for name, count in sorted(token_counts.items(), key=lambda x: int(x[0].split(".")[1]))],
        "",
        "## 직접 쓴 값",
        "| 키 | 값(px) | 쓰인 수 |",
        "| --- | --- | --- |",
        *[f"| `{key}` | {value} | {count} |" for (key, value), count in sorted(raw.items(), key=lambda x: (x[0][0], float(x[0][1])))],
        "",
        "## 문제",
        *([f"* {problem}" for problem in problems] or ["* 없음"]),
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=pathlib.Path)
    args = parser.parse_args()
    measures = collect_measures(COMPONENTS_DIR)
    text = render_markdown(measures, find_problems(measures))
    if args.out:
        args.out.write_text(text, encoding="utf-8")
    else:
        print(text)


if __name__ == "__main__":
    main()
