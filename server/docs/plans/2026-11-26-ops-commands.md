# 운영 API(IAP) Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

> 2026-11-26 개정: 첫 plan(운영자 IAM DB 사용자로 로컬 실행)은 D145 ⑦로 대체됐습니다. 첫 plan의 Task 1~9는 브랜치 `server/1321-ops-commands`에 구현돼 있고(commit `cc47281c..f9966bc7`), 이 plan은 그 위에서 접속 부분을 바꿉니다.

**Goal:** 운영 명령을 IAP로 막은 별도 Cloud Run 서비스 `server-ops`의 운영 API로 옮기고, DB에는 서비스 계정만 붙게 하며, CLI는 그 API를 부르는 클라이언트로 바꿉니다.

**Architecture:** `internal/ops` Service(조회, 부여와 회수, 열람, 감사)는 그대로 쓰고, 새 패키지 `internal/opsapi`가 IAP JWT 검증, 허용 목록, `POST /ops/v1/*` 핸들러를 맡습니다. `server ops-serve`가 이 라우터만 띄우고, Terraform이 `server-ops` 서비스(IAP), 서비스 계정, DB 사용자를 만듭니다. CLI는 OAuth ID token으로 API를 부릅니다.

**Tech Stack:** Go, pgx/v5, sqlc, goose, `github.com/golang-jwt/jwt/v5`(ES256), `golang.org/x/oauth2`(데스크톱 OAuth), Terraform google `~> 8.9`, GitHub Actions(`deploy-server-env.yml`)

**Spec:** `server/docs/specs/2026-11-26-ops-commands-design.md`(2026-11-26 개정판)

## Global Constraints

* REST v1(`api/openapi.yaml`)은 바꾸지 않습니다. `go run ./cmd/contractgate -base origin/staging` 통과.
* 사람 DB 계정을 만드는 코드와 문서를 남기지 않습니다(`GrantOpsRole`, `ops.env`, `gcloud sql users create <메일>` 안내 삭제).
* 감사 `channel`은 `ops_api` 하나. trigger는 `at := now()`, `channel <> 'ops_api'` 거절, `actor`는 덮지 않음. UPDATE, TRUNCATE, 2년 안 DELETE 거절은 유지.
* 운영 API 경로는 모두 `POST /ops/v1/...`와 JSON 본문. URL에 사유, 목적, 날짜, 계정 id, 거래 id가 들어가지 않습니다. 본문 상한 64 KiB, 응답 `Cache-Control: no-store`.
* IAP JWT: 헤더 `x-goog-iap-jwt-assertion`, ES256, 공개키 `https://www.gstatic.com/iap/verify/public_key-jwk`, `iss` `https://cloud.google.com/iap`, `aud` `/projects/<프로젝트 번호>/locations/<리전>/services/server-ops`. `x-goog-authenticated-user-email`은 쓰지 않음.
* 허용 목록 Secret `OPS_OPERATORS`(쉼표 구분 메일, 앞뒤 공백 제거, 소문자 비교). 비면 모든 요청 403.
* 사유: 첫 판 규칙에 더해 `@` 거절. `storeTransaction`: 1~128자, `[A-Za-z0-9._-]`.
* 상태 코드: 400 입력, 401 IAP 검증 실패, 403 허용 목록 밖, 404 계정이나 프로필 없음, 409 회수 불가와 이미 끝남과 지운 계정 부여, 500. CLI 종료 코드는 400이면 2, 그 밖의 실패는 1.
* 로그에 요청과 응답 본문, 사유, 목적, 메일을 남기지 않습니다(route, status, latency만).
* 운영자 메일은 저장소, tfvars, CI 로그에 두지 않습니다(D74).
* 문서에 긴 대시(U+2014), 범위 대시(U+2013), 가운뎃점(U+00B7) 금지.
* commit마다 `go vet ./... && golangci-lint run ./...`(staging 태그도) 깨끗.

## Review Focus

