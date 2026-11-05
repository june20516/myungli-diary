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


# V2 spec §8
def test_specimen_has_v2_section():
    html = SPECIMEN.read_text(encoding="utf-8")
    assert 'id="v2-elements"' in html
    for element in ("seal-fill", "seal-soft", "seal-outline", "tag-good", "tag-bad", "tag-neutral", "status-tag",
                    "caution-mark"):
        assert f'data-element="{element}"' in html, element
    assert "../components/README.md" in html


def test_specimen_has_motion_samples():
    html = SPECIMEN.read_text(encoding="utf-8")
    for pattern in ("appear.seep", "select.seep-slide", "loading.breathe", "seal.stamp", "mark.underline-grow", "press.ink"):
        assert f'data-pattern="{pattern}"' in html, pattern
    assert "prefers-reduced-motion" in html


def test_specimen_seal_uses_logo_path():
    html = SPECIMEN.read_text(encoding="utf-8")
    assert "M1.2 1.5 q8.8 -1.3 17.6 0 q1.2 8.5 0 17 q-8.8 1.3 -17.6 0 q-1.2 -8.5 0 -17 z" in html


DS1_RULES_PAGE = DESIGN_DIR / "artifacts" / "2026-11-05-ds1-rules.html"


def test_ds1_rules_page_uses_only_token_variables():
    """DS1 규칙 견본은 색을 직접 쓰지 않고 토큰 CSS 변수만 씁니다(D105 ④)."""
    html = DS1_RULES_PAGE.read_text(encoding="utf-8")

    assert 'href="ds1/tokens.css"' in html
    assert re.findall(r"""(?:[:=]\s*["']?|,\s*)#[0-9a-fA-F]{3,8}\b""", html) == []
    assert "rgb(" not in html and "rgba(" not in html and "hsl(" not in html
    assert "var(--color-" in html


def test_ds1_rules_page_has_no_forbidden_dashes():
    """사용자에게 보이는 견본 글에 긴 대시, 범위 대시, 가운뎃점을 쓰지 않습니다(D93)."""
    html = DS1_RULES_PAGE.read_text(encoding="utf-8")

    assert [char for char in ("—", "–", "·") if char in html] == []
