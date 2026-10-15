# P3 프로필·엔진·캐시 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 프로필 세 operation(`getProfile`·`createProfile`·`updateProfile`)과 `getMe.hasProfile`이 실제로 응답하고, 출생 정보를 저장할 때 엔진(gRPC)으로 검증하며, 엔진 결과를 PostgreSQL 캐시에 `ruleset_version`별로 둡니다. 그 전에 app·writing이 요청한 계약 필드(#141·#152)를 계약만 담은 PR로 먼저 병합합니다.

**Architecture:** `internal/engine`이 gRPC 클라이언트(h2c 또는 TLS + ID token), 오류 분류, 테스트 대역, `ruleset_version` 감시를 맡습니다. `internal/fortune`이 캐시 → singleflight → 엔진 → 저장 흐름과 `ResultCache`(PostgreSQL)를 맡습니다. `internal/profile`이 호칭 정규화, 출생 정보 검증, 출생 해시, 저장을 맡고 출생 정보가 바뀔 때만 `fortune`으로 엔진 검증을 합니다. `internal/city`는 GeoNames에서 만든 도시 자료를 내장하고 id로 찾습니다. `httpapi`는 핸들러와 오류 매핑만 더합니다.

**Tech Stack:** Go 1.27, `google.golang.org/grpc`, `google.golang.org/protobuf`, buf(`go tool buf`, 생성 플러그인 `protoc-gen-go`·`protoc-gen-go-grpc`도 `go tool`), `google.golang.org/api/idtoken`, `golang.org/x/sync/singleflight`, `golang.org/x/text/unicode/norm`, testcontainers-go(이미 씀). 새 의존성은 구현 시점의 최신 안정판을 `go get`으로 넣고 `go.mod`에 고정합니다.

**Spec:** `server/docs/specs/2026-10-11-server-mvp-design.md` §3.2·§3.3(프로필·캐시), §5, §7, §11. 앞 계획 메모: `server/docs/plans/README.md` "다음 계획에 넘길 메모 > P3". 요청: #141, #152(1·2), #79(클라이언트 쪽), 호칭 규칙 `docs/identity/writing/rules/josa.yaml` `name_rules`.

## Global Constraints

- P1·P2의 Global Constraints를 모두 이어받습니다: 작업 범위는 `server/`와 `.github/workflows/server.yml`, 도구는 `go tool`로 고정, 생성 코드 commit, 업무 시각은 `Clock`으로만(SQL `now()` 금지, S17), sqlc 패키지는 도메인마다(S17), FK `ON DELETE RESTRICT`, 상태-값 짝은 CHECK(S5), problem code는 `problem/codes.go` 상수로만(S21), 커밋 꼬리말.
- **로그 금지:** 출생 정보(날짜·시각·성별·시간대·경도·도시 id), 호칭, 출생 해시, 엔진 요청·응답 본문. 계정 id와 gRPC 상태 코드는 남겨도 됩니다.
- **계약 변경은 Task 1에서만** 합니다. 다른 task는 계약에 있는 operation·필드·code만 씁니다.
- D41 지원 범위: 양력 1900-01-31 ~ 2099-12-31. 엔진 deadline 3초, `UNAVAILABLE`은 한 번만 다시 시도(시도마다 3초).
- 422 오류의 `errors[].field`는 요청 본문 기준 JSON Pointer입니다(예 `/birth/time/value`).
- PR 두 개: **PR A**는 Task 1(계약)과 이 plan 문서만 담아 먼저 병합합니다(workflow §6 "계약 먼저 병합"). Task 2는 PR A 병합 직후에 합니다. **PR B**는 Task 3~15이며 `origin/main`에서 새로 딴 `server/p3-impl` 브랜치에서 합니다.

## Review Focus

1. 엔진이 내려간 동안 `PATCH /v1/me/profile`에 `currentTimezone`(또는 호칭·알림)만 보냄 → 엔진을 부르지 않으므로 200입니다. 엔진 검증은 `birth`가 실제로 바뀔 때만 합니다. (Task 12)
2. 첫 등록 `PUT`이 두 번 동시에 옴(버튼 두 번) → 프로필 행은 하나이고 두 응답 모두 200입니다. (Task 12)
3. 음력 1900년 1월생처럼 범위에 일부만 걸친 달(Ruling P로 정정: 범위에 일부만 걸친 달 `GetMonthCalendar(1900,1)`, 출생 정보는 상한 쪽 음력) → 엔진 `OUT_OF_RANGE`가 500이 아니라 422 `birth.out_of_range`(`/birth/date`)입니다. (Task 6·12·13)
4. 엔진을 배포해 `ruleset_version`이 바뀜 → 다음 감시 주기 뒤 요청은 이전 버전 캐시를 쓰지 않고 엔진을 부릅니다. 감시 조회가 실패해도 마지막으로 안 버전을 버리지 않습니다. (Task 5·11)
5. server가 엔진보다 먼저 떠서 시작 때 `GetInfo`가 실패함 → server는 뜨고, 버전을 알기 전의 엔진 요청은 503 `engine.unavailable`(`Retry-After`)이며, 감시가 성공하면 회복합니다. (Task 5·13)

---

## PR A: 계약 `1.0.0-draft.3`

### Task 1: 계약 보강 (#141·#152, 프로필 오류 code)

브랜치: `server/profile-engine`(이미 있음). 이 task와 plan 문서를 PR A로 올립니다.

**Files:**
- Modify: `server/api/openapi.yaml`, 생성 코드 `server/internal/httpapi/gen/api.gen.go`(`go generate ./api/...`)
- Modify: `server/internal/httpapi/problem/codes.go`(새 code 2개), `server/internal/httpapi/unimplemented.go`(새 operation 2개의 501)
- Modify: `server/internal/httpapi/contract_routes_test.go`(`minimalRequests`에 새 operation)
- Modify: `server/docs/specs/2026-10-11-server-mvp-design.md` §5.2 표, §11.2 표
- Test: `server/api/contract_test.go`

**Interfaces:**
- Produces (계약, `info.version: 1.0.0-draft.3`, 모두 추가라 하위 호환):
  1. `GET /v1/me/profile` — `operationId: getProfile`, bearer. 200 `Profile`, 409 `profile.required`. 설명: "저장된 프로필을 돌려줍니다. 새 기기·재설치에서 현재 값을 받는 데 씁니다(#141)."
  2. `POST /v1/lunar-date` — `operationId: convertLunarDate`, `security: [appCheck: []]`, `getBirthHour`와 같은 비로그인 규칙(기기·IP별 분당 30회, 429 `rate_limited`). 요청 `LunarDateRequest{installationId(1~128), date: LunarOrSolarDate(음력 연·월·일), isLeapMonth: boolean}`(모두 required). 200 `LunarDate{solarDate: string(format date), monthHasLeap: boolean}`. `monthHasLeap`은 "그해 그 음력 달에 윤달이 있는지"입니다. 422: 없는 음력 날짜(윤달이 없는 달의 윤달, 그 달에 없는 30일)는 `date.invalid`(`/date` 또는 `/isLeapMonth`), D41 범위 밖은 `date.out_of_range`. 설명에 "app은 윤달 선택을 보일지 정하려고 `day: 1`, `isLeapMonth: false`로 먼저 물을 수 있습니다"를 적습니다.
  3. `City`에 `countryName: string`(required, 요청 언어의 나라 이름), `regionName: string`(선택, 1차 행정구역 이름. GeoNames에 없으면 생략) 추가. `name` 설명에 "요청 언어의 이름"을 적습니다.
  4. `Preview`에 `dayKindName: string`(required) 추가. 설명: "날의 성격 이름(writing `glossary.value_name`의 `day_kind`). 미리보기는 로그인 전이라 `getGlossary`를 쓸 수 없어 이름을 함께 싣습니다(D68②)." `Preview.fortune` 설명에 "`fortune.tag`가 IA `preview.fortune.body`입니다"를 적습니다.
  5. `Daily`와 `CalendarDay`에 `characterReason: SlotText`(required, 슬롯 `character.reason`, 키 `character.reason.<dayKind>`) 추가.
  6. `Glossary`에 `meanings`(required, object, `additionalProperties: RenderedText`) 추가. 설명: "용어 id → 뜻 문장(writing 슬롯 `term.meaning`, 키 `term.<용어 id>`)".
  7. `Segment.term` 설명을 "이 조각이 용어면 그 **용어 id**(`<범주>.<값>` 또는 `tag.<키>`, 호칭·조사 처리 규칙 v1.1). `Glossary.values`·`meanings`를 찾는 키입니다"로 바꿉니다.
  8. `SlotText` 설명의 "깊이 `explain`의 풀이 문장은 … 없습니다"를 "깊이 explain의 오늘 풀이(`explain.today_reason`)와 근거 문장(`evidence.basis`·`evidence.source`)은 core 근거 목록(#130)이 정해지면 필드로 더합니다"로 바꿉니다.
  9. 새 problem code 2개(`x-problem-codes`와 `UnprocessableEntity` 설명에 추가): `timezone.invalid`(422, "IANA 시간대 이름이 아님. `errors[].field`는 `/currentTimezone` 또는 `/birth/timezone`"), `city.not_found`(422, "`cityId`가 도시 목록에 없음. `errors[].field`는 `/birth/place/cityId`"). `createProfile`·`updateProfile` 설명에 두 code를 적습니다.
