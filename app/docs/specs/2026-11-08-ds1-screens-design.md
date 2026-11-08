# DS1 화면 따라잡기 (컴포넌트 4.0.0·5.0.0, 토큰 1.3.0·1.4.0, REST 1.5~1.8, IA v5, 검수 버그) 설계

* 작성: app 세션, 2026-11-08
* 상태: 초안, 구현 브랜치 `app/ds1-screens`
* 요청: drift #810(PR #809~#867 계약 변경), #808(컴포넌트 4.0.0, 토큰 1.3.0), #851(컴포넌트 5.0.0, 토큰 1.4.0, fixture 명리 확인), #833(REST 1.5.0~1.8.0), #796(검수 회차1 동작 버그 다섯 건)
* 보낸 요청(처리됨): #862(server PR #866, REST 1.9.0 `getDiaryStats`, S146), #863(writing PR #864 `role.day_master` W61, server seed #865)
* 관련 결정: 루트 D105~D113, design V56~V95, server S138~S142·S146, writing W55~W61
* 쓰는 계약: design 컴포넌트 5.0.0과 토큰 1.4.0(`docs/identity/design/components/`, `tokens/`), IA v5(`docs/ia/screens.json`), REST 1.9.0(`server/api/openapi.yaml`), writing ARB(R35까지)
* 화면 기준(origin): 비공개 기록 `review/shots/2026-11-05/ia-final/` 2판(10장). 내용은 이 문서에 옮기지 않습니다(D74)

## 1. 목적과 범위

app을 DS1 확정 화면과 지금 main의 계약에 한 번에 맞춥니다. **구성**(무엇이 어떤 순서로 어디에 있는지)은 origin과 IA v5를 따르고, **세부 모양**(여백, 크기, 색, 아이콘)은 컴포넌트 계약이 최종입니다(origin README 규칙). origin에 있어도 그리지 않는 것은 원국 "신강" 알약(D113 ⑦)과 시안 표기("예시 수치", "D106" 같은 설명 글)입니다. origin에 없어도 넣는 것은 일기 쓰기의 질문 바꾸기 아이콘입니다(V82).

**성공 기준**
* ci-gate의 app drift 검사와 전체 검사(analyze, 전체 테스트, golden, 커버리지 ratchet, fixture 스키마, ARB 문구)가 통과하고, drift #810이 main에서 자동으로 닫힙니다.
* 화면 10개(나 탭, 오늘, 근거 잠김 시트, 일기 목록, 일기 쓰기, 달력, 그날 시트, 사주 표 원국, 만세력과 대운, 12운성 시트)를 fake 대역으로 찍은 스크린샷이 origin과 구성이 같습니다. 다른 곳은 계약이 그렇게 정한 곳뿐이고, 그 목록을 PR에 남깁니다.
* 새 화면 `tag-sheet`, `color-rule-sheet`가 registry에 등록되고 `ia_pending.dart`가 비어 있습니다.
* #796 다섯 건이 위젯 테스트로 재현된 뒤 고쳐집니다.
* 바뀐 흐름의 로컬 Patrol(today, diary, calendar, me)이 통과합니다.

**다루지 않는 것**
* 공유 이미지(`share-image`)의 모양 변경. IA에 `day-character`가 이 자리로 남아 있고 계약 변경이 없습니다.

## 2. 현재 상태(실측, 2026-11-08)

* main을 합치고 생성기(IA, ARB, API)를 돌리면 지워진 슬롯과 부품을 쓰는 곳에서 컴파일이 깨집니다(`todayLuckyTagBody`, `todayCharacterReason`, `todayEvidenceLink`, `daySheetCharacterReason`, `depthLinkEvidence`가 함수로 바뀜, `LuckLevel.veryGood` switch).
* `tool/gen_tokens.dart`는 `color.verdict.track`(DTCG gradient 값)에서 멈추고, 그다음 `motion.duration.page`와 `motion.easing.page`가 같은 이름이 되어 멈춥니다. `border.width.hairline`, `size.icon.*`, `motion.offset.page`는 내보내는 코드가 없습니다.
* REST 1.6.0부터 `Daily.guideCandidates`와 `CalendarDay.scoreItems`가 필수라 지금 fixture로는 fake 모드가 읽기에 실패합니다.
* app에 없는 컴포넌트: `section-header`, `explain-sheet`(지금은 term 풀이 판만), `scroll-hint`, `hanja-tag`, `date-header`, `tag-sentence-list`, `fortune-verdict`, `score-row`, `date-block`, `diary-summary`, `luck-pillar`, `birth-info-row`, `band-table`, `stage-strip`, 요소 `stem.chip`, `keyboard.dismiss`, `button.pair`, `list.divider`(공용), 패턴 `page.push`.

