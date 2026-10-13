# P1 기반과 REST 계약 초안 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 이후 모든 계획이 올라설 Go 서버 뼈대(하위 명령, 설정, Clock, 로깅, DB·migration, HTTP·오류 형식, CI, 이미지)를 만들고, app이 기댈 REST API v1 계약 초안(`server/api/openapi.yaml`)과 그 생성 코드를 확정합니다.

**Architecture:** Go 바이너리 하나(`cmd/server`)가 하위 명령으로 service와 Job을 실행합니다. HTTP는 표준 `net/http` 위에 oapi-codegen strict server를 얹고, 모든 오류를 RFC 9457 problem+json으로 냅니다. P1이 끝나면 모든 v1 엔드포인트가 계약대로 요청을 검증하고 501 `not_implemented`를 돌려주며, 이후 계획이 핸들러를 하나씩 채웁니다.

**Tech Stack:** Go 1.27, `net/http`, oapi-codegen v2(≥ 2.8.0, OpenAPI 3.1 지원), kin-openapi, `github.com/oapi-codegen/nethttp-middleware`, pgx v5, goose v3, testcontainers-go, `log/slog`, golangci-lint v2, Docker(distroless)

**Spec:** `server/docs/specs/2026-10-11-server-mvp-design.md` (특히 §2, §5, §11, §12, §13.1)

## Global Constraints

- 작업 디렉터리는 `server/`입니다. 그 밖은 `.github/workflows/server.yml`만 고칩니다.
- Go 모듈 경로: `github.com/june20516/myungli-diary/server`, `go 1.27`.
- 코드 생성·DB 도구는 `go.mod`의 `tool` 지시어로 버전을 고정하고 `go tool <이름>`으로 실행합니다(oapi-codegen, goose). golangci-lint는 CI에서 공식 action으로, 로컬에서는 설치본으로 실행합니다.
- 생성 코드는 commit하고, CI가 다시 생성해 차이가 없는지 검사합니다.
- 시간은 `Clock`으로만 읽습니다. `time.Now()`를 직접 부르는 코드는 `internal/platform/clock`뿐입니다.
- 로그에 출생 정보, 호칭, 일기·일정 본문, 토큰, 요청 본문을 남기지 않습니다.
- 오류 응답은 모두 `application/problem+json`이고 `code`·`traceId`를 담습니다. `type`은 `https://api.myungli.app/problems/<code>`입니다(실제 도메인이 정해지면 바꿈, spec §11.1).
- JSON 필드는 camelCase, 날짜는 `YYYY-MM-DD`, 시각은 RFC 3339입니다. 사용자의 선택은 상태 필드로 보내고, 필드를 빼거나 `null`로 뜻을 담지 않습니다(spec §3.2·§5.1). 계약에 `null` 타입을 쓰지 않습니다.
- OpenAPI 3.1 문서이되, oapi-codegen의 초기 3.1 지원 범위를 넘지 않도록 3.1 전용 문법(`type` 배열, `$ref` 형제 키워드, `webhooks`, `const`)은 쓰지 않습니다.
- 요청 본문 상한은 1 MiB입니다.
- 커밋 메시지 끝에는 세션의 Co-Authored-By·Claude-Session 줄을 붙입니다.

## Review Focus

1. 아주 큰 요청 본문(예: 5 MiB JSON) → 메모리를 쓰기 전에 413 `request.too_large` problem으로 끊어야 합니다. (Task 6)
2. 계약에 있는 경로에 틀린 메서드(예: `PATCH /v1/me`) → 텍스트가 아닌 405 `method.not_allowed` problem과 `Allow` 헤더. (Task 6)
3. JSON이 아닌 Content-Type으로 본문을 보냄 → 415 `request.unsupported_media_type` problem. (Task 8)
4. DB가 꺼져 있거나 주소가 틀린 채 `serve`·`migrate` 시작 → 멈춰 있지 않고 5초 안에 0이 아닌 코드로 끝나며 원인을 로그에 남김. (Task 5)
5. 배포 중 SIGTERM을 받았을 때 처리 중인 요청 → 끊지 않고 끝까지 응답한 뒤 종료(최대 10초). (Task 6)

---

### Task 1: Go 모듈과 하위 명령 진입점

**Files:**
- Create: `server/go.mod`, `server/cmd/server/main.go`, `server/internal/cli/cli.go`
- Test: `server/internal/cli/cli_test.go`

**Interfaces:**
- Produces:
  - `cli.Run(ctx context.Context, args []string, getenv func(string) string, stderr io.Writer) int` — 종료 코드 0 성공, 1 실행 오류, 2 사용법 오류.
  - `cli.Command` 테이블: `serve`, `migrate up|down|status`, `seed`, `job precompute|notify|retention`. P1에서 `seed`와 `job *`은 `cli.ErrNotImplemented`를 내고 종료 코드 1입니다(P4·P8에서 채움).
  - `main`은 `signal.NotifyContext(ctx, SIGINT, SIGTERM)`로 만든 ctx를 넘기고 `os.Exit(cli.Run(...))`만 합니다.

- [ ] **Step 1: 모듈을 만들고 도구를 고정**

```bash
cd server
go mod init github.com/june20516/myungli-diary/server
go get -tool github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@latest
go get -tool github.com/pressly/goose/v3/cmd/goose@latest
go tool oapi-codegen -version
```
Expected: 버전이 `v2.8.0` 이상으로 출력됩니다. 미만이면 멈추고 보고합니다(OpenAPI 3.1 지원 조건).

- [ ] **Step 2: 실패하는 테스트 작성** (`cli_test.go`)

