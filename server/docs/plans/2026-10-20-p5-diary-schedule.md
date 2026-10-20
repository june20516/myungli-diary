# P5 일기·일정 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 일기(`listDiaries`·`getDiary`·`putDiary`·`deleteDiary`·`restoreDiary`)와 일정(`listSchedules`·`createSchedule`·`updateSchedule`·`deleteSchedule`·`restoreSchedule`)이 실제로 응답하고, 생성 POST가 `Idempotency-Key`를 지키게 합니다.

**Architecture:** `internal/diary`와 `internal/schedule`이 각자 sqlc 패키지(`diarydb`·`scheduledb`)와 서비스를 가집니다. 일기 저장 때 그날의 태그·`ruleset_version`·가이드 질문은 `fortune.Views.DayRecord`가 만들고, `diary`는 이를 인터페이스(`diary.Days`)로만 씁니다(spec §2.2). 멱등 키는 `httpapi` 미들웨어가 `idempotency_keys` 표로 처리하며 도메인은 모릅니다.

**Tech Stack:** Go 1.27, sqlc/pgx/goose, oapi-codegen strict server, testcontainers(`dbtest`), `clock.Clock`

**Spec:** `server/docs/specs/2026-10-11-server-mvp-design.md` §3.1·§3.2(일정 시각 짝)·§3.3 일기·일정·`idempotency_keys`, §5.1(cursor, `Idempotency-Key`), §5.2 일기·일정 행, §5.3(오늘 D30, 일기 날짜 D49, 저장 때 기록 D47·D59④, 동시 저장), §11.2(멱등 409·422). REST 계약 `server/api/openapi.yaml` 1.0.0-draft.6.

## Global Constraints

* 행을 물리적으로 지우지 않습니다. 일기·일정 삭제는 `deleted_at` soft delete이고, 조회는 모두 `deleted_at IS NULL`입니다. FK는 `ON DELETE RESTRICT`입니다(S6·S7). 예외는 시스템 데이터인 `idempotency_keys`입니다.
* 일기는 하루 1편입니다: partial unique `(account_id, date) WHERE deleted_at IS NULL`(D49). `all_tags`에 GIN 인덱스(D47①).
* "오늘"은 프로필 `current_timezone` 기준 날짜이고 `clock.Clock`으로 셉니다(D30). 오늘 이후 일기는 422 `diary.future_date`, 지난 날은 쓸 수 있습니다.
* 일기 저장 때 그날 엔진 결과의 `all_tags`, `featured_tags`(키와 길흉), `ruleset_version`, 가이드 질문의 렌더된 조각 배열을 함께 기록합니다(D47·D59④). 그날 선택 기록이 없으면 저장할 때 고릅니다(spec §5.3).
* 일정 시각 짝: `all_day = false`일 때만 `time`이 있습니다(CHECK). 422 `request.inconsistent`의 field·rule은 계약 `ScheduleInput`·`SchedulePatch` 설명 그대로입니다(`/time`, `required_by_status`·`forbidden_by_status`).
* `listSchedules`는 `from`·`to` 포함 62일 이내, 넘으면 422 `range.too_long`입니다.
* 없는 일기는 404 `diary.not_found`, 없는 일정(남의 일정, 지운 일정 포함)은 404 `schedule.not_found`입니다.
* 멱등(spec §5.1·§11.2): 같은 계정·같은 키는 24시간 동안 같은 응답(상태·본문·`Location`). 처리 중이면 409 `idempotency.in_progress`, 본문이 다르면 422 `idempotency.mismatch`. 키가 없으면 멱등 처리 없이 그대로 처리합니다.
* ID는 UUIDv7, 시각 `timestamptz`, 날짜 `date`입니다. 일정 `time`은 `time` 열(분 단위)입니다.
* 로그에 일기 본문·일정 제목·메모를 남기지 않습니다.
* 공개 저장소(D74): 커밋·PR·fixture에 가격·수익 수치와 비공개 경로 링크를 넣지 않습니다.

