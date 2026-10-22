# 일기 하루 여러 편 (D83) Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** app 일기를 하루 여러 편(id 기반, 한 날짜 10편 상한)으로 바꾸고 drift #412를 한 PR에서 맞춥니다.

**Architecture:** REST draft.13 생성 클라이언트 위에 `DiaryRepository`를 id 기반으로 다시 세우고, 초안은 (계정, 날짜, 일기 id) 단위로 바꿉니다. 그날 일기 목록 provider 하나가 입구 세 곳의 상태(`first`·`more`·`full`)와 일기 줄을 함께 공급합니다. 화면 경로는 `?id=`(한 편)와 `?date=`(그날 새 일기)로 나뉩니다.

**Tech Stack:** Flutter 3.47.7, Riverpod 3.x(코드 생성 없음), go_router, Dio 생성 클라이언트(openapi-generator), drift, 생성자 문법 `const new(...)`.

**Spec:** `app/docs/specs/2026-10-22-diary-multi-design.md`

## 시작 전

* 브랜치 `app/d83-diary`(origin/main 기준). 세션을 열면 `git fetch origin && git merge origin/main`.
* `tool/gen_api.sh`는 Docker가 켜져 있어야 합니다.
* **Task 2~5 사이에는 `flutter analyze` 전체가 실패합니다**(API 재생성이 날짜 기반 호출을 깨뜨리고, 호출하는 화면은 Task 5·6에서 고칩니다). 각 task는 적힌 테스트 파일만 돌려 확인하고, Task 6 끝에서 전체 analyze가 통과해야 합니다.

## Global Constraints

* 한 날짜 상한 상수 `diaryDayLimit = 10`(D83 ②). 기준은 server이고 app 상수가 어긋나도 422가 막습니다.
* 같은 날 순서는 server 순서(날짜 내림차순, 같은 날 작성 순)를 그대로 씁니다. app이 다시 정렬하지 않습니다.
* 새 일기의 초안 키는 `diaryId = ''`, 날짜마다 하나입니다.
* 경로 query: `id`(상수 `diaryIdQuery`), `date`(기존 `dateQuery`). `diary-edit`에서 `id`가 `date`보다 앞섭니다.
* 오류 보고는 `CrashSummary.from(error)`만 씁니다. 일기 본문·초안은 로그·CrashReporter에 싣지 않습니다(D64).
* 일기 목록은 기기에 저장하지 않습니다(A45 그대로).
* 결정 번호 A67~A71(spec §10). 문구 키는 writing ARB의 것만 쓰고 새 임시 키를 만들지 않습니다.
* 공개 저장소(D74): 내부 수치를 fixture·문서에 적지 않습니다.

## Review Focus

1. 같은 날 새 일기 초안이 있는 채로 그날 입구를 다시 누르면 그 초안으로 이어 써야 하고, 저장된 다른 일기 본문이 섞이면 안 됩니다(초안 대상 혼동).
2. 새 일기 저장이 시간 초과로 실패한 뒤 다시 누르면 같은 `Idempotency-Key`를 보내 일기가 한 편만 생겨야 합니다.
3. 같은 날 일기를 저장·삭제한 뒤 today·day-sheet·달력 도장·목록이 모두 새 편수를 보여야 합니다(다시 받기 누락).
4. 달력 격자 범위에 100편이 넘게 있어도 모든 날짜에 도장이 찍혀야 합니다(cursor 이어 받기).
5. 합치기로 그날 11편 이상이어도 입구는 `full`이어야 합니다(`== 10`이 아니라 `>= 10`).

각 줄의 테스트: 1은 Task 1(대상별 초안)·Task 4(고치기 저장이 새 일기 초안을 남김), 2는 Task 4, 3은 Task 4(저장 뒤 다시 묻기)·Task 6(흐름), 4는 Task 2(`datesIn` 이어 받기), 5는 Task 3(`diaryWriteEntryOf(11)`)·Task 6(day-sheet 11편).

---

### Task 1: 초안을 일기 한 편 단위로 (DB v2)

**Files:**
- Modify: `lib/core/storage/app_database.dart`(`DiaryDrafts`에 `diaryId`, `schemaVersion` 2, `migration`), `lib/core/storage/app_database.g.dart`(build_runner)
- Modify: `lib/features/diary/data/diary_draft_store.dart`
- Create: `lib/features/diary/model/diary_draft_target.dart`
- Test: `test/features/diary/data/diary_draft_store_test.dart`, `test/core/storage/app_database_migration_test.dart`(새)

**Interfaces:**
- Produces:
  - `sealed class DiaryDraftTarget { CalendarDate get date; String get diaryId; }`, `DiaryDraftTarget.newOn(CalendarDate date)`(diaryId `''`), `DiaryDraftTarget.existing({required CalendarDate date, required String id})`. 값 동등성(`==`·`hashCode`)이 있습니다.
  - `DiaryDraftStore.read(DiaryDraftTarget) → Future<String?>`, `write(DiaryDraftTarget, String body)`, `remove(DiaryDraftTarget)`

