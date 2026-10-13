# Apple 웹 로그인 재설계 (P2a) Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** Android Apple 웹 로그인에서 토큰이 URL에 실리지 않게 합니다. server 콜백이 검증·교환을 마치고 App Link로 일회용 교환 코드만 넘기며, app은 교환 코드와 nonce 원문으로 로그인을 마칩니다.

**Architecture:** `auth.Service`에 `BeginAppleWebLogin`(콜백에서 검증·교환·임시 저장)과 `CompleteAppleWebLogin`(교환 코드 소비와 기존 로그인 트랜잭션)을 더합니다. 임시 결과는 새 테이블 `apple_web_logins`에 둡니다. `httpapi`는 콜백을 303 App Link로 바꾸고, 새 operation `completeAppleWebLogin`, 계약 밖 정적 응답 두 개(`GET /auth/apple` 안내 페이지, `GET /.well-known/assetlinks.json`)를 더합니다.

**Tech Stack:** 기존과 같습니다(Go 1.27, pgx v5, sqlc, go-oidc, golang-jwt, oapi-codegen strict server, kin-openapi).

**Spec:** `server/docs/specs/2026-10-13-apple-web-callback-design.md`(구속력 있는 기준), `server/docs/specs/2026-10-11-server-mvp-design.md` §4.1. 결정 S15·S19·S22.

## Global Constraints

- P1·P2의 Global Constraints를 모두 이어받습니다(`2026-10-11-p1-foundation.md`, `2026-10-13-p2-auth-account.md`): 작업 범위 `server/`, `go tool` 고정, 생성 코드 commit, 시간은 `Clock`, ID는 `uuid.NewV7()`, 업무 시각은 쿼리 인자, 행 물리 삭제 금지·FK `ON DELETE RESTRICT`, 상태와 값 짝은 CHECK, 로그 금지 항목, problem+json, OpenAPI 3.1 전용 문법 금지, 커밋 꼬리말.
- 교환 코드: 256비트 난수 base64url(패딩 없음), DB에는 SHA-256만, 수명 2분(`AppleWebExchangeTTL = 2 * time.Minute`), 일회용. nonce가 틀려도 소진하지 않습니다.
- 로그에 남기지 않는 값에 교환 코드, App Link의 query, Apple `user`가 더해집니다.
- 오류 code는 `internal/httpapi/problem/codes.go` registry와 계약 `x-problem-codes`에 함께 넣습니다(S21). 새 code는 `auth.exchange_invalid`(401) 하나입니다.
- 계약 `info.version`은 `1.0.0-draft.2`(하위 호환이 깨지는 변경: `loginApple`의 `clientType` 제거).

## Review Focus

1. 교환 코드를 가로챈 쪽이 nonce를 틀리게 보냄 → 401 `auth.exchange_invalid`이고 그 코드는 소진되지 않아, 정상 app이 맞는 nonce로 2분 안에 성공합니다. (Task 4)
2. 같은 교환 코드로 동시에 두 번 완료 요청 → 정확히 하나만 로그인되고 다른 하나는 401. (Task 4)
3. 콜백에서 Apple이 일시 장애(JWKS·token 5xx) → 400 화면이 아니라 App Link로 `error=provider_unavailable`이 가서 app이 재시도를 안내합니다. (Task 5)
4. App Link가 앱을 열지 못해 브라우저가 `GET /auth/apple?exchange=…`를 염 → 안내 HTML, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, 교환 코드는 intent 링크로만 전달, 요청 로그에 query 없음. (Task 5)
5. 완료 요청에서 로그인 트랜잭션이 실패(DB 오류) → 교환 코드는 소진되지 않고, 2분 안 재시도로 성공합니다. (Task 4)

---

### Task 1: 계약 변경

**Files:**
- Modify: `server/api/openapi.yaml`, 생성 코드 `server/internal/httpapi/gen/api.gen.go`(go generate), `server/internal/httpapi/unimplemented.go`(새 operation 기본 구현)
- Modify: `server/internal/httpapi/problem/codes.go`(`AuthExchangeInvalid = Code{"auth.exchange_invalid", 401}`, `AllCodes`에 추가)
- Test: `server/api/contract_test.go`, `server/internal/httpapi/contract_routes_test.go`