```go
func TestRun_NoArgs_PrintsUsageAndExits2(t *testing.T)        // args = []        → 2, stderr에 "usage:" 포함
func TestRun_UnknownCommand_Exits2(t *testing.T)               // ["nope"]         → 2, stderr에 `unknown command "nope"`
func TestRun_JobWithoutName_Exits2(t *testing.T)               // ["job"]          → 2
func TestRun_UnknownJob_Exits2(t *testing.T)                   // ["job","x"]      → 2
func TestRun_NotImplementedJob_Exits1(t *testing.T)            // ["job","notify"] → 1, stderr에 "not implemented"
func TestRun_MigrateWithoutDirection_Exits2(t *testing.T)      // ["migrate"]      → 2
```

- [ ] **Step 3: 실패 확인** — Run: `go test ./internal/cli/...` Expected: FAIL (`undefined: Run`)

- [ ] **Step 4: `cli.go`와 `main.go` 구현.** 하위 명령은 이름 → `func(ctx, args, cfgSource, stderr) error` 맵으로 둡니다. `serve`와 `migrate`의 실제 동작은 Task 5·6에서 연결하고, 이 task에서는 사용법 검증만 합니다.

- [ ] **Step 5: 통과 확인** — Run: `go test ./internal/cli/...` Expected: PASS

- [ ] **Step 6: Commit** — `git add server/go.mod server/go.sum server/cmd server/internal/cli && git commit -m "feat(server): Go 모듈과 하위 명령 진입점"`

### Task 2: 설정

**Files:**
- Create: `server/internal/platform/config/config.go`
- Test: `server/internal/platform/config/config_test.go`

**Interfaces:**
- Produces:
  - `type Config struct { Env string; Port int; DatabaseURL string; LogLevel slog.Level; GCPProjectID string }`
  - `config.Load(getenv func(string) string) (Config, error)`
  - `(Config) RequireDatabase() error` — `DatabaseURL`이 비면 오류.

| 환경 변수 | 필드 | 기본값 | 검증 |
| --- | --- | --- | --- |
| `APP_ENV` | Env | `local` | `local`·`staging`·`prod` 중 하나 |
| `PORT` | Port | `8080` | 1~65535 정수 (Cloud Run이 넣는 값) |
| `DATABASE_URL` | DatabaseURL | 없음 | `RequireDatabase`에서만 검사 |
| `LOG_LEVEL` | LogLevel | `info` | `debug`·`info`·`warn`·`error` |
| `GOOGLE_CLOUD_PROJECT` | GCPProjectID | 없음 | 없음 |

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestLoad_Defaults(t *testing.T)            // 빈 환경 → Env "local", Port 8080, LogLevel slog.LevelInfo
func TestLoad_InvalidEnv(t *testing.T)          // APP_ENV=dev → 오류 메시지에 "APP_ENV"
func TestLoad_InvalidPort(t *testing.T)         // PORT=0, PORT=abc → 오류 메시지에 "PORT"
func TestLoad_InvalidLogLevel(t *testing.T)     // LOG_LEVEL=verbose → 오류
func TestRequireDatabase(t *testing.T)          // DatabaseURL "" → 오류, 값이 있으면 nil
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/platform/config/...` Expected: FAIL
- [ ] **Step 3: `config.go` 구현** — 오류는 잘못된 변수를 모두 모아 `errors.Join`으로 돌려줍니다.
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 환경 변수 설정 로드"`

### Task 3: Clock

**Files:**
- Create: `server/internal/platform/clock/clock.go`, `server/internal/platform/clock/clocktest/fake.go`
- Test: `server/internal/platform/clock/clocktest/fake_test.go`

**Interfaces:**
- Produces:
  - `type Clock interface { Now() time.Time }`, `clock.System{}` (UTC로 돌려줌)
  - `clocktest.New(t time.Time) *clocktest.Fake`, `(*Fake) Now() time.Time`, `(*Fake) Set(time.Time)`, `(*Fake) Advance(time.Duration)` — 여러 goroutine에서 안전.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestFake_SetAndAdvance(t *testing.T) // New(2026-10-11T00:00Z) → Advance(90*time.Minute) → Now()==2026-10-11T01:30Z
func TestFake_ConcurrentAccess(t *testing.T) // -race에서 Advance와 Now를 100개 goroutine으로 동시에 불러도 경합 없음
func TestSystem_ReturnsUTC(t *testing.T)     // clock.System{}.Now().Location() == time.UTC
```

- [ ] **Step 2: 실패 확인** — Run: `go test -race ./internal/platform/clock/...` Expected: FAIL
- [ ] **Step 3: 구현** — `Fake`는 `sync.Mutex`로 보호합니다.
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 주입 가능한 Clock"`

### Task 4: 구조화 로그와 trace id

**Files:**
- Create: `server/internal/platform/logging/logging.go`, `server/internal/platform/logging/trace.go`
- Test: `server/internal/platform/logging/logging_test.go`, `server/internal/platform/logging/trace_test.go`

**Interfaces:**
- Produces:
  - `logging.New(w io.Writer, level slog.Level, projectID string) *slog.Logger` — JSON. Cloud Logging이 읽는 키로 바꿉니다: 레벨 키 `severity`(값 `DEBUG`·`INFO`·`WARNING`·`ERROR`), 메시지 키 `message`. ctx에 trace id가 있으면 `traceId`를, projectID가 있으면 `logging.googleapis.com/trace` = `projects/<projectID>/traces/<traceId>`를 붙입니다.
  - `logging.WithTrace(next http.Handler) http.Handler` — W3C `traceparent`(`00-<32hex>-<16hex>-<2hex>`)에서 trace id를 읽고, 없거나 형식이 틀리면 새 32자리 hex를 만듭니다. 응답 헤더 `X-Trace-Id`로도 돌려줍니다.
  - `logging.TraceID(ctx context.Context) string`

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestNew_UsesCloudLoggingKeys(t *testing.T)    // logger.Warn("x") → JSON에 "severity":"WARNING","message":"x"
func TestNew_AddsTraceFromContext(t *testing.T)    // projectID "p", ctx trace "4bf92f3577b34da6a3ce929d0e0e4736"
                                                   // → "traceId" 값과 "logging.googleapis.com/trace":"projects/p/traces/4bf9…4736"
