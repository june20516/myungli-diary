package ops

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

var (
	testNow   = time.Date(2026, 11, 26, 3, 0, 0, 0, time.UTC)
	testActor = Actor{ID: "bran", Channel: ChannelCLI}
)

// newServiceAt은 지금 시각을 at으로 고정한 Service를 만듭니다. 감사 행의 at은 trigger가 DB now()로 정하므로 고정되지 않습니다.
func newServiceAt(pool *pgxpool.Pool, at time.Time) *Service {
	svc := NewService(pool)
	svc.now = func(context.Context, pgx.Tx) (time.Time, error) { return at, nil }
	return svc
}

// sessionUser는 테스트 연결의 session_user입니다. CLI 감사 행의 actor는 trigger가 이 값으로 정합니다.
func sessionUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	var user string
	require.NoError(t, pool.QueryRow(context.Background(), "SELECT session_user").Scan(&user))
	return user
}

func newTestService(t *testing.T) (*Service, *pgxpool.Pool) {
	t.Helper()
	pool := dbtest.New(t)
	return newServiceAt(pool, testNow), pool
}

func insertAccount(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, pool.QueryRow(context.Background(), `INSERT INTO accounts (id, status, last_active_at, created_at)
		VALUES (gen_random_uuid(), 'active', $1, $2) RETURNING id`, testNow.Add(-time.Hour), testNow.Add(-72*time.Hour)).Scan(&id))
	return id
}

func insertPurchase(t *testing.T, pool *pgxpool.Pool, accountID, originalID uuid.UUID, id, storePurchaseID string) {
	t.Helper()
	_, err := pool.Exec(context.Background(), `INSERT INTO purchases (id, account_id, original_account_id, product_id, store, store_purchase_id, purchased_at, production)
		VALUES ($1, $2, $3, 'ad_free_monthly', 'app_store', $4, $5, false)`, id, accountID, originalID, storePurchaseID, testNow.Add(-24*time.Hour))
	require.NoError(t, err)
}

type auditRow struct {
	Actor, Channel, Action, Reason, Target string
	AccountID                              *uuid.UUID
}

func auditRows(t *testing.T, pool *pgxpool.Pool) []auditRow {
	t.Helper()
	rows, err := pool.Query(context.Background(), `SELECT actor, channel, action, reason, target::text, account_id FROM ops_audit ORDER BY at, id`)
	require.NoError(t, err)
	got, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (auditRow, error) {
		var r auditRow
		err := row.Scan(&r.Actor, &r.Channel, &r.Action, &r.Reason, &r.Target, &r.AccountID)
		return r, err
	})
	require.NoError(t, err)
	return got
}

func TestAccountSummary_ShowsSupportFields(t *testing.T) {
	svc, pool := newTestService(t)
	ctx := context.Background()
	id := insertAccount(t, pool)
	other := insertAccount(t, pool)

	_, err := pool.Exec(ctx, `INSERT INTO auth_identities (id, account_id, provider, subject, created_at)
		VALUES (gen_random_uuid(), $1, 'kakao', 'secret-subject', $2)`, id, testNow.Add(-70*time.Hour))
	require.NoError(t, err)
	for i, platform := range []string{"ios", "android"} {
		_, err = pool.Exec(ctx, `INSERT INTO devices (id, account_id, fcm_token, token_hash, platform, active, last_seen_at, created_at)
			VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7)`,
			id, "secret-token-"+platform, []byte{byte(i + 1)}, platform, i == 0, testNow.Add(-time.Duration(i+1)*time.Hour), testNow.Add(-time.Duration(60-i)*time.Hour))
		require.NoError(t, err)
	}
	_, err = pool.Exec(ctx, `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'ad_free', 'operator', 'grp-1', $2, $3), ($1, 'insight', 'operator', 'grp-1', $2, $3)`,
		id, testNow.Add(-time.Hour), testNow.Add(24*time.Hour))
	require.NoError(t, err)
	insertPurchase(t, pool, id, id, "p-own", "tx-own")
	insertPurchase(t, pool, id, other, "p-merged", "tx-merged")

	got, err := svc.AccountSummary(ctx, testActor, AccountKey{AccountID: id}, "문의 확인")
	require.NoError(t, err)

	assert.Equal(t, id, got.Account.ID)
	assert.Equal(t, "active", got.Account.Status)
	assert.True(t, testNow.Add(-72*time.Hour).Equal(got.Account.CreatedAt))
	assert.True(t, testNow.Add(-time.Hour).Equal(got.Account.LastActiveAt))
	assert.Nil(t, got.Account.DeletedAt)

	require.Len(t, got.Identities, 1)
	assert.Equal(t, "kakao", got.Identities[0].Provider)
	assert.True(t, testNow.Add(-70*time.Hour).Equal(got.Identities[0].LinkedAt))

	require.Len(t, got.Devices, 2)
	assert.Equal(t, "ios", got.Devices[0].Platform)
	assert.True(t, got.Devices[0].Active)
	assert.Equal(t, "android", got.Devices[1].Platform)
	assert.False(t, got.Devices[1].Active)

	assert.True(t, got.Status.AdFree.Active)
	assert.True(t, got.Status.Insight.Active)
	assert.Equal(t, billing.SourceOperator, got.Status.AdFree.Source)
	assert.Len(t, got.Grants, 2)

	require.Len(t, got.Purchases, 2)
	byProduct := map[string]PurchaseInfo{}
	for _, p := range got.Purchases {
		byProduct[*p.StorePurchaseID] = p
	}
	assert.Nil(t, byProduct["tx-own"].MergedFrom)
	require.NotNil(t, byProduct["tx-merged"].MergedFrom)
	assert.Equal(t, other, *byProduct["tx-merged"].MergedFrom)
	assert.False(t, byProduct["tx-own"].Production)
	assert.Equal(t, "app_store", byProduct["tx-own"].Store)

	// 제공자 subject와 알림 token은 결과 어디에도 나오지 않습니다.
	dump := fmt.Sprintf("%+v", got)
	assert.NotContains(t, dump, "secret-subject")
	assert.NotContains(t, dump, "secret-token")
}

