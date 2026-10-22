"""글자 수 상한 계산 테스트 (depth-lock spec §5, spec-followups spec §5)."""
import json
import pathlib
import re
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import fonts  # noqa: E402
import lengths  # noqa: E402
from lengths import (CONTENT_WIDTH, Result, Target, corpus_sentences, en_line_chars, free_width,  # noqa: E402
                     ja_line_chars, ko_line_chars, ko_name_chars, measure, render_table)

REPO_ROOT = TOOLS_DIR.parents[3]
FONT_FILES = [name for pair in lengths.FONT_FILES.values() for name in pair if name]

EXISTING_ROWS = [  # lengths.md 2.2.0 시점의 확정 13행 중 남은 11행(D79로 ui.depth 두 행을 뺌). 값이 바뀌면 안 됨 (spec-followups spec §5.6)
    '| `daily.fortune.head`<br>`daily.fortune.tag` | today sentence-block card (상자 없이 본문 폭, 시안 design-v2-today) | 320px | 2 | 32 | 42 | **32** | **32** | **57** |',
    '| `daily.guide` | guide-question-card question (안쪽 space.20) | 280px | 2 | 40 | 36 | **36** | **30** | **70** |',
    '| `daily.color`<br>`daily.direction`<br>`daily.number`<br>`daily.focus_time` | lucky-card explain (안쪽 space.12) | 296px | 2 | 36 | 58 | **36** | **36** | **64** |',
    '| `daily.focus_reason` | lucky-card explain 안 한 줄 | 296px | 1 | 10 | 26 | **10** | **10** | **18** |',
    # daily.tag_label은 2.5.0(#239)에서 더 좁은 오늘 화면 lucky-card tag 칩으로 다시 잼. 확정값(굵은 칸)은 그대로
    "| `daily.tag_label` | lucky-card tag 칩 값 (오늘 화면, 굵기 600, 좌우 12px, 아이콘 16 + 간격 6. diary tag-chip보다 좁음) | 274px | 1 | 10 | 24 | **10** | **10** | **18** |",
    '| `calendar.day_level` | day-character badge (좌우 10px) | 300px | 1 | 10 | 27 | **10** | **10** | **18** |',
    '| `calendar.score_item` | term-token label (좌우 4px) | 312px | 1 | 10 | 30 | **10** | **10** | **18** |',
    '| `calendar.solar_term` | day-cell lunar 줄 (칸 폭 44px, 굵게) | 44px | 1 | 10 | 4 | **4** | **3** | **6** |',
    '| `glossary.value_name` | lucky-card chip 값 (칩이 한 줄에 혼자일 때, 좌우 12px, 아이콘 16 + 간격 6) | 274px | 1 | 10 | 24 | **10** | **10** | **18** |',
    '| `chart.yongsin_method` | saju-chart 본문 sentence-block body | 본문 | 제한 없음 | 60 | - | **60** | **60** | **108** |',
    # settings.calculation_basis는 W21로 ui 슬롯 calc-basis.longitude.body로 옮겨 감. 값은 그대로 (#284)
    '| `calc-basis.longitude.body` | calc-basis 본문 sentence-block body | 본문 | 제한 없음 | 120 | - | **120** | **120** | **216** |',
]

# D77로 IA에 더한 ui 자리 → 그 자리를 담은 writing 슬롯 (writing W33, 슬롯 id를 두고 ia 필드로 자리를 적음)
D77_SLOTS = {
    "today.evidence.link": "ui.depth.evidence_link",
    "evidence-sheet.sheet.title": "ui.evidence.title",
    "login.error.body": "ui.login.error",
    "event-edit.save.cta": "ui.event-edit.save",
    "event-edit.delete.cta": "ui.event-edit.delete",
    "event-edit.offline.notice": "ui.event-edit.offline",
    "event-edit.save.failed": "ui.event-edit.save-failed",
    "diary-edit.save.cta": "ui.diary-edit.save",
    "diary-view.deleted.toast": "ui.diary-view.deleted",
}

DIALOG_SLOTS_EXPECTED = {"diary-view.delete.confirm", "event-edit.delete.confirm", "account-delete.delete.confirm",
                         "settings.logout.confirm", "preview.share.login-notice", "profile-edit.recalc.confirm",
                         "login-methods.unlink.confirm", "account-merge.merge.confirm"}
