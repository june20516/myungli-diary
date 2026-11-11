"""토큰 생성기와 토큰 파일 테스트 (V1 spec §4~§7)."""
import pathlib
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

from dtcg import find_problems, flatten, resolve  # noqa: E402
from palette import (  # noqa: E402
    CLEAR_LEVEL_MODES, MAX_CAUTION_CHROMA, MAX_GREAT_GOOD_LIGHTNESS_GAP, MIN_GREAT_GOOD_CHROMA_GAP, MIN_LEVEL_DISTANCE, MIN_TEXT_CONTRAST, build_palette,
    contrast_ratio, oklab_distance, oklch_lightness_chroma)
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
    assert "계약 버전: 1.8.0" in readme
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


# 같은 날 일기 사이 점선 (2026-10-22-diary-row-multi-design.md §5)
def test_timeline_entry_role():
    files = build_token_files()
    light = flatten(files["color.light.tokens.json"])
    dark = flatten(files["color.dark.tokens.json"])
    assert light["color.timeline.entry"]["$value"] == "{color.neutral.300}"
    assert dark["color.timeline.entry"]["$value"] == "{color.neutral.700}"


# DS1 spec(2026-11-05-ds1-rules-design.md) §8: 1.3.0은 추가만
TOKENS_1_3_0_ADDED = {
    "border.width.hairline": ("dimension", {"value": 0.5, "unit": "px"}),
    "size.icon.16": ("dimension", {"value": 16, "unit": "px"}),
    "size.icon.20": ("dimension", {"value": 20, "unit": "px"}),
    "size.icon.24": ("dimension", {"value": 24, "unit": "px"}),
    "size.icon.28": ("dimension", {"value": 28, "unit": "px"}),
    "motion.duration.page": ("duration", {"value": 320, "unit": "ms"}),
    "motion.easing.page": ("cubicBezier", [0.2, 0.8, 0.2, 1]),
    "motion.offset.page": ("dimension", {"value": 24, "unit": "px"}),
}


def test_tokens_1_3_0_additions_only():
    import json
    before = flatten(json.loads((TOOLS_DIR / "fixtures" / "primitive-1.2.0.tokens.json").read_text(encoding="utf-8")))
    after = flatten(build_token_files()["primitive.tokens.json"])

    for name, token in before.items():
        if name in TOKENS_1_5_0_CHANGED:  # 1.5.0에서 값만 바뀜(아래 test_tokens_1_5_0이 검사)
            continue
        assert after.get(name) == token, name
    added = {name: (after[name]["$type"], after[name]["$value"]) for name in after.keys() - before.keys()}
    assert added == TOKENS_1_3_0_ADDED


# 1.5.0 (D114, #892, 결정 V98): 금 흰색, 수 먹색. 금과 수의 견본, 바탕, 글자 값만 바뀌고(이름 그대로),
# 금과 수 칸 테두리와 다섯 오행의 간지 태그 한자색이 추가됨. 나머지는 1.4.0과 같음
TOKENS_1_5_0_CHANGED = {
    f"color.ohaeng.{element}.{part}" for element in ("metal", "water") for part in ("swatch", "bg", "fg")}
TOKENS_1_5_0_ADDED_COLOR = (
    {f"color.ohaeng.{element}.border" for element in ("metal", "water")}
    | {f"color.ohaeng.{element}.glyph" for element in ("wood", "fire", "earth", "metal", "water")})


