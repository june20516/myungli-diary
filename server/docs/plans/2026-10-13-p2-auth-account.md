# P2 인증·계정·약관 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 카카오·Apple 로그인으로 자체 토큰을 발급하고, refresh rotation, 약관 동의, 계정 삭제 예약·복구를 동작시킵니다. 인증 operation 5개와 `/v1/me` operation 3개가 501 대신 실제로 응답합니다.

**Architecture:** `internal/auth`가 제공자 토큰 검증, 자체 JWT·refresh token, 계정-제공자 연결을 맡고, `internal/account`가 계정 상태·동의·삭제를 맡습니다. 둘 다 sqlc로 생성한 자기 쿼리 패키지를 씁니다. `httpapi`는 bearer 라우트를 **인증 → 계약 검증 → 핸들러** 순서로 감싸고, 핸들러 오류는 한 곳(`writeHandlerError`)에서 problem으로 바꿉니다.

**Tech Stack:** Go 1.27, pgx v5, goose, sqlc(`go tool`), `github.com/coreos/go-oidc/v3`(v3.21.0, 제공자 JWKS 검증), `github.com/golang-jwt/jwt/v5`(v5.3.1, 자체 access token과 Apple client secret), `github.com/google/uuid`(UUIDv7), `crypto/aes`·`crypto/cipher`(AES-GCM)

**Spec:** `server/docs/specs/2026-10-11-server-mvp-design.md` (§3.1·§3.3 계정과 인증, §4, §5.1, §11). 앞 계획에서 넘어온 메모: `server/docs/plans/README.md` "다음 계획에 넘길 메모 > P2"

## Global Constraints

- P1의 Global Constraints(`2026-10-11-p1-foundation.md`)를 모두 이어받습니다: 작업 범위는 `server/`와 `.github/workflows/server.yml`, `go tool`로 도구 버전 고정, 생성 코드 commit, 시간은 `Clock`으로만, 로그 금지 항목, problem+json, OpenAPI 3.1 전용 문법 금지, 커밋 꼬리말.
- ID는 Go에서 `uuid.NewV7()`로 만듭니다. 업무 시각(`created_at`을 뺀 `last_active_at`, `deletion_requested_at`, `expires_at`, `used_at`, `revoked_at`, `agreed_at`)은 `Clock`에서 받아 쿼리 인자로 넘기고, SQL의 `now()`로 정하지 않습니다.
- 행을 물리적으로 지우지 않고 FK는 `ON DELETE RESTRICT`입니다(spec §3.1). 예외는 만료된 refresh token 정리(P8)입니다.
- 상태와 값 열의 짝은 CHECK 제약으로 DB가 지킵니다(S5).
- 토큰 수명: access 15분(ES256), refresh 30일. refresh token은 256비트 난수의 base64url(패딩 없음)이고 DB에는 SHA-256만 둡니다.
- 로그에 남기지 않는 값: 제공자 id_token·authorization code·refresh token·nonce, 자체 access·refresh token, 제공자 응답 원문, Apple 사용자 정보(`user`), 이메일. 제공자 subject도 남기지 않습니다(계정 id는 남겨도 됩니다).
- 외부 HTTP 호출(JWKS, Apple `/auth/token`·`/auth/revoke`, 카카오 unlink)은 모두 주입한 `*http.Client`로 하고 호출마다 5초 deadline을 둡니다. 테스트는 `httptest.Server`를 씁니다.
- 새 오류 코드와 계약 변경은 Task 1에서만 합니다. 다른 task는 계약에 있는 코드만 씁니다.

## Review Focus

1. 같은 refresh token으로 두 요청이 동시에 갱신 → 정확히 하나만 새 토큰을 받고, 다른 하나는 401 `auth.refresh_reused`이며, 이긴 쪽이 받은 새 토큰도 family 폐기로 401입니다(S8을 그대로 따름). (Task 8)
2. 처음 보는 사용자가 로그인 버튼을 두 번 눌러 동시에 두 요청 → 계정과 제공자 연결은 하나만 생기고 두 응답 모두 같은 계정의 토큰입니다. (Task 8)
3. 삭제 대기 계정에 남은 access token(최대 15분) → `getMe`는 `pending_deletion`을 보여 주고, `deleteMe`는 같은 예정일로 202, 그 밖의 bearer 요청은 401 `auth.token_invalid`입니다. (Task 10)
4. Android Apple 웹 흐름에서 사용자가 취소 → Apple이 `error`·`state`만 form_post로 보냄 → 400 화면에 멈추지 않고 deep link로 `error`·`state`를 넘깁니다. (Task 11)
5. 카카오·Apple JWKS나 token 엔드포인트 장애(연결 실패, 5xx) → 401이 아니라 503 `auth.provider_unavailable`이라 app이 재로그인 대신 재시도합니다. (Task 6)

---

### Task 1: 계약 보강 (nonce 규칙, Apple 취소, 동의 버전 불일치)

**Files:**
- Modify: `server/api/openapi.yaml`, 생성 코드 `server/internal/httpapi/gen/api.gen.go`(go generate)
- Modify: `server/internal/httpapi/contract_routes_test.go`(`minimalRequests`의 `appleCallback`이 계속 통과하는지)
- Test: `server/api/contract_test.go`

**Interfaces:**
- Produces: 계약 변경 세 가지. 모두 하위 호환 추가라 `info.version`은 `1.0.0-draft` 그대로입니다.
  1. `KakaoLoginRequest.nonce`·`AppleLoginRequest.nonce` 설명: "nonce 원문입니다. app은 제공자(카카오·Apple)에게 이 원문의 SHA-256 소문자 hex를 nonce로 보냅니다. server는 id_token의 `nonce` claim이 SHA-256(원문) hex와 같은지 확인합니다." `nonce`에 `minLength: 16`, `maxLength: 256`.
  2. `appleCallback` form: `required: [state]`, `error` 속성(string, "사용자가 취소하면 Apple이 보내는 오류 코드, 예 `user_cancelled_authorize`") 추가. 설명에 "`error`가 있으면 `error`·`state`를, 없으면 `code`·`id_token`·`state`·`user`를 deep link 쿼리로 넘깁니다. `error`도 `code`·`id_token`도 없으면 400입니다"를 더합니다.
  3. `agreeConsents`에 `'422': UnprocessableEntity` 응답 추가, `UnprocessableEntity` 설명에 `consent.version_mismatch`("동의한 문서 버전이 현재 버전과 다름. `errors[].field`는 `/documents/<i>/version`") 추가.

- [ ] **Step 1: 실패하는 테스트 작성** (`contract_test.go`)

```go
func TestContract_LoginNonceDocumentsHashRule(t *testing.T)   // 두 요청 스키마의 nonce.description에 "SHA-256" 포함, minLength 16, maxLength 256
func TestContract_AppleCallbackAcceptsCancellation(t *testing.T) // form 스키마 required == ["state"], properties에 "error"
func TestContract_AgreeConsentsDeclares422(t *testing.T)      // agreeConsents.responses에 "422"
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./api/...` Expected: FAIL 3건
- [ ] **Step 3: `openapi.yaml`을 위 내용대로 고치고 `go generate ./...`**
- [ ] **Step 4: 통과 확인** — Run: `go test ./api/... ./internal/httpapi/...` Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 계약에 nonce 해시 규칙, Apple 취소 콜백, 동의 버전 불일치 422"`

