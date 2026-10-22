# 일기 하루 여러 편 (D83) Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 일기를 한 날짜에 10편까지 쓸 수 있게 저장을 날짜 기록(`diary_days`)과 일기 한 편(`diaries`)으로 나누고, 일기 REST API를 id 경로로 바꿉니다(draft.13).

**Architecture:** 날짜 기록은 그날 첫 편을 쓸 때 `fortune.Views.DayRecord`로 만들어 `diary_days`에 한 번 넣고 바꾸지 않습니다. 만들기·되살리기는 그 행을 `FOR UPDATE`로 잠근 트랜잭션 안에서 살아 있는 편수를 세어 10편 상한을 지킵니다. 계약을 먼저 병합(PR A, 새 operation은 501)하고, 구현(PR B)이 뒤따릅니다.

**Tech Stack:** Go 1.27, sqlc/pgx/goose, oapi-codegen strict server, kin-openapi(계약 테스트), testcontainers(`dbtest`), `clock.Clock`

**Spec:** `server/docs/specs/2026-10-22-diary-multi-design.md` (§ 번호는 이 spec). REST 계약 `server/api/openapi.yaml` 1.0.0-draft.12 → draft.13.

## Global Constraints

* 한 날짜에 살아 있는(`deleted_at IS NULL`) 일기는 `diary.MaxEntriesPerDay = 10`편까지입니다. 상한은 만들기와 되살리기(지운 일기를 살릴 때)에만 겁니다. 넘으면 422 `diary.day_full`입니다(D83 ②, S96).
* 날짜 기록(`all_tags`·`featured_tags`·`guide_question`·`ruleset_version`)은 그날 첫 편을 쓸 때 만들고 바꾸지 않습니다(S50). 둘째 편부터는 엔진을 부르지 않습니다.
* 행을 물리적으로 지우지 않습니다. 일기 삭제는 `deleted_at` soft delete이고 FK는 `ON DELETE RESTRICT`입니다(S6·S7).
* "오늘"은 프로필 `current_timezone` 기준이고 `clock.Clock`으로 셉니다(D30). 오늘 이후는 422 `diary.future_date`, D41 범위 밖은 422 `date.out_of_range`(field `date`).
* 없는 일기·남의 일기·지운 일기는 404 `diary.not_found`입니다. 내용을 비운(`content_purged_at`) 일기는 되살리기에서도 404입니다.
* 목록 순서는 `date DESC, created_at ASC, id ASC`, cursor는 `(date, createdAt, id)`의 불투명 문자열이고 해석할 수 없으면 400 `request.invalid`(field `cursor`)입니다(S98).
* ID는 UUIDv7, 시각 `timestamptz`, 날짜 `date`입니다.
* 로그에 일기 본문과 가이드 질문을 남기지 않습니다.
* 공개 저장소(D74): 커밋·PR·fixture에 가격·수익 수치와 비공개 경로 링크를 넣지 않습니다.
* 계약 PR(A)은 브랜치 `server/d83-diary-multi`, 구현 PR(B)은 PR A 병합 뒤 `git fetch origin && git switch -c server/d83-diary-impl --no-track origin/main && git push -u origin server/d83-diary-impl && git status -sb`로 만든 브랜치입니다.

## Review Focus

1. 두 기기가 같은 새 날짜에 동시에 첫 편을 만듦: 둘 다 201이고 날짜 기록은 하나, 일기는 두 편이어야 합니다(PK 충돌 500이 아님).
2. 그날 살아 있는 일기가 10편인데 그중 하나(이미 살아 있음)에 `restoreDiary`: 상한 검사 없이 200이어야 합니다(지운 일기를 살릴 때만 422).
3. 같은 날짜의 일기가 두 쪽에 걸쳐 나뉘고 `created_at`이 같은 행이 있음: 다음 쪽에 중복·빠짐이 없어야 합니다(`id`로 순서를 끝까지 정함).
4. draft.12 app이 보내던 날짜만 담은 cursor(`base64url("2026-10-12")`): 500이 아니라 400 `request.invalid`(field `cursor`)여야 합니다.
5. `DayExists`가 true를 돌려준 뒤 만들기 전에 날짜 기록이 지워짐(익명화·합치기): 기록을 다시 만들어 한 번 재시도해 201이어야 합니다.

---

## 결정 (plan이 정한 것)

| # | 결정 | 근거 |
| --- | --- | --- |
| P-1 | PR A는 옛 일기 핸들러 파일(`diary_handlers.go`·`diary_handlers_test.go`)을 지우고, 새 operation 6개는 `Unimplemented`의 501로 둡니다. PR B가 새 핸들러로 다시 만듭니다 | 생성된 strict interface가 바뀌어 옛 핸들러가 컴파일되지 않음. P3 계약 PR #163 선례 |
| P-2 | cursor 원문은 JSON `{"d":"YYYY-MM-DD","c":"<RFC 3339 nano>","i":"<uuid>"}`이고 base64url(패딩 없음)로 감쌉니다. 세 필드가 모두 있고 형식이 맞아야 합니다 | spec §4.3. `timestamptz`(마이크로초)를 잃지 않음 |
| P-3 | 날짜 기록이 지워져 다시 만드는 재시도는 Service에서 한 번만 합니다 | spec §3.2 |
| P-4 | migration 데이터 이관 테스트는 `dbtest.New` 뒤 `postgres.Migrate(ctx, pool, "down")`으로 00013만 내리고 옛 모양 행을 넣은 뒤 `"up"`으로 올립니다 | 별도 helper 없이 현재 도구로 됨 |
| P-5 | 일기 목록 cursor와 순서는 Store가 정하고, cursor 문자열 인코딩은 httpapi가 합니다(`diary.Cursor` 값을 주고받음) | 지금 날짜 cursor와 같은 나눔 |