func TestWithTrace_ParsesTraceparent(t *testing.T) // traceparent "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
                                                   // → TraceID(ctx)=="4bf92f3577b34da6a3ce929d0e0e4736", X-Trace-Id 헤더 같은 값
func TestWithTrace_GeneratesWhenMissingOrInvalid(t *testing.T) // 없음, "garbage" → 32자리 소문자 hex, 두 요청의 값이 다름
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/platform/logging/...` Expected: FAIL
- [ ] **Step 3: 구현** — `slog.JSONHandler`의 `ReplaceAttr`로 키를 바꾸고, ctx에서 trace id를 읽어 붙이는 `slog.Handler` wrapper를 둡니다.
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): Cloud Logging 형식 로그와 trace id"`

### Task 5: DB 연결, migration, 테스트용 DB

**Files:**
- Create: `server/compose.yaml`, `server/db/embed.go`, `server/db/migrations/00001_init.sql`, `server/internal/platform/postgres/postgres.go`, `server/internal/platform/postgres/migrate.go`, `server/internal/platform/dbtest/dbtest.go`
- Modify: `server/internal/cli/cli.go` (`migrate` 연결)
- Test: `server/internal/platform/postgres/postgres_test.go`, `server/internal/platform/postgres/migrate_test.go`

**Interfaces:**
- Consumes: `config.Config.RequireDatabase()` (Task 2), `logging.New` (Task 4)
- Produces:
  - `db.Migrations embed.FS` (패키지 `github.com/june20516/myungli-diary/server/db`, `//go:embed migrations/*.sql`)
  - `postgres.Open(ctx context.Context, url string) (*pgxpool.Pool, error)` — 연결 확인(ping)까지 5초 제한.
  - `postgres.Migrate(ctx context.Context, pool *pgxpool.Pool, direction string) error` — `up`(전부), `down`(하나), `status`. goose provider API에 `db.Migrations`를 넘깁니다.
  - `dbtest.New(t testing.TB) *pgxpool.Pool` — 패키지당 PostgreSQL 컨테이너 하나를 띄우고 migration을 적용한 template DB를 만든 뒤, 테스트마다 `CREATE DATABASE … TEMPLATE …`로 새 DB를 줍니다. `t.Cleanup`에서 DB를 지웁니다. 이후 계획의 모든 DB 테스트가 이 함수를 씁니다.
- 고정 값: 이미지 `postgres:17-alpine`(Cloud SQL PostgreSQL 17과 맞춤). `compose.yaml`은 포트 5432, 사용자·DB 이름 `myungli`, 비밀번호 `myungli`(로컬 전용).
- `00001_init.sql`: 이후 테이블이 쓸 트리거 함수 `set_updated_at()`(행을 고칠 때 `updated_at = now()`)을 만들고, down에서 지웁니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestMigrate_UpDownUp(t *testing.T)            // dbtest 컨테이너에서 up → down → up 모두 오류 없음, status에 00001이 applied
func TestInit_SetUpdatedAtExists(t *testing.T)     // up 뒤 `SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at'` 한 행
func TestOpen_UnreachableFailsFast(t *testing.T)   // "postgres://u:p@127.0.0.1:1/x" → 6초 안에 오류
func TestDBTest_IsolatedDatabases(t *testing.T)    // dbtest.New 두 번 → 서로 다른 current_database()
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/platform/postgres/...` Expected: FAIL (Docker가 켜져 있어야 합니다)
- [ ] **Step 3: 구현과 `migrate` 하위 명령 연결** — `migrate`는 `RequireDatabase` → `Open` → `Migrate` 순서이며, 실패하면 오류를 로그로 남기고 종료 코드 1입니다.
- [ ] **Step 4: 통과 확인** — Run: `go test ./internal/platform/postgres/... ./internal/cli/...` Expected: PASS
- [ ] **Step 5: 로컬 확인** — Run: `docker compose up -d && DATABASE_URL=postgres://myungli:myungli@localhost:5432/myungli?sslmode=disable go run ./cmd/server migrate status` Expected: `00001_init.sql`이 Applied로 표시
- [ ] **Step 6: Commit** — `git commit -m "feat(server): PostgreSQL 연결, goose migration, 테스트 DB"`

### Task 6: HTTP 뼈대와 problem+json

**Files:**
- Create: `server/internal/httpapi/problem/problem.go`, `server/internal/httpapi/server.go`, `server/internal/httpapi/middleware.go`, `server/internal/cli/serve.go`
- Test: `server/internal/httpapi/problem/problem_test.go`, `server/internal/httpapi/server_test.go`, `server/internal/cli/serve_test.go`

