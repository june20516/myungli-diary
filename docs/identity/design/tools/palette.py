"""명리일기 V0 색 체계 생성기와 대비 검사기.

spec: docs/identity/design/specs/2026-10-10-visual-identity-design.md §3·§4,
      docs/identity/design/specs/2026-10-11-design-tokens-design.md §3·§7 (V1 역할),
      docs/identity/design/specs/2026-10-11-components-design.md §5.3 (V2 역할)

사용법:
    python3 palette.py            # 팔레트 전체를 JSON으로 출력
    python3 palette.py --check    # 글자 조합 대비를 검사하고, 미달이 있으면 종료 코드 1
"""
from __future__ import annotations

import json
import math
import re
import sys
from dataclasses import dataclass

MIN_TEXT_CONTRAST = 4.5
# 비활성 글자는 WCAG 1.4.3 예외지만 3:1은 지킵니다 (V2 spec §5.3)
MIN_DISABLED_CONTRAST = 3.0
# 옅은 낙관 도장: 모드 → (팔레트, 단계, 알파) (V2 spec §5.3)
SEAL_SOFT = {"light": ("sage", 700, 0.22), "dark": ("sage", 200, 0.28)}

# 모든 팔레트가 공유하는 명도 단계 (spec §3.1)
LIGHTNESS_BY_STEP = {
    50: 0.975, 100: 0.95, 200: 0.90, 300: 0.83, 400: 0.74, 500: 0.65,
    600: 0.56, 700: 0.47, 800: 0.38, 900: 0.29, 950: 0.22,
}
STEPS_WITHOUT_950 = tuple(step for step in LIGHTNESS_BY_STEP if step != 950)
ALL_STEPS = tuple(LIGHTNESS_BY_STEP)

# 팔레트 이름: (hue, 최대 채도, 단계)
BRAND_SCALES = {
    "sage": (150, 0.07, STEPS_WITHOUT_950),
    "coral": (28, 0.11, STEPS_WITHOUT_950),
    "neutral": (110, 0.008, ALL_STEPS),
}

# 오행: (hue, 견본 명도, 견본 채도) (spec §3.3). 금과 수는 아래 OHAENG_FIXED가 모든 값을 정합니다.
OHAENG_SWATCHES = {
    "wood": (145, 0.58, 0.13),
    "fire": (27, 0.60, 0.17),
    "earth": (78, 0.76, 0.13),
    "metal": (250, 0.985, 0.004),
    "water": (258, 0.24, 0.025),
}
# 목, 화, 토의 옅은 바탕과 글자 (명도, 채도)
OHAENG_TEXT_LEVELS = {
    "tint": (0.94, 0.03),
    "ink": (0.42, 0.08),
    "tint_dark": (0.30, 0.04),
    "ink_dark": (0.88, 0.05),
}
# 금은 흰색, 수는 먹색(국내 사주 앱 관습과 원전 水黑, 淮南子 白虎·玄武. D114, #892, 결정 V98).
# 부위 → (명도, 채도). 모드와 관계없이 금은 가장 밝은 칸, 수는 가장 어두운 칸(관문 Q2 A).
# 수는 반전 칸(진한 바탕 + 흰 글자). border는 칸이 화면 바탕과 가까운 모드에서만 보이는 1px 안쪽 선이고,
# 칸이 바탕과 충분히 다른 모드에서는 None(= 칸 바탕과 같은 값, 보이지 않음)입니다.
OHAENG_FIXED = {
    "metal": {
        "swatch": (0.985, 0.004), "tint": (0.975, 0.004), "ink": (0.42, 0.015),
        "tint_dark": (0.88, 0.006), "ink_dark": (0.32, 0.015),
        "border": (0.80, 0.01), "border_dark": None,
    },
    "water": {
        "swatch": (0.24, 0.025), "tint": (0.30, 0.03), "ink": (0.96, 0.01),  # 관문 Q1 ① 먹남
        "tint_dark": (0.17, 0.02), "ink_dark": (0.90, 0.01),
        "border": None, "border_dark": (0.38, 0.02),
    },
}
# 칸 테두리가 필요한지 가르는 기준: 칸 바탕이나 테두리 중 하나는 칸이 놓이는 면(bg.sheet, bg.base, highlight.bg)과
# 이 대비 이상 (금, 수)
MIN_OHAENG_EDGE_CONTRAST = 1.4