**Interfaces:**
- Produces:
  - `info.version: 1.0.0-draft.2`
  - 새 operation `completeAppleWebLogin`: `POST /v1/auth/apple/web`, `security: []`, 요청 `AppleWebLoginRequest {exchangeCode: string(minLength 43, maxLength 43), nonce: string(minLength 16, maxLength 256, 설명은 LoginKakaoRequest.nonce와 같은 규칙)}`, 응답 200 `LoginResponse`, 400, 401(설명에 `auth.exchange_invalid`: 없음·만료·이미 씀·nonce 불일치를 구분하지 않음), 429, 500, 503.
  - `AppleLoginRequest`에서 `clientType` 제거. `loginApple` 설명: "iOS 전용. Android는 appleCallback과 completeAppleWebLogin을 씁니다."
  - `appleCallback` 303 설명: `Location`은 `<APP_LINK_BASE>/auth/apple?exchange=<교환 코드>&state=<state>`, 실패하면 `?error=<값>&state=<state>`. `error` 값은 `user_cancelled_authorize`, `token_invalid`, `provider_unavailable`, `invalid_request`, `server_error`. `code`·`id_token`·`user`를 넘기지 않음. `state`가 없으면 400.
  - `x-problem-codes`에 `auth.exchange_invalid: {status: 401, description: ...}`

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestContract_VersionIsDraft2(t *testing.T)                        // info.version == "1.0.0-draft.2"
func TestContract_CompleteAppleWebLoginIsPublic(t *testing.T)          // operation 존재, security 빈 배열, 요청 required [exchangeCode, nonce], 401 응답
func TestContract_AppleLoginRequestHasNoClientType(t *testing.T)       // properties에 clientType 없음
func TestContract_AppleCallbackLocationDescribesExchange(t *testing.T) // 303 설명에 "exchange", "server_error" 포함, "id_token" 미포함
```
`contract_routes_test.go`의 `minimalRequests`에 `completeAppleWebLogin`(43자 exchangeCode, 16자 nonce)을 더하고, `loginApple` 최소 요청에서 `clientType`을 뺍니다.

- [ ] **Step 2: 실패 확인** — Run: `go test ./api/... ./internal/httpapi/...` Expected: FAIL
- [ ] **Step 3: `openapi.yaml` 수정, `go generate ./...`, `Unimplemented.CompleteAppleWebLogin` 추가, registry에 code 추가**
- [ ] **Step 4: 통과 확인** — Run: `go test ./api/... ./internal/httpapi/...` Expected: PASS (S21 대조 테스트 포함)
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 계약에 completeAppleWebLogin, appleCallback 교환 코드 Location (1.0.0-draft.2)"`

### Task 2: 스키마와 쿼리

**Files:**
- Create: `server/db/migrations/00003_apple_web_logins.sql`
- Modify: `server/db/queries/auth.sql`, 생성 `server/internal/auth/authdb/`
- Test: `server/internal/platform/postgres/schema_accounts_test.go`(또는 새 `schema_apple_web_test.go`)