### Task 2: 날짜 형식 검사를 달력 기준으로 (`errors[].code` 통일)

P1 메모의 "`errors[].code` 통일"입니다. 지금 `2026-02-30`은 kin-openapi 정규식을 통과한 뒤 생성 코드 디코드에서 실패해, 경로 parameter는 code `type`, 본문은 `errors[]` 없는 400이 됩니다. 검증 단계에서 `format`으로 잡히게 해 모든 형식 위반을 `errors[].code = 위반한 keyword`로 맞춥니다.

**Files:**
- Modify: `server/internal/httpapi/validate.go`(`init`)
- Test: `server/internal/httpapi/contract_routes_test.go`

**Interfaces:**
- Produces: `format: date`는 `time.Parse("2006-01-02", s)`가 성공해야 통과, `format: date-time`은 `time.Parse(time.RFC3339, s)`가 성공해야 통과합니다. `openapi3.DefineStringFormatValidator`로 등록합니다.

- [ ] **Step 1: 테스트 수정·추가**

```go
// TestAPI_NonexistentDateReturns400을 바꿈:
//   GET /v1/daily/2026-02-30 → 400 request.invalid, errors == [{field:"date", code:"format"}]
//   POST /v1/schedules {"date":"2026-02-30",...} → 400 request.invalid, errors == [{field:"/date", code:"format"}]
func TestAPI_LeapDayIsValidOnlyInLeapYears(t *testing.T) // /v1/daily/2028-02-29 → 501, /v1/daily/2027-02-29 → 400 format
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/httpapi/ -run 'Nonexistent|LeapDay'` Expected: FAIL (code `type`, errors 비어 있음)
- [ ] **Step 3: `validate.go`의 `init`에 두 format validator 등록.** `RequestErrorHandlerFunc`·`writeParameterError`의 주석에서 "없는 날짜" 예를 지우고, 이제 그 경로는 검증을 통과한 값이 생성 타입으로 바뀌지 않는 예외 경로라고 적습니다.
- [ ] **Step 4: 통과 확인** — Run: `go test ./internal/httpapi/...` Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "fix(server): 없는 날짜를 검증 단계에서 format 위반으로 잡음"`

### Task 3: 핸들러 오류 경로 단일화와 로그 정제

**Files:**
- Create: `server/internal/httpapi/errors.go`
- Modify: `server/internal/httpapi/register.go`(`writeHandlerError`)
- Test: `server/internal/httpapi/errors_test.go`

**Interfaces:**
- Produces:
  - `type Error struct { Status int; Code, Title string; Errors []problem.FieldError; BearerChallenge bool }`와 `func (e *Error) Error() string`. 핸들러가 계약의 오류를 그대로 지정할 때 씁니다.
  - `func RegisterDomainError(target error, status int, code, title string)` 대신 **패키지 변수 표** `var domainErrors = []domainError{...}`를 두고, Task 7·8·9의 sentinel을 이 표에 추가합니다(아래 표가 최종 상태). `errors.Is`로 위에서부터 찾습니다.

    | sentinel (패키지) | 상태 | code |
    | --- | --- | --- |
    | `auth.ErrProviderTokenInvalid` | 401 | `auth.provider_token_invalid` |
    | `auth.ErrProviderUnavailable` | 503 | `auth.provider_unavailable` |
    | `auth.ErrRefreshInvalid` | 401 | `auth.token_invalid` |
    | `auth.ErrRefreshReused` | 401 | `auth.refresh_reused` |
    | `account.ErrNotFound` | 401 | `auth.token_invalid` (bearer challenge) |

  - `writeHandlerError` 순서: `ErrNotImplemented` → 501; `*Error` → 그대로(`BearerChallenge`면 `problem.WriteBearerChallenge`); `domainErrors` 표; `*pgconn.ConnectError` 또는 `pgxpool` 획득 실패 → 503 `service.unavailable`; 그 밖 → 500 `internal`.
  - 500·503 로그는 `logHandlerError(ctx, logger, err)` 하나로 남깁니다. `*pgconn.PgError`가 들어 있으면 `pgCode`·`constraint`·`table`만 남기고 `Message`·`Detail`·`Where`는 남기지 않습니다. 그 밖은 오류 타입(`%T`)과 `err.Error()`를 남깁니다. 도메인 코드는 오류 문구에 개인정보를 넣지 않는다는 규칙을 `errors.go` 주석에 적습니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestWriteHandlerError_ExplicitErrorKeepsStatusCodeAndFields(t *testing.T) // &Error{422,"consent.version_mismatch",...,Errors:[{"/documents/0/version","consent.version_mismatch"}]} → 그대로
func TestWriteHandlerError_BearerChallengeAddsHeader(t *testing.T)            // BearerChallenge → WWW-Authenticate: Bearer error="invalid_token"
func TestWriteHandlerError_DomainSentinelIsMapped(t *testing.T)               // fmt.Errorf("x: %w", auth.ErrRefreshReused) → 401 auth.refresh_reused, WWW-Authenticate 없음
func TestWriteHandlerError_ConnectErrorIs503(t *testing.T)                    // &pgconn.ConnectError{} 감싼 오류 → 503 service.unavailable
func TestWriteHandlerError_PgErrorLogOmitsDetail(t *testing.T)                // PgError{Code:"23505", ConstraintName:"c", Detail:"Key (subject)=(12345)"} → 로그에 "23505"·"c" 있음, "12345" 없음, 응답 500 internal
```

Task 7·8·9 전에는 sentinel이 없으므로, 표 테스트는 이 task에서 `httpapi` 내부 테스트용 sentinel로 확인하고 실제 sentinel 행은 각 task가 표에 더하며 같은 테스트에 사례를 추가합니다.

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/httpapi/ -run WriteHandlerError` Expected: FAIL
- [ ] **Step 3: `errors.go` 구현, `register.go`의 `writeHandlerError`를 위 순서로 교체**
- [ ] **Step 4: 통과 확인** — Run: `go test ./internal/httpapi/...` Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 핸들러 오류를 한 경로로 problem 변환, DB 오류 로그 정제"`

### Task 4: sqlc 도입과 계정·인증 스키마

**Files:**
- Create: `server/db/migrations/00002_accounts_auth.sql`, `server/db/sqlc.yaml`, `server/db/generate.go`, `server/db/queries/auth.sql`, `server/db/queries/account.sql`
- Create(생성): `server/internal/auth/authdb/`, `server/internal/account/accountdb/`
- Modify: `server/go.mod`(`tool github.com/sqlc-dev/sqlc/cmd/sqlc`, `require github.com/google/uuid`)
- Test: `server/internal/platform/postgres/schema_accounts_test.go`

