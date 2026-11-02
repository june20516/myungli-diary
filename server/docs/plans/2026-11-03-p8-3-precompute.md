# P8-3 job precompute Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 30분마다 도는 `server job precompute`가 현지 22:00~22:29인 최근 활동 사용자의 다음 날 데일리(다음 날이 1일이면 다음 달 캘린더도)를 엔진에서 계산해 결과 캐시에 채웁니다.

**Architecture:** 대상 후보는 `profile.ListActiveProfiles`가 DB에서 계정 id 순으로 페이지를 나눠 읽고, 새 패키지 `internal/precompute`가 Go 시각 계산(내장 tzdata, S31)으로 현지 22:00~22:29인 사람만 골라 `fortune.Service`의 `Daily`·`Month`를 동시 8개로 부릅니다. 캐시 쓰기는 `fortune.Service`가 이미 합니다(캐시가 있으면 엔진을 부르지 않음). CLI `job precompute`가 DB, 엔진 client, `engine.Versions`를 조립하고, Terraform이 Job과 Scheduler(UTC 매시 0분, 30분)를 만들며, 배포 workflow가 이미지와 설정을 붙이고 Scheduler를 켭니다.

**Tech Stack:** Go, pgx/v5, sqlc, `golang.org/x/sync/errgroup`, testcontainers(dbtest), Terraform(google provider), GitHub Actions

**Spec:** `server/docs/specs/2026-10-11-server-mvp-design.md` §8.1 (P8 나누기: `server/docs/plans/2026-10-28-p8-1-devices.md` "P8 전체 나누기")

## 확인한 사실 (2026-11-03, `origin/main` 코드)

| 사실 | 출처 |
| --- | --- |
| `job precompute` 이름은 등록돼 있고 `ErrNotImplemented`를 돌려줌 | `internal/cli/cli.go:192-202` |
| `TestRun_NotImplementedJob_Exits1`은 `notify`로 검사함(precompute를 채워도 안 깨짐) | `internal/cli/cli_test.go:65` |
| 대상 판정에 쓰는 열: `accounts.status`(`active`·`deleted`), `accounts.last_active_at`(NOT NULL), `profiles.current_timezone`(NOT NULL). 프로필이 있으면 출생 정보는 모두 있음(`profiles_complete`) | migration 00002, 00004, 00015 |
| `fortune.Service.Daily(ctx, birth, date, currentTimezone)`와 `Month(ctx, birth, year, month, currentTimezone)`는 캐시를 먼저 읽고, 없으면 엔진을 불러 캐시에 씀 | `internal/fortune/service.go:71-147` |
| `fortune.Service`는 `engine.Versions`가 채워져 있어야 동작함(비면 `ErrUnavailable`) | `internal/fortune/service.go:149`, `internal/engine/versions.go:35` |
| 프로필 행 변환 `profileFromRow`는 비공개 함수 | `internal/profile/service.go:267` |
| retention Job 패턴: `jobs.tf`의 `server_jobs` map, Scheduler는 `paused = true`로 만들고 배포 workflow가 `gcloud run jobs update` 뒤 `resume` | `deploy/terraform/env/jobs.tf`, `scheduler.tf`, `.github/workflows/deploy-server-env.yml:149-155` |
| 엔진 테스트 대역 `enginetest.Fake`(`Daily`, `MonthCalendar`, `Info` 함수 필드) | `internal/engine/enginetest/fake.go` |

## Global Constraints

