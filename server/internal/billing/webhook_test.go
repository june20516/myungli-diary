package billing_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

// webhookBody는 RevenueCat webhook 본문 모양입니다. JSON 디코드 결과처럼 배열은 []any입니다.
func webhookBody(eventID, eventType string, fields map[string]any) map[string]any {
	event := map[string]any{"id": eventID, "type": eventType}
	for k, v := range fields {
		event[k] = v
	}
	return map[string]any{"api_version": "1.0", "event": event}
}

func TestParseWebhook_EventIDMissingOrNotString_Invalid(t *testing.T) {
	tests := []struct {
		name string
		body map[string]any
	}{
		{"event 없음", map[string]any{"api_version": "1.0"}},
		{"event가 객체 아님", map[string]any{"event": "x"}},
		{"id 없음", map[string]any{"event": map[string]any{"type": "INITIAL_PURCHASE"}}},
		{"id가 문자열 아님", map[string]any{"event": map[string]any{"id": 12.0, "type": "INITIAL_PURCHASE"}}},
		{"id가 빈 문자열", map[string]any{"event": map[string]any{"id": "", "type": "INITIAL_PURCHASE"}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := billing.ParseWebhook(tt.body)
			assert.ErrorIs(t, err, billing.ErrWebhookInvalid)
		})
	}
}

func TestParseWebhook_CollectsUUIDCandidatesDeduplicated(t *testing.T) {
	a, b, c, d := uuid.New(), uuid.New(), uuid.New(), uuid.New()
	body := webhookBody("evt-1", "TRANSFER", map[string]any{
		"app_user_id":          a.String(),
		"original_app_user_id": "$RCAnonymousID:abc123",
		"aliases":              []any{"$RCAnonymousID:abc123", a.String(), b.String(), 7.0},
		"transferred_from":     []any{c.String()},
		"transferred_to":       []any{d.String(), b.String()},
	})

	got, err := billing.ParseWebhook(body)

	require.NoError(t, err)
	assert.Equal(t, "evt-1", got.ID)
	assert.Equal(t, "TRANSFER", got.Type)
	assert.Equal(t, []uuid.UUID{a, b, c, d}, got.AccountIDs)
}

func TestParseWebhook_NonCanonicalUUIDIgnored(t *testing.T) {
	a := uuid.New()
	body := webhookBody("evt-1", "RENEWAL", map[string]any{
		// 대문자·중괄호 표기는 서버가 RevenueCat에 쓰는 고객 id(소문자 표준 표기)와 다른 고객이라 버립니다.
		"app_user_id": "{" + a.String() + "}",
		"aliases":     []any{"urn:uuid:" + a.String(), "A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11"},
	})

	got, err := billing.ParseWebhook(body)

	require.NoError(t, err)
	assert.Empty(t, got.AccountIDs)
}

func TestParseWebhook_CollectsStorePurchaseIDs(t *testing.T) {
	body := webhookBody("evt-1", "CANCELLATION", map[string]any{
		"transaction_id":          "2000000002",
		"original_transaction_id": "2000000001",
	})

	got, err := billing.ParseWebhook(body)

	require.NoError(t, err)
	assert.Equal(t, []string{"2000000002", "2000000001"}, got.StorePurchaseIDs)
}

func TestParseWebhook_StorePurchaseIDsDeduplicatedAndNonEmpty(t *testing.T) {
	body := webhookBody("evt-1", "NON_RENEWING_PURCHASE", map[string]any{
		"transaction_id":          "GPA.1",
		"original_transaction_id": "GPA.1",
	})
	got, err := billing.ParseWebhook(body)
	require.NoError(t, err)
	assert.Equal(t, []string{"GPA.1"}, got.StorePurchaseIDs)

	got, err = billing.ParseWebhook(webhookBody("evt-2", "RENEWAL", map[string]any{"transaction_id": "", "original_transaction_id": 7.0}))
	require.NoError(t, err)
	assert.Empty(t, got.StorePurchaseIDs)
}

func TestParseWebhook_TypeMissing_Empty(t *testing.T) {
	got, err := billing.ParseWebhook(map[string]any{"event": map[string]any{"id": "evt-1"}})

	require.NoError(t, err)
	assert.Empty(t, got.Type)
}

type webhookFixture struct {
	syncFixture
	logs     *bytes.Buffer
	webhooks *billing.Webhooks
}

func newWebhookFixture(t *testing.T) webhookFixture {
	t.Helper()
	f := newSyncFixture(t)
	logs := &bytes.Buffer{}
	logger := logging.New(logs, slog.LevelDebug, "")
	return webhookFixture{
		syncFixture: f,
		logs:        logs,
		webhooks:    billing.NewWebhooks(f.pool, f.syncer, "Bearer test-secret", f.clk, logger),
	}
}