func TestAccountSummary_WritesAuditBeforeReturning(t *testing.T) {
	svc, pool := newTestService(t)
	id := insertAccount(t, pool)

	_, err := svc.AccountSummary(context.Background(), Actor{ID: "bran", Channel: ChannelAdminAPI}, AccountKey{AccountID: id}, " 환불 문의 ")
	require.NoError(t, err)

	rows := auditRows(t, pool)
	require.Len(t, rows, 1)
	assert.Equal(t, "account_show", rows[0].Action)
	assert.Equal(t, "bran", rows[0].Actor)
	assert.Equal(t, "admin_api", rows[0].Channel)
	assert.Equal(t, "환불 문의", rows[0].Reason)
	require.NotNil(t, rows[0].AccountID)
	assert.Equal(t, id, *rows[0].AccountID)
	assert.JSONEq(t, fmt.Sprintf(`{"accountId":%q}`, id), rows[0].Target)
}

func TestAccountSummary_NotFoundStillAudited(t *testing.T) {
	svc, pool := newTestService(t)
	missing := uuid.New()

	got, err := svc.AccountSummary(context.Background(), testActor, AccountKey{AccountID: missing}, "문의")
	require.ErrorIs(t, err, ErrAccountNotFound)
	assert.Equal(t, AccountSummary{}, got)

	rows := auditRows(t, pool)
	require.Len(t, rows, 1)
	assert.Equal(t, "account_show", rows[0].Action)
	assert.Nil(t, rows[0].AccountID)
	assert.JSONEq(t, fmt.Sprintf(`{"accountId":%q}`, missing), rows[0].Target)
}

func TestAccountSummary_ByStoreTransaction(t *testing.T) {
	svc, pool := newTestService(t)
	id := insertAccount(t, pool)
	insertPurchase(t, pool, id, id, "p1", "tx-1")

	got, err := svc.AccountSummary(context.Background(), testActor, AccountKey{StoreTransaction: "tx-1"}, "영수증 문의")
	require.NoError(t, err)
	assert.Equal(t, id, got.Account.ID)

	rows := auditRows(t, pool)
	require.Len(t, rows, 1)
	require.NotNil(t, rows[0].AccountID)
	assert.Equal(t, id, *rows[0].AccountID)
	assert.JSONEq(t, `{"storeTransaction":"tx-1"}`, rows[0].Target)
}

func TestAccountSummary_StoreTransactionNotFound(t *testing.T) {
	svc, pool := newTestService(t)

	_, err := svc.AccountSummary(context.Background(), testActor, AccountKey{StoreTransaction: "nope"}, "문의")
	require.ErrorIs(t, err, ErrAccountNotFound)
	rows := auditRows(t, pool)
	require.Len(t, rows, 1)
	assert.Nil(t, rows[0].AccountID)
}

