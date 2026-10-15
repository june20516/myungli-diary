"""슬롯별 글자 수 상한을 레이아웃 폭과 실제 글꼴 폭으로 계산합니다 (writing #54·#131).

spec: docs/identity/design/specs/2026-10-11-depth-lock-lengths-design.md §5,
      docs/identity/design/specs/2026-10-15-spec-followups-design.md §5

사용법 (저장소 루트에서):
    uv run --with fonttools==4.54.1 python docs/identity/design/tools/lengths.py --font-dir .suberpowers/fonts
    # 표를 Markdown으로 출력합니다. lengths.md의 표와 같아야 합니다(test_lengths.py).

계산 방법:
* 기준 화면 폭 360px, 화면 좌우 여백 space.20 → 본문 폭 320px. 칸 폭은 각 컴포넌트 명세의 안쪽 여백을 뺀 값입니다.
* 여러 자리에 쓰는 슬롯은 가장 좁은 자리의 칸으로 잽니다(예: ui.action.button은 dialog 버튼).
* ko 문장 자리: writing 라운드 원고(R1~R8, 중복 제거)의 문장을 이어 붙여 어절 단위(keep-all)로 줄을 채우고,
  꽉 찬 줄 글자 수의 하위 10%를 한 줄 글자 수로 봅니다. 상한 = 한 줄 글자 수 × 줄 수.
  경험값이라 어절이 길게 몰린 문장은 상한 안이어도 한 줄 더 쓸 수 있습니다(문장 칸은 자르지 않고 줄이 늚).
* ko 이름 자리(한 줄): 띄어쓰기 없는 한글로 칸 폭을 채운 글자 수입니다. 가장 넓은 경우라 상한 안이면 늘 들어갑니다.
* ja: 글자 단위 줄바꿈 + 금칙 처리. 줄마다 한 글자를 금칙 여유로 뺍니다. 자간은 0으로 봅니다.
  문장 글꼴은 Zen Maru Gothic의 가나·한자 평균 폭, UI 글꼴(Pretendard JP, 측정 파일 없음)은 전각 1em으로 봅니다.
  Pretendard 가나는 1em보다 좁으므로 이 값은 보수적입니다.
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
    prefix: str = ""  # 이름 앞에 늘 붙는 글자(예: 태그 칩의 '#'). 실제 폭만큼 칸에서 뺌
    reserve_slot: str | None = None  # 같은 줄 오른쪽 값 자리. 그 슬롯의 ko 확정 글자 수만큼 폭을 뺌
    reserve_px: float = 0.0  # 같은 줄에 붙는 고정 폭(예: 이유 줄 끝 링크). 그만큼 칸에서 뺌


# 한 슬롯에 제목·본문·버튼 키가 함께 있는 확인 창. 제목 키와 버튼 키에만 상한을 둡니다(본문은 창이 늘어남).
DIALOG_SLOTS = (
    "diary-view.delete.confirm", "event-edit.delete.confirm", "account-delete.delete.confirm",
    "settings.logout.confirm", "preview.share.login-notice", "profile-edit.recalc.confirm",
)

TARGETS = (
    Target(("daily.fortune.head", "daily.fortune.tag"), "today sentence-block card (상자 없이 본문 폭, 시안 design-v2-today)", "sentence", 17, 0, CONTENT_WIDTH, 2, True, 32),
    Target(("daily.guide",), "guide-question-card question (안쪽 space.20)", "sentence", 17, 0, CONTENT_WIDTH - 40, 2, True, 40),
    Target(("daily.color", "daily.direction", "daily.number", "daily.focus_time"), "lucky-card explain (안쪽 space.12)",
           "ui-400", 13, -0.26, CONTENT_WIDTH - 24, 2, True, 36),
    Target(("daily.focus_reason",), "lucky-card explain 안 한 줄", "ui-400", 13, -0.26, CONTENT_WIDTH - 24, 1, False, 10),
    Target(("daily.tag_label",), "tag-chip ('#' 뒤, 좌우 10px)", "ui-500", 12, -0.24, CONTENT_WIDTH - 20, 1, False, 10, prefix="#"),
    Target(("calendar.day_level",), "day-character badge (좌우 10px)", "ui-500", 13, -0.26, CONTENT_WIDTH - 20, 1, False, 10),
    Target(("calendar.score_item",), "term-token label (좌우 4px)", "ui-500", 12, -0.24, CONTENT_WIDTH - 8, 1, False, 10),
    Target(("calendar.solar_term",), "day-cell lunar 줄 (칸 폭 44px, 굵게)", "ui-700", 10.5, -0.22, (CONTENT_WIDTH - 2 * 6) / 7, 1, False, 10),
    Target(("glossary.value_name",), "lucky-card chip 값 (칩이 한 줄에 혼자일 때, 좌우 12px, 아이콘 16 + 간격 6)", "ui-500", 13, -0.26, CONTENT_WIDTH - 24 - 16 - 6, 1, False, 10),
    Target(("ui.depth.surface", "ui.depth.explain", "ui.depth.evidence"), "segmented 세 칸 중 한 칸",
           "ui-600", 14, -0.28, (CONTENT_WIDTH - 2 * 1 - 2 * 3) / 3, 1, False, 10),
    Target(("ui.depth.default_label",), "settings-row value 이름 (좌우 16px, 화살표 16, 오른쪽 값 = 단계 이름)",
           "ui-400", 14, -0.28, CONTENT_WIDTH - 2 * 16 - 16, 1, False, 10, reserve_slot="ui.depth.surface"),
    # ui 이름 자리와 새 content 슬롯 (#131, spec-followups spec §5.2). writing 초안이 없어 계산값이 확정값
    Target(("welcome.cta.start", "welcome.cta.signin", "preview.cta.save", "preview.cta.restart", "consent.cta.agree",
            "notify-ask.cta.allow", "notify-ask.cta.skip", "force-update.cta.store", "account-delete.cta.delete",
            "today.guide.cta", "evidence-sheet.lock.cta", "ad-free.restore.cta", "diary-list.pick-date.cta",
            "day-sheet.event.add", "day-sheet.diary.write-cta", "share-preview.cta.share"),
           "primary-button (좌우 space.20)", "ui-600", 14, -0.28, CONTENT_WIDTH - 2 * 20, 1, False, None),
    Target(DIALOG_SLOTS, "dialog title (확인 창 슬롯의 제목 키, 바깥 28·안쪽 24)",
           "ui-600", 16, -0.32, SCREEN_WIDTH - 2 * 28 - 2 * 24, 2, False, None),
    Target(("ui.action.button",) + DIALOG_SLOTS, "dialog 버튼 두 개 중 하나 (확인 창 슬롯은 버튼 키, 버튼 사이 8)",
           "ui-600", 14, -0.28, (SCREEN_WIDTH - 2 * 28 - 2 * 24 - 8) / 2, 1, False, None),
    Target(("ui.login.provider",), "social-login-button 글자 (좌우 16, 로고 20 + 간격 8)",
           "ui-600", 14, -0.28, CONTENT_WIDTH - 2 * 16 - 20 - 8, 1, False, None),
    Target(("ui.error.client", "ui.error.code", "ui.login.error", "ui.app.trace", "evidence-sheet.unlock.failed",
            "diary-edit.saved.tags"), "toast (좌우 16)", "ui-400", 14, -0.28, CONTENT_WIDTH - 2 * 16, 2, True, None),
    Target(("ui.nav.tab",), "tab-bar 탭 라벨 (화면 폭 4등분)", "ui-500", 11, -0.22, SCREEN_WIDTH / 4, 1, False, None),
    Target(("ui.birth.option",), "segmented 두 칸 중 한 칸 (check-row inline 글자 포함)",
           "ui-600", 14, -0.28, (CONTENT_WIDTH - 2 * 1 - 2 * 3) / 2, 1, False, None),
    Target(("share-preview.ratio.label",), "segmented 세 칸 중 한 칸",
           "ui-600", 14, -0.28, (CONTENT_WIDTH - 2 * 1 - 2 * 3) / 3, 1, False, None),
    Target(("consent.required.label",), "check-row card 동의 항목 (좌우 16, 상자 24 + 간격 12, 보기 40)",
           "ui-400", 14, -0.28, CONTENT_WIDTH - 2 * 16 - 24 - 12 - 40, 2, False, None),
    Target(("onboard-call.input.hint", "event-edit.title.hint", "event-edit.memo.hint"),
           "text-field 안내 (좌우 16, 지우기 20 + 간격 8)", "ui-400", 17, 0, CONTENT_WIDTH - 2 * 16 - 20 - 8, 1, False, None),
    Target(("birthplace.search.hint",), "city-search 검색칸 안내 (text-field에서 돋보기 20 + 간격 8)",
           "ui-400", 17, 0, CONTENT_WIDTH - 2 * 16 - 20 - 8 - 20 - 8, 1, False, None),
    Target(("diary-edit.body.placeholder",), "diary-editor 입력칸 안내 (좌우 16)",
           "sentence", 15, 0, CONTENT_WIDTH - 2 * 16, 2, True, None),
    Target(("ui.app.notice", "saju-chart.time-unknown.notice", "diary-edit.offline.notice"),
           "notice-banner (좌우 12, 아이콘 16 + 간격 8)", "ui-400", 13, -0.26, CONTENT_WIDTH - 2 * 12 - 16 - 8, 2, True, None),
    Target(("ui.picker.item",), "date-picker·time-picker 휠 칸 (본문 폭 3등분)",
           "ui-600", 16, -0.32, CONTENT_WIDTH / 3, 1, False, None),
    Target(("evidence-sheet.section.basis", "evidence-sheet.section.source", "evidence-sheet.section.personal"),
           "evidence-sheet 구역 제목", "ui-500", 13, -0.26, CONTENT_WIDTH, 1, False, None),
    Target(("birthplace.standard.link", "day-sheet.diary.open"), "depth-link 이름 (화살표 14 + 간격 2)",
           "ui-600", 14, -0.28, CONTENT_WIDTH - 14 - 2, 1, False, None),
    Target(("saju-chart.yongsin.open",), "sentence-block locked 열기 (흐린 줄과 같은 줄 오른쪽 절반, 화살표 14 + 간격 2)",
           "ui-600", 14, -0.28, CONTENT_WIDTH / 2 - 14 - 2, 1, False, None),
    Target(("ui.app.name",), "app-bar 제목 (좌우 16, 뒤로 44, 동작 44 × 2)",
           "ui-600", 16, -0.32, SCREEN_WIDTH - 2 * 16 - 44 - 2 * 44, 1, False, None),
    Target(("onboard-time.hour.confirm",), "time-picker 시진 확인 줄", "ui-400", 13, -0.26, CONTENT_WIDTH, 1, False, None),
    # 끝 링크 폭: Pretendard SemiBold 14px 자간 −0.28로 잰 U+00A0 + "근거 보기" 53.4px + 화살표 14 + 간격 2 = 69.4 → 70
    Target(("character.reason",), "day-character 이유 줄 (끝 depth-link inline-end 자리를 뺌)",
           "ui-400", 13, -0.26, CONTENT_WIDTH, 2, True, None, reserve_px=70),
    Target(("chart.ilgan_head",), "my-saju 일간 소개 첫 문장 sentence-block card (today 총운과 같은 칸)",
           "sentence", 17, 0, CONTENT_WIDTH, 2, True, None),
)

# 레이아웃이 줄 수를 막지 않는 자리(스크롤 본문). writing 초안을 그대로 둡니다.
UNBOUNDED = {
    "chart.yongsin_method": ("saju-chart 본문 sentence-block body", 60),
    "settings.calculation_basis": ("calc-basis 본문 sentence-block body", 120),
}

# 레이아웃이 길이를 막지 않아 design이 상한을 두지 않는 슬롯 (spec-followups spec §5.3)
SCREEN_READER_ONLY = "스크린리더 전용(화면에 보이지 않음)"
SCROLL_BODY = "스크롤 본문"
OUTSIDE_APP = "app 밖 화면(server 웹 페이지)"
NO_LIMIT = {
    "ui.nav.a11y": SCREEN_READER_ONLY,
    "ui.a11y.label": SCREEN_READER_ONLY,
    "ui.picker.label": SCREEN_READER_ONLY,
    "evidence-sheet.a11y.locked": SCREEN_READER_ONLY,
    "evidence-sheet.a11y.checking": SCREEN_READER_ONLY,
    "evidence-sheet.a11y.unlocked": SCREEN_READER_ONLY,
    "today.reaction.label": SCREEN_READER_ONLY,
    "chart.ilgan_body": SCROLL_BODY,
    "chart.yongsin_summary": SCROLL_BODY,
    "term.meaning": SCROLL_BODY + "(풀이 시트·태그 모아보기)",
    "ui.app.bootstrap": SCROLL_BODY + "(error-state 문장)",
    "system.apple_return": OUTSIDE_APP,
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
    """라운드 기록 표의 선택지 문장(한글 문장만, "다 별로" 제외, 처음 나온 순서로 중복 제거)."""
    sentences: list[str] = []
    row = re.compile(r"^\|\s*\d+\s*\|\s*(.+?)\s*\|")
    for path in sorted(rounds_dir.glob("*-round-R*.md")):
        for line in path.read_text(encoding="utf-8").splitlines():
            match = row.match(line)
            if not match:
                continue
            text = match.group(1).replace("**", "").strip()
            if (re.search(r"[가-힣]", text) and re.search(r"[.?!]$", text) and "다 별로" not in text
                    and text not in sentences):
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


def free_width(target: Target, advances: dict[int, float], finals: dict[str, int]) -> float:
    """앞에 붙는 글자, 오른쪽 값 자리, 같은 줄의 고정 폭을 뺀, 글자가 쓸 수 있는 폭."""
    width = target.width - text_width(target.prefix, advances, target.size, target.tracking) - target.reserve_px
    if target.reserve_slot:
        width -= finals[target.reserve_slot] * (advances[ord("가")] * target.size + target.tracking)
    return round(width, 1)


def measure(fonts: Fonts, words: list[str], targets: tuple[Target, ...] = TARGETS) -> list[Result]:
    """targets 순서대로 잽니다. reserve_slot은 앞에서 잰 슬롯이어야 합니다."""
    results = []
    finals: dict[str, int] = {}
    for target in targets:
        ko_advances = fonts.ko(target.font)
        target = replace(target, width=free_width(target, ko_advances, finals), prefix="", reserve_slot=None, reserve_px=0.0)
        if target.sentence:
            ko = ko_line_chars(words, ko_advances, target.size, target.tracking, target.width) * target.lines
        else:
            ko = ko_name_chars(ko_advances, target.size, target.tracking, target.width) * target.lines
        ja = ja_line_chars(fonts.ja(target.font), target.size, target.width) * target.lines
        en = en_line_chars(ko_advances, target.size, target.tracking, target.width) * target.lines
        result = Result(target, ko, ja, en)
        finals.update({slot: result.final("ko") for slot in target.slots})
        results.append(result)
    return results


def render_table(results: list[Result]) -> str:
    lines = [
        "| 슬롯 | 놓이는 칸 | 칸 폭 | 줄 | ko 초안 | ko 계산 | **ko** | **ja** | **en** |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for result in results:
        target = result.target
        slots = "<br>".join(f"`{slot}`" for slot in target.slots)
        draft = "-" if target.draft is None else target.draft
        lines.append(
            f"| {slots} | {target.where} | {target.width:g}px | {target.lines} | {draft} | {result.ko} "
            f"| **{result.final('ko')}** | **{result.final('ja')}** | **{result.final('en')}** |"
        )
    for slot, (where, draft) in UNBOUNDED.items():
        lines.append(f"| `{slot}` | {where} | 본문 | 제한 없음 | {draft} | - "
                     f"| **{draft}** | **{draft}** | **{math.floor(draft * 1.8)}** |")
    lines += ["", "| 슬롯 | 상한 없음 이유 |", "| --- | --- |"]
    lines += [f"| `{slot}` | {reason} |" for slot, reason in NO_LIMIT.items()]
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
