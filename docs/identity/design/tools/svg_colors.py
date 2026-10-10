"""SVG·HTML 산출물의 색이 팔레트 안에 있는지 확인하는 도우미."""
from __future__ import annotations

import re

HEX_IN_MARKUP = re.compile(r"#[0-9a-fA-F]{6}\b")
RGB_FUNCTION = re.compile(r"rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})")
# 팔레트와 대조할 수 없는 색 표기: 3·4·8자리 hex와 그 밖의 색 함수.
# HTML 숫자 엔티티(&#123;)는 앞에 &가 붙으므로 제외합니다.
UNSUPPORTED_HEX = re.compile(r"(?<!&)#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{3,4})\b")
UNSUPPORTED_FUNCTION = re.compile(r"\b(?:hsla?|hwb|lab|lch|oklab|oklch|color|color-mix)\(")


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
    """문서 안의 #rrggbb 색과 rgb()/rgba()의 RGB를 소문자 hex로 모읍니다."""
    colors = {match.lower() for match in HEX_IN_MARKUP.findall(text)}
    for red, green, blue in RGB_FUNCTION.findall(text):
        colors.add("#" + "".join(f"{int(channel):02x}" for channel in (red, green, blue)))
    return colors


def unsupported_colors_in_markup(text: str) -> set[str]:
    """팔레트와 대조할 수 없는 색 표기를 모읍니다. 비어 있어야 검사가 빈틈없습니다."""
    found = {match.lower() for match in UNSUPPORTED_HEX.findall(text)}
    found |= set(UNSUPPORTED_FUNCTION.findall(text))
    return found