- Produces (Go): `problem.TimezoneInvalid = Code{"timezone.invalid", 422}`, `problem.CityNotFound = Code{"city.not_found", 422}`(`AllCodes`에도 추가). `Unimplemented.GetProfile`, `Unimplemented.ConvertLunarDate`는 `ErrNotImplemented`.

- [ ] **Step 1: 실패하는 테스트 작성** (`contract_test.go`)

```go
func TestContract_VersionIsDraft3(t *testing.T)               // info.version == "1.0.0-draft.3" (기존 TestContract_VersionIsDraft2를 바꿈)
func TestContract_GetProfileExists(t *testing.T)              // GET /v1/me/profile operationId getProfile, 200 schema $ref Profile, "409" 응답 있음, bearer
func TestContract_ConvertLunarDateIsAppCheck(t *testing.T)    // POST /v1/lunar-date, security == [{appCheck: []}], 200 LunarDate required [solarDate, monthHasLeap], "422"·"429" 응답 있음
func TestContract_DisplayFieldsRequired(t *testing.T)         // City.required ⊇ countryName, Preview.required ⊇ dayKindName, Daily·CalendarDay.required ⊇ characterReason, Glossary.required ⊇ meanings
func TestContract_ProfileProblemCodes(t *testing.T)           // x-problem-codes에 timezone.invalid·city.not_found가 status 422로 있음
```

`TestContract_OperationIDs`의 목록에 `getProfile`, `convertLunarDate`를 더합니다.

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./api/...` Expected: FAIL(위 5건, OperationIDs)
- [ ] **Step 3: `openapi.yaml`을 위 내용대로 고치고 `go generate ./api/...`, `codes.go`·`unimplemented.go`·`minimalRequests`를 맞추고, spec §5.2(프로필 행에 `GET`, 비로그인 행에 `POST /v1/lunar-date`), §11.2(두 code 행) 갱신**
- [ ] **Step 4: 통과 확인** — Run: `cd server && go test ./... && go vet ./...` Expected: PASS(problem code 대조 테스트 포함)
- [ ] **Step 5: Commit 후 PR A**

```bash
git add server/api server/internal/httpapi server/docs
git commit -m "feat(server): 계약 1.0.0-draft.3 — 프로필 읽기, 음력 변환, 표시용 이름·문장 필드 (#141, #152)"
git push -u origin server/profile-engine
```

PR 본문: `Closes #152`가 아니라 `참고 #141`, `참고 #152`(일부 처리). `ci-gate` 통과 뒤 병합합니다.

### Task 2: 요청함 정리 (PR A 병합 직후)

**Files:** 없음(GitHub Issues만). 본문 파일은 scratchpad에 씁니다.

- [ ] **Step 1: core에 RPC 요청** — `gh issue create --label from:server,to:core,kind:request --milestone S2`. 제목 `[server→core] 음력 날짜 → 양력 변환과 윤달 유무 RPC (#141)`. 본문: 필요한 것 `rpc ConvertLunarDate(LunarDateRequest) returns (LunarDateResponse)`, `LunarDateRequest{LocalDate date; bool is_leap_month}`, `LunarDateResponse{LocalDate solar; bool month_has_leap; ResponseMeta meta}`, 없는 날짜는 `INVALID_ARGUMENT`, D41 범위 밖은 `OUT_OF_RANGE`(GetChart와 같은 KASI 음력 표, D41). 왜: app date-picker의 양력 확인 줄과 윤달 선택(D41, app은 음력을 계산하지 않음). 영향: server `convertLunarDate`가 이 RPC를 기다림. 관련 #141, 계약 `1.0.0-draft.3`.
- [ ] **Step 2: app에 계약 변경 알림** — `from:server,to:app,kind:request`. 제목 `[server→app] 계약 1.0.0-draft.3: getProfile, convertLunarDate, City·Preview·Daily·CalendarDay·Glossary 표시 필드`. 본문에 Task 1의 1~9를 한 줄씩, 구현 시점(getProfile: P3 PR B, convertLunarDate: core RPC 뒤, City·Preview: P6, Daily·CalendarDay·Glossary 문장: P4), GeoNames(CC BY 4.0) 출처 표기를 오픈소스 고지에 넣어 달라는 요청을 적습니다.
- [ ] **Step 3: root에 계약 목록 버전 갱신 요청** — `from:server,to:root,kind:request`. `docs/contracts/README.md`의 REST API v1 버전을 `1.0.0-draft.3`으로.
- [ ] **Step 4: 받은 요청 닫기와 나누기** (workflow §5.2 "일부만 처리")
  * #152: 1·2를 계약에 넣었다는 코멘트로 닫고, 3·4(`explain.today_reason`, 근거 `basis`·`source`)는 새 Issue `from:server,to:server,kind:task`로 엽니다("core #130 뒤 계약에 추가"). 새 번호를 닫는 코멘트에 남깁니다.
  * #141은 PR B에서 처리합니다(1번 구현). 이 단계에서는 코멘트로 2~4의 계약 반영과 3번의 core 요청 번호만 남깁니다.

---

## PR B: 구현

시작: `cd ../myungli-diary-server && git fetch origin && git switch -c server/p3-impl --no-track origin/main && git push -u origin server/p3-impl && git status -sb`

### Task 3: proto 생성 (buf)

**Files:**
- Create: `server/buf.gen.yaml`, `server/internal/gen/enginev1/generate.go`, 생성 코드 `server/internal/gen/enginev1/engine.pb.go`·`engine_grpc.pb.go`
- Modify: `server/go.mod`(tool: `github.com/bufbuild/buf/cmd/buf`, `google.golang.org/protobuf/cmd/protoc-gen-go`, `google.golang.org/grpc/cmd/protoc-gen-go-grpc`)
- Test: `server/internal/gen/enginev1/enginev1_test.go`

**Interfaces:**
- Produces: Go 패키지 `github.com/june20516/myungli-diary/server/internal/gen/enginev1`(`enginev1.MyungliEngineClient`, `enginev1.NewMyungliEngineClient`, 메시지 타입).

buf v2 managed mode로 `go_package`를 `github.com/june20516/myungli-diary/server/internal/gen/enginev1`로 덮어쓰고, 입력은 `directory: ../proto`, 플러그인은 `local: [go, tool, protoc-gen-go]`처럼 `go tool`로 부릅니다. `generate.go`는 `//go:generate go tool buf generate --template ../../../buf.gen.yaml`처럼 server 루트 기준으로 실행되게 합니다(경로는 구현자가 맞추되 출력은 `internal/gen/enginev1/`).