**Interfaces:**
- Consumes: `logging.WithTrace`, `logging.TraceID` (Task 4), `clock.Clock` (Task 3), `postgres.Open` (Task 5)
- Produces:
  - `problem.Problem{ Type, Title string; Status int; Code, TraceID, Detail string; Errors []problem.FieldError }`, `problem.FieldError{ Field, Code string }` — JSON 이름은 spec §11.1 예시대로. 빈 `Detail`·`Errors`는 내보내지 않습니다.
  - `problem.New(status int, code, title string) problem.Problem`
  - `problem.Write(w http.ResponseWriter, r *http.Request, p problem.Problem)` — `Type`을 코드로 채우고 `TraceID`를 ctx에서 채웁니다. 상태가 401이면 `WWW-Authenticate: Bearer error="invalid_token"`을 붙입니다.
  - `type httpapi.Deps struct { Logger *slog.Logger; Clock clock.Clock; DB *pgxpool.Pool }`
  - `httpapi.NewHandler(deps httpapi.Deps, routes func(mux *http.ServeMux)) http.Handler` — 미들웨어 순서: trace → panic 복구 → 본문 상한 → 접근 로그. `routes`로 이후 task와 계획이 경로를 등록합니다. `GET /healthz`는 항상 등록하고 200 `{"status":"ok"}`.
  - `cli` `serve`: `http.Server{ReadHeaderTimeout: 10s}`. ctx가 취소되면 `Shutdown`을 10초 제한으로 부릅니다.
- 고정 code: 등록되지 않은 경로 404 `route.not_found`, 메서드 불일치 405 `method.not_allowed`(+`Allow`), panic 500 `internal`, 본문 1 MiB 초과 413 `request.too_large`.
- 접근 로그 필드: `method`, `route`(등록 패턴), `status`, `latencyMs`. 경로의 실제 값과 본문은 남기지 않습니다(날짜 경로에도 개인정보가 섞일 수 있음).

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestWrite_SetsHeadersAndFields(t *testing.T)    // New(422,"diary.future_date","Diary date is in the future")
                                                     // → Content-Type "application/problem+json", body.type ".../problems/diary.future_date", traceId 채워짐
func TestWrite_401AddsWWWAuthenticate(t *testing.T)
func TestHandler_Healthz(t *testing.T)               // GET /healthz → 200 {"status":"ok"}
func TestHandler_UnknownRoute(t *testing.T)          // GET /nope → 404 problem code "route.not_found"
func TestHandler_MethodNotAllowed(t *testing.T)      // routes에 "GET /v1/x" 등록, DELETE /v1/x → 405 problem "method.not_allowed", Allow 헤더에 GET
func TestHandler_PanicRecovered(t *testing.T)        // panic 하는 핸들러 → 500 problem "internal", 로그에 stack, 응답에 stack 없음
func TestHandler_BodyTooLarge(t *testing.T)          // 본문을 읽는 핸들러에 5 MiB → 413 problem "request.too_large"
func TestServe_GracefulShutdown(t *testing.T)        // 2초 걸리는 요청 진행 중 ctx 취소 → 그 요청이 200으로 끝난 뒤 serve 반환
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/httpapi/... ./internal/cli/...` Expected: FAIL
- [ ] **Step 3: 구현** — 404·405는 `ServeMux`가 내는 평문 응답을 그대로 두지 않고 problem으로 바꿉니다. `mux.Handler(r)`가 빈 패턴을 돌려주는 경우를 가로채는 방식을 씁니다. 본문 상한은 `http.MaxBytesReader`이며, 읽다가 `*http.MaxBytesError`가 나면 413으로 바꾸는 헬퍼 `httpapi.DecodeJSON(w, r, v any) bool`을 둡니다.
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): HTTP 뼈대, problem+json, graceful shutdown"`

### Task 7: REST API v1 계약 초안

**Files:**
- Create: `server/api/openapi.yaml`, `server/api/contract_test.go` (패키지 `api_test`)

**Interfaces:**
- Produces: `server/api/openapi.yaml` — app에 제공하는 계약 원본. Task 8이 이 파일로 코드를 생성합니다.

- [ ] **Step 1: 3.1 생성 가능 여부를 먼저 확인 (spike, 버릴 파일)**

저장소 밖 임시 디렉터리(`SPIKE=$(mktemp -d)`)에 `openapi: 3.1.0`, 경로 하나(`GET /v1/ping`), `components.schemas` 하나, `securitySchemes.bearerAuth`가 있는 최소 문서 `mini.yaml`을 만들고 다음을 실행합니다.
Run: `go tool oapi-codegen -generate types,std-http-server,strict-server -package gen "$SPIKE/mini.yaml" > /dev/null`
Expected: 오류 없이 끝남. 실패하면 멈추고 보고합니다(계약 버전을 3.0.3으로 내릴지 사용자 결정 필요).

- [ ] **Step 2: 실패하는 계약 테스트 작성** (`contract_test.go`, kin-openapi `openapi3.NewLoader`)

```go
func TestContract_LoadsAndValidates(t *testing.T)       // LoadFromFile("openapi.yaml") 후 doc.Validate(ctx) == nil, doc.OpenAPI == "3.1.0"
func TestContract_OperationIDs(t *testing.T)            // operationId 집합이 아래 표의 집합과 정확히 같음
func TestContract_ErrorsAreProblems(t *testing.T)       // 모든 4xx·5xx·default 응답의 content가 application/problem+json 하나이고 $ref는 Problem
func TestContract_SecurityByDefault(t *testing.T)       // 최상위 security는 bearerAuth. 아래 표의 "인증" 열이 없음·App Check인 operation만 security를 덮어씀
func TestContract_NoNullTypes(t *testing.T)             // 문서 어디에도 "null" 타입·nullable 없음
func TestContract_CreatePostsAcceptIdempotencyKey(t *testing.T) // createSchedule, registerDevice에 헤더 Idempotency-Key(선택)
```

- [ ] **Step 3: 실패 확인** — Run: `go test ./api/...` Expected: FAIL (파일 없음)

- [ ] **Step 4: `openapi.yaml` 작성** — 아래 표가 계약 내용입니다. 표에 없는 필드는 넣지 않습니다.