**Interfaces:**
- Produces: 테이블 `apple_web_logins` — `id uuid PRIMARY KEY`, `exchange_hash bytea NOT NULL UNIQUE`, `subject text NOT NULL`, `nonce_hash text NOT NULL`(id_token nonce claim, 소문자 hex 64자 CHECK `nonce_hash ~ '^[0-9a-f]{64}$'`), `apple_refresh_token bytea NOT NULL`, `apple_token_key_id text NOT NULL`, `apple_client_id text NOT NULL`, `expires_at timestamptz NOT NULL`, `consumed_at timestamptz`, `created_at timestamptz NOT NULL DEFAULT now()`, CHECK `consumed_at IS NULL OR consumed_at <= expires_at`.
- Produces 쿼리: `InsertAppleWebLogin`, `GetAppleWebLoginForUpdate`(exchange_hash → 행, `FOR UPDATE`), `ConsumeAppleWebLogin`(id, consumed_at; `consumed_at IS NULL`일 때만, `:execrows`). 필수 시각 인자는 `::timestamptz` 캐스트로 `time.Time`.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestSchema_AppleWebLoginExchangeHashUnique(t *testing.T)  // 같은 exchange_hash 두 번 → 23505
func TestSchema_AppleWebLoginNonceHashFormat(t *testing.T)     // 대문자·63자 → 23514
func TestSchema_AppleWebLoginConsumedNotAfterExpiry(t *testing.T) // consumed_at > expires_at → 23514
func TestSchema_MigrationDownUp(t *testing.T)                  // 기존 테스트가 00003까지 down/up
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/platform/postgres/ -run 'Schema'` Expected: FAIL
- [ ] **Step 3: migration·쿼리 작성, `go generate ./...`.** migration 개수를 가정하는 기존 테스트(`migrate_test.go`, `cli_test.go`)도 맞춥니다.
- [ ] **Step 4: 통과 확인** — Expected: PASS, `go build ./...`
- [ ] **Step 5: Commit** — `git commit -m "feat(server): Apple 웹 로그인 임시 결과 테이블과 쿼리"`

### Task 3: provider — nonce 없이 id_token 검증

**Files:**
- Modify: `server/internal/auth/provider/apple.go`
- Test: `server/internal/auth/provider/apple_test.go`

**Interfaces:**
- Consumes: `verifyIDTokenClaims`(oidc.go, 서명·iss·aud·exp·sub 확인, nonce는 보지 않음)
- Produces: `func (a *Apple) VerifyWebCallback(ctx context.Context, idToken string) (Identity, string, error)` — web(Services ID) 검증기로 검증하고 `(subject, id_token의 nonce claim)`을 돌려줍니다. nonce claim이 비었으면 `ErrTokenInvalid`. 오류 분류는 `Verify`와 같습니다(JWKS 장애 `ErrUnavailable`).
- `AppleClient` 인터페이스(`internal/auth/service.go`)에 이 메서드를 더하고, `Verify`의 `client` 인자와 `AppleNative`/`AppleWeb` 상수는 `ExchangeCode`·`clientID`가 계속 쓰므로 그대로 둡니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestApple_VerifyWebCallbackReturnsSubjectAndNonce(t *testing.T) // aud=ServicesID 토큰 → sub, nonce claim
func TestApple_VerifyWebCallbackRejectsNativeAudience(t *testing.T)  // aud=BundleID → ErrTokenInvalid
func TestApple_VerifyWebCallbackRequiresNonceClaim(t *testing.T)     // nonce 없음 → ErrTokenInvalid
func TestApple_VerifyWebCallbackJWKSDownIsUnavailable(t *testing.T)  // ErrUnavailable
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/auth/provider/ -run WebCallback` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): Apple 웹 콜백용 nonce 없는 id_token 검증"`

### Task 4: auth 서비스 — 시작과 완료

**Files:**
- Create: `server/internal/auth/apple_web.go`
- Modify: `server/internal/auth/service.go`(`LoginApple`의 `client` 인자 제거 → native 고정, `login`이 트랜잭션 안 사전 단계를 받을 수 있게), `server/internal/auth/errors.go`(`ErrExchangeInvalid`), `server/internal/httpapi/errors.go`(domainErrors 행: `ErrExchangeInvalid` → `problem.AuthExchangeInvalid`, bearer challenge 없음)
- Test: `server/internal/auth/apple_web_test.go`, `server/internal/httpapi/errors_test.go`(사례 추가)

**Interfaces:**
- Produces:
  - `const AppleWebExchangeTTL = 2 * time.Minute`
  - `var ErrExchangeInvalid`
  - `func (s *Service) LoginApple(ctx context.Context, idToken, authorizationCode, rawNonce string) (LoginResult, error)` — native 전용(기존 동작 그대로).
  - `func (s *Service) BeginAppleWebLogin(ctx context.Context, idToken, authorizationCode string) (exchangeCode string, err error)` — `VerifyWebCallback` → `ExchangeCode(ctx, code, provider.AppleWeb, subject)` → 행 id(`uuid.NewV7`)를 aad로 refresh token `Box.Seal` → 교환 코드 생성(`token.NewRefreshToken`과 같은 방식의 256비트 base64url, 해시 SHA-256) → `InsertAppleWebLogin`(만료 now+TTL). provider 오류는 `ErrProviderTokenInvalid`·`ErrProviderUnavailable`로(LoginApple과 같은 `providerError`).
  - `func (s *Service) CompleteAppleWebLogin(ctx context.Context, exchangeCode, rawNonce string) (LoginResult, error)` — 하나의 트랜잭션에서: `GetAppleWebLoginForUpdate`(없음 → `ErrExchangeInvalid`) → `consumed_at` 있음·`now >= expires_at` → `ErrExchangeInvalid` → `hex(sha256(rawNonce)) != nonce_hash`(상수 시간) → `ErrExchangeInvalid`이고 **소진하지 않음** → `Box.Open`(aad 행 id)로 refresh token 복원 → 기존 로그인 단계(계정 찾기·만들기·복구, identity에 aad=identity id로 다시 Seal, 토큰 발급)를 **같은 트랜잭션**에서 → `ConsumeAppleWebLogin`(1행이 아니면 `ErrExchangeInvalid`) → commit. identity unique 위반이면 기존처럼 처음부터 한 번 다시 실행합니다. 트랜잭션이 실패하면 행은 소진되지 않습니다.
  - 완료 실패 때 S19의 조건부 revoke는 하지 않습니다(행이 남아 재시도 가능, 만료 행 정리는 P8).

