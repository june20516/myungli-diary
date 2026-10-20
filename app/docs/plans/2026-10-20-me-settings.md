# app 나·설정 Implementation Plan (계획 6)

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** fake 모드에서 회원이 `me` 탭(`my-saju`)에서 일간·용신·행운 색을 보고, "근거 보기"로 `saju-chart`(원국표·오행 분포·용신 판정 근거 / 만세력·대운·세운)를 엽니다. 톱니로 `settings`에 가서 알림 시각·언어를 바꾸고, `profile-edit`으로 호칭·출생 정보를 고칩니다(무거운 변경은 확인 창 뒤 다시 계산). 로그아웃, `account-delete`, `legal`(약관·개인정보·오픈소스 고지)도 씁니다.

**Architecture:**
* `lib/features/me/`: data(차트 저장소·사주 기반 영구 캐시)·application(차트·근거 주제·설정 값)·presentation(`my-saju`·`saju-chart`·`settings`·`legal`).
* `lib/features/profile/`: `profile-edit`·`account-delete`와 프로필 수정 흐름. 계획 2의 수정 모드 입력 화면(`?mode=edit`, `pop(값)`, A19)을 그대로 씁니다.
* 새 컴포넌트:
  * `settings-row`: `lib/design/components/action/`
  * `saju-pillars`·`ohaeng-bar`·`manse-table`·`daeun-table`과 요소 `ohaeng.cell`·`tag.me`·`highlight.current`·`mark.caution`: `lib/design/components/saju/`·`elements/`
* 근거 시트와 잠금 해제 흐름은 `EvidenceSubject`에 차트 주제를 더해 그대로 씁니다(A26).

**Tech Stack:** 계획 5와 같음(Flutter, Riverpod 3.x 코드 생성 없음, go_router, Dio 생성 클라이언트, drift, `intl`, `url_launcher`). 새 패키지 없음.

**Spec:**
* 제품 결정 D79: 기본 깊이 설정 없음(IA v4)
* `app/docs/specs/2026-10-13-app-architecture-design.md`: §4.4 사주 기반 영구 캐시, §5 사주 변경의 무게, §10 계획 6
* 화면: IA `docs/ia/screens.json` v4(`my-saju`·`saju-chart`·`settings`·`profile-edit`·`account-delete`·`legal`)
* 컴포넌트: `docs/identity/design/components/saju.json`·`.md`, `action.json`(`settings-row`), `elements.json`, `today.json`(`lucky-card`), `feedback.json`(`dialog`·`notice-banner`)
* REST: `server/api/openapi.yaml` 1.0.0-draft.8(`getChart`·`updateProfile`·`getProfile`·`deleteMe`·`logout`·`getMe`)
* 제품 결정: D15·D16·D18·D28·D29·D36·D37·D53·D60·D61·D64

## 시작 전

* 브랜치 `app/me-settings`(`origin/main`에서 `--no-track`, 같은 이름 원격 추적, 만들어 둠).
* drift #322(PR #320, IA v4: `settings.depth.desc` 제거)는 첫 commit에서 IA 생성 코드와 커버리지를 다시 만들어 맞췄습니다. PR 본문에 `Closes #322`.
* #316(D79): writing #317이 원고를 빼면 `import_writing_arb.dart`로 `settingsDepthDesc`·`depthDefaultLabel`·`depthSurface`·`depthEvidence`를 정리합니다(`depthExplain`은 남음). 그 전에 이 계획이 끝나면 PR 본문에 `참고 #316`.
* 열린 drift가 있으면 첫 commit에서 맞춥니다(세션 시작 때 `gh issue list --label drift`).
* 검사는 `app/CLAUDE.md` "검사" 절을 따릅니다. 로컬 Patrol은 `tool/patrol_local.sh`입니다.

## 외부 대기 (이 계획은 기다리지 않고 진행)

