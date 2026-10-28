package retention_test

import (
	"bytes"
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/retention"
)

var now = time.Date(2026, 10, 28, 3, 0, 0, 0, time.UTC)

type fixture struct {
	t     *testing.T
	pool  *pgxpool.Pool
	store *retention.Store
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	pool := dbtest.New(t)
	return &fixture{t: t, pool: pool, store: retention.NewStore(pool, clocktest.New(now))}
}

func (f *fixture) exec(sql string, args ...any) {
	f.t.Helper()
	_, err := f.pool.Exec(context.Background(), sql, args...)
	require.NoError(f.t, err, sql)
}

func (f *fixture) count(sql string, args ...any) int {
	f.t.Helper()
	var n int
	require.NoError(f.t, f.pool.QueryRow(context.Background(), sql, args...).Scan(&n), sql)
	return n
}

func (f *fixture) account() uuid.UUID {
	f.t.Helper()
	id := uuid.Must(uuid.NewV7())
	f.exec("INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', $2)", id, now)
	return id
}

// runSteps는 DB만 쓰는 정리 단계를 모두 돌립니다.
func (f *fixture) runSteps() {
	f.t.Helper()
	for _, step := range f.store.Steps() {
		_, err := step.Run(context.Background())
		require.NoError(f.t, err, step.Name)
	}
}

// birthHash는 n으로 구분되는 32바이트 지문입니다.
func birthHash(n byte) []byte { return bytes.Repeat([]byte{n}, 32) }

func (f *fixture) insertCaches(n byte, rulesetVersion string, createdAt time.Time) {
	f.t.Helper()
	f.exec("INSERT INTO chart_cache (birth_hash, ruleset_version, as_of_year, response, created_at) VALUES ($1, $2, 2026, '\\x00', $3)",
		birthHash(n), rulesetVersion, createdAt)
	f.exec("INSERT INTO daily_cache (birth_hash, ruleset_version, date, current_timezone, response, created_at) VALUES ($1, $2, '2026-10-28', 'Asia/Seoul', '\\x00', $3)",
		birthHash(n), rulesetVersion, createdAt)
	f.exec("INSERT INTO month_cache (birth_hash, ruleset_version, year, month, current_timezone, response, created_at) VALUES ($1, $2, 2026, 10, 'Asia/Seoul', '\\x00', $3)",
		birthHash(n), rulesetVersion, createdAt)
}

func (f *fixture) countCaches(n byte) int {
	f.t.Helper()
	return f.count(`SELECT (SELECT count(*) FROM chart_cache WHERE birth_hash = $1)
		+ (SELECT count(*) FROM daily_cache WHERE birth_hash = $1)
		+ (SELECT count(*) FROM month_cache WHERE birth_hash = $1)`, birthHash(n))
}

func TestSteps_DeletesExpiredCaches(t *testing.T) {
	f := newFixture(t)
	f.insertCaches(1, "rs-1", now.Add(-31*24*time.Hour))
	f.insertCaches(2, "rs-1", now.Add(-29*24*time.Hour))

	f.runSteps()

	assert.Zero(t, f.countCaches(1))
	assert.Equal(t, 3, f.countCaches(2))
}

func TestDeleteStaleRulesetCaches_KeepsCurrentVersion(t *testing.T) {
	f := newFixture(t)
	f.insertCaches(1, "rs-1", now)
	f.insertCaches(2, "rs-2", now)

	deleted, err := f.store.DeleteStaleRulesetCaches(context.Background(), "rs-2")

	require.NoError(t, err)
	assert.Equal(t, int64(3), deleted)
	assert.Zero(t, f.countCaches(1))
	assert.Equal(t, 3, f.countCaches(2))
}

func TestSteps_DeletesOldIdempotencyKeys(t *testing.T) {
	f := newFixture(t)
	account := f.account()
	insert := `INSERT INTO idempotency_keys (account_id, key, request_hash, created_at) VALUES ($1, $2, $3, $4)`
	f.exec(insert, account, "old", birthHash(1), now.Add(-25*time.Hour))
	f.exec(insert, account, "new", birthHash(1), now.Add(-23*time.Hour))

	f.runSteps()

	assert.Zero(t, f.count("SELECT count(*) FROM idempotency_keys WHERE key = 'old'"))
	assert.Equal(t, 1, f.count("SELECT count(*) FROM idempotency_keys WHERE key = 'new'"))
}