GRADIENT_LIGHT = ["#eef4ef", "#fbefee"]
GRADIENT_DARK_OKLCH = [(0.23, 0.022, 150), (0.23, 0.024, 20)]
# 열린 근거 표시 그라데이션(D118, 결정 V111, 토큰 1.7.0): 세이지 → 금빛 → 산호. 구역 제목 글자와 반짝임 띠로도
# 쓰여 멈춤 색마다 bg.base, bg.sheet 위 글자 대비 4.5:1을 넘깁니다. 세이지와 산호는 브랜드 단계, 금빛만 OKLCH 값.
# 시안 가안(라이트 #b08a3e, #c4776c)은 흰 바탕에서 3.0~3.4:1이라 같은 색상에서 명도를 낮춤.
UNLOCKED_GRADIENT = {
    "light": [("sage", 700), (0.53, 0.105, 80), ("coral", 600)],
    "dark": [("sage", 400), (0.80, 0.105, 80), ("coral", 400)],
}

# 달력 4단계 (DS1 spec 2026-11-05-ds1-screens-design.md §3, 토큰 1.4.0): 모드 → 단계 → (명도, 채도, hue).
# 라이트(CLEAR_LEVEL_MODES)는 잘 풀리는 날 둘을 모두 맑게 둡니다: 채도를 sRGB 끝까지 올려(oklch_to_hex가 경계로 자름)
# 흰색만 섞은 coral이 되고, 아주 잘 풀리는 날이 명도는 낮고 채도는 높습니다(사용자 결정 2026-11-07, #801 관문 Q1 ⑤:
# 잘 풀리는 날이 탁해 보이면 부정적으로 읽힘). 다크는 명도를 같게 두고 채도로만 가릅니다.
# 조심할 날은 회색으로 명도를 낮춰 구분합니다. 값이 아니라 규칙(아래 상수)을 test_tokens.py가 다시 재서 검사합니다.
CALENDAR_LEVELS = {
    "light": {"great": (0.90, 0.075, 30), "good": (0.94, 0.075, 30), "caution": (0.87, 0.0015, 110)},
    "dark": {"great": (0.34, 0.075, 30), "good": (0.34, 0.030, 30), "caution": (0.285, 0.002, 110)},
}
MIN_LEVEL_DISTANCE = 0.03  # 이웃한 단계, 바탕, 흰 표면 위 채움의 OKLab 거리 하한
CLEAR_LEVEL_MODES = ("light",)  # 잘 풀리는 두 단계가 흰색만 섞은 순색(가장 큰 RGB 채널 255)인 모드
MAX_GREAT_GOOD_LIGHTNESS_GAP = 0.005  # CLEAR_LEVEL_MODES 밖(다크): 두 단계 명도가 같음
MAX_CAUTION_CHROMA = 0.003
# 아주 잘 풀리는 날이 잘 풀리는 날보다 채도가 이만큼 이상 높아야 함(두 모드 모두)
MIN_GREAT_GOOD_CHROMA_GAP = 0.02
# 흰 표면(bg.sheet) 위 옅은 채움: 라이트는 neutral-100, 다크는 neutral-800
FILL_SOFT_STEP = {"light": 100, "dark": 800}
# 현재 강조 바탕(지금 대운, 올해 세운 칸, 띠 표 일주 열): 회색이라 sage 꼬리표와 용어 칩이 묻히지 않음.
# 화면 바탕(bg.base)과 같은 단계지만 그 역할을 가리키지 않고 따로 둠. 카드(bg.sheet) 위에서만 씀 (V93, #801 관문 Q4 ③)
HIGHLIGHT_STEP = {"light": 50, "dark": 950}

WHITE = "#ffffff"
HEX_PATTERN = re.compile(r"#[0-9a-fA-F]{6}")


@dataclass(frozen=True)
class ContrastResult:
    name: str
    foreground: str
    background: str
    ratio: float
    passed: bool


def _oklch_to_linear_srgb(lightness: float, chroma: float, hue: float) -> tuple[float, float, float]:
    hue_radians = math.radians(hue)
    a = chroma * math.cos(hue_radians)
    b = chroma * math.sin(hue_radians)
    l_ = lightness + 0.3963377774 * a + 0.2158037573 * b
    m_ = lightness - 0.1055613458 * a - 0.0638541728 * b
    s_ = lightness - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def _is_in_srgb_gamut(rgb: tuple[float, float, float]) -> bool:
    return all(-1e-4 <= channel <= 1 + 1e-4 for channel in rgb)


