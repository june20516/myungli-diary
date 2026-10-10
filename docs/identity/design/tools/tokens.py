"""palette.py 결과와 타이포·간격·반경 상수로 DTCG 토큰 파일 다섯 개를 만듭니다.

spec: docs/identity/design/specs/2026-10-11-design-tokens-design.md §4~§7
토큰 파일은 손으로 고치지 않고, 이 파일이나 palette.py를 고친 뒤 다시 만듭니다.

사용법 (저장소 루트에서):
    python3 docs/identity/design/tools/tokens.py
"""
from __future__ import annotations

import json
import pathlib

from palette import WHITE, build_palette

DESIGN_DIR = pathlib.Path(__file__).resolve().parent.parent
TOKENS_DIR = DESIGN_DIR / "tokens"
EXTENSION_KEY = "io.github.june20516.myungli-diary"  # DTCG 권장대로 역도메인 표기
GRADIENT_ANGLE = 160

SPACES = (2, 4, 8, 12, 16, 20, 24, 32, 48)
RADII = {"xs": 4, "sm": 8, "md": 12, "lg": 20, "xl": 28, "full": 9999}

# 모드별 알파 색 (spec §3.3): (원시 팔레트 이름 또는 white, 단계, 알파)
CHIP_ALPHA = {"light": 0.70, "dark": 0.08}
SWATCH_BORDER = {"light": (900, 0.18), "dark": (100, 0.28)}

ROLE_DESCRIPTIONS = {
    "bg.base": "기본 바탕",
    "bg.sheet": "시트·패널 바탕",
    "text.primary": "본문 글자",
    "text.secondary": "보조 글자",
    "line": "선",
    "action.primary": "주 버튼 바탕",
    "action.on-primary": "주 버튼 글자",
    "term.bg": "용어 토큰 바탕 (굵게 하지 않음)",
    "term.fg": "용어 토큰 글자",
    "badge.good.bg": "좋은 날(YONGSIN_DAY) 배지 바탕",
    "badge.good.fg": "좋은 날 배지 글자",
    "badge.gwiin.bg": "귀인의 날(GWIIN_DAY) 배지 바탕",
    "badge.gwiin.fg": "귀인의 날 배지 글자",
    "badge.gisin.bg": "기신의 날(GISIN_DAY) 배지 바탕",
    "badge.gisin.fg": "기신의 날 배지 글자",
    "badge.ordinary.border": "평범한 날(ORDINARY_DAY) 배지 테두리. 바탕은 없음",
    "badge.ordinary.fg": "평범한 날 배지 글자",
    "calendar.good.bg": "캘린더 LuckLevel GOOD 날짜 칸 채우기. NEUTRAL은 채우지 않음",
    "calendar.caution.bg": "캘린더 LuckLevel CAUTION 날짜 칸 채우기",
}

FONT_FAMILIES = {
    "ko": {
        "sentence": ["Gowun Dodum", "Pretendard", "sans-serif"],
        "ui": ["Pretendard", "sans-serif"],
        "hanja": ["Pretendard JP", "sans-serif"],
    },
    "ja": {
        "sentence": ["Zen Maru Gothic", "Pretendard JP", "sans-serif"],
        "ui": ["Pretendard JP", "sans-serif"],
        "hanja": ["Pretendard JP", "sans-serif"],
    },
}

# 이름: (글꼴 묶음, 크기, 굵기, 줄 간격 ko·en, 줄 간격 ja, 설명) (spec §4.2)
TYPE_STYLES = {
    "sentence.card": ("sentence", 17, 400, 1.65, 1.75, "카드 문장"),
    "sentence.body": ("sentence", 15, 400, 1.6, 1.7, "일반 본문 (일기, 풀이)"),
    "display": ("ui", 24, 600, 1.25, 1.25, "큰 제목"),
    "title": ("ui", 20, 600, 1.3, 1.3, "화면 제목"),
    "subtitle": ("ui", 16, 600, 1.4, 1.4, "소제목"),
    "label.lg": ("ui", 14, 600, 1.3, 1.3, "버튼·탭"),
    "label.md": ("ui", 13, 500, 1.3, 1.3, "칩·배지"),
    "caption.md": ("ui", 12, 500, 1.3, 1.3, "캡션·날짜"),
    "caption.sm": ("ui", 11, 500, 1.3, 1.3, "원국표 칸 아래 표기"),
    "numeric.calendar": ("ui", 14, 500, 1.2, 1.2, "캘린더 날짜 (고정폭 숫자)"),
    "numeric.table": ("ui", 13, 500, 1.3, 1.3, "대운·세운 표의 나이·연도 (고정폭 숫자)"),
    "hanja.pillar": ("hanja", 17, 700, 1.0, 1.0, "원국표 한자"),
}
KO_UI_LETTER_SPACING = -0.02  # 글자 크기의 -2%, px로 환산 (spec §4.2)


def color_value(hex_color: str, alpha: float | None = None) -> dict:
    """DTCG srgb 색 값. components는 hex 채널/255를 소수 넷째 자리에서 반올림합니다."""
    value = {
        "colorSpace": "srgb",
        "components": [round(int(hex_color[index:index + 2], 16) / 255, 4) for index in (1, 3, 5)],
        "hex": hex_color,
    }
    if alpha is not None:
        value["alpha"] = alpha
    return value


def _name_order(name: str) -> list[tuple[int, int | str]]:
    """이름을 점으로 나눠, 숫자 부분은 숫자로 비교합니다(neutral.50이 neutral.100보다 앞)."""
    return [(0, int(part)) if part.isdigit() else (1, part) for part in name.split(".")]


