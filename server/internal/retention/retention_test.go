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
