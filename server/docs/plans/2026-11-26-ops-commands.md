# 운영 명령 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 운영자가 자기 컴퓨터에서 `server ops ...`로 계정 조회, 권한 부여와 회수, 콘텐츠 열람, 감사 기록 조회를 하고, 모든 실행이 지울 수 없는 감사 표에 남게 합니다.

**Architecture:** 핵심 함수는 `internal/ops` Service(어드민 API가 나중에 그대로 씀)에 두고, 모든 공개 함수가 같은 트랜잭션에서 감사 행을 씁니다. CLI(`internal/cli/ops.go`)는 인자 해석, `session_user`로 실행자 결정, 출력만 합니다. DB는 새 역할 `myungli_ops`, 감사 표 `ops_audit`(trigger로 갱신 금지, 2년 지난 행만 삭제), 권한 출처 `operator`를 migration 00029로 더합니다.

**Tech Stack:** Go, pgx/v5, sqlc(`db/sqlc.yaml`), goose migration, testcontainers(`internal/platform/dbtest`), Cloud SQL Go connector(IAM 인증)

**Spec:** `server/docs/specs/2026-11-26-ops-commands-design.md`

## Global Constraints

* REST 계약(`api/openapi.yaml`)은 바꾸지 않습니다. `go run ./cmd/contractgate -base origin/staging`이 통과해야 합니다.
* 사유: 앞뒤 공백을 뗀 뒤 1~500자(rune), `\n`, `\r` 금지. 없으면 사용법 오류(종료 코드 2)이고 DB에 붙지 않습니다.
* 목적 값은 정확히 `inquiry`, `incident`, `policy`, `legal`입니다.
* 감사 `action` 값은 정확히 `account_show`, `grant`, `revoke`, `content_view`, `audit_list`이고, `channel`은 `cli`, `admin_api`입니다.
* 감사 행과 출력에 일기와 일정 본문, 호칭, 출생 정보, 제공자 subject, 토큰을 넣지 않습니다. 결과는 stdout으로만 쓰고 로거(stderr)에는 본문을 쓰지 않습니다.
* 부여 기간: 만료는 지금보다 뒤이고 지금부터 366일 이내. `--days`는 1~366.
* 회수 가능한 출처는 `operator`, `rewarded_ad`뿐입니다.
* 감사 기록과 운영자 부여 행의 보관은 2년(`now.AddDate(-2, 0, 0)`)입니다.
* 주석과 오류 문구는 기존 코드처럼 한국어입니다. 사용자에게 보이는 글이 아니므로 D93 문자 제한은 해당하지 않지만, runbook에도 긴 대시와 가운뎃점은 쓰지 않습니다.
* 새 브랜치 `server/1321-ops-commands`(이미 있음)에서 작업하고, commit마다 `go vet ./... && golangci-lint run ./...`이 깨끗해야 합니다.

## Review Focus

1. 감사 행 쓰기가 실패하면(예: `ops_audit` 권한 없음) 조회와 열람 결과가 하나도 출력되지 않아야 합니다. → Task 4, Task 6 테스트 `..._AuditFailureReturnsNothing`
2. 같은 그날 일기가 지운 일기(`deleted_at`)나 비운 일기(`content_purged_at`)를 포함할 때, 열람은 살아 있는 일기만 보여야 합니다(지운 것은 개수만). → Task 6 `TestViewDiary_ExcludesDeletedAndPurged`
3. `--store-transaction`으로 찾은 거래가 장부에 여러 행(같은 스토어 거래, unique 아님)이면 계정이 하나일 때만 보이고, 둘 이상이면 계정 id 목록만 알리고 상세를 보이지 않아야 합니다. → Task 4 `TestAccountSummary_StoreTransactionAmbiguous`
4. `ad_free` 묶음으로 준 두 행 중 하나의 id로 회수해도 두 행이 함께 거둬져야 합니다. → Task 5 `TestRevoke_AdFreeBundleRevokesBoth`
5. 사람 IAM 사용자 판별이 서비스 계정(`...@project.iam`)과 `postgres` 같은 내장 사용자를 넣지 않아야 합니다. → Task 1 `TestGrantOpsRole_OnlyHumanIAMUsers`

---

### Task 1: migration과 운영자 역할

