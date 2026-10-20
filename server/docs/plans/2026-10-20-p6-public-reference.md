# P6 비로그인·참조 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 로그인 없는 요청(`createPreview`·`getBirthHour`·`convertLunarDate`)이 App Check와 요청 한도를 거쳐 실제로 응답하고, 참조 요청(`listCities`·`getAppConfig`)과 staging E2E 테스트 로그인(#93, S24)이 동작하게 합니다. 규칙 정합성 점검 #281(D78)의 server 몫(Apple 복귀 페이지 원고 렌더 D66, 원국 개인 해석 D60, D75 결정, `Notice.text` 설명, 문서 정리)도 함께 처리합니다.

**Architecture:** App Check 토큰은 `auth/provider`의 JWKS 검증 기반(go-oidc RemoteKeySet) 위에서 검증하고, `httpapi`는 계약의 `security: appCheck` operation을 `RegisterAPI`에서 감쌉니다(bearer와 같은 방식). 요청 한도는 `internal/ratelimit`(PostgreSQL 고정 창)이고 `httpapi`가 operation 단위로 겁니다. 미리보기는 `fortune`이 계정 없이 오늘 데일리를 렌더하고, 1회 제한은 `internal/preview`가 `preview_usage`로 지킵니다. 언어는 `Accept-Language` middleware가 고릅니다.

**Tech Stack:** Go 1.27, go-oidc v3(JWKS), sqlc/pgx/goose, oapi-codegen strict server, testcontainers(`dbtest`), build tag `staging`

**Spec:** `server/docs/specs/2026-10-11-server-mvp-design.md` §2.1·§2.2, §3.3(`preview_usage`·`rate_limits`), §5.1(언어), §5.2 비로그인·참조 행, §5.3(미리보기 D50, 시진 확인 D58), §11.2(App Check 401, 미리보기 403, 요청 한도 429), §13.2(staging 테스트 로그인 S24). 결정 D50·D58·D29. REST 계약 `server/api/openapi.yaml` 1.0.0-draft.7.

## Global Constraints

* 로그인 없는 요청은 입력을 저장하지 않습니다(D50·D58). 미리보기는 설치 id의 SHA-256만 `preview_usage`에 남깁니다.
* App Check 실패는 401 `app_check.invalid`입니다. 토큰은 헤더 `X-Firebase-AppCheck`입니다. 검증: RS256, JWKS `https://firebaseappcheck.googleapis.com/v1/jwks`, `iss` = `https://firebaseappcheck.googleapis.com/<project number>`, `aud`에 `projects/<project number>` 포함, 만료 전. JWKS를 받아 오지 못하면 503 `service.unavailable`(토큰 오류가 아님).
* 요청 한도는 operation마다 클라이언트 IP별 분당 30회이고, 넘으면 429 `rate_limited`와 `Retry-After`(초)입니다. 대상은 `getBirthHour`·`convertLunarDate`입니다.
* 미리보기는 설치(`installationId`)마다 1번이며 두 번째는 403 `preview.used`입니다(최선 노력). 언어는 `Accept-Language`, 날짜는 `currentTimezone`의 오늘입니다. `evidenceAccess`는 늘 `locked`입니다.
* 시진 확인은 `Asia/Seoul`과 대표 경도(경도 없음)로 계산합니다(D58 ②). 응답 `start`·`end`는 그 시간대 벽시계 HH:MM입니다.
* 언어 고르기: bearer 요청은 프로필 `language`, 그 밖은 `Accept-Language`(계약 info 공통 규약). 지원 언어는 `ko`·`en`·`ja`입니다.
* staging 테스트 로그인은 build tag `staging` 파일에만 있고, 비밀 헤더 `X-Test-Login-Secret`이 `TEST_LOGIN_SECRET`과 다르면(상수 시간 비교) 404입니다. 본문 `{label}`은 영숫자 32자 이하입니다(S24, spec §13.2).
* 로그에 출생 정보·설치 id·IP 원문·토큰을 남기지 않습니다. 제품 코드는 `clock.Clock`을 씁니다.
* 공개 저장소(D74): 커밋·PR·fixture에 가격·수익 수치와 비공개 경로 링크를 넣지 않습니다.

## Review Focus