**Interfaces:**
- Produces: 테이블(모든 id `uuid PRIMARY KEY`, FK `REFERENCES accounts(id) ON DELETE RESTRICT`, `created_at timestamptz NOT NULL DEFAULT now()`)

  | 테이블 | 열과 제약 |
  | --- | --- |
  | `accounts` | `status text NOT NULL CHECK (status IN ('active','pending_deletion','deleted'))`, `deletion_requested_at`, `anonymized_at`, `last_active_at timestamptz NOT NULL`, `updated_at`(트리거 `set_updated_at`). CHECK: `active` ⇔ 두 시각 모두 null, `pending_deletion` ⇔ `deletion_requested_at`만 있음, `deleted` ⇔ 둘 다 있음 |
  | `auth_identities` | `account_id`, `provider text CHECK IN ('kakao','apple')`, `subject text NOT NULL`, `apple_refresh_token bytea`, `apple_token_key_id text`, `apple_client_id text`, `provider_disconnected_at timestamptz`, `updated_at`(트리거). `UNIQUE (provider, subject)`. CHECK: `apple_*` 세 열은 모두 있거나 모두 null, `provider = 'kakao'`면 모두 null. 인덱스 `(account_id)` |
  | `refresh_tokens` | `account_id`, `token_hash bytea NOT NULL UNIQUE`, `family_id uuid NOT NULL`, `expires_at`, `used_at`, `revoked_at`. 인덱스 `(family_id)`, `(account_id) WHERE revoked_at IS NULL` |
  | `consents` | `account_id`, `document text CHECK IN ('terms','privacy')`, `version text NOT NULL`, `agreed_at timestamptz NOT NULL`. `UNIQUE (account_id, document, version)` |

- Produces: sqlc 설정 — `engine: postgresql`, `schema: migrations`, `sql_package: pgx/v5`, 쿼리 파일마다 `gen.go.package`가 `authdb`·`accountdb`인 블록 둘. override: `uuid` → `github.com/google/uuid.UUID`, nullable `uuid` → `uuid.NullUUID`, `timestamptz` → `time.Time`, nullable `timestamptz` → `*time.Time`. `emit_interface: true`(`Querier`).
- Produces: 쿼리 이름(이후 task가 씀). `auth.sql`: `CreateAccount`, `GetIdentity`(provider, subject → identity와 계정 status, `FOR UPDATE OF accounts`), `CreateIdentity`, `UpdateAppleToken`, `RestoreAccount`(pending → active, `deletion_requested_at` null), `ClearProviderDisconnected`, `InsertRefreshToken`, `GetRefreshTokenForUpdate`(hash → 행과 계정 status), `MarkRefreshTokenUsed`, `RevokeFamily`, `RevokeAccountTokens`, `ListIdentities`(account), `MarkProviderDisconnected`(apple 세 열을 비우고 시각 기록). `account.sql`: `GetAccountAccess`(status, deletion_requested_at, last_active_at), `TouchLastActive`(`last_active_at < $2`일 때만), `ListConsents`, `InsertConsent`(`ON CONFLICT DO NOTHING`), `RequestDeletion`(active → pending, 갱신 행 수 반환).
- `db/generate.go`: `//go:generate go tool sqlc generate -f sqlc.yaml`. CI의 기존 "생성 코드 일치" 단계가 sqlc도 검사합니다(`server.yml` 변경 없음). sqlc의 PostgreSQL 파서는 cgo를 쓰므로 ubuntu runner의 gcc로 빌드됩니다.

- [ ] **Step 1: 도구 고정** — `go get -tool github.com/sqlc-dev/sqlc/cmd/sqlc@v1.31.1 && go tool sqlc version` Expected: `v1.31.1`
- [ ] **Step 2: 실패하는 DB 테스트 작성** (`dbtest.New`로 migration 적용 DB)

```go
func TestSchema_AccountStatusRequiresMatchingTimestamps(t *testing.T) // active+deletion_requested_at, pending+null, deleted+anonymized null → 각각 check_violation(23514)
func TestSchema_KakaoIdentityRejectsAppleColumns(t *testing.T)        // provider kakao + apple_refresh_token → 23514
func TestSchema_AppleTokenColumnsComeTogether(t *testing.T)           // apple_refresh_token만 있고 key_id null → 23514
func TestSchema_IdentityUniquePerProviderSubject(t *testing.T)        // 같은 (provider, subject) 두 번 → 23505
func TestSchema_AccountsCannotBeDeletedWhileReferenced(t *testing.T)  // identity가 있는 계정 DELETE → foreign_key_violation(23503)
func TestSchema_MigrationDownUp(t *testing.T)                         // Migrate down → up 성공
```

- [ ] **Step 3: 실패 확인** — Run: `go test ./internal/platform/postgres/ -run Schema` Expected: FAIL (테이블 없음)
- [ ] **Step 4: migration·쿼리·sqlc 설정 작성 후 `go generate ./...`**
- [ ] **Step 5: 통과 확인** — Run: `go test ./internal/platform/postgres/... && go build ./...` Expected: PASS
- [ ] **Step 6: Commit** — `git commit -m "feat(server): 계정·인증 스키마와 sqlc 쿼리"`

### Task 5: 자체 토큰과 비밀값 암호화 (`internal/auth/token`, `internal/auth/secretbox`)

**Files:**
- Create: `server/internal/auth/token/access.go`, `server/internal/auth/token/refresh.go`, `server/internal/auth/secretbox/secretbox.go`
- Test: `server/internal/auth/token/access_test.go`, `server/internal/auth/token/refresh_test.go`, `server/internal/auth/secretbox/secretbox_test.go`

**Interfaces:**
- Produces (`token`):
  - `type SigningKey struct { ID string; Private *ecdsa.PrivateKey }`, `func ParseSigningKey(id, pemPKCS8 string) (SigningKey, error)` — P-256이 아니면 오류.
  - `func NewAccessIssuer(current SigningKey, previous []SigningKey, clk clock.Clock) *AccessIssuer`
  - `func (i *AccessIssuer) Issue(accountID uuid.UUID) (token string, expiresAt time.Time, err error)` — header `alg: ES256`, `kid`; claim `sub`·`iat`·`exp`(15분)·`jti`(UUIDv7).
  - `func (i *AccessIssuer) Verify(token string) (uuid.UUID, error)` — `kid`로 current·previous에서 키를 찾고 `ES256`만 허용(`jwt.WithValidMethods`). 오류는 `ErrAccessExpired` 또는 `ErrAccessInvalid` 둘 중 하나.
  - `const AccessTTL = 15 * time.Minute`, `const RefreshTTL = 30 * 24 * time.Hour`
  - `func NewRefreshToken() (raw string, hash []byte, err error)`, `func HashRefreshToken(raw string) []byte`
- Produces (`secretbox`):
  - `type Key struct { ID string; Bytes []byte }`, `func ParseKey(id, base64Std string) (Key, error)` — 32바이트가 아니면 오류.
  - `func New(current Key, previous []Key) *Box`
  - `func (b *Box) Seal(plaintext []byte) (ciphertext []byte, keyID string, err error)` — AES-256-GCM, 12바이트 무작위 nonce를 앞에 붙임.
  - `func (b *Box) Open(ciphertext []byte, keyID string) ([]byte, error)` — 모르는 keyID, 변조는 오류.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestAccess_IssueThenVerifyReturnsAccount(t *testing.T)