- [ ] **Step 1: 테스트 작성** — `TestEngineServiceDescriptor`: `enginev1.MyungliEngine_ServiceDesc.ServiceName == "myungli.engine.v1.MyungliEngine"`이고 메서드 이름 집합이 `{GetChart, GetDaily, GetMonthCalendar, GetBirthHour, GetInfo}`.
- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/gen/...` Expected: FAIL(패키지 없음)
- [ ] **Step 3: 도구 추가, `buf.gen.yaml`·`generate.go` 작성, `go generate ./internal/gen/...`**
- [ ] **Step 4: 통과 확인** — Run: `cd server && go test ./internal/gen/... && go generate ./... && git status --porcelain` Expected: PASS, 두 번째 생성 뒤 차이 없음
- [ ] **Step 5: Commit** — `feat(server): 엔진 proto Go 생성 (buf managed mode)`

### Task 4: 엔진 클라이언트와 테스트 대역

**Files:**
- Create: `server/internal/engine/engine.go`(인터페이스·오류), `server/internal/engine/client.go`(gRPC 구현), `server/internal/engine/enginetest/fake.go`(대역)
- Modify: `server/internal/platform/config/config.go`(엔진 설정)
- Test: `server/internal/engine/client_test.go`(bufconn 서버), `server/internal/platform/config/config_test.go`

**Interfaces:**
- Produces:

```go
package engine

// Engine은 server가 쓰는 엔진 RPC입니다. 요청·응답은 proto 타입 그대로입니다(계약이 proto).
type Engine interface {
	GetChart(ctx context.Context, req *enginev1.ChartRequest) (*enginev1.ChartResponse, error)
	GetDaily(ctx context.Context, req *enginev1.DailyRequest) (*enginev1.DailyResponse, error)
	GetMonthCalendar(ctx context.Context, req *enginev1.MonthRequest) (*enginev1.MonthResponse, error)
	GetBirthHour(ctx context.Context, req *enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error)
	GetInfo(ctx context.Context) (*enginev1.InfoResponse, error)
}

var (
	ErrUnavailable     = errors.New("engine unavailable")      // UNAVAILABLE(재시도 뒤), 연결 실패
	ErrTimeout         = errors.New("engine timeout")          // DEADLINE_EXCEEDED
	ErrInternal        = errors.New("engine internal error")   // INTERNAL, 그 밖의 상태
	ErrInvalidArgument = errors.New("engine invalid argument") // INVALID_ARGUMENT
	ErrOutOfRange      = errors.New("engine out of range")     // OUT_OF_RANGE
)

type ClientConfig struct {
	Addr     string // host:port
	Audience string // 비어 있으면 h2c(로컬). 있으면 TLS(시스템 루트) + 이 audience의 Google ID token
}

func NewClient(cfg ClientConfig, opts ...grpc.DialOption) (*Client, error) // grpc.NewClient. opts는 테스트의 bufconn dialer용
func (c *Client) Close() error
```

- `enginetest.Fake`: 메서드마다 응답·오류를 넣는 필드(`Chart func(*enginev1.ChartRequest) (*enginev1.ChartResponse, error)` 등)와 호출 횟수(`atomic.Int64`), `Info` 기본값 `{engine_version: "test", ruleset_version: "rs-1"}`.
- config: `config.LoadEngine(getenv) (EngineConfig, error)`, `EngineConfig{Addr, Audience string}`. `ENGINE_ADDR`는 필수(없으면 `"ENGINE_ADDR가 필요합니다"` 오류), `ENGINE_AUDIENCE`는 선택이며 있으면 https URL이어야 합니다.

호출마다 3초 deadline을 걸고, `UNAVAILABLE`이면 한 번 더 부릅니다(새 3초). 오류 문구에는 요청 값을 넣지 않습니다. `status.Code`로 분류해 위 sentinel로 감싸고(`fmt.Errorf("엔진 GetChart: %w", ErrX)`), 원래 gRPC 상태는 오류 체인에 남기지 않습니다(상세 메시지에 입력이 담길 수 있음). ID token은 `idtoken.NewTokenSource(ctx, audience)`를 `grpc.WithPerRPCCredentials`(oauth 어댑터)로 붙입니다.

- [ ] **Step 1: 실패하는 테스트 작성** (bufconn에 가짜 `MyungliEngineServer`를 띄움)

```go
func TestClient_MapsStatusToSentinel(t *testing.T)     // table: InvalidArgument→ErrInvalidArgument, OutOfRange→ErrOutOfRange, Internal→ErrInternal, DeadlineExceeded→ErrTimeout, Unavailable(두 번)→ErrUnavailable, Unknown→ErrInternal
func TestClient_RetriesUnavailableOnce(t *testing.T)   // 첫 호출 Unavailable, 둘째 성공 → 성공, 서버 호출 2회
func TestClient_DoesNotRetryOtherCodes(t *testing.T)   // Internal → 서버 호출 1회
func TestClient_AppliesDeadline(t *testing.T)          // 서버가 ctx.Deadline()을 받았고 남은 시간 ≤ 3초
func TestClient_ErrorTextHasNoStatusMessage(t *testing.T) // 서버가 status.Error(InvalidArgument, "1990-01-01")를 돌려줘도 err.Error()에 "1990" 없음
func TestLoadEngine(t *testing.T)                      // ENGINE_ADDR 없음 → 오류, ENGINE_AUDIENCE "http://x" → 오류, 정상 값 → 그대로
```

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/engine/... ./internal/platform/config/...` Expected: FAIL
- [ ] **Step 3: 구현** (`engine.go`, `client.go`, `enginetest/fake.go`, `config.LoadEngine`)
- [ ] **Step 4: 통과 확인** — 같은 명령, Expected: PASS
- [ ] **Step 5: Commit** — `feat(server): 엔진 gRPC 클라이언트, 오류 분류, 테스트 대역`

### Task 5: `ruleset_version` 감시

**Files:**
- Create: `server/internal/engine/versions.go`
- Test: `server/internal/engine/versions_test.go`

**Interfaces:**
- Consumes: `engine.Engine.GetInfo`
- Produces:

```go
var ErrVersionUnknown = errors.New("engine ruleset version unknown") // 아직 한 번도 받지 못함

type Versions struct{ /* engine, logger, 마지막 값(sync.RWMutex 또는 atomic.Pointer) */ }
func NewVersions(e Engine, logger *slog.Logger) *Versions
func (v *Versions) Refresh(ctx context.Context) error   // GetInfo 한 번. 실패하면 이전 값을 유지하고 오류만 돌려줌
func (v *Versions) Current() (string, error)            // 마지막 ruleset_version, 없으면 ErrVersionUnknown
func (v *Versions) Run(ctx context.Context, interval time.Duration) // 바로 Refresh, 그 뒤 interval마다. ctx 취소로 끝. 실패는 Warn 로그
```

`serve`는 `interval = 10 * time.Minute`로 `Run`을 goroutine에서 돌립니다(Task 13). `Run`의 주기는 실제 시간(`time.Ticker`)이며 테스트는 `Refresh`를 직접 부릅니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestVersions_UnknownBeforeFirstRefresh(t *testing.T) // Current → ErrVersionUnknown
func TestVersions_RefreshUpdates(t *testing.T)            // Fake Info rs-1 → Refresh → "rs-1"; Info rs-2 → Refresh → "rs-2"
func TestVersions_FailureKeepsLastValue(t *testing.T)     // rs-1 받은 뒤 GetInfo 오류 → Refresh 오류, Current 여전히 "rs-1"
func TestVersions_RunStopsOnCancel(t *testing.T)          // ctx 취소 뒤 Run이 반환, 첫 Refresh는 Run 시작 즉시 일어남(Fake 호출 1회 이상)
```

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/engine/...` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Expected: PASS(`-race` 포함)
- [ ] **Step 5: Commit** — `feat(server): 엔진 ruleset_version 감시 (spec §7.1)`

