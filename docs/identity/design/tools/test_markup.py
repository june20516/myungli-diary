"""SVG 조립 도우미 테스트: 바깥 태그 벗기기, 가로 조합, 로고 모음."""
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
DESIGN_DIR = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

from logo_sheet import logo_sheet_svg  # noqa: E402
from svg_markup import inner_markup  # noqa: E402

LOGO = DESIGN_DIR / "logo"
LOGO_SHEET = DESIGN_DIR / "artifacts" / "2026-10-10-v0-logo-final.svg"
DECLARED_SVG = '<?xml version="1.0" encoding="UTF-8"?>\n<!-- 설명 -->\n<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><rect width="1" height="1"/></svg>\n'


def test_inner_markup_strips_declaration_and_leading_comment():
    assert inner_markup(DECLARED_SVG) == '<rect width="1" height="1"/>'


def test_inner_markup_keeps_inner_comments():
    assert inner_markup('<svg><!-- 안 --><g/></svg>') == "<!-- 안 --><g/>"


def test_logo_sheet_is_self_contained():
    sheet = logo_sheet_svg(LOGO)
    assert "href=" not in sheet
    root = ET.fromstring(sheet)
    ids = [element.get("id") for element in root.iter() if element.get("id")]
    assert len(ids) == len(set(ids)), "id 충돌"


def test_logo_sheet_matches_committed_artifact():
    assert logo_sheet_svg(LOGO) == LOGO_SHEET.read_text(encoding="utf-8")


def test_logo_sheet_has_no_xml_declaration_inside():
    assert len(re.findall(r"<\?xml", logo_sheet_svg(LOGO))) == 0