- [ ] **Step 1: 실패하는 테스트 작성** (`dbtest.New`, `providertest`, `clocktest.Fake`)

```go
func TestBeginAppleWebLogin_StoresSealedTokenAndReturnsCode(t *testing.T) // 43자 코드, 행 1개, exchange_hash == sha256(code), apple_refresh_token != 평문, Open(aad=행 id) == 교환 결과
func TestBeginAppleWebLogin_ProviderErrorsMapToSentinels(t *testing.T)    // token invalid → ErrProviderTokenInvalid, 5xx → ErrProviderUnavailable, 행 없음
func TestCompleteAppleWebLogin_CreatesAccountAndConsumes(t *testing.T)    // LoginResult, IsNewAccount, identity의 apple 열 = 같은 토큰(aad=identity id), consumed_at 기록
func TestCompleteAppleWebLogin_SecondUseIsInvalid(t *testing.T)           // 같은 코드 두 번째 → ErrExchangeInvalid
func TestCompleteAppleWebLogin_WrongNonceDoesNotConsume(t *testing.T)     // 틀린 nonce → ErrExchangeInvalid, consumed_at null, 맞는 nonce로 성공 (Review Focus 1)
func TestCompleteAppleWebLogin_ExpiredIsInvalid(t *testing.T)             // +2분 → 무효(경계: now >= expires_at), +1분59초 → 성공
func TestCompleteAppleWebLogin_ConcurrentSameCodeOneWins(t *testing.T)    // goroutine 2개 → 성공 1, ErrExchangeInvalid 1, accounts 1행 (Review Focus 2, -race)
func TestCompleteAppleWebLogin_TxFailureKeepsCodeUsable(t *testing.T)     // refresh_tokens BEFORE INSERT trigger로 실패 → 오류, consumed_at null, trigger 제거 후 재시도 성공 (Review Focus 5)
func TestCompleteAppleWebLogin_RestoresPendingDeletion(t *testing.T)      // 기존 Apple 계정 pending → active, RestoredFromDeletion
func TestLoginApple_NativeStillWorks(t *testing.T)                         // 기존 native 테스트가 새 signature로 통과
```
`errors_test.go`의 `TestWriteHandlerError_DomainSentinelIsMapped`에 `ErrExchangeInvalid` → 401 `auth.exchange_invalid`, WWW-Authenticate 없음.

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/auth/ -run 'AppleWeb|LoginApple'` Expected: FAIL
- [ ] **Step 3: 구현.** `login`/`loginOnce`가 트랜잭션 안에서 먼저 실행할 함수(교환 코드 확인·복호화)를 받도록 넓히되, 카카오·native 경로의 동작은 바꾸지 않습니다.
- [ ] **Step 4: 통과 확인** — Run: `go test -race ./internal/auth/... ./internal/httpapi/...` Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): Apple 웹 로그인 시작·완료 서비스와 일회용 교환 코드"`

### Task 5: 설정, 핸들러, 안내 페이지, assetlinks

**Files:**
- Modify: `server/internal/platform/config/config.go`(`APPLE_CALLBACK_DEEPLINK` 제거, `APP_LINK_BASE`·`ANDROID_APP_PACKAGE`·`ANDROID_CERT_SHA256`·`ANDROID_STORE_URL` 필수 추가), `server/internal/cli/serve.go`(`parseAuthSettings` 검증, 조립), `server/internal/httpapi/api.go`, `server/internal/httpapi/auth_handlers.go`, `server/internal/httpapi/register.go`(계약 밖 경로 등록)
- Create: `server/internal/httpapi/applink.go`(안내 페이지·assetlinks 핸들러)
- Test: `server/internal/platform/config/config_test.go`, `server/internal/cli/serve_test.go`, `server/internal/httpapi/auth_handlers_test.go`, `server/internal/httpapi/applink_test.go`