## Review Focus

1. 같은 날짜에 두 기기가 동시에 처음 `putDiary`: 하나는 201, 다른 하나는 200이고 일기는 한 편이어야 합니다(500이나 두 행이 아님).
2. 시간대 경계: UTC로는 아직 어제인 서울 00:05에 오늘 일기를 쓸 수 있고, 내일 날짜는 422여야 합니다.
3. 쓰기 → 지우기 → 쓰기 → 지우기 뒤 되살리기: 가장 최근에 지운 일기가 돌아오고, 그날 살아 있는 일기가 있으면 409 `diary.date_taken`이어야 합니다.
4. 같은 `Idempotency-Key`로 일정 만들기를 다시 보냄: 같은 id·`Location`·본문, 일정은 하나. 본문이 다르면 422, 첫 요청이 아직 처리 중이면 409. 첫 요청이 실패(4xx·5xx)했으면 같은 키로 다시 시도할 수 있어야 합니다.
5. 일기 목록을 넘기는 사이에 일기를 새로 쓰거나 지움: 다음 쪽에 중복이나 빠짐이 없어야 합니다(날짜 keyset cursor).

---

## 결정 (plan이 정한 것)

| # | 결정 | 근거 |
| --- | --- | --- |
| P5-1 | 이미 있는 일기를 `putDiary`로 고치면 본문만 바꾸고, 태그·`ruleset_version`·가이드 질문은 처음 쓸 때 기록한 값을 유지합니다. 기록은 그 일기를 쓸 때 본 질문과 그날 결과라서입니다. | D59④ |
| P5-2 | 길흉은 저장 때 `featured_tags`(jsonb `[{key, polarity}]`)에 같이 적습니다. 태그 길흉 표(S36)는 `httpapi`에서 `fortune`으로 옮겨(`fortune.TagPolarity`) 운세 응답과 일기가 함께 씁니다. | spec §3.3 `featured_tags: 키·길흉` |
| P5-3 | 가이드 질문은 `fortune.Views.Daily`가 렌더한 `daily.guide` 문장입니다. 원고가 없어 문장이 비면 `guide_question`은 NULL이고 응답에서 생략합니다(계약에서 선택 필드). | 계약 `Diary.guideQuestion` |
| P5-4 | `restoreDiary`는 그 날짜에 지운 일기 중 `deleted_at`이 가장 늦은 것을 되살립니다. 그날 살아 있는 일기가 있으면 409 `diary.date_taken`, 지운 일기가 없으면 404 `diary.not_found`입니다. | 계약 `restoreDiary` |
| P5-5 | `restoreSchedule`은 지운 일정을 되살리고, 이미 살아 있는 일정이면 그대로 200입니다(같은 요청을 다시 보내도 같은 결과). 없으면 404 `schedule.not_found`입니다. | spec §5.1 멱등 원칙 |
| P5-6 | 일기 목록 cursor는 마지막 항목의 날짜를 base64url로 감싼 불투명 문자열입니다. 날짜가 계정 안에서 유일하므로(살아 있는 일기) keyset `date < cursor`로 넘깁니다. 해석할 수 없는 cursor는 400 `request.invalid`(field `/cursor`)입니다. | spec §5.1, Review Focus 5 |
| P5-7 | `listDiaries`의 `from > to`는 빈 목록입니다. `listSchedules`의 `from > to`는 400 `request.invalid`(field `/from`)입니다. 일정 목록은 범위가 필수이고 범위 검사(62일)와 같은 자리에서 판정하기 때문입니다. | 계약 각 operation |
| P5-8 | `excerpt`는 본문 앞 100 code point입니다(NFC 뒤). | 계약 `DiarySummary.excerpt` |
| P5-9 | 일정 `memo`의 빈 문자열은 NULL로 저장하고 응답에서 생략합니다(PATCH의 `""`는 지우기). | 계약 `SchedulePatch` |
| P5-10 | 일정 날짜에는 D41 범위 검사를 하지 않습니다. 엔진 계산이 없는 사용자 기록이기 때문입니다. | D41은 계산 범위 |
| P5-11 | 멱등 키 행은 첫 요청 때 `completed_at` 없이 넣고(같은 키 경쟁은 PK가 가름), 2xx면 응답을 저장하고, 2xx가 아니면 행을 지워 다시 시도할 수 있게 합니다. 24시간 지난 행은 없는 것으로 보고 덮어씁니다. 요청 지문은 메서드·경로·본문의 SHA-256입니다. | spec §11.2, Review Focus 4 |
| P5-12 | 계정 익명화 때 일기 본문·일정 제목·메모를 지우는 일(`content_purged_at`)은 P8입니다. P5는 열만 둡니다. | spec §9 |