// storedEvent는 billing_events 한 행입니다.
type storedEvent struct {
	AccountID   uuid.NullUUID
	Payload     []byte
	ReceivedAt  time.Time
	ProcessedAt *time.Time
}

func eventRows(t *testing.T, pool *pgxpool.Pool, eventID string) []storedEvent {
	t.Helper()
	rows, err := pool.Query(context.Background(),
		`SELECT account_id, payload, received_at, processed_at FROM billing_events WHERE event_id = $1`, eventID)
	require.NoError(t, err)
	defer rows.Close()
	var out []storedEvent
	for rows.Next() {
		var e storedEvent
		require.NoError(t, rows.Scan(&e.AccountID, &e.Payload, &e.ReceivedAt, &e.ProcessedAt))
		out = append(out, e)
	}
	require.NoError(t, rows.Err())
	return out
}

func TestWebhooks_Handle_FirstEvent_StoresAndSyncs(t *testing.T) {
	f := newWebhookFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1))
	body := webhookBody("evt-1", "INITIAL_PURCHASE", map[string]any{"app_user_id": accountID.String()})

	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	rows := eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	assert.Equal(t, uuid.NullUUID{UUID: accountID, Valid: true}, rows[0].AccountID)
	assert.True(t, rows[0].ReceivedAt.Equal(now))
	require.NotNil(t, rows[0].ProcessedAt)
	assert.True(t, rows[0].ProcessedAt.Equal(now))
	var payload map[string]any
	require.NoError(t, json.Unmarshal(rows[0].Payload, &payload))
	assert.Equal(t, body, payload)

	assert.EqualValues(t, 1, f.source.calls.Load())
	assertPeriod(t, allGrants(t, f.pool), "p1", oct1, nov1, nil)
}

func TestWebhooks_Handle_SameEventAgain_DoesNotSync(t *testing.T) {
	f := newWebhookFixture(t)
	accountID := newAccount(t, f.pool)
	body := webhookBody("evt-1", "RENEWAL", map[string]any{"app_user_id": accountID.String()})
	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	f.clk.Advance(time.Minute)
	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	assert.EqualValues(t, 1, f.source.calls.Load())
	rows := eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	require.NotNil(t, rows[0].ProcessedAt)
	assert.True(t, rows[0].ProcessedAt.Equal(now), "처음 처리 시각을 유지합니다")
}

func TestWebhooks_Handle_SyncFails_NotProcessedThenRetried(t *testing.T) {
	f := newWebhookFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1))
	body := webhookBody("evt-1", "INITIAL_PURCHASE", map[string]any{"app_user_id": accountID.String()})
	f.source.failWith(billing.ErrProviderUnavailable)

	err := f.webhooks.Handle(context.Background(), body)

	require.ErrorIs(t, err, billing.ErrProviderUnavailable)
	rows := eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	assert.Nil(t, rows[0].ProcessedAt)
	assert.Empty(t, allGrants(t, f.pool))

	f.source.failWith(nil)
	f.clk.Advance(time.Minute)
	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	rows = eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	require.NotNil(t, rows[0].ProcessedAt)
	assert.True(t, rows[0].ProcessedAt.Equal(now.Add(time.Minute)))
	assertPeriod(t, allGrants(t, f.pool), "p1", oct1, nov1, nil)
}

func TestWebhooks_Handle_ConcurrentSameEvent_OneRow(t *testing.T) {
	f := newWebhookFixture(t)
	accountID := newAccount(t, f.pool)
	f.source.set(accountID, owned("p1", oct1))
	body := webhookBody("evt-1", "INITIAL_PURCHASE", map[string]any{"app_user_id": accountID.String()})

	var wg sync.WaitGroup
	errs := make([]error, 2)
	for i := range errs {
		wg.Add(1)
		go func() {
			defer wg.Done()
			errs[i] = f.webhooks.Handle(context.Background(), body)
		}()
	}
	wg.Wait()

	for _, err := range errs {
		require.NoError(t, err)
	}
	var eventCount int
	require.NoError(t, f.pool.QueryRow(context.Background(), "SELECT count(*) FROM billing_events").Scan(&eventCount))
	assert.Equal(t, 1, eventCount, "같은 event.id는 billing_events 행 하나입니다")
	rows := eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	assert.NotNil(t, rows[0].ProcessedAt)
	grants := allGrants(t, f.pool)
	require.Len(t, grants, 2, "구매 하나는 ad_free·insight 두 행입니다")
	assertPeriod(t, grants, "p1", oct1, nov1, nil)
}

