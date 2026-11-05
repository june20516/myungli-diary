"""디자인 토큰을 CSS 변수로 내보냅니다 (DS1, #801, D105 ④).

웹 시안이 토큰을 직접 읽도록 `tokens/*.tokens.json`을 `artifacts/ds1/tokens.css` 하나로 옮깁니다.
변수 이름은 토큰 이름의 `.`을 `-`로 바꾼 것입니다(`space.16` → `--space-16`).
라이트 색과 모드 없는 값은 `:root`, 다크 색은 `[data-theme="dark"]`, 일본어 글자는 `:lang(ja)`에 둡니다.
글자 스타일(`type.*`)은 `-family`·`-size`·`-weight`·`-letter-spacing`·`-line-height` 다섯 변수로 풉니다.
그라데이션은 색 멈춤 목록(`#eef4ef 0%, ...`)이라 `linear-gradient(<방향>, var(--gradient-today))`로 씁니다.

    python3 docs/identity/design/tools/token_css.py     # 저장소 루트에서. 손으로 고치지 않습니다
"""
from __future__ import annotations

import json
import pathlib
import re
from typing import Iterator

from tokens import TOKENS_DIR

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
CSS_PATH = TOOLS_DIR.parent / "artifacts" / "ds1" / "tokens.css"
REFERENCE = re.compile(r"^\{([a-z0-9.\-]+)\}$")


def css_name(token_name: str) -> str:
    return "--" + token_name.replace(".", "-")


def leaf_tokens(node: dict, prefix: str = "") -> Iterator[tuple[str, dict]]:
    """`$value`가 있는 토큰을 (점 이름, 토큰)으로 차례대로 돌려줍니다."""
    for key, value in node.items():
        if key.startswith("$") or not isinstance(value, dict):
            continue
        name = f"{prefix}.{key}" if prefix else key
        if "$value" in value:
            yield name, value
        else:
            yield from leaf_tokens(value, name)


def _number(value: float) -> str:
    return str(int(value)) if float(value).is_integer() else str(value)


def _dimension(value: dict) -> str:
    return f"{_number(value['value'])}{value['unit']}"


def _color(value: dict) -> str:
    alpha = value.get("alpha")
    if alpha is None or alpha == 1:
        return value["hex"]
    red, green, blue = (round(component * 255) for component in value["components"])
    return f"rgba({red}, {green}, {blue}, {_number(alpha)})"


def _reference_or(value: object, convert) -> str:
    if isinstance(value, str):
        match = REFERENCE.match(value)
        if match:
            return f"var({css_name(match.group(1))})"
    return convert(value)


def _shadow(value: dict | list) -> str:
    layers = value if isinstance(value, list) else [value]
    return ", ".join(
        " ".join(
            [*(_dimension(layer[key]) for key in ("offsetX", "offsetY", "blur", "spread") if key in layer),
             _reference_or(layer["color"], _color)]
        )
        for layer in layers
    )


def _font_family(value: list[str]) -> str:
    return ", ".join(name if name in ("sans-serif", "serif", "monospace") else f'"{name}"' for name in value)


def _declarations(name: str, token: dict) -> list[tuple[str, str]]:
    token_type, value = token["$type"], token["$value"]
    variable = css_name(name)
    if token_type == "typography":
        return [
            (f"{variable}-family", _reference_or(value["fontFamily"], _font_family)),
            (f"{variable}-size", _dimension(value["fontSize"])),
            (f"{variable}-weight", str(value["fontWeight"])),
            (f"{variable}-letter-spacing", _dimension(value["letterSpacing"])),
            (f"{variable}-line-height", _number(value["lineHeight"])),
        ]
    converters = {
        "color": lambda v: _reference_or(v, _color),
        "dimension": lambda v: _reference_or(v, _dimension),
        "duration": lambda v: _reference_or(v, _dimension),
        "cubicBezier": lambda v: "cubic-bezier(" + ", ".join(_number(n) for n in v) + ")",
        "fontFamily": _font_family,
        "shadow": _shadow,
        "gradient": lambda v: ", ".join(
            f"{_reference_or(stop['color'], _color)} {_number(stop['position'] * 100)}%" for stop in v
        ),
        "fontWeight": str,
        "number": _number,
    }
    if token_type not in converters:
        raise ValueError(f"{name}: CSS로 옮기는 법을 모르는 토큰 종류 {token_type}")
    return [(variable, converters[token_type](value))]


def _block(selector: str, files: list[str], tokens_dir: pathlib.Path) -> str:
    lines = [f"{selector} {{"]
    for file in files:
        document = json.loads((tokens_dir / file).read_text(encoding="utf-8"))
        for name, token in leaf_tokens(document):
            lines.extend(f"  {variable}: {value};" for variable, value in _declarations(name, token))
    lines.append("}")
    return "\n".join(lines)


def build_css(tokens_dir: pathlib.Path = TOKENS_DIR) -> str:
    header = "/* tools/token_css.py가 tokens/에서 만든 파일입니다. 손으로 고치지 않습니다. */"
    return "\n\n".join([
        header,
        _block(":root", ["primitive.tokens.json", "color.light.tokens.json", "typography.tokens.json"], tokens_dir),
        _block('[data-theme="dark"]', ["color.dark.tokens.json"], tokens_dir),
        _block(":lang(ja)", ["typography.ja.tokens.json"], tokens_dir),
    ]) + "\n"


def main() -> None:
    CSS_PATH.parent.mkdir(parents=True, exist_ok=True)
    CSS_PATH.write_text(build_css(TOKENS_DIR), encoding="utf-8")
    print(f"{CSS_PATH} 씀")


if __name__ == "__main__":
    main()