---

### Task 1: 계약 설명 보강 (draft.7, 계약 먼저 병합)

**Files:**
- Modify: `server/api/openapi.yaml`, `server/api/contract_test.go`, `server/internal/httpapi/gen/api.gen.go`(재생성), `docs/contracts/README.md`(REST 행)

- [ ] **Step 1:** `contract_test.go`에 `TestContract_Draft7Additions`를 더합니다(draft.6 테스트와 같은 형식). 버전 테스트를 `TestContract_VersionIsDraft7`(`1.0.0-draft.7`)로 바꿉니다. 고정할 설명: `putDiary`에 "본문만 바꾸고", `restoreDiary`에 "가장 늦게 지운", `listDiaries`에 "`from`이 `to`보다 늦으면 빈 목록", `listSchedules`에 "`from`이 `to`보다 늦으면 400 `request.invalid`", `restoreSchedule`에 "이미 살아 있는 일정이면 그대로", `listSchedules`·`restoreSchedule`·`deleteSchedule`의 404 code `schedule.not_found`.
- [ ] **Step 2:** `cd server && go test ./api/` → FAIL(설명 없음, 버전 draft.6).
- [ ] **Step 3:** openapi에 P5-1·P5-4·P5-5·P5-7 문장을 operation 설명으로 넣고 `info.version`을 `1.0.0-draft.7`로 올립니다. `go generate ./...`.
- [ ] **Step 4:** `go test ./api/ ./internal/httpapi/` → PASS.
- [ ] **Step 5:** README REST 행 버전·내용(draft.7: 설명만) 고치고 commit `feat(server): 계약 1.0.0-draft.7 — 일기·일정 동작 설명`. 이 task만 담은 PR을 먼저 올립니다(계약 먼저 병합, workflow §6).

### Task 2: 태그 길흉 표 이동과 그날 기록(`fortune.DayRecord`)

**Files:**
- Create: `server/internal/fortune/polarity.go`, `server/internal/fortune/dayrecord.go`, 각 `_test.go`
- Modify: `server/internal/httpapi/fortune_convert.go`(표를 지우고 `fortune.TagPolarity` 사용)

**Interfaces:**
- Produces:
  - `func TagPolarity(key string) (Polarity, bool)`, `type Polarity string`(`PolarityGood`·`PolarityBad`·`PolarityNeutral` = `"good"`·`"bad"`·`"neutral"`)
  - `type FeaturedTag struct{ Key string; Polarity Polarity }`
  - `type DayRecord struct{ AllTags []string; Featured []FeaturedTag; RulesetVersion string; GuideQuestion []render.Segment }` (`GuideQuestion`은 원고가 없으면 nil)
  - `func (v *Views) DayRecord(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (DayRecord, error)`