**공통**
- `info.version: 1.0.0-draft`, `servers`는 `/`(상대).
- `securitySchemes`: `bearerAuth`(http bearer, JWT), `appCheck`(apiKey, header `X-Firebase-AppCheck`).
- 모든 operation에 응답 `default: Problem`을 둡니다. 400·401·403·404·409·413·415·422·429·500·502·503·504 중 해당 operation이 낼 수 있는 상태는 따로 적습니다.
- 공통 parameter: `Date`(path `date`, `format: date`), `IdempotencyKey`(header, 1~255자).

**operation 표**

| operationId | 메서드·경로 | 인증 | 요청 | 성공 응답 |
| --- | --- | --- | --- | --- |
| `loginKakao` | `POST /v1/auth/kakao` | 없음 | `KakaoLoginRequest` | 200 `LoginResponse` |
| `loginApple` | `POST /v1/auth/apple` | 없음 | `AppleLoginRequest` | 200 `LoginResponse` |
| `appleCallback` | `POST /v1/auth/apple/callback` | 없음 | form-urlencoded `code`, `id_token`, `state`, `user`(선택) | 303, `Location` 헤더 |
| `refreshToken` | `POST /v1/auth/refresh` | 없음 | `RefreshRequest` | 200 `TokenPair` |
| `logout` | `POST /v1/auth/logout` | bearer | `RefreshRequest` | 204 |
| `getMe` | `GET /v1/me` | bearer | - | 200 `Me` |
| `deleteMe` | `DELETE /v1/me` | bearer | - | 202 `DeletionScheduled` |
| `agreeConsents` | `POST /v1/me/consents` | bearer | `ConsentRequest` | 204 |
| `createProfile` | `PUT /v1/me/profile` | bearer | `ProfileInput` | 200 `ProfileResponse` |
| `updateProfile` | `PATCH /v1/me/profile` | bearer | `ProfilePatch` (`application/merge-patch+json`) | 200 `ProfileResponse` |
| `getDaily` | `GET /v1/daily/{date}` | bearer | - | 200 `Daily` |
| `getChart` | `GET /v1/chart` | bearer | - | 200 `Chart` |
| `getCalendar` | `GET /v1/calendar/{year}/{month}` | bearer | path `year` 1900~2099, `month` 1~12 | 200 `Calendar` |
| `putReaction` | `PUT /v1/daily/{date}/slots/{slot}/reaction` | bearer | `ReactionInput` | 204 |
| `deleteReaction` | `DELETE /v1/daily/{date}/slots/{slot}/reaction` | bearer | - | 204 |
| `getGlossary` | `GET /v1/glossary` | bearer | query `lang`(선택) | 200 `Glossary`, `ETag` |
| `createPreview` | `POST /v1/preview` | App Check | `PreviewRequest` | 200 `Preview` |
| `getBirthHour` | `POST /v1/birth-hour` | App Check | `BirthHourRequest` | 200 `BirthHour` |
| `listDiaries` | `GET /v1/diaries` | bearer | query `from`, `to`(date), `tag`, `cursor`, `limit`(1~100, 기본 30) | 200 `DiaryList` |
| `getDiary` | `GET /v1/diaries/{date}` | bearer | - | 200 `Diary` |
| `putDiary` | `PUT /v1/diaries/{date}` | bearer | `DiaryInput` | 200 `Diary`(수정), 201 `Diary`(새로 씀) |
| `deleteDiary` | `DELETE /v1/diaries/{date}` | bearer | - | 204 |
| `restoreDiary` | `POST /v1/diaries/{date}/restore` | bearer | - | 200 `Diary` |
| `listSchedules` | `GET /v1/schedules` | bearer | query `from`, `to`(필수, 62일 이내) | 200 `ScheduleList` |
| `createSchedule` | `POST /v1/schedules` | bearer | `ScheduleInput` | 201 `Schedule`, `Location` |
| `updateSchedule` | `PATCH /v1/schedules/{id}` | bearer | `SchedulePatch` (`application/merge-patch+json`) | 200 `Schedule` |
| `deleteSchedule` | `DELETE /v1/schedules/{id}` | bearer | - | 204 |
| `restoreSchedule` | `POST /v1/schedules/{id}/restore` | bearer | - | 200 `Schedule` |
| `registerDevice` | `POST /v1/devices` | bearer | `DeviceInput` | 201 `Device` |
| `deleteDevice` | `DELETE /v1/devices/{id}` | bearer | - | 204 |
| `getEntitlements` | `GET /v1/me/entitlements` | bearer | - | 200 `Entitlements` |
| `restorePurchases` | `POST /v1/billing/restore` | bearer | - | 200 `Entitlements` |
| `revenuecatWebhook` | `POST /webhooks/revenuecat` | 없음(Authorization 헤더는 핸들러가 검증) | 자유 형식 object | 200 |
| `listCities` | `GET /v1/cities` | 없음 | query `q`(1~50자, 필수), `lang`(선택), `limit`(1~50, 기본 20) | 200 `CityList`, `ETag` |
| `getAppConfig` | `GET /v1/app-config` | 없음 | - | 200 `AppConfig` |
| `getHealth` | `GET /healthz` | 없음 | - | 200 `Health` |

`{slot}`은 writing 슬롯 id(예: `daily.fortune.head`), `{id}`는 UUID입니다. 언어는 bearer 요청이면 프로필 값, 그 밖이면 `Accept-Language`를 씁니다(spec §5.1).

**스키마 표** (필수 필드는 굵게. 굵지 않은 필드는 생략 가능하며 생략은 "값 없음"만 뜻함)

