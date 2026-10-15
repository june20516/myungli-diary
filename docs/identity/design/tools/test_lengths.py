"""글자 수 상한 계산 테스트 (depth-lock spec §5, spec-followups spec §5)."""
import pathlib
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import lengths  # noqa: E402
from lengths import (CONTENT_WIDTH, Result, Target, corpus_sentences, en_line_chars, free_width,  # noqa: E402
                     ja_line_chars, ko_line_chars, ko_name_chars, measure, render_table)

REPO_ROOT = TOOLS_DIR.parents[3]
FONT_DIR = REPO_ROOT / ".suberpowers" / "fonts"
FONT_FILES = [name for pair in lengths.FONT_FILES.values() for name in pair if name]
FONTS_PRESENT = all((FONT_DIR / name).exists() for name in FONT_FILES)

EXISTING_ROWS = [  # lengths.md 2.2.0 시점의 확정 13행. 값이 바뀌면 안 됨 (spec-followups spec §5.6)
    '| `daily.fortune.head`<br>`daily.fortune.tag` | today sentence-block card (상자 없이 본문 폭, 시안 design-v2-today) | 320px | 2 | 32 | 42 | **32** | **32** | **57** |',
    '| `daily.guide` | guide-question-card question (안쪽 space.20) | 280px | 2 | 40 | 36 | **36** | **30** | **70** |',
    '| `daily.color`<br>`daily.direction`<br>`daily.number`<br>`daily.focus_time` | lucky-card explain (안쪽 space.12) | 296px | 2 | 36 | 58 | **36** | **36** | **64** |',
    '| `daily.focus_reason` | lucky-card explain 안 한 줄 | 296px | 1 | 10 | 26 | **10** | **10** | **18** |',
    "| `daily.tag_label` | tag-chip ('#' 뒤, 좌우 10px) | 293px | 1 | 10 | 28 | **10** | **10** | **18** |",
    '| `calendar.day_level` | day-character badge (좌우 10px) | 300px | 1 | 10 | 27 | **10** | **10** | **18** |',
    '| `calendar.score_item` | term-token label (좌우 4px) | 312px | 1 | 10 | 30 | **10** | **10** | **18** |',
    '| `calendar.solar_term` | day-cell lunar 줄 (칸 폭 44px, 굵게) | 44px | 1 | 10 | 4 | **4** | **3** | **6** |',
    '| `glossary.value_name` | lucky-card chip 값 (칩이 한 줄에 혼자일 때, 좌우 12px, 아이콘 16 + 간격 6) | 274px | 1 | 10 | 24 | **10** | **10** | **18** |',
    '| `ui.depth.surface`<br>`ui.depth.explain`<br>`ui.depth.evidence` | segmented 세 칸 중 한 칸 | 104px | 1 | 10 | 8 | **8** | **6** | **13** |',
    '| `ui.depth.default_label` | settings-row value 이름 (좌우 16px, 화살표 16, 오른쪽 값 = 단계 이름) | 177.4px | 1 | 10 | 15 | **10** | **10** | **18** |',
    '| `chart.yongsin_method` | saju-chart 본문 sentence-block body | 본문 | 제한 없음 | 60 | - | **60** | **60** | **108** |',
    '| `settings.calculation_basis` | calc-basis 본문 sentence-block body | 본문 | 제한 없음 | 120 | - | **120** | **120** | **216** |',
]

DIALOG_SLOTS_EXPECTED = {"diary-view.delete.confirm", "event-edit.delete.confirm", "account-delete.delete.confirm",
                         "settings.logout.confirm", "preview.share.login-notice", "profile-edit.recalc.confirm"}

# 한글 1em, 띄어쓰기 0.5em, 라틴 0.5em인 가짜 글꼴
FAKE = {ord(" "): 0.5, ord("가"): 1.0, **{ord(char): 0.5 for char in "abcdefghijklmnopqrstuvwxyz"}}


def test_content_width_is_360_minus_gutters():
    assert CONTENT_WIDTH == 320