def test_tokens_1_5_0_changes_only_metal_and_water():
    files = build_token_files()
    palette_ohaeng = build_palette()["ohaeng"]
    pairs = [("primitive.tokens.json", "primitive-1.4.0.tokens.json")]
    pairs += [(f"color.{mode}.tokens.json", f"color.{mode}-1.4.0.tokens.json") for mode in ("light", "dark")]
    for current, frozen in pairs:
        before, after = _frozen(frozen), flatten(files[current])
        for name, token in before.items():
            if name in TOKENS_1_5_0_CHANGED:
                assert after[name]["$type"] == token["$type"], name
                assert after[name]["$value"] != token["$value"], name
                continue
            assert after.get(name) == token, (current, name)
        added = after.keys() - before.keys()
        expected = TOKENS_1_5_0_ADDED_COLOR | TOKENS_1_6_0_ADDED_COLOR | TOKENS_1_7_0_ADDED | TOKENS_1_8_0_ADDED
        assert added == (set() if current.startswith("primitive") else expected), current
    for mode, cell in (("light", "tint"), ("dark", "tint_dark")):
        tokens = flatten(files[f"color.{mode}.tokens.json"])
        for element in ("metal", "water"):
            assert tokens[f"color.ohaeng.{element}.bg"]["$value"]["hex"] == palette_ohaeng[element][cell]
    light, dark = (flatten(files[f"color.{mode}.tokens.json"]) for mode in ("light", "dark"))
    # 테두리가 필요 없는 모드는 칸 바탕을 가리키는 별칭
    assert light["color.ohaeng.water.border"]["$value"] == "{color.ohaeng.water.bg}"
    assert dark["color.ohaeng.metal.border"]["$value"] == "{color.ohaeng.metal.bg}"
    assert light["color.ohaeng.metal.border"]["$value"]["hex"] == palette_ohaeng["metal"]["border"]
    assert dark["color.ohaeng.water.border"]["$value"]["hex"] == palette_ohaeng["water"]["border_dark"]
    # 간지 태그 한자색: 반전 칸(라이트 수, 다크 금)만 알약 바탕색
    assert light["color.ohaeng.water.glyph"]["$value"] == "{color.ohaeng.water.bg}"
    assert dark["color.ohaeng.metal.glyph"]["$value"] == "{color.ohaeng.metal.bg}"
    for element in ("wood", "fire", "earth", "metal"):
        assert light[f"color.ohaeng.{element}.glyph"]["$value"] == "{color.ohaeng." + element + ".fg}"
    for element in ("wood", "fire", "earth", "water"):
        assert dark[f"color.ohaeng.{element}.glyph"]["$value"] == "{color.ohaeng." + element + ".fg}"


# 1.8.0 (#1003, D122, 결정 V115): 집중 시간 해와 달 아이콘 color.time.day, color.time.night 추가만
TOKENS_1_8_0_ADDED = {"color.time.day", "color.time.night"}


def test_tokens_1_8_0_adds_only_time_icons():
    from palette import build_palette, contrast_ratio
    files = build_token_files()
    roles = build_palette()["roles"]
    for current, frozen in [("primitive.tokens.json", "primitive-1.7.0.tokens.json")] + [
            (f"color.{mode}.tokens.json", f"color.{mode}-1.7.0.tokens.json") for mode in ("light", "dark")]:
        before, after = _frozen(frozen), flatten(files[current])
        for name, token in before.items():
            assert after.get(name) == token, (current, name)
        added = after.keys() - before.keys()
        assert added == (set() if current.startswith("primitive") else TOKENS_1_8_0_ADDED), current
    expected = {"light": ("#b8811a", "#355a8f"), "dark": ("#dea645", "#8fa9d1")}
    for mode, (day, night) in expected.items():
        tokens = flatten(files[f"color.{mode}.tokens.json"])
        assert tokens["color.time.day"]["$value"]["hex"] == day
        assert tokens["color.time.night"]["$value"]["hex"] == night
        for part in ("day", "night"):
            # 칩 바탕 위 비텍스트 대비 3:1 (V115)
            assert contrast_ratio(roles[mode][f"time.{part}"], roles[mode]["bg.sheet"]) >= 3.0


# 1.7.0 (#950, D118, 결정 V111): 열린 근거 표시 그라데이션 gradient.unlocked 추가만
TOKENS_1_7_0_ADDED = {"gradient.unlocked"}


def test_tokens_1_7_0_adds_only_unlocked_gradient():
    from palette import build_palette
    files = build_token_files()
    palette = build_palette()
    for current, frozen in [("primitive.tokens.json", "primitive-1.6.0.tokens.json")] + [
            (f"color.{mode}.tokens.json", f"color.{mode}-1.6.0.tokens.json") for mode in ("light", "dark")]:
        before, after = _frozen(frozen), flatten(files[current])
        for name, token in before.items():
            assert after.get(name) == token, (current, name)
        added = after.keys() - before.keys()
        assert added == (set() if current.startswith("primitive") else TOKENS_1_7_0_ADDED | TOKENS_1_8_0_ADDED), current
    for mode in ("light", "dark"):
        token = flatten(files[f"color.{mode}.tokens.json"])["gradient.unlocked"]
        assert token["$type"] == "gradient"
        assert [stop["color"]["hex"] for stop in token["$value"]] == palette["unlocked"][mode]
        assert [stop["position"] for stop in token["$value"]] == [0.0, 0.5, 1.0]
        assert token["$extensions"] == {"io.github.june20516.myungli-diary": {"angle": 90}}
    brand = palette["brand"]
    # 세이지와 산호 끝은 브랜드 단계, 가운데만 금빛
    assert palette["unlocked"]["light"][0] == brand["sage"][700] and palette["unlocked"]["light"][2] == brand["coral"][600]
    assert palette["unlocked"]["dark"][0] == brand["sage"][400] and palette["unlocked"]["dark"][2] == brand["coral"][400]