**Files:**
- Create: `server/db/migrations/00029_ops.sql`
- Create: `server/internal/platform/postgres/opsrole.go`
- Create: `server/internal/platform/postgres/opsrole_test.go`
- Create: `server/internal/platform/postgres/schema_ops_test.go`
- Modify: `server/internal/cli/cli.go` (`runMigrate`, `DB_RUNTIME_USER` 블록 뒤)

**Interfaces:**
- Produces: `postgres.OpsRole = "myungli_ops"`, `func GrantOpsRole(ctx context.Context, pool *pgxpool.Pool) ([]string, error)`(넣은 사용자 이름 목록), 표 `ops_audit`, 출처 값 `operator`

**migration 00029 내용(Up):**
* `entitlement_grants_source_check`를 `('ad_free_pass','rewarded_ad','subscription','test_grant','operator')`로 바꿈(00022 방식). Down은 `operator` 행을 지우고 이전 목록으로.
* 표:
  ```sql
  CREATE TABLE ops_audit (
      id         uuid        PRIMARY KEY,
      at         timestamptz NOT NULL,
      actor      text        NOT NULL CHECK (actor <> ''),
      channel    text        NOT NULL CHECK (channel IN ('cli', 'admin_api')),
      action     text        NOT NULL CHECK (action IN ('account_show', 'grant', 'revoke', 'content_view', 'audit_list')),
      account_id uuid,
      purpose    text        CHECK (purpose IN ('inquiry', 'incident', 'policy', 'legal')),
      reason     text        NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
      target     jsonb       NOT NULL,
      before     jsonb,
      after      jsonb,
      CONSTRAINT ops_audit_purpose_for_view CHECK ((action = 'content_view') = (purpose IS NOT NULL))
  );
  CREATE INDEX ops_audit_account_idx ON ops_audit (account_id, at DESC);
  CREATE INDEX ops_audit_at_idx ON ops_audit (at);
  ```
  `account_id`에 FK를 두지 않습니다(없는 계정 조회도 기록).
* trigger 함수 `ops_audit_guard()`: `UPDATE`면 예외, `DELETE`면 `OLD.at >= now() - interval '2 years'`일 때 예외. `BEFORE UPDATE OR DELETE ... FOR EACH ROW`.
* `REVOKE UPDATE ON ops_audit FROM myungli_app;`
* 역할 `myungli_ops` NOLOGIN(00024처럼 `duplicate_object` 무시). `GRANT USAGE ON SCHEMA public`, `SELECT ON accounts, auth_identities, devices, entitlement_grants, purchases, diaries, diary_days, schedules, profiles, ops_audit`, `INSERT ON entitlement_grants, ops_audit`, `UPDATE (revoked_at) ON entitlement_grants`, `USAGE ON SEQUENCE entitlement_grants_id_seq`.
* Down: 역할의 권한을 거두고(역할은 지우지 않음, 00024와 같음) trigger, 함수, 표 삭제.

- [ ] **Step 1: 실패하는 테스트 작성** (`schema_ops_test.go`, `dbtest.New`로 migration 적용된 DB)
  * `TestOpsAudit_UpdateRejected`: 행 하나 넣고 `UPDATE ops_audit SET reason='x'`가 오류.
  * `TestOpsAudit_DeleteOnlyOlderThanTwoYears`: `at = now() - interval '2 years 1 day'` 행은 지워지고, `now() - interval '1 year'` 행 `DELETE`는 오류.
  * `TestOpsAudit_PurposeRequiredOnlyForView`: `content_view`에 purpose NULL이면 오류, `grant`에 purpose 값이 있으면 오류.
  * `TestEntitlementGrants_OperatorSourceAllowed`: source `operator` 행 INSERT 성공.
  * `TestMigrate_OpsDownUp`: `MigrateDownTo(28)` 뒤 다시 `Migrate up`이 성공(기존 `migrate_test.go` 방식).
- [ ] **Step 2: `go test ./internal/platform/postgres/ -run 'OpsAudit|OperatorSource|OpsDownUp'` 실행, migration이 없어 FAIL 확인**
- [ ] **Step 3: `00029_ops.sql` 작성 후 같은 명령으로 PASS 확인**
- [ ] **Step 4: 역할 테스트 작성** (`opsrole_test.go`)
  * `TestGrantOpsRole_OnlyHumanIAMUsers`: `CREATE ROLE "op@example.com" LOGIN`, `CREATE ROLE "server@proj.iam" LOGIN`, `CREATE ROLE "nologin@example.com" NOLOGIN`을 만든 뒤 `GrantOpsRole` 결과가 `["op@example.com"]`이고 `pg_has_role('op@example.com','myungli_ops','MEMBER')`가 true, 나머지는 false. 테스트 끝에 역할을 지움(cluster 공용이므로 이름에 테스트별 접미사).
  * `TestOpsRole_Privileges`: `SET ROLE myungli_ops` 상태에서 `SELECT FROM diaries` 성공, `INSERT INTO ops_audit` 성공, `DELETE FROM ops_audit` 실패, `UPDATE entitlement_grants SET expires_at=...` 실패, `UPDATE entitlement_grants SET revoked_at=...` 성공, `INSERT INTO diaries` 실패.
