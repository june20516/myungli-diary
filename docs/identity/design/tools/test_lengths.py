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

EXISTING_ROWS = [  # lengths.md 2.2.0 시점의 확정 13행 중 남은 11행(D79로 ui.depth 두 행을 뺌). 값이 바뀌면 안 됨 (spec-followups spec §5.6). 4.0.0(DS1)에서 칸 설명과 폭만 바뀐 행은 새 설명, 굵은 확정값은 그대로
    '| `daily.fortune.head`<br>`daily.fortune.tag` | today sentence-block card (상자 없이 본문 폭, 시안 design-v2-today) | 320px | 2 | 32 | 42 | **32** | **32** | **57** |',
    '| `daily.guide` | guide-question-card question (안쪽 space.20) | 280px | 2 | 40 | 36 | **36** | **30** | **70** |',
    '| `daily.color`<br>`daily.direction`<br>`daily.number`<br>`daily.focus_time` | lucky-card 설명 시트 본문 (explain-sheet, sheet 안쪽 24, sentence-block body) | 312px | 2 | 36 | 46 | **36** | **36** | **64** |',
    '| `daily.focus_reason` | lucky-card 설명 시트 안 한 줄 | 312px | 1 | 10 | 22 | **10** | **10** | **18** |',
    # daily.tag_label은 2.5.0(#239)에서 lucky-card tag 칩으로, 5.0.0(DS1)에서 그 변형이 지워져 hanja-tag 이름 칸으로 다시 잼. 확정값(굵은 칸)은 그대로
    "| `daily.tag_label` | hanja-tag 이름 (카드 안 한 줄, 카드 안쪽 16, 앞 4 + 한자 원 22 + 간격 4, 뒤 12. diary-summary, diary-row 카드가 가장 좁음) | 246px | 1 | 10 | 22 | **10** | **10** | **18** |",
    '| `calendar.day_level` | day-character badge (좌우 12px, day-sheet 안이 가장 좁음) | 288px | 1 | 10 | 26 | **10** | **10** | **18** |',
    '| `calendar.score_item` | term-token label (좌우 4px) | 312px | 1 | 10 | 30 | **10** | **10** | **18** |',
    '| `calendar.solar_term` | day-cell lunar 줄 (칸 폭 44px, 굵게) | 44px | 1 | 10 | 4 | **4** | **3** | **6** |',
    '| `glossary.value_name` | lucky-card chip 값 (칩이 한 줄에 혼자일 때, 좌우 12px, 아이콘 16 + 간격 4) | 276px | 1 | 10 | 25 | **10** | **10** | **18** |',
    '| `chart.yongsin_method` | saju-chart 본문 sentence-block body | 본문 | 제한 없음 | 60 | - | **60** | **60** | **108** |',
    # settings.calculation_basis는 W21로 ui 슬롯 calc-basis.longitude.body로 옮겨 감. 값은 그대로 (#284)
    '| `calc-basis.longitude.body` | calc-basis 본문 sentence-block body | 본문 | 제한 없음 | 120 | - | **120** | **120** | **216** |',
]

# D77로 IA에 더한 ui 자리 → 그 자리를 담은 writing 슬롯 (writing W33, 슬롯 id를 두고 ia 필드로 자리를 적음)
D77_SLOTS = {
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
    "account-merge.overlap.notice", "account-merge.cta.merge", "account-merge.merge.confirm",
    "ui.login-methods.row", "ui.account-merge.choice", "ui.account-merge.saju", "ui.settings.login-methods",
}
# D85 계정 합치기 두 단계·D88 구매 내역 (#480·#483·#494, spec 2026-10-23 §8)
ISSUE_480 = {
    "login-methods.merge.cta", "ad-free.history.cta", "account-merge.auth.body", "purchase-history.missing.notice",
    "ui.account-merge.summary", "ui.purchase.meta", "ui.purchase.status",
}
# #548·#564: IA ad-free 구매 버튼과 기간 고지
ISSUE_564 = {"ad-free.buy.cta", "ad-free.offer.period"}
ISSUE_354 = {"profile-edit.recalc.notice"}  # settings-row groupNote (V50)
# D102 문의 화면 contact (#763)
ISSUE_763 = {
    "contact.bar.title", "contact.intro.body", "contact.message.field", "contact.email.field",
    "contact.attached.notice", "contact.send.cta", "contact.sent.toast", "contact.address.note", "ui.contact.error",
}
# writing W51 IA 밖 ui 슬롯 7개 (#710)
ISSUE_710 = {"ui.settings.row", "ui.legal.row", "ui.profile-edit.birthplace", "ui.saju-chart.tab", "ui.saju.header",
             "ui.saju.tag", "ui.evidence.personal-empty"}