def _gamma_encode(channel: float) -> float:
    channel = min(max(channel, 0.0), 1.0)
    if channel <= 0.0031308:
        return 12.92 * channel
    return 1.055 * channel ** (1 / 2.4) - 0.055


def oklch_to_hex(lightness: float, chroma: float, hue: float) -> str:
    """OKLCH를 sRGB hex로 바꿉니다. sRGB 밖이면 채도를 0.001씩 줄여 맞춥니다."""
    rgb = _oklch_to_linear_srgb(lightness, chroma, hue)
    while chroma > 0 and not _is_in_srgb_gamut(rgb):
        chroma = max(chroma - 0.001, 0.0)
        rgb = _oklch_to_linear_srgb(lightness, chroma, hue)
    return "#" + "".join(f"{round(_gamma_encode(channel) * 255):02x}" for channel in rgb)


def _linearize(value: int) -> float:
    """0~255 sRGB 채널 값을 선형 값으로 바꿉니다."""
    channel = value / 255
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def hex_to_oklab(hex_color: str) -> tuple[float, float, float]:
    """#rrggbb를 OKLab(L, a, b)으로 바꿉니다."""
    if not isinstance(hex_color, str) or not HEX_PATTERN.fullmatch(hex_color):
        raise ValueError(f"#rrggbb 형식이 아닌 색입니다: {hex_color!r}")

    red, green, blue = (_linearize(int(hex_color[index:index + 2], 16)) for index in (1, 3, 5))
    l_ = (0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue) ** (1 / 3)
    m_ = (0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue) ** (1 / 3)
    s_ = (0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue) ** (1 / 3)
    return (
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    )


def oklab_distance(first_hex: str, second_hex: str) -> float:
    return math.dist(hex_to_oklab(first_hex), hex_to_oklab(second_hex))


def oklch_lightness_chroma(hex_color: str) -> tuple[float, float]:
    lightness, a, b = hex_to_oklab(hex_color)
    return lightness, math.hypot(a, b)


def _relative_luminance(hex_color: str) -> float:
    if not isinstance(hex_color, str) or not HEX_PATTERN.fullmatch(hex_color):
        raise ValueError(f"#rrggbb 형식이 아닌 색입니다: {hex_color!r}")

    red, green, blue = (int(hex_color[index:index + 2], 16) for index in (1, 3, 5))
    return 0.2126 * _linearize(red) + 0.7152 * _linearize(green) + 0.0722 * _linearize(blue)


def _unrounded_contrast(foreground: str, background: str) -> float:
    lighter, darker = sorted(
        (_relative_luminance(foreground), _relative_luminance(background)), reverse=True
    )
    return (lighter + 0.05) / (darker + 0.05)


def composite(foreground_hex: str, alpha: float, background_hex: str) -> str:
    """반투명 글자·도장을 바탕 위에 겹친 색. 화면 합성처럼 sRGB 감마 값에서 섞습니다."""
    channels = []
    for index in (1, 3, 5):
        top = int(foreground_hex[index:index + 2], 16)
        bottom = int(background_hex[index:index + 2], 16)
        channels.append(round(top * alpha + bottom * (1 - alpha)))
    return "#" + "".join(f"{channel:02x}" for channel in channels)


def contrast_ratio(foreground: str, background: str) -> float:
    """WCAG 2 대비 비율을 소수 둘째 자리로 반올림해 돌려줍니다(표시용)."""
    return round(_unrounded_contrast(foreground, background), 2)


def brand_scale(hue: float, peak_chroma: float, steps: tuple[int, ...]) -> dict[int, str]:
    """명도 0.6 근처에서 채도가 가장 높고 양 끝으로 갈수록 줄어드는 단계를 만듭니다."""
    scale = {}
    for step in steps:
        lightness = LIGHTNESS_BY_STEP[step]
        weight = max(1 - abs(lightness - 0.6) / 0.45, 0.12)
        scale[step] = oklch_to_hex(lightness, peak_chroma * weight, hue)
    return scale