func TestAccess_ExpiredAfter15Minutes(t *testing.T)            // Fake clock +15m+1s → ErrAccessExpired
func TestAccess_RejectsOtherAlgorithms(t *testing.T)           // HS256(공개 키 바이트를 비밀로), alg none → ErrAccessInvalid
func TestAccess_VerifiesTokenSignedByPreviousKey(t *testing.T) // previous 키로 발급한 토큰을 current+previous issuer가 검증
func TestAccess_UnknownKidIsInvalid(t *testing.T)
func TestAccess_SubjectMustBeUUID(t *testing.T)                // 같은 키로 sub "abc" 서명 → ErrAccessInvalid
func TestRefresh_TokenHas256BitsAndHashIsSHA256(t *testing.T)  // base64url 디코드 32바이트, hash == sha256(raw)
func TestSecretbox_SealOpenRoundTrip(t *testing.T)
func TestSecretbox_OpenWithPreviousKey(t *testing.T)
func TestSecretbox_TamperedCiphertextFails(t *testing.T)
func TestSecretbox_ParseKeyRejectsWrongLength(t *testing.T)
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/auth/...` Expected: FAIL
- [ ] **Step 3: 구현** (`golang-jwt/jwt/v5`를 직접 의존으로)
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): ES256 access token, refresh token, AES-GCM 비밀값 상자"`

### Task 6: 제공자 연동 (`internal/auth/provider`)

**Files:**
- Create: `server/internal/auth/provider/oidc.go`, `kakao.go`, `apple.go`, `errors.go`, `providertest/providertest.go`
- Test: `server/internal/auth/provider/kakao_test.go`, `apple_test.go`, `oidc_test.go`

**Interfaces:**
- Produces:
  - `var ErrTokenInvalid`, `var ErrUnavailable` (Task 8에서 `auth.ErrProviderTokenInvalid`·`auth.ErrProviderUnavailable`로 다시 내보냄).
  - `type Identity struct { Subject string }`
  - `type KakaoConfig struct { AppKey, AdminKey string; Issuer, JWKSURL, UnlinkURL string; HTTP *http.Client }` — 기본값 Issuer `https://kauth.kakao.com`, JWKS `https://kauth.kakao.com/.well-known/jwks.json`, unlink `https://kapi.kakao.com/v1/user/unlink`.
  - `func NewKakao(cfg KakaoConfig) *Kakao`
  - `func (k *Kakao) Verify(ctx context.Context, idToken, rawNonce string) (Identity, error)` — `iss`, `aud == AppKey`, `exp`, 서명(RS256), `nonce == hex(sha256(rawNonce))`.
  - `func (k *Kakao) Unlink(ctx context.Context, subject string) error` — `POST`, `Authorization: KakaoAK <AdminKey>`, form `target_id_type=user_id&target_id=<subject>`. 2xx 성공. 카카오가 "이미 연결이 끊긴 사용자"로 답하면(4xx 본문의 `code: -101`) 성공으로 봅니다.
  - `type AppleConfig struct { TeamID, KeyID string; PrivateKey *ecdsa.PrivateKey; BundleID, ServicesID, WebRedirectURI string; Issuer, JWKSURL, TokenURL, RevokeURL string; HTTP *http.Client; Clock clock.Clock }` — 기본값 Issuer `https://appleid.apple.com`, JWKS `https://appleid.apple.com/auth/keys`, token `https://appleid.apple.com/auth/token`, revoke `https://appleid.apple.com/auth/revoke`.
  - `type AppleClient string; const AppleNative AppleClient = "native"; const AppleWeb AppleClient = "web"`
  - `func (a *Apple) Verify(ctx context.Context, idToken, rawNonce string, client AppleClient) (Identity, error)` — `aud`는 native면 BundleID, web이면 ServicesID.
  - `func (a *Apple) ExchangeCode(ctx context.Context, code string, client AppleClient) (refreshToken, clientID string, err error)` — `client_secret`은 ES256 JWT(`iss` TeamID, `iat`, `exp` iat+5분, `aud` `https://appleid.apple.com`, `sub` clientID, header `kid` KeyID). web이면 `redirect_uri=WebRedirectURI`를 함께 보냅니다. Apple의 `400 invalid_grant`는 `ErrTokenInvalid`.
  - `func (a *Apple) Revoke(ctx context.Context, refreshToken, clientID string) error` — `token_type_hint=refresh_token`.
  - 장애 분류: 연결 실패·timeout·5xx·JWKS 조회 실패는 `ErrUnavailable`, 그 밖의 검증 실패는 `ErrTokenInvalid`. go-oidc v3.21의 `IDTokenVerifier.Verify`는 KeySet 오류를 `%v`로 감싸 원인을 잃으므로, `oidc.KeySet`을 구현한 래퍼가 `RemoteKeySet.VerifySignature`의 오류를 받아 조회 실패인지 판별하고 요청 ctx에 둔 기록 칸에 남깁니다. JWKS 응답이 2xx가 아니면 go-oidc가 타입 없는 오류를 만들므로, JWKS용 `http.Client`의 Transport가 2xx가 아닌 응답을 타입 있는 오류로 바꿉니다.
  - `providertest`: 테스트용 RSA 키로 JWKS를 내주는 `httptest.Server`와 `SignIDToken(claims map[string]any) string`, Apple token·revoke와 카카오 unlink 엔드포인트 대역(받은 form을 기록, 응답 상태를 바꿀 수 있음). Task 8·11이 씁니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestKakao_VerifyAcceptsValidToken(t *testing.T)            // Subject == claims.sub
func TestKakao_VerifyRejectsWrongAudienceIssuerNonceExpiry(t *testing.T) // 표 테스트, 각각 ErrTokenInvalid
func TestKakao_NonceComparesSHA256Hex(t *testing.T)             // token nonce = 원문 그대로면 ErrTokenInvalid, hex(sha256(원문))이면 통과
func TestKakao_JWKSDownIsUnavailable(t *testing.T)              // JWKS 서버 500, 연결 거부 → ErrUnavailable
func TestKakao_UnknownKidRefetchesJWKS(t *testing.T)            // 키 교체 후 새 kid 토큰 → 통과
func TestKakao_UnlinkSendsAdminKeyAndTarget(t *testing.T)
func TestKakao_UnlinkAlreadyUnlinkedIsSuccess(t *testing.T)     // 400 {"code":-101} → nil
func TestApple_VerifyUsesAudiencePerClient(t *testing.T)        // native 토큰을 web으로 검증하면 ErrTokenInvalid
func TestApple_ExchangeCodeSendsSignedClientSecret(t *testing.T) // client_secret을 공개 키로 검증, sub == clientID, web이면 redirect_uri 포함
func TestApple_ExchangeInvalidGrantIsTokenInvalid(t *testing.T)
func TestApple_TokenEndpoint5xxIsUnavailable(t *testing.T)
func TestApple_RevokeSendsRefreshToken(t *testing.T)
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/auth/provider/...` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 카카오·Apple id_token 검증, Apple code 교환·revoke, 카카오 unlink"`

### Task 7: 설정과 serve의 DB 연결

**Files:**
- Modify: `server/internal/platform/config/config.go`, `server/internal/cli/serve.go`, `server/internal/platform/dbtest/dbtest.go`
- Test: `server/internal/platform/config/config_test.go`, `server/internal/cli/serve_test.go`