### Task 6: 실제 엔진 계약 테스트와 로컬 실행 (#79 클라이언트 쪽)

**Files:**
- Create: `server/internal/engine/contract_test.go`(`//go:build enginecontract`)
- Modify: `server/compose.yaml`(엔진 서비스), `.github/workflows/server.yml`(계약 테스트 step)

**Interfaces:**
- Consumes: `engine.NewClient`, `enginev1` 타입

testcontainers-go `FromDockerfile{Context: "../../../core"}`로 엔진 이미지를 빌드해 띄우고(`PORT=50051`), `grpc.health.v1.Health/Check`(서비스 `myungli.engine.v1.MyungliEngine`)가 `SERVING`이 될 때까지 기다립니다. compose에는 `engine` 서비스(`build: ../core`, `ports: "50051:50051"`, gRPC health 검사)를 더하고 주석에 "로컬 `ENGINE_ADDR=localhost:50051`"을 적습니다. CI에는 `go test -race ./...` 다음에 `go test -tags enginecontract ./internal/engine/...` step을 둡니다(이름 "실제 엔진과 계약 테스트").

- [ ] **Step 1: 테스트 작성**

```go
func TestRealEngine_GetInfo(t *testing.T)            // engine_version·ruleset_version이 비어 있지 않음
func TestRealEngine_GetChartSolar(t *testing.T)      // 양력 1990-05-15 10:30 남 Asia/Seoul, as_of 2026-10-15 → pillars.day 있음, meta.ruleset_version == GetInfo 값
func TestRealEngine_LunarLeapMissingIsInvalid(t *testing.T) // 음력 2026-01-01 is_leap_month true(2026년 1월 윤달 없음) → ErrInvalidArgument
func TestRealEngine_PartialRangeMonthIsOutOfRange(t *testing.T) // 음력 1900-01-01 → ErrOutOfRange (Ruling P로 정정: 범위에 일부만 걸친 달 `GetMonthCalendar(1900,1)`, 출생 정보는 상한 쪽 음력) (plans/README P3 메모)
```

- [ ] **Step 2: 실행** — Run: `cd server && go test -tags enginecontract ./internal/engine/...` Expected: PASS(엔진 판정이 다르면 core 동작을 확인하고 테스트 값이 아니라 server 가정을 고칩니다)
- [ ] **Step 3: compose·CI 수정 후 `docker compose up -d engine`으로 로컬 기동 확인**
- [ ] **Step 4: Commit** — `test(server): 실제 엔진 컨테이너 계약 테스트, compose 엔진 서비스 (#79)`

### Task 7: 프로필·캐시 migration과 sqlc

**Files:**
- Create: `server/db/migrations/00004_profiles_caches.sql`, `server/db/queries/profile.sql`, `server/db/queries/cache.sql`, 생성 `server/internal/profile/profiledb/*`, `server/internal/fortune/cachedb/*`
- Modify: `server/db/sqlc.yaml`(두 패키지, `*overrides`), `server/db/generate.go` 주석
- Test: `server/db/migrations_test.go`가 있으면 거기에, 없으면 `server/internal/profile/profiledb/constraints_test.go`

**Interfaces:**
- Produces (테이블):
  * `profiles`: `account_id uuid PK REFERENCES accounts ON DELETE RESTRICT`, `honorific text`, `language text CHECK IN ('ko','en','ja')`, `current_timezone text`, `calendar text CHECK IN ('solar','lunar')`, `is_leap_month boolean`, `birth_year smallint CHECK 1900~2099`·`birth_month smallint CHECK 1~12`·`birth_day smallint CHECK 1~31`(음력 30일이 `date`에 들어가지 않으므로 정수 셋), `birth_time_status text CHECK IN ('known','unknown')`, `birth_time time`, `gender text CHECK IN ('male','female')`, `birth_timezone text`, `birth_place_status text CHECK IN ('not_asked','skipped','city')`, `birth_city_id text`, `longitude double precision`, `notify_status text CHECK IN ('not_asked','enabled','disabled')`, `notify_time time`, `birth_hash bytea CHECK (octet_length = 32)`, `anonymized_at timestamptz`, `created_at`, `updated_at`(트리거 `set_updated_at`).
  * CHECK(S5): `birth_time_status='known'` ⇔ `birth_time IS NOT NULL`; `birth_place_status='city'` ⇔ (`birth_city_id`, `longitude`) 모두 NOT NULL, 아니면 모두 NULL; `calendar='solar'` ⇒ `NOT is_leap_month`; `notify_status='enabled'` ⇔ `notify_time IS NOT NULL`; `notify_time`의 분은 5의 배수·초 0; `anonymized_at IS NULL` ⇒ 출생 열 전체와 `honorific`·`birth_hash` NOT NULL.
  * `chart_cache(birth_hash bytea, ruleset_version text, as_of_year int, response bytea, created_at)`, PK 앞 셋. `daily_cache(birth_hash, ruleset_version, date date, current_timezone text, response, created_at)`, PK 앞 넷. `month_cache(birth_hash, ruleset_version, year int, month int, current_timezone, response, created_at)`, PK 앞 다섯. 계정 FK 없음(spec §3.3).
- Produces (쿼리): `profiledb`: `GetProfile(account_id)`, `ProfileExists(account_id) bool`, `UpsertProfile(전체 열) RETURNING *`(`ON CONFLICT (account_id) DO UPDATE`), `cachedb`: `GetChart/PutChart`, `GetDaily/PutDaily`, `GetMonth/PutMonth`(Put은 `ON CONFLICT DO NOTHING`).

> spec §3.3은 `birth_date`라고 적었지만 음력 30일 때문에 정수 셋으로 둡니다. Task 15에서 spec을 고칩니다.

- [ ] **Step 1: 실패하는 테스트 작성** (`dbtest.New`)

```go
func TestProfiles_RejectsTimeStatusMismatch(t *testing.T)  // known + birth_time NULL → CHECK 위반(23514)
func TestProfiles_RejectsCityWithoutLongitude(t *testing.T) // city + longitude NULL → 23514; skipped + city_id 있음 → 23514
func TestProfiles_RejectsSolarLeap(t *testing.T)           // solar + is_leap_month true → 23514
func TestProfiles_RejectsNotifyMinuteNotMultipleOf5(t *testing.T) // enabled 07:03 → 23514
func TestProfiles_UpsertKeepsOneRow(t *testing.T)           // 같은 account로 두 번 Upsert → 행 1개, 두 번째 값
func TestCache_PutIsIdempotent(t *testing.T)                // 같은 키 PutDaily 두 번 → 오류 없음, Get은 첫 값
```

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/profile/... ./internal/fortune/...` Expected: FAIL
- [ ] **Step 3: migration·쿼리 작성, `go generate ./db/...`, up → down → up 확인**(`go tool goose`로 로컬 compose DB에)
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `feat(server): profiles·엔진 결과 캐시 테이블과 쿼리`

### Task 8: 호칭 정규화 (`name_rules`)

**Files:**
- Create: `server/internal/profile/honorific/honorific.go`, `server/internal/profile/honorific/emoji_table.go`(생성), `server/internal/profile/honorific/gen/main.go`(표 생성기), `server/internal/profile/honorific/testdata/emoji-data.txt`(Unicode 16.0.0 원본, 생성기 입력)
- Test: `server/internal/profile/honorific/honorific_test.go`

**Interfaces:**
- Produces:

```go
package honorific

// Code는 거부 사유와 경고입니다. 0은 "없음"입니다.
type Code int
const (
	None Code = iota
	Empty; TooLong; Emoji; Control; InvalidChar // 거부
	SuffixStripped; SuffixWarning               // 경고
)

type Result struct {
	Value    string // 거부면 ""
	Rejected Code   // 거부 사유, 통과면 None
	Warnings []Code // 통과일 때의 경고(순서: SuffixStripped, SuffixWarning)
}