def _ohaeng_palette() -> dict[str, dict[str, str]]:
    """오행마다 견본, 바탕(tint), 글자(ink)와 다크 짝. 금과 수는 테두리(border, border_dark)도 둡니다."""
    palette = {}
    for element, (hue, swatch_lightness, swatch_chroma) in OHAENG_SWATCHES.items():
        colors = {"swatch": oklch_to_hex(swatch_lightness, swatch_chroma, hue)}
        fixed = OHAENG_FIXED.get(element)
        for part, (lightness, chroma) in OHAENG_TEXT_LEVELS.items():
            if fixed:
                lightness, chroma = fixed[part]
            colors[part] = oklch_to_hex(lightness, chroma, hue)
        if fixed:
            for part, cell in (("border", "tint"), ("border_dark", "tint_dark")):
                colors[part] = oklch_to_hex(*fixed[part], hue) if fixed[part] else colors[cell]
        palette[element] = colors
    return palette


def ohaeng_glyph_part(colors: dict[str, str], mode: str, sheet: str) -> str:
    """hanja-tag ganji 흰 원(bg.sheet) 안 한자색이 가리킬 부위: 이름 글자색이 bg.sheet에서 읽히면 글자색,
    아니면 알약 바탕색(결정 V78 용신의 날과 같은 규칙, V98). 돌려주는 값은 "fg" 또는 "bg"."""
    ink = "ink" if mode == "light" else "ink_dark"
    return "fg" if _unrounded_contrast(colors[ink], sheet) >= MIN_TEXT_CONTRAST else "bg"


def _roles(brand: dict[str, dict[int, str]]) -> dict[str, dict[str, str]]:
    sage, coral, neutral = brand["sage"], brand["coral"], brand["neutral"]
    roles = {
        "light": {
            "bg.base": neutral[50],
            "bg.sheet": WHITE,
            "text.primary": neutral[900],
            "text.secondary": neutral[700],
            "line": neutral[200],
            "action.primary": sage[700],
            "action.on-primary": WHITE,
            "term.bg": sage[100],
            "term.fg": sage[700],
            "invite.fg": sage[600],
            "badge.good.bg": coral[600],
            "badge.good.fg": WHITE,
            "badge.gwiin.bg": coral[100],
            "badge.gwiin.fg": coral[700],
            "badge.gisin.bg": neutral[100],
            "badge.gisin.fg": neutral[700],
            "badge.ordinary.border": neutral[300],
            "badge.ordinary.fg": neutral[700],
            "calendar.good.bg": coral[100],
            "calendar.caution.bg": neutral[100],
            "fill.soft": neutral[FILL_SOFT_STEP["light"]],
            "highlight.bg": neutral[HIGHLIGHT_STEP["light"]],
            "inverse.bg": neutral[900],
            "inverse.fg": neutral[100],
            "disabled.bg": neutral[100],
            "disabled.fg": neutral[600],
            "seal.knock": sage[50],
            "seal.on-soft": sage[800],
            "tag.good.bg": coral[100],
            "tag.good.fg": coral[700],
            "tag.bad.bg": neutral[100],
            "tag.bad.fg": neutral[700],
            "tag.neutral.border": neutral[300],
            "tag.neutral.fg": neutral[700],
            "timeline.entry": neutral[300],
        },
        "dark": {
            "bg.base": neutral[950],
            "bg.sheet": neutral[900],
            "text.primary": neutral[100],
            "text.secondary": neutral[400],
            "line": neutral[800],
            "action.primary": sage[300],
            "action.on-primary": neutral[950],
            "term.bg": sage[800],
            "term.fg": sage[200],
            "invite.fg": sage[400],
            "badge.good.bg": coral[300],
            "badge.good.fg": neutral[900],
            "badge.gwiin.bg": coral[800],
            "badge.gwiin.fg": coral[200],
            "badge.gisin.bg": neutral[800],
            "badge.gisin.fg": neutral[200],
            "badge.ordinary.border": neutral[700],
            "badge.ordinary.fg": neutral[400],
            "calendar.good.bg": coral[900],
            "calendar.caution.bg": neutral[900],
            "fill.soft": neutral[FILL_SOFT_STEP["dark"]],
            "highlight.bg": neutral[HIGHLIGHT_STEP["dark"]],
            "inverse.bg": neutral[100],
            "inverse.fg": neutral[900],
            "disabled.bg": neutral[800],
            "disabled.fg": neutral[500],
            "seal.knock": neutral[900],
            "seal.on-soft": sage[200],
            "tag.good.bg": coral[800],
            "tag.good.fg": coral[200],
            "tag.bad.bg": neutral[800],
            "tag.bad.fg": neutral[200],
            "tag.neutral.border": neutral[700],
            "tag.neutral.fg": neutral[400],
            "timeline.entry": neutral[700],
        },
    }
    for mode, levels in CALENDAR_LEVELS.items():
        for level, oklch in levels.items():
            roles[mode][f"calendar.level.{level}"] = oklch_to_hex(*oklch)
    return roles