func TestAccountSummary_StoreTransactionAmbiguous(t *testing.T) {
	svc, pool := newTestService(t)
	a, b := insertAccount(t, pool), insertAccount(t, pool)
	insertPurchase(t, pool, a, a, "p1", "tx-dup")
	insertPurchase(t, pool, b, b, "p2", "tx-dup")

	got, err := svc.AccountSummary(context.Background(), testActor, AccountKey{StoreTransaction: "tx-dup"}, "문의")
	var ambiguous AmbiguousTransactionError
	require.True(t, errors.As(err, &ambiguous))
	assert.ElementsMatch(t, []uuid.UUID{a, b}, ambiguous.AccountIDs)
	assert.Equal(t, AccountSummary{}, got)

	rows := auditRows(t, pool)
	require.Len(t, rows, 1)
	assert.Nil(t, rows[0].AccountID)
	assert.JSONEq(t, fmt.Sprintf(`{"storeTransaction":"tx-dup","candidates":[%q,%q]}`, min(a.String(), b.String()), max(a.String(), b.String())), rows[0].Target)
}

func TestAccountSummary_ValidatesInputBeforeDB(t *testing.T) {
	svc, pool := newTestService(t)
	ctx := context.Background()
	id := insertAccount(t, pool)

	_, err := svc.AccountSummary(ctx, testActor, AccountKey{AccountID: id}, "")
	assert.ErrorIs(t, err, ErrReason)
	_, err = svc.AccountSummary(ctx, Actor{}, AccountKey{AccountID: id}, "문의")
	assert.ErrorIs(t, err, ErrActor)
	_, err = svc.AccountSummary(ctx, testActor, AccountKey{}, "문의")
	assert.ErrorIs(t, err, ErrAccountKey)
	_, err = svc.AccountSummary(ctx, testActor, AccountKey{AccountID: id, StoreTransaction: "tx"}, "문의")
	assert.ErrorIs(t, err, ErrAccountKey)
	assert.Empty(t, auditRows(t, pool))
}

// TestAccountSummary_AuditFailureReturnsNothing은 감사 행을 쓸 수 없으면 조회 결과를 돌려주지 않음을 확인합니다.
func TestAccountSummary_AuditFailureReturnsNothing(t *testing.T) {
	dbtest.LockCluster(t)
	_, pool := newTestService(t)
	ctx := context.Background()
	id := insertAccount(t, pool)

	svc := newNoAuditService(t, pool)
	got, err := svc.AccountSummary(ctx, testActor, AccountKey{AccountID: id}, "문의")
	require.Error(t, err)
	var pgErr *pgconn.PgError
	require.ErrorAs(t, err, &pgErr)
	assert.Equal(t, "42501", pgErr.Code)
	assert.Contains(t, pgErr.Message, "ops_audit", "감사 INSERT 권한 때문에 실패해야 합니다")
	assert.Equal(t, AccountSummary{}, got)
	assert.Empty(t, auditRows(t, pool))
}

// newNoAuditService는 ops_audit INSERT 권한만 없는 역할로 연결한 Service를 만듭니다.
// 읽기 권한은 모두 있고 쓰기 권한은 어떤 표에도 없습니다. 역할은 테스트가 끝나면 지웁니다.
func newNoAuditService(t *testing.T, pool *pgxpool.Pool) *Service {
	t.Helper()
	ctx := context.Background()
	role := "ops_noaudit_" + strings.ReplaceAll(uuid.NewString(), "-", "")[:12]
	for _, stmt := range []string{
		"CREATE ROLE " + role + " NOLOGIN",
		"GRANT USAGE ON SCHEMA public TO " + role,
		"GRANT SELECT ON ALL TABLES IN SCHEMA public TO " + role,
		"GRANT INSERT ON entitlement_grants TO " + role,
		"GRANT UPDATE (updated_at) ON accounts TO " + role, // 계정 행 FOR SHARE에 필요하며 myungli_ops와 같습니다.
		"GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO " + role,
	} {
		_, err := pool.Exec(ctx, stmt)
		require.NoError(t, err, stmt)
	}
	t.Cleanup(func() {
		for _, stmt := range []string{"DROP OWNED BY " + role, "DROP ROLE IF EXISTS " + role} {
			if _, err := pool.Exec(context.Background(), stmt); err != nil {
				t.Errorf("%s: %v", stmt, err)
			}
		}
	})

	cfg := pool.Config().Copy()
	cfg.AfterConnect = func(ctx context.Context, conn *pgx.Conn) error {
		_, err := conn.Exec(ctx, "SET ROLE "+role)
		return err
	}
	restricted, err := pgxpool.NewWithConfig(ctx, cfg)
	require.NoError(t, err)
	t.Cleanup(restricted.Close)
	return newServiceAt(restricted, testNow)
}