**Interfaces:**
- Produces:
  - `type AuthConfig struct { JWTKeyID, JWTKeyPEM, JWTPreviousKeyID, JWTPreviousKeyPEM, TokenKeyID, TokenKey, TokenPreviousKeyID, TokenPreviousKey, KakaoAppKey, KakaoAdminKey, AppleTeamID, AppleKeyID, ApplePrivateKeyPEM, AppleBundleID, AppleServicesID, AppleWebRedirectURI, AppleCallbackDeepLink string }`
  - `func LoadAuth(getenv func(string) string) (AuthConfig, error)` — 필수 값이 비면 모두 모아 `errors.Join`. 환경 변수 이름은 필드 순서대로 `JWT_SIGNING_KEY_ID`, `JWT_SIGNING_KEY`, `JWT_PREVIOUS_KEY_ID`, `JWT_PREVIOUS_KEY`, `TOKEN_ENCRYPTION_KEY_ID`, `TOKEN_ENCRYPTION_KEY`, `TOKEN_PREVIOUS_KEY_ID`, `TOKEN_PREVIOUS_KEY`, `KAKAO_APP_KEY`, `KAKAO_ADMIN_KEY`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_BUNDLE_ID`, `APPLE_SERVICES_ID`, `APPLE_WEB_REDIRECT_URI`, `APPLE_CALLBACK_DEEPLINK`. `*_PREVIOUS_*` 둘은 선택이고 ID와 값이 함께 있어야 합니다. 로컬도 같은 규칙이며 대체 값을 만들지 않습니다.
  - `func NewURL(t testing.TB) string` (`dbtest`) — `New`와 같은 격리 DB의 연결 주소.
  - `runServe`: `config.Load` → `RequireDatabase` → `LoadAuth` → `postgres.Open` → 서비스 조립(Task 12에서 채움). DB 연결 실패는 로그를 남기고 `loggedError`.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestLoadAuth_ReportsAllMissingRequired(t *testing.T)     // 빈 환경 → 오류에 필수 변수 13개 이름이 모두 있음
func TestLoadAuth_PreviousKeyNeedsBothIDAndValue(t *testing.T) // JWT_PREVIOUS_KEY만 있음 → 오류
func TestRun_ServeFailsFastWhenDatabaseUnreachable(t *testing.T) // DATABASE_URL=postgres://x@127.0.0.1:1/x, 인증 설정 완비 → 5초 안에 종료 코드 1, stderr에 "DB 연결 실패"
func TestRun_ServeRequiresDatabaseURL(t *testing.T)            // DATABASE_URL 없음 → 1, stderr에 "DATABASE_URL"
// TestRun_ServeStartsWithoutDatabaseURLAndStopsOnCancel → TestRun_ServeStartsAndStopsOnCancel로 바꿈:
//   dbtest.NewURL과 테스트용 키로 시작, /healthz 200, GET /v1/me(토큰 없음) 401, cancel 뒤 종료 코드 0
```

테스트용 키는 테스트 helper `testAuthEnv(t) map[string]string`이 실행할 때 만듭니다(P-256 키를 PKCS8 PEM으로, 32바이트 무작위 키를 base64로).

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/platform/config/... ./internal/cli/...` Expected: FAIL
- [ ] **Step 3: 구현.** `/v1/me`가 401이 되는 것은 Task 10·12 뒤이므로, 이 task에서는 그 단언을 501로 두고 Task 12에서 401로 바꿉니다.
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 인증 설정 로드, serve의 DB 연결과 빠른 실패"`

### Task 8: 로그인·갱신·로그아웃 서비스 (`internal/auth`)

**Files:**
- Create: `server/internal/auth/service.go`, `server/internal/auth/errors.go`, `server/internal/auth/disconnect.go`
- Test: `server/internal/auth/service_test.go`, `server/internal/auth/disconnect_test.go`

**Interfaces:**
- Consumes: Task 4 `authdb`, Task 5 `token`·`secretbox`, Task 6 `provider`
- Produces:
  - sentinel: `ErrProviderTokenInvalid`, `ErrProviderUnavailable`, `ErrRefreshInvalid`, `ErrRefreshReused` (Task 3 표에 행 추가)
  - `type TokenPair struct { AccessToken string; AccessExpiresAt time.Time; RefreshToken string; RefreshExpiresAt time.Time }`
  - `type LoginResult struct { AccountID uuid.UUID; Tokens TokenPair; IsNewAccount, RestoredFromDeletion bool }`
  - `type KakaoVerifier interface { Verify(ctx, idToken, rawNonce string) (provider.Identity, error) }`, `type AppleClient interface { Verify(...); ExchangeCode(...); Revoke(...) }`, `type KakaoUnlinker interface { Unlink(ctx, subject string) error }` — Task 6 타입이 만족합니다.
  - `func NewService(pool *pgxpool.Pool, deps ServiceDeps) *Service` (`ServiceDeps{Kakao, Apple, KakaoUnlink, Access *token.AccessIssuer, Box *secretbox.Box, Clock clock.Clock, Logger *slog.Logger}`)
  - `func (s *Service) LoginKakao(ctx, idToken, rawNonce string) (LoginResult, error)`
  - `func (s *Service) LoginApple(ctx, idToken, authorizationCode, rawNonce string, client provider.AppleClient) (LoginResult, error)` — 검증 → code 교환(실패하면 로그인 실패) → 트랜잭션.
  - 로그인 트랜잭션: `GetIdentity`(행 잠금). 없으면 계정(`active`, `last_active_at = now`)과 identity를 만들고 `IsNewAccount`. `pending_deletion`이면 `RestoreAccount`, `ClearProviderDisconnected`, `RestoredFromDeletion`. Apple이면 refresh token을 `Box.Seal`해 저장(새로 만들 때와 매번 갱신). 새 refresh family를 만들고 토큰 쌍을 발급. `(provider, subject)` unique 위반(동시 첫 로그인)이면 트랜잭션을 처음부터 한 번 다시 실행해 기존 행을 씁니다.
  - `func (s *Service) Refresh(ctx, rawRefresh string) (TokenPair, error)` — 트랜잭션에서 `GetRefreshTokenForUpdate`. 없음·만료·폐기·계정이 `active`가 아님 → `ErrRefreshInvalid`. `used_at`이 있으면 `RevokeFamily`를 **commit하고** `ErrRefreshReused`. 그 밖은 `MarkRefreshTokenUsed` 후 같은 family로 새 토큰(만료 now+30일).
  - `func (s *Service) Logout(ctx, accountID uuid.UUID, rawRefresh string) error` — 토큰이 그 계정 것이면 family 폐기. 없거나 남의 것이어도 nil(존재를 드러내지 않음).
  - `func (s *Service) RevokeAllSessions(ctx, accountID uuid.UUID) error`
  - `func (s *Service) DisconnectProviders(ctx, accountID uuid.UUID) error` — `ListIdentities`에서 `provider_disconnected_at`이 없는 것마다 Apple은 복호화해 `Revoke`, 카카오는 `Unlink`, 성공하면 `MarkProviderDisconnected`. 하나가 실패해도 나머지를 시도하고 오류를 `errors.Join`으로 돌려줍니다. P8의 `job retention`이 같은 함수로 재시도합니다.