def build_palette() -> dict:
    """원시 팔레트, 오행 팔레트, 그라데이션, 의미 역할을 모두 만듭니다."""
    brand = {
        name: brand_scale(hue, peak_chroma, steps)
        for name, (hue, peak_chroma, steps) in BRAND_SCALES.items()
    }
    return {
        "brand": brand,
        "ohaeng": _ohaeng_palette(),
        "gradient": {
            "light": list(GRADIENT_LIGHT),
            "dark": [oklch_to_hex(*stop) for stop in GRADIENT_DARK_OKLCH],
        },
        "roles": _roles(brand),
        "unlocked": {
            mode: [brand[stop[0]][stop[1]] if isinstance(stop[0], str) else oklch_to_hex(*stop) for stop in stops]
            for mode, stops in UNLOCKED_GRADIENT.items()
        },
    }


def _text_pairs(palette: dict) -> list[tuple[str, str, str]]:
    """검사할 (이름, 글자색, 바탕색) 목록. 이름은 "<mode> <조합>"입니다."""
    pairs = []
    for mode, roles in palette["roles"].items():
        for text_role in ("text.primary", "text.secondary"):
            for background_role in ("bg.base", "bg.sheet"):
                pairs.append((f"{mode} {text_role} on {background_role}", roles[text_role], roles[background_role]))
            for index, stop in enumerate(palette["gradient"][mode]):
                pairs.append((f"{mode} {text_role} on gradient[{index}]", roles[text_role], stop))
        pairs.append((f"{mode} action.primary", roles["action.on-primary"], roles["action.primary"]))
        pairs.append((f"{mode} term", roles["term.fg"], roles["term.bg"]))
        # 권유 글자(일기 쓰기 질문 뗀 자리 "무엇을 쓸지 고민인가요?", V102)는 종이(bg.sheet) 위에만 놓임
        pairs.append((f"{mode} invite.fg on bg.sheet", roles["invite.fg"], roles["bg.sheet"]))
        # 열린 근거 그라데이션(V111)은 구역 제목 글자와 반짝임 띠라 멈춤 색마다 두 바탕에서 글자 대비
        for index, stop in enumerate(palette["unlocked"][mode]):
            for background_role in ("bg.base", "bg.sheet"):
                pairs.append((f"{mode} unlocked[{index}] on {background_role}", stop, roles[background_role]))
        pairs.append((f"{mode} badge.good", roles["badge.good.fg"], roles["badge.good.bg"]))
        pairs.append((f"{mode} badge.gwiin", roles["badge.gwiin.fg"], roles["badge.gwiin.bg"]))
        pairs.append((f"{mode} badge.gisin", roles["badge.gisin.fg"], roles["badge.gisin.bg"]))
        # 평범한 날 배지는 바탕이 없어, 놓일 수 있는 모든 바탕에서 검사합니다 (V1 spec §3.1)
        ordinary_backgrounds = [("bg.base", roles["bg.base"]), ("bg.sheet", roles["bg.sheet"])]
        ordinary_backgrounds += [(f"gradient[{index}]", stop) for index, stop in enumerate(palette["gradient"][mode])]
        for background_name, background in ordinary_backgrounds:
            pairs.append((f"{mode} badge.ordinary.fg on {background_name}", roles["badge.ordinary.fg"], background))
        for text_role in ("text.primary", "text.secondary"):
            for cell_role in ("calendar.good.bg", "calendar.caution.bg"):
                pairs.append((f"{mode} {text_role} on {cell_role}", roles[text_role], roles[cell_role]))
        for level in CALENDAR_LEVELS[mode]:
            pairs.append((f"{mode} text.primary on calendar.level.{level}", roles["text.primary"],
                          roles[f"calendar.level.{level}"]))
        ink, tint = ("ink", "tint") if mode == "light" else ("ink_dark", "tint_dark")
        for element, colors in palette["ohaeng"].items():
            pairs.append((f"{mode} ohaeng.{element}", colors[ink], colors[tint]))
            # hanja-tag ganji 흰 원 안 한자 (V98)
            glyph = colors[ink] if ohaeng_glyph_part(colors, mode, roles["bg.sheet"]) == "fg" else colors[tint]
            pairs.append((f"{mode} ohaeng.{element}.glyph on bg.sheet", glyph, roles["bg.sheet"]))
        pairs += _v2_pairs(palette, mode, roles, ink)
    return pairs


