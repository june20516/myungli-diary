"""토큰 CSS 변수 내보내기 테스트 (DS1, #801, D105 ④)."""
import json
import pathlib
import re
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

from token_css import CSS_PATH, build_css, css_name, leaf_tokens  # noqa: E402
from tokens import TOKENS_DIR  # noqa: E402


def block(css: str, selector: str) -> str:
    match = re.search(re.escape(selector) + r"\s*\{(.*?)\n\}", css, re.S)
    assert match, f"{selector} 블록 없음"
    return match.group(1)


def declarations(text: str) -> dict[str, str]:
    return dict(re.findall(r"(--[a-z0-9\-]+):\s*([^;]+);", text))


def test_every_primitive_token_has_css_variable():
    primitive = json.loads((TOKENS_DIR / "primitive.tokens.json").read_text(encoding="utf-8"))
    root = declarations(block(build_css(TOKENS_DIR), ":root"))

    for name, token in leaf_tokens(primitive):
        variable = css_name(name)
        if token["$type"] in ("dimension",):
            assert root[variable] == f"{token['$value']['value']}px", name
        elif token["$type"] == "duration":
            assert root[variable] == f"{token['$value']['value']}ms", name
        else:
            assert variable in root, name


def test_space_16_is_16px():
    root = declarations(block(build_css(TOKENS_DIR), ":root"))

    assert root["--space-16"] == "16px"
    assert root["--motion-easing-seep"] == "cubic-bezier(0.2, 0.7, 0.2, 1)"


def test_dark_colors_scoped():
    css = build_css(TOKENS_DIR)
    root = declarations(block(css, ":root"))
    dark = declarations(block(css, '[data-theme="dark"]'))

    assert root["--color-bg-base"] == "var(--color-neutral-50)"
    assert "--color-bg-base" in dark
    assert dark["--color-bg-base"] != root["--color-bg-base"]
    assert not any(name.startswith("--space-") for name in dark)


def test_ja_typography_scoped():
    css = build_css(TOKENS_DIR)
    ja = declarations(block(css, ":lang(ja)"))

    assert ja["--type-sentence-card-line-height"] == "1.75"
    assert ja["--font-family-sentence"].startswith('"Zen Maru Gothic"')


def test_committed_css_is_fresh():
    assert CSS_PATH.read_text(encoding="utf-8") == build_css(TOKENS_DIR), "token_css.py로 다시 만드세요"
