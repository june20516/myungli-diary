# 로그인 제공자 넷과 계정 연결·합치기 (D82) Implementation Plan

> PR C(합치기), 409 본문의 합치기 토큰, 합친 계정을 `pending_deletion`으로 두는 부분은 D85·S105·S110·S111로 바뀌었습니다. 지금 계획은 `2026-10-23-account-delete-merge-purchases.md`입니다.

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** LINE·Google 로그인, 한 계정의 제공자 연결 목록·붙이기·떼기, 두 계정 합치기(요약·실행·광고 제거권 합산)를 REST draft.14와 구현에 넣습니다.

**Architecture:** 공용 OIDC 검증을 넓혀 LINE(ES256)·Google(audience 여러 개)을 받습니다. 붙이기가 다른 계정의 연결을 만나면 해시만 저장하는 일회용 합치기 토큰을 409 본문으로 주고, 새 패키지 `internal/merge`가 한 트랜잭션에서 연결·일기·일정을 남길 계정으로 옮기고 없앨 계정을 `pending_deletion`으로 둡니다. 광고 제거권은 구매를 `merged_purchases`로 옮겨 동기화가 RevenueCat 목록과 합쳐 D61로 다시 이어 붙입니다. 계약(PR A) → 제공자·연결(PR B) → 합치기(PR C) 순으로 병합합니다.

**Tech Stack:** Go 1.27, sqlc/pgx/goose, oapi-codegen strict server, kin-openapi(계약 테스트), go-oidc v3, golang-jwt v5(대역 서명), testcontainers(`dbtest`), `clock.Clock`

**Spec:** `server/docs/specs/2026-10-22-login-providers-merge-design.md` (§ 번호는 이 spec). REST 계약 `server/api/openapi.yaml` 1.0.0-draft.13 → draft.14.

## Global Constraints

* 제공자 값은 `kakao`·`apple`·`line`·`google`(계약 enum `LoginProvider`, 닫힌 enum), DB에는 `test`가 더 있습니다. 한 계정에 같은 제공자 연결은 하나입니다(S100).
* LINE id_token: iss `https://access.line.me`, ES256, JWKS `https://api.line.me/oauth2/v2.1/certs`, aud = `LINE_CHANNEL_ID`. Google: iss `https://accounts.google.com` 또는 `accounts.google.com`, RS256, JWKS `https://www.googleapis.com/oauth2/v3/certs`, aud ∈ `GOOGLE_CLIENT_IDS`(쉼표 목록)(S99).
* nonce는 네 제공자 모두 `id_token nonce = hex(SHA-256(원문))`이고 일회용으로 기록하지 않습니다.
* 합치기 토큰: 랜덤 32바이트 base64url(패딩 없음), DB에는 SHA-256만, 수명 `MergeTicketTTL = 10 * time.Minute`, 일회용, 발급받은 bearer 계정만 씀. URL에 넣지 않습니다(S101).
* LINE·Google의 허가 취소는 server가 부르지 않습니다. 카카오 unlink·Apple revoke는 떼기·합치기 commit 뒤 한 번 시도하고 실패는 경고 로그만 남깁니다(S100).
* 합치기는 `Idempotency-Key`를 받지 않습니다. 없앨 계정은 `pending_deletion`, 연결·일기(지운 것 포함, 10편 상한 무시)·일정은 남길 계정으로, 프로필·동의·문장 선택 기록은 남길 계정 것(S102).
* 새 problem code와 상태: `auth.provider_taken` 409, `auth.identity_in_use` 409(확장 필드 `mergeToken`·`expiresAt`), `auth.identity_pending_deletion` 409, `auth.last_identity` 409, `auth.identity_not_found` 404, `merge.token_invalid` 422. 이 응답들에는 `errors[]`가 없습니다(S104).
* 로그에 id_token·nonce·subject·합치기 토큰 원문·제공자 token·호칭·출생 정보를 남기지 않습니다. 제공자 이름·단계·계정 id만 남깁니다.
* ID는 UUIDv7, 시각 `timestamptz`.
* 공개 저장소(D74): 커밋·PR·fixture에 가격·수익 수치와 비공개 경로 링크를 넣지 않습니다.
* 브랜치: PR A는 `server/d82-login-providers`. PR B·C는 앞 PR 병합 뒤 `git fetch origin && git switch -c <브랜치> --no-track origin/main && git push -u origin <브랜치> && git status -sb`(B `server/d82-identities`, C `server/d82-merge`).

## Review Focus

1. 같은 제공자 사용자를 두 계정이 동시에 붙임: 한쪽 201, 다른 쪽 409 `auth.identity_in_use`(500이 아님). Task 5에서 고정합니다.
2. 같은 합치기 토큰으로 `mergeAccounts`가 동시에 두 번 옴(두 기기·재시도): 한쪽만 200, 다른 쪽 422 `merge.token_invalid`. 데이터가 두 번 옮겨지거나 교착이 나지 않아야 합니다. Task 8에서 고정합니다.
3. 토큰을 받은 뒤 합치기 전에 그 연결을 다른 계정이 떼거나 다른 계정이 삭제를 요청함: 422 `merge.token_invalid`이고 아무것도 바뀌지 않아야 합니다. Task 8에서 고정합니다.
4. 없앨 계정의 광고 제거권 구매가 나중에 RevenueCat transfer로 남길 계정 목록에도 나타남: 기간을 두 번 세지 않아야 합니다(같은 구매 id). Task 9에서 고정합니다.
5. `keep: other`로 합친 뒤 현재 기기가 들고 있던(없앨 계정의) refresh token으로 갱신: 401 `auth.token_invalid` 계열이어야 하고, 응답의 새 토큰 쌍은 남길 계정으로 동작해야 합니다. Task 10 흐름 테스트에서 고정합니다.

---

## 결정 (plan이 정한 것)

| # | 결정 | 근거 |
| --- | --- | --- |
| P-1 | `account_merge_tickets`와 토큰 발급은 PR B(migration `00014`)에 둡니다. PR C의 `00015`는 `account_merges`·`merged_purchases`만 | 계약의 409 본문이 `mergeToken`을 요구함. spec §8을 이에 맞춰 고침 |
| P-2 | 합치기의 날짜 기록은 옮기지 않고 남길 계정에 없는 날짜만 복사(`INSERT … SELECT … ON CONFLICT DO NOTHING`)한 뒤 일기 `account_id`를 바꿉니다 | `diaries_day_fk (account_id, date)`가 날짜 기록 키 변경을 막음. spec §4.3을 이에 맞춰 고침 |
| P-3 | problem 확장 필드는 `problem.Problem`에 `MergeToken string \`json:"mergeToken,omitempty"\``·`ExpiresAt *time.Time \`json:"expiresAt,omitempty"\``, `httpapi.Error`에 같은 두 필드를 더해 씁니다 | 지금 확장 필드가 이것뿐이라 일반 map보다 단순 |
| P-4 | 떼기·합치기 뒤 허가 취소는 `auth.Service.RevokeGrant(ctx, RemovedIdentity) error` 하나로 합니다(카카오 unlink, Apple revoke, LINE·Google·test는 아무것도 안 함) | 지금 `disconnect`/`revokeApple`을 재사용 |
| P-5 | 합치기 뒤 새 세션은 `auth.Service.StartSession(ctx, accountID) (TokenPair, error)`(새 family)로 commit 뒤 발급합니다. 실패하면 500이고 app은 로그인 화면으로 갑니다 | 토큰 발급 코드를 auth 밖에 복제하지 않음. 합치기 결과는 이미 commit됨 |
| P-6 | 합치기 코드는 새 패키지 `internal/merge`(쿼리 `db/queries/merge.sql`, sqlc 패키지 `mergedb`)에 둡니다 | 연결·일기·일정·계정·billing 표를 함께 건드리는 트랜잭션이라 한 도메인 패키지에 넣지 않음 |
| P-8 | `LinkIdentityRequest`는 oneOf 없이 선택 필드 셋 + 필수 `nonce` 하나로 두고, 조합 검사는 `auth.LinkIdentity`가 `*InvalidProofError`로 돌려줍니다 | 계약에 `additionalProperties: false`가 없어 oneOf면 Apple iOS 증명이 두 갈래에 맞아 거절됨. spec §3.1·§6을 이에 맞춰 고침 |
| P-7 | LINE·Google 설정(`LINE_CHANNEL_ID`·`GOOGLE_CLIENT_IDS`)은 카카오·Apple처럼 `require`(비면 시작 실패)입니다 | spec §2.1 "지금 처리를 따름" |