func TestSteps_DeletesEndedRateLimitWindows(t *testing.T) {
	f := newFixture(t)
	insert := `INSERT INTO rate_limits (key, window_start, count) VALUES ($1, $2, 1)`
	f.exec(insert, "ended", now.Add(-2*time.Minute))
	f.exec(insert, "current", now.Truncate(time.Minute))

	f.runSteps()

	assert.Zero(t, f.count("SELECT count(*) FROM rate_limits WHERE key = 'ended'"))
	assert.Equal(t, 1, f.count("SELECT count(*) FROM rate_limits WHERE key = 'current'"))
}

// insertRefreshToken은 refresh token 행을 넣습니다. replacedBy가 있으면 이미 쓴 토큰입니다.
func (f *fixture) insertRefreshToken(account uuid.UUID, expiresAt time.Time, replacedBy *uuid.UUID) uuid.UUID {
	f.t.Helper()
	id := uuid.Must(uuid.NewV7())
	var usedAt *time.Time
	if replacedBy != nil {
		usedAt = &now
	}
	f.exec(`INSERT INTO refresh_tokens (id, account_id, token_hash, family_id, expires_at, used_at, replaced_by_id)
		VALUES ($1, $2, $3, $1, $4, $5, $6)`, id, account, id[:], expiresAt, usedAt, replacedBy)
	return id
}

func (f *fixture) refreshTokenExists(id uuid.UUID) bool {
	f.t.Helper()
	return f.count("SELECT count(*) FROM refresh_tokens WHERE id = $1", id) == 1
}

func TestSteps_DeletesExpiredRefreshTokens(t *testing.T) {
	f := newFixture(t)
	account := f.account()
	b := f.insertRefreshToken(account, now.Add(-time.Hour), nil)
	a := f.insertRefreshToken(account, now.Add(-2*time.Hour), &b)
	live := f.insertRefreshToken(account, now.Add(time.Hour), nil)

	f.runSteps()

	assert.False(t, f.refreshTokenExists(a))
	assert.False(t, f.refreshTokenExists(b))
	assert.True(t, f.refreshTokenExists(live))
}

// TTL을 줄인 배포 뒤에는 앞 토큰이 뒤 토큰보다 늦게 만료될 수 있습니다. 살아 있는 토큰이 가리키는 행은 남깁니다.
func TestSteps_KeepsExpiredRefreshTokenReferencedByLiveToken(t *testing.T) {
	f := newFixture(t)
	account := f.account()
	b := f.insertRefreshToken(account, now.Add(-time.Hour), nil)
	a := f.insertRefreshToken(account, now.Add(time.Hour), &b)

	f.runSteps()

	assert.True(t, f.refreshTokenExists(a))
	assert.True(t, f.refreshTokenExists(b))
}

func TestSteps_DeletesMergeTicketsDayAfterExpiry(t *testing.T) {
	f := newFixture(t)
	account, other := f.account(), f.account()
	identity := uuid.Must(uuid.NewV7())
	f.exec("INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'kakao-1')", identity, other)
	insert := `INSERT INTO account_merge_tickets (id, token_hash, account_id, other_account_id, identity_id, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)`
	old, recent := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	f.exec(insert, old, old[:], account, other, identity, now.Add(-25*time.Hour))
	f.exec(insert, recent, recent[:], account, other, identity, now.Add(-23*time.Hour))

	f.runSteps()

	assert.Zero(t, f.count("SELECT count(*) FROM account_merge_tickets WHERE id = $1", old))
	assert.Equal(t, 1, f.count("SELECT count(*) FROM account_merge_tickets WHERE id = $1", recent))
}