**Interfaces:**
- Consumes: Task 4 `BeginAppleWebLogin`, `CompleteAppleWebLogin`, `LoginApple`(새 signature)
- Produces:
  - `AuthConfig`: `AppLinkBase, AndroidAppPackage, AndroidCertSHA256, AndroidStoreURL string`(`AppleCallbackDeepLink` 제거). 필수 변수는 16개, 선택 4개.
  - 시작 검증(`parseAuthSettings`): `APP_LINK_BASE`·`ANDROID_STORE_URL`은 `https` URL이고 host가 있어야 함, `APP_LINK_BASE`는 path가 없거나 `/`. `ANDROID_APP_PACKAGE`는 Android 패키지 이름 형식. `ANDROID_CERT_SHA256`은 쉼표로 나눈 각 값이 `AA:BB:…` 32바이트 hex(대문자). 실패하면 종료 코드 1, 로그에 변수 이름만.
  - `httpapi.API`: `AppLink AppLinkConfig`(`Base *url.URL`, `Package string`, `CertSHA256 []string`, `StoreURL string`). `AppleCallbackDeepLink` 제거.
  - `AppleCallback`: `state` 없으면 400 `request.invalid`(지금과 같음). `error`가 있으면 값이 `user_cancelled_authorize`일 때 그대로, 그 밖은 `invalid_request`로 303. `code`·`id_token`이 둘 다 있으면 `BeginAppleWebLogin` → 성공 303 `exchange`+`state`, `ErrProviderTokenInvalid` → `error=token_invalid`, `ErrProviderUnavailable` → `error=provider_unavailable`, 그 밖 오류 → `error=server_error`(오류는 `logHandlerError` 규칙으로 로그). 둘 중 하나라도 없으면 `error=invalid_request`. 모든 Location은 `Base` + `/auth/apple` + query(`url.Values.Encode`). `user`는 무시하고 로그에도 남기지 않습니다.
  - `CompleteAppleWebLogin` 핸들러 → 200 `LoginResponse`(`consentRequired`는 `Accounts.Me`, loginApple과 같은 helper).
  - `LoginApple` 핸들러: `clientType` 없이 native.
  - `GET /auth/apple`: 200 `text/html; charset=utf-8`, 헤더 `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'`. 본문은 고정 한국어 한 문장("명리일기 앱에서 계속해 주세요.")과 링크 두 개: intent 링크 `intent://<Base host>/auth/apple?<받은 query를 다시 Encode>#Intent;scheme=https;package=<Package>;S.browser_fallback_url=<StoreURL를 QueryEscape>;end`, 스토어 링크. query 값은 `html/template`로 이스케이프. 교환 코드 형식(43자 base64url)이 아니거나 query가 비었으면 같은 안내 페이지에서 intent 링크 없이 스토어 링크만.
  - `GET /.well-known/assetlinks.json`: 200 `application/json`, `[{"relation":["delegate_permission/common.handle_all_urls"],"target":{"namespace":"android_app","package_name":<Package>,"sha256_cert_fingerprints":[...]}}]`, `Cache-Control: public, max-age=3600`.
  - 두 경로는 계약 밖이라 `RegisterAPI`가 `/healthz`처럼 직접 등록합니다(인증·계약 검증 없음, 요청 로그 미들웨어는 그대로 거침).

- [ ] **Step 1: 실패하는 테스트 작성**