## 3. 진행 단계

한 브랜치에서 단계마다 commit합니다. 단계 안 task는 subagent가 맡고, 단계 끝마다 리뷰합니다.

| 단계 | 내용 | 닫는 요청 |
| --- | --- | --- |
| 1. drift 기반 | 생성 코드(IA, ARB, API, 토큰) 다시 만들기, 토큰 생성기 고치기, 지워진 슬롯과 부품을 쓰는 곳 정리, fixture 필수 필드, 컴파일과 계약 테스트 복구 | #810, #833 일부 |
| 2. 공용 기반 | 4.0.0 규칙(간격, 아이콘 크기, 구분선, press.ink, sheet, dialog, skeleton, page.push, quiet 52, button.pair, settings-row, keyboard.dismiss)과 여러 화면이 쓰는 새 컴포넌트(`section-header`, `hanja-tag`, `explain-sheet`, `stem.chip`, `scroll-hint`) | #808 |
| 3. 나 탭(B) | 다섯 섹션, `luck-pillar` `compact`, `diary-summary`(`getDiaryStats`), 사주 원국 카드 공유 | #851 일부 |
| 4. 오늘(A), 근거(G), tag-sheet | `date-header`, 총운 결정 태그와 보조 문장, 사주 기운, 행운 칩과 설명 시트, D112, `lock.veil` G1, `tag-sentence-list` | #851, #833 |
| 5. 일기(F, C) | `diary-row` 날의 성격과 대표 태그, 떠 있는 쓰기 버튼, `app-bar` `edit`, `date-block`, 인용 질문과 바꾸기 | #851, #833 |
| 6. 달력(D) | `day-cell` 네 단계, 범례와 입구, 그날 시트 full, `fortune-verdict`, `score-row`, `color-rule-sheet`, 일정 섹션 머리 + | #851, #833 |
| 7. 사주 표(E) | 머리 제목과 `birth-info-row`, 섹션 머리, 용신 판정 근거 잠김 2줄, `band-table`, `luck-pillar` `column`, `scroll-hint`, `stage-strip` 시트 | #851 |
| 8. 검수 버그 | 다섯 건 모두 재현 테스트 뒤 고침(F-019는 `role.day_master`) | #796 |
| 9. fixture 명리 | #851 표 정정, 엔진으로 다시 계산한 값, 새 필드 | #851 |
| 10. origin 대조와 마무리 | 화면 스크린샷 대조, golden, 전체 검사, 로컬 Patrol, CLAUDE.md, 결정 기록 | |

단계 8의 F-013과 단계 2의 `keyboard.dismiss`는 같은 task에서 다룹니다. 단계 9의 fixture 값은 단계 3~7 화면이 쓰므로 단계 1에서 필수 필드만 먼저 채우고, 명리 정정은 단계 9에서 합니다.

## 4. app 결정 (A109~)

결정 로그 `app/docs/decisions.md`에 같은 내용을 행으로 적습니다.