- [ ] **Step 5: FAIL 확인 후 `opsrole.go` 구현.** 대상 조회: `SELECT rolname FROM pg_roles WHERE rolcanlogin AND rolname LIKE '%@%' AND rolname NOT LIKE '%.iam' AND NOT pg_has_role(rolname, 'myungli_ops', 'MEMBER') ORDER BY rolname`; 각 이름에 `GRANT myungli_ops TO <pgx.Identifier>`. 이미 구성원이면 목록에 넣지 않음.
- [ ] **Step 6: `runMigrate`에서 `direction == "up"`이고 `APP_ENV`가 `staging` 또는 `prod`일 때 `GrantOpsRole`을 부르고, 넣은 수만 로그(`"운영자 역할 구성원 추가", "count", n`)로 남김. 이름은 로그에 남기지 않음.** local은 부르지 않음. `TestRunMigrate_GrantsOpsRoleOnlyInDeployedEnv`(local에서 안 부름을 역할 구성원으로 확인)를 `internal/cli`에 더함.
- [ ] **Step 7: `go test -race ./internal/platform/postgres/ ./internal/cli/ -run 'Ops|Migrate'` PASS**
- [ ] **Step 8: Commit** `feat(server): 운영 감사 표와 운영자 역할 (#1321)`

### Task 2: billing의 운영자 부여와 행 회수

**Files:**
- Modify: `server/db/queries/billing.sql`, `server/internal/billing/store.go`
- Create: `server/internal/billing/operator.go`, `server/internal/billing/operator_test.go`
- Modify: `server/internal/httpapi/billing_handlers.go:44-51`, `server/internal/httpapi/billing_handlers_test.go`
- Generated: `server/internal/billing/billingdb/*` (`go generate ./...`)

**Interfaces:**
- Produces:
  * `billing.SourceOperator Source = "operator"`
  * `type OperatorKind string`; `OperatorAdFree OperatorKind = "ad_free"`, `OperatorInsight OperatorKind = "insight"`
  * `type GrantRow struct { ID int64; Entitlement Entitlement; Source Source; SourceRef string; StartsAt, ExpiresAt time.Time; RevokedAt *time.Time }`
  * `func GrantOperatorTx(ctx context.Context, tx pgx.Tx, accountID uuid.UUID, kind OperatorKind, sourceRef string, startsAt, expiresAt time.Time) ([]GrantRow, error)`
  * `func RevokeGroupTx(ctx context.Context, tx pgx.Tx, accountID uuid.UUID, grantID int64, now time.Time) (before, after []GrantRow, err error)`
  * `func ListGrantsTx(ctx context.Context, q billingdb.DBTX, accountID uuid.UUID) ([]GrantRow, error)` (취소, 만료 포함 전부, `starts_at DESC, id DESC`)
  * 오류: `ErrAccountNotActive`, `ErrGrantNotFound`, `ErrGrantNotRevocable`(출처가 `operator`, `rewarded_ad` 밖), `ErrGrantAlreadyEnded`

**새 쿼리:** `LockAccountStatus`(`SELECT status FROM accounts WHERE id=@account_id FOR SHARE`), `InsertOperatorGrant :one`(RETURNING 전체 칸), `GrantByID :one`(`FOR UPDATE`, account_id 조건), `GrantsBySourceRef :many`(같은 계정, 같은 source, 같은 source_ref, `FOR UPDATE`), `RevokeGrantByID :one`(RETURNING), `ListAccountGrants :many`.

**규칙:** `ad_free`는 `ad_free`와 `insight` 두 행(같은 source_ref), `insight`는 한 행. 계정 status가 `active`가 아니면 `ErrAccountNotActive`. 회수는 `grantID` 행의 출처를 보고, `operator`면 같은 source_ref 묶음 전부를, `rewarded_ad`면 그 행만 `revoked_at = now`. 묶음에 끝나지 않은 행이 하나도 없으면(`revoked_at` 있음 또는 `expires_at <= now`) `ErrGrantAlreadyEnded`.

