"""palette.py 테스트: spec(2026-10-10-visual-identity-design.md) §3·§4의 값을 기준으로 합니다."""
import json
import pathlib
import re
import subprocess
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import palette  # noqa: E402
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
    ratios = {r.name: round(r.ratio, 2) for r in results}
    assert ratios["light badge.good"] == 4.89
    assert ratios["light term"] == 5.80


def test_check_contrast_compares_unrounded_ratio():
    palette = build_palette()
    palette["roles"]["light"]["badge.good.bg"] = "#6363f8"  # 흰 글자 대비 4.496, 반올림하면 4.50
    result = next(r for r in check_contrast(palette) if r.name == "light badge.good")
    assert result.passed is False


def test_check_contrast_flags_failure():
    palette = build_palette()
    palette["roles"]["light"]["badge.good.bg"] = "#f4b6ae"
    failed = [r for r in check_contrast(palette) if not r.passed]
    assert [r.name for r in failed] == ["light badge.good"]


def test_cli_json_output_is_deterministic():
    first = subprocess.run([sys.executable, PALETTE_PY], capture_output=True, check=True).stdout
    second = subprocess.run([sys.executable, PALETTE_PY], capture_output=True, check=True).stdout
    assert first == second
    assert json.loads(first)["brand"]["sage"]["600"] == "#597f61"


def test_cli_check_exit_code():
    result = subprocess.run([sys.executable, PALETTE_PY, "--check"], capture_output=True, text=True)
    assert result.returncode == 0


def test_cli_check_reports_failure(monkeypatch, capsys):
    failing = build_palette()
    failing["roles"]["light"]["badge.good.bg"] = "#f4b6ae"
    monkeypatch.setattr(palette, "build_palette", lambda: failing)
    assert palette.main(["--check"]) == 1
    output = capsys.readouterr().out
    assert "FAIL  1.73  light badge.good" in output


V1_ROLES = {
    "light": {"badge.gwiin.bg": ("coral", 100), "badge.gwiin.fg": ("coral", 700),
              "badge.gisin.bg": ("neutral", 100), "badge.gisin.fg": ("neutral", 700),
              "badge.ordinary.border": ("neutral", 300), "badge.ordinary.fg": ("neutral", 700),
              "calendar.good.bg": ("coral", 100), "calendar.caution.bg": ("neutral", 100)},
    "dark": {"badge.gwiin.bg": ("coral", 800), "badge.gwiin.fg": ("coral", 200),
             "badge.gisin.bg": ("neutral", 800), "badge.gisin.fg": ("neutral", 200),
             "badge.ordinary.border": ("neutral", 700), "badge.ordinary.fg": ("neutral", 400),
             "calendar.good.bg": ("coral", 900), "calendar.caution.bg": ("neutral", 900)},
}


def test_v1_roles_follow_spec():
    palette = build_palette()
    for mode, roles in V1_ROLES.items():
        for role, (scale, step) in roles.items():
            assert palette["roles"][mode][role] == palette["brand"][scale][step], (mode, role)


def test_contrast_covers_v1_pairs():
    names = {result.name for result in check_contrast(build_palette())}
    assert len(names) == 52
    for mode in ("light", "dark"):
        assert f"{mode} badge.gwiin" in names
        assert f"{mode} badge.gisin" in names
        for background in ("bg.base", "bg.sheet", "gradient[0]", "gradient[1]"):
            assert f"{mode} badge.ordinary.fg on {background}" in names
        for text_role in ("text.primary", "text.secondary"):
            for cell in ("calendar.good.bg", "calendar.caution.bg"):
                assert f"{mode} {text_role} on {cell}" in names