def _v2_pairs(palette: dict, mode: str, roles: dict[str, str], ink: str) -> list[tuple[str, str, str]]:
    """V2 역할 조합 (V2 spec §5.3)."""
    pairs = [
        (f"{mode} tag.good", roles["tag.good.fg"], roles["tag.good.bg"]),
        (f"{mode} tag.bad", roles["tag.bad.fg"], roles["tag.bad.bg"]),
        (f"{mode} tag.neutral.fg on bg.sheet", roles["tag.neutral.fg"], roles["bg.sheet"]),
        (f"{mode} tag.neutral.fg on bg.base", roles["tag.neutral.fg"], roles["bg.base"]),
        (f"{mode} inverse", roles["inverse.fg"], roles["inverse.bg"]),
        (f"{mode} disabled", roles["disabled.fg"], roles["disabled.bg"]),
        (f"{mode} status", roles["term.fg"], roles["term.bg"]),
        # 강조 칸 위 글자(나이, 연도 action.primary 굵게, 칸 글자 text.primary) (V93)
        (f"{mode} action.primary on highlight.bg", roles["action.primary"], roles["highlight.bg"]),
        (f"{mode} text.primary on highlight.bg", roles["text.primary"], roles["highlight.bg"]),
        (f"{mode} seal.knock on seal.fill", roles["seal.knock"], roles["action.primary"]),
        (f"{mode} calendar.weekday.sun on bg.base", palette["ohaeng"]["fire"][ink], roles["bg.base"]),
        (f"{mode} calendar.weekday.sat on bg.base", palette["ohaeng"]["earth"][ink], roles["bg.base"]),
    ]
    scale, step, alpha = SEAL_SOFT[mode]
    seal = palette["brand"][scale][step]
    for cell_role in ("bg.base", "calendar.good.bg", "calendar.caution.bg"):
        stamped = composite(seal, alpha, roles[cell_role])
        pairs.append((f"{mode} text.primary on seal.soft over {cell_role}", roles["text.primary"], stamped))
    # 옅은 도장 위의 sage 글자(선택된 날 숫자, 질문 카드 버튼 글자)는 action.primary 대신 seal.on-soft
    for cell_role in ("bg.base", "bg.sheet", "calendar.good.bg", "calendar.caution.bg"):
        stamped = composite(seal, alpha, roles[cell_role])
        pairs.append((f"{mode} seal.on-soft on seal.soft over {cell_role}", roles["seal.on-soft"], stamped))
    return pairs


def check_contrast(palette: dict) -> list[ContrastResult]:
    """모든 글자 조합의 대비를 계산해 기준(4.5:1) 통과 여부와 함께 돌려줍니다.

    비교는 반올림하지 않은 값으로 합니다. 4.496이 4.50으로 반올림되어 통과하지 않게 하려는 것입니다.
    """
    results = []
    for name, foreground, background in _text_pairs(palette):
        ratio = _unrounded_contrast(foreground, background)
        minimum = MIN_DISABLED_CONTRAST if name.endswith(" disabled") else MIN_TEXT_CONTRAST
        results.append(ContrastResult(name, foreground, background, ratio, ratio >= minimum))
    return results


def main(argv: list[str]) -> int:
    palette = build_palette()
    if "--check" not in argv:
        print(json.dumps(palette, indent=2, sort_keys=True))
        return 0

    results = check_contrast(palette)
    for result in results:
        mark = "ok  " if result.passed else "FAIL"
        print(f"{mark} {result.ratio:>5.2f}  {result.name}  ({result.foreground} on {result.background})")
    failures = [result for result in results if not result.passed]
    print(f"\n{len(results) - len(failures)}/{len(results)} 조합 통과 "
          f"(기준 {MIN_TEXT_CONTRAST}:1, 비활성 글자 {MIN_DISABLED_CONTRAST}:1)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