- [ ] **Step 1: 실패하는 테스트 작성** (`operator_test.go`, 트랜잭션은 `postgres` tx 도우미 사용)
  * `TestGrantOperator_AdFreeGivesBothRows`: 행 2개, 둘 다 source `operator`, 같은 source_ref, `Store.Status`가 AdFree, Insight 모두 active이고 Source `operator`.
  * `TestGrantOperator_InsightOnly`: 행 1개, AdFree inactive.
  * `TestGrantOperator_RejectsInactiveAccount`: `pending_deletion` 계정에 `ErrAccountNotActive`, 행 0개.
  * `TestRevokeGroup_OperatorBundleRevokesBoth`: insight 행 id로 회수해도 두 행 모두 `revoked_at` 있음, before 두 행 `RevokedAt` nil, after 두 행 값 있음.
  * `TestRevokeGroup_RewardedAdSingleRow`
  * `TestRevokeGroup_RejectsPassGrant`: `ad_free_pass` 행에 `ErrGrantNotRevocable`, 행 그대로.
  * `TestRevokeGroup_OtherAccountGrantNotFound`: 다른 계정 행 id면 `ErrGrantNotFound`.
  * `TestRevokeGroup_AlreadyEnded`
- [ ] **Step 2: FAIL 확인** `go test ./internal/billing/ -run 'GrantOperator|RevokeGroup'`
- [ ] **Step 3: 쿼리 추가, `go generate ./...`, `operator.go` 구현, PASS 확인**
- [ ] **Step 4: 계약 변환 테스트** `TestContractSource_OperatorMapping`(`billing_handlers_test.go`): Status의 Insight 출처가 `operator`이고 AdFree가 active면 응답 `insight.source`가 `ad_free_pass`, AdFree가 inactive면 `rewarded_ad`. FAIL 확인.
- [ ] **Step 5: `contractSource(s billing.Status) gen.InsightSource`로 바꿔 구현**(출처가 `operator`일 때만 AdFree 활성 여부를 봄, `test_grant`는 그대로 `ad_free_pass`). PASS 확인.
- [ ] **Step 6: `go run ./cmd/contractgate -base origin/staging` 통과, `go generate ./... && git status --porcelain`에 생성물 외 변화 없음**
- [ ] **Step 7: Commit** `feat(server): 운영자 권한 부여와 행 회수 (#1321)`

### Task 3: ops 감사 기록과 Service 뼈대

**Files:**
- Create: `server/internal/ops/ops.go`, `server/internal/ops/audit.go`, `server/internal/ops/audit_test.go`
- Create: `server/db/queries/ops.sql`, `server/internal/ops/opsdb/*`(생성)
- Modify: `server/db/sqlc.yaml`(package `opsdb`, out `../internal/ops/opsdb`, `overrides: *overrides`)

**Interfaces:**
- Produces:
  * `type Channel string` (`ChannelCLI = "cli"`, `ChannelAdminAPI = "admin_api"`), `type Actor struct { ID string; Channel Channel }`
  * `type Purpose string` (`PurposeInquiry`, `PurposeIncident`, `PurposePolicy`, `PurposeLegal`), `func ParsePurpose(s string) (Purpose, error)`
  * `func ValidateReason(s string) (string, error)` (정리한 사유를 돌려줌)
  * `type Action string` (`ActionAccountShow`, `ActionGrant`, `ActionRevoke`, `ActionContentView`, `ActionAuditList`)
  * `type Entry struct { Actor Actor; Action Action; AccountID *uuid.UUID; Purpose *Purpose; Reason string; Target any; Before, After any }`
  * `func recordTx(ctx context.Context, tx pgx.Tx, id uuid.UUID, at time.Time, e Entry) error` (패키지 내부)
  * `type Service struct{ pool *pgxpool.Pool; clk clock.Clock }`, `func NewService(pool *pgxpool.Pool, clk clock.Clock) *Service`
  * `func (s *Service) inTx(ctx context.Context, fn func(pgx.Tx) error) error` (`postgres.InTx(ctx, s.pool, fn)`)
  * 오류: `ErrReason`, `ErrPurpose`, `ErrActor`(빈 ID 또는 모르는 Channel)