# D82·D83 로그인 수단·계정 합치기와 윤달 표지 (#389·#260, spec 2026-10-22 §6)
ISSUE_389 = {
    "login-methods.intro.body", "login-methods.last.notice", "login-methods.unlink.confirm",
    "account-merge.title.head", "account-merge.title.body", "account-merge.choice.label",
    "account-merge.overlap.notice", "account-merge.cta.merge", "account-merge.cta.cancel", "account-merge.merge.confirm",
    "ui.login-methods.row", "ui.account-merge.choice", "ui.account-merge.saju", "ui.settings.login-methods",
}

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
    assert "| `calc-basis.longitude.body` |" in table and "**216**" in table


def test_corpus_reads_round_choices():
    sentences = corpus_sentences()  # 라운드는 W1 동안 계속 늘어나므로 개수를 고정하지 않음 (#252)
    assert sentences and len(set(sentences)) == len(sentences)
    assert "오늘은 남색이 잘 맞아요." in sentences
    assert all("다 별로" not in sentence and "**" not in sentence for sentence in sentences)


def test_measured_corpus_matches_lengths_md_basis():
    basis = re.search(r"writing 라운드 R1~R(\d+) 원고 문장\(중복을 뺀 (\d+)개\)",
                      (TOOLS_DIR.parent / "lengths.md").read_text(encoding="utf-8"))
    last_round, count = int(basis.group(1)), int(basis.group(2))
    measured = corpus_sentences(last_round=lengths.MEASURED_LAST_ROUND)
    assert last_round == lengths.MEASURED_LAST_ROUND and len(measured) == count
    assert corpus_sentences()[:count] == measured  # 뒤 라운드는 측정 말뭉치를 바꾸지 않음


def test_every_requested_slot_has_a_value_or_no_limit():
    slots = {slot for target in lengths.TARGETS for slot in target.slots} | set(lengths.UNBOUNDED)
    issue_54 = {
        "daily.fortune.head", "daily.fortune.tag", "daily.guide", "daily.color", "daily.direction", "daily.number",
        "daily.focus_time", "daily.tag_label", "daily.focus_reason", "calendar.day_level", "calendar.score_item",
        "calendar.solar_term", "glossary.value_name", "chart.yongsin_method",
        # ui.depth.surface·explain·evidence·default_label은 D79로 기본 깊이 설정과 함께 뺌(#318). explain은 NO_LIMIT
        "calc-basis.longitude.body",  # 옛 settings.calculation_basis (W21)
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
        # 최종 리뷰에서 더한 이름 자리
        "ui.depth.evidence_link", "ui.guide.card", "settings.ad-free.label", "ui.evidence.title",
        "saju-chart.yongsin.title",
    } | DIALOG_SLOTS_EXPECTED
    assert slots == issue_54 | issue_131 | set(D77_SLOTS.values()) | ISSUE_389
    assert set(lengths.NO_LIMIT) == {  # spec-followups spec §5.3 표
        "ui.nav.a11y", "ui.a11y.label", "ui.picker.label", "evidence-sheet.a11y.locked", "evidence-sheet.a11y.checking",
        "evidence-sheet.a11y.unlocked", "today.reaction.label", "chart.ilgan_body", "chart.yongsin_summary",
        "term.meaning", "ui.app.bootstrap", "system.apple_return", "ui.guide.a11y", "login.discard.notice",
        "ui.depth.explain", "login-methods.error.body", "ui.account-merge.error", "ui.day-cell.lunar",
    }
    assert not set(lengths.NO_LIMIT) & slots


def test_trailing_link_is_taken_from_last_line_only():
    # 한 줄 ko 7자·ja 6자·en 11자(폭 70). 링크는 label.lg 14px −0.28, 앞 U+00A0(가짜 글꼴에 없어 1em) + 화살표 16.
    # ko "가가" 57.16px → ceil(57.16 × 7 / 70) = 6자, ja 전각 28 + 13.72 + 16 → 5자, en "ab" 43.16px → 7자를 한 번만 뺌
    target = Target(("r",), "칸", "ui", 10, 0, 70, 2, True, None, trailing_link="link")
    links = {"link": {"ko": "가가", "ja": "가가", "en": "ab"}}
    (result,) = measure(FakeFonts(), ["가가가"] * 30, (target,), links)
    assert (result.ko, result.ja, result.en) == (8, 7, 15)
    assert result.target.width == 70