---

## PR A: 계약 (draft.14)

### Task 1: REST 계약 draft.14와 생성 코드

**Files:**
- Modify: `server/api/openapi.yaml`(`info.version`, `info.description`의 nonce 규칙, 새 경로 6개, 스키마, problem code 표)
- Modify: `server/api/contract_test.go`(`expectedOperationIDs`, `TestContract_VersionIsDraft13` → `TestContract_VersionIsDraft14`, 새 테스트 2개)
- Regenerate: `server/internal/httpapi/gen/`(`go generate ./api/...`)
- Modify: `server/internal/httpapi/problem/codes.go`(새 code 6개, `AllCodes`)
- Modify: `server/internal/httpapi/unimplemented.go`(새 operation 7개)
- Modify: `server/internal/httpapi/contract_routes_test.go`(`minimalRequests`)

**Interfaces:**
- Produces (계약): operation `loginLine`(`POST /v1/auth/line`), `loginGoogle`(`POST /v1/auth/google`), `listIdentities`(`GET /v1/me/identities`), `linkIdentity`(`POST /v1/me/identities/{provider}`), `unlinkIdentity`(`DELETE /v1/me/identities/{provider}`), `previewMerge`(`POST /v1/me/merge/preview`), `mergeAccounts`(`POST /v1/me/merge`). 스키마는 spec §6 목록.
- Produces (Go): `problem.AuthProviderTaken`·`AuthIdentityInUse`·`AuthIdentityPendingDeletion`·`AuthLastIdentity`(409), `AuthIdentityNotFound`(404), `MergeTokenInvalid`(422). 생성 타입 `gen.LoginProvider`(`gen.Kakao`·`gen.Apple`·`gen.Line`·`gen.Google`), `gen.LinkIdentityRequestObject{Provider gen.LoginProvider, Body *gen.LinkIdentityRequest}`, `gen.MergeRequest{MergeToken string, Keep gen.MergeRequestKeep}`.

- [ ] **Step 1: 계약 테스트를 먼저 고침**

`api/contract_test.go`:
* `expectedOperationIDs`에 새 operation 7개.
* `TestContract_VersionIsDraft14`: `doc.Info.Version == "1.0.0-draft.14"`.
* 새 `TestContract_Draft14Identities`:
  ```go
  // loginLine·loginGoogle: security 빈 배열, 본문 required == {idToken, nonce}, 200 LoginResponse, 401·503 있음
  // LoginProvider enum == {kakao, apple, line, google}
  // listIdentities 200 스키마 IdentityList{items: []Identity}; Identity.required == {provider, linkedAt}, properties에 subject 없음
  // linkIdentity: {provider} path parameter $ref LoginProvider, 응답 200·201·400·401·409·503 있음, 409 content 스키마 $ref IdentityInUseProblem
  // IdentityInUseProblem: allOf에 Problem, properties에 mergeToken(string)·expiresAt(date-time). 둘은 auth.identity_in_use일 때만 있으므로 required가 아님
  // LinkIdentityRequest: required == {nonce}, properties == {idToken, authorizationCode, exchangeCode, nonce}, oneOf 없음
  //   (계약에 additionalProperties: false가 없어 oneOf로 나누면 Apple iOS 증명이 두 갈래에 다 맞아 거절됨)
  //   설명에 제공자별 조합: kakao·line·google은 idToken, apple은 idToken+authorizationCode(iOS) 또는 exchangeCode(Android)
  // unlinkIdentity: 204·404·409, 본문 없음
  // previewMerge: 본문 MergePreviewRequest{mergeToken}, 200 MergePreview, 422 있음
  // MergePreview.required == {current, other, overlapDayCount}; MergeAccountSummary.required == {saju, diaryCount, providers}, honorific는 선택
  // MergeSaju.status enum == {saved, none}
  // mergeAccounts: 본문 MergeRequest.required == {mergeToken, keep}, keep enum == {current, other}, 200 MergeResult{accountId, tokens}, 422·503 있음
  // mergeAccounts parameters에 Idempotency-Key 없음
  ```
* 새 `TestContract_Draft14ProblemCodes`: 표에 `auth.provider_taken`·`auth.identity_in_use`·`auth.identity_pending_deletion`·`auth.last_identity`(409), `auth.identity_not_found`(404), `merge.token_invalid`(422).
* `TestContract_LoginNonceDocumentsHashRule`(지금 카카오·Apple 확인)이 `loginLine`·`loginGoogle`·`linkIdentity`도 보게 넓힙니다. `info.description`에 "일회용으로 기록하지 않습니다"와 "Google"이 있는지도 확인합니다.

- [ ] **Step 2: 실패를 확인**

Run: `cd server && go test ./api/`
Expected: FAIL(`loginLine operation이 없음`, 버전 draft.13)

- [ ] **Step 3: `openapi.yaml`을 spec §2.2·§3·§4·§5·§6대로 고침**

* 설명은 spec 문장을 옮깁니다. `linkIdentity` 설명에 응답별 경우(spec §3.1의 다섯 줄), Apple 증명 두 모양, "409가 나면 새로 받은 Apple 승인은 저장하지 않음"을 적습니다. `unlinkIdentity` 설명: "LINE·Google의 제공자 허가는 server가 취소하지 않습니다. app이 떼기 전에 SDK로 취소합니다. 카카오·Apple은 server가 취소를 시도합니다." `mergeAccounts` 설명: spec §4.3의 옮기는 것·남기는 것, "`Idempotency-Key`를 받지 않습니다. 응답을 잃어 다시 보내면 422 `merge.token_invalid`이고, 어느 제공자로 로그인해도 남길 계정입니다", 없앨 계정의 구매 조회 실패 503 `billing.provider_unavailable`.
* `info.description` 공통 규약에 nonce 문장: "로그인과 `linkIdentity`의 nonce는 제공자에게 SHA-256 hex를, server에 원문을 보냅니다. server는 `id_token`의 `nonce`가 원문의 SHA-256 hex인지만 보고 일회용으로 기록하지 않습니다. Google은 app 프로세스마다 nonce가 하나라 같은 원문이 여러 번 올 수 있습니다."
* 새 operation의 오류 응답은 기존 `components/responses`를 씁니다. `linkIdentity`의 409만 content를 `IdentityInUseProblem`(Problem + 선택 `mergeToken`·`expiresAt`)으로 두고, 설명에 "`mergeToken`·`expiresAt`은 `auth.identity_in_use`일 때만 있습니다. `auth.provider_taken`·`auth.identity_pending_deletion`에는 없습니다"를 적습니다.
* `LinkIdentityRequest` 설명: 제공자별 조합이 맞지 않으면(필요한 필드가 없거나 그 제공자가 쓰지 않는 필드가 있음) 400 `request.invalid`이고, `errors[]`는 없는 필드 `{field: "/idToken", code: "required"}`, 쓰지 않는 필드 `{field: "/exchangeCode", code: "additionalProperties"}` 꼴입니다. Apple에 `idToken`·`authorizationCode`와 `exchangeCode`가 함께 오면 `exchangeCode`가 쓰지 않는 필드입니다.
* bearer operation 5개는 기본 security. 동의 전 403은 기존 공통 설명을 따릅니다.

- [ ] **Step 4: 계약 테스트 통과 확인**

