# app 오늘·깊이 시트 Implementation Plan (계획 3)

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** fake 모드에서 회원이 `today`에서 오늘 풀이(날의 성격, 총운과 좋아요, 행운 카드 4종, 가이드 질문)를 보고, 용어를 눌러 `explain-sheet`, "근거 보기"로 `evidence-sheet`(잠금 4상태, 보상형 광고로 열기)를 열고, `share-preview`에서 오늘 카드 이미지를 공유하게 합니다. 오늘 응답은 그날 캐시로 오프라인에도 보입니다.

**Architecture:** 화면은 `lib/features/today/`(오늘·공유), `lib/features/depth/`(풀이·근거 시트와 잠금 해제), `lib/features/glossary/`(용어 이름), `lib/features/monetization/`(이용권), `lib/features/diary/`(오늘 일기 유무만)에 둡니다. 오늘 응답은 `DailyController` 하나가 캐시 → server 순서로 내보내고, 반응·잠금 해제도 이 controller를 거쳐 화면과 캐시를 함께 바꿉니다. 시트는 route가 아니라 `DepthSheets` 서비스가 `showMyungliSheet`로 열고, IA 대조를 위해 `sheetRegistry`에 등록합니다.

**Tech Stack:** 기반·계획 2와 같음(Flutter stable, Riverpod 3.x 코드 생성 없음, go_router, Dio 생성 클라이언트, drift, `timezone`). 새 패키지는 없습니다(PNG는 `RepaintBoundary.toImage`, 로고 SVG는 기반에서 쓰는 방식을 따름).

**Spec:** `app/docs/specs/2026-10-13-app-architecture-design.md` (§3 시트, §4.4 그날 캐시·잠금 해제, §4.5 시간, §6.5 콘텐츠 문장, §7 보상형 광고·공유, §8 테스트, §10 계획 3). 결정은 `app/docs/decisions.md` A1~A21과 이 계획이 더하는 A22~A27입니다. 화면 내용은 IA `docs/ia/screens.json` v2, 컴포넌트는 `docs/identity/design/components/` 2.2.0(`today.json`·`sentence.json`·`frame.json`), REST는 `server/api/openapi.yaml` 1.0.0-draft.2, 용어 키는 writing `slots/content/glossary.yaml`·`term.yaml`이 기준입니다.

## 시작 전

* 브랜치 `app/today`(`origin/main`에서 `--no-track`으로 만들고 같은 이름으로 push함)에서 작업합니다. 작업 디렉터리는 worktree `../myungli-diary-app`의 `app/`입니다.
* Flutter 명령 앞에 `export PATH="$HOME/development/flutter/bin:$PATH"`를 둡니다.
* `app/CLAUDE.md` "이후 계획으로 넘긴 사항"의 계획 3 항목은 아래 표와 Task 4·11에 모두 들어 있습니다.

## 이 계획이 정하는 것 (계약 사이 빈칸)

결정 번호는 Task 1에서 `app/docs/decisions.md`에 적고, 다른 단위가 바꿔야 하는 것은 Task 1에서 Issue로 보냅니다.