func Normalize(lang string, raw string) Result
```

> `Code`를 문자열(`"name.empty"` 등)로 두지 않습니다. S21 테스트(`problem_codes_test.go`)가 `internal/` 어디서든 등록된 code와 같은 문자열 리터럴을 막기 때문입니다. httpapi가 `Code` → `problem.Name*` 표 하나로 바꿉니다. `josa.yaml` 예시의 code 문자열과 비교하는 테스트는 `honorific_test.go` 안에 `map[string]Code` 표를 둡니다(리터럴 검사는 `_test.go`를 보지 않습니다).

규칙은 기준 구현 `mlw/josa.py`의 `normalize_name`과 같은 순서입니다: NFC → 앞뒤 공백 제거 → 제어 문자(Cc) → 이모지(Extended_Pictographic, Regional_Indicator, U+200D, U+FE0F, U+20E3) → 금지 글자 `{ } [ ] ( )` → ko `님`을 끝에서 반복해 떼고 `TrimRightFunc(unicode.IsSpace)` → 비면 Empty → 글자 수(rune) 초과(ko 10, ja 10, en 20) → ja `さん`·`様`·`ちゃん`로 끝나면 경고. 규칙 값(길이, 접미사, 금지 글자)은 Go 상수로 두고, 테스트가 `josa.yaml`과 같은지 확인합니다. 생성기는 `emoji-data.txt`의 `Extended_Pictographic` 줄을 `*unicode.RangeTable`로 씁니다(`//go:generate go run ./gen`).

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestNormalize_MatchesJosaYAMLExamples(t *testing.T) // ../../../../docs/identity/writing/rules/josa.yaml의 name_rules.examples 6건을 읽어 value·codes 일치(value null ↔ Rejected != "")
func TestRulesMatchJosaYAML(t *testing.T)                // max_length·strip_suffix·warn_suffix·forbidden_chars가 josa.yaml과 같음
func TestNormalize_RepeatedSuffixStripped(t *testing.T)  // ko "민지님님" → "민지", [SuffixStripped]; ko "님" → Empty
func TestNormalize_Emoji(t *testing.T)                   // "민지😀" → Emoji; "🇰🇷" → Emoji; "1️⃣" → Emoji
func TestNormalize_CountsRunesNotBytes(t *testing.T)     // ko 한글 10자 통과, 11자 TooLong; en 20자 통과
func TestNormalize_ControlChar(t *testing.T)             // "민\u0007지" → Control
```

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/profile/honorific/...` Expected: FAIL
- [ ] **Step 3: 생성기·표·`Normalize` 구현, `go generate ./internal/profile/honorific/...`**
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `feat(server): 호칭 정규화 (josa.yaml name_rules 기준 구현과 같은 규칙)`

### Task 9: 도시 자료 (GeoNames)

**Files:**
- Create: `server/internal/city/city.go`, `server/internal/city/data/cities.json.gz`(생성 결과, commit), `server/internal/city/cmd/build/main.go`(자료 생성기), `server/internal/city/README.md`(생성 방법·출처·라이선스)
- Test: `server/internal/city/city_test.go`

**Interfaces:**
- Produces:

```go
package city

type City struct {
	ID          string            // GeoNames geonameid
	Names       map[string]string // "ko"·"en"·"ja" → 이름 (세 언어 모두 채움)
	Country     string            // ISO 3166-1 alpha-2
	CountryName map[string]string // 세 언어 모두 채움
	RegionName  map[string]string // 1차 행정구역 이름, 없으면 nil
	Timezone    string            // IANA
	Longitude   float64
}

func Lookup(id string) (City, bool)
func DataVersion() string // 내장 파일 SHA-256 앞 12 hex
func All() []City         // P6 listCities 검색용, 이름(en) 순
```

생성기 입력(다운로드는 생성기가 하지 않고 인자로 경로를 받음, README에 받는 곳을 적음): `cities15000.zip`, `countryInfo.txt`, `admin1CodesASCII.txt`, `alternateNamesV2.zip`. 언어별 이름은 `alternateNamesV2`의 `isolanguage`가 그 언어이고 `isHistoric`·`isColloquial`이 아닌 것 중 `isPreferredName` 우선, 그다음 `isShortName`이 아닌 첫 값입니다. 없으면 en, en도 없으면 GeoNames `name`입니다. 출력은 gzip JSON이며 `go:embed`로 넣고 `init`이 아니라 처음 쓸 때 `sync.OnceValues`로 풉니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestLookup_Seoul(t *testing.T)        // "1835848" → Country "KR", Timezone "Asia/Seoul", Names["ko"] == "서울", 126 < Longitude < 128
func TestLookup_Tokyo(t *testing.T)        // "1850147" → Names["ja"] == "東京", CountryName["ja"] == "日本"
func TestLookup_Unknown(t *testing.T)      // "0" → false
func TestAll_EveryCityHasThreeNames(t *testing.T) // 모든 도시의 Names·CountryName에 ko·en·ja가 비어 있지 않음, Timezone이 time.LoadLocation 성공, -180 ≤ Longitude ≤ 180
func TestEmbeddedSizeUnder4MiB(t *testing.T)
```

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/city/...` Expected: FAIL
- [ ] **Step 3: 생성기 작성, 자료를 받아 생성(`go run ./internal/city/cmd/build -cities … -countries … -admin1 … -alternates … -out internal/city/data/cities.json.gz`), `city.go` 구현**
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `feat(server): GeoNames 도시 자료 내장과 id 조회`

### Task 10: 출생 정보 검증과 출생 해시

**Files:**
- Create: `server/internal/profile/profile.go`(도메인 타입), `server/internal/profile/validate.go`, `server/internal/profile/birthhash.go`
- Test: `server/internal/profile/validate_test.go`, `server/internal/profile/birthhash_test.go`

**Interfaces:**
- Consumes: `city.Lookup`, `honorific.Normalize`
- Produces:

```go
package profile

type Calendar string   // "solar" | "lunar"
type TimeStatus string // "known" | "unknown"
type PlaceStatus string // "not_asked" | "skipped" | "city"
type NotifyStatus string // "not_asked" | "enabled" | "disabled"

type LocalDate struct{ Year, Month, Day int }
type LocalTime struct{ Hour, Minute int }

type Birth struct {
	Calendar    Calendar
	IsLeapMonth bool
	Date        LocalDate
	TimeStatus  TimeStatus
	Time        *LocalTime // TimeStatus known일 때만
	Gender      string     // "male" | "female"
	Timezone    string
	PlaceStatus PlaceStatus
	CityID      string   // PlaceStatus city일 때만
	Longitude   *float64 // city일 때 도시 경도로 채움(입력에는 없음)
}

type Notification struct {
	Status NotifyStatus
	Time   *LocalTime // enabled일 때만
}

type Profile struct {
	Honorific       string
	Language        string
	CurrentTimezone string
	Birth           Birth
	Notification    Notification
}

// Violation은 422 의미 검사 위반의 종류입니다. httpapi가 problem code로 바꿉니다(문자열로 두지 않는 이유는 Task 8 참고).
type Violation int
const (
	DateInvalid Violation = iota + 1
	BirthOutOfRange; Inconsistent; TimezoneInvalid; CityNotFound; BirthInvalid
	HonorificRejected // 사유는 ValidationError.Honorific
)

// StatusRule은 Inconsistent의 세부입니다.
type StatusRule int
const (
	NoStatusRule StatusRule = iota
	RequiredByStatus  // 응답 errors[].code "required_by_status"
	ForbiddenByStatus // "forbidden_by_status"
)

type FieldViolation struct {
	Field string     // JSON Pointer
	Rule  StatusRule // Inconsistent일 때만. 그 밖의 errors[].code는 httpapi가 Violation의 problem code로 채움
}

type ValidationError struct {
	Violation Violation      // 첫 위반의 종류
	Honorific honorific.Code // Violation이 HonorificRejected일 때만
	Fields    []FieldViolation
}
func (e *ValidationError) Error() string // 종류와 field만, 값 없음

// ValidateBirth는 엔진을 부르기 전에 server가 하는 검사입니다(spec §7.2). city면 Longitude를 채운 Birth를 돌려줍니다.
func ValidateBirth(b Birth, pointer string) (Birth, error) // pointer는 "/birth"
func ValidateTimezone(name, pointer string) error
func ValidateNotification(n Notification, pointer string) error // pointer "/notification"
func BirthHash(b Birth) [32]byte
```

