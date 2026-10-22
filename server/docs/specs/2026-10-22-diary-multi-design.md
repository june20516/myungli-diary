# 일기 하루 여러 편 (D83) — spec

* 날짜: 2026-10-22
* 요청: Issue #407 (root→server, accepted), 상한 개정 #422(PR #423으로 D83 ②·④ 개정)
* 기준: D83(D49 개정), D82 ⑥, D59 ④, server spec §5(REST)·§7(일기), S50~S58·S60
* 결정 번호: S95~S98

## 1. 목표

일기를 하루에 여러 편 쓸 수 있게 저장 구조와 REST 계약을 바꿉니다. S3 REST v1 freeze 전에 계약에 들어가야 합니다(freeze 뒤에는 하위 호환을 깨는 변경이 됨).

* 날짜에 붙는 기록(태그·대표 태그·가이드 질문·`ruleset_version`)은 날짜 하나에 하나이고, 같은 날 일기들이 함께 씁니다(D83 ①).
* 일기 한 편은 본문과 작성·수정 시각을 가집니다. 미래 날짜는 쓸 수 없습니다(D49 유지).
* 같은 날 일기는 작성 순으로 보입니다. 한 날짜에 살아 있는 일기는 10편까지입니다(D83 ②).
* 지금 저장된 일기는 그날의 첫 편이 됩니다(D83 ⑤).
* 계정 합치기(D82, #386)가 이 모델 위에서 설계될 수 있게 합칠 때의 날짜 기록 규칙을 정해 둡니다. 합치기 구현은 범위 밖입니다.

## 2. 저장 구조 (migration `00013_diary_days.sql`)

### 2.1. 표

**`diary_days` (새 표, 날짜 기록)**

| 열 | 타입 | 비고 |
| --- | --- | --- |
| `account_id` | uuid NOT NULL | `accounts(id)` FK, ON DELETE RESTRICT |
| `date` | date NOT NULL | |
| `all_tags` | text[] NOT NULL | 지금 `diaries.all_tags`와 같은 값(S51) |
| `featured_tags` | jsonb NOT NULL | `[{"key","polarity"}]`(S51) |
| `guide_question` | jsonb | `[{"text","term"}]`, 질문이 없으면 NULL(S52) |
| `ruleset_version` | text NOT NULL | |
| `created_at` | timestamptz NOT NULL DEFAULT now() | |

* PK `(account_id, date)`. 태그 필터용 `CREATE INDEX diary_days_all_tags ON diary_days USING gin (all_tags)`.
* 그날 첫 편을 쓸 때 만들고 이후 바꾸지 않습니다(S50). `updated_at`이 없는 까닭입니다.
* 그날 일기를 모두 지워도 행은 남습니다. 다시 쓰거나 되살릴 때 같은 기록을 씁니다. 행을 지우는 일은 계정 익명화(P8)와 합치기(D82)만 합니다.

**`diaries` (일기 한 편)**

| 열 | 비고 |
| --- | --- |
| `id`, `account_id`, `date`, `body`, `created_at`, `updated_at`, `deleted_at`, `content_purged_at` | 지금 열 그대로 |
| ~~`all_tags`, `featured_tags`, `guide_question`, `ruleset_version`~~ | `diary_days`로 옮기고 지움 |

* `(account_id, date)` → `diary_days(account_id, date)` FK, ON DELETE RESTRICT.
* `diaries_one_per_day`(살아 있는 행의 날짜 유일)와 `diaries_all_tags`를 지웁니다.
* 목록용 인덱스 `diaries_list ON diaries (account_id, date DESC, created_at, id) WHERE deleted_at IS NULL`(S63 대체).
* `diaries_set_updated_at` 트리거는 그대로입니다.

### 2.2. 이관 (Up)

1. `diary_days`를 만듭니다.
2. (계정, 날짜)마다 행 하나를 넣습니다. 그 날짜에 살아 있는 행이 있으면 그 행의 기록을, 없으면 가장 먼저 만든 행(`created_at`, `id` 순)의 기록을 씁니다(`DISTINCT ON (account_id, date) … ORDER BY account_id, date, (deleted_at IS NOT NULL), created_at, id`). `created_at`은 고른 행의 `created_at`입니다.
3. FK와 목록 인덱스를 걸고, `diaries_one_per_day`·`diaries_all_tags`와 옮긴 네 열을 지웁니다.

지운 일기는 지운 상태로 남고, 이제 id로 하나씩 되살릴 수 있습니다.

### 2.3. 되돌리기 (Down)

네 열을 다시 만들어 `diary_days`에서 채우고, `diaries_one_per_day`·`diaries_all_tags`를 다시 만든 뒤 `diary_days`를 지웁니다. 한 날짜에 살아 있는 일기가 둘 이상이면 유일 인덱스를 만들지 못해 실패합니다. 하루 1편 데이터에서만 되돌릴 수 있다는 점을 migration 주석에 적습니다.

### 2.4. 10편 상한과 동시 요청 (S96)

* 세는 대상은 그 날짜의 살아 있는(`deleted_at IS NULL`) 일기입니다.
* 상한은 만들기와 되살리기에만 겁니다. 고치기·지우기와 계정 합치기에는 걸지 않습니다(D83 ④: 합친 결과 10편을 넘어도 막지 않고, 그날은 더 쓸 수 없음).
* 상수는 `diary.MaxEntriesPerDay = 10` 하나로 둡니다.
* 만들기 트랜잭션:
  1. `INSERT INTO diary_days … ON CONFLICT (account_id, date) DO NOTHING`
  2. `SELECT … FROM diary_days WHERE account_id = $1 AND date = $2 FOR UPDATE` (날짜 기록을 읽으면서 그 날짜를 잠금)
  3. 살아 있는 편수를 셈. `>= MaxEntriesPerDay`면 롤백하고 `ErrDayFull`
  4. `INSERT INTO diaries …`
* 되살리기 트랜잭션: 대상 행을 찾고(없거나 내용을 비웠으면 `ErrNotFound`), 이미 살아 있으면 그대로 돌려줍니다. 아니면 그 날짜의 `diary_days` 행을 `FOR UPDATE`로 잠그고 편수를 센 뒤 `deleted_at = NULL`.
* 같은 날짜로 동시에 오는 만들기·되살리기는 2번의 행 잠금으로 줄을 서므로 상한이 정확합니다. 다른 날짜끼리는 서로 막지 않습니다.

## 3. 도메인 코드 (`internal/diary`)

### 3.1. Store

| 메서드 | 동작 |
| --- | --- |
| `DayExists(ctx, accountID, date) (bool, error)` | 날짜 기록이 있는지. Service가 엔진 호출을 건너뛸지 정할 때 씀 |
| `CreateEntry(ctx, accountID, date, body, record *DayRecord) (Entry, error)` | §2.4 만들기 트랜잭션. `record`가 nil이면 1번을 건너뛰고, 2번에서 행이 없으면(그 사이 익명화·합치기가 날짜 기록을 지움) `ErrDayRecordMissing` |
| `Get(ctx, accountID, id) (Entry, error)` | 살아 있는 일기와 그날 기록을 JOIN해 돌려줌. 없으면 `ErrNotFound` |
| `UpdateBody(ctx, accountID, id, body) (Entry, error)` | 살아 있는 일기의 본문만 바꿈 |
| `Delete(ctx, accountID, id) error` | soft delete. 없거나 이미 지웠으면 `ErrNotFound` |
| `Restore(ctx, accountID, id) (Entry, error)` | §2.4 되살리기 트랜잭션 |
| `List(ctx, accountID, ListQuery) ([]Entry, error)` | §4.3 순서와 keyset |

`Entry`에 `ID uuid.UUID`가 더해지고, 태그·질문·`RulesetVersion`은 JOIN한 날짜 기록에서 채웁니다. `ListQuery`의 keyset은 `Before *profile.LocalDate`에서 `After *Cursor{Date, CreatedAt, ID}`로 바뀝니다.

### 3.2. Service

* `Create(ctx, accountID, profile, date, body) (Entry, error)`: 미래 날짜면 `ErrFutureDate`(프로필 시간대 기준 오늘, 지금 규칙). `DayExists`가 false일 때만 `Days.DayRecord`로 엔진을 불러 기록을 만들고(트랜잭션 밖, 지금과 같음), `CreateEntry`에 넘깁니다. 둘째 편부터는 엔진을 부르지 않습니다.
  * `DayExists`가 false였는데 그 사이 다른 요청이 날짜 기록을 먼저 넣었으면, 1번의 `ON CONFLICT DO NOTHING`이 먼저 넣은 기록을 남기고 2번이 그것을 읽습니다. 같은 날짜의 기록은 하나로 모입니다.
  * `DayExists`가 true였으면 `record`를 nil로 넘깁니다. 그 사이 날짜 기록이 지워져 `ErrDayRecordMissing`이 오면 기록을 만들어 한 번만 다시 부릅니다(두 번째도 실패하면 그 오류를 그대로 돌려줌).
* `Get`·`UpdateBody`·`Delete`·`Restore`·`List`는 Store로 넘깁니다.
* 새 오류: `ErrDayFull`. 그대로: `ErrNotFound`, `ErrFutureDate`.
* `Put`(upsert)과 `createWithRecord`는 없앱니다.

### 3.3. 익명화(P8) 메모

`diary_days.guide_question`은 호칭이 들어간 렌더 원문이라 개인 정보입니다. P8 익명화는 `diaries.body`와 함께 `diary_days.guide_question`도 비워야 합니다. 이 spec에서는 구현하지 않고 `server/CLAUDE.md` 다음 할 일의 P8 항목에 적습니다.

## 4. REST 계약 (draft.13, 하위 호환이 깨지는 변경, S97)

### 4.1. Operation

경로 매개변수는 일정과 같은 `{id}`(`type: string, format: uuid`)입니다. 없는 일기와 남의 일기는 같은 404 `diary.not_found`입니다.

| operation | 경로 | 요청 | 응답 |
| --- | --- | --- | --- |
| `listDiaries` | `GET /v1/diaries` | query `from`·`to`·`tag`·`cursor`·`limit`(그대로) | 200 `DiaryList` |
| `createDiary` | `POST /v1/diaries` | `DiaryInput {date, body}`, header `Idempotency-Key`(선택) | 201 `Diary`, `Location: /v1/diaries/{id}` |
| `getDiary` | `GET /v1/diaries/{id}` | | 200 `Diary` |
| `updateDiary` | `PUT /v1/diaries/{id}` | `DiaryBodyInput {body}` | 200 `Diary` |
| `deleteDiary` | `DELETE /v1/diaries/{id}` | | 204 |
| `restoreDiary` | `POST /v1/diaries/{id}/restore` | | 200 `Diary` |

* `createDiary`: 그날 첫 편이면 날짜 기록을 함께 만듭니다. 같은 `Idempotency-Key`로 다시 보내면 24시간 동안 같은 응답입니다(S60, 대상에 `createDiary` 추가). 오류는 422 `diary.future_date`·`date.out_of_range`·`diary.day_full`, 409 `profile.required`(그대로), 엔진 오류 502·503·504(지금 `putDiary`와 같음).
* `updateDiary`: 본문만 바꾸고 날짜 기록은 그대로입니다(S50). 고칠 수 있는 것이 본문 하나라 전체 교체(PUT)로 두어 멱등입니다. 엔진을 부르지 않으므로 502·504가 없습니다. 지운 일기는 404.
* `deleteDiary`: 지운 일기는 `restoreDiary`로 되살릴 수 있습니다. 이미 지운 일기는 404.
* `restoreDiary`: 이미 살아 있으면 그대로 200(`restoreSchedule`과 같음). 내용을 비운 일기(`content_purged_at`)는 404. 그날 살아 있는 일기가 이미 10편이면 422 `diary.day_full`.
* 날짜별 목록은 `listDiaries?from=<d>&to=<d>`로 받습니다. 새 경로를 두지 않습니다.

### 4.2. 스키마

* `DiaryInput`: `required: [date, body]`. `date`(format date), `body`(minLength 1, maxLength 10000, 지금과 같음).
* `DiaryBodyInput`(새): `required: [body]`, `body`는 위와 같음.
* `Diary`: `id`(format uuid)를 더해 `required: [id, date, body, tags, rulesetVersion, createdAt, updatedAt]`. 설명에 "`tags`·`guideQuestion`·`rulesetVersion`은 그날 첫 편을 쓸 때 기록한 날짜 기록이고 같은 날 일기에 똑같이 붙습니다"를 적습니다.
* `DiarySummary`: `id`, `createdAt`을 더해 `required: [id, date, createdAt, excerpt, featuredTags]`.
* `DiaryList`: 그대로.

### 4.3. 목록 순서와 cursor (S98, S55 대체)

* 순서: `date DESC, created_at ASC, id ASC`. 날짜는 최근부터, 같은 날짜 안에서는 작성 순입니다(D83 ②, IA `diary-list`).
* cursor: 마지막 항목의 `(date, createdAt, id)`를 JSON으로 만들어 base64url(패딩 없음)로 감싼 불투명 문자열입니다. keyset 조건은 `date < c.date OR (date = c.date AND (created_at, id) > (c.created_at, c.id))`입니다. 해석할 수 없으면 400 `request.invalid`(field `cursor`, 지금과 같음).
* `limit`은 일기 편수 기준입니다(기본 30, 최대 100). 한 날짜의 일기가 두 쪽에 나뉠 수 있고, app은 날짜로 묶어 그립니다. 계약 설명에 적습니다.
* `tag` 필터는 `diary_days.all_tags @> ARRAY[tag]`를 JOIN으로 겁니다(GIN 사용).

### 4.4. Problem code

* 새 `diary.day_full` (422): "그 날짜에 살아 있는 일기가 이미 10편". writing 오류 문구 요청에 쓰도록 #407에 코드 이름을 남깁니다(지휘 #422 코멘트).
* 없앰 `diary.date_taken` (409): id로 되살리면 날짜가 겹칠 일이 없습니다.
* 그대로 `diary.not_found`, `diary.future_date`.

### 4.5. 없애는 것

`PUT/GET/DELETE /v1/diaries/{date}`(`putDiary`·옛 `getDiary`·옛 `deleteDiary`), `POST /v1/diaries/{date}/restore`(옛 `restoreDiary`), problem `diary.date_taken`. freeze 전이므로 `/v2`를 열지 않고 v1을 고칩니다(S93은 freeze 뒤 규칙). app에는 §6대로 알립니다.

## 5. 계정 합치기 때의 규칙 (S95, 구현은 D82)

D82 spec이 따를 규칙만 정합니다.

* 겹치는 날짜(두 계정 모두 `diary_days` 행이 있음): 남는 계정의 날짜 기록을 쓰고, 옮겨 온 일기도 그 기록을 함께 씁니다. 떠나는 계정의 그 날짜 기록은 지웁니다. 남는 사주가 사용자가 고른 사주라 태그 뜻이 그 사주와 맞습니다. 옮겨 온 일기는 쓸 때 본 가이드 질문을 잃습니다(사용자 결정, 2026-10-22).
* 겹치지 않는 날짜: 떠나는 계정의 날짜 기록을 남는 계정으로 그대로 옮깁니다.
* 10편 상한을 걸지 않습니다(D83 ④).
* 합치기 전 요약의 "옮겨질 일기 수"와 "같은 날 일기가 겹치는 날 수"는 각각 떠나는 계정의 살아 있는 일기 수, 두 계정 모두 살아 있는 일기가 있는 날짜 수입니다(#407 ④, #386 정정 코멘트).

## 6. 계약 변경 알림

* app 앞으로 `kind:request` Issue를 엽니다(`from:server,to:app`, 마일스톤 S3). 본문은 §4의 차이(새·없앤 operation, 스키마 필드, cursor·순서, `diary.day_full`, `diary.date_taken` 제거)이고, 지휘의 app 요청 #408을 참고로 겁니다.
* `docs/contracts/README.md`의 REST 행을 `1.0.0-draft.13`으로 고치고 변경 요약을 덧붙입니다.

## 7. PR 나누기

1. **계약 PR** (이 브랜치 `server/d83-diary-multi`)
   * 내용: 이 spec과 계획, `openapi.yaml` draft.13, `go generate ./api/...` 생성 코드, `problem/codes.go`(`DiaryDayFull` 추가, `DiaryDateTaken` 제거), 계약 표 server 행, 결정 S95~S98.
   * 옛 일기 핸들러는 지우고, 새 operation 6개는 `Unimplemented`가 501로 답합니다(P3 계약 PR #163 선례). main은 아직 배포 전이라(P9) 사이 기간의 501은 문제가 되지 않습니다.
   * app에 §6의 Issue를 엽니다. 본문에는 `참고 #407`.
2. **구현 PR** (계약 PR 병합 뒤 `origin/main`에서 딴 `server/d83-diary-impl`)
   * 내용: migration `00013`, sqlc 쿼리와 생성 코드, Store·Service, 핸들러와 멱등 대상 추가, 테스트, `server/CLAUDE.md` 현재 상태·다음 할 일.
   * 본문에 `Closes #407`.

## 8. 테스트

| 층 | 확인할 것 |
| --- | --- |
| migration (testcontainers) | 00012까지 올린 DB에 살아 있는 행·지운 행·지운 행만 있는 날짜를 넣고 00013을 올리면, 날짜 기록이 규칙(§2.2)대로 하나씩 생기고 일기 행 수·본문·`deleted_at`이 그대로인지. Down 뒤 원래 열 값이 돌아오는지(하루 1편 데이터) |
| Store | 같은 날짜로 동시에 12편 만들면 정확히 10편 성공, 2편 `ErrDayFull`. 10편인 날의 되살리기는 `ErrDayFull`, 9편이면 성공. 이미 살아 있는 일기 되살리기는 그대로. 내용을 비운 일기 되살리기는 `ErrNotFound`. 둘째 편이 첫 편의 날짜 기록을 그대로 씀. 날짜 기록이 동시에 두 번 들어와도 하나. 목록 순서(날짜 내림차순, 같은 날 작성 순), cursor 경계(같은 날짜 안에서 쪽이 나뉨), 태그 필터, 남의 일기 404 |
| Service | 미래 날짜 `ErrFutureDate`, 날짜 기록이 있으면 `Days.DayRecord`를 부르지 않음(대역 호출 수 0) |
| httpapi | 계약 경로 테스트(`contract_routes_test`)의 일기 경로 갱신, 오류 매핑(`diary.day_full` 422, `diary.not_found` 404), `createDiary`의 `Location`과 멱등 재생, `TestProblemCodes_` |
| cli 흐름 | `diary_schedule_flow_test`를 새 경로로: 만들기 2편 → 날짜 목록 → 고치기 → 지우기 → 되살리기 |

## 9. 결정

| 번호 | 내용 |
| --- | --- |
| S95 | 일기 저장을 날짜 기록(`diary_days`, 처음 쓸 때 만들고 바꾸지 않음, 일기를 다 지워도 남음)과 일기 한 편(`diaries`)으로 나눕니다. 계정 합치기 때 겹치는 날짜는 남는 계정의 날짜 기록을 쓰고 옮겨 온 일기도 그것을 씁니다(§5) |
| S96 | 한 날짜의 살아 있는 일기 10편 상한(D83 ②)은 만들기·되살리기에만 걸고, 날짜 기록 행 `FOR UPDATE` 잠금으로 동시 요청을 줄 세웁니다. 넘으면 422 `diary.day_full`. 합치기에는 걸지 않습니다 |
| S97 | 일기 API는 id 경로(`/v1/diaries/{id}`)입니다. 만들기는 `POST /v1/diaries`(`Idempotency-Key` 대상), 고치기는 본문 전체 교체 `PUT`, 되살리기는 이미 살아 있으면 200. 날짜 경로와 `diary.date_taken`을 없앱니다(freeze 전 변경) |
| S98 | 일기 목록은 `date DESC, created_at ASC, id ASC`이고 cursor는 `(date, createdAt, id)` JSON의 base64url입니다(S55 대체). `limit`은 편수 기준이라 한 날짜가 두 쪽에 나뉠 수 있습니다 |