func TestSteps_DeletesInactiveDevicesAfter30Days(t *testing.T) {
	f := newFixture(t)
	account := f.account()
	insert := `INSERT INTO devices (id, account_id, fcm_token, token_hash, platform, active, last_seen_at)
		VALUES ($1, $2, $3, $4, 'android', $5, $6)`
	stale, recent, active := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	f.exec(insert, stale, account, stale.String(), stale[:], false, now.Add(-31*24*time.Hour))
	f.exec(insert, recent, account, recent.String(), recent[:], false, now.Add(-29*24*time.Hour))
	f.exec(insert, active, account, active.String(), active[:], true, now.AddDate(-1, 0, 0))

	f.runSteps()

	assert.Zero(t, f.count("SELECT count(*) FROM devices WHERE id = $1", stale))
	assert.Equal(t, 1, f.count("SELECT count(*) FROM devices WHERE id = $1", recent))
	assert.Equal(t, 1, f.count("SELECT count(*) FROM devices WHERE id = $1", active))
}

func TestSteps_DeletesPreviewUsageAfterOneYear(t *testing.T) {
	f := newFixture(t)
	insert := `INSERT INTO preview_usage (device_hash, used_at) VALUES ($1, $2)`
	f.exec(insert, birthHash(1), now.AddDate(-1, 0, -1))
	f.exec(insert, birthHash(2), now.AddDate(-1, 0, 1))

	f.runSteps()

	assert.Zero(t, f.count("SELECT count(*) FROM preview_usage WHERE device_hash = $1", birthHash(1)))
	assert.Equal(t, 1, f.count("SELECT count(*) FROM preview_usage WHERE device_hash = $1", birthHash(2)))
}

// insertGrant는 권한 구간 한 행을 넣습니다. 구간은 expiresAt 하루 전에 시작합니다.
func (f *fixture) insertGrant(account uuid.UUID, source, sourceRef string, expiresAt time.Time) {
	f.t.Helper()
	entitlement := "ad_free"
	f.exec(`INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)`, account, entitlement, source, sourceRef, expiresAt.Add(-24*time.Hour), expiresAt)
}

func (f *fixture) grantExists(sourceRef string) bool {
	f.t.Helper()
	return f.count("SELECT count(*) FROM entitlement_grants WHERE source_ref = $1", sourceRef) == 1
}

func TestSteps_DeletesRewardRecordsAfterOneYear(t *testing.T) {
	f := newFixture(t)
	account := f.account()
	insert := `INSERT INTO reward_events (transaction_id, account_id, raw_query, received_at) VALUES ($1, $2, '', $3)`
	f.exec(insert, "old", account, now.AddDate(-1, 0, -1))
	f.exec(insert, "recent", account, now.AddDate(-1, 0, 1))
	f.insertGrant(account, "rewarded_ad", "old", now.AddDate(-1, 0, -1))
	f.insertGrant(account, "rewarded_ad", "recent", now.AddDate(-1, 0, 1))

	f.runSteps()

	assert.Zero(t, f.count("SELECT count(*) FROM reward_events WHERE transaction_id = 'old'"))
	assert.Equal(t, 1, f.count("SELECT count(*) FROM reward_events WHERE transaction_id = 'recent'"))
	assert.False(t, f.grantExists("old"))
	assert.True(t, f.grantExists("recent"))
}

func (f *fixture) insertPurchase(account uuid.UUID, id string, purchasedAt time.Time) {
	f.t.Helper()
	f.exec(`INSERT INTO purchases (id, account_id, original_account_id, product_id, store, purchased_at, production)
		VALUES ($1, $2, $2, 'ad_free_30d', 'app_store', $3, true)`, id, account, purchasedAt)
}

func (f *fixture) purchaseExists(id string) bool {
	f.t.Helper()
	return f.count("SELECT count(*) FROM purchases WHERE id = $1", id) == 1
}

