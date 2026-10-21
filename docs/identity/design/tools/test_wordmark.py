"""워드마크·가로 조합 테스트: spec §6.2."""
import pathlib
import sys
import xml.etree.ElementTree as ET

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
DESIGN_DIR = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

from palette import build_palette  # noqa: E402
from svg_colors import colors_in_markup, palette_colors, unsupported_colors_in_markup  # noqa: E402
from wordmark import lockup_svg, wordmark_svg  # noqa: E402

SVG = "{http://www.w3.org/2000/svg}"
LOGO = DESIGN_DIR / "logo"


@pytest.fixture
def font_path(font_dir):
    return font_dir / "GowunDodum-Regular.ttf"


def test_wordmark_is_outlined(font_path):
    svg = wordmark_svg(font_path, "명리일기", "#2b2b2a")
    root = ET.fromstring(svg)
    assert root.find(f".//{SVG}text") is None
    assert len(root.findall(f".//{SVG}path")) == 4
    assert colors_in_markup(svg) == {"#2b2b2a"}


def test_wordmark_rejects_missing_glyph(font_path):
    with pytest.raises(ValueError):
        wordmark_svg(font_path, "명리일기☃", "#2b2b2a")


def test_lockup_accepts_icon_with_xml_declaration():
    icon = '<?xml version="1.0"?>\n' + (LOGO / "icon-large.svg").read_text()
    wordmark = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 100"><path d="M0 0h1v1z"/></svg>'
    lockup = lockup_svg(icon, wordmark)
    assert "<?xml" not in lockup
    assert len(ET.fromstring(lockup).findall(f"{SVG}svg")) == 2  # 아이콘과 워드마크, 한 겹씩


@pytest.mark.parametrize("name", ["wordmark.svg", "wordmark-dark.svg", "lockup.svg", "lockup-dark.svg"])
def test_logo_files_use_palette_colors(name):
    markup = (LOGO / name).read_text()
    stray = colors_in_markup(markup) - palette_colors(build_palette()) - {"#ffffff"}
    assert stray == set(), f"{name}: 팔레트 밖 색 {sorted(stray)}"
    assert unsupported_colors_in_markup(markup) == set(), name
