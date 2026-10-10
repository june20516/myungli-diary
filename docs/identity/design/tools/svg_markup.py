"""SVG 파일을 다른 SVG 안에 넣을 때 쓰는 도우미."""
from __future__ import annotations

import re

# 앞쪽의 XML 선언·주석과 바깥 <svg> 여는 태그, 그리고 끝의 닫는 태그
OUTER_SVG = re.compile(r"^\s*(?:<\?xml[^>]*\?>\s*)?(?:<!--.*?-->\s*)*<svg[^>]*>|</svg>\s*$", re.DOTALL)


def inner_markup(svg: str) -> str:
    """바깥 <svg> 태그(앞의 XML 선언·주석 포함)를 벗긴 내용을 돌려줍니다."""
    return OUTER_SVG.sub("", svg).strip()