def reference_or_value(hex_color: str, primitives: dict[str, str]) -> str | dict:
    """같은 hex의 원시 토큰이 있으면 참조(여럿이면 이름순 첫 번째, 단계는 숫자 순), 없으면 색 값."""
    matches = sorted((name for name, primitive_hex in primitives.items() if primitive_hex == hex_color),
                     key=_name_order)
    if matches:
        return "{" + matches[0] + "}"
    return color_value(hex_color)


def serialize(document: dict) -> str:
    return json.dumps(document, indent=2, ensure_ascii=False) + "\n"


def _token(token_type: str, value: object, description: str | None = None, extensions: dict | None = None) -> dict:
    token = {"$type": token_type, "$value": value}
    if description:
        token["$description"] = description
    if extensions:
        token["$extensions"] = {EXTENSION_KEY: extensions}
    return token


def _place(document: dict, dotted_name: str, token: dict) -> None:
    *groups, leaf = dotted_name.split(".")
    node = document
    for group in groups:
        node = node.setdefault(group, {})
    node[leaf] = token


def _px(value: float) -> dict:
    return {"value": value, "unit": "px"}


def _primitive_hexes(palette: dict) -> dict[str, str]:
    hexes = {
        f"color.{scale}.{step}": hex_color
        for scale, steps in palette["brand"].items()
        for step, hex_color in steps.items()
    }
    hexes["color.white"] = WHITE
    return hexes


def _primitive_document(palette: dict) -> dict:
    document: dict = {}
    for name, hex_color in _primitive_hexes(palette).items():
        _place(document, name, _token("color", color_value(hex_color)))
    for element, colors in palette["ohaeng"].items():
        _place(document, f"color.ohaeng.{element}.swatch", _token(
            "color", color_value(colors["swatch"]),
            "오행 견본: 색 자체를 보여주는 자리. 모드와 관계없이 같은 값이고 항상 swatch.border를 둡니다"))
    for value in SPACES:
        _place(document, f"space.{value}", _token("dimension", _px(value)))
    for name, value in RADII.items():
        _place(document, f"radius.{name}", _token("dimension", _px(value)))
    return document


def _color_document(palette: dict, mode: str) -> dict:
    primitives = _primitive_hexes(palette)
    brand = palette["brand"]
    document: dict = {}
    for role, hex_color in palette["roles"][mode].items():
        _place(document, f"color.{role}", _token("color", reference_or_value(hex_color, primitives),
                                                 ROLE_DESCRIPTIONS[role]))
    _place(document, "color.chip.bg", _token("color", color_value(WHITE, CHIP_ALPHA[mode]), "칩 바탕 (반투명 흰색)"))
    border_step, border_alpha = SWATCH_BORDER[mode]
    _place(document, "color.swatch.border", _token(
        "color", color_value(brand["neutral"][border_step], border_alpha), "오행 견본 테두리"))
    background, foreground = ("tint", "ink") if mode == "light" else ("tint_dark", "ink_dark")
    for element, colors in palette["ohaeng"].items():
        _place(document, f"color.ohaeng.{element}.bg", _token(
            "color", color_value(colors[background]), "원국표 칸처럼 글자가 얹히는 오행 바탕"))
        _place(document, f"color.ohaeng.{element}.fg", _token("color", color_value(colors[foreground]), "오행 글자"))
    stops = palette["gradient"][mode]
    _place(document, "gradient.today", _token(
        "gradient",
        [{"color": color_value(stop), "position": index / (len(stops) - 1)} for index, stop in enumerate(stops)],
        "데일리 카드·온보딩·공유 이미지에만 씁니다. 단색으로 바뀌어도 깨지지 않게 씁니다",
        {"angle": GRADIENT_ANGLE}))
    return document


def _typography_document(language: str) -> dict:
    document: dict = {}
    for family, fonts in FONT_FAMILIES[language].items():
        _place(document, f"font.family.{family}", _token("fontFamily", fonts))
    for name, (family, size, weight, line_height_ko, line_height_ja, description) in TYPE_STYLES.items():
        tracks = language == "ko" and family == "ui" and not name.startswith("numeric.")
        letter_spacing = round(size * KO_UI_LETTER_SPACING, 2) if tracks else 0
        value = {
            "fontFamily": "{font.family." + family + "}",
            "fontSize": _px(size),
            "fontWeight": weight,
            "letterSpacing": _px(letter_spacing),
            "lineHeight": line_height_ko if language == "ko" else line_height_ja,
        }
        extensions = {"fontFeatures": ["tnum"]} if name.startswith("numeric.") else None
        _place(document, f"type.{name}", _token("typography", value, description, extensions))
    return document


def build_token_files() -> dict[str, dict]:
    """파일 이름 → DTCG 문서."""
    palette = build_palette()
    return {
        "primitive.tokens.json": _primitive_document(palette),
        "color.light.tokens.json": _color_document(palette, "light"),
        "color.dark.tokens.json": _color_document(palette, "dark"),
        "typography.tokens.json": _typography_document("ko"),
        "typography.ja.tokens.json": _typography_document("ja"),
    }


def main() -> None:
    TOKENS_DIR.mkdir(exist_ok=True)
    for name, document in build_token_files().items():
        path = TOKENS_DIR / name
        path.write_text(serialize(document), encoding="utf-8")
        print(path)


if __name__ == "__main__":
    main()