1. IAP 공개키를 처음 받지 못하거나 갱신이 실패할 때(네트워크 오류) 요청은 401이 아니라 503으로 끝나고, 캐시된 키가 있으면 그대로 검증해야 합니다. → Task 3 `TestVerifier_KeyFetchFailure`
2. `OPS_OPERATORS`에 대소문자나 공백이 섞인 메일이 있어도 같은 계정으로 맞아야 합니다. → Task 3 `TestAllowlist_Normalizes`
3. 같은 요청에 `accountId`와 `storeTransaction`이 둘 다 오거나, JSON에 모르는 칸이 있으면 400이어야 합니다(오타가 조용히 무시되지 않게). → Task 4 `TestHandlers_RejectsUnknownFields`
4. 운영 API가 local에서 개발용 고정 신원으로 뜨는 설정이 staging, prod에서 켜지면 기동이 실패해야 합니다. → Task 5 `TestOpsServe_DevIdentityRejectedOutsideLocal`
5. CLI의 refresh token이 만료되거나 철회되면 자세한 안내(`server ops login`)와 함께 종료 코드 1이어야 하고, token 파일 권한이 600보다 넓으면 거절해야 합니다. → Task 7 `TestOpsClient_TokenErrors`

---

### Task 0: CLI 프로그램 접근 확인(spike, 사용자와 함께, 버릴 코드)

spec §3.4. Cloud Run 직접 IAP에서 사람 계정의 프로그램 접근이 되는지 확인합니다. 결과에 따라 Task 7을 유지하거나 미룹니다.

- [ ] **Step 1: 사용자에게 준비를 안내**(외부 준비): staging에 데스크톱 OAuth 클라이언트를 만들고 IAP `programmatic_clients`에 넣기.
- [ ] **Step 2: 사용자가 staging에 빈 IAP 서비스를 띄움**(server가 명령을 드림): `gcloud run deploy ops-spike --image=us-docker.pkg.dev/cloudrun/container/hello --region=asia-northeast3 --no-allow-unauthenticated --iap`, IAP 서비스 에이전트 `run.invoker`, 사용자 계정 `iap.httpsResourceAccessor`.
- [ ] **Step 3: 작은 Go 프로그램(scratchpad, 저장소에 넣지 않음)으로 루프백 OAuth 로그인 뒤 ID token을 `Authorization: Bearer`로 보내 200을 확인.** 서비스 응답의 `x-goog-iap-jwt-assertion` 클레임(`aud`, `email`)을 기록합니다.
- [ ] **Step 4: 결과를 #1321에 기록하고 사용자에게 `ops-spike` 삭제를 안내.** 실패하면 Task 7을 빼고 브라우저 경로 안을 지휘에 올립니다.

### Task 1: migration 00029 개정과 역할 지정

**Files:**
- Modify: `server/db/migrations/00029_ops.sql`, `server/internal/platform/postgres/schema_ops_test.go`, `server/internal/platform/postgres/opsrole.go`(내용 교체), `opsrole_test.go`, `server/internal/cli/cli.go`(`runMigrate`), `server/internal/cli/cli_test.go`

**Interfaces:**
- Produces: `postgres.GrantOpsUser(ctx, pool, member string) error`, `postgres.CheckRoleSeparation(ctx, pool, runtimeUser, opsUser string) error`(오류 `ErrRuntimeInOpsRole`, `ErrOpsInAppRole`, `ErrUnexpectedOpsMember`), 감사 칸 `actor_sub text NOT NULL`, `channel` CHECK `('ops_api')`

