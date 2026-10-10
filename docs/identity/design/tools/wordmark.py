"""고운돋움 글리프를 아웃라인 path로 바꿔 워드마크와 가로 조합 SVG를 만듭니다.

spec: docs/identity/design/specs/2026-10-10-visual-identity-design.md §6.2

사용법 (저장소 루트에서):
    uv run --with fonttools==4.54.1 python docs/identity/design/tools/wordmark.py \
        --font .suberpowers/fonts/GowunDodum-Regular.ttf --out-dir docs/identity/design/logo
"""
from __future__ import annotations

import argparse
import pathlib
import xml.etree.ElementTree as ET

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

from palette import build_palette
from svg_markup import inner_markup

WORDMARK_TEXT = "명리일기"
WORDMARK_HEIGHT_PX = 64
ICON_CORNER_RATIO = 0.22  # 플랫폼이 깎는 모서리와 비슷하게 보여줍니다
SVG_NAMESPACE = "http://www.w3.org/2000/svg"


def _number(value: float) -> str:
    return f"{value:.1f}".rstrip("0").rstrip(".")


def wordmark_svg(font_path: pathlib.Path, text: str, fill: str, letter_spacing_em: float = 0.02) -> str:
    """text를 글리프 아웃라인으로 바꾼 SVG를 돌려줍니다. 글꼴에 없는 글자가 있으면 ValueError."""
    font = TTFont(str(font_path))
    character_map = font.getBestCmap()
    glyph_set = font.getGlyphSet()
    units_per_em = font["head"].unitsPerEm
    letter_spacing = letter_spacing_em * units_per_em

    missing = [character for character in text if ord(character) not in character_map]
    if missing:
        raise ValueError(f"글꼴에 없는 글자: {''.join(missing)}")

    paths = []
    x_min = y_min = float("inf")
    x_max = y_max = float("-inf")
    cursor = 0.0
    for character in text:
        glyph_name = character_map[ord(character)]
        path_pen = SVGPathPen(glyph_set)
        glyph_set[glyph_name].draw(path_pen)
        bounds_pen = BoundsPen(glyph_set)
        glyph_set[glyph_name].draw(bounds_pen)
        if bounds_pen.bounds:
            left, bottom, right, top = bounds_pen.bounds
            x_min, x_max = min(x_min, cursor + left), max(x_max, cursor + right)
            y_min, y_max = min(y_min, bottom), max(y_max, top)
        paths.append(
            f'<path transform="translate({_number(cursor)} 0) scale(1 -1)" d="{path_pen.getCommands()}"/>'
        )
        cursor += font["hmtx"][glyph_name][0] + letter_spacing

    width, height = x_max - x_min, y_max - y_min
    pixel_width = WORDMARK_HEIGHT_PX * width / height
    return (
        f'<svg xmlns="{SVG_NAMESPACE}" viewBox="{_number(x_min)} {_number(-y_max)} {_number(width)} {_number(height)}" '
        f'width="{_number(pixel_width)}" height="{WORDMARK_HEIGHT_PX}">\n'
        f'  <title>{text}</title>\n'
        f'  <g fill="{fill}">\n    ' + "\n    ".join(paths) + "\n  </g>\n</svg>\n"
    )


def lockup_svg(icon_svg: str, wordmark: str, gap_ratio: float = 0.25, icon_to_cap_ratio: float = 1.5) -> str:
    """아이콘 + 워드마크 가로 조합. 아이콘 높이는 워드마크 높이의 icon_to_cap_ratio배입니다."""
    wordmark_root = ET.fromstring(wordmark)
    _, _, viewbox_width, viewbox_height = (float(value) for value in wordmark_root.get("viewBox").split())
    wordmark_height = 100.0
    wordmark_width = wordmark_height * viewbox_width / viewbox_height
    icon_size = wordmark_height * icon_to_cap_ratio
    gap = icon_size * gap_ratio
    total_width = icon_size + gap + wordmark_width
    corner = 100 * ICON_CORNER_RATIO
    return (
        f'<svg xmlns="{SVG_NAMESPACE}" viewBox="0 0 {_number(total_width)} {_number(icon_size)}" '
        f'width="{_number(total_width * 0.64)}" height="{_number(icon_size * 0.64)}">\n'
        f'  <title>명리일기</title>\n'
        f'  <defs><clipPath id="icon-corner"><rect width="100" height="100" rx="{_number(corner)}"/></clipPath></defs>\n'
        f'  <svg x="0" y="0" width="{_number(icon_size)}" height="{_number(icon_size)}" viewBox="0 0 100 100">\n'
        f'    <g clip-path="url(#icon-corner)">\n{inner_markup(icon_svg)}\n    </g>\n  </svg>\n'
        f'  <svg x="{_number(icon_size + gap)}" y="{_number((icon_size - wordmark_height) / 2)}" '
        f'width="{_number(wordmark_width)}" height="{_number(wordmark_height)}" '
        f'viewBox="{wordmark_root.get("viewBox")}">\n{inner_markup(wordmark)}\n  </svg>\n'
        f"</svg>\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="워드마크와 가로 조합 SVG를 만듭니다.")
    parser.add_argument("--font", type=pathlib.Path, required=True)
    parser.add_argument("--out-dir", type=pathlib.Path, required=True)
    arguments = parser.parse_args()

    roles = build_palette()["roles"]
    icon = (arguments.out_dir / "icon-large.svg").read_text(encoding="utf-8")
    for suffix, mode in (("", "light"), ("-dark", "dark")):
        wordmark = wordmark_svg(arguments.font, WORDMARK_TEXT, roles[mode]["text.primary"])
        (arguments.out_dir / f"wordmark{suffix}.svg").write_text(wordmark, encoding="utf-8")
        (arguments.out_dir / f"lockup{suffix}.svg").write_text(lockup_svg(icon, wordmark), encoding="utf-8")
        print(f"wordmark{suffix}.svg, lockup{suffix}.svg")


if __name__ == "__main__":
    main()
