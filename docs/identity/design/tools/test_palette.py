"""palette.py 테스트: spec(2026-10-10-visual-identity-design.md) §3·§4의 값을 기준으로 합니다."""
import json
import pathlib
import re
import subprocess
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

from palette import build_palette, check_contrast, contrast_ratio, oklch_to_hex  # noqa: E402

PALETTE_PY = str(TOOLS_DIR / "palette.py")

SPEC_SAGE = {
    50: "#f2f9f3", 100: "#e8f2e9", 200: "#d4e3d6", 300: "#b8cebc", 400: "#96b49b",
    500: "#749a7b", 600: "#597f61", 700: "#47634c", 800: "#354838", 900: "#242f26",
}
SPEC_CORAL = {
    50: "#fef4f2", 100: "#ffe9e5", 200: "#f6d5d1", 300: "#e8bbb4", 400: "#d79990",
    500: "#c4776d", 600: "#a75c53", 700: "#814942", 800: "#5d3631", 900: "#3b2522",
}
SPEC_NEUTRAL = {
    50: "#f7f7f6", 100: "#eeeeed", 200: "#dededc", 300: "#c7c7c5", 400: "#ababa7",
    500: "#8f908b", 600: "#747570", 700: "#5b5b57", 800: "#424340", 900: "#2b2b2a", 950: "#1b1b1a",
}


def test_contrast_known_values():
    assert contrast_ratio("#ffffff", "#000000") == 21.0
    assert contrast_ratio("#FFFFFF", "#a75c53") == 4.89


@pytest.mark.parametrize("bad", ["#fff", "ffffff", "#gggggg", ""])
def test_contrast_rejects_malformed_hex(bad):
    with pytest.raises(ValueError):
        contrast_ratio(bad, "#000000")


def test_out_of_gamut_is_mapped_to_valid_hex():
    assert re.fullmatch(r"#[0-9a-f]{6}", oklch_to_hex(0.9, 0.4, 145))


def test_brand_scales_match_spec():
    palette = build_palette()["brand"]
    assert palette["sage"] == SPEC_SAGE
    assert palette["coral"] == SPEC_CORAL
    assert palette["neutral"] == SPEC_NEUTRAL


def test_ohaeng_matches_spec():
    ohaeng = build_palette()["ohaeng"]
    assert ohaeng["wood"]["swatch"] == "#418e47"
    assert ohaeng["water"]["swatch"] == "#153e78"
    assert ohaeng["metal"]["tint"] == "#e8ebef"
    assert ohaeng["metal"]["ink"] == "#454e58"
    assert ohaeng["fire"]["tint_dark"] == "#402623"
    assert ohaeng["earth"]["ink_dark"] == "#ead4b3"


def test_gradient_matches_spec():
    assert build_palette()["gradient"] == {
        "light": ["#eef4ef", "#fbefee"],
        "dark": ["#162017", "#271818"],
    }


def test_all_text_pairs_pass():
    results = check_contrast(build_palette())
    assert [r.name for r in results if not r.passed] == []
    ratios = {r.name: r.ratio for r in results}
    assert ratios["light badge.good"] == 4.89
    assert ratios["light term"] == 5.80


def test_check_contrast_flags_failure():
    palette = build_palette()
    palette["roles"]["light"]["badge.good.bg"] = "#f4b6ae"
    failed = [r for r in check_contrast(palette) if not r.passed]
    assert [r.name for r in failed] == ["light badge.good"]


def test_generation_is_deterministic():
    assert json.dumps(build_palette(), sort_keys=True) == json.dumps(build_palette(), sort_keys=True)


def test_cli_check_exit_code():
    result = subprocess.run([sys.executable, PALETTE_PY, "--check"], capture_output=True, text=True)
    assert result.returncode == 0