- [ ] **Step 1: 실패하는 테스트**
  * `diary_draft_store_test.dart`: `'같은 날 새 일기 초안과 고치는 일기 초안은 따로 남는다'` — `write(newOn(d), 'A')`, `write(existing(date: d, id: 'x'), 'B')` 뒤 `read(newOn(d)) == 'A'`, `read(existing(date: d, id: 'x')) == 'B'`, `read(existing(date: d, id: 'y')) == null`. `'remove는 그 대상만 지운다'`. 기존 계정 한정 테스트는 대상 인자로 고칩니다.
  * `app_database_migration_test.dart`: `'v1 날짜 초안은 v2 새 일기 초안으로 옮겨진다'` — v1 schema(`diary_drafts(account_id, date, body, updated_at)`, PK (account_id, date))를 raw SQL로 만들고 행 하나를 넣은 메모리 DB를 `schemaVersion` 2로 열어 `DiaryDraftStore.read(newOn(그날))`이 그 본문입니다.
- [ ] **Step 2: 실패 확인** — `flutter test test/features/diary/data/diary_draft_store_test.dart test/core/storage/app_database_migration_test.dart` FAIL
- [ ] **Step 3: 구현**
  * `DiaryDrafts.diaryId`: `text().withDefault(const Constant(''))()`, `primaryKey => {accountId, date, diaryId}`. 표 주석을 "(계정, 날짜, 일기 id)당 1개, 새 일기는 id `''`"로 고칩니다.
  * `migration`: `onUpgrade`에서 `from < 2`면 `m.alterTable(TableMigration(diaryDrafts, newColumns: [diaryDrafts.diaryId]))`(기존 행은 기본값 `''`이 됨).
  * `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS
- [ ] **Step 5: Commit** — `feat(app): 일기 초안을 일기 한 편 단위로 (D83, A68)`

### Task 2: REST draft.13 클라이언트, 저장소, fake server

**Files:**
- Regenerate: `lib/core/api/gen/**`, `lib/core/api/gen_routes/routes.g.dart`(`tool/gen_api.sh`)
- Modify: `lib/features/diary/data/diary_repository.dart`
- Modify: `lib/core/api/fake/fake_diary_store.dart`, `lib/core/api/fake/fake_server.dart`(`_diaryOperations`·`_answerFromDiaryStore`)
- Modify: `fixtures/member/{getDiary,listDiaries}.json`, `fixtures/diary-written/{getDiary,listDiaries}.json`(`id`·`createdAt` 추가)
- Create: `fixtures/diary-day-full/listDiaries.json`(오늘 날짜 요약 10개), `fixtures/scenarios.json`에 `diary-day-full` 등록, `README.md` fake 시나리오 표에 한 줄
- Test: `test/features/diary/diary_repository_test.dart`, `test/core/fake_server_diaries_test.dart`

**Interfaces:**
- Produces (`DiaryRepository`):
  - `const int diaryDayLimit = 10;`
  - `Future<Diary> create(CalendarDate date, String body, {required String idempotencyKey})`
  - `Future<Diary> update(String id, String body)`
  - `Future<Diary?> find(String id)` (404 → null)
  - `Future<void> delete(String id)`
  - `Future<List<DiarySummary>> diariesOn(CalendarDate date)` (`from`=`to`=date, limit 100)
  - `Future<Set<CalendarDate>> datesIn(CalendarDate from, CalendarDate to)` (cursor 끝까지)
  - `page(...)` 그대로. `existsOn`·`put` 삭제.
- Fake: `FakeDiaryStore`는 id(uuid v4) 키, `create(Object? body, {String? idempotencyKey})`·`update(String id, Object? body)`·`get(String id)`·`delete(String id)`·`list(...)`. 시나리오 fixture의 요약에 `id`가 없으면 만들지 않고 fixture가 줍니다.

- [ ] **Step 1: 재생성** — `tool/gen_api.sh`. `git status`에 `diary_body_input.dart` 새 파일과 `default_api.dart` 등의 변경이 보입니다.
- [ ] **Step 2: 실패하는 테스트**
  * repository(Dio mock, 기존 테스트 방식): `create`가 `POST /v1/diaries`에 `{date, body}`와 `Idempotency-Key` header를 보냄, `update`가 `PUT /v1/diaries/x`에 `{body}`, `find`의 404 → null, `diariesOn(d)`가 `from=d&to=d&limit=100`, `'datesIn은 nextCursor가 없을 때까지 이어 받는다'`(첫 응답 `nextCursor: 'c1'`, 둘째 없음 → 요청 2번, 두 쪽 날짜의 합집합), 422 `diary.day_full` → `ProblemError(code: 'diary.day_full')`.
  * fake server: `'같은 날 두 편은 작성 순으로 목록에 나온다'`, `'10편째 뒤 createDiary는 422 diary.day_full'`(field `date`), `'같은 Idempotency-Key 재전송은 같은 일기를 돌려주고 늘지 않는다'`, `'지운 일기 getDiary는 404'`, `'updateDiary는 본문만 바꾸고 tags·createdAt은 그대로'`, `'오늘 뒤 날짜 createDiary는 422 diary.future_date'`.
- [ ] **Step 3: 실패 확인** — `flutter test test/features/diary/diary_repository_test.dart test/core/fake_server_diaries_test.dart` FAIL
- [ ] **Step 4: 구현** — 실패 분류와 빈 응답 처리는 지금 메서드와 같습니다. fake의 목록 정렬은 `date DESC, createdAt ASC, id ASC`, 요약에 `id`·`createdAt`을 넣습니다. `restoreDiary`는 fake에서 501로 둡니다(app이 부르지 않음).
- [ ] **Step 5: fixture 검증** — `uv run --with jsonschema --with pyyaml --with referencing --with rfc3339-validator sh -c 'python -I tool/test_validate_fixtures.py && python -I tool/validate_fixtures.py'` 통과
- [ ] **Step 6: 통과 확인** — Step 3 명령 PASS
- [ ] **Step 7: Commit** — `feat(app): 일기 저장소를 id 기반 REST draft.13으로 (#437, D83)`

### Task 3: 그날 일기 목록 provider와 입구 상태

**Files:**
- Modify: `lib/features/diary/application/diary_providers.dart`
- Create: `lib/features/diary/model/diary_write_entry.dart`
- Test: `test/features/diary/model/diary_write_entry_test.dart`(새), `test/features/diary/application/diary_application_test.dart`

**Interfaces:**
- Consumes: Task 2 `DiaryRepository.diariesOn`, `diaryDayLimit`
- Produces:
  - `enum DiaryWriteEntry { first, more, full }`, `DiaryWriteEntry diaryWriteEntryOf(int count)`
  - `final FutureProviderFamily<List<DiarySummary>, CalendarDate> diariesOnProvider` (autoDispose, `retry: (_, _) => null`, 실패하면 `const []`, 예상 못한 오류만 `CrashSummary`)
  - `todayDiaryExistsProvider`·`diaryExistsOnProvider` 삭제

- [ ] **Step 1: 실패하는 테스트** — `diaryWriteEntryOf(0) == first`, `(1) == more`, `(9) == more`, `(10) == full`, `(11) == full`. `diariesOnProvider`: 성공 시 server 순서 그대로, `OfflineError` → 빈 목록·보고 없음, `UnexpectedError` → 빈 목록·`CrashReporter.record` 한 번.
- [ ] **Step 2: 실패 확인** — `flutter test test/features/diary/model/diary_write_entry_test.dart test/features/diary/application/diary_application_test.dart` FAIL
- [ ] **Step 3: 구현** — 실패 규칙은 지금 `_existsOrFalse`를 옮깁니다.
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS
- [ ] **Step 5: Commit** — `feat(app): 그날 일기 목록과 쓰는 입구 상태 (D83 ②, A69)`

### Task 4: 쓰기·지우기 상태와 오류 문구

**Files:**
- Modify: `lib/features/diary/application/diary_edit.dart`
- Create: `lib/features/diary/model/diary_edit_target.dart`
- Modify: `lib/core/l10n/error_messages.dart`(`diary.day_full` 추가, `diary.date_taken` 삭제)
- Test: `test/features/diary/application/diary_application_test.dart`, `test/contract/problem_codes_contract_test.dart`(돌리기만)

**Interfaces:**
- Consumes: Task 1 `DiaryDraftTarget`·`DiaryDraftStore`, Task 2 `DiaryRepository`, Task 3 `diariesOnProvider`
- Produces:
  - `sealed class DiaryEditTarget`: `DiaryEditTarget.newOn(CalendarDate date)`, `DiaryEditTarget.existing(String id)`. 값 동등성이 있습니다.
  - `diaryEditProvider`: `AsyncNotifierProviderFamily<DiaryEdit, DiaryEditState, DiaryEditTarget>`
  - `DiaryEditState.date`(`CalendarDate`, 새 일기는 target의 날짜, 고치기는 `existing.date`)를 더합니다.
  - `final FutureProviderFamily<Diary?, String> diaryProvider`(`diaryOnProvider` 대체, autoDispose, 재시도 끔)
  - `DiaryDeleter.delete(Diary diary) → Future<bool>`
  - `void invalidateDiaryViews(Ref ref, CalendarDate date, {String? id})`: `diaryPagesProvider`, `diariesOnProvider(date)`, `diaryDatesProvider`, `id`가 있으면 `diaryProvider(id)`

- [ ] **Step 1: 실패하는 테스트**
  * `'새 일기 저장은 create이고 성공하면 그날 새 일기 초안을 지운다'`
  * `'새 일기 저장이 TimeoutError로 실패한 뒤 다시 저장하면 같은 Idempotency-Key를 보낸다'`(repository fake가 받은 키 두 개가 같음)
  * `'고치기 저장은 update이고 그 일기 초안만 지운다'`(같은 날 새 일기 초안은 남음)
  * `'422 diary.day_full이면 초안을 남기고 ProblemError를 던진다'`(`state.status == local`, `offline == false`)
  * `'고치기를 열면 그 일기 초안이 저장된 본문보다 앞선다'`
  * `'저장 뒤 그날 diariesOnProvider를 다시 묻는다'`(listen 횟수)
  * `DiaryDeleter`: 성공·404 모두 그 일기 초안을 지우고 `invalidateDiaryViews`.
- [ ] **Step 2: 실패 확인** — `flutter test test/features/diary/application/diary_application_test.dart` FAIL
- [ ] **Step 3: 구현** — `build`는 spec §8 "열 때"대로. 새 일기의 `Idempotency-Key`는 notifier 필드(`String? _createKey`)에 처음 저장 때 uuid v4(`package:uuid`의 `Uuid().v4()`, 일정 `schedule_providers.dart`와 같음)로 만들고 성공하면 null로 돌립니다. 성공한 뒤 `state.existing`이 생기므로 같은 화면에서 다시 저장하면 `update`입니다.
- [ ] **Step 4: 통과 확인** — Step 2 명령과 `flutter test test/contract/problem_codes_contract_test.dart` PASS
- [ ] **Step 5: Commit** — `feat(app): 일기 쓰기를 한 편 단위로, 한 날짜 상한 오류 (D83, #424, A71)`

### Task 5: 일기 경로와 쓰기·보기·목록 화면

**Files:**
- Modify: `lib/app/router/app_router.dart`(`diaryIdQuery`, `diaryPathOf`), `test/app/dated_path_test.dart`
- Modify: `lib/features/diary/presentation/diary_edit_screen.dart`, `diary_view_screen.dart`, `diary_page_list.dart`(`tag-diary`도 이 줄을 씀)
- Test: `test/flows/diary_edit_flow_test.dart`, `diary_view_flow_test.dart`, `diary_list_flow_test.dart`, `tag_diary_flow_test.dart`, `diary_journey_flow_test.dart`

**Interfaces:**
- Consumes: Task 4 `DiaryEditTarget`·`diaryEditProvider`·`diaryProvider`·`DiaryDeleter.delete(Diary)`
- Produces: `const String diaryIdQuery = 'id';`, `String diaryPathOf(String screenId, String id)`(`/<id>?id=<uuid>`), `DiaryEditTarget diaryEditTargetOf(Uri uri, CalendarDate today)`(`app_router.dart`, `id` 우선 → `date` → 오늘 새 일기)

- [ ] **Step 1: 실패하는 테스트**
  * `dated_path_test.dart`: `diaryPathOf(ScreenIds.diaryView, 'x') == '/diary-view?id=x'`; `diaryEditTargetOf`의 세 갈래(`?id=x&date=…` → existing('x')).
  * 흐름: `diary-edit?date=오늘`에서 저장 → `diary-view?id=<새 id>`에 본문; 보기에서 고치기 → `diary-edit?id=` → 저장 → 같은 id; 목록 줄을 누르면 그 줄의 id로 `diary-view`; `diary-view`에 `id` 없음 → 찾지 못함 안내; 저장 422 `diary.day_full`(시나리오 `diary-day-full`, 오늘) → `errorDiaryDayFull` toast·화면 머묾.
- [ ] **Step 2: 실패 확인** — `flutter test test/app/dated_path_test.dart test/flows/diary_edit_flow_test.dart test/flows/diary_view_flow_test.dart` FAIL
- [ ] **Step 3: 구현** — `diary-view` 제목 날짜는 받은 `Diary.date`(받기 전에는 제목 없이 app-bar). 고치기는 `context.pushReplacement(diaryPathOf(ScreenIds.diaryEdit, diary.id))`, 저장 뒤 `pushReplacement(diaryPathOf(ScreenIds.diaryView, saved.id))`. `_DiaryPageRow`는 `summary.id`로 엽니다.
- [ ] **Step 4: 통과 확인** — Step 2 명령과 나머지 일기 흐름 테스트 PASS
- [ ] **Step 5: Commit** — `feat(app): 일기 화면을 id 경로로 (D83, A67)`

### Task 6: drift 생성물과 쓰는 입구 세 곳

**Files:**
- Regenerate: `lib/core/ia/gen/ia.g.dart`(`dart run tool/gen_ia.dart`), `lib/core/l10n/arb/*.arb`(`dart run tool/import_writing_arb.dart`) 뒤 `flutter gen-l10n`, `dart run tool/gen_tokens.dart`(바뀜 없음 확인)
- Modify: `lib/design/components/today/guide_question_card.dart`(`onAction` nullable), `lib/design/components/input/month_date_picker.dart`(`onConfirm` nullable), 두 컴포넌트 테스트와 widgetbook use case(비활성 knob 하나씩)
- Modify: `lib/features/today/application/today_content.dart`(`diaryWritten` → `diaries: List<DiarySummary>`), `lib/features/today/presentation/today_screen.dart`
- Modify: `lib/features/calendar/presentation/day_sheet_body.dart`
- Modify: `lib/features/diary/presentation/diary_list_screen.dart`(`PickDateSheet`)
- Modify: `lib/features/diary/presentation/diary_page_list.dart`에서 `_DiaryPageRow`를 공개 위젯 `DiarySummaryRow({required DiarySummary summary, bool isLast, String? listTag})`로 꺼내 today·day-sheet가 함께 씁니다
- Test: `test/features/today/today_screen_test.dart`, `test/features/calendar/day_sheet_test.dart`, `test/flows/diary_list_flow_test.dart`, `test/flows/today_diary_flow_test.dart`(새), `test/screenshots/screens_test.dart`

**Interfaces:**
- Consumes: Task 3 `diariesOnProvider`·`diaryWriteEntryOf`, Task 5 `diaryPathOf`·`datedPathOf`
- Produces: `DiarySummaryRow`(위)

- [ ] **Step 1: 재생성** — 위 네 명령. 이 시점에 `day_sheet_body.dart`가 `daySheetDiaryOpen(count)`로 컴파일 오류인 것이 정상입니다.
- [ ] **Step 2: 실패하는 테스트**
  * today: 오늘 0편 → 버튼 `todayGuideCta`, 일기 줄 없음; 2편 → `todayGuideCtaWritten`, `DiarySummaryRow` 2개 작성 순, 첫 줄을 누르면 `diary-view?id=<첫 id>`; 시나리오 `diary-day-full` → `todayGuideCtaFull`, 버튼 비활성(누르면 아무 이동 없음); 목록 실패 → `todayGuideCta`·줄 없음.
  * day-sheet: 지난 날 0편 → 머리 없음·`daySheetDiaryWriteCta`; 3편 → 머리 `daySheetDiaryOpen(3)` 문구, 줄 3개, `daySheetDiaryWriteCtaWritten`; 10편·11편 → `daySheetDiaryWriteCtaFull` `PrimaryButton` 비활성; 받는 중 → skeleton; 미래 날 → 일기 입구 없음; 쓰기 버튼 → `diary-edit?date=<그날>`.
  * diary-list 날짜 골라 쓰기: 이미 쓴 날을 골라도 `diary-edit?date=`(새 일기); 10편인 날 → `diaryListPickDateConfirmFull`·버튼 비활성.
  * 흐름 `today_diary_flow_test.dart`(`Covers: today>diary-view`, `today>diary-edit`): 오늘 한 편 쓰기 → 돌아오면 줄 1개·`todayGuideCtaWritten` → 두 번째 쓰기 → 줄 2개, 달력에 오늘 도장.
- [ ] **Step 3: 실패 확인** — `flutter test test/features/today/today_screen_test.dart test/features/calendar/day_sheet_test.dart test/flows/diary_list_flow_test.dart test/flows/today_diary_flow_test.dart` FAIL
- [ ] **Step 4: 구현** — 입구에서 돌아오면 `invalidateDiaryViews` 대신 그날 `diariesOnProvider(date)`·`diaryDatesProvider`를 다시 묻습니다(지금 `_openDiary`의 자리). day-sheet의 "보기/쓰기 두 후보 자리 잡기" Stack은 머리·줄·버튼 세로 배치로 바뀝니다.
- [ ] **Step 5: 통과 확인** — Step 3 명령 PASS, `flutter analyze`와 `dart analyze`가 이슈 없음
- [ ] **Step 6: screenshot·golden** — `flutter test test/screenshots/screens_test.dart --update-goldens` 뒤 바뀐 이미지가 today·day-sheet·diary-list 날짜 시트뿐인지 확인
- [ ] **Step 7: Commit** — `feat(app): 쓰는 입구는 언제나 새 일기, 그날 일기 줄과 10편 상한 (D83, #408·#424), drift #412`

### Task 6b: design 2.7.0 컴포넌트 계약 (drift #412의 design 원인)

drift #412에는 design 컴포넌트 계약 2.7.0(PR #439)이 들어 있어 `test/contract/component_contract_test.dart`가 실패합니다(IA 컴포넌트 42개, `account-choice` 없음, `social-login-button`에 `line`·`google`·`connected` 없음). 이 task는 **컴포넌트만** 맞춥니다. 로그인 화면의 네 버튼·언어별 순서, `login-methods`·`account-merge` 화면은 계획 7(`2026-10-22-real-login.md`)에 남깁니다.

기준: design spec `docs/identity/design/specs/2026-10-22-login-methods-account-merge-design.md` §2·§3, 명세 `docs/identity/design/components/action.json`(`social-login-button`)·`input.json`(`account-choice`)·`action.md`·`input.md`.

**Files:**
- Modify: `lib/design/components/action/social_login_button.dart`(`SocialProvider`에 `line`·`google`, 변형 그리기, `connected` 상태, `spec`), `assets/brand/line/`·`assets/brand/google/`(각 사 공식 로고), `pubspec.yaml`(assets)
- Create: `lib/design/components/input/account_choice.dart`
- Modify: `widgetbook/lib/` action·input 디렉터리(use case), `test/contract/component_contract_test.dart`(개수 41 → 42)
- Test: `test/design/social_login_button_test.dart`(있으면 수정), `test/design/account_choice_test.dart`(새), action·input golden

**Interfaces:**
- Produces:
  - `enum SocialProvider { kakao, line, google, apple }`(지금 위치 그대로)
  - `SocialLoginButton`에 `bool connected = false`(연결됨 줄: 중립 바탕·배지 로고·제공자 이름·`check` + "연결됨" 라벨 인자). 문구는 인자로 받습니다(`label`, `connectedLabel`). 마지막 하나면 `onPressed: null`로 누를 수 없고 모양은 그대로입니다(V39).
  - `final class AccountChoiceOption { const new({required String name, required bool current, required String saju, required String diaryCount, required String providers}); }`
  - `class AccountChoice extends StatelessWidget { const new({required List<AccountChoiceOption> options, required int? selectedIndex, required ValueChanged<int>? onSelected, required String groupLabel, required String currentLabel, bool loading = false, String? identifier}); static const ComponentSpec spec; }` — `options`는 두 개, `selectedIndex == null`이면 `none`, `onSelected == null`이면 `disabled`(고름 잠금), `loading`이면 카드 두 장 크기의 숨쉬기 자리.

- [ ] **Step 1: 실패하는 테스트**
  * `component_contract_test.dart`가 이미 실패합니다(개수 42, `social-login-button` 변형·상태, `account-choice` 대조). 개수 기대값을 42로 고칩니다.
  * `account_choice_test.dart`: `'처음에는 어느 카드도 고르지 않는다'`(두 카드 semantics checked false), `'카드를 누르면 onSelected(그 index)'`, `'onSelected가 null이면 눌러도 바뀌지 않는다'`, `'radio-group 이름은 groupLabel, 카드 라벨은 카드 안 글자를 위에서 아래로'`, `'current 카드에만 currentLabel 알약'`, `'loading이면 카드 글자가 없다'`.
  * social-login-button: `'connected면 제공자 이름과 연결됨 라벨, 제공자 바탕색이 아님'`, `'connected이고 onPressed가 null이면 누를 수 없고 button 역할·힌트가 없다'`, `'line·google 변형이 그려진다'`.
  * golden: `social-login-button` 네 변형 × 기본·loading·disabled·connected(라이트·다크), `account-choice` none·selected·disabled·loading(라이트·다크).
- [ ] **Step 2: 실패 확인** — `flutter test test/contract/component_contract_test.dart test/design/account_choice_test.dart` FAIL
- [ ] **Step 3: 구현** — 값은 design spec §2.1(LINE `#06C755`·눌림 검정 30% 덮개·비활성 값, Google light/dark 테마 값·Google Sans Medium 14/20 없으면 시스템 글꼴), §2.3(connected 모양·배지 20px·심볼 14px·`check` 14px·"연결됨" `type.caption.lg` `action.primary`), §3(카드·고름 표시·상태·햅틱 `selection`·`select.seep-slide`/`appear.seep`). 로고는 각 사 공식 배포 자산(Google Sign-In branding 자산, LINE Login button 자산)을 받아 `assets/brand/`에 두고, 출처 URL을 그 디렉터리 `SOURCE.md`에 적습니다. 공식 자산을 받을 수 없으면 BLOCKED로 보고합니다.
- [ ] **Step 4: 통과 확인** — Step 2 명령 PASS, golden 갱신(`tool/goldens_linux.sh <파일> --update-goldens`) 뒤 같은 명령 PASS, `cd widgetbook && flutter analyze && flutter test` PASS
- [ ] **Step 5: Commit** — `feat(app): 컴포넌트 계약 2.7.0 — social-login-button LINE·Google·연결됨, account-choice (drift #412, #389)`

### Task 7: 마무리 검사, 문서, 알림

**Files:**
- Modify: `docs/decisions.md`(A67~A71, spec §10 문구 그대로, A33·A48·A51 행에 "A70·A68·A67이 갱신" 표시), `CLAUDE.md`(현재 상태 한 줄, 다음 할 일에서 #408·#424·#437·#412 제거, #410 대기 추가), `patrol_test/diary_test.dart`(일기 id 경로로 깨지는 단계만 고침)
- Test: 전체

- [ ] **Step 1: drift 검사 재현** — `dart run tool/gen_ia.dart && dart run tool/gen_tokens.dart && flutter gen-l10n && tool/gen_api.sh && git status --porcelain -- .` 출력 없음
- [ ] **Step 2: 전체 검사** — `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `dart analyze`, `dart run tool/ia_coverage.dart --check`, `flutter test --exclude-tags golden`, golden job과 같은 `flutter test --tags golden`, 루트에서 `uv run --project docs/identity/writing/tools mlw check-arb app/lib/core/l10n/arb/*.arb`, fixture 검증, `app/widgetbook`에서 `flutter analyze && flutter test`. 모두 통과
- [ ] **Step 3: Patrol(로컬)** — `tool/patrol_local.sh patrol_test/diary_test.dart`와 `tool/patrol_local.sh patrol_test/today_test.dart` 통과
- [ ] **Step 4: Commit** — `docs(app): 일기 하루 여러 편 결정 A67~A71과 현재 상태`
- [ ] **Step 5: 알림(PR을 올린 뒤)** — #418: `errorDiaryDateTaken`을 더 쓰지 않음. #424: 되살리기 UI가 없어(A50) 되살리기 422는 해당 없음. #408: 목록의 날짜 묶음 모양은 design #410 답으로 맞춤.
- [ ] **Step 6: PR** — 본문 `Closes #412`, `Closes #437`, `Closes #424`, `Closes #408`

### Task 8: design 2.8.0 컴포넌트 — `diary-row` `day`·`entries`, `guide-question-card` `full` (spec §13)

main 병합(`4b89cf9e`)으로 컴포넌트 2.8.0·토큰 1.2.0·IA(#460)가 들어와 `component_contract_test` 2건(`guide-question-card` `full`, `diary-row` `day`·`entries`)이 실패하고 생성물 두 개(`ia.g.dart`·`tokens.g.dart`)가 낡았습니다. 이 task는 **생성물과 컴포넌트만** 맞춥니다. 화면 연결은 Task 9입니다.

기준: spec §13, design spec `../docs/identity/design/specs/2026-10-22-diary-row-multi-design.md`, 명세 `../docs/identity/design/components/diary.json`·`diary.md`(`diary-row`), `today.json`·`today.md`(`guide-question-card`), `sentence.json`(`depth-link`), 토큰 `color.timeline.entry`.

**Files:**
- Regenerate: `lib/core/ia/gen/ia.g.dart`, `lib/design/tokens/gen/tokens.g.dart`, l10n(바뀌면)
- Modify: `lib/design/components/diary/diary_row.dart`, `lib/design/components/today/guide_question_card.dart`, `lib/design/components/sentence/depth_link.dart`(`daySheetSlot`이 남았으면 삭제)
- Modify: `test/contract/component_contract_test.dart`, widgetbook diary·today use case
- Test: diary-row·guide-question-card 위젯 테스트(기존 파일), golden(diary·today)

**Interfaces:**
- Produces:
  - `class DiaryEntryLine extends StatelessWidget { const new({required DateTime createdAt, required String excerpt, required VoidCallback onTap, bool showDivider = false, String? identifier}); }` — `showDivider`면 줄 위에 점선(첫 줄은 false).
  - `class DiaryEntryData { const new({required DateTime createdAt, required String excerpt, required VoidCallback onTap}); }`
  - `class DiaryDayGroup extends StatelessWidget`(`day` 두 편 이상): `DiaryRow`의 날짜·배지·태그 인자에 `entries: List<DiaryEntryData>`(2개 이상, assert)를 더하고 `onTap`은 없습니다.
  - `class DiaryEntries extends StatelessWidget { const new({required List<DiaryEntryData> entries, required DiaryEntriesSurface surface, String? head}); }`, `enum DiaryEntriesSurface { card, plain }` — `card`는 오늘(명세 `byScreen.today`), `plain`은 그날 시트(머리 `head`가 있으면 명세 `head` 스타일로 위에). 빈 목록이면 `SizedBox.shrink()`.
  - `DiaryEntriesSkeleton`(줄 두 개 높이).
  - `GuideQuestionState.full`.

- [ ] **Step 1: 생성물** — `dart run tool/gen_ia.dart && dart run tool/gen_tokens.dart && flutter gen-l10n`, `git status`에 두 생성 파일 차이. `flutter test test/contract/component_contract_test.dart`가 위 2건만 실패하는지 확인.
- [ ] **Step 2: 실패하는 테스트**
  * contract: `diary-row` 변형 `day`·`entries`, `entry`의 시각 글자 스타일·미리보기 1줄·간격 12·꺾쇠 16·위아래 12·최소 48·점선(1·4·3·`color.timeline.entry`), `entries.container.byScreen.today` 값과 `head` 값을 공개 상수와 대조. `guide-question-card` `full`의 버튼 변형·상태와 도장 유지.
  * 위젯: `'entry 줄은 시각과 미리보기 첫 줄을 읽는다'`, `'본문이 비면 시각만 읽고 한 줄 높이를 지킨다'`, `'점선은 줄과 줄 사이에만'`(첫 줄 위·끝 줄 아래 없음), `'묶음 카드는 버튼이 아니고 그룹, 안의 줄이 각각 버튼'`, `'entries가 비면 아무것도 그리지 않는다'`, `'full이면 버튼을 눌러도 onAction이 불리지 않고 햅틱이 없다'`, `'full에서도 도장이 남는다'`.
  * golden: `diary-row` 한 편·묶음(3편)·entries card·entries plain(머리 포함)·빈 본문 줄, `guide-question-card` before·after·full(라이트·다크, 기존 golden 글자 크기 관례).
- [ ] **Step 3: 실패 확인** — 해당 테스트 파일 FAIL
- [ ] **Step 4: 구현** — 값은 명세 그대로. 시각은 `createdAt.toLocal()`을 `DateFormat.jm(localeName)`으로(설정 화면과 같은 형식). 점선은 `CustomPainter`. 묶음 카드의 흐름 줄은 카드 높이만큼 잇습니다. 눌림은 `PressInkTarget`(줄 안). 
- [ ] **Step 5: 통과 확인** — 해당 테스트 PASS, `tool/goldens_linux.sh`(단독 실행) 뒤 새 PNG를 열어 확인, `cd widgetbook && flutter analyze && flutter test` PASS
- [ ] **Step 6: Commit** — `feat(app): 컴포넌트 2.8.0 — diary-row day·entries와 점선, guide-question-card full (D83, #410)`

### Task 9: 화면에 2.8.0 연결, 결정 A72, 마무리 검사

**Files:**
- Modify: `lib/features/today/presentation/today_screen.dart`(가이드 카드 아래 `DiaryEntries` card, `full` 상태), `lib/features/calendar/presentation/day_sheet_body.dart`(머리 + `DiaryEntries` plain + 버튼, `DiaryMonthHeader` 빌림 제거), `lib/features/diary/presentation/diary_page_list.dart`(같은 날 묶음), `lib/features/diary/application/diary_summary_rows.dart`·`lib/app/diary_summary_rows.dart`(줄 builder가 entries 데이터로 바뀌면 그에 맞게, feature 간 presentation import 금지 규칙 유지)
- Create: 묶음 순수 함수 `groupDiariesByDate(List<DiarySummary>) → List<List<DiarySummary>>`(위치는 `lib/features/diary/model/` 또는 application, 관례에 맞춤)
- Modify: `docs/decisions.md`(A72, spec §10 문구 그대로, A69 행에 "(A72가 갱신)"), `CLAUDE.md`(현재 상태 줄에 2.8.0, real-login 초안 번호를 "A73부터 다시 매김"으로, #410 대기 bullet 삭제)
- Test: 묶음 함수 단위 테스트, today·day-sheet·diary-list 위젯/흐름 테스트, screenshot

- [ ] **Step 0: REST draft.14 따라잡기(main 병합으로 들어옴, 추가만)** — `tool/gen_api.sh` 재생성, `test/contract/open_enums_contract_test.dart`의 기대 열린 enum 목록에 계약이 새로 연 enum(`LoginProvider` 등, 실패 메시지 그대로)을 더함, `test/contract/problem_codes_contract_test.dart`의 `_awaitingWriting`에 draft.14의 새 code(실패 메시지의 `missing` 목록 그대로)를 넣고 주석의 "지금은 없습니다"를 "D82 draft.14 code, writing 문구 대기"로. `gen_api_routes_test`의 operation 수가 바뀌면 계약 수로. 화면·동작 변화는 없습니다(새 operation은 계획 7이 씀). `flutter test --tags contract` PASS 뒤 commit `chore(app): REST draft.14 생성 클라이언트와 대기 code (D82, #463)`
- [ ] **Step 1: 실패하는 테스트**
  * 묶음: `'같은 날 이웃만 묶는다'`, `'순서를 바꾸지 않는다'`(같은 날 안 작성 순 그대로), `'빈 목록은 빈 목록'`, `'한 날짜가 두 쪽에 나뉘어도 이어 붙인 뒤 한 묶음'`.
  * today: `'오늘 쓴 일기가 있으면 가이드 카드 아래 entry 줄, 누르면 diary-view?id='`, `'0편이면 entries를 그리지 않는다'`, `'10편이면 가이드 카드가 full'`.
  * day-sheet: `'머리 편수 → 줄 → 버튼 순서'`, `'0편이면 버튼만'`, `'머리는 링크가 아니다'`.
  * diary-list: `'같은 날 두 편은 묶음 카드 하나, 날짜 열은 한 번'`, `'다음 쪽에 이어지는 같은 날은 같은 묶음 카드로 커진다'`.
- [ ] **Step 2: 실패 확인** — FAIL
- [ ] **Step 3: 구현** — spec §13. 오늘·그날 시트 줄에 태그 칩이 없어지므로 `tagLinked` 인자는 쓰는 곳이 남을 때만 유지합니다.
- [ ] **Step 4: 전체 검사** — Task 7 Step 1·2와 같은 명령 전부(drift 재현, format, analyze 둘, `ia_coverage --check`, `flutter test --exclude-tags golden`, golden 단독, `mlw check-arb`, fixture, widgetbook), screenshot 재생성, Patrol `diary_test.dart`·`today_test.dart`
- [ ] **Step 5: Commit** — `feat(app): 오늘·그날 시트·일기 목록에 같은 날 여러 편 모양 (D83, #410, A72)`