* 대상: 실행 시각 기준 현지 시각이 22:00 이상 22:30 미만이고, `last_active_at`이 실행 시각에서 14일(336시간) 안이며, 계정 `status = 'active'`이고 프로필이 있는 사용자(spec §8.1).
* 계산할 것: 현지 날짜의 다음 날 데일리. 다음 날이 1일이면 그 다음 날의 연·월 캘린더도(spec §8.1).
* 엔진 동시 호출은 8개까지(spec §8.1).
* 실패한 사용자는 건너뜁니다. 요청 시점 계산이 대신하므로 사용자에게 보이지 않습니다(spec §8.1).
* 시간대 계산은 Go `time.LoadLocation`(내장 tzdata, S31)으로 합니다. DB의 `AT TIME ZONE`은 쓰지 않습니다(DB tz 자료와 server가 다를 수 있고, 이름 하나가 틀리면 쿼리 전체가 실패함).
* 실행 시각(`now`)은 Job 시작 때 한 번 읽어 모든 판정에 씁니다.
* Job 실패(종료 코드 1)는 DB 조회 실패, 엔진 버전 조회 실패, 그리고 대상이 1명 이상인데 모두 실패했을 때만입니다(엔진 장애를 경보로 받기 위해). 일부 실패는 성공으로 끝내고 수를 로그에 남깁니다(S128).
* 로그에 출생 정보와 계정 id를 남기지 않습니다. 수(대상, 성공, 실패, 건너뜀)만 남깁니다.
* Scheduler: `0,30 * * * *`, `time_zone = "Etc/UTC"`. 30분 단위가 아닌 시간대(예: +05:45)도 한 번은 창에 듭니다.

## Review Focus

1. 시간대 이름이 Go에서 안 읽히는 프로필 하나가 있어도 나머지 대상은 계산되고, 그 프로필은 실패 1로 셉니다.
2. DST 전환일(예: `America/New_York` 3월 둘째 일요일)에도 현지 시각 판정이 Go 계산 그대로 맞고, 다음 날 날짜가 하루 뒤입니다(시각 더하기가 아니라 날짜 더하기).
3. 12월 31일 현지 22시 대상은 다음 날 1월 1일 데일리와 다음 해 1월 캘린더를 계산합니다.
4. 대상이 페이지 크기보다 많아도(예: 페이지 2, 대상 5) 모두 한 번씩만 계산합니다.
5. 엔진이 모든 호출에 실패하면 Job이 실패로 끝나고, 대상이 0명이면 성공입니다.

---

### Task 1: 활동 사용자 프로필 페이지 조회

**Files:**
- Modify: `server/db/queries/profile.sql` (끝에 쿼리 추가)
- Regenerate: `server/internal/profile/profiledb/` (`go generate ./db/`)
- Modify: `server/internal/profile/service.go` (함수 추가)
- Test: `server/internal/profile/active_test.go` (새 파일)

**Interfaces:**
- Produces:
  - `type ActiveProfile struct { AccountID uuid.UUID; Profile Profile }`
  - `func ListActiveProfiles(ctx context.Context, db profiledb.DBTX, activeSince time.Time, after uuid.UUID, limit int32) ([]ActiveProfile, error)` — `status = 'active'`이고 `last_active_at >= activeSince`인 계정의 프로필을 `account_id > after` 순서로 `limit`개. 첫 페이지는 `after = uuid.Nil`.

- [ ] **Step 1: 실패하는 테스트 작성** (`dbtest.New(t)`, 계정과 프로필은 기존 `service_test.go`의 helper 방식으로 만듦)
  * `TestListActiveProfiles_FiltersByStatusAndLastActive`: 활동 1일 전 계정 A, 정확히 `activeSince` 계정 B, `activeSince`보다 1초 전 계정 C, 삭제된 계정 D, 프로필 없는 계정 E → 결과 id 집합이 {A, B}.
  * `TestListActiveProfiles_PagesByAccountID`: 계정 5개, `limit = 2`로 `after`를 이어 세 번 부르면 2, 2, 1개이고 합친 id가 정렬된 5개와 같음. 네 번째는 빈 slice.
  * `TestListActiveProfiles_ConvertsProfile`: 결과 `Profile`이 같은 계정의 `Service.Get`(기존 조회) 결과와 같음.
