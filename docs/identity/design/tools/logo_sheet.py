"""logo/ 의 SVG들을 외부 참조 없는 한 장의 로고 모음 SVG로 묶습니다.

산출물: docs/identity/design/artifacts/2026-10-10-v0-logo-final.svg (logo/ 원본이 바뀌면 다시 만듭니다)

사용법 (저장소 루트에서):
    python3 docs/identity/design/tools/logo_sheet.py
"""
from __future__ import annotations

import pathlib
import re

from svg_markup import inner_markup

DESIGN_DIR = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = DESIGN_DIR / "artifacts" / "2026-10-10-v0-logo-final.svg"
LIGHT_BACKGROUND = "#f7f7f6"  # neutral-50
DARK_BACKGROUND = "#1b1b1a"  # neutral-950

# (파일, x, y, 너비, 높이, 미리보기 모서리 반경 또는 None)
PLACEMENTS = [
    ("icon-large.svg", 40, 50, 180, 180, 40),
    ("icon-large.svg", 250, 170, 60, 60, 13),
    ("icon-small.svg", 330, 201, 29, 29, 6),
    ("wordmark.svg", 420, 60, 229, 64, None),
    ("lockup.svg", 420, 150, 349, 96, None),
    ("icon-large.svg", 40, 330, 180, 180, 40),
    ("icon-large.svg", 250, 450, 60, 60, 13),
    ("icon-small.svg", 330, 481, 29, 29, 6),
    ("wordmark-dark.svg", 420, 340, 229, 64, None),
    ("lockup-dark.svg", 420, 430, 349, 96, None),
]


def _instance(logo_dir: pathlib.Path, index: int, name: str, x: int, y: int, width: int, height: int,
              corner: int | None) -> str:
    source = (logo_dir / name).read_text(encoding="utf-8")
    view_box = re.search(r'viewBox="([^"]+)"', source).group(1)
    inner = inner_markup(source)
    # 같은 파일을 여러 번 넣으므로 id에 인스턴스 번호를 붙여 충돌을 막습니다.
    for identifier in set(re.findall(r'id="([^"]+)"', inner)):
        inner = inner.replace(f'id="{identifier}"', f'id="{identifier}-{index}"')
        inner = inner.replace(f"url(#{identifier})", f"url(#{identifier}-{index})")
    body = f'<svg x="{x}" y="{y}" width="{width}" height="{height}" viewBox="{view_box}">{inner}</svg>'
    if corner is None:
        return body
    clip = (f'<clipPath id="corner-{index}"><rect x="{x}" y="{y}" width="{width}" height="{height}" '
            f'rx="{corner}"/></clipPath>')
    return f'<defs>{clip}</defs><g clip-path="url(#corner-{index})">{body}</g>'


def logo_sheet_svg(logo_dir: pathlib.Path) -> str:
    """라이트(위)·다크(아래) 두 줄로 아이콘, 워드마크, 가로 조합을 모은 SVG를 돌려줍니다."""
    parts = [_instance(logo_dir, index, *placement) for index, placement in enumerate(PLACEMENTS)]
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 560" width="960" height="560">\n'
        "<!-- V0 로고 일체 모음 (원본: docs/identity/design/logo/) -->\n"
        f'<rect width="960" height="280" fill="{LIGHT_BACKGROUND}"/>\n'
        f'<rect y="280" width="960" height="280" fill="{DARK_BACKGROUND}"/>\n'
        + "\n".join(parts) + "\n</svg>\n"
    )


if __name__ == "__main__":
    OUTPUT.write_text(logo_sheet_svg(DESIGN_DIR / "logo"), encoding="utf-8")
    print(OUTPUT)