Run: `cd server && go test ./api/`
Expected: PASS

- [ ] **Step 5: 생성 코드와 컴파일 맞추기**

`go generate ./api/...` 뒤 `problem/codes.go`에 새 code 6개(`AllCodes`의 상태별 줄), `unimplemented.go`에 7개 메서드(`ErrNotImplemented`), `contract_routes_test.go` `minimalRequests`에:
`"loginLine": {POST, "/v1/auth/line", json, {"idToken":"x","nonce":"n"}}`, `"loginGoogle"` 같은 모양, `"listIdentities": {GET, "/v1/me/identities"}`, `"linkIdentity": {POST, "/v1/me/identities/line", json, {"idToken":"x","nonce":"n"}}`, `"unlinkIdentity": {DELETE, "/v1/me/identities/line"}`, `"previewMerge": {POST, "/v1/me/merge/preview", json, {"mergeToken":"t"}}`, `"mergeAccounts": {POST, "/v1/me/merge", json, {"mergeToken":"t","keep":"current"}}`.

- [ ] **Step 6: 계약 검사 전체**

Run: `cd server && go generate ./... && git status --porcelain && go test -race ./api/ && go test -race -run 'TestRegisterAPI_|TestProblemCodes_|TestContractRoutes' ./internal/httpapi/`
Expected: 이 task가 바꾼 파일만 바뀌고 PASS

- [ ] **Step 7: Commit**

```bash
git add server/api server/internal/httpapi
git commit -m "feat(server): 로그인 제공자·계정 연결·합치기 계약 draft.14 (D82, #386)"
```

### Task 2: 결정·spec·계약 표, app·지휘 Issue, PR A

**Files:**
- Modify: `server/docs/decisions.md`(S99~S104)
- Modify: `server/docs/specs/2026-10-11-server-mvp-design.md`(§4 인증에 "D82로 넷, `2026-10-22-login-providers-merge-design.md`", §11.2 problem code 표에 새 code 6개)
- Modify: `docs/contracts/README.md`(REST 행 `1.0.0-draft.14`)
- Create: `server/docs/plans/2026-10-22-login-providers-merge.md`(이 문서)

- [ ] **Step 1: 결정 S99~S104**

spec §10 표의 문장을 `decisions.md` 표 형식(`| S99 | 2026-10-22 | 인증 | … | spec 2026-10-22-login-providers-merge §2 |`)으로 넣습니다. 분류: S99·S100·S101 인증, S102 데이터, S103 결제, S104 API.

- [ ] **Step 2: 계약 표 행**

REST 행 버전 칸 `1.0.0-draft.14`, 상태 칸 끝에 덧붙임: "draft.14: 추가만(D82, #386, S99~S104). `loginLine`·`loginGoogle`, 연결 `listIdentities`·`linkIdentity`·`unlinkIdentity`(`/v1/me/identities/{provider}`), 합치기 `previewMerge`·`mergeAccounts`(`/v1/me/merge`, 일회용 합치기 토큰은 `linkIdentity` 409 `auth.identity_in_use` 본문), nonce 일회용 기록 없음(Google 반복 가능), 새 problem code 6개(app 요청 #<Step 4 번호>)."

- [ ] **Step 3: 공개 저장소 확인과 commit**

Run: `git diff origin/main... | grep -nE '[0-9][0-9,]*원|₩|\$[0-9]|myungli-diary-internal'`
Expected: 출력 없음

```bash
git add server/docs docs/contracts/README.md
git commit -m "docs(server): 로그인 제공자·합치기 결정 S99~S104, 계약 표 draft.14"
```

- [ ] **Step 4: Issue 셋과 PR**

* app 앞 `kind:request`(`--label from:server,to:app,kind:request --milestone S3`): 제목 "[server→app] REST draft.14: LINE·Google 로그인, 계정 연결·합치기 (D82)". 본문: 새 operation 7개와 스키마, 붙이기 증명 모양(Android Apple은 `{exchangeCode, nonce}`), 409 `auth.identity_in_use`의 `mergeToken`(10분, 일회용) → `previewMerge`(소진 안 함) → `mergeAccounts`, LINE·Google 허가 취소는 app이 떼기·계정 삭제 직전에 SDK로(그 기기에 제공자 token이 없으면 생략), 합치기 응답을 잃으면 로그인 화면으로, 새 problem code 6개, nonce 규칙, 참고 #386·#387.
* 지휘 앞(`--label from:server,to:root,kind:request`): 제목 "[server→root] D82 ⑤ 단서: LINE·Google 허가 취소는 app이 함". 본문: LINE deauthorize·Google revoke가 사용자 제공자 token을 요구하고 server는 갖지 않는다는 사실, 사용자 결정(2026-10-22, server 세션), ⑤에 더할 문장 "LINE·Google은 app이 떼기·계정 삭제 직전에 SDK로 허가 취소를 하고, 그 기기에 제공자 token이 없으면 생략합니다(server spec S100)".
* #386 코멘트: spec 경로, PR 셋 나눔, 위 두 Issue 번호.
* app Issue 번호를 Step 2의 `<Step 4 번호>`에 채워 새 commit.

`git merge origin/main` → `git push -u origin server/d82-login-providers` → `gh pr create`. 본문: 요약, 검사 결과, `참고 #386`.

---

## PR B: 제공자·연결 (`server/d82-identities`)

### Task 3: LINE·Google verifier와 설정

**Files:**
- Modify: `server/internal/auth/provider/oidc.go`(`newVerifier`에 `algs []string` 매개변수)
- Modify: `server/internal/auth/provider/kakao.go`, `apple.go`(`newVerifier` 호출에 `[]string{oidc.RS256}`)
- Create: `server/internal/auth/provider/line.go`, `server/internal/auth/provider/google.go`
- Modify: `server/internal/auth/provider/providertest/providertest.go`(ES256 키, LINE·Google 설정·claims·생성자)
- Create: `server/internal/auth/provider/line_test.go`, `server/internal/auth/provider/google_test.go`
- Modify: `server/internal/auth/provider/oidc_test.go`(`TestNewLINE_RejectsMissingRequiredConfig`, `TestNewGoogle_RejectsMissingRequiredConfig`)
- Modify: `server/internal/platform/config/config.go`·`config_test.go`(`LineChannelID`, `GoogleClientIDs []string`)
- Modify: `server/internal/cli/serve.go`·`serve_test.go`(`ProviderURLs`에 `LineJWKS`·`GoogleJWKS`, verifier 조립)

**Interfaces:**
- Produces: `provider.LINEConfig{ChannelID, Issuer, JWKSURL string; HTTP *http.Client; Clock clock.Clock}`, `provider.NewLINE(LINEConfig) (*provider.LINE, error)`, `(*LINE).Verify(ctx, idToken, rawNonce string) (Identity, error)`. 상수 `DefaultLINEIssuer = "https://access.line.me"`, `DefaultLINEJWKSURL = "https://api.line.me/oauth2/v2.1/certs"`.
- Produces: `provider.GoogleConfig{ClientIDs []string; JWKSURL string; HTTP *http.Client; Clock clock.Clock}`, `provider.NewGoogle(GoogleConfig) (*provider.Google, error)`, `(*Google).Verify(ctx, idToken, rawNonce string) (Identity, error)`. 상수 `DefaultGoogleJWKSURL = "https://www.googleapis.com/oauth2/v3/certs"`, 받는 iss `GoogleIssuers = []string{"https://accounts.google.com", "accounts.google.com"}`.
- Produces (providertest): `LINEChannelID = "1650000000"`, `GoogleClientIDs = []string{"test-ios.apps.googleusercontent.com", "test-web.apps.googleusercontent.com"}`, `(*Server).LINEConfig(clk)`, `GoogleConfig(clk)`, `NewLINE(t, clk)`, `NewGoogle(t, clk)`, `LINEClaims(subject, rawNonce string, now time.Time) map[string]any`, `GoogleClaims(subject, rawNonce, aud, iss string, now time.Time) map[string]any`, `(*Server).SignES256IDToken(claims) string`(JWKS에 EC 공개 키도 실음).
- Produces (config): `cfg.LineChannelID string`(`require("LINE_CHANNEL_ID")`), `cfg.GoogleClientIDs []string`(`GOOGLE_CLIENT_IDS`를 쉼표로 나누고 공백 제거, 빈 항목 제외, 결과가 비면 필수 누락 오류).