```go
// config_test.go
func TestLoadAuth_ReportsAllMissingRequired(t *testing.T)   // 필수 16개(APPLE_CALLBACK_DEEPLINK 없음, 새 4개 포함)
// serve_test.go
func TestRun_ServeRejectsUnparsableAuthSettings(t *testing.T) // 표에 http APP_LINK_BASE, path 있는 APP_LINK_BASE, 잘못된 패키지, 잘못된 지문 추가
// auth_handlers_test.go
func TestAppleCallback_SuccessRedirectsWithExchangeOnly(t *testing.T)   // 303, Location host/path == Base/auth/apple, query 키 정확히 {exchange,state}
func TestAppleCallback_CancellationRedirectsWithError(t *testing.T)     // error=user_cancelled_authorize, state
func TestAppleCallback_UnknownAppleErrorBecomesInvalidRequest(t *testing.T)
func TestAppleCallback_ProviderUnavailableRedirects(t *testing.T)       // error=provider_unavailable (Review Focus 3)
func TestAppleCallback_ProviderTokenInvalidRedirects(t *testing.T)      // error=token_invalid
func TestAppleCallback_UnexpectedErrorRedirectsServerError(t *testing.T)
func TestAppleCallback_MissingCodeRedirectsInvalidRequest(t *testing.T)
func TestAppleCallback_MissingStateIs400(t *testing.T)
func TestCompleteAppleWebLogin_ReturnsLoginResponse(t *testing.T)       // expectContractResponse 통과
func TestCompleteAppleWebLogin_InvalidIs401(t *testing.T)               // auth.exchange_invalid, WWW-Authenticate 없음
func TestLoginApple_NoClientType(t *testing.T)
// applink_test.go
func TestAppLinkPage_HeadersAndIntentLink(t *testing.T)     // 헤더 4개, intent 링크에 exchange·state·package·fallback, 스크립트 없음 (Review Focus 4)
func TestAppLinkPage_EscapesQuery(t *testing.T)             // state에 "<script>" → 이스케이프
func TestAppLinkPage_MalformedExchangeShowsStoreOnly(t *testing.T)
func TestAppLinkPage_RequestLogHasNoQuery(t *testing.T)     // 로그 버퍼에 교환 코드 문자열 없음
func TestAssetLinks_Content(t *testing.T)                   // package, 지문 배열, Content-Type, 캐시 헤더
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/platform/config/... ./internal/cli/... ./internal/httpapi/...` Expected: FAIL
- [ ] **Step 3: 구현.** `testAuthEnv`(serve_test)에 새 변수 4개를 넣습니다.
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): Apple 웹 콜백을 교환 코드 App Link로, 완료 핸들러, 안내 페이지와 assetlinks"`

### Task 6: 처음부터 끝까지 흐름과 문서

**Files:**
- Modify: `server/internal/cli/auth_flow_test.go`, `server/docs/plans/README.md`, `server/CLAUDE.md`, `server/docs/specs/2026-10-13-apple-web-callback-design.md`(구현과 다른 점이 있으면)
- Test: `server/internal/cli/auth_flow_test.go`

**Interfaces:**
- Consumes: Task 1~5 전부

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestAuthFlow_AndroidAppleWebLogin(t *testing.T)
// providertest로 web id_token(aud ServicesID, nonce=hex(sha256(raw)))과 AppleCode 준비
// → POST /v1/auth/apple/callback(form: code, id_token, state) 303, Location query {exchange,state}
// → GET /auth/apple?exchange=…&state=… 200 HTML(App Link 실패 대비 페이지)
// → POST /v1/auth/apple/web {exchange, 틀린 nonce} 401 auth.exchange_invalid
// → POST /v1/auth/apple/web {exchange, 맞는 nonce} 200, consentRequired true
// → 같은 요청 다시 401 → GET /v1/me 200
```

- [ ] **Step 2: 실패 확인 후 통과** — Run: `go test ./internal/cli/ -run AndroidAppleWebLogin`
- [ ] **Step 3: 전체 확인** — Run: `go vet ./... && golangci-lint run && go test -race ./... && go generate ./... && git status --porcelain` Expected: 모두 통과, 마지막 출력 없음
- [ ] **Step 4: 문서.** `plans/README.md`: 계획 표에 이 계획을 P2a 행(**완료**)으로, "다음 계획에 넘길 메모" P8에 "`apple_web_logins` 만료·소진 행 정리. 만료됐는데 소진되지 않은 행은 그 subject의 연결 행이 없을 때만 Apple refresh token을 revoke(S19와 같은 규칙)", P9에 "인증 설정 변수 목록 갱신(`APP_LINK_BASE`·`ANDROID_*` 4개, `APPLE_CALLBACK_DEEPLINK` 제거), `assetlinks.json`을 내줄 도메인". `CLAUDE.md` 현재 상태·다음 할 일 갱신.
- [ ] **Step 5: Commit** — `git commit -m "test(server): Android Apple 웹 로그인 흐름, 계획 메모 갱신"`

PR을 올린 뒤: app에 `kind:request`(계약 `1.0.0-draft.2`: `completeAppleWebLogin`, Location 형식과 `error` 값, `loginApple`의 `clientType` 제거, App Link 경로 `/auth/apple`, assetlinks 지문 제공 요청), root에 계약 목록 버전 갱신 요청, writing에 안내 페이지 문구 슬롯 요청을 보냅니다. #89·#92·#93은 PR 본문 `Closes`로 닫습니다.
