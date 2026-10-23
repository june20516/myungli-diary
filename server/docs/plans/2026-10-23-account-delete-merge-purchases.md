# 계정 삭제·계정 합치기·구매 장부 (D85·D88) Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 계정 삭제를 즉시 실제 삭제로, 허가 취소를 재시도로, 구매를 산 계정에 고정하는 장부로, 계정 합치기를 별도 입구(A 고정·프로필 선택·기록과 구매 이동)로 바꾸고 REST draft.15에 담습니다.

**Architecture:** 계약을 먼저 한 PR로 내고(PR 1), 그 위에 계정 삭제(PR 2)·구매 장부(PR 3)·합치기(PR 4)를 쌓습니다. 계정 삭제는 `account.DeleteAccountTx`가 한 트랜잭션에서 지우고 허가 취소 대기 행을 넣으며, 합치기가 같은 함수를 B에 부릅니다. 구매 장부 `purchases`는 주인을 처음 적은 계정으로 고정하고 사용 구간(`entitlement_grants`)을 저장해 환불·합치기 때만 지금부터 다시 잇습니다.

**Tech Stack:** Go 1.27, sqlc/pgx/goose, oapi-codegen strict server, kin-openapi(계약 테스트), testcontainers(`dbtest`), `clock.Clock`, `postgres.InTx`

**Spec:** `server/docs/specs/2026-10-23-account-delete-merge-purchases-design.md`(§ 번호는 이 spec). REST 계약 `server/api/openapi.yaml` 1.0.0-draft.14 → draft.15.

## Global Constraints

