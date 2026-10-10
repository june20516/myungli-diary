"""견본 페이지 테스트: 색이 palette.py와 어긋나지 않는지 지킵니다 (spec §7·§8)."""
import pathlib
import re
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
DESIGN_DIR = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

from palette import build_palette  # noqa: E402
from svg_colors import colors_in_markup, palette_colors, unsupported_colors_in_markup  # noqa: E402

SPECIMEN = DESIGN_DIR / "specimen" / "index.html"


def css_vars(html: str) -> dict[str, str]:
    return {name: value.lower() for name, value in re.findall(r"(--[\w.-]+):\s*(#[0-9a-fA-F]{6})", html)}


def test_specimen_variables_match_palette():
    palette = build_palette()
    variables = css_vars(SPECIMEN.read_text())
    for name, scale in palette["brand"].items():
        for step, hex_value in scale.items():
            assert variables[f"--{name}-{step}"] == hex_value
    for element, parts in palette["ohaeng"].items():
        for part, hex_value in parts.items():
            assert variables[f"--ohaeng-{element}-{part}"] == hex_value


def test_specimen_role_variables_match_palette():
    html = SPECIMEN.read_text()
    variables = css_vars(html)
    references = dict(re.findall(r"(--role-[\w-]+):\s*var\((--[\w-]+)\)", html))
    for mode, roles in build_palette()["roles"].items():
        for role, hex_value in roles.items():
            name = f"--role-{mode}-{role.replace('.', '-')}"
            assert name in references, name
            assert variables[references[name]] == hex_value, name


def test_specimen_uses_only_palette_colors():
    stray = colors_in_markup(SPECIMEN.read_text()) - palette_colors(build_palette()) - {"#ffffff"}
    assert stray == set(), f"{SPECIMEN.name}: 팔레트 밖 색 {sorted(stray)}"


def test_specimen_has_no_unsupported_colors():
    found = unsupported_colors_in_markup(SPECIMEN.read_text())
    assert found == set(), f"{SPECIMEN.name}: 검사할 수 없는 색 표기 {sorted(found)}"


def test_specimen_references_existing_logos():
    sources = re.findall(r'src="\.\./logo/([\w.-]+\.svg)"', SPECIMEN.read_text())
    assert sources
    for source in sources:
        assert (DESIGN_DIR / "logo" / source).exists(), source
