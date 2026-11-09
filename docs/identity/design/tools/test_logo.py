"""앱 아이콘 테스트: SVG(spec §6.1)와 래스터 원본(결정 V99)."""
import hashlib
import json
import pathlib
import re
import struct
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


# 앱 아이콘 래스터 원본 (결정 V99, #908). 원본 PNG는 tools/app_icon.py가 logo/source/에서 만들고
# logo/app-icon.json에 sha256과 안전 영역 측정값을 적습니다. 테스트는 표준 라이브러리만 씁니다(CI 의존성 그대로).
MANIFEST = json.loads((LOGO / "app-icon.json").read_text(encoding="utf-8"))
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
COLOR_TYPE_RGB, COLOR_TYPE_RGBA = 2, 6
RASTER_MASTERS = {
    "icon-large.png": COLOR_TYPE_RGB,  # App Store가 알파 채널을 거부하므로 큰, 작은 원형과 배경은 알파 없음
    "icon-small.png": COLOR_TYPE_RGB,
    "icon-android-background.png": COLOR_TYPE_RGB,
    "icon-android-foreground.png": COLOR_TYPE_RGBA,
    "lockup.png": COLOR_TYPE_RGBA,
    "lockup-dark.png": COLOR_TYPE_RGBA,
}


def png_chunks(path):
    data = path.read_bytes()
    assert data[:8] == PNG_SIGNATURE, path.name
    offset, chunks = 8, []
    while offset < len(data):
        length, kind = struct.unpack(">I4s", data[offset:offset + 8])
        chunks.append((kind.decode("ascii"), data[offset + 8:offset + 8 + length]))
        offset += 12 + length
    return chunks


def png_header(path):
    kind, body = png_chunks(path)[0]
    assert kind == "IHDR"
    width, height, bit_depth, color_type = struct.unpack(">IIBB", body[:10])
    return width, height, bit_depth, color_type


def test_manifest_lists_every_raster_master():
    assert set(MANIFEST["files"]) == set(RASTER_MASTERS)
    assert {path.name for path in LOGO.glob("*.png")} == set(RASTER_MASTERS)


@pytest.mark.parametrize("name, color_type", sorted(RASTER_MASTERS.items()))
def test_raster_master_matches_manifest(name, color_type):
    path = LOGO / name
    record = MANIFEST["files"][name]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record["sha256"], f"{name}: app_icon.py로 다시 만들지 않음"
    width, height, bit_depth, actual_type = png_header(path)
    assert [width, height] == record["size"] and bit_depth == 8 and actual_type == color_type
    if name.startswith("icon-"):
        assert width == height == MANIFEST["masterPx"] == 1024  # 풀블리드 정사각, 모서리는 플랫폼이 깎음
    else:
        assert height == MANIFEST["lockupHeightPx"]
    assert "tIME" not in {kind for kind, _ in png_chunks(path)}  # 같은 원본이면 같은 파일


def test_sources_match_manifest():
    for name, digest in MANIFEST["sources"].items():
        assert hashlib.sha256((LOGO / "source" / name).read_bytes()).hexdigest() == digest, name
    assert set(MANIFEST["sources"]) == {"book-detailed.png", "book-flat.png"}


def test_raster_android_foreground_sits_in_safe_zone():
    # 108dp 캔버스 가운데 66dp 원(반지름 33) 안에 책 몸통과 그림자 끝까지
    record = MANIFEST["androidForeground"]
    radius = record["safeDiameterDp"] / 2
    assert record["safeDiameterDp"] == 66
    assert record["bodyMaxRadiusDp"] <= record["anyMaxRadiusDp"] <= radius


def test_small_icon_enlarges_seal_like_v7():
    # 관문 Q1 ②: 작은 원형 낙관 1.45배(옛 작은 원형과 같은 34%), 큰 원형은 그대로
    assert MANIFEST["smallSealScale"] == 1.45


def test_lockup_corner_matches_wordmark_tool():
    from wordmark import ICON_CORNER_RATIO

    source = (TOOLS_DIR / "app_icon.py").read_text(encoding="utf-8")
    assert float(re.search(r"^LOCKUP_CORNER_RATIO = ([\d.]+)", source, re.M).group(1)) == ICON_CORNER_RATIO