| 대기 | 요청 | 기다리는 동안 |
| --- | --- | --- |
| `my-saju` 문장(`chart.ilgan_head`·`ilgan_body`·`yongsin_summary` 원고 있음)을 담을 `Chart` 필드가 계약에 없음 | server(Task 1에서 엶, #329 닫힘) | A55: draft.10(#344)에서 `Chart.ilganHead`·`ilganBody`·`yongsinSummary`(선택)로 해제했습니다. 필드가 없으면 문장 자리는 그리지 않고, 일간 이름·용신·행운 색은 `Chart`와 용어 사전으로 그립니다 |
| 이용약관·개인정보 처리방침 문서의 주소 | 지휘(Task 1에서 엶, #330 닫힘) | A61: 답(D80)에 따라 주소는 `AppConfig.legal`에서 받습니다(draft.10). 받는 동안 두 줄은 비활성입니다. 오픈소스 고지는 앱 안에서 엽니다 |

## 이 계획이 정하는 것 (계약 사이 빈칸)

| 빈칸 | 정한 것 |
| --- | --- |
| `my-saju`의 content 슬롯 3개에 계약 필드가 없음 | **A55:** `my-saju`는 위에서부터 이렇게 그립니다. ① 일간 표지(`Chart.pillars.day.stem`의 용어 사전 이름, 용어 토큰 → `explain-sheet` `stem.<값>`) ② 슬롯 `my-saju.ilgan.head`·`ilgan.body`(계약 필드가 생기면 `sentence-block` `card`, 그 전에는 그리지 않음) ③ 용신과 행운 색 `lucky-card`(용신·희신 오행 이름과 `color.<element>`, 용어 토큰 → `explain-sheet` `element.<값>`) ④ `my-saju.yongsin.body`(②와 같은 규칙) ⑤ `depth-link` "근거 보기" → `saju-chart`. 시간 모름이면(`Chart.notices`에 `time_unknown`) 맨 위에 `notice-banner` `time-unknown` |
| `getChart` 캐시 | **A56:** spec §4.4 그대로 사주 기반 영구 캐시입니다(`CacheKind.chart`, 키 = 계정 + 사주 지문 + 언어 + 연도). 프로필 사본이 없으면 캐시 없이 응답만 씁니다(A24와 같음). `evidenceAccess: locked`로 받은 차트는 권한이 생기면 다시 받습니다(달력 A32와 같은 `lockedKeys`). `rulesetVersion`은 `observeRulesetVersion`에 넘깁니다 |
| `saju-chart` 두 탭의 구성 | **A57:** `segmented` 두 항목. "원국"은 `saju-pillars` → `ohaeng-bar`(`elementWeights`를 목·화·토·금·수 순서로, 값은 소수 한 자리) → 용신 판정 근거 줄(`saju-chart.yongsin.basis`, 잠기면 `sentence-block` locked + "열기" → `evidence-sheet` locked). "만세력"은 `manse-table` → `daeun-table`(지금 대운·올해 세운은 기기 오늘 기준, 처음 열 때 지금 대운이 보이게 가로 위치를 맞춤, 움직임 없음). 탭은 화면을 떠났다 와도 기억하지 않고 "원국"부터입니다 |
| 원국 개인 해석("내 사주에서는", D60)의 자리 | **A58:** `saju-chart`의 용어 토큰은 `explain-sheet`를 열고, 그 시트의 "근거 보기"가 `evidence-sheet`를 엽니다. 근거 시트는 누른 용어의 (`kind`, `position`, `index`, `shinsal`)과 같은 `Chart.personalReadings` 항목을 보이고, 잠겨 있으면 잠금 안내와 해제 흐름(A26)입니다. 이 경로는 차트 근거 주제 `ChartEvidenceSubject`로 엽니다 |
| 설정 값의 출처와 저장 | **A59:** 알림 시각은 `Profile.notification`, 언어는 `Profile.language`이고 바꾸면 `updateProfile`(PATCH, 그 필드만) 뒤 응답을 새 사본으로 둡니다. 저장 중에는 그 줄이 비활성이고, 실패하면 오류 toast와 이전 값입니다. 알림 시각은 `time-picker` `notify` half 시트(5분 단위, 끄기 포함). 알림을 처음 켜면 OS 권한을 묻습니다(계획 2 `PushPermission`, 거절하면 `disabled`로 저장). 광고 제거 줄은 `Me.adFree`(활성이면 `settingsAdFreeLabelActive({date})`)이고 누르면 `ad-free`(계획 7 전에는 대기 화면)입니다 |
| 앱 언어 | **A60:** 앱 언어는 프로필 사본의 `language`, 사본이 없으면 기기 로케일입니다(`localeProvider`가 사본을 봄). 설정에서 바꾸면 PATCH 성공 뒤 앱 전체가 그 언어로 다시 그려지고, 언어별 캐시는 키가 달라 자연히 새로 받습니다. 한국어가 아닌 언어로 바꾸고 출생지가 `not_asked`면 `settings.language.birthplace-notice` 시트(버튼 → `birthplace` 수정 모드)를 띄웁니다(D29) |
| 기본 깊이 | **D79(#315·#316, 지휘 결정):** 기본 깊이 설정을 없앱니다. 깊이는 입구별로 고릅니다(용어 → 풀이, 근거 보기 → 근거). `settings`에 깊이 줄과 `segmented`가 없습니다(IA v4). |
| `legal` 문서 | **A61(D80으로 고침):** 줄 셋. "이용약관"·"개인정보 처리방침"은 `getAppConfig` 응답의 주소(`AppConfig.legal`, 루트 D80, 계약 draft.10)에 화면 언어 `?lang=ko\|en\|ja`를 붙여 외부 브라우저(`ExternalBrowser` 경계)로 엽니다. 주소는 상수 파일로 두지 않고 출처는 `legalLinksProvider`(`lib/app/entry/legal_links_provider.dart`) 하나입니다. 받는 동안 두 줄은 비활성이고, 받지 못하면 오류 toast와 누르면 다시 받기입니다. "오픈소스 라이선스"는 Flutter `LicensePage`입니다. GeoNames(CC BY 4.0, #312)와 Pretendard·글꼴 고지는 `LicenseRegistry.addLicense`로 더합니다(`lib/app/licenses.dart`) |
| 사주 변경 흐름 | **A62:** `profile-edit`은 줄마다 지금 값을 보이고(사본 기준), 누르면 그 입력 화면을 수정 모드로 엽니다(`extra` = 지금 값). 돌아온 값은 바로 저장하지 않고 화면 안 변경으로 듭니다. 호칭만 바뀌면 바로 PATCH합니다(가벼운 변경). 무거운 항목(생일·시간·성별·출생지)이 바뀌었으면 하단 저장 버튼이 켜집니다. 누르면 `dialog`(`profile-edit.recalc.confirm`, 기본 선택 취소, 본문 `{before} → {after}`는 바뀐 항목만 ` · `로 이음)를 띄웁니다. 확정하면 PATCH 뒤 사주 기반 캐시(달력·차트·그날)를 지우고 `my-saju`로 갑니다(`go`). 실패하면 `profile-edit:error`(`notice-banner` + 다시 시도), 바꾼 값은 남깁니다. 사본이 없으면(새 기기·재설치) 화면을 열 때 `getProfile`로 채웁니다(#312, A18) |
| 계정 삭제 | **A63:** `account-delete`의 버튼은 `dialog` `destructive` 뒤 `deleteMe`(202)이고, 성공하면 `revokeAndSignOut`으로 로컬 로그아웃해 진입이 `welcome`으로 갑니다. 실패하면 `account-delete:error`(오류 toast, 버튼 다시 시도). 로그아웃은 `settings`의 `dialog`(`settings.logout.confirm`) 뒤 `revokeAndSignOut`입니다 |
| 사주 표 칸의 글자(사전 원고에 천간·십성·12운성·신살 이름이 아직 없음, writing W1) | **A65:** 천간 10·지지 12의 한자와 오행은 언어와 상관없는 고정 값이라 app 표(`lib/features/me/model/ganji.dart`)로 둡니다. 칸의 독음·용어 이름(십성·12운성·신살·지장간)은 용어 사전 `values`에서 읽습니다. 없으면 사전 `hanja`, 그것도 없으면 그 자리를 비웁니다(키를 그대로 보이지 않음). 용어 토큰은 이름이 있을 때만 누를 수 있습니다 |
| IA·writing에 없는 문구 | **A64:** app 임시 ARB(A7 방식, `@키.description`에 `임시`) 22개: 설정 `settingsNotifyLabel`·`settingsNotifyOff`·`settingsLanguageLabel`·`settingsLogoutLabel`, 정보 수정 `profileEditBirthplaceKorea`, 사주 표 `sajuChartTabNatal`·`sajuChartTabLuck`·`sajuPillarHour`·`Day`·`Month`·`Year`·`manseRowHiddenStems`·`manseRowTwelveStages`·`manseRowShinsal`·`sajuTagMe`·`daeunTagNow`·`seunTagThisYear`·`daeunTableLabel({age})`·`ohaengBarItem({element},{count})`, 약관 `legalTermsLabel`·`legalPrivacyLabel`·`legalLicensesLabel`. 줄 이름 중 다른 화면 제목과 같은 것(정보 수정·계산 기준·약관·정책·계정 삭제·광고 제거, 호칭·생일·태어난 시간·성별·출생지)은 그 원고를 다시 쓰고, 언어 이름(한국어·English·日本語)은 번역하지 않는 자기 이름이라 코드 상수입니다. writing에 목록을 알립니다 |

## Global Constraints

* 기반·계획 2~5 plan의 Global Constraints를 모두 따릅니다.
  * 경고 0, 생성 코드는 손대지 않습니다. 토큰은 의미 역할로만 씁니다.
  * Material 효과는 끄고 스피너는 쓰지 않습니다. 문구는 ARB를 거칩니다.
  * IA id를 Key와 Semantics `identifier`로 붙입니다.
  * 주석은 한국어, commit은 `feat(app):`입니다. TDD로 진행합니다.
  * D64: 출생 정보·호칭을 crash 기록에 싣지 않습니다.
* 의존 방향은 presentation → application → data → core입니다. feature끼리는 application provider와 `model/`로만 잇습니다(`feature_layering_test` 허용 목록은 빈 채로).
* 컴포넌트 변형·상태 id는 명세 그대로 enum이고 `ComponentSpec`으로 대조합니다. 새 컴포넌트는 golden(light·dark × ko·ja × 1.0·1.3·2.0)과 Widgetbook use case를 둡니다.
* 값은 `saju.json` 그대로입니다.
  * `saju-pillars`: 열 순서 시·일·월·연, 간격 6, `ohaeng.cell` `pillar`(높이 66), 일간 테두리 `action.primary` 2px 안쪽, '나' 꼬리표는 칸 밖 층, 시간 모름이면 시주 점선 빈 칸, 글자 크기 1.3배에서 멈춤
  * `ohaeng-bar`: 높이 10, `radius.full`, 사이 2, 범례 5열, 0개는 막대 칸 없음 + 견본 0.35
  * `manse-table`: 행 머리 너비 52, 선 1px `line`, `ohaeng.cell` `mini`
  * `daeun-table`: 기둥 52·사이 4, 나이는 한국식(`startAgeKorean`), 세운 5×2, 지금·올해는 `highlight.current` + `tag.status`, 낙관 윤곽 없음
  * `settings-row`: 높이 52 이상, 좌우 16, 묶음 `bg.sheet` `radius.md` 사이 20, 1px 선 안쪽 16, 변형 `navigate`·`value`·`toggle`·`destructive`(`mark.caution`, 빨간색 없음)
* 근거 데이터(표·만세력·대운)는 무료이고, 판정 근거·원전·원국 개인 해석만 잠깁니다(D60). 잠긴 내용은 server가 보내지 않습니다.
* **재사용·확장·사용감(사용자 지시):**
  * `ohaeng.cell`은 원국표·만세력·대운 표가 한 요소를 씁니다.
  * 설정 줄은 `settings`·`profile-edit`·`legal`이 같은 `settings-row`입니다.
  * 근거 시트·잠금 해제는 오늘과 같은 흐름입니다.
  * 무거운 변경은 확인 창, 가벼운 변경은 바로 저장입니다.
* 공개 저장소(D74): 가격·수익 수치, 비공개 경로 링크를 적지 않습니다.

## Review Focus

1. **무거운 변경 실패:** 저장이 실패하면 바꾼 값과 화면이 그대로 남습니다. 이전 사주 캐시도 지워지지 않아, 다시 시도하거나 취소하면 이전 풀이가 보입니다.
2. **두 번 누르기:** 무거운 변경 확인을 빠르게 두 번 눌러도 PATCH는 한 번입니다. 계정 삭제 버튼도 `deleteMe`는 한 번입니다.
3. **출생지 안내:** 언어를 바꾸는 PATCH가 실패하면 앱 언어는 그대로입니다. 출생지 안내 시트도 성공했을 때만 뜹니다.
4. **올해와 지금 대운:** 기기 날짜가 해를 넘겨도(자정 넘어 화면 열기) 세운 표의 '올해'와 지금 대운 강조가 새 오늘을 따릅니다. 캐시 키의 연도도 바뀌어 새 세운을 받습니다.
5. **잠금 해제 뒤 다시 받기:** `saju-chart`에서 보상형 광고로 잠금을 풀면 차트를 다시 받아 용신 판정 근거와 개인 해석이 열립니다. 오늘 화면의 잠금도 함께 풀린 상태입니다(같은 권한).

---

### Task 1: 결정 기록, 임시 문구, 다른 단위 요청

**Files:** Modify `app/docs/decisions.md`, `lib/core/l10n/arb/app_{ko,en,ja}.arb`, `test/contract/app_bar_title_contract_test.dart`(`_allowedTemporaryKeys`)

- [x] A55~A63를 위 표 문장으로 적습니다.
- [x] A64 임시 키를 세 ARB에 더하고(`@키.description`에 `임시`) `flutter gen-l10n`, 허용 목록에 더합니다.
- [x] Issue 셋을 엽니다(`gh issue create`, 마일스톤 A1).
  * server(`kind:request`): `Chart`에 `ilganHead`·`ilganBody`·`yongsinSummary`(`SlotText`, 슬롯 `chart.ilgan_head`·`ilgan_body`·`yongsin_summary`, 앞의 것만 호칭) 추가
  * 지휘(`kind:request`): 약관·개인정보 처리방침 문서 주소와 호스팅 주체
  * writing(`kind:request`): A64 임시 키 목록
- [x] commit

### Task 2: 차트 fixture·저장소·캐시·근거 주제

**Files:**
* Create `tool/gen_chart_fixture.py`, `fixtures/member/getChart.json`, `fixtures/evidence-unlocked/getChart.json`, `lib/features/me/data/chart_repository.dart`, `lib/features/me/application/chart_providers.dart`
* Modify `lib/core/storage/cache_store.dart`(`CacheKind.chart`), `lib/features/depth/application/evidence_unlock_controller.dart`(`ChartEvidenceSubject`)
* Test `test/features/me/chart_repository_test.dart`, `test/features/me/chart_evidence_subject_test.dart`

**Interfaces:**
* Produces:
  * `chartProvider`: `AsyncNotifierProvider<ChartController, Chart>`, `refreshQuietly()`
  * `ChartEvidenceSubject implements EvidenceSubject`(`const new()`)
  * `personalReadingOf(Chart, {required PersonalReadingKindEnum kind, Position? position, int? index, ShinsalKind? shinsal}) → PersonalReading?`
  * `chartYearProvider`(기기 오늘의 연도)

- [x] fixture: core `compose_chart`로 member 프로필(양력 1990-05-15 14:30, 여성)의 2026년 차트를 만듭니다. 문장(`yongsin.basis`, `personalReadings`)은 writing 슬롯 형식의 대역 문장이고, `member`는 locked(개인 해석·근거 없음), `evidence-unlocked`는 unlocked입니다. 생성 방식과 엔진 값이 아닌 것은 `gen_calendar_fixtures.py`처럼 머리 주석에 적습니다. fixture 검증 통과.
- [x] 테스트:
  * 캐시 키에 연도·언어·지문이 들어감
  * 사본이 없으면 캐시를 읽거나 쓰지 않음
  * locked로 받은 키는 권한이 생기면 다시 받음
  * `rulesetVersion` 관찰
  * `personalReadingOf`가 kind·position·index·shinsal로 찾음
  * `ChartEvidenceSubject.evidenceOf('saju-chart.yongsin.basis')`가 `Chart.yongsin.basis.evidence`
- [x] 구현, commit

### Task 3: `settings-row`

**Files:** Create `lib/design/components/action/settings_row.dart`(`SettingsRow`, `SettingsGroup`); Test `test/design/action/settings_row_test.dart`, golden, Widgetbook

- [x] 테스트:
  * 변형별 부품: `navigate` 화살표 / `value` 값 + 화살표 / `toggle` 스위치(Semantics switch, 켜고 끌 때 selection 햅틱) / `destructive` `mark.caution` + 굵은 글자 + 화살표 없음
  * `disabled` 글자색과 누를 수 없음, 높이 52·눌림 대상 48 이상
  * 묶음 안 1px 선 안쪽 16, 묶음 제목
  * 스크린리더 라벨은 "글자 + 값"
- [x] 구현(`mark.caution` 요소는 `lib/design/elements/caution_mark.dart`), golden, commit

### Task 4: `ohaeng.cell`·`tag.me`·`highlight.current`와 `saju-pillars`

**Files:** Create `lib/design/elements/ohaeng_cell.dart`, `tag_me.dart`, `lib/design/components/saju/saju_pillars.dart`; Test 각 `_test.dart`, golden

- [x] 테스트:
  * `OhaengCell(element, size: pillar|mini, hanja, reading)`의 오행별 바탕·글자(`ohaeng_colors.dart`), 크기 66·30
  * `SajuPillars`의 열 순서 시·일·월·연, 천간 위·지지 아래 십성 `term-token` label(지지는 정기 기준), 일간 테두리와 '나' 꼬리표(칸에 잘리지 않음)
  * 시간 모름이면 시주 점선 빈 칸
  * 표 Semantics(기둥 이름·한자·독음·오행·십성), 글자 크기 1.3배에서 멈춤
- [x] 구현, golden, commit

### Task 5: `ohaeng-bar`

**Files:** Create `lib/design/components/saju/ohaeng_bar.dart`; Test, golden

- [x] 테스트:
  * 막대 칸 순서 목·화·토·금·수, 너비가 값에 비례
  * 0인 오행은 칸 없음 + 견본 0.35·개수 `text.secondary`
  * 범례 5열(견본 12·이름·개수)
  * 접근성 라벨 "목 N, 화 N, …"
- [x] 구현, golden, commit

### Task 6: `manse-table`

**Files:** Create `lib/design/components/saju/manse_table.dart`; Test, golden

- [x] 테스트:
  * 열 순서는 원국표와 같음, 행 머리 52(지장간·12운성·신살 `term-token` label → 누르면 콜백)
  * 지장간 한자(`font.family.hanja`)와 독음
  * 신살이 여럿이면 칸 안 여러 줄, 시간 모름이면 시주 열 빈 칸
  * 표 Semantics(행 머리 읽음), 1.3배에서 멈춤
- [x] 구현, golden, commit

### Task 7: `daeun-table`

**Files:** Create `lib/design/components/saju/daeun_table.dart`; Test, golden

- [x] 테스트:
  * 대운 기둥 52·사이 4, 가로 스크롤, 한국식 나이와 시작 연도
  * 지금 대운은 `highlight.current` + `tag.status` "지금", 처음 열 때 지금 대운이 보이는 위치(움직임 없음)
  * 세운 5×2는 지금 대운 10년, 올해 칸 강조 + "올해"
  * 낙관 윤곽이 없음
  * Semantics "대운 N세부터 …"와 지금·올해 낭독
- [x] 구현, golden, commit

### Task 8: `my-saju`

**Files:** Create `lib/features/me/presentation/my_saju_screen.dart`; Modify `screen_registry.dart`, `test/contract/ia_pending.dart`, `app_bar_title_contract_test.dart`; Test `test/flows/my_saju_flow_test.dart`

- [x] 테스트:
  * 제목 `my-saju.bar.title`(탭 루트, 톱니 → `settings`)
  * A55 순서: 일간 표지 → 용신·행운 색 `lucky-card` → "근거 보기" → `saju-chart`
  * 일간·오행 용어 → `explain-sheet`
  * `loading` skeleton, `error` 다시 시도, `time-unknown` 배너
  * 하단 `ad-banner`
  * 문장 슬롯 필드가 없으면 그 자리를 그리지 않음
- [x] 구현, IA 대조·커버리지 선언, commit

### Task 9: `saju-chart`

**Files:** Create `lib/features/me/presentation/saju_chart_screen.dart`; Modify 등록·대기 목록; Test `test/flows/saju_chart_flow_test.dart`

- [x] 테스트:
  * 제목, 두 탭(A57) 전환
  * "원국" 탭: 원국표·오행 분포·용신 판정 근거(unlocked면 문장, locked면 `lock.veil` + "열기" → `evidence-sheet` locked → 잠금 해제 흐름 뒤 다시 받기, Review Focus 5)
  * "만세력" 탭: 만세력 표·대운 표(지금·올해)
  * 용어 토큰 → `explain-sheet` → "근거 보기" → 개인 해석(A58, unlocked 시나리오)
  * `time-unknown`: 시주 빈 칸 + `saju-chart.time-unknown.notice`
  * `loading`·`error`
  * 올해가 바뀌면 새 연도로 다시 받음(Review Focus 4)
- [x] 구현, commit

### Task 10: `settings`와 앱 언어

**Files:** Create `lib/features/me/presentation/settings_screen.dart`, `lib/features/me/application/settings_controller.dart`; Modify `lib/core/api/api_providers.dart`(`localeProvider`가 사본 `language`를 봄); Test `test/flows/settings_flow_test.dart`

**Interfaces:** Produces `SettingsController.setNotification(NotificationSetting)`·`setLanguage(Language)` → `Future<void>`(실패는 `AppError`)

- [x] 테스트:
  * 묶음과 줄(A59, D79로 기본 깊이 줄 없음)
  * 알림 시각 시트 → PATCH `notification` → 값 표시, 처음 켤 때 권한, 거절이면 `disabled`
  * 언어 시트 → PATCH `language` → 앱이 그 언어로, 실패하면 그대로(Review Focus 3)
  * 한국어 밖으로 바꾸고 출생지 `not_asked`면 출생지 안내 → `birthplace` 수정 모드
  * 광고 제거 줄(활성이면 날짜) → `ad-free`
  * 정보 수정 → `profile-edit`, 계산 기준 → `calc-basis`, 약관·정책 → `legal`, 계정 삭제 → `account-delete`
  * 로그아웃 확인 → `revokeAndSignOut` → `welcome`
- [x] 구현, 등록(`settings` → `calc-basis` 출구, 계획 IA v3 넘김분), commit

### Task 11: `profile-edit`

**Files:** Create `lib/features/profile/presentation/profile_edit_screen.dart`, `lib/features/profile/application/profile_edit_controller.dart`; Test `test/flows/profile_edit_flow_test.dart`

- [x] 테스트:
  * 줄마다 지금 값, 누르면 수정 모드 입력 화면(`extra` 지금 값), 돌아온 값이 화면 변경으로 남음
  * 호칭만 바꾸면 바로 PATCH, 확인 창 없음
  * 무거운 변경 → 저장 → 확인 창(기본 취소, 바뀐 항목만 `before → after`)
  * 확정하면 PATCH 한 번(Review Focus 2) → 사주 캐시 지움 → `my-saju`
  * 실패하면 `error` 배너와 값 유지, 이전 캐시 유지(Review Focus 1)
  * 사본이 없으면 `getProfile`로 채워 엶(#312)
- [x] 구현, commit

### Task 12: `account-delete`·`legal`

**Files:** Create `lib/features/profile/presentation/account_delete_screen.dart`, `lib/features/me/presentation/legal_screen.dart`, `lib/app/entry/legal_links_provider.dart`(D80: `AppConfig.legal`, 상수 파일 없음), `lib/app/licenses.dart`; Test `test/flows/account_delete_flow_test.dart`, `test/features/me/legal_screen_test.dart`

- [x] 테스트:
  * 계정 삭제: 제목·안내·버튼 → `destructive` 확인 → `deleteMe` 한 번 → 로그아웃 정리 → `welcome`, 실패하면 `error` toast와 다시 시도
  * `legal`: 줄 셋, 주소를 받는 동안 두 문서 줄 비활성·받지 못하면 오류 toast와 다시 받기, `?lang=` 붙이기, 오픈소스 라이선스 페이지에 GeoNames 고지(A61, #312)
- [x] 구현, commit

### Task 13: 흐름·E2E·문서

- [x] 흐름 테스트: 나의 사주 → 근거 보기 → 사주 표(두 탭) → 용어 → 풀이 → 근거; 설정 → 정보 수정 → 생일 바꿔 저장 → 확인 → 나의 사주 새 원국; 설정 → 로그아웃 → welcome.
- [x] Patrol 흐름 하나(`patrol_test/me_test.dart`, `tool/patrol_local.sh`), 커버리지 `--update-baseline`.
- [x] 전체 검사(format·analyze·dart analyze·widgetbook·test·golden·coverage·check-arb·fixture), `CLAUDE.md` 현재 상태·다음 할 일, README(새 fixture), PR(`Closes #312`, 대기 Issue는 `참고`).
