"""슬롯별 글자 수 상한을 레이아웃 폭과 실제 글꼴 폭으로 계산합니다 (writing #54).

spec: docs/identity/design/specs/2026-10-11-depth-lock-lengths-design.md §5

사용법 (저장소 루트에서):
    uv run --with fonttools==4.54.1 python docs/identity/design/tools/lengths.py --font-dir .suberpowers/fonts
    # 표를 Markdown으로 출력합니다. lengths.md의 표와 같아야 합니다(test_lengths.py).

계산 방법:
* 기준 화면 폭 360px, 화면 좌우 여백 space.20 → 본문 폭 320px. 칸 폭은 각 컴포넌트 명세의 안쪽 여백을 뺀 값입니다.
* ko 문장 자리: writing 라운드 원고(R1~R7)의 문장을 이어 붙여 어절 단위(keep-all)로 줄을 채우고,
  꽉 찬 줄 글자 수의 하위 10%를 한 줄 글자 수로 봅니다. 상한 = 한 줄 글자 수 × 줄 수.
* ko 이름 자리(한 줄): 띄어쓰기 없는 한글로 칸 폭을 채운 글자 수입니다.
* ja: 글자 단위 줄바꿈 + 금칙 처리. 줄마다 한 글자를 금칙 여유로 뺍니다.
  문장 글꼴은 Zen Maru Gothic의 가나·한자 평균 폭, UI 글꼴은 전각 1em으로 봅니다.
* en: 글꼴의 라틴 소문자 폭을 영어 글자 빈도로 가중 평균하고, 줄마다 평균 단어(4.7자 + 띄어쓰기)의 절반을 줄바꿈 손실로 뺍니다.
"""
from __future__ import annotations

import argparse
import math
import pathlib
import re
import sys
from dataclasses import dataclass, replace

DESIGN_DIR = pathlib.Path(__file__).resolve().parent.parent
ROUNDS_DIR = DESIGN_DIR.parent / "writing" / "artifacts"

SCREEN_WIDTH = 360
SCREEN_GUTTER = 20
CONTENT_WIDTH = SCREEN_WIDTH - 2 * SCREEN_GUTTER

KO_LINE_PERCENTILE = 0.10
EN_AVERAGE_WORD_LETTERS = 4.7

# 글꼴 묶음 → (ko·en 파일, ja 파일). ja UI 글꼴(Pretendard JP)은 전각 1em으로 계산하므로 파일이 없습니다.
FONT_FILES = {
    "sentence": ("GowunDodum-Regular.ttf", "ZenMaruGothic-Regular.ttf"),
    "ui-400": ("Pretendard-Regular.otf", None),
    "ui-500": ("Pretendard-Medium.otf", None),
    "ui-600": ("Pretendard-SemiBold.otf", None),
    "ui-700": ("Pretendard-Bold.otf", None),
}

# 영어 글자 빈도(%), 띄어쓰기는 단어 손실 계산에서 따로 봅니다.
ENGLISH_LETTER_FREQUENCY = {
    "e": 12.7, "t": 9.1, "a": 8.2, "o": 7.5, "i": 7.0, "n": 6.7, "s": 6.3, "h": 6.1, "r": 6.0,
    "d": 4.3, "l": 4.0, "c": 2.8, "u": 2.8, "m": 2.4, "w": 2.4, "f": 2.2, "g": 2.0, "y": 2.0,
    "p": 1.9, "b": 1.5, "v": 1.0, "k": 0.8, "j": 0.15, "x": 0.15, "q": 0.1, "z": 0.07,
}


@dataclass(frozen=True)
class Target:
    """슬롯이 놓이는 칸 하나."""
    slots: tuple[str, ...]
    where: str
    font: str
    size: float
    tracking: float
    width: float
    lines: int
    sentence: bool
    draft: int | None
    reserve_chars: int = 0  # 같은 줄 오른쪽 값 자리(같은 글자 스타일의 한글 글자 수)만큼 폭을 뺌