검사 순서(먼저 걸린 하나만 돌려줌): 상태-값 짝(`/birth/time/value`, `/birth/place/cityId`, `/birth/isLeapMonth` — 양력인데 true면 `forbidden_by_status`) → 양력이면 달력에 있는 날짜인지(`/birth/date`, `DateInvalid`) → 양력이면 D41 범위(`/birth/date`, `BirthOutOfRange`) → 시간대(`/birth/timezone`, `time.LoadLocation`, 빈 문자열과 `"Local"`도 거부) → 도시(`/birth/place/cityId`, `CityNotFound`). 음력의 날짜 존재·범위는 엔진 판정입니다.

`BirthHash` 정규형(S23 사주 지문과 같은 값, 버전 접두어로 바꿀 여지를 남김): `"v1|" + calendar + "|" + leap("1"/"0") + "|" + fmt.Sprintf("%04d-%02d-%02d") + "|" + (known면 "%02d:%02d", 아니면 "-") + "|" + gender + "|" + timezone + "|" + (경도 있으면 strconv.FormatFloat(lon, 'f', -1, 64), 없으면 "-")`의 SHA-256. 호칭·현재 시간대·도시 id는 넣지 않습니다(경도로 충분).

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestValidateBirth_StatusPairs(t *testing.T)   // table: known 시각 없음 → Inconsistent /birth/time/value RequiredByStatus; unknown 시각 있음 → ForbiddenByStatus; city id 없음 → /birth/place/cityId RequiredByStatus; skipped id 있음 → ForbiddenByStatus; solar leap → /birth/isLeapMonth ForbiddenByStatus
func TestValidateBirth_SolarDateExists(t *testing.T) // 2023-02-29 → DateInvalid /birth/date; 2024-02-29 통과; 2026-04-31 → DateInvalid
func TestValidateBirth_D41Range(t *testing.T)      // 1900-01-30 → BirthOutOfRange; 1900-01-31 통과; 2099-12-31 통과
func TestValidateBirth_LunarSkipsCalendarChecks(t *testing.T) // lunar 1990-02-30 통과(엔진 판정)
func TestValidateBirth_Timezone(t *testing.T)      // "Asia/Seoul" 통과; "Mars/Base"·""·"Local" → TimezoneInvalid /birth/timezone
func TestValidateBirth_CityFillsLongitude(t *testing.T) // city "1850147" → Longitude ≈ 139.69; "0" → CityNotFound
func TestValidateNotification(t *testing.T)        // enabled 시각 없음 → /notification/time RequiredByStatus; disabled 시각 있음 → ForbiddenByStatus
func TestBirthHash_StableAndSensitive(t *testing.T) // 같은 입력 같은 해시; 고정 입력의 hex를 golden 값으로 고정; 성별·윤달·경도 하나만 바뀌어도 다름; 도시 id만 다르고 경도가 같으면 같음
```

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/profile/...` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `feat(server): 출생 정보 검증(S5 짝, D41, 시간대, 도시)과 출생 해시`

### Task 11: 엔진 결과 캐시와 조회 흐름

**Files:**
- Create: `server/internal/fortune/cache.go`(`ResultCache`, PostgreSQL 구현), `server/internal/fortune/service.go`, `server/internal/fortune/birthinfo.go`(`profile.Birth` → `enginev1.BirthInfo`)
- Test: `server/internal/fortune/service_test.go`, `server/internal/fortune/cache_test.go`

**Interfaces:**
- Consumes: `engine.Engine`, `*engine.Versions`(아래 `VersionSource`로), `cachedb`, `profile.Birth`, `profile.BirthHash`
- Produces:

```go
package fortune

type VersionSource interface{ Current() (string, error) } // *engine.Versions가 만족

type ChartKey struct{ BirthHash [32]byte; Ruleset string; AsOfYear int }
type DailyKey struct{ BirthHash [32]byte; Ruleset string; Date profile.LocalDate; CurrentTimezone string }
type MonthKey struct{ BirthHash [32]byte; Ruleset string; Year, Month int; CurrentTimezone string }

// ResultCache는 엔진 응답 protobuf bytes를 담습니다(S4). 없으면 (nil, false, nil).
type ResultCache interface {
	GetChart(ctx context.Context, k ChartKey) ([]byte, bool, error)
	PutChart(ctx context.Context, k ChartKey, response []byte) error
	GetDaily(ctx context.Context, k DailyKey) ([]byte, bool, error)
	PutDaily(ctx context.Context, k DailyKey, response []byte) error
	GetMonth(ctx context.Context, k MonthKey) ([]byte, bool, error)
	PutMonth(ctx context.Context, k MonthKey, response []byte) error
}
func NewPostgresCache(pool *pgxpool.Pool) ResultCache

type Service struct{ /* engine, versions, cache, singleflight.Group, logger */ }
func NewService(e engine.Engine, v VersionSource, c ResultCache, logger *slog.Logger) *Service
func (s *Service) Chart(ctx context.Context, b profile.Birth, asOf profile.LocalDate) (*enginev1.ChartResponse, error)
func (s *Service) Daily(ctx context.Context, b profile.Birth, date profile.LocalDate, currentTimezone string) (*enginev1.DailyResponse, error)
func (s *Service) Month(ctx context.Context, b profile.Birth, year, month int, currentTimezone string) (*enginev1.MonthResponse, error)
```

흐름(세 메서드 같음): `versions.Current()`(실패 `ErrVersionUnknown`이면 `engine.ErrUnavailable`로 감싸 돌려줌) → 캐시 조회(있으면 `proto.Unmarshal`) → 없으면 `singleflight` 키(종류 + hex 해시 + 나머지 키)로 엔진 호출 → 응답의 `meta.ruleset_version`을 키로 `proto.Marshal(Deterministic)` 저장. 캐시 읽기·쓰기 오류는 Warn 로그만 남기고 엔진 결과로 계속합니다(캐시는 정확성에 필요하지 않음). singleflight는 첫 호출자의 ctx 취소가 다른 호출자에게 번지지 않게 `context.WithoutCancel` + 엔진 deadline으로 부릅니다.

- [ ] **Step 1: 실패하는 테스트 작성** (`enginetest.Fake`, `dbtest.New`)

```go
func TestService_ChartMissCallsEngineThenCaches(t *testing.T)   // 첫 호출 엔진 1회, 둘째 호출 엔진 0회 추가, 응답 동일(proto.Equal)
func TestService_RulesetChangeMissesOldCache(t *testing.T)      // rs-1로 캐시 → Fake Info/meta rs-2, Versions.Refresh → 다시 엔진 호출
func TestService_ConcurrentSameKeyCallsEngineOnce(t *testing.T) // 10 goroutine 동시 Daily(같은 키), Fake가 느리게 응답 → 엔진 호출 1회
func TestService_UnknownVersionIsUnavailable(t *testing.T)      // Versions Refresh 전 → errors.Is(err, engine.ErrUnavailable), 엔진 호출 0회
func TestService_CacheFailureFallsBackToEngine(t *testing.T)    // GetDaily가 오류인 대역 캐시 → 엔진 결과 반환, 오류 없음
func TestService_DailyKeyIncludesTimezone(t *testing.T)         // 같은 날 Asia/Seoul·America/New_York → 엔진 2회
func TestToBirthInfo(t *testing.T)                              // unknown 시각 → time 없음; not_asked → longitude 없음; lunar leap → CALENDAR_TYPE_LUNAR, is_leap_month
```

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/fortune/...` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Expected: PASS(`-race`)
- [ ] **Step 5: Commit** — `feat(server): 엔진 결과 캐시(ResultCache)와 조회 흐름 (S4, spec §7.1)`

### Task 12: 프로필 서비스

**Files:**
- Create: `server/internal/profile/service.go`
- Test: `server/internal/profile/service_test.go`

**Interfaces:**
- Consumes: `profiledb`, `fortune.Service.Chart`(아래 `ChartChecker`로), `Validate*`, `honorific.Normalize`, `BirthHash`, `clock.Clock`
- Produces:

```go
var ErrNotFound = errors.New("profile not found")