| 스키마 | 필드 |
| --- | --- |
| `Problem` | **type**(uri), **title**, **status**(int), **code**, **traceId**, detail, errors[`FieldError`{**field**, **code**}] |
| `Text` | **segments**[`Segment`{**text**, term}] |
| `SlotText` | **slot**, **messageKey**, **variant**(string: `advice`·`state`·`care`·`1`·`2`·`single`), **text**(`Text`), **reactable**(bool), reaction(`like`), evidence[`Evidence`] |
| `Evidence` | **ruleId**, **sourceRef**, detail(object, 값은 string) |
| `Notice` | **code**(`ambiguous_local_time`·`nonexistent_local_time`·`zi_hour_next_day`·`time_unknown`·`near_solar_term`·`dayun_start_approximate`·`focus_time_fallback`), **text**(`Text`) |
| `KakaoLoginRequest` | **idToken**, **nonce** |
| `AppleLoginRequest` | **idToken**, **authorizationCode**, **nonce**, **clientType**(`native`·`web`) |
| `RefreshRequest` | **refreshToken** |
| `TokenPair` | **accessToken**, **accessTokenExpiresAt**(date-time), **refreshToken**, **refreshTokenExpiresAt**(date-time) |
| `LoginResponse` | **tokens**(`TokenPair`), **isNewAccount**, **consentRequired**, **restoredFromDeletion** |
| `Me` | **accountId**(uuid), **status**(`active`·`pending_deletion`), deletionScheduledAt(date-time), **consentRequired**, **requiredConsents**[`ConsentDocument`], **hasProfile**, **adFree**(`AdFree`) |
| `ConsentDocument` | **document**(`terms`·`privacy`), **version** |
| `ConsentRequest` | **documents**[`ConsentDocument`] (1개 이상) |
| `DeletionScheduled` | **deletionScheduledAt**(date-time) |
| `LunarOrSolarDate` | **year**(1900~2099), **month**(1~12), **day**(1~31) — 음력 30일이 있어 `format: date`를 쓰지 않습니다 |
| `BirthTime` | **status**(`known`·`unknown`), value(`HH:MM`, pattern `^([01][0-9]|2[0-3]):[0-5][0-9]$`) |
| `BirthPlace` | **status**(`not_asked`·`skipped`·`city`), cityId |
| `Birth` | **calendar**(`solar`·`lunar`), **date**(`LunarOrSolarDate`), **isLeapMonth**, **time**(`BirthTime`), **gender**(`male`·`female`), **timezone**(IANA), **place**(`BirthPlace`) |
| `Notification` | **status**(`not_asked`·`enabled`·`disabled`), time(`HH:MM`, 분은 5의 배수: pattern `^([01][0-9]|2[0-3]):[0-5][05]$`) |
| `ProfileInput` | **honorific**(1~20자), **language**(`ko`·`en`·`ja`), **currentTimezone**, **birth**(`Birth`), **notification**(`Notification`) |
| `ProfilePatch` | `ProfileInput`의 모든 필드를 생략 가능하게. `birth`는 통째로 바꿈 |
| `Profile` | `ProfileInput`의 필드 전부(필수) |
| `ProfileResponse` | **profile**(`Profile`), **warnings**[`FieldError`] (`name.suffix_stripped`·`name.suffix_warning`) |
| `Pillar` | **stem**(`gap`…`gye` 10개), **branch**(`ja`…`hae` 12개) — 값은 proto enum 이름에서 접두어를 떼고 소문자로(glossary 키 규칙과 같음) |
| `Tag` | **key**, **polarity**(`good`·`bad`·`neutral`) |
| `Daily` | **date**, **rulesetVersion**, **dayPillar**(`Pillar`), **dayKind**(`gwiin_day`·`yongsin_day`·`gisin_day`·`ordinary_day`), **fortune**{**head**(`SlotText`), tag(`SlotText`)}, **guide**(`SlotText`), **cards**(`DailyCards`), **tags**{**featured**[`Tag`] 0~2개, **all**[string]}, **relations**[`Relation`], **notices**[`Notice`] |
| `DailyCards` | **color**{**element**, **role**(`yongsin`·`tonggwan`), **text**(`SlotText`)}, **direction**{**direction**(`n`·`ne`·`e`·`se`·`s`·`sw`·`w`·`nw`), **text**}, **number**{**number**(int), **text**}, **focusTime**{**picks**[`FocusSlot`] 1~2개, **fallback**, **text**} |
| `FocusSlot` | **branch**, **pillar**(`Pillar`), **start**, **end**(date-time, 프로필 현재 시간대의 offset으로), **huangdaoLucky**, **score**(int), **reasons**[string: `gwiin`·`yongsin`·`huisin`·`hap`] |
| `Relation` | **kind**(`stem_hap`·`branch_hap`·`chung`·`hyeong`), **natalPosition**(`year_stem`…`hour_branch` 8개), **suppressed**(bool), suppressedBy(kind와 같은 값) |
| `Chart` | **rulesetVersion**, **pillars**{**year**, **month**, **day**(`Pillar`), hour(`Pillar`, 시간 모름이면 생략)}, **tenGods**[{**position**, **tenGod**}], **hiddenStems**[{**position**, **stems**[{**stem**, **tenGod**}]}], **twelveStages**[{**position**, **stage**}], **shinsal**[{**kind**, **position**}], **gongmang**[branch], **elementWeights**[{**element**, **weight**(number)}], **strength**{**score**, **level**}, **yongsin**{**yongsin**, **huisin**, **gisin**, **tonggwan**, **method**(`johu`·`johu_neutral`·`eokbu`), johuStem, **text**(`SlotText`)}, **daeun**{**forward**, **startYears**, **startMonths**, **periods**[{**pillar**, **startAge**, **startAgeKorean**, **stemTenGod**, **branchTenGod**, **twelveStage**}]}, **seun**[{**year**, **pillar**, **tenGod**, **relationsWithNatal**[kind]}], **notices**[`Notice`] |
| `Calendar` | **year**, **month**, **rulesetVersion**, **days**[`CalendarDay`], **notices**[`Notice`] |
| `CalendarDay` | **date**, **pillar**, **lunar**{**month**, **day**, **isLeapMonth**}, solarTerm{**kind**(`sohan`…`dongji` 24개), **at**(date-time)}, **dayKind**, **luckLevel**(`good`·`neutral`·`caution`), **score**(int), **scoreItems**[{**id**, **score**}], featuredTag(`Tag`), **level**(`SlotText`) |
| `ReactionInput` | **reaction**(`like`) |
| `Glossary` | **seedVersion**, **lang**, **values**(object: 범주 → (값 → 이름)) — 범주는 writing `glossary.value_name` 키의 `<범주>`, 그리고 `tag`·`focus_reason`·`score_item`·`solar_term` |
| `PreviewRequest` | **installationId**(1~128자, 앱 설치마다 만든 무작위 값), **currentTimezone**, **birth**(`Birth`) |
| `Preview` | **date**, **dayKind**, **fortune**{**head**(`SlotText`), tag(`SlotText`)}, **featuredTags**[`Tag`], **notices**[`Notice`] |
| `BirthHourRequest` | **installationId**, **calendar**, **date**(`LunarOrSolarDate`), **isLeapMonth**, **time**(`HH:MM`) |
| `BirthHour` | **branch**, **start**(`HH:MM`), **end**(`HH:MM`) |
| `DiaryInput` | **body**(1~10000자) |
| `Diary` | **date**, **body**, guideQuestion(`Text`), **tags**{**featured**[`Tag`], **all**[string]}, **rulesetVersion**, **createdAt**, **updatedAt** |
| `DiaryList` | **items**[`DiarySummary`{**date**, **excerpt**(본문 앞 100자), **featuredTags**[`Tag`]}], nextCursor |
| `ScheduleInput` | **date**, **allDay**, time(`HH:MM`, `allDay`가 false일 때만), **title**(1~100자), memo(0~2000자) |
| `SchedulePatch` | `ScheduleInput`의 모든 필드를 생략 가능하게 |
| `Schedule` | **id**(uuid), `ScheduleInput`의 필드, **createdAt**, **updatedAt** |
| `ScheduleList` | **items**[`Schedule`] |
| `DeviceInput` | **fcmToken**(1~4096자), **platform**(`ios`·`android`) |
| `Device` | **id**(uuid), **platform** |
| `AdFree` | **active**, expiresAt(date-time) |
| `Entitlements` | **adFree**(`AdFree`) |
| `City` | **id**(string, GeoNames id), **name**, **country**(ISO 3166-1 alpha-2), **timezone** |
| `CityList` | **dataVersion**, **items**[`City`] |
| `AppConfig` | **minimumVersion**{**ios**, **android**} (semver 문자열) |
| `Health` | **status**(`ok`) |

