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
* 문장 끝 링크(trailing_link): writing 원고의 링크 문구를 언어별로 재(앞 U+00A0 + 화살표 16), 마지막 줄에서 그 폭의 글자 수를 한 번 뺍니다.
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
# 확정 표를 잰 라운드(lengths.md "ko 문장 자리"). 뒤 라운드가 늘어도 확정값이 움직이지 않게 여기서 멈춥니다
MEASURED_LAST_ROUND = 8
UI_TEXT_DIR = DESIGN_DIR.parent / "writing" / "content"
LANGUAGES = ("ko", "ja", "en")

SCREEN_WIDTH = 360
SCREEN_GUTTER = 20
CONTENT_WIDTH = SCREEN_WIDTH - 2 * SCREEN_GUTTER

KO_LINE_PERCENTILE = 0.10

# 문장 끝 depth-link inline-end: label.lg(ui-600 14 −0.28), 앞 U+00A0, 뒤 화살표 caret-right 14 + 간격 2 (결정 V29)
LINK_FONT, LINK_SIZE, LINK_TRACKING = "ui-600", 14, -0.28
LINK_ARROW_PX = 14 + 2
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
    trailing_link: str | None = None  # 문장 끝에 붙는 링크 슬롯. 그 원고 폭만큼 마지막 줄에서 뺌(언어별)


# 한 슬롯에 제목·본문·버튼 키가 함께 있는 확인 창. 제목 키와 버튼 키에만 상한을 둡니다(본문은 창이 늘어남).
DIALOG_SLOTS = (
    "diary-view.delete.confirm", "event-edit.delete.confirm", "account-delete.delete.confirm",
    "settings.logout.confirm", "preview.share.login-notice", "profile-edit.recalc.confirm",
    # D82 로그인 수단 떼기·계정 합치기 확인 창 (#389)
    "login-methods.unlink.confirm", "account-merge.merge.confirm",
)