def test_no_limit_rows_are_rendered():
    table = render_table([])
    assert "| `ui.a11y.label` |" in table and "| `system.apple_return` |" in table and "상한 없음" in table
    assert "상한을 두지 않는 슬롯" in table


def test_only_dialog_slots_sit_in_two_targets():
    seen = {}
    for target in lengths.TARGETS:
        for slot in target.slots:
            seen[slot] = seen.get(slot, 0) + 1
    assert {slot for slot, count in seen.items() if count > 1} == DIALOG_SLOTS_EXPECTED == set(lengths.DIALOG_SLOTS)


def test_measuring_fonts_are_pinned():
    assert set(FONT_FILES) <= {font.name for font in fonts.FONTS}


def test_existing_rows_keep_their_values(capsys, font_dir):
    lengths.main(["--font-dir", str(font_dir)])
    table = capsys.readouterr().out
    assert all(row in table for row in EXISTING_ROWS)


def test_committed_table_matches_measurement(capsys, font_dir):
    lengths.main(["--font-dir", str(font_dir)])
    table = capsys.readouterr().out
    assert table in (TOOLS_DIR.parent / "lengths.md").read_text(encoding="utf-8")


def test_d77_ia_slots_are_measured():
    ia = json.loads((REPO_ROOT / "docs" / "ia" / "screens.json").read_text(encoding="utf-8"))
    ia_slots = {slot["id"] for screen in ia["screens"] for slot in screen.get("slots", [])}
    assert set(D77_SLOTS) <= ia_slots
    measured = {slot for target in lengths.TARGETS for slot in target.slots}
    assert set(D77_SLOTS.values()) <= measured
    places = {slot: target.where for target in lengths.TARGETS for slot in target.slots}
    assert {places[D77_SLOTS[ia_id]].split(" ")[0] for ia_id in ("event-edit.save.cta", "diary-edit.save.cta")} == {"primary-button"}
    assert places["ui.event-edit.offline"].startswith("notice-banner")
    assert places["ui.diary-view.deleted"].startswith("toast") and places["ui.event-edit.save-failed"].startswith("toast")


def test_d82_ia_slots_are_measured():
    ia = json.loads((REPO_ROOT / "docs" / "ia" / "screens.json").read_text(encoding="utf-8"))
    screens = {screen["id"]: screen for screen in ia["screens"]}
    ia_slots = {slot["id"] for sid in ("login-methods", "account-merge") for slot in screens[sid]["slots"]
                if not slot["id"].endswith(".bar.title")}
    measured = {slot for target in lengths.TARGETS for slot in target.slots}
    assert ia_slots <= measured | set(lengths.NO_LIMIT)
    places = {slot: target.where for target in lengths.TARGETS for slot in target.slots}
    assert places["account-merge.cta.merge"].startswith("primary-button")
    assert "44px" in lengths.NO_LIMIT["ui.day-cell.lunar"]
    assert next(t for t in lengths.TARGETS if "ui.login.provider" in t.slots).width == 232


def test_latin_ja_label_takes_en_limit(capsys, font_dir):
    # ja 카카오 라벨은 가이드에 일본어 문구가 없어 영문 "Login with Kakao"(#143). 전각 기준 ja 상한 대신 en 상한 (#446)
    assert lengths.KEY_LIMITS == {("ui.login.provider", "loginKakaoLabel", "ja"): (
        "en", "ja 원고가 영문(카카오 가이드에 일본어 문구 없음, #143). 실측 106px로 칸 232px에 들어감")}
    lengths.main(["--font-dir", str(font_dir)])
    table = capsys.readouterr().out
    provider_row = next(line for line in table.splitlines() if line.startswith("| `ui.login.provider` | social"))
    en_limit = provider_row.split("**")[-2]
    assert f"| `ui.login.provider` | `loginKakaoLabel` | ja | **{en_limit}** |" in table