---

## PR A: 계약 (draft.13)

### Task 1: REST 계약 draft.13과 생성 코드

**Files:**
- Modify: `server/api/openapi.yaml`(`info.version`, `/v1/diaries`, `/v1/diaries/{id}`, `/v1/diaries/{id}/restore`, 옛 `{date}` 경로 제거, `DiaryInput`·`DiaryBodyInput`·`Diary`·`DiarySummary`, problem code 표·`Conflict`·`UnprocessableEntity` 설명, `info.description`의 멱등 대상 목록)
- Modify: `server/api/contract_test.go`(`expectedOperationIDs`, `TestContract_CreatePostsAcceptIdempotencyKey`, `TestContract_VersionIsDraft12` → `TestContract_VersionIsDraft13`, `TestContract_Draft7Additions`의 `putDiary`·`restoreDiary` 문구)
- Regenerate: `server/internal/httpapi/gen/`(`go generate ./api/...`)
- Modify: `server/internal/httpapi/problem/codes.go`(`DiaryDayFull` 추가, `DiaryDateTaken` 제거, `AllCodes`)
- Modify: `server/internal/httpapi/errors.go:85`(`diary.ErrDateTaken` 매핑 줄 제거)
- Modify: `server/internal/httpapi/unimplemented.go`(일기 operation 6개)
- Delete: `server/internal/httpapi/diary_handlers.go`, `server/internal/httpapi/diary_handlers_test.go`
- Modify: `server/internal/httpapi/contract_routes_test.go`(`minimalRequests`, 일기 경로를 예로 쓰던 본문 검사 테스트들, access log route 테스트)
- Modify: `server/internal/cli/diary_schedule_flow_test.go`(일기 단계 제거, 일정 단계만 남김. PR B Task 7이 새 일기 흐름을 넣음)

**Interfaces:**
- Produces (계약): operation `listDiaries`·`createDiary`·`getDiary`·`updateDiary`·`deleteDiary`·`restoreDiary`(spec §4.1 표 그대로), 스키마 `DiaryInput{date, body}`·`DiaryBodyInput{body}`·`Diary{id, …}`·`DiarySummary{id, date, createdAt, excerpt, featuredTags}`.
- Produces (Go): `problem.DiaryDayFull = Code{"diary.day_full", http.StatusUnprocessableEntity}`. 생성 타입 `gen.CreateDiaryRequestObject`(`Body *gen.DiaryInput`, `Params.IdempotencyKey`), `gen.GetDiaryRequestObject{Id openapi_types.UUID}`, `gen.UpdateDiaryRequestObject{Id, Body *gen.DiaryBodyInput}`, `gen.DeleteDiaryRequestObject{Id}`, `gen.RestoreDiaryRequestObject{Id}`, `gen.CreateDiary201JSONResponse{Body gen.Diary, Headers gen.CreateDiary201ResponseHeaders{Location *string}}`(`createSchedule`과 같은 모양).

- [ ] **Step 1: 계약 테스트를 먼저 고침**

`api/contract_test.go`:
* `expectedOperationIDs`의 일기 줄을 `"listDiaries", "createDiary", "getDiary", "updateDiary", "deleteDiary", "restoreDiary"`로.
* `TestContract_CreatePostsAcceptIdempotencyKey`의 목록을 `{"createSchedule", "registerDevice", "createDiary"}`로.
* `TestContract_VersionIsDraft13`: `doc.Info.Version == "1.0.0-draft.13"`.
* `TestContract_Draft7Additions`에서 `putDiary` 항목을 지우고, `restoreDiary` 기대 문구를 `{"이미 살아 있는 일기", "404 `diary.not_found`", "422 `diary.day_full`"}`로.
* 새 `TestContract_Draft13DiaryEntries`:
  ```go
  // 경로와 메서드
  paths := map[string][]string{
      "/v1/diaries":              {"GET listDiaries", "POST createDiary"},
      "/v1/diaries/{id}":         {"GET getDiary", "PUT updateDiary", "DELETE deleteDiary"},
      "/v1/diaries/{id}/restore": {"POST restoreDiary"},
  }
  // doc.Paths.Find("/v1/diaries/{date}") == nil, Find("/v1/diaries/{date}/restore") == nil
  // {id} 매개변수 schema: type string, format uuid
  // Diary.required ⊇ {id, date, body, tags, rulesetVersion, createdAt, updatedAt}; Diary.properties.id.format == "uuid"
  // DiarySummary.required == {id, date, createdAt, excerpt, featuredTags}
  // DiaryInput.required == {date, body}; DiaryBodyInput.required == {body}; 두 body 모두 minLength 1, maxLength 10000
  // createDiary 응답에 201(Location 헤더)·409·422가 있고 200은 없음
  // updateDiary 응답에 502·504가 없음
  // listDiaries 설명에 "같은 날짜 안에서는 작성 순"과 "한 날짜의 일기가 두 쪽에 나뉠 수"가 있음
  ```