func TestWebhooks_Handle_UnknownAccount_RecordsOnlyAndWarns(t *testing.T) {
	f := newWebhookFixture(t)
	unknown := uuid.New()
	body := webhookBody("evt-1", "INITIAL_PURCHASE", map[string]any{
		"app_user_id":          unknown.String(),
		"original_app_user_id": "$RCAnonymousID:abc123",
	})

	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	rows := eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	assert.False(t, rows[0].AccountID.Valid)
	assert.NotNil(t, rows[0].ProcessedAt)
	assert.Zero(t, f.source.calls.Load())
	assert.Contains(t, f.logs.String(), `"severity":"WARNING"`)
	assert.Contains(t, f.logs.String(), "evt-1")
}

func TestWebhooks_Handle_TestEvent_NoSync(t *testing.T) {
	f := newWebhookFixture(t)
	accountID := newAccount(t, f.pool)
	body := webhookBody("evt-test", "TEST", map[string]any{"app_user_id": accountID.String()})

	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	assert.Zero(t, f.source.calls.Load())
	rows := eventRows(t, f.pool, "evt-test")
	require.Len(t, rows, 1)
	assert.NotNil(t, rows[0].ProcessedAt)
}

// TRANSFER는 양쪽 계정을 모두 동기화하지만 주인은 옮기지 않습니다(S107). 옮겨 준 계정의 구간도 그대로입니다.
func TestWebhooks_Handle_Transfer_SyncsBothAccountsOwnerStays(t *testing.T) {
	f := newWebhookFixture(t)
	from, to := newAccount(t, f.pool), newAccount(t, f.pool)
	f.source.set(from, owned("p1", oct1))
	require.NoError(t, f.syncer.Sync(context.Background(), from))
	f.source.set(from)
	f.source.set(to, owned("p1", oct1))
	body := webhookBody("evt-1", "TRANSFER", map[string]any{
		"transferred_from": []any{from.String()},
		"transferred_to":   []any{to.String()},
	})

	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	assert.EqualValues(t, 3, f.source.calls.Load(), "앞선 동기화 1번 + 양쪽 계정 2번")
	assert.Equal(t, from, ledgerOf(t, f.pool, "p1").Owner)
	grants := allGrants(t, f.pool)
	require.Len(t, grants, 2)
	assert.Equal(t, from, findGrant(t, grants, billing.AdFree, "p1").AccountID)
	assertPeriod(t, grants, "p1", oct1, nov1, nil)
	rows := eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	assert.Equal(t, uuid.NullUUID{UUID: from, Valid: true}, rows[0].AccountID, "account_id는 찾은 첫 계정입니다")
}

// 결제 직후 동기화가 RevenueCat 장애(503)로 실패하면 장부는 비어 있고, 뒤에 온 webhook의 후보 계정이 주인이 됩니다(spec §5.2).
// 같은 이벤트 재전송과 같은 구매의 다른 이벤트도 구간을 하나만 둡니다.
func TestWebhook_FirstSeenByWebhookOwnsOnce(t *testing.T) {
	pool := dbtest.New(t)
	clk := clocktest.New(now)
	accountID := newAccount(t, pool)
	var unavailable atomic.Bool
	unavailable.Store(true)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if unavailable.Load() {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		if !strings.Contains(r.URL.Path, "/customers/"+accountID.String()+"/") {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		_, _ = fmt.Fprintf(w, `{"object":"list","next_page":null,"items":[{"id":"pur_1","product_id":%q,"purchased_at":%d,
			"status":"owned","environment":"production","store":"app_store","store_purchase_identifier":"2000000001"}]}`,
			testAdFreeProduct, oct1.UnixMilli())
	}))
	t.Cleanup(server.Close)
	revenueCat := billing.NewRevenueCat(billing.RevenueCatConfig{ProjectID: "proj_test", APIKey: "sk_test", BaseURL: server.URL})
	syncer := billing.NewSyncer(pool, revenueCat, billing.SyncConfig{Catalog: billing.AdFreeCatalog([]string{testAdFreeProduct})}, clk)
	webhooks := billing.NewWebhooks(pool, syncer, "Bearer test-secret", clk, logging.New(&bytes.Buffer{}, slog.LevelDebug, ""))

	require.ErrorIs(t, syncer.Sync(context.Background(), accountID), billing.ErrProviderUnavailable)
	assert.Zero(t, ledgerCount(t, pool), "실패한 동기화는 장부에 아무것도 남기지 않음")

	unavailable.Store(false)
	body := webhookBody("evt-1", "NON_RENEWING_PURCHASE", map[string]any{
		"app_user_id": accountID.String(), "transaction_id": "2000000001",
	})
	require.NoError(t, webhooks.Handle(context.Background(), body))
	clk.Advance(time.Minute)
	require.NoError(t, webhooks.Handle(context.Background(), body))
	require.NoError(t, webhooks.Handle(context.Background(), webhookBody("evt-2", "NON_RENEWING_PURCHASE", map[string]any{
		"app_user_id": accountID.String(), "transaction_id": "2000000001",
	})))

	row := ledgerOf(t, pool, "pur_1")
	assert.Equal(t, accountID, row.Owner)
	assert.Equal(t, "app_store", row.Store)
	require.NotNil(t, row.StorePurchaseID)
	assert.Equal(t, "2000000001", *row.StorePurchaseID)
	grants := allGrants(t, pool)
	require.Len(t, grants, 2, "구매 하나는 ad_free·insight 구간 하나씩")
	assertPeriod(t, grants, "pur_1", oct1, nov1, nil)
}