- [ ] **Step 1:** 테스트: `TestTagPolarity`는 지금 `fortune_convert.go` 표의 15키 전부와 모르는 키(false)를 확인합니다. `TestViews_DayRecord`(views_test 픽스처 재사용)는 `dailyResponse(true)`에 `AllTags: ["dohwa","yeokma"]`, `FeaturedTags: ["dohwa"]`를 넣고 `RulesetVersion "rs-1"`, `Featured [{dohwa, good}]`(표의 값), 가이드 질문 `"눈길이 간 사람을 적어 볼까요?"`를 확인합니다. 가이드 원고를 뺀 시드(`viewSeed(t, "", fortune.SlotGuide)`)면 `GuideQuestion`이 nil입니다. 표에 없는 대표 태그는 오류입니다(엔진 계약 위반).
- [ ] **Step 2:** `go test ./internal/fortune/ -run 'TagPolarity|DayRecord'` → FAIL.
- [ ] **Step 3:** 표를 옮기고 `DayRecord`를 구현합니다. `Daily`를 불러 그 결과에서 뽑습니다(선택 기록도 `Daily`가 남김). 빈 조각 배열(`emptyText`)은 nil로 바꿉니다. `httpapi`의 기존 변환은 `fortune.TagPolarity`를 씁니다.
- [ ] **Step 4:** `go test ./internal/fortune/ ./internal/httpapi/` → PASS.
- [ ] **Step 5:** Commit `feat(server): 그날 기록 DayRecord, 태그 길흉 표를 fortune으로`.

### Task 3: 일기 표와 저장소

**Files:**
- Create: `server/db/migrations/00006_diaries.sql`, `server/db/queries/diary.sql`, `server/internal/diary/diarydb/`(생성), `server/internal/diary/store.go`, `store_test.go`
- Modify: `server/db/sqlc.yaml`(`diarydb` 추가)

**Interfaces:**
- Produces (`package diary`):
  - `type Entry struct{ Date profile.LocalDate; Body string; AllTags []string; Featured []fortune.FeaturedTag; GuideQuestion []render.Segment; RulesetVersion string; CreatedAt, UpdatedAt time.Time }`
  - `type Store struct` / `func NewStore(pool *pgxpool.Pool) *Store`
  - `(s *Store) Get(ctx, accountID uuid.UUID, date profile.LocalDate) (Entry, error)` — 없으면 `ErrNotFound`
  - `(s *Store) Upsert(ctx, accountID uuid.UUID, e Entry) (Entry, bool, error)` — bool은 새로 만들었는지
  - `(s *Store) Delete(ctx, accountID uuid.UUID, date profile.LocalDate) error`
  - `(s *Store) Restore(ctx, accountID uuid.UUID, date profile.LocalDate) (Entry, error)` — `ErrNotFound`, `ErrDateTaken`
  - `(s *Store) List(ctx, accountID uuid.UUID, q ListQuery) ([]Entry, error)`, `type ListQuery struct{ From, To *profile.LocalDate; Tag *string; Before *profile.LocalDate; Limit int }`
  - sentinel `ErrNotFound`, `ErrDateTaken`

- [ ] **Step 1:** migration: spec §3.3 `diaries` 열(`id uuid PK`, `account_id` FK RESTRICT, `date`, `body text NOT NULL`, `all_tags text[] NOT NULL`, `featured_tags jsonb NOT NULL`, `guide_question jsonb`, `ruleset_version text NOT NULL`, `created_at`, `updated_at`, `deleted_at`, `content_purged_at`), partial unique `diaries_one_per_day (account_id, date) WHERE deleted_at IS NULL`, GIN `(all_tags)`, 목록용 `(account_id, date DESC) WHERE deleted_at IS NULL`.
- [ ] **Step 2:** 테스트(`dbtest`): `TestStore_UpsertCreatesThenUpdatesBodyOnly`(두 번째 Upsert는 false, 본문만 바뀌고 태그·질문·ruleset·created_at 유지 — P5-1), `TestStore_ConcurrentUpsertKeepsOneRow`(goroutine 둘, 하나만 true, 행 하나 — Review Focus 1), `TestStore_DeleteThenGetIsNotFound`, `TestStore_RestoreLatestDeleted`(쓰기·지우기 두 번 뒤 두 번째 본문이 돌아옴 — P5-4), `TestStore_RestoreWhenAliveIsDateTaken`, `TestStore_RestoreWithoutDeletedIsNotFound`, `TestStore_ListFiltersRangeTagAndDeleted`, `TestStore_ListBeforeIsKeyset`(limit 2로 넘기는 사이 새 일기를 넣어도 중복·빠짐 없음 — Review Focus 5), `TestStore_OtherAccountInvisible`.
- [ ] **Step 3:** `go generate ./...`(sqlc) 뒤 `go test ./internal/diary/` → FAIL.
- [ ] **Step 4:** 구현. Upsert는 `INSERT … ON CONFLICT (account_id, date) WHERE deleted_at IS NULL DO UPDATE SET body, updated_at RETURNING …, (xmax = 0) AS created`. Restore는 한 트랜잭션에서 살아 있는 행 확인 → 가장 늦게 지운 행의 `deleted_at`을 NULL로(unique 위반은 `ErrDateTaken`). 조각 배열 jsonb는 `[{"text":…,"term":…}]`(term은 없으면 생략).
- [ ] **Step 5:** `go test ./internal/diary/` → PASS. Commit `feat(server): 일기 표와 저장소`.