* **A109 토큰 생성기.** `$type`이 `color`인 것만 색 역할로 받고, gradient 값은 `GradientTokens`로 보냅니다. 이름은 접두사를 떼고 camelCase(`color.verdict.track` → `verdictTrack`). `motion.*.page`는 `pageDuration`, `pageEasing`, `pageOffset`으로 종류를 이름 끝에 붙입니다. `border.width.*`와 `size.icon.*`는 새 클래스로 냅니다.
* **A110 `page.push`.** `ThemeData.pageTransitionsTheme`에 두 플랫폼이 같은 builder 하나를 둡니다(오른쪽에서 24px와 투명도, 320ms, 뒤 화면 정지, 동작 줄이기면 투명도만). iOS 가장자리 밀어 뒤로 가기는 남기고, 탭 사이 이동과 시트에는 쓰지 않습니다.
* **A111 아이콘 크기.** `AppIconSize`를 토큰 네 단계와 `adjacentText(fontSize)`로 바꿉니다. 글자 옆 아이콘만 기기 글자 배율을 그 칸의 `textScaleMax`까지 곱합니다(`icon.textScale`).
* **A112 한자 글자표.** `hanja-tag`의 글자는 계약 `parts.glyphs`(이름 기준)를 app이 키 기준 상수 표로 옮깁니다. 날의 성격 enum, 십성 묶음 enum, 태그 키(`harmony` 合, `clash`, `clash_day_branch`, `clash_month_branch` 沖, `hyeong` 刑, `cheoneul_gwiin` 天, `dohwa` 桃, `yeokma` 驛, `hwagae` 華, `gongmang` 空, `ten_god_rush.<묶음>`은 그 묶음 글자), 점수 항목 id. 표에 없는 키는 태그를 그리지 않고 비치명 오류로 남깁니다. 표는 계약 테스트가 `sentence.json` glyphs 17자와 대조합니다.
* **A113 `tag-sheet` 데이터.** 1순위 태그는 `featured[0]`, 2순위는 `featured[1]`입니다(D108 ①). 1순위의 문장 줄은 총운 보조 문장(`fortune.tag`)과 오늘의 질문(`guide`), 2순위는 `empty`입니다. 머리 근거 아이콘은 근거를 가진 1순위(보조 문장 근거)에서만 보이고, 2순위는 그 태그 몫의 문장과 근거가 계약에 없어 숨깁니다.
* **A114 오늘 일정 섹션 제목.** IA v5 `today.event.title`(사용자 결정 2026-11-07)을 따라 일정이 있는 날 `section-header`를 둡니다. `today.md` 배치 6번("제목 없이")과 어긋나므로 #851에 코멘트로 알립니다.
* **A115 질문 바꾸기.** 후보는 `Daily.guideCandidates`이고 바꾸기는 다음 후보로 돌아갑니다(끝이면 처음). 저장할 때 고른 후보의 `messageKey`와 `variant`를 `createDiary.guideQuestion`으로 보내고, 후보를 받지 못했으면(오프라인 초안) 필드를 뺍니다. 로컬 초안에 고른 질문의 키와 variant를 함께 남기고, 다시 열 때 후보에 있으면 그 질문을 씁니다(drift schema 판 올림). 실패 뒤 다시 보낼 때 멱등 키를 다시 쓰는 조건에 고른 질문을 넣습니다. 이미 저장한 일기를 고칠 때는 바꾸기를 숨기고 저장된 질문을 보입니다. 422 `diary.guide_invalid`는 오늘 풀이를 다시 읽어 후보를 새로 받고 일반 저장 실패 문구를 보이며 본문은 지킵니다.
* **A116 색 규칙 시트 점수표.** 일곱 줄(용신의 날 +2, 귀인의 날 +2, 합 +1, 기신의 날 −1, 일지 충과 월지 충 −2, 충 −1, 형 −1)은 계약 `calendar.md` color-rule-sheet 배치 절과 엔진 spec §8에서 온 app 상수입니다. 내려주는 API가 없습니다. 이름은 용어 사전 `score_item`에서 찾습니다. 그날 시트 내역 줄은 server `scoreItems`를 더함 먼저, 뺌 다음(같은 부호 안은 server 순서)으로 놓고, 점수 0인 항목은 그리지 않습니다.
* **A117 사주 표 처음 탭.** 나 탭 "대운 전체"는 사주 표를 만세력과 대운 탭으로 엽니다. 경로 query `tab=luck`으로 넘기고, 없으면 원국 탭입니다.
* **A118 사주 표 머리 데이터.** 제목의 호칭과 `birth-info-row`의 출생 정보는 `Chart`에 없어 프로필 provider에서 읽습니다. 프로필을 못 읽으면 머리 줄만 뼈로 둡니다.
* **A119 회고 집계.** `diary-summary`는 `getDiaryStats`(REST 1.9.0)를 나의 사주 화면 진입 때 받습니다. 편수 `entryCount`는 편 단위이고 `few`(5편 미만) 판단에 씁니다. 날의 성격 막대와 태그 옆 수는 날짜 단위(`days`, S146)이고, 막대 순서는 계약 `order`로 app이 정합니다. 캐시는 두지 않고(일기를 쓰거나 지우면 바뀜), 일기 저장과 삭제 뒤 이 provider를 다시 읽습니다. 실패하면 회고 카드 자리에만 `error-state`(다시 시도)를 두고 다른 섹션은 그대로 보입니다(화면 전체를 막지 않음). fake 대역은 fixture 일기 목록에서 S146 규칙대로 셉니다.
* **A120 #796 고치는 방향.** F-026: 날짜 시트의 확인 버튼을 스크롤 밖 아래에 고정해 늘 보이게 합니다(계약의 고르기 → 확인 흐름 유지). F-027: 시트의 bounce 보정이 본문 viewport 높이를 바꾸지 않게 하고(Transform만), 닫기 판정은 손가락 이동 거리로 합니다. F-013: `MyungliTextField`와 `DiaryEditor`에 밖을 누르면 초점 풀기, 입력 화면 스크롤 뷰에 끌면 내리기, 그리고 `keyboard.dismiss` 버튼. F-030: 시진 확인 줄의 key 교체를 없애 글자만 바꾸고, 요청 실패(null) 때 붙잡은 값을 지우지 않습니다. F-019: 일간 칩은 용어 `role.day_master`(W61, 시드 #865)를 엽니다. 근거 시트의 원국 개인 해석(`day_master`) 연결은 그대로 둡니다. 재현 테스트를 먼저 쓰고 실패를 본 뒤 고칩니다.
* **A121 fixture 명리 값.** #851 표를 따르되 태그는 손 계산하지 않고 core 엔진으로 그날 값을 다시 뽑아 넣습니다(달력과 원국은 기존 생성 스크립트, 오늘과 일기는 엔진 호출로 값을 확인한 뒤 손으로 고침). 표에 없던 어긋남(10-05, 10-08, 10-12)도 엔진 값으로 맞추고 #851에 결과를 남깁니다. `dayKind`를 일부러 덮은 날(`DAY_KIND_OVERRIDES`)은 화면 사례용이라 그대로 둡니다.