- [ ] **Step 2: 실행해 실패 확인** — `cd server && go test ./internal/profile/ -run TestListActiveProfiles` → 컴파일 실패(`ListActiveProfiles` 없음)
- [ ] **Step 3: 쿼리와 함수 구현**
  * 쿼리 `-- name: ListActiveProfiles :many`: `SELECT sqlc.embed(p) FROM profiles p JOIN accounts a ON a.id = p.account_id WHERE a.status = 'active' AND a.last_active_at >= @active_since AND p.account_id > @after ORDER BY p.account_id LIMIT @page_size`. `sqlc.embed`로 행의 `Profile` 필드가 `profiledb.Profile`이 되게 합니다.
  * `ListActiveProfiles`는 행마다 `profileFromRow`로 바꿉니다.
- [ ] **Step 4: 통과 확인** — `cd server && go generate ./db/ && go test -race ./internal/profile/` → PASS
- [ ] **Step 5: Commit** — `feat(server): 활동 사용자 프로필 페이지 조회 (P8-3)`

### Task 2: precompute 실행 로직

**Files:**
- Create: `server/internal/precompute/precompute.go`
- Test: `server/internal/precompute/precompute_test.go`

**Interfaces:**
- Consumes: Task 1의 `profile.ActiveProfile`
- Produces:
  - `type Fortune interface { Daily(ctx context.Context, b profile.Birth, date profile.LocalDate, currentTimezone string) (*enginev1.DailyResponse, error); Month(ctx context.Context, b profile.Birth, year, month int, currentTimezone string) (*enginev1.MonthResponse, error) }` (`*fortune.Service`가 만족)
  - `type ProfileLister func(ctx context.Context, activeSince time.Time, after uuid.UUID, limit int32) ([]profile.ActiveProfile, error)`
  - `type Deps struct { Profiles ProfileLister; Fortune Fortune; Clock clock.Clock; Logger *slog.Logger }`
  - `type Result struct { Targets, Succeeded, Failed int }`
  - `var ErrAllFailed = errors.New(...)`
  - `func Run(ctx context.Context, deps Deps) (Result, error)`
  * 상수: `activeWindow = 14 * 24 * time.Hour`, `pageSize int32 = 500`, `engineConcurrency = 8`, 창 `22:00 <= 현지 < 22:30`.

- [ ] **Step 1: 실패하는 테스트 작성** (가짜 `Fortune`은 호출을 mutex로 기록하고 동시 실행 수 최대값을 잼. `Profiles`는 메모리 slice를 `after`·`limit`로 자름. 시계는 `clocktest.New`)
  * `TestRun_SelectsUsersInLocalWindow`: now = `2026-11-03T13:15:00Z`. `Asia/Seoul`(22:15, 대상), `Asia/Tokyo`(22:15, 대상), `Europe/London`(13:15, 아님), `Asia/Kathmandu`(19:00, 아님) → `Daily`가 서울과 도쿄에 날짜 `2026-11-04`, 각자 `CurrentTimezone`으로 불림. `Result{Targets: 2, Succeeded: 2}`.
  * `TestRun_WindowBoundaries`: 현지 21:59:59 아님, 22:00:00 대상, 22:29:59 대상, 22:30:00 아님.
  * `TestRun_MonthOnLastDay`: now = `2026-12-31T13:10:00Z`, `Asia/Seoul` → `Daily(2027-01-01)`과 `Month(2027, 1)`. 다른 날(11-03)에는 `Month`를 부르지 않음.
  * `TestRun_DSTNextDate`: now = `2027-03-14T03:10:00Z`(`America/New_York` 3-13 22:10 EST, 다음 날 3-14 02:00에 EDT로 바뀜) → `Daily(2027-03-14)`.
  * `TestRun_InvalidTimezoneCountsFailed`: `Nowhere/Invalid` 1명, 서울 대상 1명 → 서울은 계산, `Result{Targets: 2, Succeeded: 1, Failed: 1}`, 오류 없음. (시간대를 못 읽으면 대상인지 모르므로 대상과 실패로 셈)
  * `TestRun_PartialFailureSucceeds`: 대상 3명 중 1명의 `Daily`가 오류 → `Result{Targets: 3, Succeeded: 2, Failed: 1}`, 오류 없음. `Daily`가 실패한 사람은 `Month`도 부르지 않음.
  * `TestRun_AllFailedIsError`: 대상 2명 모두 실패 → `errors.Is(err, ErrAllFailed)`. 대상 0명 → 오류 없음, `Result{}`.
  * `TestRun_PagesThroughAll`: 대상 1203명(`pageSize` 500을 넘김) → `Daily` 호출 1203번, 계정마다 한 번.
  * `TestRun_LimitsConcurrency`: 대상 40명, 가짜 `Daily`가 잠깐 막힘 → 동시 실행 최대값 ≤ 8이고 > 1.
  * `TestRun_ListErrorIsError`: `Profiles`가 오류 → 오류를 감싸 돌려줌.
  * `TestRun_UsesActiveSince`: `Profiles`가 받은 `activeSince`가 now - 336h.