* 새 `TestContract_Draft13ProblemCodes`: 계약의 problem code 표에 `diary.day_full`(status 422)이 있고 `diary.date_taken`이 없음(`TestContract_ProblemCodesSurviveLoad`가 쓰는 표 읽기 helper를 씀).

- [ ] **Step 2: 실패를 확인**

Run: `cd server && go test ./api/`
Expected: FAIL (`createDiary operation이 없음`, `info.version = "1.0.0-draft.12"` 등)

- [ ] **Step 3: `openapi.yaml`을 spec §4대로 고침**

* `info.version: 1.0.0-draft.13`. `info.description`의 `Idempotency-Key` 대상 목록에 `createDiary`를 더함.
* `/v1/diaries`에 `post: createDiary`(parameters `$ref IdempotencyKey`, requestBody `DiaryInput`, 201 `Diary` + `Location` 헤더, 400·401·403·409·413·415·422·500·502·503·504·default). 설명: spec §4.1의 `createDiary` 줄(첫 편이면 날짜 기록을 만듦, 10편이면 422 `diary.day_full`, 미래 422 `diary.future_date`, 범위 밖 422 `date.out_of_range`, 프로필 없으면 409 `profile.required`).
* `listDiaries` 설명: "날짜 내림차순이고, 같은 날짜 안에서는 작성 순(`createdAt` 오름차순)입니다. `limit`은 일기 편수라 한 날짜의 일기가 두 쪽에 나뉠 수 있습니다. 날짜 하나의 일기는 `from`과 `to`에 같은 날짜를 넣어 받습니다." + 기존 `from` > `to` 문장.
* `/v1/diaries/{id}`(path parameter `id`, `type: string, format: uuid`, 일정과 같은 모양): `get: getDiary`, `put: updateDiary`(requestBody `DiaryBodyInput`, 200 `Diary`, 502·504 없음), `delete: deleteDiary`. 설명은 spec §4.1.
* `/v1/diaries/{id}/restore`: `post: restoreDiary`, 200 `Diary`, 404, 422. 설명: "지운 일기를 되살립니다. 이미 살아 있는 일기면 그대로 200입니다. 내용을 비운 일기와 없는 일기(남의 일기 포함)는 404 `diary.not_found`, 그 날짜에 살아 있는 일기가 이미 10편이면 422 `diary.day_full`입니다."
* `/v1/diaries/{date}`, `/v1/diaries/{date}/restore` 제거. `components/parameters/Date`를 다른 곳이 쓰지 않으면 제거.
* 스키마는 spec §4.2. `Diary` 설명에 "`tags`·`guideQuestion`·`rulesetVersion`은 그날 첫 편을 쓸 때 기록한 날짜 기록이고 같은 날 일기에 똑같이 붙습니다"를 더함.
* problem code 표: `diary.day_full`(422, "그 날짜에 살아 있는 일기가 이미 10편") 추가, `diary.date_taken` 제거. `Conflict` 응답 설명에서 `diary.date_taken` 제거, `UnprocessableEntity` 업무 규칙 목록에 `diary.day_full` 추가.

- [ ] **Step 4: 계약 테스트 통과 확인**

Run: `cd server && go test ./api/`
Expected: PASS

- [ ] **Step 5: 생성 코드와 컴파일 맞추기**

`go generate ./api/...` 뒤:
* `problem/codes.go`: `DiaryDayFull` 추가(`AllCodes`의 422 줄), `DiaryDateTaken` 제거.
* `errors.go`: `diary.ErrDateTaken` 매핑 줄 제거(`diary.ErrDateTaken` 변수는 PR B Task 4가 지움).
* `unimplemented.go`: 일기 operation 6개(`ListDiaries`·`CreateDiary`·`GetDiary`·`UpdateDiary`·`DeleteDiary`·`RestoreDiary`)가 `ErrNotImplemented`.
* `diary_handlers.go`·`diary_handlers_test.go` 삭제(P-1). `api.go`의 `Diaries DiaryService` 필드와 interface는 그대로 둡니다(serve 조립이 계속 컴파일되게).
* `contract_routes_test.go`: `minimalRequests`의 일기 항목을 `"listDiaries": {GET, "/v1/diaries"}`, `"createDiary": {POST, "/v1/diaries", json, `{"date":"2026-10-11","body":"오늘"}`}`, `"getDiary"`·`"deleteDiary"`·`"restoreDiary"`·`"updateDiary"`는 `/v1/diaries/0192a3b4-0000-7000-8000-000000000001`(PUT 본문 `{"body":"오늘"}`). 본문 검사 테스트들(필수 필드 누락 400, `text/plain` 415, 본문 크기 413, 잘린 JSON 400)이 쓰던 `PUT /v1/diaries/2026-10-11`을 `POST /v1/diaries`로 바꾸고 본문에 `date`를 넣음. access log route 테스트는 `GET /v1/diaries/{id}`를 기대.
* `cli/diary_schedule_flow_test.go`: 일기 요청 줄을 지우고 일정 흐름만 남김. 테스트 이름에서 "Diary"를 뺌.

- [ ] **Step 6: 계약 검사 전체**