// 후보 계정이 accounts에 없으면 이벤트의 스토어 거래 id로 장부의 주인을 찾아 동기화합니다(spec §5.4).
func TestWebhook_UnknownCandidateFallsBackToLedgerOwner(t *testing.T) {
	tests := []struct {
		name   string
		fields map[string]any
	}{
		{"transaction_id", map[string]any{"transaction_id": "store-p1"}},
		{"original_transaction_id", map[string]any{"transaction_id": "store-unknown", "original_transaction_id": "store-p1"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newWebhookFixture(t)
			owner := newAccount(t, f.pool)
			f.source.set(owner, owned("p1", oct1))
			require.NoError(t, f.syncer.Sync(context.Background(), owner))

			f.clk.Advance(time.Hour)
			refundedAt := f.clk.Now()
			f.source.set(owner, refunded("p1", oct1))
			fields := map[string]any{"app_user_id": uuid.New().String(), "original_app_user_id": "$RCAnonymousID:abc123"}
			for k, v := range tt.fields {
				fields[k] = v
			}

			require.NoError(t, f.webhooks.Handle(context.Background(), webhookBody("evt-1", "CANCELLATION", fields)))

			assert.EqualValues(t, 2, f.source.calls.Load(), "주인 계정을 한 번 더 동기화")
			assertPeriod(t, allGrants(t, f.pool), "p1", oct1, nov1, &refundedAt)
			rows := eventRows(t, f.pool, "evt-1")
			require.Len(t, rows, 1)
			assert.Equal(t, uuid.NullUUID{UUID: owner, Valid: true}, rows[0].AccountID)
			assert.NotNil(t, rows[0].ProcessedAt)
			assert.Contains(t, f.logs.String(), owner.String())
		})
	}
}

// 후보 계정도 장부 주인도 못 찾으면 기록만 하고 Warn 로그를 남깁니다.
func TestWebhooks_Handle_UnknownAccountAndPurchase_RecordsOnly(t *testing.T) {
	f := newWebhookFixture(t)
	body := webhookBody("evt-1", "CANCELLATION", map[string]any{
		"app_user_id": uuid.New().String(), "transaction_id": "store-nowhere",
	})

	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	assert.Zero(t, f.source.calls.Load())
	rows := eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	assert.False(t, rows[0].AccountID.Valid)
	assert.NotNil(t, rows[0].ProcessedAt)
	assert.Contains(t, f.logs.String(), `"severity":"WARNING"`)
}

func TestWebhooks_Handle_InvalidBody_NoRow(t *testing.T) {
	f := newWebhookFixture(t)

	err := f.webhooks.Handle(context.Background(), map[string]any{"event": map[string]any{"type": "RENEWAL"}})

	require.ErrorIs(t, err, billing.ErrWebhookInvalid)
	var count int
	require.NoError(t, f.pool.QueryRow(context.Background(), "SELECT count(*) FROM billing_events").Scan(&count))
	assert.Zero(t, count)
}

func TestWebhooks_Handle_LogsNoPayload(t *testing.T) {
	f := newWebhookFixture(t)
	body := webhookBody("evt-1", "INITIAL_PURCHASE", map[string]any{
		"app_user_id": uuid.New().String(),
		"store":       "payload-marker-value",
	})

	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	assert.NotContains(t, f.logs.String(), "payload-marker-value")
}

func TestWebhooks_Authorized(t *testing.T) {
	logger := logging.New(&bytes.Buffer{}, slog.LevelDebug, "")
	clk := clocktest.New(now)
	configured := billing.NewWebhooks(nil, nil, "Bearer test-secret", clk, logger)
	unconfigured := billing.NewWebhooks(nil, nil, "", clk, logger)

	assert.True(t, configured.Authorized("Bearer test-secret"))
	assert.False(t, configured.Authorized("Bearer other"))
	assert.False(t, configured.Authorized("test-secret"))
	assert.False(t, configured.Authorized(""))
	assert.False(t, unconfigured.Authorized(""))
	assert.False(t, unconfigured.Authorized("Bearer test-secret"))
}