def test_ko_name_chars_fills_one_line_without_spaces():
    assert ko_name_chars(FAKE, size=10, tracking=0, width=55) == 5


def test_ko_line_chars_wraps_by_word():
    # 어절 "가가가"(30px) 둘 + 띄어쓰기(5px) = 65px. 폭 70이면 두 어절이 한 줄(7자), 세 어절은 넘침.
    words = ["가가가"] * 30
    assert ko_line_chars(words, FAKE, size=10, tracking=0, width=70) == 7


def test_ko_line_chars_takes_lower_tenth_of_full_lines():
    # 폭 70에서 5자 이상 어절은 혼자 한 줄이 되므로 꽉 찬 줄 = [5, 5, 6, 7 × 17]. 20줄의 하위 10% 위치(2)는 6.
    # 마지막 어절 "가"는 꽉 찬 줄이 아니라서 세지 않음.
    words = ["가" * 5] * 2 + ["가" * 6] + ["가" * 7] * 17 + ["가"]
    assert ko_line_chars(words, FAKE, size=10, tracking=0, width=70) == 6


def test_ko_line_chars_needs_a_full_line():
    with pytest.raises(ValueError):
        ko_line_chars(["가"], FAKE, size=10, tracking=0, width=100)


def test_ja_line_chars_reserves_one_char_for_kinsoku():
    assert ja_line_chars(None, size=10, width=100) == 9


def test_en_line_chars_subtracts_half_a_word():
    # 글자·띄어쓰기 모두 0.5em → 한 자 5px, 폭 100이면 20자에서 (4.7 + 1) / 2 = 2.85를 빼고 버림
    assert en_line_chars(FAKE, size=10, tracking=0, width=100) == 17


def test_final_takes_smaller_of_draft_and_layout():
    target = Target(("s",), "칸", "sentence", 17, 0, 320, 2, True, 32)
    result = Result(target, ko=42, ja=30, en=50)
    assert (result.final("ko"), result.final("ja"), result.final("en")) == (32, 30, 50)
    assert Result(target, ko=42, ja=40, en=80).final("en") == 57
    no_draft = Target(("s",), "칸", "sentence", 17, 0, 320, 2, True, None)
    assert Result(no_draft, ko=42, ja=30, en=50).final("ko") == 42


class FakeFonts:
    def ko(self, family):
        return FAKE

    def ja(self, family):
        return None


def test_free_width_subtracts_prefix_and_reserved_slot():
    target = Target(("n",), "칸", "ui", 10, 0, 100, 1, False, 10, prefix="a", reserve_slot="v")
    # 'a' 5px + 값 3자 × 10px
    assert free_width(target, FAKE, {"v": 3}) == 65


def test_measure_uses_earlier_final_for_reserved_width():
    targets = (
        Target(("v",), "값 칸", "ui", 10, 0, 45, 1, False, 10),
        Target(("n",), "이름 칸", "ui", 10, 0, 100, 1, False, 10, reserve_slot="v"),
    )
    value, name = measure(FakeFonts(), [], targets)
    assert value.ko == 4 and name.target.width == 60 and name.ko == 6
    assert (name.ja, name.en) == (5, 9)


def test_render_table_lists_targets_and_unbounded_slots():
    target = Target(("a", "b"), "칸", "ui", 10, 0, 45, 1, False, 10)
    table = render_table([Result(target, ko=4, ja=3, en=6)])
    assert "| `a`<br>`b` | 칸 | 45px | 1 | 10 | 4 | **4** | **3** | **6** |" in table
    assert "| `settings.calculation_basis` |" in table and "**216**" in table


def test_corpus_reads_round_choices():
    sentences = corpus_sentences()
    assert len(sentences) == 49 and len(set(sentences)) == len(sentences)
    assert "오늘은 남색이 잘 맞아요." in sentences
    assert all("다 별로" not in sentence and "**" not in sentence for sentence in sentences)