- 모든 공개 Service 함수는 먼저 `Actor`와 사유를 검사하고, 감사 행과 데이터 접근을 한 트랜잭션에서 합니다. 커밋에 실패하면 결과 대신 오류를 돌려줍니다.

- [ ] **Step 1: 실패하는 테스트 작성** (`audit_test.go`)
  * `TestValidateReason`: 표 기반. `""`, `"  "`, `"a\nb"`, `"a\rb"`, 501자는 `ErrReason`; `" 환불 확인 "` → `"환불 확인"`; 500자 통과.
  * `TestParsePurpose`: 네 값 통과, `"Inquiry"`, `""`, `"other"`는 `ErrPurpose`.
  * `TestRecordTx_WritesRow`: `Target: map[string]any{"date":"2026-11-01"}`, Before nil이 DB에 `target` JSON과 `before IS NULL`로 남음.
- [ ] **Step 2: FAIL 확인 → 구현 → PASS** `go test ./internal/ops/`
- [ ] **Step 3: Commit** `feat(server): 운영 감사 기록 쓰기 (#1321)`

### Task 4: 계정 조회와 감사 기록 조회

**Files:**
- Create: `server/internal/ops/account.go`, `server/internal/ops/account_test.go`, `server/internal/ops/auditlist.go`, `server/internal/ops/auditlist_test.go`
- Modify: `server/db/queries/ops.sql`

**Interfaces:**
- Consumes: Task 2 `billing.ListGrantsTx`, `billing.Store.Status`(또는 같은 계산), Task 3 전부
- Produces:
  * `type AccountKey struct { AccountID uuid.UUID; StoreTransaction string }` (정확히 하나만 값, 아니면 `ErrAccountKey`)
  * `func (s *Service) AccountSummary(ctx context.Context, actor Actor, key AccountKey, reason string) (AccountSummary, error)`
  * `type AccountSummary struct { Account AccountInfo; Identities []IdentityInfo; Devices []DeviceInfo; Status billing.Status; Grants []billing.GrantRow; Purchases []PurchaseInfo }`
  * `AccountInfo{ID uuid.UUID; Status string; CreatedAt time.Time; DeletionRequestedAt *time.Time; LastActiveAt time.Time}`, `IdentityInfo{Provider string; LinkedAt time.Time; DisconnectedAt *time.Time}`, `DeviceInfo{Platform string; Active bool; CreatedAt, LastSeenAt time.Time}`, `PurchaseInfo{ProductID, Store string; StorePurchaseID *string; PurchasedAt time.Time; RefundedAt *time.Time; Production bool; MergedFrom *uuid.UUID}`(원래 계정이 다르면 `original_account_id`)
  * `ErrAccountNotFound`, `type AmbiguousTransactionError struct{ AccountIDs []uuid.UUID }`
  * `func (s *Service) AuditList(ctx context.Context, actor Actor, filter AuditFilter, reason string) ([]AuditRecord, error)`; `AuditFilter{AccountID *uuid.UUID; Since *time.Time; Limit int}`(둘 중 하나 이상, Limit 기본 100 최대 1000); `AuditRecord`는 표 칸 그대로(`Target`, `Before`, `After`는 `json.RawMessage`)
- 감사 `target`: 계정 키(`{"accountId":...}` 또는 `{"storeTransaction":...}`). 없는 계정도 감사 행을 쓰고 커밋한 뒤 `ErrAccountNotFound`. AuditList의 감사 행은 필터를 `target`으로, `account_id`는 필터의 계정.

- [ ] **Step 1: 실패하는 테스트 작성**
  * `TestAccountSummary_ShowsSupportFields`: 계정, kakao 연결, 기기 둘, 운영자 부여, sandbox 구매 하나를 만든 뒤 결과 칸 값 확인. `Identities`에 subject가 없음은 타입으로 보장.
  * `TestAccountSummary_WritesAuditBeforeReturning`: 감사 행 하나, action `account_show`, `actor`가 넘긴 값, `account_id` 일치.
  * `TestAccountSummary_NotFoundStillAudited`: 없는 id → `ErrAccountNotFound`, 감사 행 `account_id` NULL.
  * `TestAccountSummary_ByStoreTransaction`
  * `TestAccountSummary_StoreTransactionAmbiguous`: 두 계정에 같은 `(store, store_purchase_id)` → `AmbiguousTransactionError`에 두 id, 상세 없음, 감사 행은 남음.
  * `TestAccountSummary_AuditFailureReturnsNothing`: `ops_audit` INSERT 권한을 뺀 역할로 연결(`SET ROLE` 테스트 역할)해 오류이고 결과가 zero value.
  * `TestAuditList_FiltersAndAuditsItself`: 기록 셋 중 계정 필터로 둘, 그리고 `audit_list` 행이 새로 생김.
  * `TestAuditList_RequiresFilter`