- [ ] **Step 1: 실패하는 provider 테스트**

`line_test.go`:
* `TestLINE_VerifyAcceptsValidES256Token`: `SignES256IDToken(LINEClaims("U1", "raw", now))` → `Identity{Subject: "U1"}`.
* `TestLINE_VerifyRejectsWrongAudienceIssuerNonceExpiryAndRS256`: aud `"other"`, iss `"https://example.com"`, nonce 해시 다름, exp 지남, RS256으로 서명 → 모두 `errors.Is(err, provider.ErrTokenInvalid)`.
* `TestLINE_JWKSFailureIsUnavailable`: `SetJWKSStatus(500)` → `ErrUnavailable`.

`google_test.go`:
* `TestGoogle_VerifyAcceptsBothIssuerForms`: iss `"https://accounts.google.com"`와 `"accounts.google.com"` 둘 다 통과.
* `TestGoogle_VerifyAcceptsEveryConfiguredAudience`: `GoogleClientIDs[0]`·`[1]` 둘 다 통과.
* `TestGoogle_VerifyRejectsUnknownAudienceIssuerNonce`: aud `"other.apps.googleusercontent.com"`, iss `"https://evil.example"`, nonce 다름 → `ErrTokenInvalid`.
* `TestGoogle_VerifyAcceptsRepeatedNonce`: 같은 원문 nonce의 두 토큰이 둘 다 통과(일회용 기록 없음).

`oidc_test.go`: `NewLINE(LINEConfig{})`·`NewGoogle(GoogleConfig{})`가 오류이고 문구에 `ChannelID`·`ClientIDs`가 있음. 기존 `TestVerify_RejectsNonRS256`은 카카오 기준 그대로 통과해야 합니다.

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test ./internal/auth/provider/...`
Expected: FAIL(`undefined: provider.NewLINE` 등)

- [ ] **Step 3: 구현**

* `newVerifier(issuer, audience string, algs []string, keySet, clk)`. LINE은 `[]string{oidc.ES256}`.
* Google은 go-oidc `oidc.Config{SkipClientIDCheck: true, SkipIssuerCheck: true, SupportedSigningAlgs: []string{oidc.RS256}, Now: clk.Now}`로 서명·exp를 검증한 뒤 `slices.Contains(GoogleIssuers, token.Issuer)`와 `token.Audience` 중 하나가 `ClientIDs`에 있는지 확인하고, 아니면 `ErrTokenInvalid`. nonce는 `nonceMatches`. 공용 `verifyIDTokenClaims`·`nonceMatches`를 재사용합니다.
* providertest: 기존 RSA 키 옆에 P-256 키 하나(`kid` 고정 `"providertest-es256"`), `serveJWKS`가 두 키를 모두 냅니다.

- [ ] **Step 4: 설정과 조립 테스트**

`config_test.go`: `GOOGLE_CLIENT_IDS=" a , b ,"` → `[]string{"a", "b"}`; `LINE_CHANNEL_ID` 없음 → 필수 누락 오류에 이름이 있음; `GOOGLE_CLIENT_IDS=" , "` → 필수 누락. `serve_test.go`의 환경 fixture에 두 값을 더하고 `ProviderURLs{LineJWKS, GoogleJWKS}`를 대역으로 채웁니다. 조립은 Task 4가 `auth.ServiceDeps`에 넣으므로 이 task에서는 verifier 생성까지(생성 실패가 `provider line:`·`provider google:` 접두 오류)입니다.

- [ ] **Step 5: 통과 확인**

Run: `cd server && go test -race ./internal/auth/provider/... ./internal/platform/config/ ./internal/cli/ -run 'Provider|Config|LINE|Google|Serve'`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add server/internal/auth/provider server/internal/platform/config server/internal/cli
git commit -m "feat(server): LINE·Google id_token 검증과 설정 (S99)"
```

### Task 4: migration 00014, LINE·Google 로그인, 계정 삭제 해제

**Files:**
- Create: `server/db/migrations/00014_identities_multi.sql`
- Modify: `server/db/migrate_test.go`(00014 테스트, D83 선례), migration 개수 기대 13 → 14(`migrate_test.go`, `internal/cli/cli_test.go`)
- Modify: `server/db/queries/auth.sql`(아래 쿼리), regenerate `internal/auth/authdb`
- Modify: `server/internal/auth/service.go`(`ServiceDeps.Line`·`Google`, `LoginLine`·`LoginGoogle`, 상수 `providerLine = "line"`, `providerGoogle = "google"`)
- Modify: `server/internal/auth/disconnect.go`(`disconnect`가 `line`·`google`은 외부 호출 없이 성공)
- Modify: `server/internal/auth/service_test.go`, `disconnect_test.go`
- Modify: `server/internal/cli/serve.go`(Task 3 verifier를 deps에)

**Interfaces:**
- Consumes: Task 3 `*provider.LINE`, `*provider.Google`.
- Produces: `auth.IDTokenVerifier interface{ Verify(ctx context.Context, idToken, rawNonce string) (provider.Identity, error) }`(`KakaoVerifier`를 이 이름의 별칭으로 둠), `ServiceDeps{…, Line, Google IDTokenVerifier}`, `(*Service).LoginLine(ctx, idToken, rawNonce string) (LoginResult, error)`, `LoginGoogle` 같은 signature.
- Produces (migration): `auth_identities_provider_check`가 `('kakao','apple','test','line','google')`, `auth_identities_line_google_without_apple CHECK (provider NOT IN ('line','google') OR apple_refresh_token IS NULL)`, `auth_identities_account_provider_key UNIQUE (account_id, provider)`, 표 `account_merge_tickets`(spec §4.1 열 그대로, `identity_id` FK ON DELETE CASCADE, `account_id`·`other_account_id` FK ON DELETE RESTRICT, 인덱스 `account_merge_tickets_expires_at_idx (expires_at)`).

- [ ] **Step 1: 실패하는 테스트**