설계 메모(계약 본문의 `description`에 옮겨 적습니다):
- 깊이 `explain`의 풀이 문장은 writing 슬롯이 아직 없어 이 초안에 없습니다. 생기면 `SlotText`에 필드를 더하는 하위 호환 변경으로 넣습니다. `evidence` 깊이는 `SlotText.evidence`의 원본 값입니다.
- 시진 확인(`getBirthHour`)은 엔진 RPC가 생기기 전까지 501을 돌려줍니다.
- 태그 `polarity`는 엔진 spec §7.7 표의 길흉입니다.

- [ ] **Step 5: 통과 확인** — Run: `go test ./api/...` Expected: PASS
- [ ] **Step 6: Commit** — `git commit -m "feat(server): REST API v1 계약 초안 (OpenAPI 3.1)"`

### Task 8: 계약 생성 코드와 요청 검증

**Files:**
- Create: `server/api/oapi-codegen.yaml`, `server/api/generate.go`(`//go:generate go tool oapi-codegen -config oapi-codegen.yaml openapi.yaml`), `server/internal/httpapi/gen/api.gen.go`(생성), `server/internal/httpapi/unimplemented.go`, `server/internal/httpapi/validate.go`
- Modify: `server/internal/cli/serve.go` (생성 핸들러 등록)
- Test: `server/internal/httpapi/contract_routes_test.go`

**Interfaces:**
- Consumes: `api/openapi.yaml` (Task 7), `httpapi.NewHandler`, `problem.Write` (Task 6)
- Produces:
  - 패키지 `gen`(`internal/httpapi/gen`): oapi-codegen `models`, `std-http-server`, `strict-server`, `embedded-spec` 생성물. `gen.StrictServerInterface`를 이후 계획이 구현합니다.
  - `httpapi.Unimplemented` — `gen.StrictServerInterface`의 모든 메서드가 501 `not_implemented` problem을 냅니다. 이후 계획은 이 타입을 embed한 구조체에서 메서드를 하나씩 덮어씁니다.
  - `httpapi.ValidateRequests(spec *openapi3.T) func(http.Handler) http.Handler` — `nethttp-middleware`의 요청 검증을 감싸, 실패를 400 `request.invalid`(`errors[].field`에 위반 위치), Content-Type 불일치를 415 `request.unsupported_media_type`로 냅니다. 인증 검사는 P2에서 넣으므로 이 계획에서는 `AuthenticationFunc`가 항상 통과시킵니다. 이 사실을 코드 주석으로 남깁니다.
  - `httpapi.RegisterAPI(mux *http.ServeMux, impl gen.StrictServerInterface, deps httpapi.Deps)`

