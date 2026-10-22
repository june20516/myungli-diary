# 슬롯별 글자 수 상한

writing 슬롯 명세의 `max_length`에 넣을 값입니다(Issue #54, #131). 굵은 세 열이 확정값입니다.

* 근거: [근거 잠금·글자 수 spec](specs/2026-10-11-depth-lock-lengths-design.md) §5, [구현 대응·글자 수 spec](specs/2026-10-15-spec-followups-design.md) §5, 결정 V27·V33
* 만드는 도구: `tools/lengths.py`. 이 표는 도구 출력을 그대로 붙인 것이고, 테스트가 둘이 같은지 확인합니다(글꼴이 있을 때).
* 글자 수는 호칭과 매개변수 값이 들어간 **최종 문장 기준**, 띄어쓰기와 문장부호를 포함합니다.

## 상한

| 슬롯 | 놓이는 칸 | 칸 폭 | 줄 | ko 초안 | ko 계산 | **ko** | **ja** | **en** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `daily.fortune.head`<br>`daily.fortune.tag` | today sentence-block card (상자 없이 본문 폭, 시안 design-v2-today) | 320px | 2 | 32 | 42 | **32** | **32** | **57** |
| `daily.guide` | guide-question-card question (안쪽 space.20) | 280px | 2 | 40 | 36 | **36** | **30** | **70** |
| `daily.color`<br>`daily.direction`<br>`daily.number`<br>`daily.focus_time` | lucky-card explain (안쪽 space.12) | 296px | 2 | 36 | 58 | **36** | **36** | **64** |
| `daily.focus_reason` | lucky-card explain 안 한 줄 | 296px | 1 | 10 | 26 | **10** | **10** | **18** |
| `daily.tag_label` | lucky-card tag 칩 값 (오늘 화면, 굵기 600, 좌우 12px, 아이콘 16 + 간격 6. diary tag-chip보다 좁음) | 274px | 1 | 10 | 24 | **10** | **10** | **18** |
| `calendar.day_level` | day-character badge (좌우 10px) | 300px | 1 | 10 | 27 | **10** | **10** | **18** |
| `calendar.score_item` | term-token label (좌우 4px) | 312px | 1 | 10 | 30 | **10** | **10** | **18** |
| `calendar.solar_term` | day-cell lunar 줄 (칸 폭 44px, 굵게) | 44px | 1 | 10 | 4 | **4** | **3** | **6** |
| `glossary.value_name` | lucky-card chip 값 (칩이 한 줄에 혼자일 때, 좌우 12px, 아이콘 16 + 간격 6) | 274px | 1 | 10 | 24 | **10** | **10** | **18** |
| `welcome.cta.start`<br>`welcome.cta.signin`<br>`preview.cta.save`<br>`preview.cta.restart`<br>`consent.cta.agree`<br>`notify-ask.cta.allow`<br>`notify-ask.cta.skip`<br>`force-update.cta.store`<br>`account-delete.cta.delete`<br>`today.guide.cta`<br>`evidence-sheet.lock.cta`<br>`ad-free.restore.cta`<br>`diary-list.pick-date.cta`<br>`day-sheet.event.add`<br>`day-sheet.diary.write-cta`<br>`share-preview.cta.share`<br>`ui.event-edit.save`<br>`ui.event-edit.delete`<br>`ui.diary-edit.save`<br>`account-merge.cta.merge`<br>`account-merge.cta.cancel` | primary-button (좌우 space.20) | 280px | 1 | - | 23 | **23** | **19** | **42** |
| `diary-view.delete.confirm`<br>`event-edit.delete.confirm`<br>`account-delete.delete.confirm`<br>`settings.logout.confirm`<br>`preview.share.login-notice`<br>`profile-edit.recalc.confirm`<br>`login-methods.unlink.confirm`<br>`account-merge.merge.confirm` | dialog title (확인 창 슬롯의 제목 키, 바깥 28·안쪽 24, destructive 앞 mark.caution 15) | 241px | 2 | - | 34 | **34** | **28** | **60** |
| `ui.action.button`<br>`diary-view.delete.confirm`<br>`event-edit.delete.confirm`<br>`account-delete.delete.confirm`<br>`settings.logout.confirm`<br>`preview.share.login-notice`<br>`profile-edit.recalc.confirm`<br>`login-methods.unlink.confirm`<br>`account-merge.merge.confirm` | dialog 버튼 두 개 중 하나 (확인 창 슬롯은 버튼 키, 버튼 사이 8) | 124px | 1 | - | 10 | **10** | **7** | **16** |
| `ui.login.provider` | social-login-button 글자 (좌우 16, 로고 20 + 간격 8) | 260px | 1 | - | 21 | **21** | **17** | **38** |
| `ui.error.client`<br>`ui.error.code`<br>`ui.login.error`<br>`ui.app.trace`<br>`evidence-sheet.unlock.failed`<br>`diary-edit.saved.tags`<br>`ui.event-edit.save-failed`<br>`ui.diary-view.deleted` | toast (좌우 16, 앞 아이콘 16 + 간격 16) | 256px | 2 | - | 48 | **48** | **34** | **78** |
| `ui.nav.tab` | tab-bar 탭 라벨 (화면 폭 4등분) | 90px | 1 | - | 9 | **9** | **7** | **15** |
| `ui.birth.option` | segmented 두 칸 중 한 칸 (check-row inline 글자 포함) | 156px | 1 | - | 13 | **13** | **10** | **22** |
| `share-preview.ratio.label` | segmented 세 칸 중 한 칸 | 104px | 1 | - | 8 | **8** | **6** | **13** |
| `consent.required.label` | check-row card 동의 항목 (좌우 16, 상자 24 + 간격 12, 보기 40) | 212px | 2 | - | 34 | **34** | **28** | **64** |
| `onboard-call.input.hint`<br>`event-edit.title.hint`<br>`event-edit.memo.hint` | text-field 안내 (좌우 16, 지우기 20 + 간격 8) | 260px | 1 | - | 17 | **17** | **14** | **31** |
| `birthplace.search.hint` | city-search 검색칸 안내 (text-field에서 돋보기 20 + 간격 8) | 232px | 1 | - | 15 | **15** | **12** | **27** |
| `diary-edit.body.placeholder` | diary-editor 입력칸 안내 (좌우 16) | 288px | 2 | - | 42 | **42** | **36** | **82** |
| `ui.app.notice`<br>`saju-chart.time-unknown.notice`<br>`diary-edit.offline.notice`<br>`ui.event-edit.offline` | notice-banner (좌우 12, 아이콘 16 + 간격 8) | 272px | 2 | - | 52 | **52** | **38** | **90** |
| `ui.picker.item` | date-picker·time-picker 휠 칸 (본문 폭 3등분) | 106.7px | 1 | - | 7 | **7** | **5** | **12** |
| `evidence-sheet.section.basis`<br>`evidence-sheet.section.source`<br>`evidence-sheet.section.personal`<br>`saju-chart.yongsin.title` | lock.veil 제목 (잠기면 앞에 자물쇠 14 + 간격 4) | 302px | 1 | - | 27 | **27** | **22** | **50** |
| `ui.depth.evidence_link`<br>`birthplace.standard.link`<br>`day-sheet.diary.open` | depth-link 이름 (화살표 14 + 간격 2) | 304px | 1 | - | 25 | **25** | **20** | **45** |
| `saju-chart.yongsin.open` | sentence-block locked 열기 (흐린 줄과 같은 줄 오른쪽 절반, 화살표 14 + 간격 2) | 144px | 1 | - | 12 | **12** | **9** | **20** |
| `ui.app.name` | app-bar 제목 (좌우 16, 뒤로 44, 동작 44 × 2) | 196px | 1 | - | 14 | **14** | **11** | **24** |
| `onboard-time.hour.confirm` | time-picker 시진 확인 줄 | 320px | 1 | - | 29 | **29** | **23** | **54** |
| `character.reason` | day-character 이유 줄 (마지막 줄 끝 depth-link inline-end `ui.depth.evidence_link` 원고 폭을 뺌) | 320px | 2 | - | 57 | **57** | **39** | **90** |
| `ui.guide.card` | guide-question-card 머리글 (안쪽 space.20) | 280px | 1 | - | 27 | **27** | **22** | **50** |
| `settings.ad-free.label` | settings-row 이름 (좌우 16, 화살표 16, 남은 기간을 담은 키 포함) | 272px | 1 | - | 23 | **23** | **18** | **42** |
| `ui.evidence.title` | evidence-sheet 제목 (sheet 안쪽 space.20) | 320px | 1 | - | 18 | **18** | **15** | **33** |
| `chart.ilgan_head` | my-saju 일간 소개 첫 문장 sentence-block card (today 총운과 같은 칸) | 320px | 2 | - | 42 | **42** | **34** | **82** |
| `login-methods.intro.body` | login-methods 첫머리 (본문 폭) | 320px | 3 | - | 90 | **90** | **63** | **150** |
| `login-methods.last.notice` | login-methods 마지막 수단 안내 (본문 폭) | 320px | 2 | - | 64 | **64** | **46** | **108** |
| `ui.login-methods.row` | social-login-button connected 이름·연결됨 (좌우 16, 로고 20 + 간격 8, check 14 + 간격 4, 둘이 나눔) | 121px | 1 | - | 10 | **10** | **7** | **16** |
| `ui.settings.login-methods` | settings-row 이름 (좌우 16, 화살표 16) | 272px | 1 | - | 23 | **23** | **18** | **42** |
| `account-merge.title.head` | account-merge 제목 (본문 폭) | 320px | 2 | - | 36 | **36** | **30** | **66** |
| `account-merge.title.body` | account-merge 설명 (본문 폭) | 320px | 4 | - | 120 | **120** | **84** | **200** |
| `account-merge.choice.label` | account-choice 묶음 이름 (본문 폭) | 320px | 1 | - | 31 | **31** | **25** | **58** |
| `account-merge.overlap.notice` | account-merge 겹치는 날 안내 (아이콘 16 + 간격 8) | 296px | 2 | - | 58 | **58** | **42** | **100** |
| `ui.account-merge.choice` | account-choice 현재 계정 알약 (카드 안 256의 절반, 좌우 8 + 테두리 1) | 110px | 1 | - | 11 | **11** | **9** | **19** |
| `ui.account-merge.saju` | account-choice 사주 요약 (카드 안 폭, 고름 표시 22 + 간격 10) | 256px | 1 | - | 23 | **23** | **18** | **43** |
| `ui.day-cell.lunar` | day-cell lunar 줄 윤달 초하루 (칸 폭 44px, type.caption.sm 500) | 44px | 1 | - | 4 | **4** | **3** | **6** |
| `chart.yongsin_method` | saju-chart 본문 sentence-block body | 본문 | 제한 없음 | 60 | - | **60** | **60** | **108** |
| `calc-basis.longitude.body` | calc-basis 본문 sentence-block body | 본문 | 제한 없음 | 120 | - | **120** | **120** | **216** |

상한을 두지 않는 슬롯 (레이아웃이 길이를 막지 않음):

| 슬롯 | 상한 없음 이유 |
| --- | --- |
| `ui.nav.a11y` | 스크린리더 전용(화면에 보이지 않음) |
| `ui.a11y.label` | 스크린리더 전용(화면에 보이지 않음) |
| `ui.picker.label` | 스크린리더 전용(화면에 보이지 않음) |
| `evidence-sheet.a11y.locked` | 스크린리더 전용(화면에 보이지 않음) |
| `evidence-sheet.a11y.checking` | 스크린리더 전용(화면에 보이지 않음) |
| `evidence-sheet.a11y.unlocked` | 스크린리더 전용(화면에 보이지 않음) |
| `today.reaction.label` | 스크린리더 전용(화면에 보이지 않음) |
| `chart.ilgan_body` | 스크롤 본문 |
| `chart.yongsin_summary` | 스크롤 본문 |
| `term.meaning` | 스크롤 본문(풀이 시트·태그 모아보기) |
| `ui.app.bootstrap` | 스크롤 본문(error-state 문장) |
| `system.apple_return` | app 밖 화면(server 웹 페이지) |
| `ui.guide.a11y` | 스크린리더 전용(화면에 보이지 않음) |
| `login.discard.notice` | 확인 창 본문(창이 늘어남) |
| `ui.depth.explain` | 스크린리더 전용(화면에 보이지 않음) |
| `login-methods.error.body` | 확인 창 본문(창이 늘어남) |
| `ui.account-merge.error` | 확인 창 본문(창이 늘어남) |

* **ko 계산**: 레이아웃에 들어가는 글자 수입니다. 확정값은 writing 초안과 이 값 중 작은 값입니다(ja 초안 = ko, en 초안 = ko × 1.8). 초안이 `-`인 칸(#131에서 더한 칸)은 계산값이 곧 확정값입니다.
* **IA 자리와 슬롯 이름:** 표는 writing 슬롯 id로 적습니다. D77로 IA에 더한 자리 중 writing이 기존 `ui.*` 슬롯에 `ia`로 담은 것은 그 슬롯 행을 봅니다(W33): `today.evidence.link` = `ui.depth.evidence_link`, `evidence-sheet.sheet.title` = `ui.evidence.title`, `login.error.body` = `ui.login.error`, `event-edit.save.cta`·`delete.cta` = `ui.event-edit.save`·`delete`, `event-edit.offline.notice` = `ui.event-edit.offline`, `event-edit.save.failed` = `ui.event-edit.save-failed`, `diary-edit.save.cta` = `ui.diary-edit.save`, `diary-view.deleted.toast` = `ui.diary-view.deleted`. 옛 content 슬롯 `settings.calculation_basis`는 `calc-basis.longitude.body`로 옮겨 갔습니다(W21). 기본 깊이 설정(segmented 세 칸, settings-row 값)은 D79로 빠져 `ui.depth.surface`·`evidence`·`default_label` 행을 지웠고, `ui.depth.explain`은 풀이 시트의 접근성 라벨로만 남아 상한이 없습니다(#318).
* **여러 자리에 쓰는 슬롯은 가장 좁은 자리의 값**을 받습니다. 예를 들어 `ui.action.button`은 `primary-button`과 `dialog` 버튼에 쓰이므로 dialog 버튼 폭(124px)으로 잽니다.
* **확인 창 슬롯**(`diary-view.delete.confirm` 등 8개)은 한 슬롯에 제목·본문·버튼 키가 함께 있어 두 칸에 나옵니다. 제목 키는 "dialog title" 행, 버튼 키는 "dialog 버튼" 행의 값이고, 본문 키는 창이 늘어나므로 상한이 없습니다. writing은 슬롯을 나누지 않고 제목 키 상한을 `key_max_length`로 담았습니다(W26, #191).
* `character.reason`은 마지막 줄 끝에 `depth-link` `inline-end`(앞 U+00A0 + `ui.depth.evidence_link` 원고 + 화살표 16)가 붙으므로, 마지막 줄에서 그 폭에 해당하는 글자 수를 한 번 뺐습니다. 링크 폭은 언어별 원고(ko "근거 보기", ja "根拠を見る", en "See the basis")로 재므로 링크 문구가 바뀌면 이 값도 다시 계산합니다.
* 칸 앞에 아이콘이 붙는 상태가 있으면 그 폭을 뺐습니다: 잠긴 구역 제목(자물쇠 14 + 간격 4), destructive 확인 창 제목(`mark.caution` 11.3 + 띄어쓰기 3.5 → 15), toast(아이콘 16 + 간격 16).
* **2.7.0(#389·#260):** 로그인 수단·계정 합치기 11행과 윤달 표지 1행을 더했습니다. 기존 확정값은 그대로입니다. `login-methods.error.body`·`ui.account-merge.error`는 `dialog` `notice`의 본문이라 상한이 없습니다. `ui.account-merge.choice`는 가장 좁은 "현재 계정" 알약(110px)으로, 사주 요약은 따로 나눈 `ui.account-merge.saju`(256px)로 잽니다. `ui.day-cell.lunar` 4자는 한글로 채운 값이라, 숫자가 섞인 표지(ko "윤12.1" 5자)는 숫자 폭이 좁아 44px 칸에 들어갑니다.
* 초안보다 줄어든 곳: `daily.guide`(질문 카드 안쪽 여백), `calendar.solar_term`(날짜 칸 44px).
* `calendar.solar_term` en 6자: 영어 절기 이름("Start of Spring")은 날짜 칸에 들어가지 않습니다. writing이 6자 이하 줄임 표기를 정했습니다(`S.Cold`, `Sp.Eq` 등). 같은 칸 스타일(Pretendard Bold 10.5px)로 재면 가장 넓은 `Summer`가 40.1px라 44px 칸에 들어갑니다.

## 상한 없음

"상한을 두지 않는 슬롯" 표의 슬롯은 레이아웃이 길이를 막지 않으므로 design이 상한을 정하지 않습니다(스크린리더 전용, 스크롤 본문, 확인 창 본문, app 밖 화면). 슬롯 명세에는 상한 값 `unbounded`로 적혀 있습니다(W26, #191). 편집상의 길이 규칙이 필요하면 writing이 정합니다.

#131이 묻지 않은 문장형 ui 슬롯(질문 제목 `*.question.head`, 설명 `*.why.body`, 잠금 안내 `evidence-sheet.lock.*` 등)은 아직 계산하지 않았습니다. 이름형 중에서는 다음 셋을 계산하지 않았습니다. 필요하면 writing이 다시 요청합니다.

* `diary-edit.draft.status`: app-bar 제목과 나눠 쓰는 폭을 명세가 정하지 않았습니다.
* `ad-free.offer.price`, `ad-free.status.remaining`: 가격·날짜 매개변수의 길이가 통화·로캘마다 달라 이름 자리 계산이 맞지 않습니다.

## 값의 성격

* **이름 자리(칩·배지·segmented·날짜 칸·설정 이름·버튼·입력칸 안내·제목 등)**: 띄어쓰기 없는 한글로 칸을 채운 가장 넓은 경우입니다. 한 줄 칸은 상한 안이면 늘 한 줄에 들어갑니다. 두 줄 이름 칸(확인 창 제목, 동의 항목)은 한 줄 값 × 2라서, 띄어쓰기가 있는 문구는 어절 단위로 감기며 세 줄이 될 수 있습니다. 두 칸 모두 높이가 늘어나므로 잘리지는 않습니다.
* **문장 자리(2줄: 총운·가이드 질문·행운 설명)**: 실제 원고로 잰 **경험값**입니다. 어절 단위 줄바꿈은 문장마다 줄 끝 빈 자리가 달라서, 어절이 길게 몰린 문장은 상한 안이어도 한 줄을 더 쓸 수 있습니다. 문장 칸은 글을 자르지 않고 줄이 늘어나므로 깨지지는 않습니다. 줄 수를 꼭 지켜야 하는 문장은 화면에서 확인합니다.
* **en**: 평균 글자 폭과 평균 단어 길이로 잰 추정값입니다. 영어 원고가 생기면 ko처럼 원고로 다시 잽니다.
* 공유 이미지(`share-image`, 1080px 캔버스)는 명세에 안쪽 여백이 없어 계산하지 않았습니다. `feed`는 문장 2줄이므로, 캔버스가 화면 비율대로 커진다면 총운 32자가 그대로 들어갑니다.

## 계산 방법

* 기준 화면 폭 360px − 화면 좌우 여백 `space.20` × 2 = 본문 폭 320px. 칸 폭은 컴포넌트 명세의 안쪽 여백을 뺀 값입니다. 오늘 화면 문장은 상자 없이 본문 폭에 놓입니다(채택 시안 `design-v2-today`).
* 줄 수: 큰 문장(card) 2줄, 행운 설명 상자·toast·안내 띠·일기 안내·이유 줄·확인 창 제목·동의 항목 2줄, 이름·칩·배지·segmented·날짜 칸·버튼 1줄, 스크롤 본문은 제한 없음.
* ko 문장 자리: writing 라운드 R1~R8 원고 문장(중복을 뺀 49개)을 어절 단위(keep-all)로 칸에 채우고, 꽉 찬 줄 글자 수의 하위 10%를 한 줄로 봅니다. 표본이 작아 원고가 바뀌면 한두 글자 움직일 수 있어, R9 뒤 라운드는 측정에 넣지 않습니다(`lengths.py` `MEASURED_LAST_ROUND`, #252). 확정값은 라운드가 늘어도 움직이지 않습니다.
* ko 이름 자리: 띄어쓰기 없는 한글로 한 줄을 채운 글자 수입니다. 앞에 붙는 글자(태그 칩 `#`)는 실제 폭을 빼고, 같은 줄의 값 자리(설정 줄 오른쪽 단계 이름)는 그 슬롯의 확정 글자 수만큼 뺍니다. 문장 끝에 붙는 링크(이유 줄)는 언어별 링크 원고 폭을 마지막 줄에서 한 번만 뺍니다.
* ja: 글자 단위 줄바꿈 + 금칙 처리, 줄마다 한 글자 여유, 자간 0. 문장 글꼴은 Zen Maru Gothic 폭, UI 글꼴은 전각 1em(실제 Pretendard 가나보다 넓게 잡은 보수값)입니다.
* en: 라틴 소문자 폭의 영어 글자 빈도 가중 평균, 줄마다 평균 단어(4.7자 + 띄어쓰기)의 절반을 줄바꿈 손실로 뺍니다.

## 용어 토큰 칩

토큰 하나에 좌우 3px씩 6px가 늘어납니다. writing 규칙상 토큰은 한 화면 2개까지(`limit.L6`), 한 문장에 모으므로(`limit.L7`) 한 문장에서 최대 12px입니다. card 글자 한 자(15.5px)보다 작지만, 줄 끝이 빠듯한 문장에서는 마지막 어절 하나를 다음 줄로 밀 수 있습니다. 그 영향은 위 "문장 자리는 경험값"이 이미 안고 있는 줄 끝 변동과 같은 크기라서 **토큰이 든 문장의 상한을 따로 두지 않습니다.** 토큰이 든 문장이 줄 수를 자주 넘기면 그때 토큰 문장 상한을 한 글자 낮춥니다.

## 다시 계산하기

측정 글꼴(고운돋움, Zen Maru Gothic, Pretendard 1.3.9 네 굵기, 모두 SIL OFL 1.1)은 저장소에 넣지 않습니다. 받는 주소(commit·버전 고정)와 sha256은 [`tools/fonts.py`](tools/fonts.py)가 기준이고, 저장소 루트에서 받은 뒤 다시 잽니다.

```
python3 docs/identity/design/tools/fonts.py --font-dir .suberpowers/fonts
uv run --with fonttools==4.54.1 python docs/identity/design/tools/lengths.py --font-dir .suberpowers/fonts
```

글꼴이 없으면 로컬에서는 표 비교 테스트가 skip됩니다. CI는 글꼴을 받아 쓰고(`DESIGN_FONTS_REQUIRED=1`), 글꼴이 없거나 checksum이 다르면 skip하지 않고 실패합니다(#362).