## 5. 경계와 데이터 흐름

* **계약 → 생성 코드:** IA(`ia.g.dart`), ARB, API 클라이언트, 토큰은 생성기로만 바꿉니다. 손으로 고치지 않습니다.
* **컴포넌트:** `lib/design/components/<계약 파일 이름>/`에 계약 id와 같은 이름으로 둡니다(`hanja_tag.dart`는 `sentence/`, `luck_pillar.dart`는 `saju/`). 각 컴포넌트는 계약의 `states.loading.skeleton` 뼈를 자기 파일에 갖고, 화면은 그 뼈를 실제 배치대로 놓습니다(V66).
* **시트:** `tag-sheet`, `color-rule-sheet`는 `sheet_registry.dart`에 등록하고 `DepthSheets`(또는 달력 시트 모음)에 여는 함수를 둡니다. `explain-sheet`는 용어 뜻, ui 문장 본문, 덧붙일 위젯(`stage-strip`), 모아보기 링크(`diaryLink`)를 받는 하나의 본문으로 합칩니다.
* **오늘 화면 표시 모델:** `TodayDisplay`에서 이유 줄과 행운 태그 칩을 빼고 음력, 일진, 십성 묶음, 대표 태그를 더합니다.

## 6. 오류 처리

* 선택 필드(`lunar`, `dayStemTenGod`, `evidencePreview`, `basisPreview`)가 없으면 그 칸만 뺍니다(계약의 `noBreakdown`, D112와 같은 방식).
* 닫힌 enum의 새 값(`very_good`)은 생성 코드로 받고, switch는 빠짐없이 다룹니다. 옛 캐시는 지금처럼 모양이 맞지 않으면 버립니다.
* 한자 글자표에 없는 태그 키는 그리지 않고 비치명 오류(Crashlytics)로 남깁니다(A112).

## 7. 테스트

* **계약 테스트:** `component_contract_test.dart` 등은 5.0.0 JSON을 읽도록 고치고, 새 컴포넌트마다 계약 값 대조를 더합니다. 지운 부품을 기대하는 단언은 지웁니다.
* **컴포넌트:** 새 컴포넌트마다 위젯 테스트와 golden(라이트, 다크, 큰 글자). golden은 Docker `tool/goldens_linux.sh`로만 만듭니다.
* **화면과 흐름:** 화면마다 상태(IA `states`) 테스트, 흐름 테스트(`test/flows/`)의 Covers 선언, `ia_coverage` ratchet이 줄지 않게.
* **버그:** #796 다섯 건은 실패하는 재현 테스트를 먼저 commit 단위 안에서 쓴 뒤 고칩니다.
* **origin 대조:** `test/screenshots/screens_test.dart` 사례를 화면 10개에 맞춰 더하고 `tool/screens_linux.sh`로 찍어 origin과 나란히 봅니다.
* **기기:** 바뀐 흐름 파일만 `tool/patrol_local.sh`로 돌립니다.

## 8. 위험

* 시트 안쪽 24와 핸들 자리, dialog 버튼 구조, `quiet` 52, 아이콘 크기 규칙은 거의 모든 golden을 바꿉니다. 단계 2 끝에서 golden을 한 번에 다시 만들고 눈으로 확인합니다.
* `page.push`는 전환 시간에 기대는 테스트(pumpAndSettle, Patrol)의 타이밍을 바꿉니다.
* 공용 글줄 skeleton을 없애면 skeleton을 주지 않던 화면 8곳이 바로 걸립니다. 기본값을 남긴 채 화면별로 옮기고 마지막에 기본값을 지웁니다.
* 작업 중 다른 PR이 계약을 또 바꾸면 이 브랜치에서 다시 따라잡습니다(drift #810에 원인이 더해짐).