### Task 4: 일기 서비스

**Files:**
- Create: `server/internal/diary/service.go`, `service_test.go`

**Interfaces:**
- Consumes: Task 2 `fortune.DayRecord`, Task 3 `Store`
- Produces:
  - `type Days interface{ DayRecord(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (fortune.DayRecord, error) }` (`*fortune.Views`가 만족)
  - `type Service struct` / `func NewService(store *Store, days Days, clk clock.Clock) *Service`
  - `(s *Service) Put(ctx, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (Entry, bool, error)` — 오늘 이후면 `ErrFutureDate`
  - `Get`·`Delete`·`Restore`·`List`는 Store로 넘깁니다(목록은 Task 5가 cursor를 다룸).

- [ ] **Step 1:** 테스트(가짜 `Days`, `clocktest`): `TestService_PutFutureDateIsError`(서울 2026-10-20 00:05 = UTC 10-19 15:05에 10-20은 통과, 10-21은 `ErrFutureDate` — Review Focus 2), `TestService_PutNewRecordsDay`(Days를 한 번 부르고 기록이 저장됨), `TestService_PutExistingSkipsDays`(이미 있으면 Days를 부르지 않음 — P5-1), `TestService_PutPassesEngineErrors`(Days 오류 그대로, 행 없음).
- [ ] **Step 2:** `go test ./internal/diary/ -run Service` → FAIL.
- [ ] **Step 3:** 구현. 미래 판정은 `p.CurrentTimezone`의 `clk.Now()` 날짜와 비교. 이미 있는지는 `Store.Get`으로 먼저 보고, 없을 때만 `DayRecord` 뒤 `Upsert`(그 사이 다른 기기가 만들었으면 Upsert가 본문만 고침 — 결과는 같음).
- [ ] **Step 4:** PASS. Commit `feat(server): 일기 서비스(미래 날짜, 저장 때 그날 기록)`.

### Task 5: 일기 operation 5개

**Files:**
- Create: `server/internal/httpapi/diary_handlers.go`, `diary_handlers_test.go`
- Modify: `server/internal/httpapi/api.go`(`Diaries DiaryService` 필드와 인터페이스), `errors.go`(`diary.ErrNotFound`→`diary.not_found`, `ErrDateTaken`→`diary.date_taken`, `ErrFutureDate`→`diary.future_date` field `/date`), `unimplemented.go`(일기 5개 제거)

**Interfaces:**
- Consumes: Task 4 `Service`
- Produces: `func encodeDiaryCursor(d profile.LocalDate) string`, `func decodeDiaryCursor(s string) (profile.LocalDate, error)`