# 1.6.0 (#929, D116, 결정 V102): 권유 글자 color.invite.fg(라이트 sage 600, 다크 sage 400) 추가만
TOKENS_1_6_0_ADDED_COLOR = {"color.invite.fg"}


def test_tokens_1_6_0_adds_only_invite_fg():
    files = build_token_files()
    for current, frozen in [("primitive.tokens.json", "primitive-1.5.0.tokens.json")] + [
            (f"color.{mode}.tokens.json", f"color.{mode}-1.5.0.tokens.json") for mode in ("light", "dark")]:
        before, after = _frozen(frozen), flatten(files[current])
        for name, token in before.items():
            assert after.get(name) == token, (current, name)
        added = after.keys() - before.keys()
        assert added == (set() if current.startswith("primitive") else TOKENS_1_6_0_ADDED_COLOR | TOKENS_1_7_0_ADDED | TOKENS_1_8_0_ADDED), current
    light, dark = (flatten(files[f"color.{mode}.tokens.json"]) for mode in ("light", "dark"))
    assert light["color.invite.fg"]["$value"] == "{color.sage.600}"
    assert dark["color.invite.fg"]["$value"] == "{color.sage.400}"


# DS1 spec(2026-11-05-ds1-screens-design.md) §3: 1.4.0은 추가만. 1.3.0 primitive와 색 두 파일을 얼려 둠
TOKENS_1_4_0_ADDED_COLOR = {
    "color.calendar.level.great", "color.calendar.level.good", "color.calendar.level.caution",
    "color.fill.soft", "color.verdict.track",
    "color.highlight.bg",  # 관문 답 2026-11-07 Q4 ③: 강조 바탕 회색 (V93)
}


def _frozen(name):
    import json
    return flatten(json.loads((TOOLS_DIR / "fixtures" / name).read_text(encoding="utf-8")))


def test_tokens_1_4_0_additions_only():
    files = build_token_files()
    after_primitive = flatten(files["primitive.tokens.json"])
    before_primitive = _frozen("primitive-1.3.0.tokens.json")
    for name, token in before_primitive.items():
        if name in TOKENS_1_5_0_CHANGED:
            continue
        assert after_primitive.get(name) == token, name
    assert after_primitive.keys() == before_primitive.keys()  # primitive는 추가 없음

    for mode in ("light", "dark"):
        before = _frozen(f"color.{mode}-1.3.0.tokens.json")
        after = flatten(files[f"color.{mode}.tokens.json"])
        for name, token in before.items():
            if name.startswith("color.tag."):  # V96: 설명만 지금 쓰임으로 고침. 값과 형식은 그대로
                assert {k: v for k, v in after[name].items() if k != "$description"} == \
                       {k: v for k, v in token.items() if k != "$description"}, (mode, name)
                assert "태그 칩" not in after[name]["$description"], (mode, name)
                continue
            if name in TOKENS_1_5_0_CHANGED:
                continue
            assert after.get(name) == token, (mode, name)
        assert set(after.keys() - before.keys()) == (
            TOKENS_1_4_0_ADDED_COLOR | TOKENS_1_5_0_ADDED_COLOR | TOKENS_1_6_0_ADDED_COLOR | TOKENS_1_7_0_ADDED | TOKENS_1_8_0_ADDED), mode
        # 기존 calendar.good.bg, calendar.caution.bg는 그대로(위 반복이 값까지 검사)
        assert "color.calendar.good.bg" in before and "color.calendar.caution.bg" in before


