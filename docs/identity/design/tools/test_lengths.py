"""글자 수 상한 계산 테스트 (depth-lock spec §5)."""
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
    assert len(sentences) == 46 and len(set(sentences)) == len(sentences)
    assert "오늘은 남색이 잘 맞아요." in sentences
    assert all("다 별로" not in sentence and "**" not in sentence for sentence in sentences)


def test_every_writing_slot_from_issue_54_has_a_value():
    slots = {slot for target in lengths.TARGETS for slot in target.slots} | set(lengths.UNBOUNDED)
    assert slots == {
        "daily.fortune.head", "daily.fortune.tag", "daily.guide", "daily.color", "daily.direction", "daily.number",
        "daily.focus_time", "daily.tag_label", "daily.focus_reason", "calendar.day_level", "calendar.score_item",
        "calendar.solar_term", "glossary.value_name", "ui.depth.default_label", "ui.depth.surface",
        "ui.depth.explain", "ui.depth.evidence", "chart.yongsin_method", "settings.calculation_basis",
    }


@pytest.mark.skipif(not FONTS_PRESENT, reason="측정 글꼴이 .suberpowers/fonts에 없음 (lengths.md 참고)")
def test_committed_table_matches_measurement(capsys):
    lengths.main(["--font-dir", str(FONT_DIR)])
    table = capsys.readouterr().out
    assert table in (TOOLS_DIR.parent / "lengths.md").read_text(encoding="utf-8")
