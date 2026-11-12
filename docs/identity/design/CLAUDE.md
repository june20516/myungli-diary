# design — 디자인 시스템

이 디렉터리에서 시작한 세션은 **design 세션**입니다. 루트 [`CLAUDE.md`](../../../CLAUDE.md)와 [`docs/workflow.md`](../../workflow.md)의 공통 규약을 함께 따릅니다. 기준 문서는 [`docs/identity/README.md`](../README.md)(브랜드 기반)입니다.

## 범위
명리일기의 시각 정체성, 디자인 토큰, 컴포넌트 명세를 만듭니다. 구현(Flutter)은 app이 합니다. 상세는 [브랜드 기반 spec §7·§9](../../specs/2026-10-10-brand-foundation-design.md)에 있습니다.

| 산출물 | 받는 쪽 | 마일스톤 |
| --- | --- | --- |
| 시각 정체성: 로고 방향, 그라데이션 규칙, 오행 팔레트, 타이포 | 모두 | V0 |
| 디자인 토큰 (`tokens/`, 데이터 파일) | app (Dart 코드 생성) | V1 freeze |
| 캘린더 길흉 표시 규칙 (엔진 spec §8 `LuckLevel` 3단계, 루트 미결에서 이관). 점이 아니라 날짜 칸 채우기(결정 V10) | app | V1 |
| 컴포넌트 명세 (`components/`): IA 컴포넌트 + 상호작용 패턴·요소 | app | V2 |

* 비공개 기록 `background/06-design-system.md`(D74)는 V0의 입력이었습니다. V0 결과가 정체성 기준으로 06을 대체합니다.
* 그라데이션은 조건부 선택입니다(README "시각 방향"). 화면 바탕 그라데이션은 `gradient.today` 토큰 하나로 묶어, 리뉴얼할 때 그 토큰만 바꾸면 되게 합니다. 열린 근거 표시는 따로 `gradient.unlocked`(결정 V111, 2026-11-10)를 씁니다.
* 사용자는 제품 작업을 컴포넌트부터 설계하기를 원합니다. app의 UI 구현은 V2 뒤에 시작합니다.