- [ ] **Step 2: 실행해 실패 확인** — `cd server && go test ./internal/precompute/` → 컴파일 실패
- [ ] **Step 3: `Run` 구현** — 페이지를 모두 읽으면서 대상을 고르고, `golang.org/x/sync/errgroup`(go.mod에 있음)의 `Group.SetLimit(engineConcurrency)`로 사용자마다 `Daily` 뒤(성공 시) 필요하면 `Month`를 부릅니다. goroutine은 오류를 돌려주지 않고 결과만 셉니다(atomic 또는 mutex). 다음 날은 `time.Date(y, m, d+1, 0, 0, 0, 0, loc)`로 구합니다. 끝에 `Logger.InfoContext(ctx, "precompute 완료", "targets", …, "succeeded", …, "failed", …)`. 사용자 실패는 `WarnContext`로 오류 종류만 남깁니다(계정 id 없음).
- [ ] **Step 4: 통과 확인** — `cd server && go test -race ./internal/precompute/` → PASS
- [ ] **Step 5: Commit** — `feat(server): precompute 대상 선정과 동시 계산 (P8-3)`

### Task 3: `job precompute` 조립

**Files:**
- Create: `server/internal/cli/precompute.go`
- Modify: `server/internal/cli/cli.go:194-202` (`runJob`에서 `precompute` 분기, 주석)
- Test: `server/internal/cli/precompute_test.go`

**Interfaces:**
- Consumes: Task 1 `profile.ListActiveProfiles`, Task 2 `precompute.Run`, 기존 `engine.NewClient`, `engine.NewVersions`, `fortune.NewService`, `fortune.NewPostgresCache`, `openDatabase`, `config.Load`, `config.LoadEngine`
- Produces:
  - `func runPrecompute(ctx context.Context, getenv func(string) string, stderr io.Writer) error` — 설정은 DB와 엔진만 읽습니다(serve 전체 설정 불필요).
  - `type precomputeDeps struct { Pool *pgxpool.Pool; Engine engine.Engine; Clock clock.Clock; Logger *slog.Logger }`
  - `func precomputeJob(ctx context.Context, deps precomputeDeps) error` — `engine.NewVersions(deps.Engine, …).Refresh` 실패는 오류. 그 뒤 `fortune.Service`를 만들어 `precompute.Run`.

- [ ] **Step 1: 실패하는 테스트 작성** (`dbtest.New(t)`, `enginetest.Fake`, 기존 `retention_test.go`의 DB·계정 helper 방식)
  * `TestJobPrecompute_FillsDailyCache`: 서울 대상 계정 1명, 시계 서울 22:10 → `precomputeJob` 뒤 `daily_cache`에 다음 날 행 1개. 한 번 더 돌리면 `Fake.Daily` 호출 수가 늘지 않음(캐시 사용).
  * `TestJobPrecompute_EngineInfoFailureIsError`: `Fake.Info`가 오류 → 오류, `Fake.Daily` 호출 0.
  * `TestRun_PrecomputeWithoutDatabaseURL_Exits1WithConfigError`: `runCLI(t, "job", "precompute")`에 DB 설정 없음 → 종료 코드 1, stderr에 설정 오류.
  * `TestRun_PrecomputeMissingEngineAddr_Exits1`: DB만 있고 `ENGINE_ADDR` 없음 → 종료 코드 1.