* `migrate_test.go` `TestMigration00014_IdentitiesMulti`: `line`·`google` 연결 insert 성공, `('line', apple_refresh_token 있음)` CHECK 위반, 같은 계정에 `kakao` 둘 → `auth_identities_account_provider_key` 위반, `account_merge_tickets`에 행을 넣고 그 연결을 지우면 토큰 행도 사라짐. Down 뒤 `line` 행이 없으면 되돌아감(00011 Down과 같은 방식).
* `service_test.go` `TestLoginLine_CreatesAccountThenReusesIt`, `TestLoginGoogle_CreatesAccountThenReusesIt`: 첫 로그인 `IsNewAccount` true, 두 번째 false·같은 `AccountID`; 연결 행 `provider`가 `line`/`google`.
* `TestLoginGoogle_ProviderErrorsMapToSentinels`: 대역 aud 틀림 → `ErrProviderTokenInvalid`, JWKS 500 → `ErrProviderUnavailable`.
* `disconnect_test.go` `TestDisconnectProviders_LINEGoogleRecordWithoutExternalCall`: 삭제 대기 계정의 `line`·`google` 연결이 `provider_disconnected_at`을 갖고, 대역의 카카오 unlink·Apple revoke 요청 수는 0.

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test ./db/ ./internal/auth/...`
Expected: FAIL

- [ ] **Step 3: 구현**

migration Up은 위 Produces. Down: `account_merge_tickets` 삭제, UNIQUE·CHECK 제거, provider CHECK를 `('kakao','apple','test')`로(`line`·`google` 행이 있으면 실패하는 것은 00011 Down 주석과 같은 규칙으로 적음). `LoginLine`·`LoginGoogle`은 `LoginKakao`와 같은 흐름(`providerError(ctx, err, providerLine, "verify")`).

- [ ] **Step 4: 통과 확인**

Run: `cd server && go generate ./... && go test -race ./db/ ./internal/auth/... ./internal/cli/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/db server/internal/auth server/internal/cli
git commit -m "feat(server): LINE·Google 로그인, 연결 제약과 합치기 토큰 표 (migration 00014)"
```

### Task 5: 연결 목록·붙이기·떼기 서비스

**Files:**
- Create: `server/internal/auth/identities.go`, `server/internal/auth/identities_test.go`
- Modify: `server/db/queries/auth.sql`(아래 쿼리), regenerate
- Modify: `server/internal/auth/errors.go`(새 sentinel과 `IdentityInUseError`)
- Modify: `server/internal/auth/disconnect.go`(`RevokeGrant` 추출, P-4)
- Modify: `server/internal/auth/apple_web.go`(교환 코드 소진을 로그인·붙이기가 함께 쓰게 `prepareLogin`을 재사용)

**Interfaces:**
- Consumes: Task 4 표·제약, `appleGrant`, `fixedTarget`·교환 코드 `prepareLogin`.
- Produces:
  ```go
  const MergeTicketTTL = 10 * time.Minute

  type LinkedIdentity struct { Provider string; LinkedAt time.Time }
  type LinkProof struct { IDToken, RawNonce, AuthorizationCode, ExchangeCode string }
  type LinkResult struct { Created bool }
  type IdentityInUseError struct { MergeToken string; ExpiresAt time.Time } // Error() 문구에 토큰을 넣지 않음
  type RemovedIdentity struct {
      ID, AccountID uuid.UUID
      Provider, Subject string
      AppleRefreshToken []byte
      AppleTokenKeyID, AppleClientID string
  }
  var ErrProviderTaken, ErrIdentityPendingDeletion, ErrLastIdentity, ErrIdentityNotFound error
  // ErrInvalidProof는 제공자별 증명 조합이 틀림. 어느 필드가 문제인지 담는 *InvalidProofError로 돌려주고 errors.Is(err, ErrInvalidProof)가 참
  type InvalidProofError struct { Field, Code string } // Field는 JSON Pointer("/idToken"), Code는 "required"·"additionalProperties"
  var ErrInvalidProof error

  func (s *Service) ListIdentities(ctx context.Context, accountID uuid.UUID) ([]LinkedIdentity, error)
  func (s *Service) LinkIdentity(ctx context.Context, accountID uuid.UUID, providerName string, proof LinkProof) (LinkResult, error)
  func (s *Service) UnlinkIdentity(ctx context.Context, accountID uuid.UUID, providerName string) error
  func (s *Service) RevokeGrant(ctx context.Context, removed RemovedIdentity) error
  ```
  `providerName`은 `"kakao"`·`"apple"`·`"line"`·`"google"`. Apple 증명은 `ExchangeCode`가 있으면 웹 흐름, 없으면 iOS(`IDToken`·`AuthorizationCode`)이고, 둘 다 있거나 필요한 값이 비면 `ErrProviderTokenInvalid`가 아니라 `ErrInvalidProof`(새 sentinel, httpapi가 400 `request.invalid`로 매핑).
- 쿼리: `ListAccountIdentities`(provider, created_at 순), `GetIdentityForLink`(`(provider, subject)`의 연결과 계정 status, 계정 행 잠금), `AccountHasProvider`, `CountIdentities`, `DeleteIdentity`(지운 행의 Apple 열을 RETURNING), `InsertMergeTicket`.

- [ ] **Step 1: 실패하는 테스트 (testcontainers, 대역 provider)**

* `TestLinkIdentity_CreatesWhenFree`: 카카오 계정에 LINE 붙이기 → `Created` true, `ListIdentities`가 `[kakao, line]`(붙인 순).
* `TestLinkIdentity_IsIdempotentForOwnIdentity`: 같은 LINE 증명 두 번 → 두 번째 `Created` false, 연결 수 그대로. Apple iOS로 같은 계정의 Apple을 다시 붙이면 refresh token이 새 값으로 바뀜.
* `TestLinkIdentity_ProviderTaken`: 계정에 LINE `U1`이 있는데 LINE `U2` 붙이기 → `ErrProviderTaken`.
* `TestLinkIdentity_InUseIssuesMergeTicket`: 다른 active 계정의 LINE `U1` 붙이기 → `errors.As(err, &inUse)`, `inUse.MergeToken`이 base64url 43자, `ExpiresAt == now + 10m`(마이크로초 절사), `account_merge_tickets`에 `token_hash = sha256(token)`, `account_id` = 현재, `other_account_id` = 다른 계정 행. 원문은 DB 어디에도 없음.
* `TestLinkIdentity_InUseDiscardsNewAppleGrantWithoutRevoke`: Apple iOS 붙이기가 in-use → 대역 revoke 요청 0, 다른 계정의 Apple refresh token 그대로.
* `TestLinkIdentity_PendingDeletionOwner`: 다른 계정이 삭제 대기 → `ErrIdentityPendingDeletion`, 토큰 행 없음.
* `TestLinkIdentity_ConcurrentLinkOfSameIdentity` (Review Focus 1): 두 계정이 같은 Google `G1`을 동시에 붙임(barrier로 동시 시작) → 하나는 `Created` true, 다른 하나는 `*IdentityInUseError`.
* `TestLinkIdentity_InvalidProofCombinations`: LINE에 `IDToken` 없음 → `InvalidProofError{"/idToken","required"}`; LINE에 `AuthorizationCode` 있음 → `{"/authorizationCode","additionalProperties"}`; Apple에 `IDToken`만 → `{"/authorizationCode","required"}`; Apple에 iOS 두 값과 `ExchangeCode` → `{"/exchangeCode","additionalProperties"}`. 모두 제공자 대역 호출 0.
* `TestLinkIdentity_AppleWebExchangeCode`: `BeginAppleWebLogin`으로 만든 교환 코드 + nonce로 붙이기 → 연결 생성, 코드 소진; 틀린 nonce → `ErrExchangeInvalid`이고 코드는 소진되지 않음.
* `TestUnlinkIdentity_RemovesAndRevokesAfterCommit`: 카카오+Apple 계정에서 Apple 떼기 → 행 없음, 대역 revoke 요청 1(복호화한 refresh token). 대역 revoke가 503이어도 nil.
* `TestUnlinkIdentity_LINEGoogleNoExternalCall`: LINE 떼기 → 대역 요청 0.
* `TestUnlinkIdentity_LastAndMissing`: 연결 하나뿐 → `ErrLastIdentity`; 없는 제공자 → `ErrIdentityNotFound`.
* `TestUnlinkIdentity_ConcurrentUnlinkKeepsOne`: 연결 둘인 계정에서 두 제공자를 동시에 떼기 → 하나만 성공하고 다른 하나는 `ErrLastIdentity`(계정 행 잠금).

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test ./internal/auth/ -run 'Link|Unlink|ListIdentities'`
Expected: FAIL

- [ ] **Step 3: 구현**

* `LinkIdentity`: 제공자 검증(트랜잭션 밖, Apple iOS는 code 교환까지) → `InTx`에서 현재 계정 행 잠금 → `GetIdentityForLink` → spec §3.1 분기. 없으면 `AccountHasProvider`로 `ErrProviderTaken`을 먼저 보고 연결 insert. unique 위반(`isIdentityConflict`)이면 트랜잭션을 한 번 다시 실행합니다(그때는 in-use가 됨). in-use면 토큰을 만들어 `InsertMergeTicket` 후 commit하고 `*IdentityInUseError`를 돌려줍니다(commit 뒤 오류 반환, `Refresh`의 `reused`와 같은 방식). 새 연결이 commit되지 않은 Apple iOS grant는 지금 `revokeUnsavedAppleGrant` 규칙을 그대로 따르되, in-use는 연결 행이 있으므로 revoke하지 않습니다.
* `UnlinkIdentity`: `InTx`에서 계정 행 잠금 → `CountIdentities`·`DeleteIdentity` → commit 뒤 `RevokeGrant(context.WithoutCancel(ctx), removed)`, 실패는 `WarnContext("떼기 뒤 허가 취소 실패", "provider", …, "reason", disconnectFailureReason(err))`.
* `RevokeGrant`: `disconnect`의 분기를 `RemovedIdentity`로 받게 옮기고 `DisconnectProviders`도 이것을 씁니다.