TARGETS = (
    Target(("daily.fortune.head", "daily.fortune.tag"), "today sentence-block card", "sentence", 17, 0, CONTENT_WIDTH, 2, True, 32),
    Target(("daily.guide",), "guide-question-card question (안쪽 space.20)", "sentence", 17, 0, CONTENT_WIDTH - 40, 2, True, 40),
    Target(("daily.color", "daily.direction", "daily.number", "daily.focus_time"), "lucky-card explain (안쪽 space.12)",
           "ui-400", 13, -0.26, CONTENT_WIDTH - 24, 2, True, 36),
    Target(("daily.focus_reason",), "lucky-card explain 안 한 줄", "ui-400", 13, -0.26, CONTENT_WIDTH - 24, 1, False, 10),
    Target(("daily.tag_label",), "tag-chip (# 포함, 좌우 10px)", "ui-500", 12, -0.24, CONTENT_WIDTH - 20 - 8, 1, False, 10),
    Target(("calendar.day_level",), "day-character badge (좌우 10px)", "ui-500", 13, -0.26, CONTENT_WIDTH - 20, 1, False, 10),
    Target(("calendar.score_item",), "term-token label (좌우 4px)", "ui-500", 12, -0.24, CONTENT_WIDTH - 8, 1, False, 10),
    Target(("calendar.solar_term",), "day-cell lunar 줄 (칸 폭 44px, 굵게)", "ui-700", 10.5, -0.22, (CONTENT_WIDTH - 2 * 6) / 7, 1, False, 10),
    Target(("glossary.value_name",), "lucky-card chip 값 (좌우 12px, 아이콘 16 + 간격 6)", "ui-500", 13, -0.26, CONTENT_WIDTH - 24 - 16 - 6, 1, False, 10),
    Target(("ui.depth.surface", "ui.depth.explain", "ui.depth.evidence"), "segmented 세 칸 중 한 칸",
           "ui-600", 14, -0.28, (CONTENT_WIDTH - 2 * 1 - 2 * 3) / 3, 1, False, 10),
    Target(("ui.depth.default_label",), "settings-row value 이름 (좌우 16px, 화살표 16, 오른쪽 값 = 단계 이름 8자)",
           "ui-400", 14, -0.28, CONTENT_WIDTH - 2 * 16 - 16, 1, False, 10, reserve_chars=8),
)

# 레이아웃이 줄 수를 막지 않는 자리(스크롤 본문). writing 초안을 그대로 둡니다.
UNBOUNDED = {
    "chart.yongsin_method": ("saju-chart 본문 sentence-block body", 60),
    "settings.calculation_basis": ("calc-basis 본문 sentence-block body", 120),
}


def load_advances(path: pathlib.Path) -> tuple[dict[int, float], float]:
    """코드 포인트 → 1em 대비 폭."""
    from fontTools.ttLib import TTFont

    font = TTFont(str(path), lazy=True)
    units = font["head"].unitsPerEm
    metrics = font["hmtx"].metrics
    advances = {code: metrics[glyph][0] / units for code, glyph in font.getBestCmap().items()}
    return advances, units


class Fonts:
    def __init__(self, font_dir: pathlib.Path):
        self._dir = font_dir
        self._cache: dict[str, dict[int, float]] = {}

    def advances(self, file_name: str) -> dict[int, float]:
        if file_name not in self._cache:
            self._cache[file_name] = load_advances(self._dir / file_name)[0]
        return self._cache[file_name]

    def ko(self, family: str) -> dict[int, float]:
        return self.advances(FONT_FILES[family][0])

    def ja(self, family: str) -> dict[int, float] | None:
        file_name = FONT_FILES[family][1]
        return self.advances(file_name) if file_name else None


def corpus_sentences(rounds_dir: pathlib.Path = ROUNDS_DIR) -> list[str]:
    """라운드 기록 표의 선택지 문장(한글 문장만, "다 별로" 제외)."""
    sentences = []
    row = re.compile(r"^\|\s*\d+\s*\|\s*(.+?)\s*\|")
    for path in sorted(rounds_dir.glob("*-round-R*.md")):
        for line in path.read_text(encoding="utf-8").splitlines():
            match = row.match(line)
            if not match:
                continue
            text = match.group(1).replace("**", "").strip()
            if re.search(r"[가-힣]", text) and re.search(r"[.?!]$", text) and "다 별로" not in text:
                sentences.append(text)
    return sentences


def text_width(text: str, advances: dict[int, float], size: float, tracking: float) -> float:
    fallback = advances.get(ord("가"), 1.0)
    return sum(advances.get(ord(char), fallback) * size + tracking for char in text)