Run: `cd server && go generate ./... && git status --porcelain && go test -race ./api/ ./seed/... ./legal/... ./internal/content/render/ ./internal/profile/honorific/ && go test -race -run 'TestRegisterAPI_|TestProblemCodes_|TestLegalPage_|TestAppCheck_' ./internal/httpapi/`
Expected: `git status --porcelain`은 이 task가 바꾼 파일만, 테스트 PASS

- [ ] **Step 7: Commit**

```bash
git add server/api server/internal/httpapi server/internal/cli/diary_schedule_flow_test.go
git commit -m "feat(server): 일기 하루 여러 편 계약 draft.13 (D83, #407)"
```

### Task 2: 결정·spec·계약 표와 app 알림, PR A

**Files:**
- Modify: `server/docs/decisions.md`(S95~S98 추가, S55·S63 행 끝에 "→ S98·S95로 대체")
- Modify: `server/docs/specs/2026-10-11-server-mvp-design.md`(§5.2 일기 행을 새 경로로, §11.2의 `diary.date_taken` 행 → `diary.day_full` 422, §3.3 일기 표 설명에 "D83으로 `diary_days`와 나뉨, `2026-10-22-diary-multi-design.md`")
- Modify: `docs/contracts/README.md`(REST 행 버전 `1.0.0-draft.13`, 변경 요약 덧붙임)
- Create: `server/docs/plans/2026-10-22-diary-multi.md`(이 문서, 이미 있음)

- [ ] **Step 1: 결정 S95~S98**

spec §9 표의 문장을 그대로 `decisions.md` 표 형식(`| S95 | 2026-10-22 | 데이터 | … | spec 2026-10-22-diary-multi §2·§5 |`)으로 넣습니다. 분류는 S95 데이터, S96 일기, S97 계약, S98 API.

- [ ] **Step 2: 계약 표 행**

REST 행의 버전 칸을 `1.0.0-draft.13`으로, 상태 칸 끝(draft.12 문장 뒤)에 덧붙임: "draft.13: 하위 호환이 깨지는 변경(D83, #407, S95~S98). 일기 id 경로 `createDiary`(`POST /v1/diaries`, `Idempotency-Key`)·`getDiary`·`updateDiary`(PUT 본문만)·`deleteDiary`·`restoreDiary`(`/v1/diaries/{id}`, 이미 살아 있으면 200), 날짜 경로와 `putDiary`·`diary.date_taken` 제거, `Diary.id`·`DiarySummary.id`·`createdAt`, 한 날짜 10편 상한 422 `diary.day_full`, 목록은 같은 날 작성 순이고 cursor는 (날짜, 작성 시각, id)(app 요청 #<Step 4 번호>)."

- [ ] **Step 3: 공개 저장소 확인과 commit**

Run: `git diff origin/main... | grep -nE '[0-9][0-9,]*원|₩|\$[0-9]|myungli-diary-internal'`
Expected: 출력 없음

```bash
git add server/docs docs/contracts/README.md
git commit -m "docs(server): 일기 하루 여러 편 결정 S95~S98, 계약 표 draft.13"
```

- [ ] **Step 4: app 요청 Issue와 PR**

app 앞 `kind:request` Issue(`--label from:server,to:app,kind:request --milestone S3`). 제목 "[server→app] REST draft.13: 일기 id 경로와 한 날짜 10편 (D83)". 본문은 spec §4의 차이 목록(새·없앤 operation, 스키마 필드, 순서·cursor, `diary.day_full`, `diary.date_taken` 제거), 지휘 요청 #408 참고, PR A 번호. 번호를 Step 2의 `<Step 4 번호>`에 채워 commit을 고칩니다(새 commit).

`git merge origin/main` → `git push -u origin server/d83-diary-multi` → `gh pr create`. 본문: 요약, 검사 결과, `참고 #407`. PR B가 `Closes #407`.

---

## PR B: 구현

PR A 병합 뒤 Global Constraints의 명령으로 `server/d83-diary-impl`을 만듭니다. Docker가 켜져 있어야 합니다(`docker info`).

### Task 3: migration 00013

**Files:**
- Create: `server/db/migrations/00013_diary_days.sql`
- Create: `server/internal/diary/migration_test.go`
- Modify: `server/internal/platform/postgres/migrate_test.go:27`(`wantSources`에 `"00013_diary_days.sql"`)

**Interfaces:**
- Produces: 표 `diary_days`(spec §2.1), `diaries`의 FK `diaries_day_fk`와 인덱스 `diaries_list`. `diaries`에 `all_tags`·`featured_tags`·`guide_question`·`ruleset_version` 열이 없음.

- [ ] **Step 1: 실패하는 이관 테스트**