## 고칠 수 있는 곳
`docs/identity/design/`, GitHub Issues(요청·보고 작성, `gh issue list --label to:design`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| 브랜드 기반 (`docs/identity/README.md`) | **사용** | 지휘 |
| MVP 화면 목록 (IA, D39) | **사용** (V2의 선행 조건) | 지휘 |
| 디자인 토큰 (`tokens/`) | **제공** (V1 freeze, 그 뒤는 추가만) | app |
| 컴포넌트 명세 (`components/`) | **제공** | app |
| 글자 수 상한 | **주고받음** (요청함) | writing |

계약 버전과 상태는 [`docs/contracts/README.md`](../../contracts/README.md)를 봅니다. 이 파일에는 버전을 적지 않습니다.

## 현재 상태 (2026-11-12, design 세션 작성)
* **D124 신살 도입** (브랜치 `design/shinsal-1029`, #1029, drift #1034, #1026): ① 날짜 머리 덕일은 음력, 일진 줄 끝 `hanja-tag` `compact` 길 색 알약(관문 A, V119, 시안 `artifacts/2026-11-12-date-virtue-questions.html`, 상한 ko 28). #1026 흉한 신살 마무리 한 줄은 풀이 시트 뜻 아래 체크 아이콘과 뉴트럴 상자(V120, 시안 `artifacts/2026-11-12-shinsal-weighing-questions.html`, 슬롯 `ui.shinsal.weighing`, 문구 writing #1030). 다음은 #1029 ② 만세력 신살 띠 밀도(core C40 자리 표현)와 ③ 새 태그 셋(고신, 과숙, 원진).
* **행운 색 둘과 집중 시간 낮, 밤 칩** (PR #1015, #1022 병합, drift #1020 V118, #982 D119, #1003 D122, 결정 V114~V117, 컴포넌트 주 버전과 토큰 부 버전은 계약 목록, 관문 시안 `artifacts/2026-11-11-lucky-chips-questions.html`): 색이 둘인 날 `lucky-card` `color` `pair`(한 알약 두 칸, 기준 이름표 없음)와 어느 칸이든 같은 행운 색 시트 `colorPairSheet`(추천이 둘이라는 한 줄, 갈렸다고 쓰지 않음, V114). `time`은 `periods` 낮 `focus_time`, 밤 `night_focus_time`, 채운 해와 달(Fill 예외 `timeOfDay`)과 새 토큰 `color.time.day`·`night`(모드별, 칩 바탕 위 3:1, `palette.py` `MIN_ICON_CONTRAST`, V115), 밤 칩 때 낱말 07:30에 새벽 → 오늘 밤(V116), 시간 시트 24시간 띠 `timeBand`(V117). `repeat`과 `clock` 지움. 칩 줄은 이어 흐름(관문 5A). 1.7.0 토큰을 `tools/fixtures/*-1.7.0`으로 얼림. 새 IA 슬롯과 D119 ② 문구 개정은 지휘 #1014, 그 슬롯은 `test_components.py` `SLOTS_OUTSIDE_IA`에 #1014로 둠.
* **시트 겹침 표시와 열린 근거 표시** (브랜치 `design/review2-extend`, #958, #950, D118, 결정 V110~V113, 컴포넌트 부 버전과 토큰 부 버전은 계약 목록, 관문 시안 `artifacts/2026-11-10-sheet-stack-questions.html`): #958 겹친 시트는 뒤 앱 화면 크기 변화를 빼고 아래 시트 둥근 윗변과 핸들을 위 시트 위로 14px 보임(`sheet.stack` `peek`, 관문 A, V110, V17 개정). #950 새 토큰 `gradient.unlocked`(세이지, 금빛, 산호, 멈춤 색마다 글자 대비 4.5:1, V111, V5 개정), 새 패턴 `unlock.glint`(열린 구역 제목과 본문, 용신 판정 근거에 1800ms 띠, 15초마다)와 동작 줄이기 대체 요소 `unlock.mark`, 근거 시트 열림 꼬리표 `unlockTag`, 열린 날 근거 아이콘 그라데이션(V112, V63 개정), 원전 뜻, 원문, 출처 순(V113). 글자 수 상한에 `evidence-sheet.unlock.until`과 #946 그날 시트 슬롯 셋을 더함. 1.6.0 토큰을 `tools/fixtures/*-1.6.0`으로 얼림. 같은 결정의 writing #951, server #952, app #953은 지휘가 보냄.
* **검수 회차2 묶음** (브랜치 `design/review2-batch`, 결정 V100~V109, 컴포넌트 부 버전과 토큰 부 버전은 계약 목록, 관문 시안 `artifacts/2026-11-10-review2-batch-questions.html`, `2026-11-10-day-sheet-questions.html`): 규칙만 고친 셋은 #920 겹친 시트 바깥 누르기 한 단계(V100, V17 개정), #917 `band-table` 빈 칸 선을 띠 한 줄 높이 상자 가운데에(V101), #918 ① 두 버튼 높이는 명세상 모두 52(app 확인 몫). 관문으로 정한 넷과 하나: #929 질문 떼기 `x`와 뗀 자리 권유 글자 + 말풍선, 붙은 질문 세로선 `action.primary`, 새 토큰 `color.invite.fg`(V102), #934 일기 줄 사주 기운 태그 모두 한 줄 가로 밀기와 끝 흐림(V103, 데이터는 server #933), #900 새 패턴 `tab.switch` 겹쳐 투명도만 200ms(V104), #923 오류 아이콘 `warning-circle`(V105), #918 ② 아래 버튼은 시스템 inset 위 16과 `input-step` `secondaryAction`(V106). #932 그날 시트: 일정 줄 시각 굵게, 종일 꼬리표, 메모 한 줄(V107), 길흉판정 카드 전체 눌러 내역 펼침(V108), 날의 성격 태그 날짜 머리 오른쪽 두 줄 가운데와 시트 내용 세로 스크롤 규칙(V109). 새 IA 슬롯 셋은 #946에서 IA에 들어감(PR #947). drift #941(#938 IA 보충의 `diary-edit.guide.remove`, `attach`)은 #942에서 슬롯 이름을 적었고 여기서 모양까지 정함.
* **오행 금 흰색, 수 먹색 #892** (브랜치 `design/ohaeng-gold-water-892`, D114, 검수 회차2 F-032, 결정 V98, 토큰 부 버전과 컴포넌트 부 버전은 계약 목록): `palette.py` `OHAENG_FIXED`가 금과 수의 모든 값을 정함(라이트 수는 관문 Q1 ① 먹남, 다크도 금이 가장 밝고 수가 가장 어두운 칸 Q2 A). 새 토큰 `color.ohaeng.metal.border`, `water.border`(칸이 화면 바탕과 가까운 모드에서만 보이는 테두리, 그 밖은 칸 바탕 별칭)와 `color.ohaeng.<오행>.glyph`(간지 태그 흰 원 안 한자색, V78 규칙). 명세: `ohaeng.cell` `border`(지장간 칩도 따름), `hanja-tag` `ganji` `pill.border`와 `glyph.fg`, `ohaeng-bar` `bar.segmentBorder`. 1.4.0 토큰을 `tools/fixtures/*-1.4.0`으로 얼려 1.5.0 변경을 검사. 관문 페이지 `artifacts/2026-11-09-ohaeng-gold-water-questions.html`. writing #893(행운 색 이름 수 남색을 검정으로)은 따로 진행.
* **앱 아이콘 래스터 원본 #908** (브랜치 `design/app-icon-raster-908`, 결정 V99, V7 개정, 컴포넌트 수 버전은 계약 목록): 사용자 제작 그림에서 떼어 낸 책 그림 둘(`logo/source/` 질감판, 평면판 2048 알파)로 `tools/app_icon.py`가 1024 PNG 마스터 넷(`icon-large`, `icon-small` 낙관 1.45배, `icon-android-foreground` 투명, `icon-android-background`)과 공유 이미지 가로 조합 `lockup.png`, `lockup-dark.png`(높이 288)를 만들고 `logo/app-icon.json`에 sha256과 Android 전경 안전 영역 측정값을 적음. `test_logo.py`가 표준 라이브러리로 대조하고 안전 영역은 PNG 픽셀로 다시 잼(CI 의존성 그대로). `share-image` `logo.asset`은 `logo/lockup.png`. 옛 도형판 SVG는 app #909 전환까지 남김. 관문 페이지 `artifacts/2026-11-09-app-icon-questions.html`(Q1 ②, Q2 ②).
* **drift #859 따라잡기** (브랜치 `design/drift-859`, IA PR #856 D113, #860, #867, writing #861, #864, 결정 V96, V97, 컴포넌트 계약 주 버전): IA에서 빠진 `tag-chip`을 지우고 일기 쓰기와 보기의 태그를 `hanja-tag`로, `IA_REMOVAL_REQUESTED`를 비움(`score-scale`도 IA에서 빠짐). 일정 섹션 제목(`today.event.title`, `day-sheet.event.title`)과 대표 태그 꺾쇠 링크 슬롯(`explain-sheet.tag.diary-link`)을 배치에 넣고 상한을 잼. 회고 `diary-summary`는 `getDiaryStats`(S146) 세는 기준. 신강약 알약은 IA에서 다시 빠져 재지 않음.
* **DS1 2단계 화면 결정 시안 #801·drift #815** (브랜치 `design/ds1-screens`, D105·D107·D108, IA v5, 결정 V69~V95, 컴포넌트 계약 주 버전과 토큰 부 버전은 계약 목록).
  * IA v5 새 컴포넌트 14개를 명세로: `section-header`·`explain-sheet`·`scroll-hint`(frame), `hanja-tag`(sentence), `date-header`·`tag-sentence-list`(today), `fortune-verdict`·`score-row`(calendar), `date-block`·`diary-summary`(diary), `luck-pillar`·`birth-info-row`·`band-table`·`stage-strip`(saju). `score-scale`은 쓰지 않아 IA에 제거를 요청합니다(`tools/components.py` `IA_REMOVAL_REQUESTED`, V87). 대기 목록 `IA_PENDING_COMPONENTS`는 비었습니다.
  * 화면 묶음 B 나 탭(V76, V77), A 오늘과 G 잠긴 문장(V78~V80), F 일기 목록과 C 일기 쓰기(V81~V83), D 달력과 그날 시트, 색 규칙 시트(V84~V87), E 사주 표(V88~V93)를 묶음마다 사용자 관문으로 정했습니다. 시안은 `artifacts/2026-11-05-ds1-screen-*.html`(토큰 CSS), 질문 비교는 `artifacts/2026-11-0*-ds1-*-questions.html`.
  * 토큰: 달력 네 단계 `color.calendar.level.*`(라이트 맑은 coral, V84), `color.fill.soft`(V74), `color.verdict.track`(V86), 현재 강조 바탕 옅은 회색 `color.highlight.bg`(V93). 추가만입니다.
  * 정리(V94): 요소 `section.header`·`explain.sheet`는 컴포넌트로 옮겨 지움, `lucky-card` `tag`와 `ohaeng.cell` `mini`와 옛 만세력·대운 부품 삭제, 키보드 내리기는 요소 `keyboard.dismiss`, 사주 용어 한자 17자(刑 추가, V70·V87). 지움과 이름 바뀜은 `components/README.md` 판 기록에 있습니다.
  * 글자 수 상한(`lengths.md` DS1 2단계 절): 상단 바 저장 글자, 가운데 초안 상태, 시진 이름, 자리 표시 기둥 글자를 새로 잼. 성별과 시간 모름 알약은 `ui.birth.option`을 함께 씀.
  * 근거: [spec](specs/2026-11-05-ds1-screens-design.md), [plan](plans/2026-11-05-ds1-screens.md), 감사 `specs/2026-11-05-ds1-audit.md`.
  * 보낸 요청: writing #850(상한과 초안 상태 원고 줄이기, 새 슬롯 여섯, 점수 항목 짧은 뜻, 그날 시트 일기 0편 제목, IA 뒤 모아보기 링크와 편수 삭제), app #851(컴포넌트 계약과 토큰 따라잡기, #808 함께, LockVeil 두 줄, 강조 바탕, 대표 태그 없는 날, fixture 명리 확인), 지휘 #852(IA 출구와 슬롯, `score-scale` 제거, D108 ② 刑), core #853(巳 지장간 순서). #801에 결과 코멘트. 결정 행 사용자 영향은 이 번호들입니다.
* **DS1 1단계 규칙 #801** (브랜치 `design/ds1-rules`, D107, 결정 V56~V68).
  * 검수 F-001~F-012를 규칙으로: 간격 쓰임표와 직접 쓴 px 0개(V56), 아이콘 `size.icon.*`·`adjacent-text`와 직접 그린 아이콘 금지(V57), 0.5px `list.divider`와 꺾쇠는 이동 줄에만, `settings-row` 앞 아이콘·`select`(V58), `section.header`(V59), `button.pair`와 `quiet` 52(V60), `press.ink` 반지름과 범위(V61), `explain.sheet`(V62), 근거 진입점 `book-open-text` 아이콘(V63), 시트 안쪽 24와 핸들 자리(V64), 확인 창 사방 24와 같은 폭 두 버튼(V65), 요소별 skeleton(V66), `page.push`(V67), 키보드 내리기(V68).
  * 도구: `tools/rules_audit.py`(간격 전수 점검, 결과 `specs/2026-11-05-ds1-audit.md`), `tools/token_css.py`(토큰을 CSS 변수로, `artifacts/ds1/tokens.css`), `tools/phosphor_names.txt`(Phosphor 이름 목록). 규칙마다 `test_components.py`에 검사.
  * 고른 안은 규칙 견본 `design-ds1-rules`(Q1 ①, Q2 ①, Q3 ②, Q4 ②, Q5 ①, Q6 ①). 근거: [spec](specs/2026-11-05-ds1-rules-design.md), [plan](plans/2026-11-05-ds1-rules.md).
  * 보낸 요청: writing #807(근거 아이콘 이름, 키보드 내리기 새 슬롯, 설정 줄 상한), app #808(4.0.0, 1.3.0 따라잡기).
* **문의 화면 #763·drift #758** (브랜치 `design/contact-758-763`, D102, 결정 V55).
  * `text-field`에 칸 위 이름 `label`, 칸 오류 줄 `errorLine`(`input-step` 오류 줄과 같은 모양), 변형 `email`, `multiline` `minLines`(문의 내용 4)와 안내 두 줄. 배치는 `input.md` "contact 화면 배치": 보내기 실패는 toast(쓴 글 유지), 주소는 길게 눌러 복사하는 글자, 보낸 뒤 설정으로 돌아가 toast, 뒤로 가기는 확인 창 없음.
  * `lengths.md`: 슬롯 9개(IA 8 + `ui.contact.error`)와 키별 상한 셋(칸 안 안내 둘, 메일 칸 오류). ja `contactEmailFieldHint`는 라틴 주소라 실측 16. R29 원고는 모두 상한 안.
  * drift #758: `text-field`, `primary-button`, `toast` 쓰는 화면에 contact.
  * 근거: [spec](specs/2026-11-04-contact-screen-design.md).
* **W51 슬롯 상한·집중 시간 칩 #710·#546** (브랜치 `design/lengths-710`, 결정 V52~V54).
  * #546(V52): `lucky-card` `time`은 구간마다 칩 하나(최대 2), 범위 표기는 W44 언어별(ko `~`, ja `〜`, en " to "), `join` 삭제, 칩 줄 최대 7, 공유 이미지는 첫 구간 칩만.
  * #710: 7개 슬롯을 `lengths.md`에 잼. 설정 줄 이름과 값은 반씩(132px, `settings-row` 값 앞 `space.8`), 사주 표 탭은 segmented 두 칸, `ui.saju.header`는 만세력 행 머리 44px 두 줄, `ui.saju.tag`는 대운 꼬리표 92px, '나' 꼬리표 `sajuTagMe`는 키별, en "Hidden stems"는 실측 키별 상한 12(`KEY_MEASURED_LIMITS`). 스크린리더 셋과 ATT는 상한 없음.
  * V53: 만세력 행 머리는 대운 라벨처럼 두 줄, 대운·세운 꼬리표는 이웃 위로 넘쳐 기둥 둘 폭까지, `tag.me`는 기둥 폭까지. V54: 표 칸 근거 시트의 빈 해석 안내 `personalEmpty`(app 구현을 명세로).
  * R26 원고 중 en `sajuChartTabLuck`(24자)이 상한 22를 넘어 writing에 줄이기 요청.
  * 근거: [spec](specs/2026-11-03-w51-lengths-time-chip-design.md).
* **사주 표 십성 라벨·피드백 표시·윤달 사주 줄 #353·#354·#587** (브랜치 `design/feedback-saju-353-354-587`, 결정 V48~V51).
  * #353(V49): `daeun-table` 대운 기둥에 천간·지지 십성과 12운성(`term-token` `label`, 줄 순서 `order`), 세운은 천간 십성 하나. 라벨은 칸 폭 안 두 줄 줄바꿈, 넘치면 `type.caption.sm`까지 줄임, 줄마다 높이 맞춤. `manse-table` 지장간은 "한자와 독음 / 십성" 두 줄 묶음을 늘 쓰고, 12운성·신살 값은 `term-token` `inline`. 십성 라벨 상한 행은 두지 않음(`glossary.value_name`이 다른 자리와 같은 슬롯).
  * #354(V50·V51): `notice-banner` `error`(`cloud-warning`, 버튼 없음, 다시 시도는 화면 저장 버튼), `stateMap.error`에 배너 추가, `settings-row` `groupNote`(묶음 카드 위 안내, `profile-edit.recalc.notice`, 상한 62·46·104), toast는 아래 고정 버튼 위 16px.
  * #587(V48): `account-choice` 사주 줄은 달력 종류 뒤에 윤달 낱말(`dayCellLeapMonth`와 같은 낱말). 256px 안(en 시각 모름 248.8px). 틀은 writing 차례.
  * 근거: [spec](specs/2026-10-28-feedback-saju-labels-design.md). 시안 없이 app 임시 구현을 기준으로 정함.
* **구매 줄 두 줄·광고 제거 새 슬롯 #564·#548** (브랜치 `design/purchase-meta-564`, W44, 컴포넌트 계약 3.1.0).
  * `purchase-row` `meta`: 구매일 줄 아래 `space.2`에 사용 기간 줄, 구분자 `join`(`purchaseMetaSeparator`) 삭제, `loading` bone 세 줄(결정 V47). 글자 수는 키마다 한 줄이라 `ui.purchase.meta` 상한 그대로.
  * `offer-card` `buy` → `ad-free.buy.cta`, `period` → `ad-free.offer.period`. 카드 안 버튼(구매, 구매 내역)은 240px 행으로 따로 잼(`ad-free.history.cta` 23·19·42 → 20·16·35), 기간 고지는 280px 한 줄. `lengths.md` 상한 없음 표의 겹친 윤달 표지 행 정리.
* **계정 합치기 두 단계·구매 내역 #480·#483·#494·#475** (브랜치 `design/catchup-480-d85-d88`, D85·D88, 컴포넌트 계약 3.0.0).
  * `account-merge` 한 화면 두 단계(인증 → 가져올 기록·구매 상자 + `account-choice` + 합치기 버튼), "합치지 않기" 없이 뒤로 가기. `account-choice`는 프로필 고르기(`facts`·`diaryCount`·`providers` 삭제, `other` 알약 추가). `login-methods`에 합치기 입구, 연결 안 함 안내는 `dialog` `notice`(V44).
  * `offer-card` `restore` → `history`, `purchase-row` 새 컴포넌트(상품 이름 → 구매일·사용 기간, 상태 오른쪽, V45, 지휘 #502로 상품 이름 추가).
  * #475: 카카오 배지 `#191919`, LINE 글자 198px(`lengths.py` `KEY_TARGETS`), `entry` 꺾쇠 앞 `space.8`, 시각 24시간제(V46).
  * 근거: [spec](specs/2026-10-23-account-merge-purchase-design.md), 결정 V44~V46, 시안 `design-v2-account-merge-purchase`.
* **같은 날 여러 편 #410** (브랜치 `design/diary-row-multi`, D83, 컴포넌트 계약 2.8.0·토큰 1.2.0).
  * `diary-row` 변형 `day`(목록·태그 모아보기: 한 편이면 지금 모양, 두 편 이상이면 날짜 하나에 카드 하나 — 배지 위·태그 아래 한 번씩, 사이에 `entry` 줄)와 `entries`(오늘·그날 시트: `entry` 줄만). `entry`는 작성 시각 + 한 줄 미리보기 + 꺾쇠, 줄 사이 1px 점선(대시 4·간격 3, 새 토큰 `color.timeline.entry`, V42).
  * 상한을 채운 날 입구: `guide-question-card` `full`(도장 남기고 버튼만 막음), 그날 시트 버튼·날짜 시트 버튼 `disabled` + writing `…Full` 키(V43). "쓴 일기 보기" 표기를 writing 키로 고침(D83 ③). 그날 시트 일기 입구는 머리(`entries.head`) + 줄 + 쓰기 버튼으로 V37을 개정하고 `depth-link` `navigate`의 `daySheetSlot`을 지움(IA day-sheet의 `depth-link`는 지휘가 PR #460으로 뺌, drift #461).
  * writing #441 키 이름 채움: `connected` "연결됨" `loginMethodsRowConnected`, 수단 구분자 `accountChoiceProviderSeparator`.
  * 근거: [spec](specs/2026-10-22-diary-row-multi-design.md), 결정 V42·V43, 시안 `design-v2-diary-row-multi`.
* **영문 ja 로그인 라벨 상한 #446** (브랜치 `design/login-label-ja`): `lengths.py` `KEY_LIMITS`(키별 상한 표)로 `ui.login.provider` ja `loginKakaoLabel`(영문 "Login with Kakao", #143)은 en 상한. IA가 `login-methods`에서 `settings-row`를 빼(PR #442) `USED_ON_EXCEPTIONS`를 지움. app #311에 2.7.0 요약을 남김.
* **로그인 수단·계정 합치기 #389** (PR #439 병합, D82·D83, 컴포넌트 계약 2.7.0, drift #395).
  * `social-login-button`: `line`·`google` 변형(각 사 가이드 값), 언어별 순서 `parts.stack.order`(맨 위만 ko 카카오·ja LINE·en Google), 상태 `connected`(중립 줄 + "연결됨", 마지막 하나는 누를 수 없음, 결정 V39). login-methods 화면 배치는 `action.md`.
  * `account-choice`(새 컴포넌트, `input`): 처음엔 고르지 않음(`none`), 카드에 호칭·"현재 계정"·사주 요약(`ui.account-merge.saju`)·일기 수·수단 이름(로고 없음). account-merge 배치는 `input.md`: 겹치는 날 안내는 경고 표시 없는 안심 안내, 강조는 최종 확인 `dialog` `destructive` 한 곳(V40).
  * `dialog`: 버튼 두 개짜리 확인 창의 첫 초점 규칙을 지움, `destructive`의 뒤로 가기는 취소(V41, #354 ②의 답).
  * `day-cell` 윤달 표지 슬롯 `ui.day-cell.lunar`(#260), `diary-row` 쓰는 화면에 today·day-sheet(D83, 모양은 #410).
  * 글자 수 상한 11행, 윤달 표지는 상한 없음(폭 44px로 확인), `ui.login.provider`는 가운데 정렬 232px로 다시 잼(`lengths.md` 2.7.0). #419 원고 중 확인 창 제목 키·ja 알약이 상한을 넘어 writing에 줄이기 요청. IA `login-methods`의 `settings-row`는 지휘가 PR #442로 뺌(#440).
  * 근거: [spec](specs/2026-10-22-login-methods-account-merge-design.md), 결정 V39~V41, 시안 `design-v2-login-methods`·`design-v2-account-merge`.
* **검사 범위 정리 #362** (PR #371 병합, D81): `design.yml` `mode`(`own` 전체, `drift`·`gate`는 계약 검사만), 측정 글꼴 CI 받기·캐시, D79 기본 깊이 행 삭제.
* **규칙 정합성 점검 #284** (브랜치 `design/rules-audit`, D78).
  * 글자 수 상한: D77 IA 자리 9개를 writing 슬롯(W33, `ui.*`에 `ia`) 기준으로 기존 행에 더함(값 그대로). `settings.calculation_basis` → `calc-basis.longitude.body`(W21). #191은 W26 `unbounded`·`key_max_length`로 끝남.
  * MD "쓰는 화면"을 IA에 맞추고 테스트가 대조함. 예외 `diary-editor` diary-view는 IA 보완 요청 #290.
  * V19·V37 개정 표시, `lucky-card` 칩 줄 전체 최대 6개, `visual-identity.md`는 계약 표를 가리킴.
  * #141 끝남: app에 V31 목표 모양 요청 #292(#282 3번과 같은 항목).
* **app 계획 4 확인 #218·drift #252·#257** (브랜치 `design/calendar-answers`).
  * `date-picker` `solar`(일정 날짜 양력만), `text-field` `multiline`(6줄까지, 줄바꿈 키), `dialog` `destructive`에 일정 삭제.
  * `event-row`: 일정에 길이가 없음(시각 일정은 진행 중 아님), '외 N개'는 라벨 끝 목록 구분자, summary `twoLines`, list `timeColumn.overflow`·`add`·`failed`.
  * `day-cell`: 높이는 1.3배 글자까지만 늘어나는 최소 높이(V36), 윤달 초하루 표지(V38, 문구는 writing #260)·윤달 라벨은 윤달 모든 날.
  * 그날 시트 일기 입구(V37): 보기 `depth-link` `navigate`(`daySheetSlot`), 쓰기 `primary-button` `filled`.
  * 근거 여럿은 문단·상자를 `space.12`로 쌓음(`repeat`), 풀이 시트 한자는 `font.family.hanja`, 원전 인용은 한자만 `fontFallback`.
  * drift: `lengths.py` 측정 말뭉치를 R8까지로 고정(`MEASURED_LAST_ROUND`). 확정값이 라운드에 따라 움직이지 않고, 테스트는 개수를 `lengths.md` 근거 문장에서 읽음.
* **오늘 화면 대표 태그 칩 #239** (브랜치 `design/today-tag`, D76): `lucky-card` 변형 `tag`(글자 굵기 600 + 앞 아이콘 `tag` 본문색, 길흉 색 없음, 결정 V35), 칩 줄 맨 앞, 공유 이미지 제외. 글자 수 `daily.tag_label`은 이 칩 폭으로 다시 잼(확정값 그대로).
* **app 질문 #195·#211** (브랜치 `design/app-questions`): `city-search` 고른 뒤 저장 중 `saving`(고른 줄 끝 점 숨쉬기, 결정 V34), 지역 구분자 `region.join`(ja `、`), `input-step` `preface` 간격 `space.24`, `skeleton` 글줄 `type`, 안내 글 본문 레이아웃(`frame.md`, IA 컴포넌트 아님).
* **구현 대응·IA v3·글자 수 상한** (브랜치 `design/spec-followups`, Issue #118·#142·#154·#159·#131).
  * app 구현 차이 판단을 명세에 확정: 링크 화살표는 아이콘 `caret-right`로 컴포넌트가 그림, 고정 높이는 최소 높이, `dialog` `notice`, `segmented` `none`, 윤달 대체 모양, 탭 아이콘, 시간 형식, 근거 시트 빈 구역 생략, 요소 값 3개.
  * IA v3: 출생지 → 계산 기준 링크 `depth-link` `navigate`(슬롯 `birthplace.standard.link`).
  * 글자 수 상한: ui 이름 자리와 새 content 슬롯 칸을 더함, 상한 없음 표, 확인 창 슬롯은 제목·버튼 키만. 기존 확정값 그대로.
  * 명세를 바꾸지 않는 Flutter 대응(의미 표시 등)은 각 `.md`의 구현 힌트에 적음.
  * 근거: [spec](specs/2026-10-15-spec-followups-design.md), 결정 V29~V33.
* **용신 근거 줄 이름 슬롯** (브랜치 `design/yongsin-title`, Issue #81): `sentence-block` `a11y.lockedNameSlot` = `saju-chart.yongsin.title`(잠김 라벨의 구역 이름).
* **문장 조각 용어 표시·근거 잠금 슬롯** (브랜치 `design/lock-slots`, Issue #68, PR #83).
  * `sentence-block.parts.segments`: `term` 조각은 `term-token`이 있는 화면에서만 칩(`term-token` `inline`), 그 밖은 일반 글자. 용어와 붙은 조사는 한 덩어리로 줄바꿈.
  * IA v1 추가분(#70) 슬롯: `sentence-block` 열기(`saju-chart.yongsin.open`), 근거 시트 구역 제목 3개·해제 실패 toast·접근성 문구 3개.
  * 슬롯 이름과 `term-token` 화면 목록은 테스트가 IA에서 읽어 비교합니다.
  * 근거: [spec](specs/2026-10-13-term-segments-lock-slots-design.md), 결정 V28.
* **V2 후속: 근거 깊이 잠금·글자 수 상한** (브랜치 `design/v2-followups`, Issue #53·#54).
  * 근거 시트 구성과 잠김 상태 4개(`depth-link.evidenceSheet`), 요소 `lock.veil`, `sentence-block` `locked`. 풀이 시트의 개인 해석 상자와 `term-token` 잠김은 뺌(D60).
  * 공통 규칙: 동작 = 둥근 사각, 표시·고르기 = 알약(예외 없음), 화면 좌우 여백 `space.20`.
  * 글자 수 상한: [`lengths.md`](lengths.md), 도구 `tools/lengths.py`(측정 글꼴은 `tools/fonts.py`로 `.suberpowers/fonts`에 받음).
  * 근거: [spec](specs/2026-10-11-depth-lock-lengths-design.md), 결정 V25~V27.
* **마일스톤 V2 컴포넌트 명세** (브랜치 `design/components`).
  * 명세: [`components/`](components/README.md) JSON(사실) + MD(설명) 11쌍. 공통 `interaction`(패턴 12개)·`elements`(요소 15개, 근거 잠금에서 16개).
  * 검사: 저장소 루트에서 `python3 docs/identity/design/tools/components.py`(IA 41개·토큰 참조·요소·패턴·상태 대응표·짝 MD).
  * 근거: [V2 spec](specs/2026-10-11-components-design.md), 결정 V13~V24. 대비 검사 86/86(비활성 글자 3:1).
* **마일스톤 V1 디자인 토큰 freeze** (브랜치 `design/tokens`).
  * 토큰: [`tokens/`](tokens/README.md) 다섯 파일. 생성: 저장소 루트에서 `python3 docs/identity/design/tools/tokens.py`. 손으로 고치지 않습니다.
  * 근거: [V1 spec](specs/2026-10-11-design-tokens-design.md), 결정 V8~V12. 대비 검사 52/52.
  * 길흉 표시는 점이 아니라 칸 채우기입니다(결정 V10).
* **V0 시각 정체성 완료** (PR #10).
  * 기준 문서: [`visual-identity.md`](visual-identity.md). 시각에 관해서는 06을 대체합니다.
  * 근거: [V0 spec](specs/2026-10-10-visual-identity-design.md), 결정 V1~V7([`decisions.md`](decisions.md)).
  * 색 값의 출처: [`tools/palette.py`](tools/palette.py) (`--check`로 대비 검사).
  * 로고 원본: [`logo/`](logo/), 견본: [`specimen/index.html`](specimen/index.html), 시안 기록: [`artifacts/index.json`](artifacts/index.json).
* 테스트: 저장소 루트에서 `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`(1초 안쪽)
  * 반복 중 빠른 경로: 바꾼 도구의 테스트 파일만 돌립니다. 예: 명세는 `... pytest docs/identity/design/tools/test_components.py -q` + `python3 docs/identity/design/tools/components.py`, 글자 수는 `test_lengths.py`, 토큰은 `test_tokens.py test_dtcg.py`.
* 측정 글꼴(고운돋움·Zen Maru Gothic·Pretendard)은 저장소에 넣지 않습니다. 받기: `python3 docs/identity/design/tools/fonts.py --font-dir .suberpowers/fonts`(주소·sha256 고정).
  * 로컬에서 글꼴이 없으면 글자 수 표 비교·워드마크 테스트 4개가 **skip**됩니다. CI는 글꼴을 받아 돌리고, 없으면 실패합니다(`DESIGN_FONTS_REQUIRED=1`).
* 앱 아이콘 래스터 원본(`logo/*.png`, V99)은 `logo/source/` 그림에서 만듭니다: `uv run --with pillow==11.0.0 --with numpy==2.1.3 --with scipy==1.14.1 python docs/identity/design/tools/app_icon.py`(resvg 필요). `logo/app-icon.json`을 함께 고칩니다. PNG는 바이너리라 이력이 커지므로 그림을 바꾸는 의도가 있는 PR에서만 다시 만들어 커밋합니다.
* 로고 원본(`logo/`)을 바꾸면 순서대로 다시 만듭니다.
  1. 워드마크·가로 조합: `uv run --with fonttools==4.54.1 python docs/identity/design/tools/wordmark.py --font .suberpowers/fonts/GowunDodum-Regular.ttf --out-dir docs/identity/design/logo`
  2. 로고 모음 산출물: `python3 docs/identity/design/tools/logo_sheet.py`. 다시 만들지 않으면 `test_logo_sheet_matches_committed_artifact`가 실패합니다.

## 다음 할 일
1. **D124 신살(#1029, #1026):** ① 덕일 V119, #1026 마무리 한 줄 V120 끝. #1029 ② 만세력 신살 띠 밀도와 넘침(core C40 `positions`), ③ 고신, 과숙, 원진 한자 태그 글자 순서로 합니다. writing #1030이 덕일 원고(상한 ko 28, ja 23, en 52)와 마무리 한 줄(ko 52, ja 38, en 88)을 쓰면 상한 안인지 봅니다. 괴강 罡처럼 한자 글꼴에 없는 글자 표시 방법도 ②③과 함께 정합니다(#1029 지휘 코멘트).
2. **#982, #1003 뒤:** #1015(V114~V117)와 #1020 drift(D123, V118: 시트 끝 근거 진입점, 시간 시트 제목, 새 슬롯 상한)는 끝남. writing이 새 슬롯 원고를 쓰면 `lengths.md` 상한(때 낱말 ko 16, 띠 날 낱말 ko 7 등) 안인지 봅니다. app은 컴포넌트 7.x와 토큰 1.8.0 drift로 따라잡습니다. 회차2 덧붙임(#962)은 병합됨: writing #951이 열림 꼬리표 문구를 쓰면 상한(27, 22, 49) 안인지 봅니다.
3. **#908 마무리:** #942가 병합되어 app #909가 래스터 원본(`logo/*.png`)과 공유 이미지 `lockup.png`로 옮깁니다. app이 옮긴 뒤 옛 도형판 SVG(`icon-*.svg`, `lockup*.svg`)와 그 검사(`test_logo.py` SVG 절, `logo_sheet.py`, `wordmark.py` 가로 조합)를 지우고, 낙관 도장 경로(V16) 대조를 컴포넌트 명세 값 기준으로 바꿉니다.
4. **2단계 후속:** app이 컴포넌트 주 버전과 토큰 부 버전을 따라잡는지(#851) 봅니다.
5. **#763 마무리:** writing이 문의 화면 상한과 키별 상한을 넣으면 #763이 닫힙니다.

그 밖에는 대기합니다. 아래 일이 생기면 엽니다.
5. **app 대응 지원:** app이 명세로 만들 수 없는 곳이나 저사양 Android 성능 결과를 `to:design` Issue로 보내면 컴포넌트 계약 버전 규칙대로 고칩니다. notice는 #82입니다.
6. W1 원어민 검수 문장이 나오면 일본어 줄 간격(1.75 / 1.7)을 다시 확인합니다.
7. app이 토큰 형식 변경을 요청하면 계약 버전 규칙(`tokens/README.md`)대로 대응합니다.
