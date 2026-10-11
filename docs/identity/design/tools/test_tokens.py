"""토큰 생성기와 토큰 파일 테스트 (V1 spec §4~§7)."""
import pathlib
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

from dtcg import find_problems, flatten, resolve  # noqa: E402
from palette import build_palette  # noqa: E402
from tokens import TOKENS_DIR, build_token_files, color_value, reference_or_value, serialize  # noqa: E402

FILES = ["primitive.tokens.json", "color.light.tokens.json", "color.dark.tokens.json",
         "typography.tokens.json", "typography.ja.tokens.json"]


def test_committed_files_match_generator():
    for name, document in build_token_files().items():
        assert (TOKENS_DIR / name).read_text(encoding="utf-8") == serialize(document), name


def test_generator_is_deterministic():
    first = {name: serialize(document) for name, document in build_token_files().items()}
    second = {name: serialize(document) for name, document in build_token_files().items()}
    assert first == second


def test_files_pass_dtcg_checks():
    # 짝 파일은 같은 이름을 쓰므로, spec §6.2의 조합(primitive + 색 모드 하나 + 글자 언어 하나)마다 검사합니다.
    files = build_token_files()
    assert sorted(files) == sorted(FILES)
    for mode in ("color.light.tokens.json", "color.dark.tokens.json"):
        for language in ("typography.tokens.json", "typography.ja.tokens.json"):
            theme = {name: files[name] for name in ("primitive.tokens.json", mode, language)}
            assert find_problems(theme) == [], (mode, language)


def test_paired_files_have_same_names():
    files = build_token_files()
    assert flatten(files["color.light.tokens.json"]).keys() == flatten(files["color.dark.tokens.json"]).keys()
    assert flatten(files["typography.tokens.json"]).keys() == flatten(files["typography.ja.tokens.json"]).keys()


def test_resolved_roles_match_palette():
    files, palette = build_token_files(), build_palette()
    for mode in ("light", "dark"):
        tokens = {**flatten(files["primitive.tokens.json"]), **flatten(files[f"color.{mode}.tokens.json"])}
        for role, hex_color in palette["roles"][mode].items():
            assert resolve(f"color.{role}", tokens)["hex"] == hex_color, (mode, role)


def test_roles_reference_primitives():
    light = flatten(build_token_files()["color.light.tokens.json"])
    assert light["color.action.primary"]["$value"] == "{color.sage.700}"
    assert light["color.bg.sheet"]["$value"] == "{color.white}"


def test_unknown_hex_is_written_as_value():
    assert reference_or_value("#123456", {"color.sage.50": "#f2f9f3"}) == color_value("#123456")


def test_duplicate_hex_picks_first_name():
    assert reference_or_value("#ffffff", {"color.white": "#ffffff", "color.a": "#ffffff"}) == "{color.a}"


def test_duplicate_hex_orders_steps_by_number():
    primitives = {"color.neutral.100": "#eeeeed", "color.neutral.50": "#eeeeed"}
    assert reference_or_value("#eeeeed", primitives) == "{color.neutral.50}"


def test_color_value_components_and_alpha():
    assert color_value("#47634c") == {
        "colorSpace": "srgb", "components": [0.2784, 0.3882, 0.298], "hex": "#47634c"}
    assert color_value("#ffffff", 0.7)["alpha"] == 0.7


def test_alpha_colors():
    files = build_token_files()
    light = flatten(files["color.light.tokens.json"])
    dark = flatten(files["color.dark.tokens.json"])
    assert light["color.chip.bg"]["$value"] == color_value("#ffffff", 0.7)
    assert dark["color.chip.bg"]["$value"] == color_value("#ffffff", 0.08)
    assert light["color.swatch.border"]["$value"]["alpha"] == 0.18
    assert dark["color.swatch.border"]["$value"]["alpha"] == 0.28


def test_ohaeng_and_gradient():
    files, palette = build_token_files(), build_palette()
    primitive = flatten(files["primitive.tokens.json"])
    dark = flatten(files["color.dark.tokens.json"])
    assert primitive["color.ohaeng.wood.swatch"]["$value"]["hex"] == palette["ohaeng"]["wood"]["swatch"]
    assert dark["color.ohaeng.wood.bg"]["$value"]["hex"] == palette["ohaeng"]["wood"]["tint_dark"]
    assert dark["color.ohaeng.wood.fg"]["$value"]["hex"] == palette["ohaeng"]["wood"]["ink_dark"]
    gradient = dark["gradient.today"]
    assert [stop["color"]["hex"] for stop in gradient["$value"]] == palette["gradient"]["dark"]
    assert gradient["$extensions"] == {"io.github.june20516.myungli-diary": {"angle": 160}}