* 용어는 D85 ①의 다섯 이름(유저 계정·인증 계정·프로필·기록·구매)만 씁니다. 코드 주석·결정·계약 설명도 같습니다.
* `accounts.status`는 `active`·`deleted` 둘뿐입니다. 삭제 대기·30일 유예·복구 로그인은 없습니다(S105).
* 계정 삭제 "지움": `profiles`, `diaries`, `diary_days`, `schedules`, `daily_selections`, `reactions`, `rotation_state`, `consents`, `auth_identities`, `refresh_tokens`, `idempotency_keys`, `account_merge_tickets`(A·B 어느 쪽이든), 그 계정 `birth_hash`의 `chart_cache`·`daily_cache`·`month_cache`. "남김": `accounts` 껍데기, `purchases`, `entitlement_grants`, `billing_events`, `reward_events`, `preview_usage`, `provider_revocations`(§3.2).
* 반응은 지우기 전에 `reaction_tallies(message_key, variant, reaction, count)`에 더합니다. `deleted_at`이 있는 반응은 더하지 않습니다.
* 허가 취소 대기: 카카오·Apple만. 다음 시도 간격 `1분 × 2^(attempts−1)`, 최대 24시간. `created_at`에서 30일 지나면 포기(Error 로그는 `id`·`provider`만). 이미 끊긴 경우는 성공(§4.2).
* 구매 주인은 장부에 처음 적은 유저 계정이고 합치기 말고는 바뀌지 않습니다. RevenueCat transfer는 주인을 바꾸지 않습니다(S107).
* 사용 구간: 새 구매 `starts_at = max(purchased_at, 이 계정 같은 권한 구간 끝)`, `expires_at = addMonth(starts_at)`. 지난 구간은 다시 계산하지 않습니다(S108).
* 구매 목록 상태(열린 enum `PurchaseStatus`): `active`·`pending`·`expired`·`refunded`·`owned`. 산 계정·합치기 출처는 주지 않습니다(S109).
* 합치기: A가 남고 `profile: current | other`, 기록·구매를 옮기고 B는 `DeleteAccountTx`로 지움. 겹치면 고른 프로필 쪽. `Idempotency-Key`를 받음. 응답은 A의 `Me`(S111).
* problem code: `auth.identity_pending_deletion` 없앰, `merge.same_account`·`merge.no_account`(422) 더함(S112).
* 로그에 id_token·nonce·subject·합치기 토큰 원문·제공자 token·호칭·출생 정보를 남기지 않습니다.
* ID는 UUIDv7, 시각 `timestamptz`. 업무 시각은 `clock.Clock`에서 받습니다.
* 공개 저장소(D74): 커밋·PR·fixture에 가격·수익 수치와 비공개 경로 링크를 넣지 않습니다.
* 2026-10-24부터 쓰는 server 결정 행은 근거 칸에 `사용자 영향: 없음` 또는 `D<n>`·`#<n>` 표시를 붙입니다(D87).
* 브랜치: PR 1은 `server/d85-contract`(이미 있음, #473 위). PR 2~4는 앞 PR 병합 뒤 `git fetch origin && git switch -c <브랜치> --no-track origin/main && git push -u origin <브랜치> && git status -sb`(2 `server/d85-account-delete`, 3 `server/d88-purchase-ledger`, 4 `server/d85-merge`). 앞 PR이 아직 병합 전이면 그 브랜치에서 `--no-track`으로 쌓고 같은 이름으로 push합니다.

## Review Focus

1. 계정 삭제 요청 도중 같은 계정의 다른 요청(일기 저장·동기화)이 옴: 삭제가 끝난 뒤 그 요청은 401이고, 지운 계정에 새 행이 생기지 않아야 합니다(FK 위반 500이 아님). Task 4에서 고정합니다.
2. RevenueCat 장애로 결제 직후 동기화가 실패한 뒤 webhook으로 처음 들어온 구매: webhook 후보 계정이 주인이 되고 구간이 한 번만 생겨야 합니다(같은 이벤트 재전송에도). Task 9에서 고정합니다.
3. 환불이 주인이 아닌 계정의 동기화(transfer된 RevenueCat 고객)로 처음 보임: 주인 계정의 구간이 끊기고 뒤 구간이 앞당겨져야 합니다. Task 9에서 고정합니다.
4. 합치기 토큰을 받은 뒤 B가 스스로 계정을 지우거나 그 인증 계정을 뗌: `mergeAccounts`는 422 `merge.token_invalid`이고 A는 바뀌지 않아야 합니다. Task 12에서 고정합니다.
5. `mergeAccounts` 응답이 사라져 같은 `Idempotency-Key`로 다시 보냄: 같은 200 `Me`, 다른 키로 다시 보내면 422 `merge.token_invalid`. Task 12에서 고정합니다.

---

## 결정 (plan이 정한 것)

| # | 결정 | 근거 |
| --- | --- | --- |
| P-1 | PR 1에서는 `ErrIdentityPendingDeletion`을 409 `auth.identity_in_use`로 바꿔 보냅니다. PR 2가 그 오류 자체를 없앱니다 | 계약에서 code를 빼면 problem code 대조 테스트가 막음. 그 사이 응답 의미("다른 계정에 있음")는 같음 |
| P-2 | PR 1의 `linkIdentity` handler는 409 본문에 토큰을 싣지 않고, 발급(`issueMergeTicket`)은 PR 2가 지웁니다 | 계약 모양은 PR 1, 동작 정리는 PR 2(spec §2) |
| P-3 | 계정 삭제 핵심은 `account.DeleteAccountTx(ctx, tx pgx.Tx, accountID uuid.UUID, now time.Time) ([]int64, error)`입니다. 허가 취소 대기 행을 SQL `INSERT … SELECT FROM auth_identities`로 넣으므로 account가 auth를 import하지 않습니다 | 합치기가 같은 트랜잭션에서 부름(D85 ④). 순환 import 방지 |
| P-4 | 허가 취소 실행은 `auth.Revocations`(`Attempt`·`RetryDue`)입니다. 계정 삭제와 합치기는 `account.Revoker` 인터페이스로 받습니다 | 제공자 호출 코드는 auth에만 둠 |
| P-5 | migration `00015`가 남은 `pending_deletion` 계정을 SQL로 같은 목록대로 지우고 `deleted`로 바꿉니다(staging만 해당, 출시 전) | spec §3.2. 반응 집계는 하지 않음(staging) |
| P-6 | 상품 목록 `billing.Catalog map[string]Product`(`Product{Months int; Entitlements []Entitlement}`)는 지금 설정 `AdFreeProductIDs`에서 만듭니다(각 1개월, `ad_free`·`insight`). 새 환경 변수는 없습니다 | spec §5.1, YAGNI |
| P-7 | 합치기 코드는 새 패키지 `internal/merge`(쿼리 `db/queries/merge.sql`, sqlc `mergedb`)입니다. 증명 검증은 `auth.Service.VerifyProof`로 auth에 둡니다 | 여러 도메인 표를 한 트랜잭션에서 건드림. 제공자 코드는 auth |
| P-8 | B의 구매 이동은 `billing.MovePurchasesTx(ctx, tx, from, to uuid.UUID, now time.Time) error`입니다. 두 계정 billing lock을 uuid 순서로 잡습니다 | 동기화와 같은 lock 규칙(S82) |

---

## PR 1: 계약 (draft.15)

### Task 1: REST 계약 draft.15, 생성 코드, handler 응답 모양

**Files:**
- Modify: `server/api/openapi.yaml`, `server/api/contract_test.go`
- Regenerate: `server/internal/httpapi/gen/`(`go generate ./api/...`)
- Modify: `server/internal/httpapi/problem/codes.go`, `problem/problem.go`(`MergeToken`·`ExpiresAt` 필드 제거), `internal/httpapi/errors.go`, `me_handlers.go`, `auth_handlers.go`, `identity_handlers.go`, `unimplemented.go`(`ListPurchases` stub)
- Test: 위 handler의 `_test.go`, `internal/httpapi/problem_codes_test.go`

**Interfaces:**
- Produces: `gen.ListPurchases*`, `gen.Purchase`, `gen.PurchaseStatus`, `gen.MergePreviewRequest`(B 증명: `provider` 필수 + `LinkIdentityRequest`의 필드), `gen.MergePreview`(`mergeToken`, `expiresAt`, `summary`), `gen.MergeRequest{MergeToken string; Profile gen.MergeProfile}`(`current`·`other`), `gen.MergeAccounts200JSONResponse`(= `Me`), `gen.DeleteMe204Response`. 이후 task는 이 이름을 씁니다.

- [ ] **Step 1: 계약 테스트 먼저**

`TestContract_VersionIsDraft14` → `TestContract_VersionIsDraft15`(`info.version == "1.0.0-draft.15"`). `expectedOperationIDs`에 `listPurchases`. `TestContract_CreatePostsAcceptIdempotencyKey`의 목록에 `mergeAccounts`. 새 테스트:

```go
func TestContract_Draft15AccountShapes(t *testing.T) {
	// deleteMe: 204만 있고 202 없음, 스키마 DeletionScheduled 없음
	// Me: status·deletionScheduledAt 없음 / LoginResponse: restoredFromDeletion 없음
	// Problem: mergeToken·expiresAt 없음
	// MergeRequest.required == [mergeToken, profile], profile enum [current, other], keep 없음
	// mergeAccounts 200 → $ref Me / previewMerge 422에 merge.same_account·merge.no_account·request.invalid
	// listPurchases 200 → {items: Purchase[]}, Purchase.required == [productId, purchasedAt, status], period 선택
	// PurchaseStatus enum == [active, pending, expired, refunded, owned]이고 open-enum 목록에 PurchaseStatus
}
```

- [ ] **Step 2: 실행해 실패 확인**

Run: `go test ./api/ -run 'TestContract_' -count=1`
Expected: FAIL(`draft.14`, 새 shape 없음)

- [ ] **Step 3: `openapi.yaml`을 spec §9대로 고침**

`info.version` 1.0.0-draft.15, `info.description`의 변경 이력·열린 enum 목록(`PurchaseStatus`). `deleteMe`·`linkIdentity`·`previewMerge`·`mergeAccounts`·`restorePurchases` 설명을 spec §3·§6·§5.4 문장으로 바꿉니다(삭제 대기·30일·복구 문구를 모두 지움). problem code 표에서 `auth.identity_pending_deletion`을 빼고 `merge.same_account`·`merge.no_account`를 더합니다. `listPurchases`는 bearer 필수, 401·500 problem. 그런 다음 `go generate ./api/...`.

- [ ] **Step 4: 생성 코드에 맞춰 handler 고침**

`DeleteMe`: 지금 `RequestDeletion`을 그대로 부르고 `gen.DeleteMe204Response{}`. `GetMe`·로그인 handler: 없어진 필드를 채우지 않음. `LinkIdentity`: 409 본문에 토큰 없음. `errors.go`: `ErrIdentityPendingDeletion`→409 `auth.identity_in_use`(P-1), `*IdentityInUseError`의 토큰을 problem에 싣지 않음. `problem.Problem`·`httpapi.Error`의 `MergeToken`·`ExpiresAt`(`MergeExpiresAt`) 제거. `codes.go`에 두 code 더하고 하나 뺌. `Unimplemented.ListPurchases`는 `ErrNotImplemented`. `previewMerge`·`mergeAccounts` stub은 그대로 501.

- [ ] **Step 5: 계약 검사 전부 통과 확인**

Run: `go generate ./... && git status --porcelain` (출력 없음), `go test -race ./api/ ./internal/httpapi/ ./internal/cli/ -count=1`
Expected: PASS. 고친 handler 테스트(`me_handlers_test.go`의 deleteMe 204, `identity_handlers_test.go`의 409에 `mergeToken` 키 없음)도 이 실행에 들어 있습니다.

- [ ] **Step 6: Commit**

```bash
git add server/api server/internal/httpapi
git commit -m "feat(server): REST 계약 draft.15 (D85·D88 계정 삭제·합치기·구매 목록)"
```

### Task 2: 결정·문서 개정과 app 요청

**Files:**
- Modify: `server/docs/decisions.md`(S105~S113 추가, S7·S16·S83·S95·S100~S104 행에 "→ S1xx로 개정" 표시), `server/docs/specs/2026-10-22-login-providers-merge-design.md`(§3.3·§4·§5 머리에 대체 표시), `docs/contracts/README.md`(server REST 행을 draft.15와 변경 요약으로), `server/CLAUDE.md`(현재 상태 한 줄, 다음 할 일 1번을 이 plan의 PR 2~4로)
- Issue: app 앞 `kind:request` 하나(라벨 `from:server`·`to:app`·`kind:request`), #481에 §7 보관 기간 표 코멘트

- [ ] **Step 1: 결정 행 작성**

spec §11의 S105~S113을 그 문장으로 옮기고 근거 칸은 `spec 2026-10-23-account-delete-merge-purchases §n`과 D85·D88. 개정되는 행은 내용을 지우지 않고 끝에 `(→ S105로 개정)` 식으로 표시합니다.

- [ ] **Step 2: 문서 검사**

Run: `cd .. && python3 -m pytest tools -q -k "decisions or contracts"` (없으면 `docs` job과 같은 명령을 `.github/workflows/ci-gate.yml`에서 찾아 실행)
Expected: PASS

- [ ] **Step 3: Commit, app 요청, #481 코멘트**

```bash
git add server/docs docs/contracts/README.md server/CLAUDE.md
git commit -m "docs(server): S105~S113, D82 spec 대체 표시, 계약 표 draft.15"
```

app 요청 본문: spec §9 "깨짐" 항목 전부, `previewMerge`→`mergeAccounts` 흐름, `listPurchases`, #463과 달라진 점(409 토큰 없음, 합치기 별도 입구), S3 freeze 전. #481 코멘트: spec §7 표와 "법률 검토 필요".

---

## PR 2: 계정 삭제 (`server/d85-account-delete`)

### Task 3: migration 00015 (계정 상태, 허가 취소 대기, 반응 집계)

**Files:**
- Create: `server/db/migrations/00015_account_delete.sql`
- Modify: `server/internal/platform/postgres/migrate_test.go`(`wantSources`에 00015)
- Test: `server/internal/platform/postgres/schema_account_delete_test.go`

- [ ] **Step 1: 스키마 테스트 작성**

```go
func TestSchema00015_AccountStatus(t *testing.T)        // 'pending_deletion' INSERT는 CHECK 위반, ('deleted', deleted_at NULL)도 위반
func TestSchema00015_PendingAccountsDeleted(t *testing.T) // 00014까지 올리고 pending 계정(프로필·일기·연결 포함)을 넣은 뒤 Up → 그 계정 status='deleted', 자식 행 0
func TestSchema00015_ProviderRevocationsHasNoFK(t *testing.T) // 원래 identity·account 행을 지워도 revocation 행이 남음
func TestSchema00015_DownRestores(t *testing.T)          // MigrateDownTo(14) 성공
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/platform/postgres/ -run 'TestSchema00015|TestMigrate' -count=1` / Expected: FAIL

- [ ] **Step 3: `00015_account_delete.sql` 작성**

Up: (1) P-5대로 `pending_deletion` 계정의 자식 행을 Global Constraints "지움" 목록 순서(자식부터)로 지움 (2) `accounts`에 `deleted_at timestamptz`, 기존 `deleted`/`pending` 행은 `deleted_at = coalesce(anonymized_at, deletion_requested_at)`, status를 `deleted`로 (3) `deletion_requested_at`·`anonymized_at`와 옛 CHECK 제거, 새 CHECK `(status = 'active' AND deleted_at IS NULL) OR (status = 'deleted' AND deleted_at IS NOT NULL)`, status CHECK `IN ('active','deleted')` (4) `auth_identities.provider_disconnected_at` 제거 (5) `provider_revocations`(spec §4.1 열, `provider IN ('kakao','apple')`, Apple 세 열은 모두 있거나 모두 없음, 인덱스 `(next_attempt_at)`) (6) `reaction_tallies(message_key text, variant text, reaction text, count bigint NOT NULL CHECK (count > 0), PRIMARY KEY (message_key, variant, reaction))`. Down은 열·표를 되돌리고 status는 `deleted`로 둡니다(지운 데이터는 되돌리지 않음을 주석으로).

- [ ] **Step 4: 통과 확인** — Run: Step 2 명령 / Expected: PASS. `go test ./internal/diary/ -run Migration -count=1`도 PASS(DownTo 기준 확인).

- [ ] **Step 5: Commit** — `git commit -m "feat(server): migration 00015 계정 상태·허가 취소 대기·반응 집계"`

### Task 4: `account.DeleteAccountTx`와 `deleteMe`

**Files:**
- Create: `server/internal/account/delete.go`, `server/internal/account/delete_test.go`
- Modify: `server/db/queries/account.sql`(삭제 쿼리들), `server/internal/account/service.go`(`RequestDeletion`·`endSessions`·`StatusPendingDeletion` 제거, `Delete` 추가), `server/internal/httpapi/me_handlers.go`(`DeleteMe` → `Delete`)
- Test: `server/internal/account/delete_test.go`, `server/internal/httpapi/me_handlers_test.go`

**Interfaces:**
- Produces:
  - `func DeleteAccountTx(ctx context.Context, tx pgx.Tx, accountID uuid.UUID, now time.Time) (revocationIDs []int64, err error)` — 이미 `deleted`면 `(nil, nil)`. 계정 행이 없으면 `ErrAccountNotFound`(지금 sentinel).
  - `type Revoker interface { Attempt(ctx context.Context, ids []int64) }`
  - `func (s *Service) Delete(ctx context.Context, id uuid.UUID) error` — `InTx`로 `DeleteAccountTx`, commit 뒤 `revoker.Attempt`(요청 취소와 분리된 context). `NewService`에 `Revoker` 인자를 더하고 `SessionEnder`는 뺍니다(세션은 행 삭제로 끝남).

- [ ] **Step 1: 테스트 작성**

```go
func TestDeleteAccountTx_RemovesPersonalData(t *testing.T)
// 모든 "지움" 표와 "남김" 표(purchases 제외, PR 3)를 채운 계정 → 지움 표의 그 계정 행 0, 남김 표 행 수 그대로,
// accounts.status='deleted'·deleted_at=now, 다른 계정 행은 그대로
func TestDeleteAccountTx_TalliesReactions(t *testing.T)
// 같은 (message_key, variant)에 반응 like 2개(하나는 deleted_at 있음) → tally count 1; 이미 tally 3이면 4
func TestDeleteAccountTx_QueuesKakaoAndAppleOnly(t *testing.T)
// kakao·apple·line·google 연결 → revocation 2행, apple 행의 암호화 열·identity_id가 원래 값
func TestDeleteAccountTx_AlreadyDeletedIsNoop(t *testing.T)
func TestService_Delete_ConcurrentWriteGets401(t *testing.T)
// 삭제 트랜잭션이 계정 행을 잡은 동안 일기 저장 요청 → 삭제 commit 뒤 401 auth.token_invalid, diaries에 새 행 없음 (Review Focus 1)
```

`me_handlers_test.go`: `deleteMe` 204, 그 뒤 같은 access token의 `getMe`는 401.

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/account/ ./internal/httpapi/ -run 'DeleteAccount|Delete|DeleteMe' -count=1` / Expected: FAIL

- [ ] **Step 3: 구현**

`account.sql`에 쿼리: `LockAccountForDelete`(FOR UPDATE, status 반환), `QueueProviderRevocations`(INSERT … SELECT, `RETURNING id`), `TallyReactions`(INSERT … SELECT … GROUP BY … ON CONFLICT DO UPDATE count = count + EXCLUDED.count), 표마다 `Delete…ByAccount`, 캐시 `DeleteCachesByBirthHash`(프로필의 `birth_hash`), `MarkAccountDeleted`. 지우는 순서는 FK 자식부터: reactions → daily_selections → rotation_state → diaries → diary_days → schedules → idempotency_keys → account_merge_tickets(`account_id` 또는 `other_account_id`) → refresh_tokens → consents → auth_identities → 캐시 → profiles. 미들웨어가 401을 내는 근거는 지금 `GetAccountAccess`의 status 판정 그대로입니다.

- [ ] **Step 4: 통과 확인** — Run: Step 2 명령 / Expected: PASS

- [ ] **Step 5: Commit** — `git commit -m "feat(server): 계정 삭제를 즉시 실제 삭제로 (S105)"`

### Task 5: 허가 취소 대기와 재시도 (`auth.Revocations`, `job retention`)

**Files:**
- Create: `server/internal/auth/revocations.go`, `revocations_test.go`
- Modify: `server/db/queries/auth.sql`(대기 행 쿼리), `server/internal/auth/disconnect.go`(`DisconnectProviders`·`stillPendingDeletion`·`markDisconnected`·`disconnect` 제거, `RevokeGrant`는 대기 행을 받는 내부 함수로), `server/internal/auth/identities.go`(`UnlinkIdentity`가 같은 트랜잭션에서 대기 행을 넣고 commit 뒤 `Attempt`), `server/internal/cli/cli.go`(`job retention` 실행), `server/internal/cli/serve.go`(조립)
- Test: `revocations_test.go`, `identities_test.go`(떼기), `internal/cli/cli_test.go`

**Interfaces:**
- Consumes: Task 4 `account.Revoker`
- Produces:
  - `type Revocations struct{…}`, `func NewRevocations(pool *pgxpool.Pool, kakao KakaoUnlinker, apple AppleRevoker, box *secretbox.Box, clk clock.Clock, log *slog.Logger) *Revocations`(지금 Service가 쓰는 제공자 인터페이스 이름을 그대로)
  - `func (r *Revocations) Attempt(ctx context.Context, ids []int64)` — `account.Revoker` 만족
  - `func (r *Revocations) RetryDue(ctx context.Context) (attempted int, err error)`
  - `func QueueRevocationTx(ctx context.Context, q *authdb.Queries, identity authdb.<떼는 행 타입>) (id int64, ok bool, err error)` — 떼기에서 씀, kakao·apple이 아니면 ok=false

- [ ] **Step 1: 테스트 작성**

```go
func TestRevocations_SuccessDeletesRow(t *testing.T)
func TestRevocations_FailureSchedulesBackoff(t *testing.T)   // attempts 1→next +1m, 2→+2m, … 11번째부터 +24h 상한
func TestRevocations_AlreadyRevokedCountsAsSuccess(t *testing.T) // Apple invalid_grant, 저장 token 없음, 카카오 미연결 응답 → 행 지움
func TestRevocations_GiveUpAfter30Days(t *testing.T)          // created_at+30d 지난 행은 부르지 않고 지움
func TestRevocations_RetryDueSkipsLocked(t *testing.T)        // RetryDue 둘을 동시에 → 가짜 제공자 호출 횟수 = 행 수
func TestUnlinkIdentity_QueuesAndAttempts(t *testing.T)       // 카카오 실패 → 떼기는 204, 대기 행 1(attempts 1)
func TestJobRetention_RunsRevocationRetry(t *testing.T)       // `server job retention`이 RetryDue를 부르고 exit 0
```

카카오 "이미 끊긴 사용자" 응답은 `provider/kakao.go`의 unlink 오류 응답 형식을 보고 sentinel `provider.ErrKakaoNotLinked`로 구분합니다(카카오 문서의 오류 code를 주석으로 남김).

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/auth/... ./internal/cli/ -run 'Revocation|Unlink|JobRetention' -count=1` / Expected: FAIL

- [ ] **Step 3: 구현** — `RetryDue`는 `SELECT … WHERE next_attempt_at <= now FOR UPDATE SKIP LOCKED LIMIT 100`을 한 트랜잭션씩 처리합니다(호출 동안 행 잠금 유지, 외부 호출 timeout은 지금 제공자 클라이언트 설정). 로그는 `id`·`provider`·결과만.

- [ ] **Step 4: 통과 확인** — Run: Step 2 명령 / Expected: PASS

- [ ] **Step 5: Commit** — `git commit -m "feat(server): 허가 취소 대기와 재시도 (S106)"`

### Task 6: 삭제 대기 경로 제거와 연결 409 정리

**Files:**
- Modify: `server/internal/auth/service.go`(복구 분기·`RestoredFromDeletion`·`statusPendingDeletion` 제거, 삭제된 계정의 인증 계정은 없으므로 새 계정 생성), `server/internal/auth/identities.go`(`issueMergeTicket`·`IdentityInUseError`의 토큰 필드·`ErrIdentityPendingDeletion` 제거, `IdentityInUseError` → sentinel `ErrIdentityInUse`), `server/internal/auth/errors.go`, `server/internal/httpapi/auth.go`(`allowedWhilePendingDeletion` 제거), `server/internal/httpapi/errors.go`, `server/internal/billing/reward.go`(pending 참조), `server/db/queries/auth.sql`·`account.sql`(쓰지 않는 쿼리)
- Test: `internal/auth/service_test.go`, `identities_test.go`, `internal/httpapi/auth_test.go`, `internal/cli/auth_flow_test.go`, `identity_flow_test.go`

- [ ] **Step 1: 테스트 고침**

복구 로그인 테스트를 `TestLogin_AfterDeleteCreatesNewAccount`(삭제 뒤 같은 카카오 subject 로그인 → `isNewAccount: true`, 다른 account id, 약관 동의 필요)로 바꿉니다. `TestLinkIdentity_OtherAccountReturnsInUse`: 409, `account_merge_tickets` 행 0. flow 테스트에서 `restoredFromDeletion`·`pending_deletion` 기대를 지웁니다.

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/auth/... ./internal/httpapi/ ./internal/cli/ -count=1` / Expected: FAIL

- [ ] **Step 3: 구현** — 위 Files의 제거. `grep -rn "pending_deletion\|PendingDeletion\|restoredFromDeletion\|RestoredFromDeletion\|MergeToken" internal db` 결과가 `account_merge_tickets` 관련(PR 4가 씀)과 migration 파일 말고 없어야 합니다.

- [ ] **Step 4: 전체 통과** — Run: `go generate ./... && git status --porcelain && go vet ./... && golangci-lint run ./... && go test -race ./... -count=1` / Expected: 출력 없음·0 issues·PASS

- [ ] **Step 5: Commit** — `git commit -m "refactor(server): 삭제 대기·복구 로그인과 연결 409 토큰 제거 (S105·S110)"`

---

## PR 3: 구매 장부 (`server/d88-purchase-ledger`)

### Task 7: migration 00016과 상품 목록

**Files:**
- Create: `server/db/migrations/00016_purchases.sql`, `server/internal/billing/catalog.go`, `catalog_test.go`
- Modify: `server/internal/platform/postgres/migrate_test.go`, `server/internal/billing/sync.go`(`SyncConfig.AdFreeProductIDs` → `Catalog`), `server/internal/cli/serve.go`
- Test: `server/internal/platform/postgres/schema_purchases_test.go`, `catalog_test.go`

**Interfaces:**
- Produces: `type Product struct { Months int; Entitlements []Entitlement }`, `type Catalog map[string]Product`, `func AdFreeCatalog(productIDs []string) Catalog`(각 `Months: 1`, `[AdFree, Insight]`), `SyncConfig{Catalog Catalog; ProductionOnly bool}`

- [ ] **Step 1: 테스트 작성**

```go
func TestSchema00016_Purchases(t *testing.T) // spec §5.1 열, account_id·original_account_id FK RESTRICT, refunded_at NULL 허용
func TestSchema00016_GrantsUniquePerAccount(t *testing.T) // 같은 (entitlement, source, source_ref)를 다른 account_id로 두 행 → 성공, 같은 account로 두 번 → unique 위반
func TestAdFreeCatalog(t *testing.T) // AdFreeCatalog([]string{"a","b"})["a"] == Product{Months: 1, Entitlements: []Entitlement{AdFree, Insight}}
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/platform/postgres/ ./internal/billing/ -run 'Schema00016|Catalog|TestMigrate' -count=1` / Expected: FAIL

- [ ] **Step 3: 구현** — `00016`: `purchases` 표(인덱스 `(account_id, purchased_at DESC)`), `entitlement_grants_source_unique`를 `(account_id, entitlement, source, source_ref)`로 교체. backfill 없음(spec §3.2 끝, 출시 전). Down은 표 제거와 unique 복원.

- [ ] **Step 4: 통과 확인** — Run: Step 2 명령 / Expected: PASS

- [ ] **Step 5: Commit** — `git commit -m "feat(server): migration 00016 구매 장부와 상품 목록"`

### Task 8: 장부 기록과 사용 구간 (`ledger.go`)

**Files:**
- Create: `server/internal/billing/ledger.go`, `ledger_test.go`
- Modify: `server/db/queries/billing.sql`

**Interfaces:**
- Consumes: Task 7 `Catalog`
- Produces:
  - `func recordPurchaseTx(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID, p Purchase, catalog Catalog, now time.Time) (owner uuid.UUID, created bool, err error)` — 없으면 넣고(주인 = accountID) 기간 상품이면 구간을 놓음. 있으면 주인을 돌려주고 바꾸지 않음. `Purchase`에 `Store string`을 더함.
  - `func markRefundedTx(ctx context.Context, q *billingdb.Queries, purchaseID string, refundedAt time.Time) (changed bool, err error)`
  - `func rechainFromTx(ctx context.Context, q *billingdb.Queries, accountID uuid.UUID, now time.Time) error`

- [ ] **Step 1: 테스트 작성** (DB 테스트, `clock` 고정)

```go
func TestRecordPurchase_FirstWriterOwns(t *testing.T)   // A가 적은 구매를 B가 다시 record → owner A, created false, B 구간 없음
func TestRecordPurchase_ChainsAfterExistingEnd(t *testing.T) // A 구간 10/5~11/5, 10/20 새 구매 → 11/5~12/5
func TestRecordPurchase_UnknownProductHasNoGrant(t *testing.T)
func TestRechainFrom_RefundCutsAndPullsLater(t *testing.T)
// 구간 p1 10/1~11/1(지금 10/10 사용 중), p2 11/1~12/1(대기). p1 환불 → p1 revoked_at=10/10, p2 = 10/10~11/10
func TestRechainFrom_KeepsPastSegments(t *testing.T)     // 9/1~10/1 끝난 구간은 환불돼도 starts/expires 그대로(revoked_at만)
func TestRechainFrom_ActiveKeepsStart(t *testing.T)      // 사용 중 구간은 시작을 바꾸지 않음
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/billing/ -run 'RecordPurchase|RechainFrom' -count=1` / Expected: FAIL

- [ ] **Step 3: 구현 — `rechainFromTx` 규칙**

권한(`ad_free`·`insight`)마다 이 계정의 살아 있는 구간(`revoked_at IS NULL`)을 구매 시각·구매 id 순으로 봅니다.

1. `expires_at <= now`인 구간은 그대로 둡니다(환불이어도 이미 끝난 구간은 바꾸지 않음).
2. 환불된 구매의 남은 구간은 `revoked_at = now`로 끊고 이어 붙이기에서 뺍니다.
3. 사용 중 구간(`starts_at <= now < expires_at`)은 시작·끝을 모두 그대로 둡니다.
4. 대기 구간(`starts_at > now`)은 원래 길이(`expires_at - starts_at`)를 유지한 채 `max(now, 앞 구간 끝)`부터 차례로 다시 붙입니다.

`MovePurchasesTx`(Task 12)는 B 쪽 구간을 `expires_at = now`로 끊고, 끊기 전 남은 길이(`expires_at - max(starts_at, now)`)를 A 쪽 대기 구간으로 넣은 뒤 이 함수를 부릅니다.

- [ ] **Step 4: 통과 확인** — Run: Step 2 명령 / Expected: PASS

- [ ] **Step 5: Commit** — `git commit -m "feat(server): 구매 장부 기록과 사용 구간 다시 잇기 (S107·S108)"`

### Task 9: 동기화·webhook을 장부로

**Files:**
- Modify: `server/internal/billing/sync.go`(`Sync`가 RevenueCat 목록 → `recordPurchaseTx`·`markRefundedTx`·`rechainFromTx`, `reconcile`·`adFreeGrants` 제거), `server/internal/billing/webhook.go`(계정을 못 찾으면 이벤트의 구매 id로 장부 주인을 찾아 동기화), `server/internal/billing/revenuecat.go`(`store` 필드 파싱), `server/db/queries/billing.sql`
- Test: `sync_test.go`, `webhook_test.go`, `chain_test.go`(장부 기준으로 고침), `internal/cli/billing_flow_test.go`

**Interfaces:**
- Consumes: Task 8
- Produces: `func (s *Syncer) Sync(ctx context.Context, accountID uuid.UUID) error`(signature 그대로), `func lockBillingAccounts(ctx context.Context, tx pgx.Tx, ids ...uuid.UUID) error`(uuid 정렬 후 advisory lock)

- [ ] **Step 1: 테스트 작성**

```go
func TestSync_TransferDoesNotMoveOwner(t *testing.T)   // A가 산 구매가 B의 RevenueCat 목록에 나타남 → B Sync 뒤 owner A, B 권한 없음 (S83 테스트를 뒤집음)
func TestSync_MissingFromListKeepsGrant(t *testing.T)  // A 목록에서 빠져도 A 구간 그대로
func TestSync_RefundSeenByNonOwner(t *testing.T)       // B 목록에서 환불로 보임 → A 구간 끊기고 뒤 구간 앞당김 (Review Focus 3)
func TestSync_ConcurrentCrossAccountNoDeadlock(t *testing.T) // A Sync와 B Sync(서로의 구매 환불)를 동시에 → 둘 다 끝남(deadline 10s)
func TestWebhook_FirstSeenByWebhookOwnsOnce(t *testing.T) // 결제 직후 Sync 실패(가짜 RevenueCat 503) 뒤 webhook → 후보 계정 owner, 같은 이벤트 재전송에도 구간 1개 (Review Focus 2)
func TestWebhook_UnknownCandidateFallsBackToLedgerOwner(t *testing.T)
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/billing/ ./internal/cli/ -run 'Sync|Webhook|Billing' -count=1` / Expected: FAIL

- [ ] **Step 3: 구현** — 다른 주인 계정을 고쳐야 할 때는 그 계정 id까지 모아 `lockBillingAccounts`로 한 번에 잡고 다시 시작합니다(이미 잡은 lock 뒤에 작은 uuid lock을 더 잡지 않음). production 필터는 지금 `ProductionOnly` 그대로 장부 기록 단계에서 적용합니다.

- [ ] **Step 4: 통과 확인** — Run: Step 2 명령 / Expected: PASS

- [ ] **Step 5: Commit** — `git commit -m "feat(server): 결제 동기화를 구매 장부 기준으로 (S83 개정)"`

### Task 10: 구매 목록 API와 `restorePurchases`

**Files:**
- Create: `server/internal/billing/purchases.go`, `purchases_test.go`
- Modify: `server/internal/httpapi/billing_handlers.go`(`ListPurchases`), `unimplemented.go`(stub 제거), `server/CLAUDE.md`(현재 상태)
- Test: `billing_handlers_test.go`, `internal/cli/billing_flow_test.go`

**Interfaces:**
- Produces: `type PurchaseItem struct { ProductID string; PurchasedAt time.Time; Status string; Period *Period }`, `type Period struct { StartsAt, EndsAt time.Time }`, `func (s *Store) Purchases(ctx context.Context, accountID uuid.UUID) ([]PurchaseItem, error)`

- [ ] **Step 1: 테스트 작성**

```go
func TestPurchases_StatusesAndPeriods(t *testing.T)
// 지금 10/20: 끝난 구간 → expired, 사용 중 → active, 대기 → pending, 환불 → refunded(period는 이 계정 구간), 목록 밖 상품 → owned·period nil
// 최근 구매 먼저
func TestPurchases_OnlyThisAccountSegment(t *testing.T) // B 구간과 A 구간이 있는 구매 → A 조회는 A 구간만
func TestListPurchases_Handler(t *testing.T)            // 200 {items}, 미인증 401
```

flow 테스트: 가짜 RevenueCat에 구매 둘 → `restorePurchases` → `listPurchases` 두 줄.

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/billing/ ./internal/httpapi/ ./internal/cli/ -run 'Purchases|ListPurchases|Billing' -count=1` / Expected: FAIL

- [ ] **Step 3: 구현** — 상태는 `refunded_at` → `refunded`, 구간 없음 → `owned`, `now < starts_at` → `pending`, `now >= expires_at` 또는 `revoked_at` → `expired`, 그 밖 `active`. 한 구매의 여러 권한 행은 같은 구간이므로 `ad_free` 행 하나로 period를 만듭니다.

- [ ] **Step 4: 전체 통과** — Run: `go generate ./... && git status --porcelain && go vet ./... && golangci-lint run ./... && go test -race ./... -count=1` / Expected: 출력 없음·0 issues·PASS

- [ ] **Step 5: Commit** — `git commit -m "feat(server): 구매 목록 API (S109)"`

---

## PR 4: 합치기 (`server/d85-merge`)

### Task 11: `previewMerge` (증명 검증, 토큰, 요약)

**Files:**
- Create: `server/internal/merge/merge.go`(`Service`·`Preview`), `merge_test.go`, `server/db/queries/merge.sql`, `server/internal/merge/mergedb/`(sqlc), `server/internal/httpapi/merge_handlers.go`, `merge_handlers_test.go`
- Modify: `server/sqlc.yaml`(mergedb), `server/internal/auth/identities.go`(`VerifyProof`), `server/internal/httpapi/unimplemented.go`(`PreviewMerge` stub 제거), `server/internal/cli/serve.go`

**Interfaces:**
- Consumes: `auth.LinkProof`
- Produces:
  - `func (s *auth.Service) VerifyProof(ctx context.Context, providerName string, proof LinkProof) (identityID, accountID uuid.UUID, found bool, err error)` — 검증 오류는 연결과 같은 sentinel. Apple은 id_token만 쓰고 code 교환 grant는 저장하지 않으며, 교환했으면 그 grant를 `revokeUnsavedAppleGrant` 하지 않습니다(B 삭제가 취소함).
  - `var ErrSameAccount`, `ErrNoAccount`, `ErrTokenInvalid`(merge 패키지)
  - `type Summary struct { Diaries, Schedules, DateRecords, Reactions, OverlapDays int; AddedDays map[billing.Entitlement]int; Current, Other ProfileSummary }`
  - `func (s *Service) Preview(ctx context.Context, accountID uuid.UUID, providerName string, proof auth.LinkProof) (token string, expiresAt time.Time, summary Summary, err error)`
  - `MergeTicketTTL = 10 * time.Minute`은 merge 패키지로 옮깁니다

- [ ] **Step 1: 테스트 작성**

```go
func TestPreview_SameAccount(t *testing.T)   // A의 카카오로 증명 → ErrSameAccount, 422 merge.same_account
func TestPreview_NoAccount(t *testing.T)     // 연결 없는 subject → ErrNoAccount, 422, auth_identities 행 생기지 않음
func TestPreview_OtherAccount(t *testing.T)  // B: 일기 3(지운 것 1), 일정 2, 날짜 기록 2(A와 겹침 1), 반응 1, 광고 제거 12일 남음
// → Summary{Diaries:3, Schedules:2, DateRecords:2, Reactions:1, OverlapDays:1, AddedDays[AdFree]=12}, 토큰 43자, ticket 행 해시만, expiresAt=now+10m
func TestPreview_EmptyOtherStillSummarizes(t *testing.T) // 기록 0건 → 200, 모두 0
func TestPreviewMerge_Handler(t *testing.T)  // 200 모양, 422 두 code, 증명 오류 401
```

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/merge/ ./internal/auth/ ./internal/httpapi/ -run 'Preview|VerifyProof' -count=1` / Expected: FAIL

- [ ] **Step 3: 구현** — 남은 날은 B의 `expires_at > now` 구간 길이 합을 일 단위 올림. 프로필 요약은 지금 `profile` 패키지의 `Birth` 변환을 씁니다.

- [ ] **Step 4: 통과 확인** — Run: Step 2 명령 / Expected: PASS

- [ ] **Step 5: Commit** — `git commit -m "feat(server): 합치기 요약 previewMerge (S110)"`

### Task 12: `mergeAccounts` 실행과 마무리

**Files:**
- Modify: `server/internal/merge/merge.go`(`Execute`), `merge_test.go`, `server/db/queries/merge.sql`, `server/internal/billing/ledger.go`(`MovePurchasesTx`), `server/internal/httpapi/merge_handlers.go`, `unimplemented.go`(stub 제거), `server/internal/cli/serve.go`(`Idempotency(..., "mergeAccounts")`), `server/CLAUDE.md`
- Create: `server/internal/cli/merge_flow_test.go`

**Interfaces:**
- Consumes: Task 4 `account.DeleteAccountTx`·`account.Revoker`, Task 8 `rechainFromTx`, Task 11
- Produces:
  - `func MovePurchasesTx(ctx context.Context, tx pgx.Tx, from, to uuid.UUID, now time.Time) error` — `from` 구간을 now에서 끊고 남은 길이로 `to` 구간을 `to` 끝에 붙임, `purchases.account_id = to`, `merged_at = now`
  - `type Profile string` (`ProfileCurrent = "current"`, `ProfileOther = "other"`)
  - `func (s *Service) Execute(ctx context.Context, accountID uuid.UUID, token string, profile Profile) error`

- [ ] **Step 1: 테스트 작성**

```go
func TestExecute_MovesRecordsAndDeletesB(t *testing.T)
// B 일기(지운 것 포함)·일정·날짜 기록·반응이 A로, B accounts deleted, B 인증 계정 0, 카카오 B → revocation 1
func TestExecute_OverlapKeepsChosenProfileSide(t *testing.T)
// 같은 날짜 기록: profile=other → B의 날짜 기록(태그·질문)이 남고 A 일기도 그 아래. 같은 (date,slot,birth_hash) 선택: B 쪽 남고 A 쪽 반응은 tally로
func TestExecute_ProfileOtherReplacesProfile(t *testing.T)
func TestExecute_PurchasesAppendRemaining(t *testing.T)
// 10/20 A 11/5 만료, B 11/1 만료 → A 끝 11/17, B 구간 revoked 10/20... (B 쪽 행은 expires_at=10/20로 끊김), purchases.account_id=A, original=B, merged_at=10/20
func TestExecute_TokenInvalidCases(t *testing.T)
// 재사용, 만료, 다른 bearer, B가 삭제됨, 그 인증 계정이 B에서 떼짐 → ErrTokenInvalid, A 변화 없음 (Review Focus 4)
func TestExecute_MutualMergeOnlyOneWins(t *testing.T) // A→B와 B→A를 동시에 → 하나 성공, 하나 ErrTokenInvalid
func TestExecute_DiaryCapIgnored(t *testing.T)        // 같은 날 A 6편 + B 6편 → 12편
```

`merge_flow_test.go`: 두 계정 로그인 → A가 B의 카카오로 `previewMerge` → `mergeAccounts`(Idempotency-Key k1) 200 `Me` → 같은 k1로 다시 200 같은 본문 → 다른 키로 다시 422 `merge.token_invalid`(Review Focus 5) → B의 refresh token은 401 → `listPurchases`에 B 구매가 A 구간으로.

- [ ] **Step 2: 실패 확인** — Run: `go test ./internal/merge/ ./internal/billing/ ./internal/cli/ -run 'Execute|MovePurchases|Merge' -count=1` / Expected: FAIL

- [ ] **Step 3: 구현** — spec §6.3 순서(잠금 → 토큰 소진 → 기록 → 프로필 → 구매 → `DeleteAccountTx(B)`). 날짜 기록 겹침은 `diaries_day_fk (account_id, date)` 때문에 "남길 날짜 기록 정하기(고른 쪽이 B면 A 행을 B 값으로 UPDATE) → B에만 있는 날짜 INSERT … SELECT → B 일기 `account_id` 변경 → B 날짜 기록은 `DeleteAccountTx`가 지움" 순서입니다. commit 뒤 `revoker.Attempt`.

- [ ] **Step 4: 전체 통과** — Run: `go generate ./... && git status --porcelain && go vet ./... && golangci-lint run ./... && go test -race ./... -count=1` / Expected: 출력 없음·0 issues·PASS

- [ ] **Step 5: Commit, CLAUDE.md** — 현재 상태에 D85·D88 한 줄, 다음 할 일에서 이 항목 제거. `git commit -m "feat(server): 계정 합치기 mergeAccounts (S111)"`. PR 본문 `Closes #481`, `Closes #492`(writing drift가 풀린 뒤 처음 병합하는 server PR이면 `Closes #478`도).