- [ ] **Step 1: 실패하는 테스트 작성** (`dbtest.New`, `providertest`, `clocktest.Fake`)

```go
func TestLoginKakao_NewSubjectCreatesAccount(t *testing.T)          // IsNewAccount, accounts 1행 active, identity 1행
func TestLoginKakao_KnownSubjectReusesAccount(t *testing.T)         // 두 번째 로그인 IsNewAccount false, 같은 AccountID
func TestLoginKakao_ConcurrentFirstLoginsCreateOneAccount(t *testing.T) // goroutine 2개 동시 → 같은 AccountID, accounts 1행 (Review Focus 2)
func TestLoginKakao_RestoresPendingDeletion(t *testing.T)           // pending 계정 → active, RestoredFromDeletion, provider_disconnected_at null
func TestLoginKakao_ProviderErrorsMapToSentinels(t *testing.T)      // ErrTokenInvalid → ErrProviderTokenInvalid, ErrUnavailable → ErrProviderUnavailable, DB 행 없음
func TestLoginApple_StoresEncryptedRefreshTokenAndClientID(t *testing.T) // 저장된 bytea는 평문과 다르고 Box.Open == 교환 결과, apple_client_id == BundleID(native)
func TestLoginApple_FailedCodeExchangeCreatesNothing(t *testing.T)
func TestRefresh_RotatesWithinFamily(t *testing.T)                  // 새 토큰의 family == 이전 family, 이전 행 used_at 기록, 만료 now+30일
func TestRefresh_ReuseRevokesFamily(t *testing.T)                   // A→B 갱신 뒤 A 다시 → ErrRefreshReused, B도 ErrRefreshInvalid
func TestRefresh_ConcurrentSameTokenOneWins(t *testing.T)           // 동시 2회 → 성공 1, ErrRefreshReused 1, 성공한 쪽 새 토큰도 무효 (Review Focus 1)
func TestRefresh_ExpiredOrUnknownIsInvalid(t *testing.T)            // Fake clock +30일+1초, 모르는 토큰
func TestRefresh_PendingDeletionAccountIsInvalid(t *testing.T)
func TestLogout_RevokesOnlyOwnFamily(t *testing.T)                  // 남의 토큰 → nil이고 그 토큰은 여전히 갱신 가능
func TestDisconnectProviders_RevokesAppleAndUnlinksKakao(t *testing.T) // Apple revoke에 복호화된 토큰과 client_id, 성공 뒤 apple 열 null·시각 기록
func TestDisconnectProviders_PartialFailureKeepsUndone(t *testing.T)   // Apple 500 → 오류, apple identity는 미처리로 남음, 다시 부르면 처리
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/auth/` Expected: FAIL
- [ ] **Step 3: 구현.** 트랜잭션은 `pgx.BeginTxFunc` 패턴으로 쓰고 serialization 실패·deadlock(40001, 40P01)은 spec §11.3대로 최대 3번 재시도하는 helper `postgres.InTx(ctx, pool, fn)`을 `internal/platform/postgres/tx.go`에 둡니다(이 task에서 만들고 Task 9도 씀).
- [ ] **Step 4: 통과 확인** — Run: `go test -race ./internal/auth/... ./internal/platform/postgres/...` Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 로그인·삭제 대기 복구, refresh rotation과 재사용 감지, 제공자 연결 해제"`

### Task 9: 계정 서비스 (`internal/account`)

**Files:**
- Create: `server/internal/account/service.go`, `server/internal/account/documents.go`
- Test: `server/internal/account/service_test.go`

**Interfaces:**
- Consumes: Task 4 `accountdb`, Task 8 `postgres.InTx`
- Produces:
  - `type Document string; const Terms Document = "terms"; const Privacy Document = "privacy"`
  - `var CurrentDocuments = map[Document]string{Terms: "1", Privacy: "1"}` (`documents.go`). 문서 버전을 올리는 것은 코드 변경과 배포입니다.
  - `type Status string` (`active`, `pending_deletion`, `deleted`)
  - `type Access struct { Status Status; DeletionScheduledAt *time.Time; ConsentRequired bool }`
  - `type ConsentDocument struct { Document Document; Version string }`
  - `type Me struct { AccountID uuid.UUID; Access; RequiredConsents []ConsentDocument }` — 프로필 유무와 권한은 P3·P7이 채우므로 담지 않습니다.
  - `var ErrNotFound`, `type ConsentVersionMismatchError struct { Index int }`(`Error()`)
  - `type SessionEnder interface { RevokeAllSessions(ctx, uuid.UUID) error; DisconnectProviders(ctx, uuid.UUID) error }` — `*auth.Service`가 만족합니다.
  - `func NewService(pool *pgxpool.Pool, sessions SessionEnder, clk clock.Clock, logger *slog.Logger) *Service`
  - `func (s *Service) Access(ctx, id uuid.UUID) (Access, error)` — 요청마다 부릅니다. `last_active_at`이 now−24h보다 이전이면 갱신(spec §3.3 "하루 1번까지"). `DeletionScheduledAt = deletion_requested_at + 30일`. `ConsentRequired`는 `CurrentDocuments`의 (문서, 버전) 중 동의 기록이 없는 것이 있으면 true.
  - `func (s *Service) Me(ctx, id uuid.UUID) (Me, error)` — `RequiredConsents`는 아직 동의하지 않은 현재 버전 문서, 문서 이름 순.
  - `func (s *Service) AgreeConsents(ctx, id uuid.UUID, docs []ConsentDocument) error` — 버전이 `CurrentDocuments`와 다른 항목이 있으면 아무것도 저장하지 않고 첫 항목의 `ConsentVersionMismatchError`. 같은 문서를 다시 동의하면 그대로 성공.
  - `func (s *Service) RequestDeletion(ctx, id uuid.UUID) (time.Time, error)` — `active`면 `pending_deletion`으로 바꿔 commit한 뒤 `RevokeAllSessions`, `DisconnectProviders`를 부르고, 실패는 경고 로그만 남깁니다(계정 id와 오류 타입). 이미 `pending_deletion`이면 바꾸지 않고 기존 예정일. 반환값은 예정일(요청 시각 + 30일).

- [ ] **Step 1: 실패하는 테스트 작성**

```go
func TestAccess_NewAccountRequiresConsent(t *testing.T)
func TestAccess_TouchesLastActiveAtMostOncePerDay(t *testing.T) // +23h → 그대로, +24h+1s → 갱신
func TestMe_ListsOnlyMissingCurrentDocuments(t *testing.T)      // terms만 동의 → [privacy "1"]
func TestAgreeConsents_AllCurrentClearsRequirement(t *testing.T)
func TestAgreeConsents_StaleVersionStoresNothing(t *testing.T)  // [terms "1", privacy "0"] → ConsentVersionMismatchError{Index:1}, terms도 저장 안 됨
func TestAgreeConsents_BumpedVersionRequiresAgain(t *testing.T) // CurrentDocuments를 테스트에서 바꿔 끼우고 원복
func TestRequestDeletion_SchedulesAndEndsSessions(t *testing.T) // 상태 pending, 반환 = now+30일, 가짜 SessionEnder 두 함수 호출됨
func TestRequestDeletion_IsIdempotent(t *testing.T)             // 두 번째 호출: 같은 예정일, SessionEnder 다시 안 부름
func TestRequestDeletion_SessionEndFailureStillSchedules(t *testing.T) // DisconnectProviders 오류 → nil, 상태 pending, 경고 로그
func TestAccess_UnknownAccountIsNotFound(t *testing.T)
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/account/` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 계정 접근 상태, 약관 동의, 삭제 예약"`