# DS1 2단계(#801) 화면 결정 시안의 새 자리: 시진 이름, 자리 표시 기둥 글자, 가운데 초안 상태 (V82, V88, V91)
DS1_SCREENS = {"ui.birth-info.row", "ui.saju.stage-marker", "diary-edit.draft.status",
               "today.featured.empty"}  # D112 대표 태그 없는 날 한 줄
# #859 drift(D113): IA 새 슬롯 일정 섹션 제목과 대표 태그 시트 꺾쇠 링크(같은 말인 tag-sheet.diary.cta 포함, V97)
ISSUE_859 = {"today.event.title", "explain-sheet.tag.diary-link", "tag-sheet.diary.cta"}

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
        "today.guide.cta", "evidence-sheet.lock.cta", "diary-list.pick-date.cta",
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
    requested = (issue_54 | issue_131 | set(D77_SLOTS.values()) | ISSUE_389 | ISSUE_480 | ISSUE_564 | ISSUE_354 | ISSUE_710
                 | ISSUE_763 | DS1_SCREENS | ISSUE_859)
    slots |= set(lengths.FIXED_LIMITS)
    assert slots == requested - {"ui.depth.evidence_link"}  # DS1(V63): 근거 아이콘의 스크린리더 이름이 되어 상한 없음
    assert set(lengths.NO_LIMIT) == {  # spec-followups spec §5.3 표
        "ui.nav.a11y", "ui.a11y.label", "ui.picker.label", "evidence-sheet.a11y.locked", "evidence-sheet.a11y.checking",
        "evidence-sheet.a11y.unlocked", "today.reaction.label", "chart.ilgan_body", "chart.yongsin_summary",
        "term.meaning", "ui.app.bootstrap", "system.apple_return", "ui.guide.a11y", "login.discard.notice",
        "ui.depth.explain", "login-methods.error.body", "ui.account-merge.error", "ui.day-cell.lunar",
        "login-methods.in-use.body", "account-merge.not-other.body", "ui.purchase.product",
        # W51 스크린리더 전용 셋과 iOS 시스템 창 (#710)
        "ui.saju.a11y", "ui.lucky-card.a11y", "ui.share.a11y", "ui.system.tracking",
        "ui.depth.evidence_link",  # DS1 근거 아이콘 스크린리더 이름 (V63)
        "ui.keyboard.dismiss",  # DS1 키보드 내리기 스크린리더 이름 (V68)
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
    assert set(D77_SLOTS.values()) - set(lengths.NO_LIMIT) <= measured
    # today.evidence.link는 IA v5(#812)에서 지워졌습니다. writing 슬롯은 스크린리더 이름이라 상한이 없습니다(V63).
    assert "ui.depth.evidence_link" in lengths.NO_LIMIT
    places = {slot: target.where for target in lengths.TARGETS for slot in target.slots}
    assert places[D77_SLOTS["event-edit.save.cta"]].split(" ")[0] == "primary-button"
    assert places[D77_SLOTS["diary-edit.save.cta"]].startswith("app-bar textAction")  # DS1 V82: 상단 바 글자 버튼
    assert places["ui.event-edit.offline"].startswith("notice-banner")
    assert places["ui.diary-view.deleted"].startswith("toast") and places["ui.event-edit.save-failed"].startswith("toast")


def test_d82_ia_slots_are_measured():
    ia = json.loads((REPO_ROOT / "docs" / "ia" / "screens.json").read_text(encoding="utf-8"))
    screens = {screen["id"]: screen for screen in ia["screens"]}
    # 빈 상태 문장은 다른 화면과 같이 재지 않음. ad-free는 새 버튼만 봄(가격·남은 기간은 재지 않는 자리, spec 2026-10-23 §8)
    ia_slots = {slot["id"] for sid in ("login-methods", "account-merge", "purchase-history")
                for slot in screens[sid]["slots"]
                if not slot["id"].endswith(".bar.title") and slot["id"] != "purchase-history.empty.body"}
    ia_slots |= {"ad-free.history.cta", "ad-free.buy.cta", "ad-free.offer.period"}
    measured = {slot for target in lengths.TARGETS for slot in target.slots}
    assert ia_slots <= measured | set(lengths.NO_LIMIT)
    places = {slot: target.where for target in lengths.TARGETS for slot in target.slots}
    assert places["account-merge.cta.merge"].startswith("primary-button")
    assert places["login-methods.merge.cta"].startswith("primary-button")
    # offer-card 안 버튼은 카드 안쪽 20 안이라 화면 폭 버튼보다 좁음 (#548·#564)
    assert places["ad-free.history.cta"].startswith("offer-card 안 primary-button")
    assert places["ad-free.buy.cta"] == places["ad-free.history.cta"]
    assert "ad-free.restore.cta" not in places
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
    assert f"| ja | `ui.login.provider` | `loginKakaoLabel` | **{en_limit}** |" in table


def test_key_limit_rows_are_not_read_as_slot_rows():
    # writing test_slots.design_lengths는 '## 상한' 절에서 "| `"로 시작하는 줄을 슬롯 행으로 읽음. 키별 행은 언어 칸으로 시작
    table = render_table([])
    key_section = table.split("키별 상한", 1)[1].split("상한을 두지 않는 슬롯", 1)[0]
    assert not any(line.startswith("| `") for line in key_section.splitlines())


def test_line_label_is_measured_at_198():
    # LINE 공식 버튼 자산의 구분선 비율을 따르면 글자 자리가 198px (#475, 결정 V46)
    target = lengths.KEY_TARGETS[("ui.login.provider", "loginLineLabel")]
    assert (target.width, target.font, target.size) == (198, "ui-600", 14)


def test_purchase_meta_and_status_are_measured_apart():
    places = {slot: target for target in lengths.TARGETS for slot in target.slots}
    assert places["ui.purchase.status"].width == 80 - 2 * 8
    assert places["ui.purchase.meta"].width == lengths.CONTENT_WIDTH - 2 * 16
    # 구매일과 사용 기간은 줄을 나눠 키마다 한 줄 (W44, 결정 V47)
    assert places["ui.purchase.meta"].lines == 1 and "키마다 한 줄" in places["ui.purchase.meta"].where


def test_offer_card_slots_are_measured_inside_card():
    places = {slot: target for target in lengths.TARGETS for slot in target.slots}
    assert places["ad-free.buy.cta"].width == lengths.CONTENT_WIDTH - 2 * 20 - 2 * 20
    assert places["ad-free.offer.period"].width == lengths.CONTENT_WIDTH - 2 * 20
    assert "ad-free.history.cta" not in next(t for t in lengths.TARGETS if "welcome.cta.start" in t.slots).slots
    assert "가져올 계정" in places["ui.account-merge.choice"].where


def test_w51_slots_are_measured_at_their_narrowest_place():
    places = {slot: target for target in lengths.TARGETS for slot in target.slots}
    # 행 머리 52에서 term-token label 좌우 4, 두 줄 (결정 V53)
    header = places["ui.saju.header"]
    assert header.width == 52 - 2 * 4 and header.lines == 2
    # 대운 꼬리표: 기둥 둘과 간격(52 × 2 + 4)에서 tag.status 좌우 8 (결정 V53)
    assert places["ui.saju.tag"].width == 52 * 2 + 4 - 2 * 8
    # 설정 줄 이름과 값은 화살표를 뺀 줄을 사이 8을 두고 나눔
    assert places["ui.settings.row"] is places["ui.profile-edit.birthplace"]
    assert places["ui.settings.row"].width == (lengths.CONTENT_WIDTH - 2 * 16 - 16 - 8 - lengths.SETTINGS_LEADING) / 2  # V58
    assert places["ui.legal.row"].width == lengths.CONTENT_WIDTH - 2 * 16 - 16
    assert places["ui.saju-chart.tab"] is places["ui.birth.option"]
    assert places["ui.evidence.personal-empty"].lines == 2 and places["ui.evidence.personal-empty"].sentence
    assert ("ui.saju.tag", "sajuTagMe") in lengths.KEY_TARGETS


def test_hidden_stems_takes_measured_limit(capsys, font_dir):
    # en "Hidden stems"는 이름 자리 추정(10)을 넘지만 낱말마다 행 머리 44px 한 줄에 들어가 두 줄 안 (#710, 결정 V53)
    (limit, reason), = [value for key, value in lengths.KEY_MEASURED_LIMITS.items()
                        if key == ("ui.saju.header", "manseRowHiddenStems", "en")]
    assert limit == len("Hidden stems")
    target = next(t for t in lengths.TARGETS if "ui.saju.header" in t.slots)
    advances = lengths.Fonts(font_dir).ko(target.font)
    assert all(lengths.text_width(word, advances, target.size, target.tracking) <= target.width
               for word in "Hidden stems".split())
    lengths.main(["--font-dir", str(font_dir)])
    table = capsys.readouterr().out
    assert f"| en | `ui.saju.header` | `manseRowHiddenStems` | **{limit}** | 실측: {reason} |" in table


def test_contact_slots_are_measured(capsys, font_dir):
    # D102 문의 화면: IA 슬롯과 IA 밖 오류 슬롯을 모두 잼. 칸 안 안내와 메일 칸 오류는 키별 (#763, 결정 V55)
    ia = json.loads((REPO_ROOT / "docs" / "ia" / "screens.json").read_text(encoding="utf-8"))
    contact = next(screen for screen in ia["screens"] if screen["id"] == "contact")
    measured = {slot for target in lengths.TARGETS for slot in target.slots}
    assert {slot["id"] for slot in contact["slots"]} | {"ui.contact.error"} <= measured
    places = {slot: target for target in lengths.TARGETS for slot in target.slots}
    assert places["contact.send.cta"].where.startswith("primary-button")
    assert places["contact.sent.toast"] is places["ui.contact.error"] and places["ui.contact.error"].where.startswith("toast")
    assert places["contact.bar.title"] is places["ui.app.name"]
    hint = lengths.KEY_TARGETS[("contact.message.field", "contactMessageFieldHint")]
    assert (hint.size, hint.width, hint.lines) == (17, lengths.CONTENT_WIDTH - 2 * 16 - 20 - 8, 2)
    error_line = lengths.KEY_TARGETS[("ui.contact.error", "contactEmailInvalid")]
    assert error_line.width == lengths.CONTENT_WIDTH - lengths.ICON_BESIDE_SMALL_TEXT - 4  # V57: 경고 표시는 아이콘 단계
    # ja 메일 칸 안내는 라틴 주소 예시라 실측 상한 하나만 나옴
    advances = lengths.Fonts(font_dir).ko("ui-400")
    assert lengths.text_width("name@example.com", advances, 17, 0) <= hint.width
    lengths.main(["--font-dir", str(font_dir)])
    table = capsys.readouterr().out
    ja_rows = [line for line in table.splitlines() if line.startswith("| ja | `contact.email.field` | `contactEmailFieldHint`")]
    assert len(ja_rows) == 1 and "**16**" in ja_rows[0]


def test_settings_label_width_after_icon():
    # DS1(결정 V58): 설정 화면 메뉴 줄은 앞 아이콘 20 + 간격 12만큼 이름 자리가 줄어듦. 이름과 값은 나머지를 반씩
    by_slot = {slot: target for target in lengths.TARGETS for slot in target.slots}
    leading = 20 + 12
    assert by_slot["settings.ad-free.label"].width == CONTENT_WIDTH - 2 * 16 - 16 - leading == 240
    assert by_slot["ui.settings.login-methods"].width == 240
    assert by_slot["ui.settings.row"].width == (CONTENT_WIDTH - 2 * 16 - 16 - 8 - leading) / 2 == 116
    assert by_slot["ui.legal.row"].width == CONTENT_WIDTH - 2 * 16 - 16  # 약관 목록 줄은 앞 아이콘 없음


def test_evidence_link_name_is_screen_reader_only():
    # DS1(결정 V63): 근거 진입점은 아이콘이라 "근거 보기"는 스크린리더 이름. 이유 줄 끝에서는 아이콘 폭(공백 + 20)만 뺌
    assert lengths.NO_LIMIT["ui.depth.evidence_link"] == lengths.SCREEN_READER_ONLY
    assert not [target for target in lengths.TARGETS if "ui.depth.evidence_link" in target.slots]
    reason = next(target for target in lengths.TARGETS if target.slots == ("character.reason",))
    assert reason.trailing_icon == 20 and reason.trailing_link is None


def _spec_px(value):
    """명세 값 `{space.24}`·`{size.icon.20}`이나 `{"value": n, "unit": "px"}`를 px 숫자로."""
    if isinstance(value, dict):
        return value["value"]
    primitive = json.loads((TOOLS_DIR.parent / "tokens" / "primitive.tokens.json").read_text(encoding="utf-8"))
    node = primitive
    for key in value.strip("{}").split("."):
        node = node[key]
    return node["$value"]["value"]


def _component(group, component_id):
    document = json.loads((TOOLS_DIR.parent / "components" / f"{group}.json").read_text(encoding="utf-8"))
    return next(c for c in document["components"] if c["id"] == component_id)


def test_layout_constants_match_component_spec():
    # DS1 최종 리뷰: 명세 폭이 바뀌면 글자 수 상한 계산도 같이 바뀌어야 함. 측정 상수를 명세 값과 대조
    sheet = _component("frame", "sheet")["parts"]["container"]
    assert lengths.SHEET_PADDING == _spec_px(sheet["paddingX"]) == 24
    assert lengths.SHEET_CONTENT_WIDTH == lengths.SCREEN_WIDTH - 2 * lengths.SHEET_PADDING == 312
    dialog = _component("feedback", "dialog")
    assert lengths.DIALOG_MARGIN == _spec_px(dialog["parts"]["container"]["marginX"])
    assert lengths.DIALOG_PADDING == _spec_px(dialog["parts"]["container"]["padding"])
    assert lengths.DIALOG_BUTTON_PADDING == _spec_px(dialog["parts"]["actions"]["buttonPaddingX"])
    title = next(v for v in dialog["variants"] if v["id"] == "destructive")["parts"]["title"]
    assert lengths.DIALOG_CAUTION == _spec_px(title["leadingSize"]) + _spec_px(title["leadingGap"])
    assert lengths.BUTTON_PADDING == _spec_px(_component("action", "primary-button")["parts"]["container"]["paddingX"])
    assert lengths.CHIP_PADDING == _spec_px(_component("today", "day-character")["parts"]["badge"]["paddingX"])
    lucky = _component("today", "lucky-card")["parts"]["chip"]
    assert lengths.CHIP_PADDING == _spec_px(lucky["paddingX"]) and lengths.LUCKY_CHIP_GAP == _spec_px(lucky["gap"])
    assert lengths.SEGMENTED_TRACK_PADDING == _spec_px(_component("input", "segmented")["parts"]["track"]["padding"])
    elements = json.loads((TOOLS_DIR.parent / "components" / "elements.json").read_text(encoding="utf-8"))["elements"]
    assert lengths.ICON_BESIDE_SMALL_TEXT == _spec_px(elements["icon"]["adjacentText"][0]["size"])
    leading = _component("action", "settings-row")["parts"]["leading"]
    assert lengths.SETTINGS_LEADING == _spec_px(leading["size"]) + _spec_px(leading["marginEnd"])
    reason = next(target for target in lengths.TARGETS if target.slots == ("character.reason",))
    icon = _component("sentence", "depth-link")["parts"]["icon"]
    assert reason.trailing_icon == _spec_px(icon["size"]) == _spec_px(icon["layoutWidth"])


def test_sheet_slots_are_measured_at_sheet_width():
    # 시트(explain, evidence, share-preview, day-sheet) 안 자리는 시트 안쪽 폭(312)으로 잼. day-sheet가 day-character를 씀
    by_slot = {slot: target for target in lengths.TARGETS for slot in target.slots}
    sheet = lengths.SHEET_CONTENT_WIDTH
    assert by_slot["ui.evidence.title"].width == sheet and by_slot["ui.evidence.personal-empty"].width == sheet
    assert by_slot["character.reason"].width == sheet
    assert by_slot["daily.color"].width == sheet and by_slot["daily.focus_reason"].width == sheet
    assert by_slot["calendar.day_level"].width == sheet - 2 * lengths.CHIP_PADDING
    assert by_slot["day-sheet.diary.write-cta"].width == sheet - 2 * lengths.BUTTON_PADDING
    assert by_slot["evidence-sheet.lock.cta"].width == sheet - 2 * lengths.BUTTON_PADDING
    assert by_slot["welcome.cta.start"].width == CONTENT_WIDTH - 2 * lengths.BUTTON_PADDING
    assert by_slot["evidence-sheet.section.basis"].width == sheet - lengths.ICON_BESIDE_SMALL_TEXT - 4
    assert by_slot["day-sheet.diary.open"].width == sheet - lengths.ICON_BESIDE_SMALL_TEXT - 2
    dialog_inner = lengths.SCREEN_WIDTH - 2 * lengths.DIALOG_MARGIN - 2 * lengths.DIALOG_PADDING
    assert by_slot["ui.action.button"].width == (dialog_inner - 8) / 2 - 2 * lengths.DIALOG_BUTTON_PADDING == 104


# DS1 2단계(#801) 새 자리와 다시 잰 자리 (결정 V82, V88, V91, V94)
def test_ds1_screen_slots_are_measured():
    places = {slot: target for target in lengths.TARGETS for slot in target.slots}
    # 상단 바 저장 글자 버튼: 동작 아이콘 둘 자리(44 × 2)까지, 좌우 space.8
    save = places["ui.diary-edit.save"]
    assert save.where.startswith("app-bar textAction") and save.width == lengths.APP_BAR_TEXT_ACTION_MAX - 2 * 8 == 72
    # 가운데 초안 상태: 뒤로 44와 저장 버튼 최대 폭 사이에서 아이콘 16 + 간격 4, 글자 수 앞 space.8과 글자 수 자리를 뺌
    status = places["diary-edit.draft.status"]
    # 가운데 정렬이라 뒤로 쪽도 저장 버튼 최대 폭만큼 비움 (우려 4 Ruling)
    center = lengths.SCREEN_WIDTH - 2 * 16 - 2 * lengths.APP_BAR_TEXT_ACTION_MAX
    assert status.width == center - 16 - 4 - 8 - lengths.DRAFT_COUNT_RESERVE == 60 and status.lines == 1
    # D112: 사주 기운 카드 안 한 줄(카드 안쪽 16, type.body.ui)
    empty = places["today.featured.empty"]
    assert empty.width == lengths.CONTENT_WIDTH - 2 * 16 and (empty.font, empty.size, empty.lines) == ("ui-400", 14, 1)
    # 시진 이름: 칸 단위로 줄이 바뀌므로 시진 칸 하나가 본문 폭을 다 쓸 때. hanja-tag 둘레와 시간 자리를 뺌
    hour = places["ui.birth-info.row"]
    assert hour.width == lengths.CONTENT_WIDTH - lengths.HANJA_TAG_CHROME - 8 - lengths.BIRTH_TIME_RESERVE
    assert hour.font == "ui-500" and hour.size == 13
    # 성별과 시간 모름 알약은 ui.birth.option 낱말을 함께 쓰고, segmented 칸이 더 좁아 그 행 값 그대로
    assert "birth-info-row" in places["ui.birth.option"].where
    assert places["daily.tag_label"].width == lengths.CONTENT_WIDTH - 2 * 16 - lengths.HANJA_TAG_CHROME
    # 자리 표시 원 18 안 한 글자
    where, width, limit, _reason = lengths.FIXED_LIMITS["ui.saju.stage-marker"]
    assert width == 18 and limit == 1 and "stage-strip" in where
    table = render_table([])
    assert "| `ui.saju.stage-marker` | " in table and "| 18px | 1 | - | - | **1** | **1** | **1** |" in table
    md = (TOOLS_DIR.parent / "lengths.md").read_text(encoding="utf-8")
    assert "* `diary-edit.draft.status`: app-bar 제목과 나눠 쓰는 폭을 명세가 정하지 않았습니다." not in md
    assert "`bandTableEmptyCell`" in md  # 빈 칸 "없음"은 ui.saju.a11y 키(스크린리더 전용, 상한 없음)


def test_ds1_layout_constants_match_component_spec():
    bar = _component("frame", "app-bar")["parts"]["textAction"]
    assert lengths.APP_BAR_TEXT_ACTION_MAX == _spec_px(bar["maxWidth"]) == 2 * _spec_px(
        _component("frame", "app-bar")["parts"]["action"]["target"])
    assert _spec_px(bar["paddingX"]) == 8
    pill = _component("sentence", "hanja-tag")["parts"]
    chrome = (_spec_px(pill["pill"]["paddingStart"]) + _spec_px(pill["glyph"]["size"]) + _spec_px(pill["pill"]["gap"])
              + _spec_px(pill["pill"]["paddingEnd"]))
    assert lengths.HANJA_TAG_CHROME == chrome == 42
    hour = _component("saju", "birth-info-row")["parts"]["hour"]
    assert _spec_px(hour["value"]["marginStart"]) == 8
    marker = _component("saju", "stage-strip")["parts"]["marker"]
    assert _spec_px(marker["size"]) == lengths.FIXED_LIMITS["ui.saju.stage-marker"][1]
    draft = _component("diary", "draft-indicator")["parts"]
    assert _spec_px(draft["icon"]["size"]) == 16 and _spec_px(draft["container"]["gap"]) == 4
    assert _spec_px(draft["count"]["marginStart"]) == 8


def test_issue_859_widths_follow_spec():
    by_slot = {slot: target for target in lengths.TARGETS for slot in target.slots}
    sheet = lengths.SHEET_CONTENT_WIDTH
    trailing = _component("frame", "section-header")["variants"]
    action = next(v for v in trailing if v["id"] == "action")["parts"]["trailing"]
    assert lengths.SECTION_TRAILING_TARGET == action["minTarget"]
    assert by_slot["today.event.title"].width == sheet - action["minTarget"]  # 그날 시트 action이 가장 좁음
    assert by_slot["explain-sheet.tag.diary-link"] is by_slot["tag-sheet.diary.cta"]
    assert by_slot["tag-sheet.diary.cta"].width == sheet - lengths.ICON_BESIDE_SMALL_TEXT - 2