def ko_line_chars(words: list[str], advances: dict[int, float], size: float, tracking: float, width: float) -> int:
    """어절 단위로 줄을 채웠을 때 꽉 찬 줄 글자 수(띄어쓰기 포함)의 하위 백분위."""
    full_lines: list[int] = []
    line = ""
    for word in words:
        candidate = f"{line} {word}" if line else word
        if text_width(candidate, advances, size, tracking) <= width:
            line = candidate
            continue
        if line:
            full_lines.append(len(line))
        line = word
    if not full_lines:
        raise ValueError("말뭉치가 한 줄도 채우지 못했습니다")
    full_lines.sort()
    return full_lines[int(len(full_lines) * KO_LINE_PERCENTILE)]


def ko_name_chars(advances: dict[int, float], size: float, tracking: float, width: float) -> int:
    return int(width // (advances[ord("가")] * size + tracking))


def ja_line_chars(advances: dict[int, float] | None, size: float, width: float) -> int:
    """금칙 여유 한 글자를 뺀 한 줄 글자 수."""
    if advances is None:
        em = 1.0
    else:
        samples = "のはをにがでとしたていますよう日今気持合時間方色向数字運"
        em = sum(advances[ord(char)] for char in samples) / len(samples)
    return int(width // (em * size)) - 1


def en_line_chars(advances: dict[int, float], size: float, tracking: float, width: float) -> int:
    total = sum(ENGLISH_LETTER_FREQUENCY.values())
    letter = sum(advances[ord(char)] * weight for char, weight in ENGLISH_LETTER_FREQUENCY.items()) / total
    letters_per_word = EN_AVERAGE_WORD_LETTERS
    space = advances[ord(" ")]
    char_width = ((letter * letters_per_word + space) / (letters_per_word + 1)) * size + tracking
    wrap_loss = (letters_per_word + 1) / 2
    return int(width // char_width - wrap_loss)


@dataclass(frozen=True)
class Result:
    target: Target
    ko: int
    ja: int
    en: int

    def final(self, language: str) -> int:
        """writing 초안과 레이아웃 계산 중 작은 값. ja·en 초안은 ko 초안(ja 같음, en 1.8배)에서 옵니다."""
        computed = getattr(self, language)
        if self.target.draft is None:
            return computed
        draft = {"ko": self.target.draft, "ja": self.target.draft, "en": math.floor(self.target.draft * 1.8)}[language]
        return min(draft, computed)


def measure(fonts: Fonts, words: list[str]) -> list[Result]:
    results = []
    for target in TARGETS:
        ko_advances = fonts.ko(target.font)
        if target.reserve_chars:
            reserved = target.reserve_chars * (ko_advances[ord("가")] * target.size + target.tracking)
            target = replace(target, width=round(target.width - reserved, 1), reserve_chars=0)
        if target.sentence:
            ko = ko_line_chars(words, ko_advances, target.size, target.tracking, target.width) * target.lines
        else:
            ko = ko_name_chars(ko_advances, target.size, target.tracking, target.width) * target.lines
        ja = ja_line_chars(fonts.ja(target.font), target.size, target.width) * target.lines
        en = en_line_chars(ko_advances, target.size, target.tracking, target.width) * target.lines
        results.append(Result(target, ko, ja, en))
    return results


def render_table(results: list[Result]) -> str:
    lines = [
        "| 슬롯 | 놓이는 칸 | 칸 폭 | 줄 | ko 초안 | ko 계산 | **ko** | **ja** | **en** |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for result in results:
        target = result.target
        slots = "<br>".join(f"`{slot}`" for slot in target.slots)
        lines.append(
            f"| {slots} | {target.where} | {target.width:g}px | {target.lines} | {target.draft} | {result.ko} "
            f"| **{result.final('ko')}** | **{result.final('ja')}** | **{result.final('en')}** |"
        )
    for slot, (where, draft) in UNBOUNDED.items():
        lines.append(f"| `{slot}` | {where} | 본문 | 제한 없음 | {draft} | - "
                     f"| **{draft}** | **{draft}** | **{math.floor(draft * 1.8)}** |")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--font-dir", type=pathlib.Path, required=True)
    args = parser.parse_args(argv)
    words = " ".join(corpus_sentences()).split()
    sys.stdout.write(render_table(measure(Fonts(args.font_dir), words)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