- [ ] **Step 4: 통과 확인**

Run: `cd server && go generate ./... && go test -race ./internal/auth/...`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/db/queries/auth.sql server/internal/auth
git commit -m "feat(server): 계정 연결 목록·붙이기·떼기와 합치기 토큰 발급 (S100·S101)"
```

### Task 6: 핸들러, 오류 매핑, 흐름 테스트, PR B

**Files:**
- Create: `server/internal/httpapi/identity_handlers.go`, `identity_handlers_test.go`
- Modify: `server/internal/httpapi/auth_handlers.go`(`LoginLine`·`LoginGoogle`)
- Modify: `server/internal/httpapi/api.go`(`AuthService`에 새 메서드 6개)
- Modify: `server/internal/httpapi/errors.go`(새 sentinel 매핑, `*auth.IdentityInUseError` → 409 + 확장 필드, P-3), `problem/problem.go`(두 필드)
- Modify: `server/internal/httpapi/unimplemented.go`(5개 제거)
- Create: `server/internal/cli/identity_flow_test.go`
- Modify: `server/CLAUDE.md`(현재 상태 D82 줄, 다음 할 일)

**Interfaces:**
- Consumes: Task 4·5의 auth 메서드와 오류.
- Produces: `problem.Problem.MergeToken`·`ExpiresAt`, `httpapi.Error.MergeToken string`·`MergeExpiresAt time.Time`.

- [ ] **Step 1: 실패하는 handler 테스트(가짜 AuthService)**

* `TestLoginLine_ReturnsLoginResponse`, `TestLoginGoogle_ProviderInvalidIs401`.
* `TestListIdentities_ReturnsProvidersInOrder`: 200 `{"items":[{"provider":"kakao","linkedAt":…},{"provider":"line",…}]}`, 본문에 `subject` 없음.
* `TestLinkIdentity_StatusByResult`: `Created` true → 201, false → 200, `ErrProviderTaken` → 409 `auth.provider_taken`(`errors` 없음), `ErrIdentityPendingDeletion` → 409 `auth.identity_pending_deletion`, `*IdentityInUseError{MergeToken:"tok", ExpiresAt:t}` → 409 `auth.identity_in_use`이고 본문 `mergeToken == "tok"`, `expiresAt == t`(RFC 3339 UTC), `&auth.InvalidProofError{Field:"/exchangeCode", Code:"additionalProperties"}` → 400 `request.invalid`, `errors == [{field:"/exchangeCode", code:"additionalProperties"}]`, `ErrExchangeInvalid` → 401 `auth.exchange_invalid`.
* `TestLinkIdentity_PassesProofFields`: 본문 `{"idToken":"i","authorizationCode":"a","exchangeCode":"c","nonce":"n"}`의 네 값이 그대로 `LinkProof{IDToken:"i", AuthorizationCode:"a", ExchangeCode:"c", RawNonce:"n"}`로, 경로 제공자가 `"apple"`로 서비스에 넘어감(조합 검사는 서비스 몫).
* `TestUnlinkIdentity_Status`: nil → 204, `ErrLastIdentity` → 409 `auth.last_identity`, `ErrIdentityNotFound` → 404 `auth.identity_not_found`.
* `TestIdentityOperations_RequireConsent`: 동의 전 계정의 `listIdentities` → 403 `consent.required`.
* `errors_test.go`: 다른 Problem에는 `mergeToken`·`expiresAt` 키가 나오지 않음(`omitempty`).

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test ./internal/httpapi/ -run 'Line|Google|Identit'`
Expected: FAIL

- [ ] **Step 3: 구현**

`linkIdentity`는 본문 선택 필드를 비어 있으면 `""`로 `LinkProof`에 담아 넘깁니다. `*auth.InvalidProofError`는 `errors.As`로 꺼내 field·code를 `errors[]` 한 항목으로 씁니다. 응답의 `linkedAt`은 UTC.

- [ ] **Step 4: 조립 흐름 테스트**

`TestIdentityFlow_LinkUnlinkAndInUse`(실제 serve 조립, 대역 provider): 카카오 로그인 → 동의 → `linkIdentity` google 201 → `listIdentities` 둘 → 두 번째 계정을 LINE으로 만들고 동의 → 첫 계정에서 그 LINE 붙이기 409 `auth.identity_in_use`(`mergeToken` 있음) → `unlinkIdentity` google 204 → `unlinkIdentity` kakao 409 `auth.last_identity`. `previewMerge`·`mergeAccounts`는 아직 501.

- [ ] **Step 5: 전체 검사**

Run: `cd server && go generate ./... && git status --porcelain && go vet ./... && go vet -tags staging ./... && golangci-lint run ./... && golangci-lint run --build-tags staging ./... && go test -race -count=1 ./...`
Expected: 생성 차이 없음, 0 issues, FAIL 0

- [ ] **Step 6: 현재 상태와 commit, PR B**

`server/CLAUDE.md` 현재 상태에 D82 PR B 한 줄(LINE·Google 로그인, 연결 관리, 합치기 토큰), 다음 할 일 맨 앞을 "D82 PR C 합치기"로.

```bash
git add server
git commit -m "feat(server): LINE·Google 로그인과 계정 연결 API (D82, #386)"
```

`git merge origin/main` → 검사 다시 → `git push -u origin server/d82-identities` → `gh pr create`(본문 `참고 #386`).

---

## PR C: 합치기 (`server/d82-merge`)

### Task 7: migration 00015와 합치기 요약

**Files:**
- Create: `server/db/migrations/00015_account_merges.sql`
- Modify: `server/db/migrate_test.go`, `server/internal/cli/cli_test.go`(개수 15)
- Create: `server/db/queries/merge.sql`, `server/db/sqlc.yaml`(패키지 `mergedb` → `../internal/merge/mergedb`)
- Create: `server/internal/merge/service.go`, `preview.go`, `preview_test.go`, `errors.go`

**Interfaces:**
- Produces (migration): `account_merges(id uuid PK, kept_account_id uuid NOT NULL FK, removed_account_id uuid NOT NULL UNIQUE FK, merged_at timestamptz NOT NULL)`, `merged_purchases`(spec §4.4 열, PK `(account_id, purchase_id)`).
- Produces:
  ```go
  package merge
  var ErrTokenInvalid error
  type Keep string
  const ( KeepCurrent Keep = "current"; KeepOther Keep = "other" )
  type Saju struct { Saved bool; Calendar string; Year, Month, Day int; IsLeapMonth bool; TimeKnown bool; Hour, Minute int }
  type AccountSummary struct { Honorific string; HasHonorific bool; Saju Saju; DiaryCount int; Providers []string }
  type Preview struct { Current, Other AccountSummary; OverlapDayCount int }
  type ServiceDeps struct { Sessions SessionStarter; Grants GrantRevoker; Billing PurchaseMover; Clock clock.Clock; Logger *slog.Logger }
  func NewService(pool *pgxpool.Pool, deps ServiceDeps) *Service
  func (s *Service) Preview(ctx context.Context, accountID uuid.UUID, rawToken string) (Preview, error)
  ```
  `SessionStarter`·`GrantRevoker`·`PurchaseMover`는 Task 8·9가 채우는 interface입니다(이 task에서는 선언만).