1. 같은 `installationId`로 미리보기가 동시에 두 번 옴: 하나만 200이고 다른 하나는 403이어야 합니다. 엔진이 실패해 응답을 못 준 요청은 1회를 쓰지 않아야 합니다(다시 시도 가능).
2. 요청 한도 창 경계: 59초에 30번째, 61초에 31번째 요청은 둘 다 통과하고, 같은 창 안 31번째만 429여야 합니다. `Retry-After`는 창이 끝날 때까지 남은 초입니다.
3. 프록시 뒤 클라이언트 IP: 클라이언트가 보낸 `X-Forwarded-For` 앞부분으로 한도를 피할 수 없어야 합니다(신뢰 홉 수만큼 오른쪽에서 셈).
4. App Check 토큰이 다른 Firebase 프로젝트 것이거나 만료됨: 401이어야 하고, JWKS 장애는 401이 아니라 503이어야 합니다.
5. `Accept-Language`가 없거나 지원 밖(`fr`), q값이 섞임(`fr;q=1, ja;q=0.5`): 지원 언어 중 q값이 가장 높은 것, 없으면 기본 언어여야 합니다.

---

## 결정 (plan이 정한 것)

| # | 결정 | 근거 |
| --- | --- | --- |
| P6-1 | 요청 한도 키는 operation + 클라이언트 IP입니다. 계약이 말하는 "기기"는 요청에 기기 식별값이 없어(App Check `sub`는 앱 id) IP만 씁니다. 계약 설명을 "IP별"로 고칩니다(Task 1). | 계약 `BirthHourRequest`·`LunarDateRequest` |
| P6-2 | 클라이언트 IP는 `X-Forwarded-For`를 오른쪽에서 `TRUSTED_PROXY_HOPS`(기본 1, Cloud Run 앞단 하나)번째 값, 헤더가 그보다 짧으면 `RemoteAddr`의 호스트입니다. 실제 값은 P9 배포에서 확인합니다. | Review Focus 3 |
| P6-3 | 요청 한도는 고정 1분 창(`window_start` = 분 단위 내림)이고 `INSERT … ON CONFLICT (key, window_start) DO UPDATE SET count = count + 1 RETURNING count` 한 문장으로 셉니다. 한도를 넘어도 센 값은 남습니다. 지난 창 정리는 P8 retention입니다. | spec §3.3 `rate_limits` |
| P6-4 | 미리보기 1회 기록은 출생 정보 검증을 통과한 뒤 엔진을 부르기 전에 선점(`INSERT … ON CONFLICT DO NOTHING`)하고, 엔진·렌더 실패로 응답을 못 주면 그 행을 지웁니다(D50 "최선 노력"과 실패 재시도). 성공한 행은 지우지 않습니다. | spec §3.3 `preview_usage` |
| P6-5 | 미리보기 총운 문장은 계정이 없어 순환 기록이 없으므로 `advice` 유형(새 사용자 첫 차례)을 쓰고 호칭은 빈 값입니다(렌더 ⓪ 규칙으로 호칭 덩어리 삭제). 선택 기록은 남기지 않습니다. 문장 틀은 활성 시드입니다. | D57, P4 렌더 규칙 |
| P6-6 | `dayKindName`은 활성 시드 용어 사전의 `day_kind.<값>` 이름입니다. 없으면 enum 값 그대로가 아니라 500으로 드러냅니다(원고 누락은 운영에서 고칠 문제). | 계약 `Preview.dayKindName` |
| P6-7 | `Accept-Language`는 RFC 9110 q값 순서로 `ko`·`en`·`ja`(주 태그 비교, `ko-KR` → `ko`) 중 첫째를 고르고, 맞는 것이 없으면 `en`입니다. 도시 이름 기본 언어(`city.localized`)와 같습니다. | 계약 info 공통 규약 |
| P6-8 | 시진 확인의 성별은 계산과 무관해 `GENDER_UNSPECIFIED`로 보냅니다. 실제 엔진이 이를 거부하면(엔진 계약 테스트로 확인) 구현을 멈추고 `to:core` 요청으로 올립니다. | proto `BirthHourRequest` |
| P6-9 | 도시 검색은 NFC·소문자로 맞춘 `q`가 세 언어 이름 중 하나의 앞부분과 같으면 후보이고, 정렬은 ① 요청 언어 이름이 앞부분 일치 ② 요청 언어 이름 순입니다. `limit`까지 자릅니다. `ETag`는 도시 자료 버전(`city.DataVersion()`)과 언어로 만들고, 같으면 304입니다. | 계약 `listCities` |
| P6-10 | 최소 앱 버전은 설정 `APP_MIN_VERSION_IOS`·`APP_MIN_VERSION_ANDROID`이고 없으면 `0.0.0`(강제 업데이트 없음)입니다. semver 형식이 아니면 시작에 실패합니다. 실제 값은 P9 배포 설정입니다. | 계약 `AppConfig` |
| P6-11 | App Check 검증기는 `auth/provider`에 둡니다. 카카오·Apple과 JWKS 조회·장애 분류(`jwksTransport`, `jwksFailureReason`)를 공유하기 때문입니다. 설정은 `FIREBASE_PROJECT_NUMBER`이고 `APP_ENV`가 `local`이면 비어 있을 수 있습니다(그때 App Check operation은 503). | spec §2.2 외부 의존 인터페이스 |
| P6-12 | 계약 draft.8은 설명과 하위 호환 추가만 합니다(Task 1·1b). P6 PR에 함께 담습니다. | S64, D78 ⑤ |
| P6-13 | 원국 개인 해석은 `Chart.personalReadings`(선택 배열)입니다. 항목은 `{kind, position?, index?, shinsal?, text}`로 proto `PersonalReading`과 같은 식별자(앱이 누른 용어를 (kind, position, index, shinsal)로 찾음)이고, `text`는 판정 메시지 키의 앞 두 마디(`personal.<종류>`)를 슬롯 id로 렌더한 문장입니다. 근거 열람 권한이 없으면 필드를 뺍니다(D60). 원고가 없는 항목은 빼고 Error 로그(선택 문장 규칙). | D60, 슬롯 명세 v1.5 `personal.*` |
| P6-14 | 빈 `Notice.text`면 app은 배너를 그리지 않습니다(app A43). 계약 설명과 S49를 이에 맞춥니다. | D78 ④ |
| P6-15 | Apple 복귀 페이지(`GET /auth/apple`)는 활성 시드의 `system.apple_return` 원고(제목·본문·두 링크 문구)를 `Accept-Language`로 고른 언어로 렌더하고 `<html lang>`도 그 언어입니다. 활성 시드나 원고가 없으면 지금의 내장 한국어 문구로 보이고 Error 로그를 남깁니다(로그인 복귀 길을 막지 않음). | D66, S22 |
| P6-16 | D75: `restoreSchedule`은 유지하고, 쓰는 곳이 없는 `FocusSlot.score`·`pillar`, `CalendarDay.scoreItems`·`featuredTag`, `Calendar.notices`는 REST freeze(S3) 전 다음 계약 개정에서 뺍니다. 하위 호환을 깨므로 app 앞으로 `kind:request`를 연 뒤 합니다(D78 ①). P6에서는 결정(S 번호)과 다음 할 일만 기록합니다. | D75, D78 ① |

