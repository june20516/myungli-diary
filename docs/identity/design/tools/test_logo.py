"""앱 아이콘 SVG 테스트: spec §6.1."""
import pathlib
import sys
import xml.etree.ElementTree as ET

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
DESIGN_DIR = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

from palette import build_palette  # noqa: E402
from svg_colors import colors_in_markup, palette_colors, unsupported_colors_in_markup  # noqa: E402

SVG = "{http://www.w3.org/2000/svg}"
LOGO = DESIGN_DIR / "logo"
ICONS = ["icon-large.svg", "icon-small.svg", "icon-android-background.svg", "icon-android-foreground.svg"]


@pytest.mark.parametrize("name", ICONS)
def test_icon_uses_only_palette_colors(name):
    stray = colors_in_markup((LOGO / name).read_text()) - palette_colors(build_palette()) - {"#ffffff"}
    assert stray == set(), f"{name}: 팔레트 밖 색 {sorted(stray)}"


@pytest.mark.parametrize(
    "name, size",
    [
        ("icon-large.svg", 100),
        ("icon-small.svg", 100),
        ("icon-android-background.svg", 108),
        ("icon-android-foreground.svg", 108),
    ],
)
def test_icon_is_square_full_bleed(name, size):
    root = ET.parse(LOGO / name).getroot()
    assert root.get("viewBox") == f"0 0 {size} {size}"
    first_rect = root.find(f"{SVG}rect")
    if name != "icon-android-foreground.svg":
        assert first_rect.get("width") == str(size) and first_rect.get("rx") is None


def test_android_foreground_sits_in_safe_zone():
    root = ET.parse(LOGO / "icon-android-foreground.svg").getroot()
    groups = root.findall(f"{SVG}g")
    assert [group.get("transform") for group in groups] == ["translate(21 21) scale(0.66)"]
    assert root.find(f"{SVG}rect") is None


def test_colors_in_markup_finds_uppercase():
    assert colors_in_markup('fill="#A75C53"') == {"#a75c53"}


def test_colors_in_markup_converts_rgb_functions():
    assert colors_in_markup("rgba(43, 43, 42, .18) rgb(255,255,255)") == {"#2b2b2a", "#ffffff"}


def test_unsupported_colors_are_reported():
    markup = "#abc #a75c5380 hsl(0 0% 0%) oklch(0.5 0.1 20) color-mix(in srgb, #a75c53, #ffffff)"
    assert unsupported_colors_in_markup(markup) == {"#abc", "#a75c5380", "hsl(", "oklch(", "color-mix("}


def test_unsupported_colors_ignore_fragment_references():
    assert unsupported_colors_in_markup('url(#background-0) href="#lf" &#123; #a75c53') == set()


@pytest.mark.parametrize("name", ICONS)
def test_icon_has_no_unsupported_colors(name):
    found = unsupported_colors_in_markup((LOGO / name).read_text())
    assert found == set(), f"{name}: 검사할 수 없는 색 표기 {sorted(found)}"