- [ ] **Step 2: FAIL 확인 → 쿼리와 구현 → PASS** `go test -race ./internal/ops/`
- [ ] **Step 3: Commit** `feat(server): 운영 계정 조회와 감사 기록 조회 (#1321)`

### Task 5: 권한 부여와 회수 Service

**Files:**
- Create: `server/internal/ops/grant.go`, `server/internal/ops/grant_test.go`

**Interfaces:**
- Consumes: Task 2 `GrantOperatorTx`, `RevokeGroupTx`, 오류들; Task 3
- Produces:
  * `type GrantRequest struct { AccountID uuid.UUID; Kind billing.OperatorKind; ExpiresAt time.Time; Reason string }`
  * `func (s *Service) Grant(ctx context.Context, actor Actor, req GrantRequest) (GrantResult, error)`; `GrantResult{AuditID uuid.UUID; Grants []billing.GrantRow}`
  * `type RevokeRequest struct { AccountID uuid.UUID; GrantID int64; Reason string }`
  * `func (s *Service) Revoke(ctx context.Context, actor Actor, req RevokeRequest) (RevokeResult, error)`; `RevokeResult{AuditID uuid.UUID; Before, After []billing.GrantRow}`
  * `ErrGrantPeriod`(만료가 지금 이전이거나 366일 초과)
- 부여: 감사 id를 먼저 만들고 그 문자열을 `source_ref`로. 감사 `target {"kind","expiresAt"}`, `before` null, `after` 만든 행들. 회수: `target {"grantId"}`, `before`/`after` 행들. 거절(`ErrAccountNotActive`, `ErrGrantNotRevocable`, `ErrGrantNotFound`, `ErrGrantAlreadyEnded`)은 트랜잭션을 되돌리고 감사 행도 남기지 않음(바뀐 것 없음).

- [ ] **Step 1: 실패하는 테스트 작성**
  * `TestGrant_SourceRefIsAuditID`: 결과 행의 `SourceRef == AuditID.String()`, 감사 `after`에 행 두 개.
  * `TestGrant_PeriodBounds`: 만료 = now-1s, now+366일+1s는 `ErrGrantPeriod`; now+366일은 통과(시계는 `clock` 고정 대역).
  * `TestRevoke_AdFreeBundleRevokesBoth`(Review Focus 4)
  * `TestRevoke_PassGrantRejectedNoAudit`: 감사 행 0개.
  * `TestGrant_AuditFailureRollsBackGrant`: 감사 INSERT 권한이 없으면 권한 행도 0개.
- [ ] **Step 2: FAIL 확인 → 구현 → PASS** `go test -race ./internal/ops/ -run 'Grant|Revoke'`
- [ ] **Step 3: Commit** `feat(server): 운영 권한 부여와 회수 (#1321)`

### Task 6: 콘텐츠 열람

**Files:**
- Create: `server/internal/ops/content.go`, `server/internal/ops/content_test.go`
- Modify: `server/db/queries/ops.sql`

**Interfaces:**
- Produces:
  * `type ContentTarget struct { AccountID uuid.UUID; Date *profile.LocalDate; ID *uuid.UUID }` (Date와 ID 중 정확히 하나, 아니면 `ErrContentTarget`, `internal/diary`와 같은 날짜 타입)
  * `type ViewRequest struct { Target ContentTarget; Purpose Purpose; Reason string }`
  * `func (s *Service) ViewDiary(ctx context.Context, actor Actor, req ViewRequest) (DiaryView, error)`; `DiaryView{Entries []DiaryEntry; DeletedCount int; Tags []string}`, `DiaryEntry{ID uuid.UUID; Date profile.LocalDate; Body string; CreatedAt, UpdatedAt time.Time}`
  * `func (s *Service) ViewSchedule(ctx, actor, req ViewRequest) (ScheduleView, error)`; `ScheduleView{Entries []ScheduleEntry; DeletedCount int}`, `ScheduleEntry{ID uuid.UUID; Date profile.LocalDate; AllDay bool; Time *string; Title string; Memo *string}`
  * `func (s *Service) ViewProfile(ctx context.Context, actor Actor, accountID uuid.UUID, purpose Purpose, reason string) (ProfileView, error)`; `ProfileView`는 `profiles` 칸 중 호칭, 언어, 현재 시간대, 달력, 윤달, 생년월일, 시간 상태, 시각, 성별, 출생 시간대, 출생지 상태, 도시 id, 경도
