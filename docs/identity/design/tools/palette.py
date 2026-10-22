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

# 오행: (hue, 견본 명도, 견본 채도) (spec §3.3)
OHAENG_SWATCHES = {
    "wood": (145, 0.58, 0.13),
    "fire": (27, 0.60, 0.17),
    "earth": (78, 0.76, 0.13),
    "metal": (250, 0.80, 0.02),
    "water": (258, 0.37, 0.11),
}
# 옅은 바탕·글자의 (명도, 채도). 금은 채도를 낮춰 수와 구분합니다.
OHAENG_TEXT_LEVELS = {
    "tint": (0.94, 0.03),
    "ink": (0.42, 0.08),
    "tint_dark": (0.30, 0.04),
    "ink_dark": (0.88, 0.05),
}
METAL_TEXT_CHROMA = {"tint": 0.006, "ink": 0.02, "tint_dark": 0.01, "ink_dark": 0.01}

GRADIENT_LIGHT = ["#eef4ef", "#fbefee"]
GRADIENT_DARK_OKLCH = [(0.23, 0.022, 150), (0.23, 0.024, 20)]

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


def _relative_luminance(hex_color: str) -> float:
    if not isinstance(hex_color, str) or not HEX_PATTERN.fullmatch(hex_color):
        raise ValueError(f"#rrggbb 형식이 아닌 색입니다: {hex_color!r}")

    def linearize(value: int) -> float:
        channel = value / 255
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    red, green, blue = (int(hex_color[index:index + 2], 16) for index in (1, 3, 5))
    return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)


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
    palette = {}
    for element, (hue, swatch_lightness, swatch_chroma) in OHAENG_SWATCHES.items():
        colors = {"swatch": oklch_to_hex(swatch_lightness, swatch_chroma, hue)}
        for part, (lightness, chroma) in OHAENG_TEXT_LEVELS.items():
            if element == "metal":
                chroma = METAL_TEXT_CHROMA[part]
            colors[part] = oklch_to_hex(lightness, chroma, hue)
        palette[element] = colors
    return palette


def _roles(brand: dict[str, dict[int, str]]) -> dict[str, dict[str, str]]:
    sage, coral, neutral = brand["sage"], brand["coral"], brand["neutral"]
    return {
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
        ink, tint = ("ink", "tint") if mode == "light" else ("ink_dark", "tint_dark")
        for element, colors in palette["ohaeng"].items():
            pairs.append((f"{mode} ohaeng.{element}", colors[ink], colors[tint]))
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
