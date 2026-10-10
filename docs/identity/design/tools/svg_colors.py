"""SVG·HTML 산출물의 색이 팔레트 안에 있는지 확인하는 도우미."""
from __future__ import annotations

import re

HEX_IN_MARKUP = re.compile(r"#[0-9a-fA-F]{6}\b")


def palette_colors(palette: dict) -> set[str]:
    """build_palette() 결과 안의 모든 hex를 모읍니다."""
    colors: set[str] = set()

    def collect(value: object) -> None:
        if isinstance(value, dict):
            for item in value.values():
                collect(item)
        elif isinstance(value, list):
            for item in value:
                collect(item)
        elif isinstance(value, str) and HEX_IN_MARKUP.fullmatch(value):
            colors.add(value.lower())

    collect(palette)
    return colors


def colors_in_markup(text: str) -> set[str]:
    """문서 안의 #rrggbb 색을 소문자로 모읍니다."""
    return {match.lower() for match in HEX_IN_MARKUP.findall(text)}