---

### Task 1: 계약 설명 보강 (draft.8)

**Files:**
- Modify: `server/api/openapi.yaml`, `server/api/contract_test.go`, `server/internal/httpapi/gen/api.gen.go`(재생성), `docs/contracts/README.md`(REST 행)

- [ ] **Step 1:** `contract_test.go`: 버전 테스트를 `TestContract_VersionIsDraft8`(`1.0.0-draft.8`)로 바꾸고 `TestContract_Draft8Additions`를 더합니다(draft.7 테스트 형식). 고정할 설명: `securitySchemes.appCheck` 설명에 `convertLunarDate`; `getBirthHour`에 "`Asia/Seoul`"과 "대표 경도", "엔진 RPC가 생기기 전까지는 501" 문장이 없음; `getBirthHour`·`convertLunarDate`에 "IP별 요청 한도(분당 30회)"; `listCities`에 "앞부분"(검색 규칙)과 "304"; info 공통 규약에 "`Accept-Language`"와 기본 언어 "`en`"; `createPreview`에 "`advice`".
- [ ] **Step 2:** `cd server && go test ./api/` → FAIL.
- [ ] **Step 3:** P6-1·P6-5·P6-7·P6-9와 D58 ②를 operation 설명에 넣고 `info.version`을 `1.0.0-draft.8`로. `go generate ./...`.
- [ ] **Step 4:** `go test ./api/ ./internal/httpapi/` → PASS. README REST 행 버전과 이력(draft.8: 설명만)을 고치고 commit `feat(server): 계약 1.0.0-draft.8 — 비로그인·참조 동작 설명`.

### Task 1b: 계약 draft.8 추가분 (#281 2·4)

**Files:**
- Modify: `server/api/openapi.yaml`, `server/api/contract_test.go`, `server/internal/httpapi/gen/api.gen.go`(재생성), `docs/contracts/README.md`(REST 행 draft.8 이력)

