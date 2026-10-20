package billing_test

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
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
	rows := eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	assert.NotNil(t, rows[0].ProcessedAt)
	assertPeriod(t, allGrants(t, f.pool), "p1", oct1, nov1, nil)
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

func TestWebhooks_Handle_Transfer_SyncsBothAccounts(t *testing.T) {
	f := newWebhookFixture(t)
	from, to := newAccount(t, f.pool), newAccount(t, f.pool)
	f.source.set(to, owned("p1", oct1))
	insertGrant(t, f.pool, from, grant(billing.AdFree, billing.SourceAdFreePass, "old", oct1, nov1))
	body := webhookBody("evt-1", "TRANSFER", map[string]any{
		"transferred_from": []any{from.String()},
		"transferred_to":   []any{to.String()},
	})

	require.NoError(t, f.webhooks.Handle(context.Background(), body))

	assert.EqualValues(t, 2, f.source.calls.Load())
	grants := allGrants(t, f.pool)
	assert.Equal(t, to, findGrant(t, grants, billing.AdFree, "p1").AccountID)
	assert.NotNil(t, findGrant(t, grants, billing.AdFree, "old").RevokedAt, "옮겨 간 계정의 이전 행은 취소됩니다")
	rows := eventRows(t, f.pool, "evt-1")
	require.Len(t, rows, 1)
	assert.Equal(t, uuid.NullUUID{UUID: from, Valid: true}, rows[0].AccountID, "account_id는 찾은 첫 계정입니다")
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
