package postgres_test

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// migration 00028은 기존 결제 webhook 기록을 허용 칸만 남기고, 보상 콜백 원문을 콜백 시각과 출처로 바꿉니다(D137 ③, S164).
func TestSchema00028_MinimizesExistingBillingAndRewardRows(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	if err := postgres.MigrateDownTo(ctx, pool, 27); err != nil {
		t.Fatal(err)
	}

	received := time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)
	insertReward := `INSERT INTO reward_events (transaction_id, raw_query, received_at) VALUES ($1, $2, $3)`
	rewards := []struct{ id, rawQuery string }{
		{"ssv", "ad_network=1&ad_unit=123&custom_data=x&key_id=1&reward_amount=1&reward_item=insight&timestamp=1792497600000&transaction_id=ssv&user_id=u&signature=s"},
		{"test", "ad_unit=123&test_reward=1&timestamp=1792497600000&transaction_id=test"},
		{"no-timestamp", "transaction_id=no-timestamp&timestamp=abc"},
	}
	for _, r := range rewards {
		if _, err := pool.Exec(ctx, insertReward, r.id, r.rawQuery, received); err != nil {
			t.Fatalf("보상 기록 %s: %v", r.id, err)
		}
	}
	insertBilling := `INSERT INTO billing_events (event_id, payload, received_at) VALUES ($1, $2, $3)`
	fullBody := `{"api_version":"1.0","event":{"id":"evt-1","type":"RENEWAL","store":"APP_STORE","price":1.5,"currency":"USD",
		"subscriber_attributes":{"$email":{"value":"someone@example.com"}},"aliases":["x"],"country_code":"KR","takehome_percentage":0.7}}`
	if _, err := pool.Exec(ctx, insertBilling, "evt-1", fullBody, received); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, insertBilling, "evt-2", `{"event":"x"}`, received); err != nil {
		t.Fatal(err)
	}

	if err := postgres.Migrate(ctx, pool, "up"); err != nil {
		t.Fatal(err)
	}

	wantRewards := map[string]struct {
		callbackAt time.Time
		source     string
	}{
		"ssv":          {time.UnixMilli(1792497600000), "ssv"},
		"test":         {time.UnixMilli(1792497600000), "test"},
		"no-timestamp": {received, "ssv"},
	}
	for id, want := range wantRewards {
		var callbackAt time.Time
		var source string
		if err := pool.QueryRow(ctx, `SELECT callback_at, source FROM reward_events WHERE transaction_id = $1`, id).Scan(&callbackAt, &source); err != nil {
			t.Fatalf("보상 기록 %s 조회: %v", id, err)
		}
		if !callbackAt.Equal(want.callbackAt) || source != want.source {
			t.Errorf("%s: callback_at = %s, source = %s, want %s, %s", id, callbackAt, source, want.callbackAt, want.source)
		}
	}
	var rawQueryColumns int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM information_schema.columns WHERE table_name = 'reward_events' AND column_name = 'raw_query'`).Scan(&rawQueryColumns); err != nil {
		t.Fatal(err)
	}
	if rawQueryColumns != 0 {
		t.Error("reward_events.raw_query가 남아 있습니다")
	}
	_, err := pool.Exec(ctx, `INSERT INTO reward_events (transaction_id, callback_at, source, received_at) VALUES ('bad', now(), 'other', now())`)
	wantSQLState(t, err, checkViolation)

	wantPayloads := map[string]map[string]any{
		"evt-1": {"event": map[string]any{"id": "evt-1", "type": "RENEWAL", "store": "APP_STORE", "price": 1.5, "currency": "USD"}},
		"evt-2": {"event": map[string]any{}},
	}
	for id, want := range wantPayloads {
		var raw []byte
		if err := pool.QueryRow(ctx, `SELECT payload FROM billing_events WHERE event_id = $1`, id).Scan(&raw); err != nil {
			t.Fatalf("결제 기록 %s 조회: %v", id, err)
		}
		var got map[string]any
		if err := json.Unmarshal(raw, &got); err != nil {
			t.Fatal(err)
		}
		gotJSON, _ := json.Marshal(got)
		wantJSON, _ := json.Marshal(want)
		if string(gotJSON) != string(wantJSON) {
			t.Errorf("%s payload = %s, want %s", id, gotJSON, wantJSON)
		}
	}
}