- 쿼리: `FindTicket`(해시로, 잠금 없음), `AccountSummaryRow`(profiles 열), `LiveDiaryCount`, `ProvidersOf`, `OverlapDayCount`(두 계정 모두 `deleted_at IS NULL` 일기가 있는 날짜 수).

- [ ] **Step 1: 실패하는 테스트**

* `TestMigration00015_AccountMerges`: 같은 `removed_account_id` 두 번 insert → unique 위반; Down/Up 왕복.
* `TestPreview_SummarizesBothAccounts`: 현재 계정(프로필 양력 1990-03-15 시각 08:30, 호칭 "민지", 일기 3편 중 1편 지움 → `DiaryCount` 2, 연결 `[kakao]`), 다른 계정(프로필 없음 → `Saju.Saved` false·`HasHonorific` false, 일기 4편, 연결 `[line]`), 겹치는 날 2개 → `OverlapDayCount` 2.
* `TestPreview_UnknownBirthTime`: 시각 모름 → `Saved` true, `TimeKnown` false.
* `TestPreview_DoesNotConsumeToken`: 두 번 불러도 둘 다 성공, `consumed_at` NULL.
* `TestPreview_TokenInvalidCases`: 없는 토큰, 만료(시계를 10분 1초 뒤로), 소진됨, 다른 bearer 계정 → 모두 `ErrTokenInvalid`.

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test ./db/ ./internal/merge/...`
Expected: FAIL

- [ ] **Step 3: 구현**

토큰은 `sha256(rawToken)`으로 찾습니다. 잘못된 base64url도 그냥 못 찾음(`ErrTokenInvalid`). 만료는 `!now.Before(expires_at)`.

- [ ] **Step 4: 통과 확인**

Run: `cd server && go generate ./... && go test -race ./db/ ./internal/merge/...`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/db server/internal/merge server/internal/cli/cli_test.go
git commit -m "feat(server): 합치기 표와 요약 (migration 00015)"
```

### Task 8: 합치기 실행

**Files:**
- Modify: `server/db/queries/merge.sql`(아래 쿼리), regenerate
- Create: `server/internal/merge/merge.go`, `merge_test.go`
- Modify: `server/internal/auth/service.go`(`StartSession`, P-5)

**Interfaces:**
- Consumes: Task 5 `auth.RemovedIdentity`·`(*auth.Service).RevokeGrant`, Task 7 표.
- Produces:
  ```go
  type SessionStarter interface { StartSession(ctx context.Context, accountID uuid.UUID) (auth.TokenPair, error) }
  type GrantRevoker interface { RevokeGrant(ctx context.Context, removed auth.RemovedIdentity) error }
  type Result struct { AccountID uuid.UUID; Tokens auth.TokenPair }
  func (s *Service) Merge(ctx context.Context, accountID uuid.UUID, rawToken string, keep Keep) (Result, error)
  ```
  `(*auth.Service).StartSession(ctx, accountID) (TokenPair, error)`는 새 family로 `issueTokens`를 트랜잭션 하나에서 부릅니다.
- 쿼리: `LockTicket`(`FOR UPDATE`), `ConsumeTicket`, `LockAccountsInOrder`(`SELECT id, status FROM accounts WHERE id = ANY(@ids) ORDER BY id FOR UPDATE`), `IdentityOwner`, `DeleteDuplicateProviderIdentities`(없앨 계정 연결 중 남길 계정에 같은 provider가 있는 것, Apple 열 RETURNING), `MoveIdentities`, `CopyMissingDiaryDays`, `MoveDiaries`, `MoveSchedules`, `RevokeAccountSessions`, `DeleteIdempotencyKeys`, `MarkMergedAway`(`status = 'pending_deletion', deletion_requested_at = @now WHERE id = @id AND status = 'active'`), `InsertAccountMerge`.

- [ ] **Step 1: 실패하는 테스트**

* `TestMerge_KeepCurrentMovesEverything` / `TestMerge_KeepOtherMovesEverything`: 각각 남길 계정에 연결 전부(`[kakao, line]`), 일기 전부(지운 일기 포함), 일정 전부(지운 것 포함)가 있고, 없앨 계정은 `pending_deletion`·연결 0·살아 있는 refresh token 0·멱등 키 0, `account_merges` 한 행, 토큰 `consumed_at` 채워짐. 결과 `AccountID` = 남길 계정, `Tokens`로 `auth.Refresh`가 됨.
* `TestMerge_OverlappingDayUsesKeptDayRecord`: 같은 날 남길 계정 7편·없앨 계정 6편 → 그날 남길 계정 살아 있는 일기 13편, 모두 남길 계정의 `diary_days`(`guide_question`이 남길 계정 값) 아래. 겹치지 않는 날은 없앨 계정의 날짜 기록이 남길 계정으로 복사됨.
* `TestMerge_KeepsSurvivorProfileAndConsents`: 남길 계정 프로필·동의·`daily_selections`는 그대로, 없앨 계정 프로필 행은 남아 있음(P8 몫).
* `TestMerge_DuplicateProviderKeepsSurvivorsAndRevokesRemoved`: 두 계정 모두 Apple이 있음 → 남길 계정의 Apple 연결만 남고, `GrantRevoker`가 없앨 계정 Apple 연결로 한 번 불림(commit 뒤). revoker 오류여도 `Merge`는 성공.
* `TestMerge_TokenReuseIsInvalid`: 같은 토큰 두 번째 → `ErrTokenInvalid`, 데이터 변화 없음.
* `TestMerge_ConcurrentSameToken` (Review Focus 2): 두 goroutine 동시 → 하나 성공, 하나 `ErrTokenInvalid`, 일기 수가 두 번 옮겨진 흔적 없음.
* `TestMerge_StateChangedSinceTicket` (Review Focus 3): 토큰 발급 뒤 다른 계정이 그 연결을 뗌(토큰 행 CASCADE 삭제) → `ErrTokenInvalid`; 다른 계정이 삭제 요청 → `ErrTokenInvalid`. 둘 다 아무 행도 바뀌지 않음.
* `TestMerge_RemovedAccountCannotLogInAsItself`: 없앨 계정이던 카카오 subject로 `LoginKakao` → 남길 계정 id(`IsNewAccount` false).

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test ./internal/merge/ -run Merge`
Expected: FAIL

- [ ] **Step 3: 구현**

spec §4.3 순서 1~7(토큰 잠금 → 두 계정 id 순 잠금·조건 재확인 → 소진 → 옮김 → 정리 → 기록). 7(세션 발급)·중복 연결 허가 취소·결제 동기화(Task 9)는 commit 뒤입니다. `keep`이 `current`·`other`가 아니면 `ErrTokenInvalid`가 아니라 호출 오류(계약 검증이 먼저 막으므로 handler까지 오지 않음).

- [ ] **Step 4: 통과 확인**

Run: `cd server && go generate ./... && go test -race ./internal/merge/... ./internal/auth/...`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/db/queries/merge.sql server/internal/merge server/internal/auth
git commit -m "feat(server): 계정 합치기 실행 (S102)"
```

### Task 9: 광고 제거권 합산

**Files:**
- Modify: `server/db/queries/billing.sql`(아래 쿼리), regenerate
- Modify: `server/internal/billing/sync.go`(`Sync`가 `merged_purchases`를 합침, `AdFreePurchases`, `RefreshMergedFrom`)
- Modify: `server/internal/billing/webhook.go`(없앤 계정 처리)
- Modify: `server/internal/billing/sync_test.go`, `webhook_test.go`
- Modify: `server/internal/merge/merge.go`·`merge_test.go`(`PurchaseMover` 사용)