func TestSteps_DeletesBillingRecordsAfterFiveYears(t *testing.T) {
	f := newFixture(t)
	account := f.account()
	insert := `INSERT INTO billing_events (event_id, account_id, payload, received_at) VALUES ($1, $2, '{}', $3)`
	f.exec(insert, "old", account, now.AddDate(-5, 0, -1))
	f.exec(insert, "recent", account, now.AddDate(-5, 0, 1))
	f.insertPurchase(account, "old", now.AddDate(-5, 0, -2))
	f.insertGrant(account, "ad_free_pass", "old", now.AddDate(-5, 0, -1))
	f.insertPurchase(account, "recent", now.AddDate(-5, 0, 1))
	f.insertGrant(account, "ad_free_pass", "recent", now.AddDate(-5, 0, 2))

	f.runSteps()

	assert.Zero(t, f.count("SELECT count(*) FROM billing_events WHERE event_id = 'old'"))
	assert.Equal(t, 1, f.count("SELECT count(*) FROM billing_events WHERE event_id = 'recent'"))
	assert.False(t, f.purchaseExists("old"))
	assert.False(t, f.grantExists("old"))
	assert.True(t, f.purchaseExists("recent"))
	assert.True(t, f.grantExists("recent"))
}

// 5년 전에 샀어도 구간이 5년 안에 끝났으면 구매와 구간을 함께 남깁니다(앞 구간 끝에 이어 붙은 구매).
func TestSteps_KeepsPurchaseWhoseGrantEndedWithinFiveYears(t *testing.T) {
	f := newFixture(t)
	account := f.account()
	f.insertPurchase(account, "chained", now.AddDate(-6, 0, 0))
	f.insertGrant(account, "ad_free_pass", "chained", now.AddDate(-4, 0, 0))

	f.runSteps()

	assert.True(t, f.purchaseExists("chained"))
	assert.True(t, f.grantExists("chained"))
}

// insertDiary는 date 날짜 기록과 일기 한 편을 넣습니다. deletedAt이 있으면 지운 일기입니다.
func (f *fixture) insertDiary(account uuid.UUID, date string, deletedAt, purgedAt *time.Time) uuid.UUID {
	f.t.Helper()
	f.exec(`INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version)
		VALUES ($1, $2, '{tag}', '[]', 'rs-1') ON CONFLICT DO NOTHING`, account, date)
	id := uuid.Must(uuid.NewV7())
	f.exec(`INSERT INTO diaries (id, account_id, date, body, deleted_at, content_purged_at) VALUES ($1, $2, $3, 'body', $4, $5)`,
		id, account, date, deletedAt, purgedAt)
	return id
}

func (f *fixture) diaryContent(id uuid.UUID) (string, *time.Time) {
	f.t.Helper()
	var body string
	var purgedAt *time.Time
	require.NoError(f.t, f.pool.QueryRow(context.Background(),
		"SELECT body, content_purged_at FROM diaries WHERE id = $1", id).Scan(&body, &purgedAt))
	return body, purgedAt
}

func TestSteps_PurgesSoftDeletedDiaryAfter30Days(t *testing.T) {
	f := newFixture(t)
	account := f.account()
	oldDeleted, recentDeleted, earlier := now.AddDate(0, 0, -31), now.AddDate(0, 0, -29), now.AddDate(0, 0, -1)
	old := f.insertDiary(account, "2026-09-01", &oldDeleted, nil)
	recent := f.insertDiary(account, "2026-09-02", &recentDeleted, nil)
	purged := f.insertDiary(account, "2026-09-03", &oldDeleted, &earlier)
	live := f.insertDiary(account, "2026-09-04", nil, nil)

	f.runSteps()

	body, purgedAt := f.diaryContent(old)
	assert.Empty(t, body)
	require.NotNil(t, purgedAt)
	assert.True(t, purgedAt.Equal(now))
	body, purgedAt = f.diaryContent(recent)
	assert.Equal(t, "body", body)
	assert.Nil(t, purgedAt)
	_, purgedAt = f.diaryContent(purged)
	require.NotNil(t, purgedAt)
	assert.True(t, purgedAt.Equal(earlier), "이미 비운 행의 시각은 그대로입니다")
	body, _ = f.diaryContent(live)
	assert.Equal(t, "body", body)
	assert.Equal(t, 1, f.count("SELECT count(*) FROM diary_days WHERE account_id = $1 AND date = '2026-09-01' AND all_tags = '{tag}'", account),
		"날짜 기록(태그·질문)은 남깁니다")
}