def test_every_requested_slot_has_a_value_or_no_limit():
    slots = {slot for target in lengths.TARGETS for slot in target.slots} | set(lengths.UNBOUNDED)
    issue_54 = {
        "daily.fortune.head", "daily.fortune.tag", "daily.guide", "daily.color", "daily.direction", "daily.number",
        "daily.focus_time", "daily.tag_label", "daily.focus_reason", "calendar.day_level", "calendar.score_item",
        "calendar.solar_term", "glossary.value_name", "ui.depth.default_label", "ui.depth.surface",
        "ui.depth.explain", "ui.depth.evidence", "chart.yongsin_method", "settings.calculation_basis",
    }
    issue_131 = {  # spec-followups spec §5.2 표
        "welcome.cta.start", "welcome.cta.signin", "preview.cta.save", "preview.cta.restart", "consent.cta.agree",
        "notify-ask.cta.allow", "notify-ask.cta.skip", "force-update.cta.store", "account-delete.cta.delete",
        "today.guide.cta", "evidence-sheet.lock.cta", "ad-free.restore.cta", "diary-list.pick-date.cta",
        "day-sheet.event.add", "day-sheet.diary.write-cta", "share-preview.cta.share", "ui.action.button",
        "ui.login.provider", "ui.error.client", "ui.error.code", "ui.login.error", "ui.app.trace",
        "evidence-sheet.unlock.failed", "diary-edit.saved.tags", "ui.nav.tab", "ui.birth.option",
        "share-preview.ratio.label", "consent.required.label", "onboard-call.input.hint", "event-edit.title.hint",
        "event-edit.memo.hint", "birthplace.search.hint", "diary-edit.body.placeholder", "ui.app.notice",
        "saju-chart.time-unknown.notice", "diary-edit.offline.notice", "ui.picker.item",
        "evidence-sheet.section.basis", "evidence-sheet.section.source", "evidence-sheet.section.personal",
        "birthplace.standard.link", "day-sheet.diary.open", "saju-chart.yongsin.open", "ui.app.name",
        "onboard-time.hour.confirm", "character.reason", "chart.ilgan_head",
    } | DIALOG_SLOTS_EXPECTED
    assert slots == issue_54 | issue_131
    assert set(lengths.NO_LIMIT) == {  # spec-followups spec §5.3 표
        "ui.nav.a11y", "ui.a11y.label", "ui.picker.label", "evidence-sheet.a11y.locked", "evidence-sheet.a11y.checking",
        "evidence-sheet.a11y.unlocked", "today.reaction.label", "chart.ilgan_body", "chart.yongsin_summary",
        "term.meaning", "ui.app.bootstrap", "system.apple_return",
    }
    assert not set(lengths.NO_LIMIT) & slots


def test_reserve_px_is_subtracted():
    target = Target(("n",), "칸", "ui", 10, 0, 100, 1, False, None, reserve_px=30)
    assert free_width(target, FAKE, {}) == 70


def test_no_limit_rows_are_rendered():
    table = render_table([])
    assert "| `ui.a11y.label` |" in table and "| `system.apple_return` |" in table and "상한 없음" in table


def test_only_dialog_slots_sit_in_two_targets():
    seen = {}
    for target in lengths.TARGETS:
        for slot in target.slots:
            seen[slot] = seen.get(slot, 0) + 1
    assert {slot for slot, count in seen.items() if count > 1} == DIALOG_SLOTS_EXPECTED == set(lengths.DIALOG_SLOTS)


@pytest.mark.skipif(not FONTS_PRESENT, reason="측정 글꼴이 .suberpowers/fonts에 없음 (lengths.md 참고)")
def test_existing_rows_keep_their_values(capsys):
    lengths.main(["--font-dir", str(FONT_DIR)])
    table = capsys.readouterr().out
    assert all(row in table for row in EXISTING_ROWS)


@pytest.mark.skipif(not FONTS_PRESENT, reason="측정 글꼴이 .suberpowers/fonts에 없음 (lengths.md 참고)")
def test_committed_table_matches_measurement(capsys):
    lengths.main(["--font-dir", str(FONT_DIR)])
    table = capsys.readouterr().out
    assert table in (TOOLS_DIR.parent / "lengths.md").read_text(encoding="utf-8")