TARGETS = (
    Target(("daily.fortune.head", "daily.fortune.tag"), "today sentence-block card (상자 없이 본문 폭, 시안 design-v2-today)", "sentence", 17, 0, CONTENT_WIDTH, 2, True, 32),
    Target(("daily.guide",), "guide-question-card question (안쪽 space.20)", "sentence", 17, 0, CONTENT_WIDTH - 40, 2, True, 40),
    Target(("daily.color", "daily.direction", "daily.number", "daily.focus_time"), "lucky-card explain (안쪽 space.12)",
           "ui-400", 13, -0.26, CONTENT_WIDTH - 24, 2, True, 36),
    Target(("daily.focus_reason",), "lucky-card explain 안 한 줄", "ui-400", 13, -0.26, CONTENT_WIDTH - 24, 1, False, 10),
    Target(("daily.tag_label",), "lucky-card tag 칩 값 (오늘 화면, 굵기 600, 좌우 12px, 아이콘 16 + 간격 6. diary tag-chip보다 좁음)",
           "ui-600", 13, -0.26, CONTENT_WIDTH - 24 - 16 - 6, 1, False, 10),
    Target(("calendar.day_level",), "day-character badge (좌우 10px)", "ui-500", 13, -0.26, CONTENT_WIDTH - 20, 1, False, 10),
    Target(("calendar.score_item",), "term-token label (좌우 4px)", "ui-500", 12, -0.24, CONTENT_WIDTH - 8, 1, False, 10),
    Target(("calendar.solar_term",), "day-cell lunar 줄 (칸 폭 44px, 굵게)", "ui-700", 10.5, -0.22, (CONTENT_WIDTH - 2 * 6) / 7, 1, False, 10),
    Target(("glossary.value_name",), "lucky-card chip 값 (칩이 한 줄에 혼자일 때, 좌우 12px, 아이콘 16 + 간격 6)", "ui-500", 13, -0.26, CONTENT_WIDTH - 24 - 16 - 6, 1, False, 10),
    # ui 이름 자리와 새 content 슬롯 (#131, spec-followups spec §5.2). writing 초안이 없어 계산값이 확정값
    Target(("welcome.cta.start", "welcome.cta.signin", "preview.cta.save", "preview.cta.restart", "consent.cta.agree",
            "notify-ask.cta.allow", "notify-ask.cta.skip", "force-update.cta.store", "account-delete.cta.delete",
            "today.guide.cta", "evidence-sheet.lock.cta", "diary-list.pick-date.cta",
            "day-sheet.event.add", "day-sheet.diary.write-cta", "share-preview.cta.share",
            # D77 IA 자리 event-edit.save.cta·delete.cta·diary-edit.save.cta (writing W33: ui 슬롯에 ia로 담음)
            "ui.event-edit.save", "ui.event-edit.delete", "ui.diary-edit.save",
            # D82 account-merge 아래 버튼 (#389)
            "account-merge.cta.merge",
            # D85 계정 합치기 입구 (#480). 합치지 않기 버튼은 IA에서 빠짐(PR #511)
            "login-methods.merge.cta"),
           "primary-button (좌우 space.20)", "ui-600", 14, -0.28, CONTENT_WIDTH - 2 * 20, 1, False, None),
    # destructive 제목 앞 mark.caution: 16 × 0.707 = 11.3 + 띄어쓰기 3.5 → 15
    Target(DIALOG_SLOTS, "dialog title (확인 창 슬롯의 제목 키, 바깥 28·안쪽 24, destructive 앞 mark.caution 15)",
           "ui-600", 16, -0.32, SCREEN_WIDTH - 2 * 28 - 2 * 24 - 15, 2, False, None),
    Target(("ui.action.button",) + DIALOG_SLOTS, "dialog 버튼 두 개 중 하나 (확인 창 슬롯은 버튼 키, 버튼 사이 8)",
           "ui-600", 14, -0.28, (SCREEN_WIDTH - 2 * 28 - 2 * 24 - 8) / 2, 1, False, None),
    # 2.7.0: 로고는 왼쪽 16에 고정하고 글자는 가운데라 양쪽에 로고 자리(16 + 20 + 8)를 비움 (#389)
    Target(("ui.login.provider",), "social-login-button 글자 (가운데 정렬, 양쪽 16 + 로고 20 + 간격 8)",
           "ui-600", 14, -0.28, CONTENT_WIDTH - 2 * (16 + 20 + 8), 1, False, None),
    # D77 IA 자리 login.error.body = ui.login.error, event-edit.save.failed·diary-view.deleted.toast (W33)
    Target(("ui.error.client", "ui.error.code", "ui.login.error", "ui.app.trace", "evidence-sheet.unlock.failed",
            "diary-edit.saved.tags", "ui.event-edit.save-failed", "ui.diary-view.deleted"),
           "toast (좌우 16, 앞 아이콘 16 + 간격 16)",
           "ui-400", 14, -0.28, CONTENT_WIDTH - 2 * 16 - 16 - 16, 2, True, None),
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
    # D77 IA 자리 event-edit.offline.notice (W33)
    Target(("ui.app.notice", "saju-chart.time-unknown.notice", "diary-edit.offline.notice", "ui.event-edit.offline"),
           "notice-banner (좌우 12, 아이콘 16 + 간격 8)", "ui-400", 13, -0.26, CONTENT_WIDTH - 2 * 12 - 16 - 8, 2, True, None),
    Target(("ui.picker.item",), "date-picker·time-picker 휠 칸 (본문 폭 3등분)",
           "ui-600", 16, -0.32, CONTENT_WIDTH / 3, 1, False, None),
    Target(("evidence-sheet.section.basis", "evidence-sheet.section.source", "evidence-sheet.section.personal",
            "saju-chart.yongsin.title"), "lock.veil 제목 (잠기면 앞에 자물쇠 14 + 간격 4)",
           "ui-500", 13, -0.26, CONTENT_WIDTH - 14 - 4, 1, False, None),
    # D77 IA 자리 today.evidence.link = ui.depth.evidence_link (W33)
    Target(("ui.depth.evidence_link", "birthplace.standard.link", "day-sheet.diary.open"),
           "depth-link 이름 (화살표 14 + 간격 2)",
           "ui-600", 14, -0.28, CONTENT_WIDTH - 14 - 2, 1, False, None),
    Target(("saju-chart.yongsin.open",), "sentence-block locked 열기 (흐린 줄과 같은 줄 오른쪽 절반, 화살표 14 + 간격 2)",
           "ui-600", 14, -0.28, CONTENT_WIDTH / 2 - 14 - 2, 1, False, None),
    Target(("ui.app.name",), "app-bar 제목 (좌우 16, 뒤로 44, 동작 44 × 2)",
           "ui-600", 16, -0.32, SCREEN_WIDTH - 2 * 16 - 44 - 2 * 44, 1, False, None),
    Target(("onboard-time.hour.confirm",), "time-picker 시진 확인 줄", "ui-400", 13, -0.26, CONTENT_WIDTH, 1, False, None),
    Target(("character.reason",), "day-character 이유 줄 (마지막 줄 끝 depth-link inline-end `ui.depth.evidence_link` 원고 폭을 뺌)",
           "ui-400", 13, -0.26, CONTENT_WIDTH, 2, True, None, trailing_link="ui.depth.evidence_link"),
    Target(("ui.guide.card",), "guide-question-card 머리글 (안쪽 space.20)", "ui-500", 12, -0.24, CONTENT_WIDTH - 2 * 20, 1, False, None),
    Target(("settings.ad-free.label",), "settings-row 이름 (좌우 16, 화살표 16, 남은 기간을 담은 키 포함)",
           "ui-400", 14, -0.28, CONTENT_WIDTH - 2 * 16 - 16, 1, False, None),
    # D77 IA 자리 evidence-sheet.sheet.title = ui.evidence.title (W33)
    Target(("ui.evidence.title",), "evidence-sheet 제목 (sheet 안쪽 space.20)", "ui-600", 20, -0.4, CONTENT_WIDTH, 1, False, None),
    Target(("chart.ilgan_head",), "my-saju 일간 소개 첫 문장 sentence-block card (today 총운과 같은 칸)",
           "sentence", 17, 0, CONTENT_WIDTH, 2, True, None),
    # D82·D83 로그인 수단·계정 합치기 (#389, spec 2026-10-22 §6)
    Target(("login-methods.intro.body",), "login-methods 첫머리 (본문 폭)", "ui-400", 14, -0.28, CONTENT_WIDTH, 3, True, None),
    Target(("login-methods.last.notice",), "login-methods 마지막 수단 안내 (본문 폭)", "ui-400", 13, -0.26, CONTENT_WIDTH, 2, True, None),
    Target(("ui.login-methods.row",), "social-login-button connected 이름·연결됨 (좌우 16, 로고 20 + 간격 8, check 14 + 간격 4, 둘이 나눔)",
           "ui-600", 14, -0.28, (CONTENT_WIDTH - 2 * 16 - 20 - 8 - 14 - 4) / 2, 1, False, None),
    Target(("ui.settings.login-methods",), "settings-row 이름 (좌우 16, 화살표 16)", "ui-400", 14, -0.28, CONTENT_WIDTH - 2 * 16 - 16, 1, False, None),
    Target(("account-merge.title.head",), "account-merge 제목 (본문 폭)", "ui-600", 20, -0.4, CONTENT_WIDTH, 2, False, None),
    Target(("account-merge.title.body",), "account-merge 설명 (본문 폭)", "ui-400", 14, -0.28, CONTENT_WIDTH, 4, True, None),
    Target(("account-merge.choice.label",), "account-choice 묶음 이름 (본문 폭)", "ui-500", 12, -0.24, CONTENT_WIDTH, 1, False, None),
    Target(("account-merge.overlap.notice",), "account-merge 겹치는 날 안내 (아이콘 16 + 간격 8)",
           "ui-400", 13, -0.26, CONTENT_WIDTH - 16 - 8, 2, True, None),
    Target(("ui.account-merge.choice",), "account-choice 현재·가져올 계정 알약 (카드 안 256의 절반, 좌우 8 + 테두리 1)",
           "ui-500", 11, -0.22, (CONTENT_WIDTH - 2 * 16 - 32) / 2 - 2 * 8 - 2, 1, False, None),
    Target(("ui.account-merge.saju",), "account-choice 사주 요약 (카드 안 폭, 고름 표시 22 + 간격 10)",
           "ui-400", 13, -0.26, CONTENT_WIDTH - 2 * 16 - 22 - 10, 1, False, None),
    # D85 계정 합치기 두 단계·D88 구매 내역 (#480·#483·#494, spec 2026-10-23 §8)
    Target(("account-merge.auth.body",), "account-merge 인증 단계 안내 (본문 폭)", "ui-400", 14, -0.28, CONTENT_WIDTH, 3, True, None),
    # 값 자리 56: 고정폭 숫자 값("30일")보다 넉넉한 폭
    Target(("ui.account-merge.summary",), "account-merge 가져올 기록·구매 상자 줄 이름 (상자 안쪽 16, 값 자리 56)",
           "ui-400", 14, -0.28, CONTENT_WIDTH - 2 * 16 - 56, 1, False, None),
    Target(("purchase-history.missing.notice",), "purchase-history 문의 안내 (본문 폭, 좌우 4)",
           "ui-400", 13, -0.26, CONTENT_WIDTH - 2 * 4, 2, True, None),
    # 상태 꼬리표 최대 폭 80(purchase-row status.maxWidth)에서 좌우 8
    Target(("ui.purchase.status",), "purchase-row 상태 낱말 (꼬리표 최대 80, 좌우 8)", "ui-500", 12, -0.24, 80 - 2 * 8, 1, False, None),
    # meta는 구매일 줄과 사용 기간 줄 두 줄이고(W44, 결정 V47), 줄마다 상품 이름 아래 카드 안 폭 전체를 씀(안쪽 16 양쪽)
    Target(("ui.purchase.meta",), "purchase-row 구매일 줄, 사용 기간 줄 (키마다 한 줄, 카드 안쪽 16)",
           "ui-400", 13, -0.26, CONTENT_WIDTH - 2 * 16, 1, False, None),
    # offer-card 안 버튼: 카드 안쪽 20 안에서 primary-button 좌우 20 (#548, 구매 내역 버튼은 화면 폭 행에서 옮김)
    Target(("ad-free.buy.cta", "ad-free.history.cta"), "offer-card 안 primary-button (카드 안쪽 20, 버튼 좌우 20)",
           "ui-600", 14, -0.28, CONTENT_WIDTH - 2 * 20 - 2 * 20, 1, False, None),
    Target(("ad-free.offer.period",), "offer-card 기간 고지 (카드 안쪽 20)", "ui-400", 13, -0.26, CONTENT_WIDTH - 2 * 20, 1, False, None),
    # 묶음 카드 위 안내 문장 (#354 ③, 결정 V50)
    Target(("profile-edit.recalc.notice",), "settings-row groupNote (묶음 카드 위, 좌우 16)",
           "ui-500", 12, -0.24, CONTENT_WIDTH - 2 * 16, 2, True, None),
)