- 감사 `target`: `{"kind":"diary|schedule|profile","date"|"id":..., "ids":[연 항목 id], "count":n}`. 본문 없음. 목적은 감사 `purpose`.
- 살아 있는 항목만(`deleted_at IS NULL AND content_purged_at IS NULL`) 보여 주고, 그날 지운 항목은 개수만.

- [ ] **Step 1: 실패하는 테스트 작성**
  * `TestViewDiary_ByDate`, `TestViewDiary_ByID`, `TestViewDiary_OtherAccountIDNotVisible`(id가 다른 계정 것이면 빈 결과)
  * `TestViewDiary_ExcludesDeletedAndPurged`(Review Focus 2)
  * `TestViewDiary_AuditHasIDsNotBody`: 감사 `target`에 id 목록과 count, 본문 문자열이 감사 행 어디에도 없음(`target::text NOT LIKE '%본문%'`).
  * `TestViewDiary_AuditFailureReturnsNothing`(Review Focus 1)
  * `TestViewSchedule_ByDate`, `TestViewProfile_Audited`
  * `TestView_RequiresExactlyOneOfDateOrID`
- [ ] **Step 2: FAIL 확인 → 구현 → PASS** `go test -race ./internal/ops/ -run View`
- [ ] **Step 3: Commit** `feat(server): 운영 콘텐츠 열람 (#1321)`

### Task 7: CLI `server ops`

**Files:**
- Create: `server/internal/cli/ops.go`, `server/internal/cli/ops_test.go`
- Modify: `server/internal/cli/cli.go` (`commands`에 `"ops": runOps`, `usageText`에 `ops account|grant|revoke|content|audit  운영 명령을 실행합니다(runbook)`)

**Interfaces:**
- Consumes: Task 3~6 Service 함수
- Produces: 하위 명령과 인자
  * `ops account show (--account <uuid> | --store-transaction <id>) --reason <s> [--json]`
  * `ops grant --account <uuid> --entitlement ad_free|insight (--days <1~366> | --until <RFC3339>) --reason <s> [--json]`
  * `ops revoke --account <uuid> --grant <id> --reason <s> [--json]`
  * `ops content diary|schedule --account <uuid> (--date YYYY-MM-DD | --id <uuid>) --purpose <p> --reason <s> [--json]`
  * `ops content profile --account <uuid> --purpose <p> --reason <s> [--json]`
  * `ops audit list (--account <uuid> | --since YYYY-MM-DD) [--limit n] --reason <s> [--json]`
- 실행자: 연결 뒤 `SELECT session_user`를 `Actor{ID, ChannelCLI}`로. 설정은 `config.Load` + `RequireDatabase`만(다른 Load 함수 부르지 않음).
- 출력: 기본은 `text/tabwriter` 표(절 제목: 계정, 로그인 수단, 기기, 권한 상태, 권한 행, 구매), `--json`은 결과 구조체를 `encoding/json` 들여쓰기로. 모두 stdout. 오류는 stderr에 한 줄(본문 없음). 끝에 `감사 기록 <id>`를 stdout 마지막 줄에(부여, 회수).
- 종료 코드: 인자 오류 2(DB에 붙기 전), `ErrAccountNotFound`, 거절, 권한 오류 1. 권한 오류(`SQLSTATE 42501`)는 `"DB 사용자 <session_user>에 운영자 역할이 없습니다. runbook '운영자 등록'을 보세요"`.

- [ ] **Step 1: 실패하는 테스트 작성** (`ops_test.go`, 기존 `cli_test.go`처럼 `Run`에 getenv, stdout, stderr 주입, DB는 `dbtest.NewURL`)
  * `TestOps_UsageErrors`: 표 기반, 사유 없음, 목적 틀림, `--date`와 `--id` 둘 다, `--days 0`, `--days`와 `--until` 둘 다, 모르는 하위 명령 → 종료 코드 2, DATABASE_URL을 비워도 2(DB에 붙지 않음).
  * `TestOps_AccountShowText`: stdout에 절 제목과 계정 id, stderr 비어 있음.
  * `TestOps_GrantThenRevokeJSON`: `--json` 출력 파싱, 부여 행 id로 회수, 종료 코드 0.
  * `TestOps_ContentBodyOnlyOnStdout`: 일기 본문 문자열이 stdout에만 있고 stderr에 없음.
  * `TestOps_ActorIsSessionUser`: 감사 행 `actor`가 연결 사용자 이름.