func TestSteps_PurgesSoftDeletedScheduleAfter30Days(t *testing.T) {
	f := newFixture(t)
	account := f.account()
	insert := `INSERT INTO schedules (id, account_id, date, all_day, title, memo, deleted_at) VALUES ($1, $2, '2026-09-01', true, 'title', 'memo', $3)`
	old, recent := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	f.exec(insert, old, account, now.AddDate(0, 0, -31))
	f.exec(insert, recent, account, now.AddDate(0, 0, -29))

	f.runSteps()

	assert.Equal(t, 1, f.count("SELECT count(*) FROM schedules WHERE id = $1 AND title = '' AND memo IS NULL AND content_purged_at = $2", old, now))
	assert.Equal(t, 1, f.count("SELECT count(*) FROM schedules WHERE id = $1 AND title = 'title' AND memo = 'memo' AND content_purged_at IS NULL", recent))
}

// insertAppleWebLogin은 Apple 웹 로그인 교환 행을 넣습니다. 토큰 열은 암호문 대신 고정 바이트입니다.
func (f *fixture) insertAppleWebLogin(subject string, expiresAt time.Time, consumed bool) uuid.UUID {
	f.t.Helper()
	id := uuid.Must(uuid.NewV7())
	var consumedAt *time.Time
	if consumed {
		consumedAt = &expiresAt
	}
	f.exec(`INSERT INTO apple_web_logins (id, exchange_hash, subject, nonce_hash, apple_refresh_token, apple_token_key_id, apple_client_id, expires_at, consumed_at)
		VALUES ($1, $2, $3, repeat('a', 64), '\x0102', 'box-1', 'web.client', $4, $5)`, id, id[:], subject, expiresAt, consumedAt)
	return id
}

func (f *fixture) appleWebLoginExists(id uuid.UUID) bool {
	f.t.Helper()
	return f.count("SELECT count(*) FROM apple_web_logins WHERE id = $1", id) == 1
}

// 콜백에서 Apple 토큰을 받았지만 app이 오지 않아 연결되지 않은 subject는 허가 취소 대기 행으로 넘깁니다(S19).
// 암호화 aad가 웹 로그인 행 id이므로 identity_id에 그 id를 넣습니다.
func TestSteps_QueuesAppleRevokeForUnclaimedWebLogin(t *testing.T) {
	f := newFixture(t)
	id := f.insertAppleWebLogin("apple-1", now.Add(-25*time.Hour), false)

	f.runSteps()

	assert.False(t, f.appleWebLoginExists(id))
	assert.Equal(t, 1, f.count(`SELECT count(*) FROM provider_revocations
		WHERE provider = 'apple' AND subject = 'apple-1' AND identity_id = $1 AND apple_refresh_token = '\x0102'
		  AND apple_token_key_id = 'box-1' AND apple_client_id = 'web.client' AND attempts = 0 AND next_attempt_at = $2`, id, now))
}

func TestSteps_SkipsAppleRevokeWhenIdentityExists(t *testing.T) {
	f := newFixture(t)
	f.exec("INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'apple', 'apple-1')", uuid.Must(uuid.NewV7()), f.account())
	id := f.insertAppleWebLogin("apple-1", now.Add(-25*time.Hour), false)

	f.runSteps()

	assert.False(t, f.appleWebLoginExists(id))
	assert.Zero(t, f.count("SELECT count(*) FROM provider_revocations"))
}

func TestSteps_SkipsAppleRevokeForConsumedWebLogin(t *testing.T) {
	f := newFixture(t)
	id := f.insertAppleWebLogin("apple-1", now.Add(-25*time.Hour), true)

	f.runSteps()

	assert.False(t, f.appleWebLoginExists(id))
	assert.Zero(t, f.count("SELECT count(*) FROM provider_revocations"))
}

func TestSteps_KeepsWebLoginWithinGrace(t *testing.T) {
	f := newFixture(t)
	id := f.insertAppleWebLogin("apple-1", now.Add(-23*time.Hour), false)

	f.runSteps()

	assert.True(t, f.appleWebLoginExists(id))
	assert.Zero(t, f.count("SELECT count(*) FROM provider_revocations"))
}