# 한 슬롯 안에서 다른 칸에 놓이는 키: (슬롯, 키) → 그 키만 재는 칸. "키별 상한" 표에 언어마다 한 행 (#475)
KEY_TARGETS = {
    ("ui.login.provider", "loginLineLabel"): Target(
        ("ui.login.provider",), "LINE 버튼 글자 (공식 자산 구분선 비율 198px, 결정 V46)", "ui-600", 14, -0.28, 198, 1, False, None),
}

# 행 값과 다른 상한을 받는 키: (슬롯, 키, 언어) → (값을 빌려 올 언어, 이유) (#446)
KEY_LIMITS = {
    ("ui.login.provider", "loginKakaoLabel", "ja"): (
        "en", "ja 원고가 영문(카카오 가이드에 일본어 문구 없음, #143). 실측 106px로 칸 232px에 들어감"),
}

# 레이아웃이 줄 수를 막지 않는 자리(스크롤 본문). writing 초안을 그대로 둡니다.
UNBOUNDED = {
    "chart.yongsin_method": ("saju-chart 본문 sentence-block body", 60),
    # W21로 content 슬롯 settings.calculation_basis가 ui 슬롯 calc-basis.longitude.body로 옮겨 감. 값은 그대로
    "calc-basis.longitude.body": ("calc-basis 본문 sentence-block body", 120),
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
    "ui.guide.a11y": SCREEN_READER_ONLY,
    "login.discard.notice": "확인 창 본문(창이 늘어남)",
    # D79로 기본 깊이 설정(segmented)이 빠져 풀이 시트의 접근성 라벨로만 남음(#318)
    "ui.depth.explain": SCREEN_READER_ONLY,
    # D82 확인 창(dialog notice)으로 보이는 실패 안내 (#389)
    "login-methods.error.body": "확인 창 본문(창이 늘어남)",
    "ui.account-merge.error": "확인 창 본문(창이 늘어남)",
    # D85 확인 창(dialog notice)으로 보이는 안내 (#480)
    "login-methods.in-use.body": "확인 창 본문(창이 늘어남)",
    "account-merge.not-other.body": "확인 창 본문(창이 늘어남)",
    # D88 ② 구매 줄 상품 이름: 줄바꿈하고, 키가 없으면 스토어 이름을 쓰므로 길이를 막지 않음 (#494)
    "ui.purchase.product": "purchase-row 상품 이름(말줄임 없이 줄바꿈, 스토어 이름 대체)",
    # 숫자가 섞인 고정 형식이라 글자 수가 폭을 대신하지 못함. 폭 44px로 확인: ko 윤12.1 26.4px (#260)
    "ui.day-cell.lunar": "day-cell 윤달 표지(형식 고정, 글자 수 대신 칸 폭 44px로 확인)",
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


def round_number(path: pathlib.Path) -> int:
    return int(re.search(r"-round-R(\d+)\.md$", path.name).group(1))


def corpus_sentences(rounds_dir: pathlib.Path = ROUNDS_DIR, last_round: int | None = None) -> list[str]:
    """라운드 기록 표의 선택지 문장(한글 문장만, "다 별로" 제외, 라운드 순서로 처음 나온 것만).

    last_round를 주면 그 라운드까지만 읽습니다."""
    sentences: list[str] = []
    row = re.compile(r"^\|\s*\d+\s*\|\s*(.+?)\s*\|")
    paths = sorted(rounds_dir.glob("*-round-R*.md"), key=round_number)
    for path in paths:
        if last_round is not None and round_number(path) > last_round:
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            match = row.match(line)
            if not match:
                continue
            text = match.group(1).replace("**", "").strip()
            if (re.search(r"[가-힣]", text) and re.search(r"[.?!]$", text) and "다 별로" not in text
                    and text not in sentences):
                sentences.append(text)
    return sentences


def link_texts(slots: set[str], content_dir: pathlib.Path = UI_TEXT_DIR) -> dict[str, dict[str, str]]:
    """링크 슬롯 → 언어 → 원고(첫 키). writing ui 원고의 한 줄 형식 `- {slot: …, key: …, text: "…"}`을 읽습니다."""
    texts: dict[str, dict[str, str]] = {slot: {} for slot in slots}
    row = re.compile(r'^- \{slot: ([^,]+), key: [^,]+, text: "(.*)"\}$')
    for language in LANGUAGES:
        for line in (content_dir / language / "ui.yaml").read_text(encoding="utf-8").splitlines():
            match = row.match(line)
            if match and match.group(1) in texts:
                texts[match.group(1)].setdefault(language, match.group(2))
    return texts


def link_width(text: str, language: str, advances: dict[int, float]) -> float:
    """문장 끝 링크 하나의 폭: 앞 U+00A0 + 링크 이름 + 화살표. ja는 UI 글꼴을 전각 1em·자간 0으로 봅니다."""
    space = text_width("\u00a0", advances, LINK_SIZE, LINK_TRACKING)
    name = len(text) * LINK_SIZE if language == "ja" else text_width(text, advances, LINK_SIZE, LINK_TRACKING)
    return space + name + LINK_ARROW_PX


def trailing_chars(width_px: float, line_chars: int, line_width: float) -> int:
    """마지막 줄에서 뺄 글자 수: 링크 폭을 그 줄의 평균 글자 폭으로 나눠 올림."""
    return math.ceil(width_px * line_chars / line_width)


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
    """앞에 붙는 글자와 오른쪽 값 자리를 뺀, 이름이 쓸 수 있는 폭."""
    width = target.width - text_width(target.prefix, advances, target.size, target.tracking)
    if target.reserve_slot:
        width -= finals[target.reserve_slot] * (advances[ord("가")] * target.size + target.tracking)
    return round(width, 1)


def measure(fonts: Fonts, words: list[str], targets: tuple[Target, ...] = TARGETS,
            links: dict[str, dict[str, str]] | None = None) -> list[Result]:
    """targets 순서대로 잽니다. reserve_slot은 앞에서 잰 슬롯이어야 하고, trailing_link는 links에 원고가 있어야 합니다."""
    results = []
    finals: dict[str, int] = {}
    for target in targets:
        ko_advances = fonts.ko(target.font)
        target = replace(target, width=free_width(target, ko_advances, finals), prefix="", reserve_slot=None)
        if target.sentence:
            ko_line = ko_line_chars(words, ko_advances, target.size, target.tracking, target.width)
        else:
            ko_line = ko_name_chars(ko_advances, target.size, target.tracking, target.width)
        lines = {
            "ko": ko_line,
            "ja": ja_line_chars(fonts.ja(target.font), target.size, target.width),
            "en": en_line_chars(ko_advances, target.size, target.tracking, target.width),
        }
        counts = {language: line * target.lines for language, line in lines.items()}
        if target.trailing_link:
            link_advances = fonts.ko(LINK_FONT)
            texts = links[target.trailing_link]
            for language in LANGUAGES:
                width_px = link_width(texts[language], language, link_advances)
                counts[language] -= trailing_chars(width_px, lines[language], target.width)
        result = Result(target, counts["ko"], counts["ja"], counts["en"])
        finals.update({slot: result.final("ko") for slot in target.slots})
        results.append(result)
    return results


def render_table(results: list[Result], key_results: list[tuple[tuple[str, str], Result]] = ()) -> str:
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
    finals = {(slot, language): result.final(language)
              for result in results for slot in result.target.slots for language in LANGUAGES}
    lines += ["", "키별 상한 (행 값과 다른 키, writing `key_max_length`):", "",
              "| 언어 | 슬롯 | 키 | 상한 | 이유 |", "| --- | --- | --- | --- | --- |"]
    for (slot, key, language), (source, reason) in KEY_LIMITS.items():
        limit = finals.get((slot, source), "-")
        # 언어 칸을 앞에 둠: writing 파서가 "| `"로 시작하는 줄을 슬롯 행으로 읽기 때문
        lines.append(f"| {language} | `{slot}` | `{key}` | **{limit}** | {source} 상한을 씀: {reason} |")
    for (slot, key), result in key_results:
        for language in LANGUAGES:
            lines.append(f"| {language} | `{slot}` | `{key}` | **{result.final(language)}** | 따로 잼: {result.target.where} |")
    lines += ["", "상한을 두지 않는 슬롯 (레이아웃이 길이를 막지 않음):", "", "| 슬롯 | 상한 없음 이유 |", "| --- | --- |"]
    lines += [f"| `{slot}` | {reason} |" for slot, reason in NO_LIMIT.items()]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--font-dir", type=pathlib.Path, required=True)
    args = parser.parse_args(argv)
    words = " ".join(corpus_sentences(last_round=MEASURED_LAST_ROUND)).split()
    links = link_texts({target.trailing_link for target in TARGETS if target.trailing_link})
    fonts = Fonts(args.font_dir)
    key_results = list(zip(KEY_TARGETS, measure(fonts, words, tuple(KEY_TARGETS.values()))))
    sys.stdout.write(render_table(measure(fonts, words, links=links), key_results))
    return 0


if __name__ == "__main__":
    sys.exit(main())