def test_space_and_radius():
    primitive = flatten(build_token_files()["primitive.tokens.json"])
    spaces = {name: token["$value"]["value"] for name, token in primitive.items() if name.startswith("space.")}
    assert spaces == {f"space.{value}": value for value in (2, 4, 8, 12, 16, 20, 24, 32, 48)}
    radii = {name: token["$value"]["value"] for name, token in primitive.items() if name.startswith("radius.")}
    assert radii == {"radius.xs": 4, "radius.sm": 8, "radius.md": 12, "radius.lg": 20,
                     "radius.xl": 28, "radius.full": 9999}


def test_typography_values():
    files = build_token_files()
    ko = flatten(files["typography.tokens.json"])
    ja = flatten(files["typography.ja.tokens.json"])
    assert ko["type.sentence.card"]["$value"]["lineHeight"] == 1.65
    assert ja["type.sentence.card"]["$value"]["lineHeight"] == 1.75
    assert ja["type.sentence.body"]["$value"]["lineHeight"] == 1.7
    assert ko["type.label.lg"]["$value"]["letterSpacing"] == {"value": -0.28, "unit": "px"}
    assert ja["type.label.lg"]["$value"]["letterSpacing"] == {"value": 0, "unit": "px"}
    assert ko["type.sentence.card"]["$value"]["letterSpacing"] == {"value": 0, "unit": "px"}
    assert ko["type.hanja.pillar"]["$value"]["fontFamily"] == "{font.family.hanja}"
    assert ko["type.numeric.calendar"]["$extensions"] == {
        "io.github.june20516.myungli-diary": {"fontFeatures": ["tnum"]}}
    assert ko["font.family.sentence"]["$value"] == ["Gowun Dodum", "Pretendard", "sans-serif"]
    assert ja["font.family.ui"]["$value"] == ["Pretendard JP", "sans-serif"]
    assert set(name for name in ko if name.startswith("type.")) == {
        "type.sentence.card", "type.sentence.body", "type.display", "type.title", "type.subtitle",
        "type.label.lg", "type.label.md", "type.caption.md", "type.caption.sm",
        "type.numeric.calendar", "type.numeric.table", "type.hanja.pillar",
        "type.body.ui", "type.caption.lg"}  # V2 추가


def test_readme_states_version_and_lists_files():
    readme = (TOKENS_DIR / "README.md").read_text(encoding="utf-8")
    assert "계약 버전: 1.1.0" in readme
    for name in FILES:
        assert name in readme


# V2 spec(2026-10-11-components-design.md) §5
def test_motion_and_shadow_tokens():
    tokens = flatten(build_token_files()["primitive.tokens.json"])
    assert tokens["motion.duration.stamp"]["$value"] == {"value": 520, "unit": "ms"}
    assert tokens["motion.duration.toast-hold"]["$value"] == {"value": 2500, "unit": "ms"}
    assert tokens["motion.duration.fade"]["$value"] == {"value": 280, "unit": "ms"}
    assert tokens["motion.easing.seep"]["$value"] == [0.2, 0.7, 0.2, 1]
    assert tokens["motion.easing.stamp-press"]["$value"] == [0.5, 0, 0.9, 0.6]
    assert tokens["shadow.raised"]["$type"] == "shadow"
    assert tokens["shadow.raised"]["$value"]["color"]["alpha"] == 0.14


def test_v2_color_roles_present_in_both_modes():
    files = build_token_files()
    for mode in ("light", "dark"):
        names = flatten(files[f"color.{mode}.tokens.json"]).keys()
        for name in ("color.scrim", "color.inverse.bg", "color.disabled.fg", "color.bar.bg", "color.seal.fill",
                     "color.seal.soft", "color.seal.knock", "color.status.bg", "color.tag.good.bg",
                     "color.tag.neutral.border", "color.calendar.weekday.sun", "color.skeleton.bone",
                     "color.timeline.line"):
            assert name in names


def test_v2_reference_roles():
    tokens = flatten(build_token_files()["color.light.tokens.json"])
    assert tokens["color.seal.fill"]["$value"] == "{color.action.primary}"
    assert tokens["color.calendar.weekday.sat"]["$value"] == "{color.ohaeng.earth.fg}"


def test_v2_alpha_roles():
    files = build_token_files()
    light = flatten(files["color.light.tokens.json"])
    dark = flatten(files["color.dark.tokens.json"])
    assert light["color.seal.soft"]["$value"]["alpha"] == 0.22
    assert dark["color.seal.soft"]["$value"]["alpha"] == 0.28
    assert dark["color.scrim"]["$value"]["hex"] == "#000000" and dark["color.scrim"]["$value"]["alpha"] == 0.5


def test_v2_type_styles():
    tokens = flatten(build_token_files()["typography.tokens.json"])
    assert tokens["type.caption.lg"]["$value"]["fontSize"] == {"value": 13, "unit": "px"}
    assert tokens["type.body.ui"]["$value"]["letterSpacing"] == {"value": -0.28, "unit": "px"}
    japanese = flatten(build_token_files()["typography.ja.tokens.json"])
    assert japanese["type.body.ui"]["$value"]["letterSpacing"] == {"value": 0, "unit": "px"}