type ChartChecker interface {
	Chart(ctx context.Context, b Birth, asOf LocalDate) (*enginev1.ChartResponse, error)
}

type Patch struct { // nil = 바꾸지 않음
	Honorific       *string
	Language        *string
	CurrentTimezone *string
	Birth           *Birth
	Notification    *Notification
}

type Saved struct {
	Profile  Profile
	Warnings []honorific.Code
}

type Service struct{ /* pool, queries, charts, clock */ }
func NewService(pool *pgxpool.Pool, charts ChartChecker, clk clock.Clock) *Service
func (s *Service) Get(ctx context.Context, accountID uuid.UUID) (Profile, error)         // 없으면 ErrNotFound
func (s *Service) Exists(ctx context.Context, accountID uuid.UUID) (bool, error)
func (s *Service) Put(ctx context.Context, accountID uuid.UUID, p Profile) (Saved, error) // 생성 또는 통째 교체
func (s *Service) Patch(ctx context.Context, accountID uuid.UUID, p Patch) (Saved, error) // 없으면 ErrNotFound
```

`Put`·`Patch` 순서: 합친 결과를 만든다(Patch는 저장된 값 위에) → 호칭을 **결과 언어**로 `Normalize`(거부면 `ValidationError{Violation: HonorificRejected, Honorific: 사유, Fields: [{Field: "/honorific"}]}`) → `ValidateTimezone(currentTimezone, "/currentTimezone")` → `ValidateBirth` → `ValidateNotification` → **출생 해시가 저장된 값과 다를 때만**(Put의 새 등록은 항상) `charts.Chart(ctx, birth, currentTimezone 기준 오늘)`; `engine.ErrInvalidArgument` → `ValidationError{BirthInvalid, /birth}`, `engine.ErrOutOfRange` → `{BirthOutOfRange, /birth/date}`, 그 밖 엔진 오류는 그대로 → `UpsertProfile`. Patch에 `honorific`이 없고 `language`만 바뀌면 저장된 호칭을 새 언어 규칙으로 다시 검사합니다(ko→en에서 길이 규칙이 달라짐). 경고는 `Patch`에 호칭이 있을 때만 돌려줍니다.

- [ ] **Step 1: 실패하는 테스트 작성** (`dbtest.New`, 계정 행은 `accountdb`로 만듦, `ChartChecker` 대역)

```go
func TestPut_CreatesAndReturnsWarnings(t *testing.T)        // 호칭 "민지님" → 저장 "민지", Warnings [SuffixStripped], Exists true, Chart 1회
func TestPut_ConcurrentFirstSaveKeepsOneRow(t *testing.T)   // 같은 계정 Put 두 개 동시 → 둘 다 성공, 행 1개
func TestPut_RejectsHonorific(t *testing.T)                 // "{name}" → ValidationError{HonorificRejected, Honorific: InvalidChar}, field /honorific, 저장 없음
func TestPut_EngineInvalidIsBirthInvalid(t *testing.T)      // ChartChecker가 engine.ErrInvalidArgument → BirthInvalid /birth, 저장 없음
func TestPut_EngineOutOfRangeIsBirthOutOfRange(t *testing.T) // engine.ErrOutOfRange → BirthOutOfRange /birth/date
func TestPut_EngineUnavailablePropagates(t *testing.T)      // engine.ErrUnavailable → errors.Is 그대로, 저장 없음
func TestPatch_TimezoneOnlySkipsEngine(t *testing.T)        // currentTimezone만 → Chart 0회, 저장됨
func TestPatch_SameBirthSkipsEngine(t *testing.T)           // 저장된 것과 같은 birth를 다시 보냄 → Chart 0회
func TestPatch_LanguageChangeRechecksHonorific(t *testing.T) // ja "ゆき" 저장 뒤 language ko만 Patch → 통과; 11자 en 호칭 저장 뒤 ko로 → TooLong /honorific
func TestPatch_MissingProfileIsNotFound(t *testing.T)
func TestPut_AsOfUsesCurrentTimezoneToday(t *testing.T)     // 가짜 Clock 2026-10-15T15:30Z, currentTimezone Asia/Seoul → asOf 2026-10-16
```

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/profile/...` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Expected: PASS(`-race`)
- [ ] **Step 5: Commit** — `feat(server): 프로필 저장·수정·조회 서비스 (엔진 검증은 출생 정보가 바뀔 때만)`

### Task 13: 프로필 핸들러, 오류 매핑, `serve` 조립

**Files:**
- Create: `server/internal/httpapi/profile_handlers.go`
- Modify: `server/internal/httpapi/api.go`(`ProfileService` 인터페이스, `API.Profiles`), `server/internal/httpapi/me_handlers.go`(`HasProfile`), `server/internal/httpapi/errors.go`(엔진·프로필 오류, `Retry-After`), `server/internal/cli/serve.go`(엔진 클라이언트, `Versions.Run`, fortune·profile 서비스)
- Test: `server/internal/httpapi/profile_handlers_test.go`, `server/internal/httpapi/me_handlers_test.go`, `server/internal/httpapi/errors_test.go`, `server/internal/cli/serve_test.go`

**Interfaces:**
- Consumes: `profile.Service`(Get·Exists·Put·Patch), `profile.ValidationError`, `engine.Err*`
- Produces:

```go
// api.go
type ProfileService interface {
	Get(ctx context.Context, accountID uuid.UUID) (profile.Profile, error)
	Exists(ctx context.Context, accountID uuid.UUID) (bool, error)
	Put(ctx context.Context, accountID uuid.UUID, p profile.Profile) (profile.Saved, error)
	Patch(ctx context.Context, accountID uuid.UUID, p profile.Patch) (profile.Saved, error)
}
// API에 Profiles ProfileService 필드
```

- 핸들러: `GetProfile`(200 `Profile`, `ErrNotFound` → 409 `profile.required`), `CreateProfile`(200 `ProfileResponse`), `UpdateProfile`(200, 없으면 409). `warnings`는 빈 배열이어도 `[]`. 변환 함수는 `profile_handlers.go` 안에 `toProfile(gen.ProfileInput) profile.Profile`, `toPatch(gen.ProfilePatch) profile.Patch`, `fromProfile(profile.Profile) gen.Profile`로 둡니다(PATCH 본문의 필드 유무는 생성 타입의 포인터로 판단).
- `GetMe.HasProfile`은 `Profiles.Exists`로 채웁니다.
- errors.go: `*profile.ValidationError` → 422. `Violation`(호칭이면 `honorific.Code`) → `problem` 상수 표 하나로 status·code를 정하고, `errors[]`는 `Fields`마다 `{field, code}`이며 code는 `Rule`이 있으면 `required_by_status`·`forbidden_by_status`, 없으면 그 problem code입니다. `domainErrors`에 `engine.ErrUnavailable` → 503 `engine.unavailable` + `Retry-After: 5`, `engine.ErrTimeout` → 504 `engine.timeout`, `engine.ErrInternal` → 502 `engine.error`. 프로필 저장 밖에서 온 `engine.ErrInvalidArgument`·`ErrOutOfRange`는 500(+ Error 로그)입니다(spec §11.3). `Retry-After`를 위해 `Error`와 `domainError`에 `RetryAfter time.Duration`을 더하고 `writeProblem`이 0보다 크면 헤더를 씁니다.
- serve.go: `config.LoadEngine` → `engine.NewClient` → `engine.NewVersions` → `go versions.Run(ctx, 10*time.Minute)` → `fortune.NewService(client, versions, fortune.NewPostgresCache(pool), logger)` → `profile.NewService(pool, fortuneService, clock)`. 엔진 연결 생성 실패는 시작 실패, `GetInfo` 실패는 시작 실패가 아닙니다(Review Focus 5). 종료 때 `client.Close()`.