- [ ] **Step 1:** 테스트(가짜 서비스, `expectContractResponse`): `putDiary` 새로 201·고침 200, 본문 `tags.featured[].polarity`·`guideQuestion.segments`·`rulesetVersion`; 프로필 없음 409; 미래 422 `diary.future_date`; 엔진 범위 밖 422 `date.out_of_range`(`outOfRangeError` 재사용); `getDiary` 없음 404; `deleteDiary` 204·없음 404; `restoreDiary` 200·409·404; `listDiaries` limit+1개를 받으면 `nextCursor`가 있고 그 cursor로 다음 쪽(`Before`)을 요청, 마지막 쪽은 `nextCursor` 없음, 깨진 cursor 400 `request.invalid` field `/cursor`(P5-6), `from > to` 빈 목록(P5-7), `excerpt` 100 code point(P5-8, 101자 본문·한글 결합 문자 NFC 확인).
- [ ] **Step 2:** `go test ./internal/httpapi/ -run Diar` → FAIL.
- [ ] **Step 3:** 구현. 목록은 `Limit+1`개를 받아 다음 쪽 여부를 정합니다.
- [ ] **Step 4:** PASS. Commit `feat(server): 일기 operation`.

### Task 6: 일정 표·서비스·operation 5개

**Files:**
- Create: `server/db/migrations/00007_schedules.sql`, `server/db/queries/schedule.sql`, `server/internal/schedule/`(`scheduledb/`, `schedule.go`, `store.go`, `service.go`, 테스트), `server/internal/httpapi/schedule_handlers.go`, `schedule_handlers_test.go`
- Modify: `server/db/sqlc.yaml`, `server/internal/httpapi/api.go`(`Schedules ScheduleService`), `errors.go`(`schedule.ErrNotFound`→`schedule.not_found`, `ErrRangeTooLong`→`range.too_long` field `/to`, `ErrRangeReversed`→`request.invalid` field `/from`), `unimplemented.go`

**Interfaces:**
- Produces (`package schedule`):
  - `type Schedule struct{ ID uuid.UUID; Date profile.LocalDate; AllDay bool; Time *profile.LocalTime; Title string; Memo *string; CreatedAt, UpdatedAt time.Time }`
  - `type Input struct{ Date profile.LocalDate; AllDay bool; Time *profile.LocalTime; Title string; Memo *string }`, `type Patch struct{ Date *profile.LocalDate; AllDay *bool; Time *profile.LocalTime; Title *string; Memo *string }`
  - `(s *Service) List(ctx, accountID, from, to profile.LocalDate) ([]Schedule, error)`, `Create(ctx, accountID, Input) (Schedule, error)`, `Update(ctx, accountID, id uuid.UUID, Patch) (Schedule, error)`, `Delete(ctx, accountID, id) error`, `Restore(ctx, accountID, id) (Schedule, error)`
  - `MaxRangeDays = 62`, sentinel `ErrNotFound`, `ErrRangeTooLong`, `ErrRangeReversed`; 짝 위반은 `*profile.ValidationError`(기존 `validationError` 변환 재사용)

- [ ] **Step 1:** migration: `schedules`(spec §3.3 열 + `id uuid PK`, `time time`, CHECK `schedules_time_by_all_day ((all_day AND time IS NULL) OR (NOT all_day AND time IS NOT NULL))`, `memo` NULL 허용), 인덱스 `(account_id, date) WHERE deleted_at IS NULL`.
- [ ] **Step 2:** 테스트: 서비스(`dbtest`) — 62일 경계(`from`~`to` 포함 62일 통과, 63일 `ErrRangeTooLong`), `from > to` `ErrRangeReversed`, 목록 정렬(날짜 → 종일 먼저 → 시각 → created_at), 남의 일정·지운 일정 Update/Delete `ErrNotFound`, Patch 규칙 셋(계약 `SchedulePatch` 설명의 `allDay` true로 바꾸면 time 지움 / false로 바꾸는데 time 없음 `required_by_status` `/time` / 결과 종일인데 time 보냄 `forbidden_by_status`), `memo: ""`는 NULL(P5-9), Restore 지운 일정·살아 있는 일정 둘 다 200(P5-5). 핸들러 — `createSchedule` 201과 `Location: /v1/schedules/{id}`, 각 오류의 code·field, 계약 응답 검증.
- [ ] **Step 3:** `go test ./internal/schedule/ ./internal/httpapi/ -run Schedule` → FAIL.
- [ ] **Step 4:** 구현. ID는 `uuid.NewV7`. Update는 행을 `FOR UPDATE`로 읽어 Patch를 적용한 결과로 짝을 검사합니다.
- [ ] **Step 5:** PASS. Commit `feat(server): 일정 표·서비스·operation`.