`migration_test.go`(package `diary_test`):
```go
func TestMigration00013_SplitsDayRecords(t *testing.T)
// dbtest.New → postgres.Migrate(ctx, pool, "down")(00013만 내림)
// 옛 모양으로 넣음: 계정 A
//   10-12: 살아 있는 행(tags {"a"}, ruleset "r2", created 10-12T09:00) + 지운 행(tags {"old"}, ruleset "r1", created 10-12T08:00)
//   10-13: 지운 행만 둘(created 08:00 tags {"first"}, 09:00 tags {"second"})
// postgres.Migrate(ctx, pool, "up")
// diary_days: (A,10-12) all_tags {"a"}, ruleset "r2"  ← 살아 있는 행 우선
//             (A,10-13) all_tags {"first"}            ← 지운 행만 있으면 가장 먼저 만든 행
// diaries: 4행, 본문·deleted_at 그대로
func TestMigration00013_DownRestoresColumns(t *testing.T)
// up 상태에서 하루 1편 데이터를 넣고 down → diaries.all_tags 등이 diary_days 값으로 돌아옴
```

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test -race -run TestMigration00013 ./internal/diary/`
Expected: FAIL (`down` 뒤 표 모양이 그대로라 `diary_days` 없음 등)

- [ ] **Step 3: `00013_diary_days.sql` 작성**

spec §2.1~§2.3대로. Up 순서: `CREATE TABLE diary_days` → `INSERT INTO diary_days … SELECT DISTINCT ON (account_id, date) account_id, date, all_tags, featured_tags, guide_question, ruleset_version, created_at FROM diaries ORDER BY account_id, date, (deleted_at IS NOT NULL), created_at, id` → GIN 인덱스 → `ALTER TABLE diaries ADD CONSTRAINT diaries_day_fk FOREIGN KEY (account_id, date) REFERENCES diary_days (account_id, date) ON DELETE RESTRICT` → `DROP INDEX diaries_one_per_day, diaries_all_tags` → `CREATE INDEX diaries_list …` → 열 4개 DROP. Down은 역순(열 추가 → `UPDATE … FROM diary_days` → `SET NOT NULL`(`guide_question` 제외) → 옛 인덱스 둘 → FK·`diaries_list` 제거 → `DROP TABLE diary_days`). 파일 머리 주석에 표 설명(00006 주석 형식)과 "Down은 한 날짜에 살아 있는 일기가 하나일 때만 됩니다".

- [ ] **Step 4: 통과 확인**

Run: `cd server && go test -race -run 'TestMigration00013|TestMigrate_' ./internal/diary/ ./internal/platform/postgres/`
Expected: PASS (diary 패키지의 다른 테스트는 Task 4 전까지 컴파일되지 않을 수 있으니 `-run`으로 좁히되, 컴파일이 깨지면 Task 4와 함께 commit)

- [ ] **Step 5: Commit**

```bash
git add server/db/migrations/00013_diary_days.sql server/internal/diary/migration_test.go server/internal/platform/postgres/migrate_test.go
git commit -m "feat(server): 일기 날짜 기록 표 diary_days (migration 00013, D83)"
```

### Task 4: 쿼리와 Store

**Files:**
- Modify: `server/db/queries/diary.sql`(전부 새로)
- Regenerate: `server/internal/diary/diarydb/`(`go generate ./db/`)
- Modify: `server/internal/diary/store.go`
- Modify: `server/internal/diary/store_test.go`

**Interfaces:**
- Consumes: Task 3의 표.
- Produces:
  ```go
  const MaxEntriesPerDay = 10
  var ErrNotFound, ErrDayFull, ErrDayRecordMissing error // ErrDateTaken 제거
  type Entry struct { ID uuid.UUID; Date profile.LocalDate; Body string; AllTags []string; Featured []fortune.FeaturedTag; GuideQuestion []render.Segment; RulesetVersion string; CreatedAt, UpdatedAt time.Time }
  type Cursor struct { Date profile.LocalDate; CreatedAt time.Time; ID uuid.UUID }
  type ListQuery struct { From, To *profile.LocalDate; Tag *string; After *Cursor; Limit int }
  func (s *Store) DayExists(ctx context.Context, accountID uuid.UUID, date profile.LocalDate) (bool, error)
  func (s *Store) CreateEntry(ctx context.Context, accountID uuid.UUID, date profile.LocalDate, body string, record *fortune.DayRecord) (Entry, error)
  func (s *Store) Get(ctx context.Context, accountID, id uuid.UUID) (Entry, error)
  func (s *Store) UpdateBody(ctx context.Context, accountID, id uuid.UUID, body string) (Entry, error)
  func (s *Store) Delete(ctx context.Context, accountID, id uuid.UUID) error
  func (s *Store) Restore(ctx context.Context, accountID, id uuid.UUID) (Entry, error)
  func (s *Store) List(ctx context.Context, accountID uuid.UUID, q ListQuery) ([]Entry, error)
  ```
- sqlc 쿼리 이름: `DiaryDayExists :one`, `InsertDiaryDay :exec`(ON CONFLICT DO NOTHING), `LockDiaryDay :one`(FOR UPDATE, 기록 열 반환), `CountLiveDiaries :one`, `InsertDiary :one`, `GetDiary :one`(id, JOIN), `UpdateDiaryBody :one`(CTE로 UPDATE 뒤 JOIN한 행), `SoftDeleteDiary :execrows`, `GetDiaryState :one`(id·date·deleted_at·content_purged_at, account 조건), `UndeleteDiary :exec`, `ListDiaries :many`(JOIN, keyset `after_*` narg, `ORDER BY d.date DESC, d.created_at ASC, d.id ASC`).

- [ ] **Step 1: 실패하는 Store 테스트**

`store_test.go`를 새 API로 바꿉니다. 지금 `entry(d, body, tags...)` helper는 `record(tags...) *fortune.DayRecord`로 바꿉니다. 테스트(이름과 assertion):
```go
TestStore_CreateFirstEntryWritesDayRecord      // CreateEntry(…, record) → Entry.AllTags == record.AllTags, DayExists == true
TestStore_SecondEntryReusesDayRecord           // 첫 편 record{"a"} 뒤 둘째 편 record nil → 둘째 Entry.AllTags == {"a"}
TestStore_SecondRecordIsIgnored                // 둘째 편에 record{"b"}를 넘겨도 AllTags == {"a"} (ON CONFLICT DO NOTHING)
TestStore_CreateWithoutRecordWhenDayMissing    // record nil, 날짜 기록 없음 → ErrDayRecordMissing
TestStore_ConcurrentCreatesStopAtTen           // 같은 날짜로 goroutine 12개 CreateEntry(record) → 성공 10, ErrDayFull 2, CountLive == 10, diary_days 행 1
TestStore_DeletedEntriesDoNotCount             // 10편 중 1편 Delete → 11번째 CreateEntry 성공
TestStore_RestoreRespectsLimit                 // 지운 1편 + 살아 있는 10편 → Restore == ErrDayFull; 살아 있는 9편이면 성공
TestStore_RestoreLiveEntryIsNoop               // 살아 있는 10편 중 하나 Restore → 그대로 Entry, 오류 없음 (Review Focus 2)
TestStore_RestorePurgedIsNotFound              // content_purged_at 채운 지운 일기 → ErrNotFound
TestStore_OtherAccountIsNotFound               // 남의 id로 Get·UpdateBody·Delete·Restore → ErrNotFound
TestStore_UpdateBodyKeepsDayRecord             // UpdateBody 뒤 AllTags·RulesetVersion·CreatedAt 그대로, Body·UpdatedAt 바뀜
TestStore_ListOrder                            // 10-12에 3편, 10-13에 2편 → 10-13(작성 순) 다음 10-12(작성 순)
TestStore_ListCursorSplitsDay                  // Limit 2로 넘기며 After에 마지막 항목 Cursor → 5편이 중복·빠짐 없이
TestStore_ListCursorSameCreatedAt              // 같은 날짜 두 행의 created_at을 UPDATE로 같게 만든 뒤 Limit 1로 넘김 → id 순으로 둘 다 (Review Focus 3)
TestStore_ListTagFilter                        // record{"a"} 날짜의 일기만 Tag "a"로 나옴
TestStore_ListRange                            // From·To 포함 범위
```

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test -race ./internal/diary/`
Expected: FAIL (컴파일 오류: `CreateEntry` 없음 등)