def test_verdict_track_runs_from_caution_to_great():
    # 기대값은 build_palette()에서 오고, 커밋 파일과의 일치는 test_committed_files_match_generator가 보장
    files = build_token_files()
    for mode in ("light", "dark"):
        tokens = flatten(files[f"color.{mode}.tokens.json"])
        track = tokens["color.verdict.track"]
        assert track["$type"] == "gradient"
        stops = track["$value"]
        assert [stop["position"] for stop in stops] == [0, 1]
        palette_roles = build_palette()["roles"][mode]
        assert stops[0]["color"]["hex"] == palette_roles["calendar.level.caution"]
        assert stops[1]["color"]["hex"] == palette_roles["calendar.level.great"]


def _level_hexes(mode):
    roles = build_palette()["roles"][mode]
    return {
        "great": roles["calendar.level.great"], "good": roles["calendar.level.good"],
        "caution": roles["calendar.level.caution"], "ordinary": roles["bg.base"],
    }


def test_calendar_levels_distinguishable():
    for mode in ("light", "dark"):
        hexes = _level_hexes(mode)
        for first, second in (("great", "good"), ("good", "ordinary"), ("good", "caution"), ("caution", "ordinary")):
            assert oklab_distance(hexes[first], hexes[second]) >= MIN_LEVEL_DISTANCE, (mode, first, second)
        great_lightness, _ = oklch_lightness_chroma(hexes["great"])
        good_lightness, _ = oklch_lightness_chroma(hexes["good"])
        if mode in CLEAR_LEVEL_MODES:
            # 사용자 결정 2026-11-07(#801 관문 Q1 ⑤): 두 단계 모두 맑게(흰색만 섞은 coral, 가장 큰 RGB 채널 255),
            # 아주 잘 풀리는 날이 더 진하게(명도는 낮고 채도는 높음). 잘 풀리는 날이 탁하면 부정적으로 보임
            for level in ("great", "good"):
                assert max(int(hexes[level][i:i + 2], 16) for i in (1, 3, 5)) == 255, (mode, level, hexes[level])
            assert great_lightness < good_lightness, mode
        else:
            assert abs(great_lightness - good_lightness) <= MAX_GREAT_GOOD_LIGHTNESS_GAP, mode
        chroma_gap = oklch_lightness_chroma(hexes["great"])[1] - oklch_lightness_chroma(hexes["good"])[1]
        assert chroma_gap >= MIN_GREAT_GOOD_CHROMA_GAP, (mode, chroma_gap)
        assert oklch_lightness_chroma(hexes["caution"])[1] <= MAX_CAUTION_CHROMA, mode


def test_calendar_number_contrast():
    for mode in ("light", "dark"):
        text = build_palette()["roles"][mode]["text.primary"]
        for level, background in _level_hexes(mode).items():
            assert contrast_ratio(text, background) >= MIN_TEXT_CONTRAST, (mode, level)


def test_fill_soft_visible_on_sheet():
    for mode in ("light", "dark"):
        roles = build_palette()["roles"][mode]
        assert oklab_distance(roles["fill.soft"], roles["bg.sheet"]) >= MIN_LEVEL_DISTANCE, mode


def test_calendar_level_values_chosen_by_user():
    # 관문 답 2026-11-07 Q1 ⑤(라이트만, 다크는 그대로)
    light, dark = _level_hexes("light"), _level_hexes("dark")
    assert (light["great"], light["good"], light["caution"]) == ("#ffd2ca", "#ffe4df", "#d4d4d3")
    assert (dark["great"], dark["good"], dark["caution"]) == ("#582720", "#46322f", "#2a2a29")


# 관문 답 2026-11-07 Q4 ③(V93): 강조 바탕은 새 primitive 없이 neutral.50(다크 neutral.950). sage 칩, 꼬리표와 갈림
def test_highlight_bg_is_soft_gray():
    palette = build_palette()
    neutral = palette["brand"]["neutral"]
    for mode, step in (("light", 50), ("dark", 950)):
        roles = palette["roles"][mode]
        assert roles["highlight.bg"] == neutral[step], mode
        assert oklab_distance(roles["highlight.bg"], roles["bg.sheet"]) >= 0.02, mode  # 카드와 화면 바탕 구분만큼
        assert oklab_distance(roles["highlight.bg"], roles["term.bg"]) >= 0.025, mode  # sage 칩과 꼬리표가 묻히지 않음
        assert contrast_ratio(roles["action.primary"], roles["highlight.bg"]) >= 4.5, mode