| 빈칸 | 정한 것 |
| --- | --- |
| writing 슬롯은 있으나 `Daily`에 문장 필드가 없음: `today.character.reason`(`character.reason`), `explain-sheet.term.meaning`(`term.meaning`), `explain-sheet.today.reason`(`explain.today_reason`), `evidence-sheet.basis.body`·`source.quote`(`evidence.basis`·`evidence.source`, core #130 대기) | **A22:** 계약에 없는 문장 자리는 그리지 않고 자리도 남기지 않습니다(A20 ②와 같은 방식). 근거 시트는 `unlocked`인데 본문이 없는 구역을 그리지 않습니다. server에 필드 추가를 요청합니다(Task 1). 필드가 계약에 들어오면 fixture와 화면 연결만 더합니다 |
| 시트(`explain-sheet`·`evidence-sheet`·`share-preview`)는 route가 아니라 `screenRegistry`에 없음. IA 대조 테스트는 `screenRegistry`만 봄 | **A23:** `sheetRegistry`(`SheetSpec(id, handledStates, exits)`)를 두고 IA 대조 테스트가 page는 `screenRegistry`, 시트는 `sheetRegistry`에서 상태를 찾습니다. 시트는 `DepthSheets`가 엽니다 |
| 그날 캐시 키에 사주 지문이 필요한데 프로필 사본이 없을 수 있음(새 기기·재설치 회원이 시간대 PATCH에 실패) | **A24:** `getDaily`는 `TimezoneSync.idle`을 기다린 뒤 요청합니다. 사본이 있으면 키 `dailyKey(지문, 사본 language, 날짜)`로 캐시를 먼저 내보내고 server 응답으로 바꿉니다. 사본이 없으면 캐시를 읽지도 쓰지도 않고 server 응답만 씁니다(그때 오프라인이면 `offline` 화면). 캐시는 **오늘 날짜 키만** 보이며 어제 캐시를 오늘로 보이지 않습니다 |
| 반응은 슬롯 단위 PUT·DELETE이고 실패할 수 있음 | **A25:** 누르면 바로 바꿔 보이고(낙관적), 실패하면 되돌리고 오류 toast입니다. 요청 중에 다시 누르면 마지막 의도만 기억했다가 끝난 뒤 server 상태와 다르면 한 번 더 보냅니다. 성공하면 캐시 JSON의 그 슬롯 `reaction`도 고칩니다. 경로의 `slot`은 `SlotText.slot`이고, `reactable == true`인 슬롯에만 버튼을 둡니다(D57: 지금은 총운 첫 문장) |
| 보상형 광고 뒤 권한 확인의 시간·실패 처리 | **A26:** 근거 시트가 열리면 `Ads.loadRewarded(userId: 계정 id)`로 미리 불러 둡니다(null이면 `lockedNoAd`). 끝까지 보면(`RewardEarned`) `unlocking`으로 `getEntitlements`를 2초 간격, 최대 30초 묻고(`rewardPollInterval`·`rewardPollTimeout`, provider로 주입), `insight.active`가 되면 세 구역 skeleton을 보이며 `getDaily`를 다시 받아 `unlocked`입니다. 30초가 지나면 `evidence-sheet.unlock.failed` toast와 `locked`입니다. 닫으면(`RewardDismissed`) 그대로 `locked`, 표시 실패(`RewardFailed`)는 오류 toast와 `locked`입니다. 시트가 닫히면 묻기를 멈춥니다 |
| 행운 카드의 값 이름: 색은 glossary `color.<오행>`, 방향은 glossary 범주가 없음, 집중 시간은 UTC로 옴 | **A27:** 색 이름은 glossary `color.<element>`, 방향 이름은 app 임시 ARB `direction<N>`(8개), 숫자는 그대로, 집중 시간은 `FocusSlot.start`·`end`를 프로필 시간대 `HH:mm`으로 바꿔 `09:30–11:30`, 둘이면 ` · `로 잇습니다. 오늘 화면은 `getDaily`와 `getGlossary`가 모두 있어야 그립니다 |
| `today`의 출구 `day-sheet`(오늘 일정 한 줄, `event-row`)·배너(`ad-banner`)·근거 시트의 `saju-pillars`와 "내 사주에서는" | 오늘 일정 줄과 `day-sheet`는 계획 4(달력 컴포넌트 묶음), 배너는 계획 7, 원국표와 개인 해석은 계획 6에서 넣습니다. `today`는 `pendingExitScreens`에 남깁니다(계획 4가 지움) |
| `notices` 중 화면 상태가 있는 것은 `time_unknown`뿐 | `time_unknown`만 `notice-banner` `timeUnknown`으로 보이고(문구는 notice `text`의 글자를 이은 것), 나머지 notice는 계획 6(`calc-basis`·`saju-chart`)에서 다룹니다 |
| "근거 보기" 링크와 근거 시트 제목에 슬롯이 없음 | app 임시 ARB `depthLinkEvidence`("근거 보기"), `evidenceSheetTitle`("오늘 풀이의 근거")를 두고 writing에 알립니다(Task 1) |
| 가이드 질문 카드의 쓰기 전·후 | `getDiary(오늘)`이 200이면 `after`(출구 `diary-view`), 404면 `before`(출구 `diary-edit`), 그 밖의 실패는 `before`로 그립니다. 일기 화면은 계획 5까지 자리표시 화면입니다 |

## Global Constraints

* 기반·계획 2 plan의 Global Constraints를 모두 따릅니다(`app/docs/plans/2026-10-13-foundation.md`, `2026-10-14-onboarding-login.md`). 경고 0, 생성 코드 손대지 않음, 토큰 의미 역할만, Material 효과 끔·스피너 금지, ARB 경유, IA id를 Key와 Semantics `identifier`로, 한국어 주석과 `feat(app):` 형식 commit, TDD, D64가 그 내용입니다.
* 의존 방향은 presentation → application → data → core이고, feature끼리는 application provider로만 참조합니다(spec §2).
* **재사용·확장·사용감(사용자 지시):**
  * 화면 안에 일회성 위젯을 두지 않습니다. 두 곳 이상에서 쓸 모양(시트 상태 틀, 값 칩, 날짜·시간 표시 등)은 `design/components/`나 feature 공용 위젯으로 뽑습니다. 이 계획의 시트·카드는 계획 4~6(`day-sheet`, `my-saju`, `saju-chart`, `tag-diary`)이 다시 씁니다.
  * 다음 계획이 기능을 더할 자리를 인터페이스로 둡니다. 예: `DepthSheets`는 어느 화면에서든 같은 호출로 열고, 잠금 해제·반응·캐시는 controller 한 곳을 거치며, 계약 필드가 늘면(A22) 화면이 아니라 표시 값 변환 한 곳만 고칩니다.
  * 사용감 인터랙션을 빠뜨리지 않습니다: 눌림(`press.ink`), 나타남·사라짐(`appear.seep`·`disappear.seep`), 햅틱(selection·light·medium, 명세에 적힌 곳), 처리 중 점 숨쉬기와 skeleton, 오류 toast, 상태가 바뀔 때 스크린리더 알림, 동작 줄이기 설정. 컴포넌트 명세의 `states`·`haptic`·`a11y`를 task마다 대조합니다.
* content 슬롯은 `SentenceBlock`(`RenderedText`)으로, ui 슬롯은 일반 `Text`로 그립니다(A21). 용어 조각은 IA에 `term-token`이 있는 화면(`today`)에서만 칩입니다(V28, `SentenceBlock`이 slotId로 정함).
* 근거 잠금은 응답의 `evidenceAccess`로만 판단합니다. app이 스스로 열지 않습니다(D60).
* 슬롯이 아닌 새 문구는 영역 접두어 lowerCamelCase 임시 키(`direction*`, `depthLinkEvidence`, `evidenceSheetTitle`)이고 ko·en·ja 세 파일에 넣고 `@키.description`에 `임시`를 적습니다.
* "오늘"은 `todayProvider`(프로필 시간대)입니다. 화면이 열린 채 자정을 넘기면 새 날짜로 다시 받습니다(spec §4.5).
* 새 컴포넌트는 `static const ComponentSpec spec`을 두고 `implementedComponents`에 등록하고, Widgetbook 항목과 golden(기반 golden과 같은 조합)을 함께 만듭니다. golden 기준 이미지는 `tool/goldens_linux.sh`로 만듭니다.
* fixture는 `fixtures/<시나리오>/<operationId>.json`이고 CI가 계약 스키마로 검증합니다. 새 시나리오는 `fixtures/scenarios.json`에 `extends`로 더하고 `app/README.md` 시나리오 표에 한 줄씩 적습니다.
* 흐름 테스트는 `test/flows/`에 두고 `pumpApp(tester, scenario: …)`으로 띄우며, 덮는 대상은 `covers(const Covers(exits: ['today>explain-sheet'], states: ['today:offline'], decisions: ['D60']))` 형식으로 적습니다.

## Review Focus

1. 오늘 화면을 연 채 자정을 넘김 → 새 날짜로 `getDaily`를 다시 받고, 그 사이 이전 날짜 응답이 "오늘"로 남지 않아야 합니다(Task 4·8).
2. 오프라인으로 앱을 열었는데 캐시에 어제 응답만 있음 → 어제 풀이를 보이지 않고 `offline` 화면입니다(Task 4).
3. 좋아요를 빠르게 여러 번 누르거나 요청이 실패함 → 화면·server·캐시가 마지막 의도로 맞춰지고, 실패면 누르기 전 상태로 돌아갑니다(Task 9).
4. `rulesetVersion`이 바뀐 응답을 받음 → 새 응답을 쓰기 전에 사주 기반 캐시를 지웁니다(쓰고 나서 지우면 방금 쓴 것도 지워짐)(Task 4).
5. 광고를 본 뒤 권한 확인 중에 시트를 닫음 → 묻기를 멈추고 닫힌 화면에 toast를 띄우지 않습니다. 다음에 열면 server 상태대로 보입니다(Task 11).

---

### Task 1: 결정 기록과 계약 빈칸 요청

**Files:**
- Modify: `app/docs/decisions.md` (A22~A27 행 추가)

**Interfaces:**
- Produces: 결정 A22~A27, Issue 3건(server·writing·design)

- [ ] **Step 1:** `app/docs/decisions.md` 표에 A22~A27을 위 "이 계획이 정하는 것" 표 그대로(날짜 2026-10-15, 분류 화면·데이터, 근거 "계획 3") 더합니다.
- [ ] **Step 2:** Issue를 보냅니다(`gh issue create`, 라벨 `from:app`, `to:<단위>`, 본문은 "무엇이 필요한가 / 왜 / 영향 / 관련").
  * **server, `kind:request`:** `Daily`에 ① `character.reason`(`SlotText`, `character.reason.<dayKind>`) ② 용어 뜻(`term.<용어 id>`)을 받을 곳(예: `getGlossary` 응답의 `meanings` 범주 또는 operation 하나) ③ 용어별 `explain.today_reason` 문장 ④ `SlotText.evidence`에 대응하는 렌더된 `basis`·`source` 문장(`evidenceAccess: locked`면 뺌)을 더해 달라는 요청. 계약만 먼저 병합하면 app은 fixture로 바로 연결한다고 적습니다. 관련: A22, writing #129, core #130.
  * **writing, `kind:request`:** 임시 키 `depthLinkEvidence`·`evidenceSheetTitle`·`directionN`~`directionNw` 원고(ko·en·ja). 관련: A22·A27, #143.
  * **design, `kind:notice`:** 근거 시트 `unlocked`에서 본문이 없는 구역을 그리지 않음(A22), 행운 카드 시간 값 형식 `09:30–11:30 · 13:30–15:30`(A27). 관련: #142.
- [ ] **Step 3:** Commit `docs(app): 계획 3 결정 A22~A27`. Issue 번호를 `app/CLAUDE.md` "보낸 요청"에 적는 일은 Task 13에서 합니다.

### Task 2: 시트 등록부와 깊이 시트 서비스

**Files:**
- Create: `app/lib/app/router/sheet_registry.dart`, `app/lib/features/depth/presentation/depth_sheets.dart`
- Modify: `app/test/contract/ia_contract_test.dart`, `app/test/contract/ia_pending.dart`
- Test: `app/test/features/depth/depth_sheets_test.dart`

**Interfaces:**
- Produces:
  * `final class SheetSpec { const new(this.id, {this.handledStates = const {}, this.exits = const {}}); final String id; final Set<String> handledStates; final Set<String> exits; }`
  * `const Map<String, SheetSpec> sheetRegistry`(이 task에서는 비어 있음. Task 10·11·12가 채움)
  * `typedef ExplainBodyBuilder = Widget Function(String termId, String sourceSlotId)`, `typedef EvidenceBodyBuilder = Widget Function(String slotId)`, `typedef ShareBodyBuilder = Widget Function()`
  * `final class DepthSheets { const new({required this.explainBody, required this.evidenceBody, required this.shareBody}); Future<void> openExplain(BuildContext context, {required String termId, required String sourceSlotId}); Future<void> openEvidence(BuildContext context, {required String slotId}); Future<void> openSharePreview(BuildContext context); }` — `slotId`·`sourceSlotId`는 writing 슬롯 id(`SlotText.slot`, 예 `daily.fortune.head`)
  * `final depthSheetsProvider = Provider<DepthSheets>` — 이 task에서는 세 builder가 빈 `SizedBox`이고, Task 10·11·12가 각각 `ExplainSheet`·`EvidenceSheet`·`SharePreviewSheet`로 바꿉니다. 여는 크기는 explain·share `SheetSize.half`, evidence `SheetSize.full`(`showMyungliSheet`)

- [ ] **Step 1: 실패하는 테스트**
  * `ia_contract_test`: 기존 "pending이 아닌 화면은 handledStates가 IA states와 같다"·ratchet 테스트가 시트(`presentation`이 `half-sheet`·`full-sheet`)는 `sheetRegistry[id]?.handledStates`에서 찾게 바꿉니다. 새 테스트 `'sheetRegistry의 id는 모두 IA 시트 화면이다'`: `sheetRegistry.keys`가 IA의 sheet 화면 id 집합의 부분집합. 새 테스트 `'pending이 아닌 시트는 exits가 IA exits의 대상 집합과 같다'`(`pendingExitScreens`에 시트가 없으므로 등록된 시트만 대조).
  * `depth_sheets_test`: `openExplain`은 `SheetSize.half`, `openEvidence`는 `SheetSize.full`로 열리고, 시트 뿌리에 IA 화면 id(`ScreenIds.explainSheet` 등)가 Key와 Semantics `identifier`로 붙는다. explain 위에서 `openEvidence`를 부르면 두 시트가 겹치고, 닫으면 explain으로 돌아온다.
- [ ] **Step 2:** `flutter test test/contract test/features/depth` → 새 테스트 FAIL.
- [ ] **Step 3:** 구현합니다. 시트 뿌리 id 부착은 `KeyedSubtree`+`Semantics(identifier:)`로 page 화면과 같은 방식입니다(spec §6.6).
- [ ] **Step 4:** 같은 명령 → PASS. 전체 `flutter test --exclude-tags golden` → PASS.
- [ ] **Step 5:** Commit `feat(app): 시트 등록부와 깊이 시트 서비스(A23)`.

### Task 3: 용어 이름 사전

**Files:**
- Create: `app/lib/features/glossary/data/glossary_repository.dart`, `app/lib/features/glossary/application/glossary_providers.dart`, `app/fixtures/member/getGlossary.json`
- Test: `app/test/features/glossary/glossary_repository_test.dart`

**Interfaces:**
- Consumes: `CacheStore`(`CacheKind.glossary`), `restClientProvider`
- Produces:
  * `final class GlossaryNames { const new(this.values); final Map<String, Map<String, String>> values; String? nameOf(String termId); String? valueName(String category, String value); }` — `termId`는 `<범주>.<값>`(첫 `.`에서 나눔)이고 태그는 `tag.<키>`
  * `final class GlossaryRepository { Future<GlossaryNames> load(Language language); }` — 캐시 키는 언어 코드, 저장 값은 `{"etag": …, "body": …}` JSON
  * `final glossaryProvider = FutureProvider<GlossaryNames>`(언어는 프로필 사본 `language`, 없으면 `appLanguageProvider`)

- [ ] **Step 1: 실패하는 테스트** (`glossary_repository_test`, fake server로)
  * `'처음에는 받아서 캐시에 etag와 함께 둔다'`: 요청 헤더에 `if-none-match` 없음, 이후 캐시에 etag가 있다.
  * `'캐시가 있으면 If-None-Match를 보내고 304면 캐시를 쓴다'`: fixture `sequence`가 `[200(ETag "g1"), 304]`일 때 두 번째 `load`의 헤더 `if-none-match == '"g1"'`이고 결과가 첫 응답과 같다.
  * `'오프라인이면 캐시를 쓰고, 캐시도 없으면 OfflineError'`.
  * `'nameOf'`: `nameOf('ten_god.pyeongwan')`이 `values['ten_god']['pyeongwan']`, `nameOf('tag.gwiin')`이 `values['tag']['gwiin']`, 모르는 id는 null.
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 구현합니다. 생성 클라이언트가 304를 예외로 던지면 `DioException.response?.statusCode == 304`를 캐시 사용으로 처리합니다. fixture `getGlossary.json`은 `color`·`element`·`ten_god`·`tag`·`stem`·`branch` 범주와 Task 4 `getDaily` fixture의 용어를 모두 담습니다(ko 이름).
- [ ] **Step 4:** 실행 → PASS. `uv run … tool/validate_fixtures.py`(README 명령) → 통과.
- [ ] **Step 5:** Commit `feat(app): 용어 이름 사전(ETag 캐시)`.

### Task 4: 오늘 응답과 그날 캐시

**Files:**
- Create: `app/lib/features/today/data/daily_repository.dart`, `app/lib/features/today/application/daily_controller.dart`, `app/fixtures/member/getDaily.json`, `app/fixtures/member-time-unknown/getDaily.json`, `app/fixtures/daily-error/getDaily.json`
- Modify: `app/fixtures/scenarios.json`, `app/README.md`(시나리오 표)
- Test: `app/test/features/today/daily_repository_test.dart`, `app/test/features/today/daily_controller_test.dart`

**Interfaces:**
- Consumes: `CacheStore.read/write/observeRulesetVersion`, `dailyKey`, `sajuFingerprint(Profile)`, `cachedProfileProvider`, `timezoneSyncProvider.idle`, `todayProvider`
- Produces:
  * `final class DailyRepository { Future<Daily> fetch(CalendarDate date); Future<Daily?> cached(String key); Future<void> store(String key, Daily daily); Future<void> patchCachedReaction(String key, {required String slot, required bool liked}); }` — `store`는 `observeRulesetVersion(daily.rulesetVersion)`을 **먼저** 부르고 씁니다. `patchCachedReaction`은 캐시 JSON에서 `slot == slot`인 모든 객체의 `reaction`을 `like`로 넣거나 지웁니다
  * `final class DailyView { const new({required this.date, required this.daily, required this.stale}); final CalendarDate date; final Daily daily; final bool stale; }` — `stale`은 server 응답을 받지 못해 캐시를 보이는 중(오프라인 배너)
  * `final dailyControllerProvider = AsyncNotifierProvider<DailyController, DailyView>`; `DailyController.reload()`(캐시 무시, 다시 받기), `DailyController.cacheKey`(사본이 없으면 null)
- [ ] **Step 1: 실패하는 테스트**
  * repository: `'store는 rulesetVersion 관찰 뒤에 쓴다'`(규칙이 바뀐 응답을 저장한 뒤 그 daily 키가 남아 있고 calendar 캐시는 지워짐), `'patchCachedReaction은 그 슬롯의 reaction만 바꾼다'`(fortune.head만 `like`, guide는 그대로; false면 키가 사라짐).
  * controller(`ProviderContainer`, fake server, 고정 시계):
    * `'사본이 있으면 캐시를 먼저 내보내고 server 응답으로 바꾼다'`: 상태가 캐시 응답 → server 응답 순서이고, 마지막 값의 `stale == false`, 캐시가 새 응답으로 바뀜.
    * `'TimezoneSync가 끝난 뒤에 getDaily를 요청한다'`: 동기화 PATCH가 끝나기 전 `callCountOf('getDaily') == 0`.
    * `'사본이 없으면 캐시를 읽지도 쓰지도 않는다'`.
    * `'오프라인이고 오늘 키 캐시가 있으면 stale 캐시'`, `'오프라인이고 어제 키만 있으면 OfflineError'`(Review Focus 2).
    * `'날짜가 바뀌면 새 날짜로 다시 받는다'`: `todayProvider`가 바뀌면 `requestBodiesOf`/경로의 날짜가 새 날짜이고, 상태의 `date`가 새 날짜(Review Focus 1). 시계는 `clockProvider` override로 바꿉니다.
    * `'server 오류면 AppError로 실패하고 reload로 다시 받는다'`(시나리오 `daily-error`).
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 구현합니다. fixture:
  * `member/getDaily.json`: 날짜 `2026-10-13`, `evidenceAccess: locked`, `dayKind: yongsin_day`, `fortune.head`(`reactable: true`, 호칭 덩어리 포함, `term` 조각 하나 `element.wood`), `fortune.tag`, `guide`, 카드 4종(색 `wood`/`yongsin`, 방향 `e`, 숫자 3, 집중 시간 picks 1개 `2026-10-13T09:30:00+09:00`~`11:30`), `tags.featured` 1개, `notices: []`, `rulesetVersion: "r1"`.
  * `member-time-unknown`(extends `member`): `notices`에 `time_unknown`.
  * `daily-error`(extends `member`): 503 `service.unavailable`.
- [ ] **Step 4:** 실행 → PASS. fixture 검증 통과.
- [ ] **Step 5:** Commit `feat(app): 오늘 응답과 그날 캐시(A24)`.

### Task 5: `lucky-card` 컴포넌트

**Files:**
- Create: `app/lib/design/components/today/lucky_card.dart`, `app/widgetbook/lib/…`(기존 항목 위치를 따름)
- Modify: `app/lib/design/components/component_spec.dart`(`implementedComponents`)
- Test: `app/test/design/today_test.dart`, `app/test/design/today_golden_test.dart`

**Interfaces:**
- Produces:
  * `enum LuckyCardVariant { color, direction, number, time }`
  * `final class LuckyItem { const new({required this.variant, required this.name, required this.value, required this.explain, this.swatch}); final LuckyCardVariant variant; final String name; final String value; final RenderedText explain; final Color? swatch; }`
  * `class LuckyCardRow extends StatefulWidget { const new({required this.items, this.interactive = true, this.slotIds = const {}, super.key}); static const ComponentSpec spec; }` — `slotIds`는 변형 → 설명 슬롯 id(`today.lucky-color.body` 등)
- [ ] **Step 1: 실패하는 테스트** (`today_test`): 칩을 누르면 설명이 열리고(`expanded` 알림), 다른 칩을 누르면 설명이 바뀌며 한 번에 하나만 열린다. 같은 칩을 다시 누르면 닫힌다. 칩 높이 34 이상·누름 영역 44 이상. 스크린리더 라벨은 "이름 + 값". `interactive: false`면 눌러도 열리지 않고 Semantics가 button이 아니다. 명세 대조 테스트가 변형 4개를 찾는다. 설명 상자는 슬롯 id를 Key·identifier로 단다.
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 명세 `today.json` `lucky-card` 값(칩 34, `radius.full`, `space.12`, gap 6, 아이콘 16, 열림 테두리 1.5 `action.primary`, 설명 `chip.bg`·`radius.md`·`space.12`, `appear.seep`/`disappear.seep`)으로 구현합니다. 색 변형의 견본은 `ohaeng.swatch` 14px 원입니다.
- [ ] **Step 4:** 실행 → PASS. golden(닫힘·열림 × 라이트·다크 × ko·ja × 1.0·2.0)을 `tool/goldens_linux.sh`로 만들고 `flutter test --tags golden` → PASS.
- [ ] **Step 5:** Commit `feat(app): lucky-card 컴포넌트`.

### Task 6: `guide-question-card` 컴포넌트

**Files:**
- Create: `app/lib/design/components/today/guide_question_card.dart`
- Modify: `component_spec.dart`, Widgetbook
- Test: `app/test/design/today_test.dart`, `today_golden_test.dart`

**Interfaces:**
- Produces: `enum GuideQuestionState { before, after }`, `class GuideQuestionCard extends StatelessWidget { const new({required this.state, required this.eyebrow, required this.question, required this.actionLabel, required this.onAction, this.questionSlotId, this.actionSlotId, super.key}); static const ComponentSpec spec; }` — `question`은 `RenderedText`
- [ ] **Step 1: 실패하는 테스트:** `before`는 `PrimaryButton` filled, `after`는 quiet 버튼과 그 글자 뒤 층의 `seal` soft 52px, 질문 글자 `text.secondary`. 그룹 라벨은 "질문"이고 `after`면 "오늘 일기 씀"을 상태로 읽는다(`stateAnnounced`). 버튼을 누르면 `onAction` 한 번.
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 명세 `guide-question-card` 값으로 구현합니다. 질문은 `SentenceBlock` card 변형입니다. "오늘 일기 씀"과 eyebrow 문구가 ARB에 없으면 `todayGuideEyebrow`·`todayGuideWritten` 임시 키를 더하고 Task 1 writing Issue에 코멘트로 덧붙입니다.
- [ ] **Step 4:** 실행 → PASS, golden(두 상태 × 기본 조합) → PASS.
- [ ] **Step 5:** Commit `feat(app): guide-question-card 컴포넌트`.

### Task 7: `share-image` 컴포넌트

**Files:**
- Create: `app/lib/design/components/today/share_image.dart`
- Modify: `component_spec.dart`, Widgetbook, `pubspec.yaml` assets(로고 lockup이 app 자산에 없으면 `docs/identity/design/logo/`에서 가져옴)
- Test: `app/test/design/today_test.dart`, `today_golden_test.dart`

**Interfaces:**
- Consumes: `LuckyCardRow(interactive: false)`, `DayCharacter`의 badge, `SentenceBlock`
- Produces: `enum ShareImageVariant { story, feed, square }`(id `story`·`feed`·`square`, 논리 크기 360×640·360×450·360×360), `class ShareImage extends StatelessWidget { const new({required this.variant, required this.date, required this.dayKind, required this.dayKindLabel, required this.sentence, required this.items, required this.footer, this.reason, super.key}); static const ComponentSpec spec; static Size logicalSize(ShareImageVariant v); }`, `String firstSentence(String text)`(첫 `.`·`。`·`!`·`?`까지)
- [ ] **Step 1: 실패하는 테스트:** 기기가 다크여도 라이트 토큰으로 그린다(V5). story는 `reason`이 있으면 보이고 칩 4개, feed는 문장 2줄·칩 3개(색·방향·숫자), square는 첫 문장·칩 3개. `firstSentence('오늘은 좋아요. 그리고')` == `'오늘은 좋아요.'`, 끝 문장부호가 없으면 전체. 라벨은 "오늘 문장 이미지 미리보기"이고 altText는 문장 전체.
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 명세 `share-image` 값(`gradient.today` 배경, 날짜 `caption.md`, 로고, footer `caption.sm`)으로 구현합니다. 1080 폭 PNG는 이 논리 크기를 `pixelRatio: 3`으로 그린 것입니다(Task 12).
- [ ] **Step 4:** 실행 → PASS, golden(세 변형 × 라이트 고정 × ko·ja) → PASS.
- [ ] **Step 5:** Commit `feat(app): share-image 컴포넌트`.

### Task 8: `today` 화면

**Files:**
- Create: `app/lib/features/today/presentation/today_screen.dart`, `app/lib/features/today/application/today_presentation.dart`, `app/lib/features/diary/data/diary_repository.dart`, `app/lib/features/diary/application/diary_providers.dart`, `app/fixtures/member/getDiary.json`(404), `app/fixtures/diary-written/getDiary.json`(200)
- Modify: `app/lib/app/router/screen_registry.dart`, `app/test/contract/ia_pending.dart`(`today`를 `pendingStateScreens`에서 지움), ARB 세 파일(`direction*`, `depthLinkEvidence`)
- Test: `app/test/features/today/today_screen_test.dart`, `app/test/features/today/today_presentation_test.dart`, `app/test/flows/today_flow_test.dart`

**Interfaces:**
- Consumes: `dailyControllerProvider`, `glossaryProvider`, `depthSheetsProvider`, `LuckyCardRow`, `GuideQuestionCard`, `DayCharacter`, `SentenceBlock`, `DepthLink`, `ShareButton`, `NoticeBanner`, `ScreenStateView`, `profileTimezoneProvider`
- Produces:
  * `List<LuckyItem> luckyItemsOf(Daily daily, GlossaryNames names, AppLocalizations l10n, String timezone)` — A27 규칙
  * `String formatFocusRange(List<FocusSlot> picks, String timezone)` — `09:30–11:30`, 둘이면 ` · `
  * `final class DiaryRepository { Future<bool> existsOn(CalendarDate date); }`(404 → false), `final todayDiaryExistsProvider = FutureProvider<bool>`(실패하면 false)
  * `const Set<String> todayHandledStates = {'loading', 'error', 'offline', 'time-unknown'}`, `const Set<String> todayExits = {diaryEdit, diaryView, explainSheet, evidenceSheet, sharePreview}`(`day-sheet`는 계획 4)
- [ ] **Step 1: 실패하는 테스트**
  * `today_presentation_test`: `formatFocusRange`가 `+09:00` 응답과 UTC로 바뀐 값 모두에서 `Asia/Seoul` 기준 `09:30–11:30`, 두 칸이면 `09:30–11:30 · 13:30–15:30`, `America/New_York`이면 그 시간대 값. `luckyItemsOf`는 색 이름을 glossary `color.wood`, 방향을 `l10n.directionE`, 숫자를 `'3'`으로 만든다.
  * `today_screen_test`(시나리오별): `member`에서 날의 성격 배지 `dayKindYongsinDay`(reason 줄 없음, A22), 총운 두 문장, 행운 칩 4개, 가이드 카드 `before`. 슬롯 id(`today.character.label`·`today.fortune.head`·`today.fortune.body`·`today.lucky-*.body`·`today.guide.question`·`today.guide.cta`)가 identifier로 붙는다. `diary-written`이면 `after`와 `todayGuideCtaWritten`. 상태: 응답 전 skeleton(`loading`), `daily-error`면 `error-state`와 다시 시도 → `reload`, `offline`(캐시 없음)이면 offline 화면, 캐시 있음이면 내용과 `notice-banner` offline, `member-time-unknown`이면 `notice-banner` timeUnknown.
  * `today_flow_test`: `member`로 띄워 `today`에 닿고, 용어 칩을 누르면 explain 시트, "근거 보기"를 누르면 evidence 시트, 공유 버튼을 누르면 share-preview 시트, 가이드 카드를 누르면 `diary-edit`(자리표시), `diary-written`이면 `diary-view`. `covers`: exits `today>explain-sheet`, `today>evidence-sheet`, `today>share-preview`, `today>diary-edit`, `today>diary-view`, states `today:loading`, `today:error`, `today:offline`, `today:time-unknown`.
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 구현합니다. 배치 순서: app-bar(오른쪽 `ShareButton` icon) → `DayCharacter` → 총운 `SentenceBlock` card(`fortune.head`, 끝에 `DepthLink` inline-end `depthLinkEvidence` → `openEvidence(slotId: fortune.head.slot)`) → `fortune.tag`(있을 때만) → `LuckyCardRow` → `GuideQuestionCard`. 용어 조각은 `openExplain(termId:, sourceSlotId:)`. 화면 뿌리에 `ScreenIds.today`. `screenRegistry`에 `ScreenSpec(ScreenIds.today, …, handledStates: todayHandledStates, exits: todayExits)`로 등록합니다. 반응 버튼은 Task 9가 붙입니다.
- [ ] **Step 4:** 실행 → PASS. `dart run tool/ia_coverage.dart --check` → 유지 이상.
- [ ] **Step 5:** Commit `feat(app): today 화면`.

### Task 9: 총운 반응

**Files:**
- Create: `app/lib/features/today/application/reaction_controller.dart`, `app/fixtures/member/putReaction.json`(204), `app/fixtures/member/deleteReaction.json`(204), `app/fixtures/reaction-failed/putReaction.json`(503)
- Modify: `app/lib/features/today/presentation/today_screen.dart`, `scenarios.json`, README
- Test: `app/test/features/today/reaction_controller_test.dart`, `today_screen_test.dart`

**Interfaces:**
- Consumes: `DailyRepository.patchCachedReaction`, `DailyController.cacheKey`
- Produces: `final reactionControllerProvider = NotifierProvider<ReactionController, Map<String, bool>>`(슬롯 id → 화면에 보일 좋아요 여부, 응답 값을 덮어씀), `ReactionController.toggle(SlotText text, {required CalendarDate date})`

- [ ] **Step 1: 실패하는 테스트**
  * `'누르면 바로 켜지고 PUT 한 번, 성공하면 캐시도 like'`.
  * `'켜진 것을 누르면 DELETE'`.
  * `'실패하면 되돌리고 오류를 알린다'`(시나리오 `reaction-failed`, 상태가 false로 돌아오고 `AppError`를 내보냄).
  * `'요청 중 두 번 더 누르면 끝난 뒤 마지막 의도와 server 상태가 같으므로 추가 요청이 없다'`(켬→끔→켬: PUT 1회), `'요청 중 한 번 더 누르면 끝난 뒤 DELETE 한 번'`(Review Focus 3).
  * `today_screen_test`: `reactable`인 `fortune.head`에만 `ReactionButton`이 있고 라벨이 `todayReactionLabel`/`todayReactionLabelSelected`, Key·identifier `today.reaction.label`. 실패하면 toast.
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 구현합니다(A25). 경로의 slot은 `SlotText.slot`, 날짜는 `DailyView.date`. `DailyController`의 새 응답을 받으면 그 슬롯의 override를 지웁니다.
- [ ] **Step 4:** 실행 → PASS.
- [ ] **Step 5:** Commit `feat(app): 총운 좋아요 반응(A25, D40·D57)`.

### Task 10: `explain-sheet`

**Files:**
- Create: `app/lib/features/depth/presentation/explain_sheet.dart`
- Modify: `app/lib/app/router/sheet_registry.dart`, `ia_pending.dart`(`explain-sheet` 지움), `depth_sheets.dart`
- Test: `app/test/features/depth/explain_sheet_test.dart`

**Interfaces:**
- Consumes: `glossaryProvider`, `DepthSheets.openEvidence`
- Produces: `class ExplainSheet extends ConsumerWidget { const new({required this.termId, required this.sourceSlotId, super.key}); }`, `SheetSpec(ScreenIds.explainSheet, handledStates: {'loading', 'error'}, exits: {ScreenIds.evidenceSheet})`
- [ ] **Step 1: 실패하는 테스트:** 제목은 `GlossaryNames.nameOf(termId)`(`SheetHeading`), 뜻·이유 자리는 없음(A22), `DepthLink` block `depthLinkEvidence`를 누르면 `openEvidence(slotId: sourceSlotId)`. glossary를 받는 동안 skeleton(`loading`), 실패하면 `error-state`와 다시 시도. glossary에 없는 용어 id면 `error-state`(`UnexpectedError`)이고 크래시 보고에는 `CrashSummary`만 남깁니다(D64).
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 구현하고 `DepthSheets.openExplain`에 연결합니다. `covers(exits: ['explain-sheet>evidence-sheet'], states: ['explain-sheet:loading', 'explain-sheet:error'])`를 흐름 테스트(`today_flow_test`)에 더합니다.
- [ ] **Step 4:** 실행 → PASS.
- [ ] **Step 5:** Commit `feat(app): explain-sheet`.

### Task 11: 이용권과 `evidence-sheet` 잠금 해제

**Files:**
- Create: `app/lib/features/monetization/data/entitlements_repository.dart`, `app/lib/features/monetization/application/entitlements_providers.dart`, `app/lib/features/depth/application/evidence_unlock_controller.dart`, `app/lib/features/depth/presentation/evidence_sheet.dart`, fixture `member/getEntitlements.json`(inactive), `evidence-unlocked/{getDaily,getEntitlements}.json`, `reward-unlock/{getDaily,getEntitlements}.json`(sequence), `reward-timeout/`(entitlements inactive 유지, 상속), `reward-unavailable/`(scenario만)
- Modify: `app/lib/core/api/fake/scenario.dart`(필드 `rewardedAd`), `app/lib/app/bootstrap.dart`(fake 모드에서 `adsProvider`를 시나리오로 override), `app/lib/design/components/depth/evidence_sheet_body.dart`(A22: unlocked이고 본문 없는 구역 숨김), `sheet_registry.dart`, `ia_pending.dart`(`evidence-sheet` 지움), `scenarios.json`, README
- Test: `app/test/features/depth/evidence_unlock_controller_test.dart`, `app/test/features/depth/evidence_sheet_test.dart`, `app/test/design/depth_test.dart`(기존 파일이면 그곳), `app/test/core/scenario_test.dart`

**Interfaces:**
- Consumes: `Ads.loadRewarded`, `RewardedResult`, `DailyController.reload`, `currentAccountIdProvider`, `showMyungliToast`, `EvidenceSheetBody`
- Produces:
  * `final class EntitlementsRepository { Future<Entitlements> fetch(); }`
  * `const rewardPollInterval = Duration(seconds: 2)`, `const rewardPollTimeout = Duration(seconds: 30)`, `final rewardPollTimingProvider = Provider<({Duration interval, Duration timeout})>`
  * `sealed class UnlockEvent`(`UnlockTimedOut`, `UnlockFailed(AppError)`), `final evidenceUnlockControllerProvider = NotifierProvider.autoDispose<EvidenceUnlockController, DepthLinkState>`; `EvidenceUnlockController.watchAd()`, `Stream<UnlockEvent> events`
  * Scenario: `enum ScenarioRewardedAd { earned, dismissed, unavailable, failed }`, `Scenario.rewardedAd`(기본 `earned`)
  * `class EvidenceSheet extends ConsumerWidget { const new({required this.slotId, super.key}); }`, `SheetSpec(ScreenIds.evidenceSheet, handledStates: {'loading', 'error'}, exits: {ScreenIds.systemRewardedAd, ScreenIds.adFree})`
- [ ] **Step 1: 실패하는 테스트**
  * `scenario_test`: `rewardedAd` 생략이면 `earned`, 모르는 값이면 `ScenarioFormatException`.
  * controller(가짜 시간 `fakeAsync` 또는 `rewardPollTimingProvider`를 짧게 override):
    * `'응답이 unlocked면 처음부터 unlocked'`, `'locked이고 광고가 없으면 lockedNoAd'`.
    * `'끝까지 보면 unlocking → 권한이 생기면 getDaily를 다시 받고 unlocked'`(시나리오 `reward-unlock`: `getEntitlements` 세 번째에 active, `getDaily` 두 번째가 unlocked).
    * `'30초 안에 권한이 없으면 UnlockTimedOut과 locked'`(`reward-timeout`, `getEntitlements` 호출 수 15 이하).
    * `'닫으면 locked 그대로 요청 없음'`(`dismissed`), `'표시 실패면 UnlockFailed와 locked'`(`failed`).
    * `'확인 중에 dispose되면 묻기를 멈춘다'`: dispose 뒤 시간을 흘려도 `getEntitlements` 호출 수가 늘지 않음(Review Focus 5).
    * `'loadRewarded의 userId는 계정 id'`.
  * `evidence_sheet_test`: 잠김이면 세 구역이 `lock.veil`이고 아래 `EvidenceLockPanel`, `lockedNoAd`면 `evidence-sheet.lock.unavailable`과 버튼 꺼짐, 확인 중이면 버튼 라벨 `evidence-sheet.a11y.checking`, 시간 초과면 toast `evidenceSheetUnlockFailed`, 광고 제거권 링크는 `ad-free`로 이동(자리표시 화면). unlocked이고 본문이 없으면 구역 제목도 그리지 않음(A22). 응답을 다시 받는 동안 세 구역 skeleton(`loading`), 다시 받기 실패는 `error-state`.
  * 흐름(`today_flow_test`에 더함): `reward-unlock`으로 근거 시트 → 광고 보고 열기 → unlocked. `covers(exits: ['evidence-sheet>system-rewarded-ad', 'evidence-sheet>ad-free'], states: ['evidence-sheet:loading', 'evidence-sheet:error'], decisions: ['D60'])`.
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 구현합니다(A26). 시트는 열릴 때 광고를 미리 불러 둡니다. `EvidenceSheetBody`의 제목은 `evidenceSheetTitle`, `pillars`·`personal`은 넘기지 않습니다(계획 6).
- [ ] **Step 4:** 실행 → PASS. 기존 `EvidenceSheetBody` golden이 바뀌면 다시 만들고 차이가 unlocked 빈 구역뿐인지 확인합니다.
- [ ] **Step 5:** Commit `feat(app): evidence-sheet와 보상형 광고 잠금 해제(A26, D60)`.

### Task 12: `share-preview`

**Files:**
- Create: `app/lib/features/today/presentation/share_preview_sheet.dart`, `app/lib/features/today/application/share_renderer.dart`
- Modify: `sheet_registry.dart`, `depth_sheets.dart`
- Test: `app/test/features/today/share_preview_sheet_test.dart`, `app/test/features/today/share_renderer_test.dart`

**Interfaces:**
- Consumes: `ShareImage`, `Segmented`, `PrimaryButton`, `shareSheetProvider`(`ShareSheet.sharePng`), `dailyControllerProvider`, `luckyItemsOf`
- Produces: `abstract interface class ShareRenderer { Future<Uint8List> render(Widget image, Size logicalSize); }`, `final class OffscreenShareRenderer`(화면 밖 `RepaintBoundary`, `pixelRatio: 3`, 라이트 `MyungliTheme`), `final shareRendererProvider`, `class SharePreviewSheet extends ConsumerStatefulWidget`, `SheetSpec(ScreenIds.sharePreview, exits: {ScreenIds.systemShare})`
- [ ] **Step 1: 실패하는 테스트:** 시트 위 `Segmented` 세 칸(`sharePreviewRatioLabelStory`·`Feed`·`Square`, 기본 story), 고르면 미리보기 변형이 바뀜. 공유 버튼(`share-preview.cta.share`)을 누르면 `ShareSheet.sharePng`이 한 번, 텍스트는 `sharePreviewImageTagline`, PNG 크기는 story 1080×1920(`share_renderer_test`에서 실제 렌더로 확인). 처리 중 다시 눌러도 한 번. 공유 실패는 오류 toast. 다크 기기에서도 미리보기가 라이트(V5). `covers(exits: ['share-preview>system-share'], decisions: ['D47'])`.
- [ ] **Step 2:** 실행 → FAIL.
- [ ] **Step 3:** 구현합니다. 문장은 `fortune.head`(호칭 포함), 이유는 A22로 없음.
- [ ] **Step 4:** 실행 → PASS.
- [ ] **Step 5:** Commit `feat(app): share-preview와 공유 이미지 렌더`.

### Task 13: E2E, 커버리지, 문서

**Files:**
- Create: `app/patrol_test/today_test.dart`
- Modify: `app/tool/coverage_baseline.json`, `app/CLAUDE.md`, `app/docs/specs/2026-10-13-app-architecture-design.md`(개정 기록, §10 계획 3에 넘긴 항목), `app/README.md`
- Test: Patrol

**Interfaces:**
- Consumes: 앞 task 전부

- [ ] **Step 1:** Patrol `today_test`: `launchApp(scenario: 'reward-unlock', deviceLocale: 'ko-KR')` → `today` → 용어 칩 → explain → 근거 보기 → 광고 보고 열기 → unlocked → 닫기 → 좋아요 켜기. 문구가 아니라 IA id·Key로 찾습니다(계획 2의 Android 영어 로케일 교훈). 다크 모드 한 번(`share-preview` 미리보기가 라이트). `covers`는 흐름 테스트와 같은 형식입니다.
- [ ] **Step 2:** 로컬 iOS 시뮬레이터에서 `patrol test -t patrol_test/today_test.dart` → PASS. Android는 브랜치를 push하고 `gh workflow run app --ref app/today`의 `e2e-android` → PASS.
- [ ] **Step 3:** `dart run tool/ia_coverage.dart --update-baseline`, `--check` → 통과(경로·상태가 28/79·11/54보다 늘어남).
- [ ] **Step 4:** 문서: spec 개정 기록에 "2026-10-15 계획 3: 시트 등록부(A23), 그날 캐시 순서(A24), 반응(A25), 잠금 해제(A26), 행운 카드 값(A27), 계약 빈칸(A22)"을 더하고 §4.4 그날 캐시에 A24 한 줄. `app/CLAUDE.md` "현재 상태"에 계획 3 요약·새 시나리오·Task 1 Issue 번호, "다음 할 일"에 계획 4(오늘 일정 줄·`day-sheet`·`today` 출구 마무리), 계획 6(근거 시트 원국표·개인 해석), 계약 필드가 오면 할 일(A22).
- [ ] **Step 5:** 전체 확인: `flutter analyze`(app·widgetbook), `flutter test`, `dart format --set-exit-if-changed .`, `mlw check-arb`, fixture 검증, `--check`. Commit `docs(app): 계획 3 상태와 다음 할 일`.