**Interfaces:**
- Produces:
  ```go
  // merge 쪽 interface, *billing.Syncer가 만족
  type PurchaseMover interface {
      // HasAdFreeHistory는 계정에 ad_free_pass 출처 행이나 merged_purchases 행이 있는지입니다.
      HasAdFreeHistory(ctx context.Context, accountID uuid.UUID) (bool, error)
      // AdFreePurchases는 계정의 RevenueCat 구매 중 광고 제거권 상품(동기화와 같은 상품·production 조건)입니다.
      AdFreePurchases(ctx context.Context, accountID uuid.UUID) ([]billing.Purchase, error)
      Sync(ctx context.Context, accountID uuid.UUID) error
  }
  ```
  `(*billing.Syncer).RefreshMergedFrom(ctx, removedAccountID uuid.UUID) (keptAccountID uuid.UUID, err error)`: 없앤 계정의 구매 목록으로 `merged_purchases.refunded`를 갱신하고 남길 계정 id를 돌려줌.
- 쿼리(billing): `ListMergedPurchases(account_id)`, `HasAdFreeHistory`, `UpdateMergedPurchaseRefund(account_id, purchase_id, refunded)`, `KeptAccountFor(removed_account_id)`. 쿼리(merge): `InsertMergedPurchase ON CONFLICT (account_id, purchase_id) DO NOTHING`, `MoveMergedPurchases`(없앨 계정 행을 남길 계정으로, 충돌이면 버림).

- [ ] **Step 1: 실패하는 테스트**

* `TestSync_MergedPurchasesChainWithOwn`: 남길 계정 RevenueCat 구매 P1(구매 10-01), `merged_purchases` P2(구매 10-05) → ad_free 행 P1 10-01~11-01, P2 11-01~12-01(D61로 이어 붙음).
* `TestSync_TransferredPurchaseCountedOnce` (Review Focus 4): RevenueCat 목록에도 P2가 나타남 → P2 행 하나, 기간 그대로.
* `TestSync_RefundedMergedPurchaseIsRevoked`: `merged_purchases.refunded` true → P2 행 `revoked_at` 채워짐.
* `TestWebhook_RemovedAccountRefreshesAndSyncsKept`: 없앤 계정 app_user_id의 환불 webhook → `merged_purchases.refunded` 갱신, 남길 계정 Sync 1회, 없앤 계정 자신의 행은 그대로(UpsertGrant가 없앤 계정으로 되돌리지 않음).
* `TestMerge_CarriesAdFreePurchases`: 없앨 계정이 P3 구매 → 합친 뒤 남길 계정에 `merged_purchases` P3, ad_free가 남은 기간만큼 늘어남.
* `TestMerge_BillingFetchFailureLeavesNothingChanged`: `HasAdFreeHistory` true이고 `AdFreePurchases`가 `billing.ErrProviderUnavailable` → `Merge`가 그 오류(`errors.Is`), 토큰 `consumed_at` NULL, 데이터 변화 없음.
* `TestMerge_NoAdFreeHistorySkipsFetch`: 대역 `AdFreePurchases` 호출 0.

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test ./internal/billing/... ./internal/merge/...`
Expected: FAIL

- [ ] **Step 3: 구현**

* `Sync`: 잠금·조회 뒤 `adFreeGrants(merge(purchases, merged), …)`. 합치기는 구매 id 기준이고 같은 id면 RevenueCat 쪽. `merged_purchases`의 `refunded`·`production`·`product_id`를 `Purchase`로 바꿔 같은 필터를 탑니다.
* `Merge`: 트랜잭션 전에 토큰으로 두 계정을 정하고(`FindTicket`), 없앨 계정이 `HasAdFreeHistory`면 `AdFreePurchases`를 조회. 실패하면 바로 돌려줌. 트랜잭션 안에서 `InsertMergedPurchase`(구매마다, `from_account_id` = 없앨 계정)와 `MoveMergedPurchases`. commit 뒤 `Sync(남길 계정)`, 실패는 경고 로그.
* webhook: 계정 후보가 `account_merges.removed_account_id`면 `RefreshMergedFrom` 뒤 돌려받은 남길 계정을 `Sync`. 없앤 계정은 `Sync`하지 않음.

- [ ] **Step 4: 통과 확인**

Run: `cd server && go generate ./... && go test -race ./internal/billing/... ./internal/merge/...`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/db/queries server/internal/billing server/internal/merge
git commit -m "feat(server): 합치기 때 광고 제거권 구매 합산 (S103)"
```

### Task 10: 합치기 핸들러, 흐름 테스트, PR C

**Files:**
- Create: `server/internal/httpapi/merge_handlers.go`, `merge_handlers_test.go`
- Modify: `server/internal/httpapi/api.go`(`MergeService` interface, `API.Merges`)
- Modify: `server/internal/httpapi/errors.go`(`merge.ErrTokenInvalid` → 422 `merge.token_invalid`, `billing.ErrProviderUnavailable`는 기존 매핑)
- Modify: `server/internal/httpapi/unimplemented.go`(2개 제거)
- Modify: `server/internal/cli/serve.go`(merge 조립)
- Modify: `server/internal/cli/identity_flow_test.go`(합치기 흐름)
- Modify: `server/CLAUDE.md`

**Interfaces:**
- Consumes: Task 7~9 `merge.Service`.
- Produces: `httpapi.MergeService interface{ Preview(…) (merge.Preview, error); Merge(…) (merge.Result, error) }`.

- [ ] **Step 1: 실패하는 handler 테스트**

* `TestPreviewMerge_MapsSummary`: `Saju{Saved:true, Calendar:"solar", Year:1990, Month:3, Day:15, TimeKnown:true, Hour:8, Minute:30}` → `{"status":"saved","calendar":"solar","date":{…},"birthTime":{"status":"known","value":"08:30"}}`; `TimeKnown` false → `birthTime.status == "unknown"`; `Saved` false → `{"status":"none"}`; `HasHonorific` false → 본문에 `honorific` 없음.
* `TestPreviewMerge_TokenInvalidIs422`: `merge.ErrTokenInvalid` → 422 `merge.token_invalid`, `errors` 없음.
* `TestMergeAccounts_ReturnsKeptAccountTokens`: 200 `{"accountId":…, "tokens":{…}}`; 요청 `keep:"other"` → 서비스에 `merge.KeepOther`.
* `TestMergeAccounts_BillingUnavailableIs503`.

- [ ] **Step 2: 실패 확인**

Run: `cd server && go test ./internal/httpapi/ -run Merge`
Expected: FAIL

- [ ] **Step 3: 구현과 조립**

- [ ] **Step 4: 조립 흐름 테스트 (Review Focus 5)**

`TestMergeFlow_KeepOtherSwitchesSession`: 계정 A(카카오, 일기 2편)와 계정 B(LINE, 일기 3편, 같은 날 1개 겹침), 둘 다 동의 → A에서 B의 LINE 붙이기 409 → `previewMerge` 200(`overlapDayCount` 1, A `diaryCount` 2, B 3) → `mergeAccounts {keep:"other"}` 200(`accountId` = B) → A의 옛 refresh token으로 `refreshToken` → 401 → 응답 토큰으로 `listDiaries` 5편 → 카카오로 다시 로그인하면 B, `isNewAccount` false → 같은 `mergeToken`으로 다시 `mergeAccounts` → 422 `merge.token_invalid`.

- [ ] **Step 5: 전체 검사**

Run: Task 6 Step 5와 같은 명령
Expected: 생성 차이 없음, 0 issues, FAIL 0

- [ ] **Step 6: 현재 상태와 commit, PR C**

`server/CLAUDE.md` 현재 상태에 D82 완료 줄(S99~S104, PR 번호 셋), 다음 할 일에서 D82를 빼고 P8 줄에 "익명화가 `account_merges`의 없앤 계정과 `merged_purchases`는 건드리지 않음, `account_merge_tickets` 지난 행 정리는 retention"을 더함.

```bash
git add server
git commit -m "feat(server): 계정 합치기 API (D82, #386)"
```

`git merge origin/main` → 검사 다시 → `git push -u origin server/d82-merge` → `gh pr create`(본문 `Closes #386`). app Issue에 PR 번호 코멘트.