- [ ] **Step 1: 실패하는 테스트 작성** (응답은 모두 `expectContractResponse`로 계약 대조)

```go
func TestGetProfile_Returns200(t *testing.T)                   // 저장된 프로필 그대로, city면 cityId 포함, longitude는 응답에 없음(계약에 없음)
func TestGetProfile_MissingIs409(t *testing.T)                 // code profile.required
func TestCreateProfile_WarningsInBody(t *testing.T)            // warnings [{field:"/honorific", code:"name.suffix_stripped"}]
func TestCreateProfile_ValidationMapsTo422(t *testing.T)       // table: Inconsistent /birth/time/value required_by_status → request.inconsistent; DateInvalid → date.invalid; TimezoneInvalid → timezone.invalid; CityNotFound → city.not_found; Honorific Emoji → name.emoji; BirthInvalid → birth.invalid
func TestCreateProfile_EngineUnavailableIs503WithRetryAfter(t *testing.T) // Retry-After "5", code engine.unavailable
func TestCreateProfile_EngineTimeoutIs504(t *testing.T)
func TestUpdateProfile_MergePatchOnlyTimezone(t *testing.T)    // Content-Type application/merge-patch+json, {"currentTimezone":"Asia/Tokyo"} → Patch에 CurrentTimezone만 non-nil
func TestUpdateProfile_MissingIs409(t *testing.T)
func TestGetMe_HasProfileTrue(t *testing.T)                    // Profiles.Exists true → hasProfile true
func TestWriteHandlerError_EngineInvalidOutsideProfileIs500(t *testing.T)
func TestServe_StartsWhenEngineInfoFails(t *testing.T)         // ENGINE_ADDR가 닫힌 포트여도 serve가 시작되고 /healthz 200 (cli 테스트 방식대로)
func TestServe_RequiresEngineAddr(t *testing.T)                // ENGINE_ADDR 없음 → 시작 실패, 오류에 "ENGINE_ADDR"
```

- [ ] **Step 2: 실패 확인** — Run: `cd server && go test ./internal/httpapi/... ./internal/cli/...` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Run: `cd server && go test -race ./... && go vet ./... && go tool golangci-lint run` (lint는 CI 버전 v2.14.0과 같은 것) Expected: PASS
- [ ] **Step 5: 로컬 확인** — `docker compose up -d`, `ENGINE_ADDR=localhost:50051 go run ./cmd/server serve`(인증 설정은 P2 README대로), 테스트 계정으로 `PUT /v1/me/profile` → 200, 엔진 컨테이너를 멈추고 `PATCH {"currentTimezone":…}` → 200, `PATCH {"birth":…다른 값}` → 503
- [ ] **Step 6: Commit** — `feat(server): 프로필 operation 3개와 hasProfile, 엔진 오류 응답 (#141)`

### Task 14: 음력 변환 operation (조건부)

**선행 조건:** Task 2 Step 1의 core RPC가 `main`에 병합됨. 이 task를 시작할 때 병합되지 않았으면 건너뛰고, Task 15에서 남은 일로 적습니다(`convertLunarDate`는 501 유지).

**Files:**
- Modify: `server/internal/gen/enginev1/*`(재생성), `server/internal/engine/engine.go`·`client.go`·`enginetest/fake.go`(`ConvertLunarDate`), `server/internal/httpapi/lunar_handlers.go`(새 파일)
- Test: `server/internal/engine/client_test.go`, `server/internal/engine/contract_test.go`, `server/internal/httpapi/lunar_handlers_test.go`

**Interfaces:**
- Produces: `Engine.ConvertLunarDate(ctx, *enginev1.LunarDateRequest) (*enginev1.LunarDateResponse, error)`(이름은 core가 병합한 proto를 따름). 핸들러 `ConvertLunarDate`: 엔진 `INVALID_ARGUMENT` → 422 `date.invalid`(`/date`), `OUT_OF_RANGE` → 422 `date.out_of_range`(`/date`), 결과를 `LunarDate{solarDate, monthHasLeap}`로. App Check와 요청 한도는 P6가 이 라우트에도 붙입니다(그 전까지 계약의 `appCheck`는 검사하지 않음 — 다른 비로그인 operation과 같음).

- [ ] **Step 1: 실패하는 테스트 작성** — `TestConvertLunarDate_Returns200`(Fake 응답 → `solarDate` "2026-02-17", `monthHasLeap` false), `TestConvertLunarDate_InvalidIs422DateInvalid`, `TestConvertLunarDate_OutOfRangeIs422`, `TestRealEngine_ConvertLunarDate`(음력 2026-01-01 → 양력 2026-02-17)
- [ ] **Step 2: 실패 확인 → Step 3: 구현 → Step 4: 통과 확인** — Run: `cd server && go test -race ./... && go test -tags enginecontract ./internal/engine/...`
- [ ] **Step 5: Commit** — `feat(server): 음력 → 양력 변환 operation (#141)`

### Task 15: 문서와 요청함 마무리

**Files:**
- Modify: `server/CLAUDE.md`(현재 상태·다음 할 일), `server/docs/plans/README.md`(P3 완료, 다음 계획 메모), `server/docs/decisions.md`(S25~), `server/docs/specs/2026-10-11-server-mvp-design.md`(§3.3 profiles 출생 날짜 정수 셋, §7.1 엔진 연결 설정, §2.1 `internal/gen/enginev1`)

- [ ] **Step 1: 결정 기록** — S25 `PUT /v1/me/profile`은 생성 또는 통째 교체(멱등), S26 출생 해시 정규형 `v1|…`(= S23 사주 지문), S27 엔진 연결(`ENGINE_ADDR` 필수, `ENGINE_AUDIENCE`가 있으면 TLS + ID token, 없으면 h2c; 시작 때 `GetInfo` 실패는 시작 실패가 아님), S28 도시 자료는 GeoNames `cities15000` + `alternateNamesV2`를 생성기로 변환해 내장, S29 엔진 검증은 출생 해시가 바뀔 때만.
- [ ] **Step 2: 다음 계획 메모** — P4: `characterReason`(Daily·CalendarDay)·`Glossary.meanings`·Preview `dayKindName` 렌더, `fortune.Service.Daily/Month` 사용, 출생 해시 = 사주 지문. P6: `listCities`는 `city.All()`·`DataVersion()`(ETag), `convertLunarDate`에도 App Check·요청 한도. P8: 이전 `ruleset_version` 캐시 행 정리, 프로필 익명화(`anonymized_at` CHECK에 맞춰 출생 열·호칭·해시 비움). P9: Cloud Run 엔진 서비스 h2c end-to-end, gRPC startup probe(`myungli.engine.v1.MyungliEngine`), internal ingress, server의 `ENGINE_ADDR`·`ENGINE_AUDIENCE`, 8초 grace(#79).
- [ ] **Step 3: `server/CLAUDE.md` 갱신** — 현재 상태에 P3 완료와 S25~S29, 다음 할 일에 P4(콘텐츠, #55·#129와 #152 나머지), Task 14를 건너뛰었다면 그 사실.
- [ ] **Step 4: 검증** — Run: `cd server && go test -race ./... && go generate ./... && git status --porcelain` Expected: PASS, 차이 없음
- [ ] **Step 5: Commit, `git merge origin/main`, PR B** — PR 본문: `Closes #141`(Task 14까지 했을 때. 건너뛰었으면 `참고 #141`로 두고 #141을 1·2·4 처리로 닫는 코멘트 + 3번을 새 `to:server` Issue로), `참고 #79`(배포 설정은 P9). 병합 뒤 `kind:report`가 필요한 마일스톤인지 `docs/roadmap.md`에서 확인합니다.