- [ ] **Step 3: `diary.sql` 작성과 `go generate ./db/`**

keyset 조건(`ListDiaries`):
```sql
AND (sqlc.narg('after_date')::date IS NULL
     OR d.date < sqlc.narg('after_date')::date
     OR (d.date = sqlc.narg('after_date')::date
         AND (d.created_at, d.id) > (sqlc.narg('after_created_at')::timestamptz, sqlc.narg('after_id')::uuid)))
```
태그 필터는 `dd.all_tags @> ARRAY[sqlc.narg('tag')::text]`(JOIN한 `diary_days dd`). 파일 머리 주석의 규칙(살아 있는 행만 조회)은 유지합니다.

- [ ] **Step 4: `store.go` 구현**

* `CreateEntry`: `postgres.InTx` 안에서 spec §2.4 순서(record가 있으면 `InsertDiaryDay` → `LockDiaryDay`(없으면 `ErrDayRecordMissing`) → `CountLiveDiaries` ≥ `MaxEntriesPerDay`면 `ErrDayFull` → `InsertDiary`(UUIDv7)). 반환 Entry는 잠근 행의 기록과 넣은 행으로 만듭니다.
* `Restore`: `InTx` 안에서 `GetDiaryState`(없거나 `content_purged_at` 있으면 `ErrNotFound`) → 살아 있으면 `GetDiary`로 그대로 반환 → `LockDiaryDay` → `CountLiveDiaries` ≥ 10이면 `ErrDayFull` → `UndeleteDiary` → `GetDiary`.
* `Upsert`·`fromUpsertRow`·`ErrDateTaken`·`uniqueViolation`(쓰는 곳이 없어지면)을 지웁니다. `encodeJSON`은 `*fortune.DayRecord`를 받게 바꿉니다.
* 패키지 주석을 "일기(한 날짜 여러 편, D83)"로.

- [ ] **Step 5: 통과 확인**

Run: `cd server && go test -race ./internal/diary/`
Expected: Store·migration 테스트 PASS (`service_test.go`는 Task 5 전이라 컴파일이 깨지면 Task 5와 함께 commit)

- [ ] **Step 6: Commit**

```bash
git add server/db/queries/diary.sql server/internal/diary
git commit -m "feat(server): 일기 Store를 날짜 기록과 한 편으로 나눔, 10편 상한 (S95·S96)"
```

### Task 5: Service

**Files:**
- Modify: `server/internal/diary/service.go`
- Modify: `server/internal/diary/service_test.go`