- [ ] **Step 1:** `TestContract_Draft8Additions`에 더합니다: `Chart.properties.personalReadings`가 있고 `required`에 없음, 스키마 `PersonalReading`의 `required: [kind, text]`와 `kind` enum 9개(proto `PersonalTermKind`에서 접두어를 떼고 소문자: `day_master`, `ten_god`, `hidden_ten_god`, `twelve_stage`, `shinsal`, `daeun_stem_ten_god`, `daeun_branch_ten_god`, `daeun_twelve_stage`, `seun_ten_god`), `position`(`Position` 참조)·`index`(integer ≥ 0)·`shinsal`(`Shinsal` 참조)은 선택, `text`는 `RenderedText`; `Notice` 설명에 "배너를 그리지 않습니다"(P6-14)가 있고 "자기 문구를 씁니다"가 없음; info 설명의 "원국 개인 해석은 writing 슬롯이 아직 없어" 문장이 없음; 계약 어디에도 "P6 구현 전까지" 같은 501 예고 문장이 없음(#281 9); `Chart.personalReadings` 설명에 근거 열람 권한 잠금(D60).
- [ ] **Step 2:** FAIL → openapi 수정(P6-13·P6-14, info "설계 메모"의 원국 개인 해석 문장 정리) → `go generate ./...` → `go test ./api/ ./internal/httpapi/` PASS. README 이력 문구를 "설명과 하위 호환 추가"로.
- [ ] **Step 3:** Commit `feat(server): 계약 draft.8 — 원국 개인 해석 필드, Notice.text 설명 (#281)`.

### Task 1c: 원국 개인 해석 렌더 (#281 2, D60)

**Files:**
- Modify: `server/internal/fortune/views.go`(ChartView에 `PersonalReadings []PersonalReadingText`), `views_test.go`, `server/internal/httpapi/fortune_convert.go`(`toChart`, 파일 머리 주석의 "원국 개인 해석은 계약에 자리가 없어" 정리), `fortune_handlers_test.go`

**Interfaces:**
- Produces: `type PersonalReadingText struct{ Reading *enginev1.PersonalReading; Text content.SlotText }`, `ChartView.PersonalReadings`(잠겨 있으면 nil)

- [ ] **Step 1:** 테스트: 열림이면 엔진 `personal_readings` 순서대로 렌더되고 슬롯 id는 메시지 키 앞 두 마디(`personal.day_master.gap` → `personal.day_master`), 매개변수는 판정 params로 렌더; 잠김이면 nil이고 렌더하지 않음(원고 누락 로그도 없음, S42와 같음); 원고 없는 항목은 빠지고 Error 로그 하나; 키가 `personal.`로 시작하지 않으면 그 항목만 빼고 Error 로그. httpapi: `Chart.personalReadings`의 kind·position·index·shinsal 변환(UNSPECIFIED는 생략, 모르는 enum은 500 기존 규칙), 잠김이면 필드 없음, 계약 응답 검증.
- [ ] **Step 2:** FAIL → 구현 → `go test -race ./internal/fortune/ ./internal/httpapi/` PASS.
- [ ] **Step 3:** Commit `feat(server): 원국 개인 해석을 Chart에 (#281, D60)`.

### Task 2: 요청 언어 고르기

**Files:**
- Create: `server/internal/httpapi/language.go`, `language_test.go`
- Modify: `server/internal/httpapi/register.go` 또는 `server.go`(middleware 조립)

**Interfaces:**
- Produces: `func PickLanguage(acceptLanguage string) string`(P6-7), `func LanguageFrom(ctx context.Context) string`(middleware가 넣은 값, 없으면 `en`), middleware `func withRequestLanguage(next http.Handler) http.Handler`

- [ ] **Step 1:** 표 테스트 `TestPickLanguage`: `""`→`en`, `"ko-KR,ko;q=0.9,en;q=0.8"`→`ko`, `"fr;q=1, ja;q=0.5"`→`ja`, `"ja;q=0.3, en;q=0.7"`→`en`, `"*"`→`en`, `"ko;q=0"`→`en`(q=0은 제외), 잘못된 q값(`"ko;q=x"`)은 그 항목을 무시. middleware 테스트로 핸들러가 `LanguageFrom(ctx)`로 값을 읽는지 확인.
- [ ] **Step 2:** `go test ./internal/httpapi/ -run 'PickLanguage|RequestLanguage'` → FAIL.
- [ ] **Step 3:** 구현. `golang.org/x/text/language`(이미 의존성)의 `ParseAcceptLanguage`를 써도 되고, 결과는 위 표와 같아야 합니다.
- [ ] **Step 4:** PASS. Commit `feat(server): Accept-Language로 요청 언어 고르기`.

### Task 3: App Check 검증

**Files:**
- Create: `server/internal/auth/provider/appcheck.go`, `appcheck_test.go`, `server/internal/httpapi/appcheck.go`, `appcheck_test.go`
- Modify: `server/internal/platform/config/config.go`(+테스트, `FIREBASE_PROJECT_NUMBER`), `server/internal/httpapi/register.go`(`Routes.AppCheck`), `server/internal/httpapi/validate.go`(110행 주석)

**Interfaces:**
- Produces:
  - `type AppCheck struct` / `func NewAppCheck(cfg AppCheckConfig) (*AppCheck, error)`, `type AppCheckConfig struct{ ProjectNumber string; HTTPClient *http.Client; JWKSURL string }`(JWKSURL 비면 운영 URL), `func (a *AppCheck) Verify(ctx context.Context, token string) error` — 토큰 오류는 `provider.ErrTokenInvalid`, JWKS 장애는 `provider.ErrUnavailable`(둘 다 기존 sentinel)
  - `httpapi`: `type AppCheckVerifier interface{ Verify(ctx context.Context, token string) error }`, `func RequireAppCheck(v AppCheckVerifier) func(op Operation, next http.Handler) http.Handler`, `Routes.AppCheck`(선택 필드, nil이면 appCheck operation은 503 `service.unavailable`)
  - `Operation`에 `AppCheck bool`(계약 security에 `appCheck`가 있는지, `operationFor`가 채움)

- [ ] **Step 1:** provider 테스트(테스트용 RSA 키와 `httptest` JWKS 서버, 기존 oidc 테스트 헬퍼 재사용): 정상 토큰 통과; `iss` 다른 프로젝트·`aud`에 `projects/<번호>` 없음·만료·서명 키 다름·alg `HS256`은 `ErrTokenInvalid`; JWKS 500은 `ErrUnavailable`(토큰 오류 아님). httpapi 테스트: 헤더 없음·검증 실패 401 `app_check.invalid`, JWKS 장애 503, 통과하면 핸들러 호출, `security: []`인 operation(`listCities`)은 검사하지 않음, `Routes.AppCheck`가 nil이면 503. `operationFor`가 `createPreview`·`getBirthHour`·`convertLunarDate`에 `AppCheck: true`를 채우는지.
- [ ] **Step 2:** `go test ./internal/auth/provider/ ./internal/httpapi/ -run 'AppCheck|OperationFor'` → FAIL.
- [ ] **Step 3:** 구현. 감싸는 순서는 App Check → 계약 검증 → 핸들러(bearer와 같은 자리). 로그에 토큰을 남기지 않습니다.
- [ ] **Step 4:** PASS. Commit `feat(server): App Check 토큰 검증`.

### Task 4: 요청 한도

**Files:**
- Create: `server/db/migrations/00009_rate_limits.sql`, `server/db/queries/ratelimit.sql`, `server/internal/ratelimit/`(`ratelimitdb/`, `ratelimit.go`, 테스트), `server/internal/httpapi/ratelimit.go`, `ratelimit_test.go`, `server/internal/httpapi/clientip.go`, `clientip_test.go`
- Modify: `server/db/sqlc.yaml`, `server/internal/platform/postgres/migrate_test.go`·`server/internal/cli/cli_test.go`(migration 개수 상수 9), `server/internal/platform/config/config.go`(`TRUSTED_PROXY_HOPS`), `register.go`(`Routes.RateLimit`)

**Interfaces:**
- Produces:
  - `package ratelimit`: `type Limiter struct` / `func New(pool *pgxpool.Pool, clk clock.Clock) *Limiter`, `func (l *Limiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (allowed bool, retryAfter time.Duration, err error)`
  - `httpapi`: `func ClientIP(r *http.Request, trustedHops int) string`, `func RateLimit(l Limiter, trustedHops int, limit int, window time.Duration, operations ...string) func(op Operation, next http.Handler) http.Handler`(인터페이스 `Limiter{ Allow(...) }`), `Routes.RateLimit`(선택)

- [ ] **Step 1:** migration: `rate_limits(key text, window_start timestamptz, count int NOT NULL, PRIMARY KEY (key, window_start))`. 키는 `<operation>:<IP의 SHA-256 hex>`(IP 원문을 남기지 않음).
- [ ] **Step 2:** 테스트: ratelimit(`dbtest`, `clocktest`) — 같은 창 30번 허용·31번째 거부와 `retryAfter` = 창 끝까지 남은 시간, 다음 창 첫 요청 허용(Review Focus 2: 59초·61초), 키별 분리, 동시 40요청에 정확히 30 허용. clientip — `trustedHops=1`이면 `X-Forwarded-For: spoofed, real`에서 `real`, 헤더 없으면 `RemoteAddr` 호스트, 홉보다 짧은 헤더면 `RemoteAddr`(Review Focus 3). httpapi — 31번째 429 `rate_limited`와 `Retry-After`(정수 초, 올림), 대상 아닌 operation 통과, 저장소 오류는 500 경로.
- [ ] **Step 3:** FAIL 확인 → 구현(P6-2·P6-3) → `go test -race ./internal/ratelimit/ ./internal/httpapi/ ./internal/platform/postgres/` PASS. 감싸는 순서: App Check → 요청 한도 → 계약 검증 → 핸들러(App Check를 통과하지 못한 요청은 한도를 쓰지 않음).
- [ ] **Step 4:** Commit `feat(server): IP별 요청 한도`.

### Task 5: 시진 확인과 음력 변환의 비로그인 규칙

**Files:**
- Create: `server/internal/httpapi/birthhour_handlers.go`, `birthhour_handlers_test.go`
- Modify: `server/internal/httpapi/lunar_handlers.go`(주석), `server/internal/httpapi/api.go`(`BirthHour` 의존, 엔진 `GetBirthHour`), `unimplemented.go`는 관례대로 둠, `server/internal/engine/`의 엔진 계약 테스트(`-tags enginecontract`)

**Interfaces:**
- Consumes: Task 3 `RequireAppCheck`, Task 4 `RateLimit`(조립은 Task 8)
- Produces: `API.GetBirthHour` 구현, `API.BirthHour interface{ GetBirthHour(ctx, *enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error) }`(`engine.Engine`가 만족)

- [ ] **Step 1:** 테스트(엔진 대역): 양력·음력 요청이 `BirthInfo{calendar, date, is_leap_month, time, timezone: "Asia/Seoul", gender: UNSPECIFIED}`(경도 없음)로 나가는지; 응답 `start`·`end`를 `Asia/Seoul` 벽시계 HH:MM로(자시처럼 날을 넘는 23:30~01:30 포함); 양력인데 `isLeapMonth: true`는 422 `request.inconsistent`(`forbidden_by_status`, `/isLeapMonth`); 엔진 `INVALID_ARGUMENT`→422 `date.invalid`, `OUT_OF_RANGE`→422 `date.out_of_range`(음력 변환과 같은 매핑 재사용); 계약 응답 검증. 엔진 계약 테스트에 실제 엔진으로 `GetBirthHour` 한 건(P6-8 확인).
- [ ] **Step 2:** FAIL → 구현 → `go test ./internal/httpapi/ -run BirthHour` PASS, `go test -tags enginecontract ./internal/engine/...` PASS(엔진이 성별 미지정을 거부하면 멈추고 보고).
- [ ] **Step 3:** Commit `feat(server): 시진 확인`.

### Task 6: 미리보기

**Files:**
- Create: `server/db/migrations/00010_preview_usage.sql`, `server/db/queries/preview.sql`, `server/internal/preview/`(`previewdb/`, `usage.go`, 테스트), `server/internal/fortune/preview.go`, `preview_test.go`, `server/internal/httpapi/preview_handlers.go`, `preview_handlers_test.go`
- Modify: `server/db/sqlc.yaml`, migration 개수 상수(10), `server/internal/httpapi/api.go`(`Previews`), `fortune_convert.go`(미리보기 변환에 기존 `Fortune`·`Tag`·`Notice` 변환 재사용)

**Interfaces:**
- Produces:
  - `package preview`: `type Usage struct` / `func NewUsage(pool) *Usage`, `func (u *Usage) Claim(ctx, installationID string) (bool, error)`(새로 선점하면 true), `func (u *Usage) Release(ctx, installationID string) error`; 저장 값은 `sha256(installationID)`
  - `fortune`: `type PreviewView struct{ Response *enginev1.DailyResponse; Head content.SlotText; Tag *content.SlotText; DayKindName string; Notices []content.Notice; Date profile.LocalDate }`, `func (v *Views) Preview(ctx context.Context, b profile.Birth, currentTimezone, lang string) (PreviewView, error)`
  - `httpapi`: `API.CreatePreview`

- [ ] **Step 1:** migration: `preview_usage(device_hash bytea PRIMARY KEY CHECK (octet_length(device_hash) = 32), used_at timestamptz NOT NULL DEFAULT now())`.
- [ ] **Step 2:** 테스트: usage(`dbtest`) — 첫 Claim true, 두 번째 false, Release 뒤 다시 true, 동시 Claim 둘 중 하나만 true(Review Focus 1), 원문 id가 표에 없음. fortune(`views_test` 픽스처) — 오늘은 `currentTimezone` 기준, 총운 head·tag가 `advice` 유형이고 호칭 덩어리가 빠짐, 선택 기록(`daily_selections`)이 생기지 않음, `dayKindName`은 용어 사전 이름, 이름이 없으면 오류(P6-6), notices 렌더. httpapi — 200 본문(`evidenceAccess: locked`, `fortune`, `featuredTags`의 길흉, `notices`), 두 번째 403 `preview.used`, 엔진 실패면 Release되어 같은 id로 다시 200, 출생 정보 검증 실패(422)는 Claim하지 않음, 언어는 `Accept-Language`, 활성 시드 없음 503, 계약 응답 검증.
- [ ] **Step 3:** FAIL → 구현(P6-4·P6-5·P6-6) → `go test -race ./internal/preview/ ./internal/fortune/ ./internal/httpapi/ ./internal/platform/postgres/` PASS.
- [ ] **Step 4:** Commit `feat(server): 비로그인 미리보기`.

### Task 7: 도시 검색과 앱 설정

**Files:**
- Create: `server/internal/city/search.go`, `search_test.go`, `server/internal/httpapi/reference_handlers.go`, `reference_handlers_test.go`
- Modify: `server/internal/httpapi/profile_handlers.go`(`birthCity`의 `gen.City` 변환을 공용 함수로 뽑음), `server/internal/platform/config/config.go`(P6-10)

**Interfaces:**
- Produces: `func Search(q, lang string, limit int) []City`(P6-9), `httpapi`의 `func toCity(c city.City, lang string, longitude float64) gen.City`(`birthCity`와 `listCities`가 공용), `API.ListCities`, `API.GetAppConfig`, `API.AppConfig struct{ MinIOS, MinAndroid string }`

- [ ] **Step 1:** 테스트: search — `"서울"`(ko)이 서울을 첫째로, `"seo"`(ko)는 영어 이름 앞부분으로도 찾음, 대소문자·NFC 무시(`"Tō"` NFD 입력), 정렬 규칙(P6-9), `limit` 자름, 빈 결과. httpapi — `listCities` 200과 `ETag`, 같은 `If-None-Match`면 304, `lang` 없으면 `Accept-Language`, `City.longitude`가 도시 자료 경도; `getAppConfig` 설정 값; 계약 응답 검증. config — 기본 `0.0.0`, semver가 아니면 오류.
- [ ] **Step 2:** FAIL → 구현 → `go test ./internal/city/ ./internal/httpapi/ ./internal/platform/config/` PASS.
- [ ] **Step 3:** Commit `feat(server): 도시 검색과 앱 설정`.

### Task 7b: Apple 복귀 페이지 원고 렌더 (#281 1, D66)

**Files:**
- Modify: `server/internal/httpapi/applink.go`(`appLinkPageTemplate`의 박힌 한국어 문구 → 원고), `applink_test.go`(또는 기존 테스트 파일), `server/internal/httpapi/api.go`(복귀 페이지가 쓰는 문장 틀 의존: 기존 `Contents`의 `Active`·`Templates` 재사용)

- [ ] **Step 1:** 테스트: `Accept-Language: ja`면 `system.apple_return` ja 원고(`apple_return.title`·`body`·`open`·`install`)와 `<html lang="ja">`; 기본 `en`; 원고 문구가 HTML 이스케이프됨; 활성 시드가 없거나 원고가 없으면 내장 한국어 문구와 Error 로그 하나(P6-15); 교환 코드·intent URL 동작은 그대로(기존 테스트 통과).
- [ ] **Step 2:** FAIL → 구현(언어는 Task 2 `LanguageFrom`, 문장은 `content.Renderer.Identifier`로 single 렌더 후 평문 이어붙임) → `go test ./internal/httpapi/` PASS.
- [ ] **Step 3:** Commit `feat(server): Apple 복귀 페이지를 writing 원고로 (#281, D66)`.

### Task 8: staging 테스트 로그인 (#93, S24)

**Files:**
- Create: `server/db/migrations/00011_test_provider.sql`, `server/internal/httpapi/testlogin_staging.go`(`//go:build staging`), `testlogin_staging_test.go`(`//go:build staging`), `server/internal/httpapi/testlogin_prod_test.go`(`//go:build !staging`)
- Modify: `server/internal/auth/service.go`(provider `test` 로그인 경로 — 기존 로그인과 같은 `LoginResponse`), migration 개수 상수(11), `server/internal/platform/config/config.go`(`TEST_LOGIN_SECRET`, staging 빌드에서만 필수), `.github/workflows/server.yml`(`go test -tags staging ./internal/httpapi/ -run TestLogin` 한 줄)

- [ ] **Step 1:** migration: `auth_identities.provider` CHECK에 `test` 추가(spec §13.2).
- [ ] **Step 2:** 테스트: staging — 맞는 비밀이면 200 `LoginResponse`(같은 label 두 번은 같은 계정), 틀리거나 없는 비밀은 404 `route.not_found`(상수 시간 비교), label 형식 위반 400, 약관 동의 흐름이 정상 로그인과 같음. prod(`!staging`) — `POST /test/v1/auth/login`이 404이고 `test` 계정이 생기지 않음.
- [ ] **Step 3:** FAIL → 구현 → `go test ./internal/httpapi/ -run TestLogin` 와 `go test -tags staging ./internal/httpapi/ -run TestLogin` PASS.
- [ ] **Step 4:** Commit `feat(server): staging 테스트 로그인 (#93)`.

### Task 9: 조립, 검증, 문서

**Files:**
- Modify: `server/internal/cli/serve.go`(App Check 검증기, 요청 한도, 미리보기·시진·도시·앱 설정 의존, 언어 middleware), `server/internal/cli/*_test.go`(조립 테스트), `server/docs/decisions.md`(P6-1~P6-12 중 오래 남을 것을 S65~), `server/docs/specs/2026-10-11-server-mvp-design.md`(§3.3 두 표 열, §5.3 요청 한도 키), `server/docs/plans/README.md`(P6 완료, P8 메모: 지난 `rate_limits` 정리, P9 메모: `TRUSTED_PROXY_HOPS`·`FIREBASE_PROJECT_NUMBER`·`APP_MIN_VERSION_*`·`TEST_LOGIN_SECRET` 배포 설정과 staging `-tags staging` 빌드), `server/CLAUDE.md`

- [ ] **Step 1:** 조립 테스트: 비로그인 operation이 App Check 대역을 거쳐 501이 아니고, App Check 헤더가 없으면 401, `listCities`·`getAppConfig`는 인증 없이 200.
- [ ] **Step 2:** 전체 확인: `cd server && go vet ./... && golangci-lint run ./... && go test -race ./... && go test -tags staging ./internal/httpapi/ && go generate ./... && git status --porcelain`(빈 출력).
- [ ] **Step 3:** #281 문서 정리(5~10번)를 같은 commit에 담습니다.
  * `server/CLAUDE.md`: 계약 버전·상태 문장(draft.6·draft.7, "구현 완료")을 지우고 계약 표(`docs/contracts/README.md`)를 가리킴; 고칠 수 있는 곳에 `.github/workflows/deploy-*.yml`(D65)과 `docs/contracts/README.md`의 자기 행; 계약 표에 사용 계약 `core/message_params.json`·`evidence_rules.json`·`evidence_sources.json`·근거 참조 형식(`source_ref`)·엔진 버전 표기를 더하고 IA를 "사용"으로(역할과 상대만); 대표 태그 "1~2개" → "0~2개"(D76); 다음 할 일 0번(#272) 삭제; D75 후속(P6-16)을 다음 할 일에.
  * spec: 머리말 상태·결정 범위, §5 머리·§14의 "계약 등록 요청" → 주는 쪽이 계약 표 행을 직접 고침, §5.3·§14의 시진 RPC·`message_params` 대기 문장, §6.4 Notice(P6-14), §9 익명화 호칭 "deleted user" → 비움(migration 00004와 같게), §3.1 물리 삭제 예외에 `idempotency_keys`·`apple_web_logins`, §5.2 프로필 PUT "첫 등록" → 생성 또는 교체(S25), §6.3 "호칭·조사 v1" → 계약 표 참조, §5.1 `Idempotency-Key`를 `createSchedule`·`registerDevice`로 한정(S60), §5.2 Apple 복귀 페이지 문구(P6-15)와 S22 설명.
  * 계약 `info.description`: "목록은 cursor 방식" 문장에 범위로 받는 목록(`listSchedules`) 예외 (설명만, draft.8 안).
  * `server/docs/decisions.md`: S49 문장을 P6-14에 맞게 고치고, P6 결정(P6-1~P6-16 중 오래 남을 것)을 S65~로, D75 결정(P6-16)을 그 안에.
  * Task 3에서 빠진 주석: `server/internal/platform/config/config.go`의 `LoadAppCheck` 숫자 검사가 `provider/appcheck.go`의 `isDigits`를 가리키게.
  * commit `docs(server): P6 결정과 현재 상태, 규칙 정합성 정리 (#281)`. PR 본문에 `Closes #281`.