- [ ] **Step 1: 생성** — Run: `cd server && go generate ./api/...` Expected: `internal/httpapi/gen/api.gen.go` 생성, `go build ./...` 성공
- [ ] **Step 2: 실패하는 테스트 작성**

```go
func TestAPI_ValidRequestReturns501(t *testing.T)           // GET /v1/me → 501 problem "not_implemented"
func TestAPI_InvalidDatePathReturns400(t *testing.T)        // GET /v1/daily/2026-13-40 → 400 "request.invalid", errors[0].field에 "date"
func TestAPI_MissingRequiredFieldReturns400(t *testing.T)   // PUT /v1/diaries/2026-10-11 본문 {} → 400, errors에 "body"
func TestAPI_WrongContentTypeReturns415(t *testing.T)       // PUT /v1/diaries/2026-10-11, Content-Type text/plain → 415
func TestAPI_NotificationTimeGranularity(t *testing.T)      // PUT /v1/me/profile, notification.time "07:03" → 400 "request.invalid"
func TestAPI_EveryOperationIsRouted(t *testing.T)           // 계약의 모든 operation에 유효한 최소 요청을 보내 404·405가 나오지 않음
```

- [ ] **Step 3: 실패 확인** — Run: `go test ./internal/httpapi/...` Expected: FAIL
- [ ] **Step 4: 구현** — `serve`는 `gen.GetSwagger()`로 계약을 읽어 `ValidateRequests`에 넘기고, `httpapi.Unimplemented{}`를 등록합니다.
- [ ] **Step 5: 통과 확인** — Expected: PASS
- [ ] **Step 6: 생성 코드 최신 확인** — Run: `go generate ./... && git diff --exit-code` Expected: 차이 없음
- [ ] **Step 7: Commit** — `git commit -m "feat(server): 계약 생성 코드, 요청 검증, 미구현 핸들러"`

### Task 9: lint, CI, 컨테이너 이미지

**Files:**
- Create: `server/.golangci.yml`, `server/Dockerfile`, `server/.dockerignore`, `.github/workflows/server.yml`

**Interfaces:**
- Produces: CI job 이름 `server`(이후 계획이 step을 더함). 이미지 진입점 `/server`, 기본 인자 `serve`.

내용:
- `.golangci.yml`(v2 형식): 기본 linter에 `errorlint`, `gosec`, `bodyclose`, `noctx`, `sqlclosecheck`, `forbidigo`(규칙: `time.Now`는 `internal/platform/clock` 밖에서 금지)를 켭니다. 생성 코드(`internal/httpapi/gen`)는 제외합니다.
- `Dockerfile`: 빌드 단계 `golang:1.27`, `CGO_ENABLED=0 go build -trimpath -o /server ./cmd/server`, 실행 단계 `gcr.io/distroless/static-debian12:nonroot`. 빌드 컨텍스트는 `server/`뿐입니다(D56④).
- `server.yml`
  - 트리거: `pull_request`와 `push`(main), 경로 필터 `server/**`, `.github/workflows/server.yml`
  - 단계: `actions/setup-go`(go-version-file `server/go.mod`) → `go vet ./...` → `golangci/golangci-lint-action`(v2) → `go test -race ./...`(ubuntu runner의 Docker로 testcontainers 실행) → `go generate ./... && git diff --exit-code` → `docker build server`

- [ ] **Step 1: 로컬 확인** — Run: `cd server && go vet ./... && golangci-lint run && go test -race ./...` Expected: 모두 통과. golangci-lint가 없으면 `brew install golangci-lint`로 설치한 뒤 실행합니다.
- [ ] **Step 2: forbidigo 규칙 확인** — `internal/httpapi`에 임시로 `_ = time.Now()`를 넣고 `golangci-lint run` → forbidigo 오류가 나는지 확인한 뒤 되돌립니다.
- [ ] **Step 3: 이미지 확인** — Run: `docker build -t myungli-server:dev server && docker run --rm -e PORT=8080 -p 8080:8080 myungli-server:dev serve & sleep 2; curl -s localhost:8080/healthz` Expected: `{"status":"ok"}`. 확인 뒤 컨테이너를 멈춥니다. (P1의 `serve`는 DB 없이도 뜹니다. DB가 필요한 핸들러가 생기는 P2에서 `RequireDatabase`를 serve에 넣습니다.)
- [ ] **Step 4: Commit** — `git commit -m "ci(server): lint·테스트·생성 코드·이미지 검사"`

### Task 10: PR과 계약 등록 요청

**Files:** 없음 (GitHub 작업)

- [ ] **Step 1: 푸시** — Run: `git push -u origin server/design`
- [ ] **Step 2: PR 생성** — 대상 `main`. 제목 `server: S1 설계와 P1 기반, REST API v1 계약 초안`. 본문에 spec·결정·계획·계약 경로와 `Closes`할 Issue가 없음을 적습니다(#3·#7·#29는 지휘 세션이 닫음). 본문 끝에 세션 attribution 줄.
- [ ] **Step 3: CI 확인** — Run: `gh pr checks --watch` Expected: `server` job과 ci-gate 통과
- [ ] **Step 4: 계약 등록 요청 Issue** — `from:server,to:root,kind:request`, 마일스톤 `S3`. 내용: REST API v1 계약 `server/api/openapi.yaml`(1.0.0-draft)과 proto 생성 코드 위치 `server/internal/gen/enginev1/`(P3에서 생성)을 `docs/contracts/README.md`에 등록 요청, freeze는 S3에서. 문장 조각 형식은 Issue #48 3번과 연결.