**Interfaces:**
- Consumes: Task 4의 Store.
- Produces:
  ```go
  func (s *Service) Create(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (Entry, error)
  func (s *Service) Get(ctx context.Context, accountID, id uuid.UUID) (Entry, error)
  func (s *Service) UpdateBody(ctx context.Context, accountID, id uuid.UUID, body string) (Entry, error)
  func (s *Service) Delete(ctx context.Context, accountID, id uuid.UUID) error
  func (s *Service) Restore(ctx context.Context, accountID, id uuid.UUID) (Entry, error)
  func (s *Service) List(ctx context.Context, accountID uuid.UUID, q ListQuery) ([]Entry, error)
  ```
  `Put`·`createWithRecord` 제거. `ErrFutureDate`는 그대로.

- [ ] **Step 1: 실패하는 Service 테스트**

`Days` 대역은 호출 수를 셉니다(지금 `service_test.go`의 대역에 `calls int` 추가).
```go
TestService_CreateRejectsFutureDate        // 서울 2026-10-12 00:05(UTC 10-11 15:05)에 10-13 → ErrFutureDate, 10-12 → 성공 (지금 테스트 유지)
TestService_FirstEntryCallsEngineOnce      // 첫 편 Create → days.calls == 1
TestService_SecondEntrySkipsEngine         // 둘째 편 Create → days.calls 그대로 1
```
Review Focus 5(DayExists true → 사이에 지워짐)는 Service가 쓰는 store 의존을 interface `entryStore`(Task 4 Store의 `DayExists`·`CreateEntry`만)로 받아 대역으로 고정합니다:
```go
TestService_RetriesOnceWhenDayRecordVanishes // 대역 DayExists → true, CreateEntry 첫 호출(record nil) → ErrDayRecordMissing, 둘째 호출(record != nil) → 성공; days.calls == 1, CreateEntry 호출 2
TestService_RetryFailsTwiceReturnsError      // 대역 CreateEntry가 두 번 다 ErrDayRecordMissing → 그 오류
```

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test -race ./internal/diary/`
Expected: FAIL (`Create` 없음)

- [ ] **Step 3: `service.go` 구현**

`Service`가 `store`를 `entryStore` interface(`DayExists`, `CreateEntry`)와 `*Store`(나머지 위임)로 받도록 `NewService(store *Store, days Days, clk clock.Clock)`은 그대로 두고, 테스트용 생성자 `newServiceWith(entries entryStore, store *Store, days Days, clk clock.Clock)`를 `export_test.go`로 엽니다. `Create` 흐름은 spec §3.2.

- [ ] **Step 4: 통과 확인**

Run: `cd server && go test -race ./internal/diary/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/internal/diary
git commit -m "feat(server): 일기 Service Create, 둘째 편부터 엔진을 부르지 않음 (D83)"
```

### Task 6: 핸들러, 오류 매핑, 멱등 대상

**Files:**
- Create: `server/internal/httpapi/diary_handlers.go`
- Create: `server/internal/httpapi/diary_handlers_test.go`
- Modify: `server/internal/httpapi/api.go:123-131`(`DiaryService`)
- Modify: `server/internal/httpapi/errors.go`(`diary.ErrDayFull` → `problem.DiaryDayFull`, field `date`)
- Modify: `server/internal/httpapi/unimplemented.go`(일기 operation 6개 제거)
- Modify: `server/internal/cli/serve.go:492`(`Idempotency(…, "createSchedule", "createDiary")`)

**Interfaces:**
- Consumes: Task 5의 Service, Task 1의 생성 타입.
- Produces:
  ```go
  type DiaryService interface {
      Create(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (diary.Entry, error)
      Get(ctx context.Context, accountID, id uuid.UUID) (diary.Entry, error)
      UpdateBody(ctx context.Context, accountID, id uuid.UUID, body string) (diary.Entry, error)
      Delete(ctx context.Context, accountID, id uuid.UUID) error
      Restore(ctx context.Context, accountID, id uuid.UUID) (diary.Entry, error)
      List(ctx context.Context, accountID uuid.UUID, q diary.ListQuery) ([]diary.Entry, error)
  }
  func encodeDiaryCursor(c diary.Cursor) string
  func decodeDiaryCursor(s string) (diary.Cursor, error)
  ```
  `CreateDiary` 201의 `Location`은 `/v1/diaries/<id>`(일정의 `Location` 만드는 방식 그대로).

- [ ] **Step 1: 실패하는 핸들러 테스트**

PR A가 지운 판을 `del=$(git log --diff-filter=D -1 --format=%H -- server/internal/httpapi/diary_handlers.go) && git show "$del^:server/internal/httpapi/diary_handlers_test.go"`로 꺼내, 그 대역·helper를 새 interface로 옮겨 씁니다(`diary_handlers.go`도 같은 방법).
```go
TestCreateDiary_Returns201WithLocation        // Location == "/v1/diaries/"+entry.ID, 본문 id·date·tags
TestCreateDiary_DayFullIs422                  // 대역 ErrDayFull → 422 diary.day_full, field date
TestCreateDiary_FutureDateIs422               // 422 diary.future_date
TestCreateDiary_OutOfRangeIs422               // 422 date.out_of_range, field date
TestCreateDiary_WithoutProfileIs409           // 409 profile.required
TestCreateDiary_IdempotentReplay              // 같은 Idempotency-Key 두 번 → 같은 상태·Location·본문, 대역 Create 호출 1 (register 경로로 serve.go와 같은 Idempotency 조립)
TestUpdateDiary_ReturnsDiary                  // 200, 본문 바뀜
TestGetDiary_NotFoundIs404                    // 404 diary.not_found
TestDeleteDiary_Returns204
TestRestoreDiary_DayFullIs422
TestListDiaries_CursorRoundTrip               // 대역이 Limit+1개 → nextCursor를 decode하면 마지막 항목의 Date·CreatedAt·ID
TestListDiaries_OldDateCursorIs400            // cursor = base64url("2026-10-12") → 400 request.invalid field cursor (Review Focus 4)
TestListDiaries_BadCursorIs400                // "!!!", base64url("{}"), base64url(`{"d":"2026-02-30","c":"…","i":"…"}`) → 400
TestListDiaries_SummaryHasIDAndCreatedAt
TestListDiaries_FromAfterToIsEmpty            // 지금 테스트 유지
```

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test -race ./internal/httpapi/`
Expected: FAIL (`CreateDiary`가 Unimplemented라 501 등)

- [ ] **Step 3: 구현**

* `diary_handlers.go`: 지운 판의 helper(`diaryAccountID`, `localDateOf`, `toDiary`, `toDiarySummary`, `featuredTags`, `excerpt`, `nonNil`, `contractDate`, `dateString`)를 되살리고 `toDiary`에 `Id`, `toDiarySummary`에 `Id`·`CreatedAt`를 더합니다. 핸들러 6개는 spec §4.1. `ListDiaries`의 쪽 나눔(Limit+1)은 지금 방식 그대로이고, `nextCursor`는 마지막 항목의 `diary.Cursor{Date, CreatedAt, ID}`입니다.
* cursor 인코딩은 P-2. `decodeDiaryCursor`는 base64url → JSON(`d`·`c`·`i` 모두 있어야 함) → `time.Parse(time.DateOnly, d)`·`time.Parse(time.RFC3339Nano, c)`·`uuid.Parse(i)` 중 하나라도 실패하면 오류.
* `CreateDiary`·`UpdateDiary`의 오류는 지금 `PutDiary`처럼 `outOfRangeError(err, fieldDiaryDate)`로 감쌉니다.
* `errors.go` 표에 `{target: diary.ErrDayFull, code: problem.DiaryDayFull, title: "Diary day full", field: "date"}`.
* `serve.go` 멱등 대상에 `"createDiary"`.

- [ ] **Step 4: 통과 확인**

Run: `cd server && go test -race ./internal/httpapi/ ./internal/cli/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/internal/httpapi server/internal/cli/serve.go
git commit -m "feat(server): 일기 id 경로 핸들러와 createDiary 멱등 (S97·S98)"
```

### Task 7: 조립 흐름 테스트, 현재 상태, PR B

**Files:**
- Modify: `server/internal/cli/diary_schedule_flow_test.go`
- Modify: `server/CLAUDE.md`(범위의 일기 줄, 현재 상태, 다음 할 일)

- [ ] **Step 1: 흐름 테스트에 일기 단계**

`TestDiaryScheduleFlow`(PR A가 남긴 일정 흐름 앞)에: `POST /v1/diaries`(10-12) 두 번 → 201 둘, id 다름 → `GET /v1/diaries?from=2026-10-12&to=2026-10-12` 2편, 작성 순 → `PUT /v1/diaries/{id1}` 본문 변경 200 → `DELETE /v1/diaries/{id1}` 204 → `GET /v1/diaries/{id1}` 404 `diary.not_found` → `POST /v1/diaries/{id1}/restore` 200 → 목록 2편. 테스트 이름에 "Diary"를 되살립니다.

- [ ] **Step 2: 통과 확인**

Run: `cd server && go test -race ./internal/cli/`
Expected: PASS

- [ ] **Step 3: `server/CLAUDE.md`**

* 범위의 일기 줄: "**하루 1편**(날짜 유일)" → "한 날짜에 살아 있는 일기 10편까지(D83), 날짜 기록(태그·`ruleset_version`·가이드 질문)은 그날 첫 편 때 한 번".
* 현재 상태에 한 줄: "D83(#407): 일기를 날짜 기록 `diary_days`와 한 편으로 나눔(migration 00013), id 경로 API(draft.13), 10편 상한 422 `diary.day_full`, `createDiary` 멱등. 결정 S95~S98."
* 다음 할 일: P8 항목에 "익명화는 `diaries.body`와 함께 `diary_days.guide_question`도 비움(spec 2026-10-22 §3.3)"; D82 #386을 맨 앞(S3 앞)에 두고 "합치기의 일기 규칙은 S95·D83 ④".

- [ ] **Step 4: commit 전 검사**

Run: `cd server && go vet ./... && golangci-lint run ./... && go test -race ./...`
Expected: 오류 없음, PASS

- [ ] **Step 5: Commit, 공개 저장소 확인, PR**

```bash
git add server/internal/cli/diary_schedule_flow_test.go server/CLAUDE.md
git commit -m "test(server): 일기 여러 편 조립 흐름, 현재 상태 갱신 (D83)"
```
`git diff origin/main... | grep -nE '[0-9][0-9,]*원|₩|\$[0-9]|myungli-diary-internal'` 출력 없음 확인 → `git merge origin/main` → `git push -u origin server/d83-diary-impl` → `gh pr create`(본문 `Closes #407`, 검사 결과).
