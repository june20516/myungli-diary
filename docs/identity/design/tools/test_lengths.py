"""글자 수 상한 계산 테스트 (depth-lock spec §5)."""
import pathlib
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import lengths  # noqa: E402
from lengths import (CONTENT_WIDTH, Result, Target, corpus_sentences, en_line_chars, ja_line_chars,  # noqa: E402
                     ko_line_chars, ko_name_chars)

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


def test_corpus_reads_round_choices():
    sentences = corpus_sentences()
    assert len(sentences) >= 40
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