### Task 10: bearer 인증과 동의·상태 관문 (`httpapi`)

P1 메모의 "인증 위치"입니다. bearer 라우트는 **인증 → 계약 검증 → 핸들러** 순서라 "토큰 없음 + 잘못된 본문"이 400 필드 상세보다 401을 먼저 받습니다.

**Files:**
- Create: `server/internal/httpapi/auth.go`
- Modify: `server/internal/httpapi/register.go`, `server/internal/httpapi/validate.go`(`AuthenticationFunc` 주석), 기존 테스트의 `RegisterAPI` 호출
- Test: `server/internal/httpapi/auth_test.go`

**Interfaces:**
- Consumes: Task 5 `token.ErrAccessExpired`·`ErrAccessInvalid`, Task 9 `account.Access`·`ErrNotFound`
- Produces:
  - `type Operation struct { ID string; Bearer bool }`
  - `type Routes struct { Spec *openapi3.T; Validate func(http.Handler) http.Handler; Authenticate func(op Operation, next http.Handler) http.Handler }`
  - `func RegisterAPI(mux *http.ServeMux, impl gen.StrictServerInterface, deps Deps, routes Routes)` — 생성 코드가 넘기는 pattern(`"GET /v1/me"`)을 계약의 (method, path)와 맞춰 `Operation`을 찾고, `Bearer`면 `Authenticate(op, Validate(h))`, 아니면 `Validate(h)`. 계약에 없는 pattern이면 panic(시작 시점 버그).
  - `type AccessTokenVerifier interface { Verify(token string) (uuid.UUID, error) }`, `type AccountGate interface { Access(ctx, uuid.UUID) (account.Access, error) }`
  - `func BearerAuth(tokens AccessTokenVerifier, gate AccountGate, logger *slog.Logger) func(op Operation, next http.Handler) http.Handler`
    - `Authorization` 헤더 scheme은 대소문자를 가리지 않습니다(RFC 9110 §11.1). 없거나 형식이 틀림 → 401 `auth.token_invalid`, 만료 → 401 `auth.token_expired`. 모두 `WriteBearerChallenge`.
    - 계정 없음 → 401 `auth.token_invalid`. `deleted` → 401 `auth.token_invalid`.
    - `pending_deletion`이면 `getMe`·`deleteMe`·`logout`만 통과, 그 밖은 401 `auth.token_invalid`.
    - `ConsentRequired`면 `getMe`·`agreeConsents`·`logout`·`deleteMe`만 통과, 그 밖은 403 `consent.required`.
    - 통과하면 ctx에 계정 id와 `account.Access`를 넣습니다: `func AccountFrom(ctx) (uuid.UUID, account.Access, bool)`.
    - gate가 DB 오류를 내면 Task 3의 `writeHandlerError`와 같은 규칙(503·500)으로 씁니다.
  - 테스트 helper: 기존 `newAPIHandler`는 `Authenticate`에 고정 계정을 넣는 통과 함수를 써서 P1 테스트를 바꾸지 않습니다.

- [ ] **Step 1: 실패하는 테스트 작성** (가짜 verifier·gate)

```go
func TestBearer_MissingTokenWithInvalidBodyIs401(t *testing.T)   // POST /v1/me/consents, 토큰 없음, 본문 {} → 401 auth.token_invalid, WWW-Authenticate 있음, errors 없음
func TestBearer_ExpiredTokenIs401Expired(t *testing.T)
func TestBearer_SchemeIsCaseInsensitive(t *testing.T)            // "bearer x" 통과
func TestBearer_PublicRoutesSkipAuthentication(t *testing.T)     // POST /v1/auth/refresh 토큰 없이 501(미구현), getHealth 200
func TestBearer_ConsentRequiredBlocksOtherOperations(t *testing.T) // GET /v1/chart → 403 consent.required, GET /v1/me → 통과
func TestBearer_PendingDeletionAllowsOnlyMeDeleteLogout(t *testing.T) // GET /v1/chart → 401 auth.token_invalid, GET /v1/me·DELETE /v1/me·POST /v1/auth/logout 통과 (Review Focus 3)
func TestBearer_DeletedOrUnknownAccountIs401(t *testing.T)
func TestBearer_GateDBDownIs503(t *testing.T)
func TestRegisterAPI_EveryBearerOperationIsGuarded(t *testing.T) // 계약에서 security가 bearerAuth인 모든 operation을 토큰 없이 부르면 401
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/httpapi/` Expected: FAIL
- [ ] **Step 3: 구현.** `ValidateRequests`의 `AuthenticationFunc`는 그대로 통과 함수로 두고, bearer는 앞 단계 `BearerAuth`가, `appCheck`는 P6이 맡는다고 주석을 고칩니다.
- [ ] **Step 4: 통과 확인** — Run: `go test ./internal/httpapi/...` Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): bearer 인증을 계약 검증 앞에 두고 동의·삭제 대기 관문"`

### Task 11: 인증·계정 핸들러

**Files:**
- Create: `server/internal/httpapi/api.go`, `server/internal/httpapi/auth_handlers.go`, `server/internal/httpapi/me_handlers.go`
- Test: `server/internal/httpapi/auth_handlers_test.go`, `server/internal/httpapi/me_handlers_test.go`

**Interfaces:**
- Consumes: Task 8 `auth.Service` 메서드, Task 9 `account.Service` 메서드, Task 10 `AccountFrom`
- Produces:
  - `type AuthService interface { LoginKakao(...); LoginApple(...); Refresh(...); Logout(...) }`, `type AccountService interface { Me(...); AgreeConsents(...); RequestDeletion(...) }` — Task 8·9의 signature 그대로.
  - `type API struct { Unimplemented; Auth AuthService; Accounts AccountService; DB *pgxpool.Pool; AppleCallbackDeepLink string }` — `gen.StrictServerInterface` 구현.
  - `loginKakao`·`loginApple` → 200 `LoginResponse`(`consentRequired`는 `Accounts.Me`로 채움). `refreshToken` → 200 `TokenPair`. `logout` → 204.
  - `appleCallback` → 303, `Location`은 `AppleCallbackDeepLink`에 쿼리를 붙인 값. `error`가 있으면 `error`·`state`만, 없으면 `code`·`id_token`·`state`, 그리고 `user`가 있으면 `user`. `error`도 `code`·`id_token` 쌍도 없으면 400 `request.invalid`, `errors`에 빠진 필드(`/code`, `/id_token`)와 code `required`. 받은 값은 로그에 남기지 않습니다.
  - `getMe` → 200 `Me`. `hasProfile: false`, `adFree: {active:false}`, `insight: {active:false}`로 고정합니다(P3·P7이 채움). `deletionScheduledAt`은 `pending_deletion`일 때만.
  - `agreeConsents` → 204. `ConsentVersionMismatchError{Index:i}` → `&Error{422, "consent.version_mismatch", ..., Errors: [{"/documents/<i>/version", "consent.version_mismatch"}]}`.
  - `deleteMe` → 202 `DeletionScheduled`.
  - `getHealth` → DB ping(1초) 성공 200, 실패 503 `service.unavailable`.