- [ ] **Step 2: 실행해 실패 확인** — `cd server && go test ./internal/cli/ -run 'Precompute'` → 실패(`ErrNotImplemented` 또는 컴파일)
- [ ] **Step 3: 구현** — `runRetention`과 같은 순서(설정 → logger → DB → 엔진 client → `precomputeJob`). 실패는 `logger.ErrorContext` 뒤 `&loggedError{err: err}`. `runJob` 주석은 "notify는 P8-4에서 채웁니다"로.
- [ ] **Step 4: 통과 확인** — `cd server && go test -race ./internal/cli/` → PASS
- [ ] **Step 5: Commit** — `feat(server): job precompute 조립 (P8-3)`

### Task 4: 배포(Job, Scheduler, workflow)

**Files:**
- Modify: `server/deploy/terraform/env/jobs.tf` (`server_jobs`에 `"server-precompute" = ["job", "precompute"]`, 위 주석)
- Modify: `server/deploy/terraform/env/scheduler.tf` (invoker IAM과 Scheduler 추가)
- Modify: `.github/workflows/deploy-server-env.yml:149-155` (단계 이름과 precompute 줄 추가)

**Interfaces:**
- Produces: Cloud Run Job `server-precompute`, Scheduler `precompute-half-hourly`(`schedule = "0,30 * * * *"`, `time_zone = "Etc/UTC"`, `paused = true`, `ignore_changes = [paused]`), `google_cloud_run_v2_job_iam_member.scheduler_precompute`

- [ ] **Step 1:** 세 파일을 retention과 같은 모양으로 고칩니다. workflow 단계 이름은 `배치 Job과 Scheduler`로 바꾸고 `server-precompute` update와 `precompute-half-hourly` resume을 더합니다.
- [ ] **Step 2: 검증** — `cd server/deploy/terraform/env && terraform fmt -check && terraform init -backend=false -input=false >/dev/null && terraform validate` → `Success!`. workflow는 `actionlint .github/workflows/deploy-server-env.yml`(설치돼 있으면) 또는 YAML 파싱 `python3 -c "import yaml,sys;yaml.safe_load(open(sys.argv[1]))" .github/workflows/deploy-server-env.yml` → 오류 없음.
- [ ] **Step 3: Commit** — `feat(server): precompute Job과 30분 Scheduler (P8-3)`

### Task 5: 결정과 문서

**Files:**
- Modify: `server/docs/decisions.md` (S128 행)
- Modify: `server/docs/specs/2026-10-11-server-mvp-design.md` §8.1 (Job 실패 조건과 UTC 0·30분 실행을 한 줄씩)
- Modify: `server/CLAUDE.md` (결정 범위 S1~S128, 현재 상태에 P8-3 한 줄, 다음 할 일 1번에서 P8-3 뺌)

- [ ] **Step 1:** S128 행: 대상 선정은 Go 시각 계산(S31 tzdata, DB `AT TIME ZONE` 쓰지 않음), 계정 id 순 500개 페이지, Job 실패는 조회·엔진 버전 실패와 대상 전원 실패만, 시간대를 못 읽은 프로필은 실패로 셈, Scheduler UTC `0,30 * * * *`. 근거 칸 끝에 `사용자 영향: 없음(캐시만 채움)`(D87).
- [ ] **Step 2: 검증** — 저장소 루트에서 `python3 tools/docs-check/docs_check.py` → `OK: docs 검사 통과`
- [ ] **Step 3: 전체 검사** — `cd server && go vet ./... && golangci-lint run ./... && go test -race ./...` → 실패 없음
- [ ] **Step 4: Commit** — `docs(server): P8-3 결정 S128과 상태 (P8-3)`

## 병합 뒤 확인 (staging)
* 배포 workflow가 `server-precompute`를 update하고 Scheduler를 resume했는지.
* 서울 22:00, 22:30 실행 로그의 `precompute 완료` 수(대상이 있으면 `targets` ≥ 1).