**migration 변경:**
* `channel` CHECK를 `('ops_api')`로, 새 칸 `actor_sub text NOT NULL CHECK (actor_sub <> '')`(실행자의 IAP `sub`, spec의 "target에 sub"를 칸으로 둠).
* `ops_audit_stamp`: `NEW.at := now()`, `channel <> 'ops_api'`면 P0001. `actor` 덮기 삭제.
* Up을 다시 돌려도 되게(`CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, trigger는 `DROP TRIGGER IF EXISTS` 뒤 생성).
* Down: `ops_audit`, 그 함수와 trigger, 인덱스는 남기고 `myungli_ops` 권한만 거둠. `operator` 출처 행 삭제와 CHECK 되돌림은 첫 판 그대로.
* 사람 IAM 사용자 판별 코드 `GrantOpsRole`과 그 테스트 삭제.

- [ ] **Step 1: 테스트 수정과 추가** `TestOpsAudit_StampSetsAtOnly`(다른 at으로 넣어도 now, actor는 넣은 값), `TestOpsAudit_RejectsNonOpsAPIChannel`, `TestMigrate_OpsDownKeepsAudit`(행 하나 넣고 `MigrateDownTo(28)` 뒤 행이 남고 다시 up 성공), `TestGrantOpsUser`, `TestCheckRoleSeparation`(runtime이 ops 구성원, ops가 app 구성원, 그 밖의 ops 구성원 각각 오류, 정상은 nil; cluster 공용이라 `dbtest.LockCluster`)
- [ ] **Step 2: FAIL 확인 → 구현 → PASS** `go test -race ./internal/platform/postgres/`
- [ ] **Step 3: `runMigrate`:** `direction == "up"`이고 `DB_OPS_USER`가 있으면 `GrantOpsUser` 뒤 `CheckRoleSeparation(DB_RUNTIME_USER, DB_OPS_USER)`, 실패하면 배포를 멈춤(로그에는 오류 종류만, 이름 없음). 둘 중 하나만 있으면 설정 오류. 테스트 `TestRunMigrate_OpsUser`.
- [ ] **Step 4: Commit** `feat(server): 운영 감사 표를 운영 API 경로로, 운영 DB 사용자 지정 (#1321)`

### Task 2: ops Service의 실행자와 입력 규칙

**Files:**
- Modify: `server/internal/ops/ops.go`, `audit.go`, `account.go`와 테스트들, `db/queries/ops.sql`(감사 INSERT와 조회에 `actor_sub`)

**Interfaces:**
- Produces: `ops.Actor{Email, Subject string}`(Channel 칸 삭제, 감사에는 언제나 `ops_api`), `ops.ChannelOpsAPI = "ops_api"`, `ValidateReason`의 `@` 거절, `ValidateStoreTransaction(s string) (string, error)`(오류 `ErrStoreTransaction`), `AuditRecord.ActorSub`

- [ ] **Step 1: 테스트 수정과 추가** 감사 행의 `actor`가 `Actor.Email`, `actor_sub`가 `Actor.Subject`, `channel`이 `ops_api`. `TestValidateReason`에 `"문의 a@b"` 거절. `TestValidateStoreTransaction`(빈 값, 129자, 공백, `/`, 한글 거절, `GPA.1234-5678_9.0` 통과). `AccountSummary`가 형식이 틀린 거래 id를 DB 전에 거절. `validateActor`는 Email 또는 Subject가 비면 `ErrActor`.
- [ ] **Step 2: FAIL 확인 → 구현 → PASS** `go test -race ./internal/ops/...`
- [ ] **Step 3: Commit** `feat(server): 운영 실행자를 IAP 신원으로, 사유와 거래 id 형식 제한 (#1321)`

### Task 3: IAP JWT 검증과 허용 목록

**Files:**
- Create: `server/internal/opsapi/iap.go`, `iap_test.go`, `allowlist.go`, `allowlist_test.go`

**Interfaces:**
- Produces:
  * `type Identity struct{ Email, Subject string }`
  * `type KeySource interface{ Keys(ctx) (map[string]*ecdsa.PublicKey, error) }`, `NewHTTPKeySource(client *http.Client, url string, clk clock.Clock) KeySource`(1시간 캐시, 모르는 `kid`면 한 번 다시 받음, 실패 시 캐시가 있으면 캐시 사용)
  * `type Verifier struct{...}`, `NewVerifier(keys KeySource, audience string, clk clock.Clock) *Verifier`, `(v *Verifier) Verify(ctx, assertion string) (Identity, error)`; 오류 `ErrNoAssertion`, `ErrInvalidAssertion`, `ErrKeysUnavailable`
  * `type Allowlist struct{...}`, `ParseAllowlist(raw string) Allowlist`, `(a Allowlist) Allows(email string) bool`
- 검증: `jwt/v5`로 `alg` ES256만, `kid`로 키 선택, `iss`, `aud` 정확 일치, `exp`와 `iat`(허용 오차 30초), `email`과 `sub` 비어 있으면 무효.

- [ ] **Step 1: 실패하는 테스트**(테스트용 P-256 키로 서명): 정상, 서명 틀림, `alg` HS256과 none, `aud`, `iss` 틀림, 만료, 미래 `iat`, `email` 없음, `kid` 모름(다시 받기 1회), `TestVerifier_KeyFetchFailure`(캐시 없음은 `ErrKeysUnavailable`, 캐시 있으면 성공), `TestAllowlist_Normalizes`(`" Op@Example.com ,x@y.z"`), 빈 목록은 모두 거절.
- [ ] **Step 2: FAIL → 구현 → PASS** `go test -race ./internal/opsapi/`
- [ ] **Step 3: Commit** `feat(server): IAP 서명 헤더 검증과 운영자 허용 목록 (#1321)`

### Task 4: 운영 API 핸들러

**Files:**
- Create: `server/internal/opsapi/router.go`, `handlers.go`, `errors.go`, `middleware.go`, `handlers_test.go`

**Interfaces:**
- Consumes: Task 2 Service, Task 3 Verifier와 Allowlist
- Produces: `NewHandler(deps Deps) http.Handler`, `type Deps struct{ Service *ops.Service; Verifier *Verifier; Allowlist Allowlist; Logger *slog.Logger }`
- 경로(spec §3.3): `accounts:show`, `grants`, `grants:revoke`, `content:diary`, `content:schedule`, `content:profile`, `audit:list`. 요청 JSON은 `DisallowUnknownFields`, camelCase. 날짜는 `YYYY-MM-DD`, `until`과 `since`는 RFC 3339와 `YYYY-MM-DD`(첫 판 CLI 규칙).
- 미들웨어 순서: 본문 상한 64 KiB, 접근 로그(route, status, latencyMs만), IAP 검증(401, 키 없음은 503), 허용 목록(403), 핸들러. 응답 `Content-Type: application/json`, `Cache-Control: no-store`.
- 오류 JSON `{"code","message"}`: `invalid_input`, `unauthenticated`, `forbidden`, `not_found`, `profile_not_found`, `conflict`, `unavailable`, `internal`. 500의 message는 고정 문구(내부 오류 원문을 응답에 넣지 않음).

* **CSRF와 쿠키 경로 차단(지휘 검토 2):** 지금은 CLI 경로만 엽니다. 요청은 `Authorization: Bearer`(IAP가 검증한 ID token)로만 받는다는 전제로, 핸들러 앞에서 ① 사용자 정의 헤더 `X-Myungli-Ops: 1` 필수(다른 사이트의 폼과 단순 요청은 붙일 수 없고, 붙이면 CORS preflight가 필요한데 이 API는 CORS를 허용하지 않음) ② `Content-Type: application/json` 필수 ③ `Origin` 헤더가 있으면 거절(CLI는 보내지 않음) ④ `Sec-Fetch-Site`가 있고 `none`이 아니면 거절. 모두 403 `forbidden`이고 감사 없음. 어드민 웹이나 브라우저 폼을 열 때는 `Origin` 허용 목록과 CSRF 토큰을 따로 설계합니다(이 plan 밖).

- [ ] **Step 1: 실패하는 테스트**(httptest, DB는 testcontainers, IAP는 Task 3의 테스트 키): `TestHandlers_CSRFGuard`(헤더 없음, form 본문, `Origin` 있음, `Sec-Fetch-Site: cross-site` 각각 403), 명령마다 200과 본문, 감사 행의 actor와 actor_sub, `TestHandlers_RejectsUnknownFields`, GET은 405, 본문 초과 413, 헤더 없음 401, 목록 밖 403(감사 행 없음), 계정 없음 404(감사 있음), `ad_free_pass` 회수 409, 응답 헤더 `no-store`, 로그 출력에 사유, 목적, 메일, 본문 문자열이 없음.
- [ ] **Step 2: FAIL → 구현 → PASS** `go test -race ./internal/opsapi/`
- [ ] **Step 3: Commit** `feat(server): 운영 API 핸들러 (#1321)`

### Task 5: `server ops-serve`와 경로 분리

**Files:**
- Create: `server/internal/cli/opsserve.go`, `opsserve_test.go`
- Modify: `server/internal/cli/cli.go`(commands, usage), `server/internal/platform/config/config.go`(`LoadOps`)

**Interfaces:**
- Produces: `config.LoadOps(getenv) (OpsConfig, error)`; `OpsConfig{Audience, Operators string; DevIdentity *opsapi.Identity}`. env: `IAP_AUDIENCE`(필수, local 제외), `OPS_OPERATORS`(Secret), `OPS_DEV_IDENTITY`(`email,sub`, `APP_ENV=local`에서만).
- `ops-serve`: `APP_ENV`가 staging이나 prod면 `CLOUD_SQL_INSTANCE` 필수, `IAP_AUDIENCE` 필수, `OPS_DEV_IDENTITY` 있으면 기동 실패. local에서 `OPS_DEV_IDENTITY`가 있으면 IAP 검증 대신 그 신원(경고 로그). 포트는 `PORT`. graceful shutdown은 `serve`와 같은 방식.

- [ ] **Step 1: 실패하는 테스트** `TestOpsServe_RequiresCloudSQLInDeployedEnv`, `TestOpsServe_DevIdentityRejectedOutsideLocal`, `TestOpsServe_RequiresAudience`, `TestRouters_Separated`(`serve` 핸들러에 `/ops/v1/accounts:show` POST가 404, `ops-serve` 핸들러에 앱 경로 예 `/v1/daily`가 404).
- [ ] **Step 2: FAIL → 구현 → PASS** `go test -race ./internal/cli/ ./internal/platform/config/`
- [ ] **Step 3: Commit** `feat(server): server ops-serve (#1321)`

### Task 6: Terraform과 배포 workflow

**Files:**
- Modify: `server/deploy/terraform/env/main.tf`(서비스 계정, IAM, locals `ops_db_user`, `ops_env`, migrator_env에 `DB_OPS_USER`), `run.tf`(`server-ops` 서비스, IAP 에이전트 invoker), `sql.tf`(`google_sql_user` ops), Secret 정의 파일(`OPS_OPERATORS` 틀, 기존 Secret 틀과 같은 곳), `outputs.tf`(`ops_env`), `.github/workflows/deploy-server-env.yml`(server-ops 서비스 갱신)

**값:**
* 서비스 계정 `server-ops`, 프로젝트 역할 `roles/cloudsql.client`, `roles/cloudsql.instanceUser`. Secret `OPS_OPERATORS`에 `secretAccessor`(이 Secret만).
* `google_sql_user` 이름 `trimsuffix(server-ops 메일, ".gserviceaccount.com")`, `CLOUD_IAM_SERVICE_ACCOUNT`.
* `google_cloud_run_v2_service "server_ops"`: name `server-ops`, `iap_enabled = true`, `ingress = "INGRESS_TRAFFIC_ALL"`, 서비스 계정 `server-ops`, 최소 0, `cpu_idle = true`, vpc_access는 server와 같음(Cloud SQL 공개 IP connector라 없어도 되면 빼고 이유 주석), lifecycle ignore는 server와 같음, 명령 args `["ops-serve"]`.
* `google_cloud_run_v2_service_iam_member` IAP 서비스 에이전트 `serviceAccount:service-${var.project_number}@gcp-sa-iap.iam.gserviceaccount.com` `roles/run.invoker`. `allUsers` 없음. IAP 접근 주체(사람)는 Terraform 밖(runbook).
* `ops_env`: `APP_ENV`, `CLOUD_SQL_INSTANCE`, `DATABASE_URL`(ops DB 사용자), `IAP_AUDIENCE = "/projects/${var.project_number}/locations/${var.region}/services/server-ops"`, `LOG_LEVEL`.
* workflow: `gcloud run services update server-ops --image ... --env-vars-file ops-env.yaml --set-secrets OPS_OPERATORS=OPS_OPERATORS:latest`(Secret 버전이 없으면 이 단계만 건너뛰고 요약에 적음), migrate Job env에 `DB_OPS_USER`가 들어감(migrator_env).
* provider `~> 8.9`의 `iap_enabled` 지원은 `terraform validate`로 확인합니다. 없으면 provider minor 범위를 올리고 lock을 갱신.

* **서비스 계정 빌려 쓰기 차단(지휘 검토 1):** `server-ops` 서비스 계정의 IAM 정책을 Terraform이 권한 있게 관리합니다(`google_service_account_iam_policy`). 정책에는 배포 계정(deployer)의 `roles/iam.serviceAccountUser`(Cloud Run 배포에 필요한 actAs)만 둡니다. `roles/iam.serviceAccountTokenCreator`와 그 밖의 주체는 두지 않습니다.
* **배포 때 검사:** 새 스크립트 `server/deploy/check-ops-sa.sh <project>`가 ① `server-ops` 계정의 IAM 정책에 deployer의 serviceAccountUser 말고 다른 바인딩이 있으면 실패 ② 프로젝트 IAM 정책에서 `roles/iam.serviceAccountUser`, `roles/iam.serviceAccountTokenCreator`, `roles/iam.workloadIdentityUser`를 가진 주체가 있으면 실패(프로젝트 단위 부여는 모든 계정을 빌려 쓸 수 있게 함). 예외는 deployer 계정의 프로젝트 단위 `roles/iam.serviceAccountUser` 하나입니다(bootstrap `deployer_roles`, 모든 서비스와 Job 배포의 actAs에 필요). 예외는 스크립트에 근거 주석과 함께 둡니다. deployer가 actAs로 `server-ops`를 쓸 수 있다는 점(배포 브랜치에 들어간 코드가 그 계정으로 실행될 수 있음, 브랜치 보호와 PR 리뷰가 막음)은 runbook "남는 위험"에 적습니다. deployer를 서비스 계정 단위 부여로 좁히는 것은 bootstrap 변경(사용자 apply)이라 이 plan 밖이고 #1321에 제안으로 남깁니다. 출력에는 역할과 주체 종류만, 사람 메일은 가림. `deploy-server-env.yml`의 server-ops 갱신 전에 돌리고 실패하면 배포를 멈춥니다. 스크립트는 `gcloud ... --format=json`과 `jq`로 쓰고, 고정 JSON 입력으로 도는 테스트(`server/deploy/check-ops-sa_test.sh` 또는 Go 테스트)를 둡니다.

- [ ] **Step 1: 구현 뒤 `terraform fmt -check`, `terraform init -backend=false && terraform validate`(env), workflow는 YAML 검사와 `sh -n`(run 블록 추출), `server.yml`의 기존 Terraform 검사가 있으면 함께.**
- [ ] **Step 2: `terraform plan`은 CI(deploy-server의 plan job)에서 확인하므로 로컬에서는 validate까지. plan에서 `server_ops`에 `allUsers`가 없음을 확인하는 기존 형식 검사가 있으면 더함.**
- [ ] **Step 3: Commit** `feat(server): server-ops 서비스와 IAP, 운영 DB 사용자 (#1321)`

### Task 7: CLI를 API 클라이언트로 (Task 0 성공 시)

**Files:**
- Modify: `server/internal/cli/ops.go`, `ops_output.go`, `ops_test.go`
- Create: `server/internal/cli/ops_client.go`, `ops_login.go`, `ops_client_test.go`

**Interfaces:**
- 인자와 출력은 첫 판 그대로. 실행은 DB 대신 API 호출. `server ops login --env staging|prod`(루프백 OAuth, `x/oauth2`, scope `openid email`, PKCE), 로컬 파일 `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/server/<환경>/ops-oauth.json`(`apiUrl`, `clientId`, `clientSecret`, `refreshToken`, 권한 600). 다른 명령은 `--env`로 그 파일을 읽어 ID token을 얻어 `Authorization: Bearer`.
- 상태 코드에서 종료 코드로: 400은 2, 그 밖은 1. 오류 출력은 `ops: <message>` 한 줄(응답 JSON의 message).
- 첫 판의 DB 직접 연결 코드(`openDatabase` 호출, `session_user` 조회, `classifyOpsError`의 PgError 분기)는 지웁니다.

- [ ] **Step 1: 실패하는 테스트**(httptest 서버가 API 흉내): 명령마다 요청 경로, 본문 JSON, `Authorization` 헤더, 응답에서 표와 JSON 출력, 상태 코드별 종료 코드, `TestOpsClient_TokenErrors`(refresh 실패, 파일 없음, 권한 644), 사용법 오류는 네트워크 전에 2.
- [ ] **Step 2: FAIL → 구현 → PASS** `go test -race ./internal/cli/ -run Ops`
- [ ] **Step 3: Commit** `feat(server): 운영 CLI를 운영 API 클라이언트로 (#1321)`

### Task 8: 문서와 결정

**Files:**
- Modify: `server/docs/runbook/ops.md`(전면 개정), `server/docs/decisions.md`(S170 개정, 처음 안 원문은 `server/docs/decisions-history.md`로), `server/docs/decisions-history.md`, `server/deploy/terraform/README.md`(운영자 등록 절 교체, Secret 목록에 `OPS_OPERATORS`), `docs/local-values.md`(K20을 `ops-oauth.json`으로), `server/CLAUDE.md`(다음 할 일 11번), spec(Task 0 결과와 `actor_sub` 칸 반영)

- [ ] **Step 1: 문서 작성.** runbook: 준비(OAuth 클라이언트, `server ops login`), 운영자 등록과 빼기(IAP 바인딩 명령, `OPS_OPERATORS` 값 갱신), 명령 사용법, 상태 코드와 종료 코드, 사유에 개인정보 금지(문의 번호나 Issue 번호만). 목적별 운영 기준과 통제 세부는 적지 않음. 사람 DB 계정 안내는 모두 삭제.
- [ ] **Step 1b: 남는 위험과 IAP 접근 기록(지휘 검토 1, 3).** 먼저 공식 문서로 확인합니다: ① 서비스 계정 토큰 발급(`iamcredentials.googleapis.com` `GenerateAccessToken`, `GenerateIdToken`)이 감사 로그의 어느 종류(관리 활동, 데이터 접근)에 남는지, 데이터 접근이면 기본으로 꺼져 있는지 ② IAP 데이터 접근 감사 로그(`iap.googleapis.com`)가 무엇을 남기는지(요청 본문, query, 헤더가 남지 않는지). 확인한 사실과 출처를 spec §2 표에 더하고, runbook "남는 위험" 절에 프로젝트 소유자의 우회 가능성과 그 기록이 남는 곳, 켜야 하는 감사 로그와 켜는 명령(`gcloud projects get-iam-policy`/`set-iam-policy`의 `auditConfigs`, 사람이 실행)을 적습니다. 지휘가 적은 "관리 활동에 남음"과 다르면 #1321에 알립니다.
- [ ] **Step 2: S170** 근거에 `사용자 영향: D145`(⑦에 이미 반영) 또는 그대로 `#1376`을 판단해 적음. 처음 안을 대체했다는 문장과 #1381 점검 항목별 처리.
- [ ] **Step 3: 전체 검사** vet, lint(기본, staging), `go test -race ./...`, contractgate, `go generate ./... && git status --porcelain`, 문서의 금지 문자 grep.
- [ ] **Step 4: Commit** `docs(server): 운영 API runbook과 S170 개정 (#1321)`
- [ ] **Step 5(controller):** 최종 브랜치 review 뒤 push, PR #1381을 ready로 바꾸고 본문 갱신, #1381에 점검 항목별 처리 코멘트, 외부 준비(OAuth 클라이언트 prod, `OPS_OPERATORS` 값, 운영자 IAP 부여)를 지휘에 알림.