- [ ] **Step 1: 실패하는 테스트 작성** (`httptest`로 계약 응답 검증: 응답을 `openapi3filter.ValidateResponse`로 확인하는 helper `expectContractResponse` 추가)

```go
func TestLoginKakao_ReturnsLoginResponse(t *testing.T)          // 계약 응답 스키마 통과, consentRequired true(새 계정)
func TestLoginKakao_ProviderInvalidIs401WithoutChallenge(t *testing.T) // auth.provider_token_invalid, WWW-Authenticate 없음
func TestLoginApple_PassesClientType(t *testing.T)              // clientType web → provider.AppleWeb
func TestRefreshToken_ReuseIs401RefreshReused(t *testing.T)
func TestLogout_Returns204(t *testing.T)
func TestAppleCallback_RedirectsWithCodeAndUser(t *testing.T)   // 303, Location 쿼리 code·id_token·state·user, URL 인코딩
func TestAppleCallback_CancellationRedirectsWithError(t *testing.T) // form error=user_cancelled_authorize&state=s → 303, 쿼리 error·state만 (Review Focus 4)
func TestAppleCallback_NeitherErrorNorCodeIs400(t *testing.T)   // state만 → 400, errors에 "/code"·"/id_token"
func TestGetMe_PendingDeletionShowsSchedule(t *testing.T)
func TestAgreeConsents_StaleVersionIs422WithPointer(t *testing.T) // errors == [{"/documents/1/version","consent.version_mismatch"}]
func TestDeleteMe_Returns202WithSchedule(t *testing.T)
func TestGetHealth_DBDownIs503(t *testing.T)
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/httpapi/ -run 'Login|Refresh|Logout|AppleCallback|GetMe|AgreeConsents|DeleteMe|GetHealth'` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Run: `go test ./internal/httpapi/...` Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat(server): 로그인·갱신·로그아웃·Apple 콜백과 /v1/me 핸들러"`

### Task 12: serve 조립과 처음부터 끝까지 흐름

**Files:**
- Modify: `server/internal/cli/serve.go`
- Test: `server/internal/cli/serve_test.go`, `server/internal/cli/auth_flow_test.go`

**Interfaces:**
- Consumes: Task 5~11 전부
- Produces: `runServe`가 `AuthConfig`로 키를 파싱하고(`token.ParseSigningKey`, `secretbox.ParseKey`, Apple .p8은 PKCS8 EC 키) `provider`·`auth.Service`·`account.Service`·`API`·`BearerAuth`를 조립합니다. 키 파싱 실패는 시작 실패(종료 코드 1, 로그에 변수 이름만). 외부 HTTP client는 하나를 만들어 나눠 쓰고 Timeout 5초.
- 테스트용 조립 함수 `newServer(cfg, authCfg, pool, httpClient, providerURLs)`를 `serve.go` 안에 두어 e2e 테스트가 `providertest` 주소를 넣을 수 있게 합니다.

- [ ] **Step 1: 실패하는 테스트 작성**

```go
// serve_test.go: TestRun_ServeStartsAndStopsOnCancel의 /v1/me 단언을 401로 바꿈
func TestAuthFlow_KakaoLoginConsentMeRefreshLogout(t *testing.T)
// providertest 카카오로 로그인 → GET /v1/chart 403 consent.required → POST /v1/me/consents(현재 버전) 204
// → GET /v1/me consentRequired false → POST /v1/auth/refresh 200 → 이전 refresh 재사용 401 auth.refresh_reused
// → 새 로그인 → POST /v1/auth/logout 204 → 그 refresh로 갱신 401 auth.token_invalid
func TestAuthFlow_DeleteThenRestoreByLogin(t *testing.T)
// Apple native 로그인 → DELETE /v1/me 202 → Apple revoke 대역이 호출됨 → 이전 refresh 401
// → 같은 subject로 다시 로그인 → restoredFromDeletion true, GET /v1/me status active
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/cli/...` Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 전체 확인** — Run: `go vet ./... && golangci-lint run && go test -race ./... && go generate ./... && git status --porcelain` Expected: 모두 통과, 마지막 출력 없음
- [ ] **Step 5: Commit** — `git commit -m "feat(server): serve에 인증·계정 조립, 로그인부터 삭제·복구까지 흐름 테스트"`

### Task 13: 결정·문서 갱신

**Files:**
- Modify: `server/docs/decisions.md`, `server/docs/plans/README.md`, `server/CLAUDE.md`

- [ ] **Step 1: 결정 추가** (`decisions.md`)
  - S15 인증 nonce: app은 제공자에게 SHA-256(원문) hex를 보내고 server에 원문을 보냅니다. 카카오·Apple이 같습니다. (Task 1)
  - S16 삭제 대기 계정: 남은 access token으로는 `getMe`·`deleteMe`·`logout`만 됩니다. refresh는 거부하고, 같은 제공자 로그인만 계정을 되돌립니다. (Task 8·10)
  - S17 데이터 접근: sqlc 생성 패키지를 도메인마다 둡니다(`internal/<domain>/<domain>db`). 업무 시각은 `Clock`에서 받아 넘깁니다.
  - S18 동의 문서 버전: `account.CurrentDocuments` 코드 상수이며, 올리면 모든 계정이 다시 동의합니다. 다른 버전으로 동의하면 422 `consent.version_mismatch`입니다.
- [ ] **Step 2: `plans/README.md`** — P2 행을 이 계획으로 연결하고 상태를 **완료**로. "다음 계획에 넘길 메모"의 P2 절을 지우고 처리하지 않은 항목을 옮깁니다: 422 `request.inconsistent`·`date.invalid` → P3(프로필)·P5(일정). P3: `getMe.hasProfile`을 채움. P7: `getMe.adFree`·`insight`를 채움. P8: 계정 삭제 때 기기 비활성(`devices`가 생기면 `RequestDeletion`에 추가), `job retention`이 `DisconnectProviders`를 재시도하고 만료 refresh token을 지움. P9: 인증 설정 17개(선택 4개 포함)를 Secret Manager에 두는 목록(`config.LoadAuth`의 이름 그대로).
- [ ] **Step 3: `server/CLAUDE.md`** — "현재 상태"와 "다음 할 일"을 P2 완료 기준으로 고칩니다.
- [ ] **Step 4: Commit** — `git commit -m "docs(server): P2 결정(S15~S18)과 다음 계획 메모"`

PR을 올린 뒤에는 app에 `kind:notice` Issue로 알립니다. 내용은 nonce 해시 규칙, Apple 콜백 deep link 쿼리(`error` 포함), `consent.version_mismatch`, 삭제 대기 계정의 요청 범위(S16)입니다. deep link 주소(`APPLE_CALLBACK_DEEPLINK`)의 scheme은 app과 정합니다.