- [ ] **Step 2: FAIL 확인 → 구현 → PASS** `go test -race ./internal/cli/ -run Ops`
- [ ] **Step 3: Commit** `feat(server): 운영 명령 server ops (#1321)`

### Task 8: retention 정리

**Files:**
- Modify: `server/db/queries/retention.sql`, `server/internal/retention/retention.go`, `server/internal/retention/*_test.go`

**Interfaces:**
- Produces: `retention.OpsAuditYears = 2`, 쿼리 `DeleteOpsAuditBefore :execrows`(`at < @before`), `DeleteOperatorGrantsEndedBefore :execrows`(source `operator`, `COALESCE(revoked_at, expires_at) < @before`), `Steps()`에 `{Name: "운영 감사 기록"}`, `{Name: "운영자 부여 권한"}`를 `years(OpsAuditYears, ...)` 같은 기존 연 단위 도우미로.

- [ ] **Step 1: 실패하는 테스트** `TestSteps_DeletesOpsAuditOlderThanTwoYears`(2년 1일 전 행 지움, 1년 전 행 남음, trigger와 충돌 없음), `TestSteps_DeletesOperatorGrantsEndedTwoYearsAgo`
- [ ] **Step 2: FAIL 확인 → 구현 → PASS** `go test -race ./internal/retention/`
- [ ] **Step 3: Commit** `feat(server): 운영 감사 기록 2년 보관 정리 (#1321)`

### Task 9: 문서, 결정, 보고

**Files:**
- Create: `server/docs/runbooks/ops.md`
- Modify: `server/docs/decisions.md`(S170 행), `server/CLAUDE.md`("다음 할 일"에 운영 명령 한 줄), `server/deploy/terraform/README.md`(운영자 등록 절), `docs/local-values.md`(server 행에 `server/<환경>/ops.env`: `APP_ENV`, `CLOUD_SQL_INSTANCE`, `DATABASE_URL`(메일 사용자 이름 포함, 비밀번호 없음))

**runbook 내용:** 준비(`gcloud auth login`, `gcloud auth application-default login`, `ops.env` 만들기와 `set -a; source`), 운영자 등록(`gcloud sql users create <메일> --instance=<인스턴스> --type=cloud_iam_user`, 소유자가 아니면 `roles/cloudsql.client`, `roles/cloudsql.instanceUser` 부여, `gcloud run jobs execute server-migrate --region ... --wait`), 운영자 빼기, 명령별 예시(Task 7 인자 그대로), 종료 코드 표, 감사 기록 보는 법. 목적별 운영 기준은 적지 않습니다.

**S170 요점:** 로컬 실행과 이유(Job 출력이 Cloud Logging), 실행자는 `session_user`, 운영자 등록과 판별 규칙, `myungli_ops` 권한, 출처 `operator`와 계약 변환(S125 선례), 회수 범위, 감사 표와 trigger, 2년 보관, 조회도 기록, 합치기에서 옮기지 않음, 요청 로그와 앱 버전은 보이지 않음.

- [ ] **Step 1: 문서 작성.** 사용자에게 보이는 글이 아니어도 runbook에 긴 대시와 가운뎃점 없음을 `grep -nP '[\x{2014}\x{2013}\x{00B7}]' server/docs/runbooks/ops.md`가 비어 있음으로 확인
- [ ] **Step 2: 전체 검사** `cd server && go vet ./... && golangci-lint run ./... && go test -race ./...`, `go vet -tags staging ./... && golangci-lint run --build-tags staging ./...`, `go run ./cmd/contractgate -base origin/staging`, `go generate ./... && git status --porcelain` 비어 있음
- [ ] **Step 3: Commit** `docs(server): 운영 명령 runbook과 S170 (#1321)`
- [ ] **Step 4: push, PR**(`Closes #1321`), 지휘 보고 코멘트: spec §9의 세 항목(처리방침 목적 두 가지, 요청 로그와 앱 버전, 감사 기록 2년 대장 반영)과 Issue 4번 실행 방식을 로컬 실행으로 바꾼 이유