### Task 7: `Idempotency-Key` 미들웨어

**Files:**
- Create: `server/db/migrations/00008_idempotency_keys.sql`, `server/db/queries/idempotency.sql`, `server/internal/httpapi/idempotency.go`, `idempotency_test.go`
- Modify: `server/db/sqlc.yaml`(`idempotencydb`, `out: ../internal/httpapi/idempotencydb`), `server/internal/httpapi/server.go`(인증 뒤에 끼움)

**Interfaces:**
- Produces: `func Idempotency(store IdempotencyStore, clk clock.Clock, routes []IdempotentRoute) func(http.Handler) http.Handler`, `type IdempotentRoute struct{ Method, Path string }`(P5는 `POST /v1/schedules`, `registerDevice`는 P8에서 더함), `IdempotencyTTL = 24 * time.Hour`

- [ ] **Step 1:** migration: `idempotency_keys(account_id uuid FK RESTRICT, key text, request_hash bytea CHECK 32바이트, status int, headers jsonb, body bytea, created_at, completed_at, PRIMARY KEY (account_id, key))`.
- [ ] **Step 2:** 테스트(`dbtest` + 실제 핸들러 체인): 같은 키·같은 본문 두 번 → 같은 상태·본문·`Location`, 일정 행 하나; 같은 키·다른 본문 → 422 `idempotency.mismatch`; 첫 요청이 처리 중(핸들러를 채널로 붙잡음)에 두 번째 → 409 `idempotency.in_progress`; 첫 요청이 422면 행이 지워져 같은 키로 다시 성공; 24시간 지난 키는 새 요청으로 처리(`clocktest`); 다른 계정의 같은 키는 서로 무관; 키 없는 요청은 표를 건드리지 않음; 대상이 아닌 경로는 통과(P5-11, Review Focus 4).
- [ ] **Step 3:** `go test ./internal/httpapi/ -run Idempotency` → FAIL.
- [ ] **Step 4:** 구현. 본문을 읽어 지문을 만든 뒤 `r.Body`를 되돌려 놓고, 응답은 `ResponseWriter` 래퍼로 모읍니다.
- [ ] **Step 5:** PASS. Commit `feat(server): Idempotency-Key 미들웨어`.

### Task 8: 조립, 검증, 문서와 요청함

**Files:**
- Modify: `server/cmd/server/`(serve 조립: `diary.NewService(…, views, clk)`, `schedule.NewService`, 미들웨어), `server/CLAUDE.md`, `server/docs/decisions.md`(P5-1~P5-12 중 오래 남을 것을 S50~로), `server/docs/specs/2026-10-11-server-mvp-design.md`(§3.3 `featured_tags` 형태, §5.3 고칠 때 기록 유지), `server/docs/plans/README.md`(넘길 메모: P8에 `content_purged_at`·`idempotency_keys` 정리·`registerDevice` 멱등 경로)

- [ ] **Step 1:** `serve` 조립 테스트(기존 조립 테스트 형식)에 일기·일정 operation이 501이 아님을 더합니다.
- [ ] **Step 2:** 전체 확인: `cd server && go vet ./... && golangci-lint run ./... && go test -race ./... && go generate ./... && git status --porcelain`(빈 출력) → 모두 통과.
- [ ] **Step 3:** 문서 갱신 후 commit `docs(server): P5 결정과 현재 상태`. PR 본문에 처리한 Issue가 없으면 `처리한 Issue: 없음`.
