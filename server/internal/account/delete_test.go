package account_test

import (
	"bytes"
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// deletedTables는 계정 삭제가 그 계정 행을 모두 지우는 표와, 그 계정의 행 수를 세는 쿼리입니다(spec §3.2 "지움").
// 캐시는 계정이 아니라 출생 해시로 세므로 따로 확인합니다.
var deletedTables = map[string]string{ //nolint:gosec // 표 이름(refresh_tokens 등)이며 비밀 값이 아닙니다
	"profiles":         `SELECT count(*) FROM profiles WHERE account_id = $1`,
	"diaries":          `SELECT count(*) FROM diaries WHERE account_id = $1`,
	"diary_days":       `SELECT count(*) FROM diary_days WHERE account_id = $1`,
	"schedules":        `SELECT count(*) FROM schedules WHERE account_id = $1`,
	"daily_selections": `SELECT count(*) FROM daily_selections WHERE account_id = $1`,
	"reactions": `SELECT count(*) FROM reactions r JOIN daily_selections s ON s.id = r.selection_id
		WHERE s.account_id = $1`,
	"rotation_state":   `SELECT count(*) FROM rotation_state WHERE account_id = $1`,
	"consents":         `SELECT count(*) FROM consents WHERE account_id = $1`,
	"auth_identities":  `SELECT count(*) FROM auth_identities WHERE account_id = $1`,
	"refresh_tokens":   `SELECT count(*) FROM refresh_tokens WHERE account_id = $1`,
	"idempotency_keys": `SELECT count(*) FROM idempotency_keys WHERE account_id = $1`,
	"account_merge_tickets": `SELECT count(*) FROM account_merge_tickets
		WHERE account_id = $1 OR other_account_id = $1`,
	"account_merge_receipts": `SELECT count(*) FROM account_merge_receipts WHERE account_id = $1`,
	"devices":                `SELECT count(*) FROM devices WHERE account_id = $1`,
	// 그 계정 Apple 인증 계정의 웹 로그인 기록입니다. seedAccount가 Apple subject를 'apple-<계정 id>'로 둡니다.
	"apple_web_logins": `SELECT count(*) FROM apple_web_logins WHERE subject = 'apple-' || $1::text`,
}

// keptTables는 계정 삭제가 건드리지 않는 표의 전체 행 수 쿼리입니다(spec §3.2 "남김", purchases는 PR 3).
var keptTables = map[string]string{
	"entitlement_grants": `SELECT count(*) FROM entitlement_grants`,
	"reward_events":      `SELECT count(*) FROM reward_events`,
	"billing_events":     `SELECT count(*) FROM billing_events`,
	"preview_usage":      `SELECT count(*) FROM preview_usage`,
}

// cacheTables는 출생 해시로 찾는 계산 캐시 표입니다.
var cacheTables = []string{"chart_cache", "daily_cache", "month_cache"}

// seededAccount는 seedAccount가 채운 계정의 id와 출생 해시입니다.
type seededAccount struct {
	id        uuid.UUID
	birthHash []byte
	// selectionID는 이 계정의 첫 문장 선택 기록 id입니다.
	selectionID int64
	// oldBirthHash는 프로필을 고치기 전 출생 해시입니다. 문장 선택 기록과 캐시에만 남아 있습니다.
	oldBirthHash []byte
}

// newAccount는 active 계정 하나를 만듭니다.
func newAccount(t *testing.T, ctx context.Context, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	id := uuid.Must(uuid.NewV7())
	require.NoError(t, authdb.New(pool).CreateAccount(ctx, authdb.CreateAccountParams{ID: id, LastActiveAt: testNow}))
	return id
}

// seedAccount는 새 계정을 만들고 "지움"과 "남김" 표, 캐시를 모두 채웁니다.
// hashByte는 출생 해시(32바이트)를 채울 값이고, subjectPrefix는 제공자 subject가 계정끼리 겹치지 않게 붙입니다.
func seedAccount(t *testing.T, ctx context.Context, pool *pgxpool.Pool, hashByte byte, subjectPrefix string) seededAccount {
	t.Helper()
	id := newAccount(t, ctx, pool)
	hash := bytes.Repeat([]byte{hashByte}, 32)
	exec := func(sql string, args ...any) {
		t.Helper()
		_, err := pool.Exec(ctx, sql, args...)
		require.NoError(t, err, sql)
	}

	exec(`INSERT INTO content_seeds (version, slots) VALUES ('seed-v1', '{}') ON CONFLICT DO NOTHING`)
	exec(`INSERT INTO profiles (account_id, honorific, language, current_timezone, calendar, is_leap_month,
			birth_year, birth_month, birth_day, birth_time_status, gender, birth_timezone, birth_place_status,
			notify_status, birth_hash)
		VALUES ($1, '벗', 'ko', 'Asia/Seoul', 'solar', false, 1990, 3, 14, 'unknown', 'female', 'Asia/Seoul',
			'not_asked', 'not_asked', $2)`, id, hash)
	exec(`INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version)
		VALUES ($1, '2026-10-12', '{}', '[]', 'r1')`, id)
	exec(`INSERT INTO diaries (id, account_id, date, body) VALUES ($1, $2, '2026-10-12', '일기')`, uuid.Must(uuid.NewV7()), id)
	exec(`INSERT INTO schedules (id, account_id, date, all_day, title) VALUES ($1, $2, '2026-10-21', true, '회의')`,
		uuid.Must(uuid.NewV7()), id)
	exec(`INSERT INTO devices (id, account_id, fcm_token, token_hash, platform, active, last_seen_at)
		VALUES ($1, $2, $3, sha256(convert_to($3, 'UTF8')), 'android', true, now())`, uuid.Must(uuid.NewV7()), id, "fcm-"+id.String())
	var selectionID int64
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, '2026-10-12', 'overall', $2, 'msg.a', 'v1', 'seed-v1') RETURNING id`, id, hash).Scan(&selectionID))
	exec(`INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'like')`, selectionID)
	exec(`INSERT INTO rotation_state (account_id, message_key, next_variant) VALUES ($1, 'msg.a', 'v2')`, id)
	exec(`INSERT INTO consents (id, account_id, document, version, agreed_at) VALUES ($1, $2, 'terms', '1', $3)`,
		uuid.Must(uuid.NewV7()), id, testNow)
	identityID := uuid.Must(uuid.NewV7())
	exec(`INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', $3)`,
		identityID, id, subjectPrefix+"-kakao")
	// Apple 인증 계정(저장한 token 없음)과 그 subject의 웹 로그인 기록입니다.
	appleSubject := "apple-" + id.String()
	exec(`INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'apple', $3)`,
		uuid.Must(uuid.NewV7()), id, appleSubject)
	exec(`INSERT INTO apple_web_logins (id, exchange_hash, subject, nonce_hash, apple_refresh_token, apple_token_key_id, apple_client_id, expires_at)
		VALUES ($1, $2, $3, $4, '\x01', 'box-1', 'web.client', $5)`,
		uuid.Must(uuid.NewV7()), bytes.Repeat([]byte{hashByte ^ 0x33}, 32), appleSubject, strings.Repeat("a", 64), testNow.Add(time.Minute))
	// 회전된 refresh token 쌍입니다. 앞 token이 replaced_by_id로 뒤 token을 가리키므로(자기참조 RESTRICT)
	// 한 번의 DELETE로 둘 다 지울 수 있어야 합니다.
	family, rotated := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	exec(`INSERT INTO refresh_tokens (id, account_id, token_hash, family_id, expires_at) VALUES ($1, $2, $3, $4, $5)`,
		rotated, id, bytes.Repeat([]byte{hashByte}, 32), family, testNow.Add(time.Hour))
	exec(`INSERT INTO refresh_tokens (id, account_id, token_hash, family_id, expires_at, used_at, replaced_by_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		uuid.Must(uuid.NewV7()), id, bytes.Repeat([]byte{hashByte ^ 0xFF}, 32), family, testNow.Add(time.Hour), testNow, rotated)
	exec(`INSERT INTO idempotency_keys (account_id, key, request_hash, created_at) VALUES ($1, 'k1', $2, $3)`,
		id, bytes.Repeat([]byte{1}, 32), testNow)
	// 이 계정이 A로 합친 영수증입니다(S115). 계정마다 다른 토큰 해시를 씁니다.
	exec(`INSERT INTO account_merge_receipts (token_hash, account_id, merged_at) VALUES ($1, $2, $3)`,
		bytes.Repeat([]byte{hashByte ^ 0xFF}, 32), id, testNow)

	// 남김 표입니다.
	exec(`INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'ad_free', 'ad_free_pass', $2, $3, $4)`, id, subjectPrefix+"-purchase", testNow, testNow.Add(time.Hour))
	exec(`INSERT INTO reward_events (transaction_id, account_id, raw_query, received_at) VALUES ($1, $2, 'q', $3)`,
		subjectPrefix+"-tx", id, testNow)
	exec(`INSERT INTO billing_events (event_id, account_id, payload, received_at) VALUES ($1, $2, '{}', $3)`,
		subjectPrefix+"-event", id, testNow)
	exec(`INSERT INTO preview_usage (device_hash) VALUES ($1)`, bytes.Repeat([]byte{hashByte}, 32))

	// 출생 해시로 만든 캐시입니다.
	exec(`INSERT INTO chart_cache (birth_hash, ruleset_version, as_of_year, response) VALUES ($1, 'r1', 2026, '\x00')`, hash)
	exec(`INSERT INTO daily_cache (birth_hash, ruleset_version, date, current_timezone, response)
		VALUES ($1, 'r1', '2026-10-12', 'Asia/Seoul', '\x00')`, hash)
	exec(`INSERT INTO month_cache (birth_hash, ruleset_version, year, month, current_timezone, response)
		VALUES ($1, 'r1', 2026, 10, 'Asia/Seoul', '\x00')`, hash)
	// 프로필을 고치기 전 출생 정보로 만든 선택 기록과 캐시입니다.
	oldHash := bytes.Repeat([]byte{hashByte ^ 0x0F}, 32)
	exec(`INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, '2026-10-01', 'overall', $2, 'msg.old', 'v1', 'seed-v1')`, id, oldHash)
	exec(`INSERT INTO chart_cache (birth_hash, ruleset_version, as_of_year, response) VALUES ($1, 'r1', 2026, '\x00')`, oldHash)

	return seededAccount{id: id, birthHash: hash, selectionID: selectionID, oldBirthHash: oldHash}
}

// deleteInTx는 DeleteAccountTx를 트랜잭션 하나에서 실행해 commit합니다.
func deleteInTx(t *testing.T, ctx context.Context, pool *pgxpool.Pool, id uuid.UUID, now time.Time) ([]int64, error) {
	t.Helper()
	var ids []int64
	err := postgres.InTx(ctx, pool, func(tx pgx.Tx) error {
		var err error
		ids, err = account.DeleteAccountTx(ctx, tx, id, now)
		return err
	})
	return ids, err
}

func countRows(t *testing.T, ctx context.Context, pool *pgxpool.Pool, sql string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, pool.QueryRow(ctx, sql, args...).Scan(&n), sql)
	return n
}

func TestDeleteAccountTx_RemovesPersonalData(t *testing.T) {
	f := newFixture(t)
	target := seedAccount(t, f.ctx, f.pool, 0xA1, "target")
	other := seedAccount(t, f.ctx, f.pool, 0xB2, "other")
	// 이 계정이 A(account_id)이거나 B(other_account_id)인 합치기 토큰을 둘 다 지웁니다.
	// 두 행 모두 다른 계정의 인증 계정을 가리켜, 인증 계정 삭제의 CASCADE가 아니라 토큰 삭제 쿼리로만 지워지게 합니다.
	var otherIdentity uuid.UUID
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT id FROM auth_identities WHERE account_id = $1`, other.id).Scan(&otherIdentity))
	for i, pair := range [][2]uuid.UUID{{other.id, target.id}, {target.id, other.id}} {
		_, err := f.pool.Exec(f.ctx, `INSERT INTO account_merge_tickets (id, token_hash, account_id, other_account_id, identity_id, expires_at)
			VALUES ($1, $2, $3, $4, $5, $6)`, uuid.Must(uuid.NewV7()), bytes.Repeat([]byte{byte(9 + i)}, 32), pair[0], pair[1], otherIdentity, testNow.Add(time.Hour))
		require.NoError(t, err)
	}

	keptBefore := map[string]int{}
	for table, sql := range keptTables {
		keptBefore[table] = countRows(t, f.ctx, f.pool, sql)
	}
	otherBefore := map[string]int{}
	for table, sql := range deletedTables {
		otherBefore[table] = countRows(t, f.ctx, f.pool, sql, other.id)
	}
	// 다른 계정 쪽에서 센 합치기 토큰 둘은 target과 함께 지워지므로 기대값에서 뺍니다.
	otherBefore["account_merge_tickets"] -= 2

	deletedAt := testNow.Add(time.Hour)
	_, err := deleteInTx(t, f.ctx, f.pool, target.id, deletedAt)
	require.NoError(t, err)

	for table, sql := range deletedTables {
		assert.Zero(t, countRows(t, f.ctx, f.pool, sql, target.id), "지운 계정의 %s", table)
		assert.Equal(t, otherBefore[table], countRows(t, f.ctx, f.pool, sql, other.id), "다른 계정의 %s", table)
	}
	for table, sql := range keptTables {
		assert.Equal(t, keptBefore[table], countRows(t, f.ctx, f.pool, sql), "남기는 %s", table)
	}
	for _, table := range cacheTables {
		assert.Zero(t, countRows(t, f.ctx, f.pool, `SELECT count(*) FROM `+table+` WHERE birth_hash = $1`, target.birthHash), "지운 계정의 %s", table)
		assert.Equal(t, 1, countRows(t, f.ctx, f.pool, `SELECT count(*) FROM `+table+` WHERE birth_hash = $1`, other.birthHash), "다른 계정의 %s", table)
	}
	// 옛 출생 정보(선택 기록에만 남은 해시)의 캐시도 지웁니다.
	assert.Zero(t, countRows(t, f.ctx, f.pool, `SELECT count(*) FROM chart_cache WHERE birth_hash = $1`, target.oldBirthHash), "지운 계정의 옛 출생 해시 캐시")
	assert.Equal(t, 1, countRows(t, f.ctx, f.pool, `SELECT count(*) FROM chart_cache WHERE birth_hash = $1`, other.oldBirthHash), "다른 계정의 옛 출생 해시 캐시")

	var status string
	var gotDeletedAt, gotLastActiveAt time.Time
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT status, deleted_at, last_active_at FROM accounts WHERE id = $1`, target.id).
		Scan(&status, &gotDeletedAt, &gotLastActiveAt))
	assert.Equal(t, "deleted", status)
	assert.True(t, deletedAt.Equal(gotDeletedAt), "deleted_at = %v", gotDeletedAt)
	assert.True(t, deletedAt.Equal(gotLastActiveAt), "껍데기에 활동 시각을 남기지 않습니다(last_active_at = deleted_at): %v", gotLastActiveAt)
	assert.Equal(t, "active", f.statusOf(t, other.id))
}

func TestDeleteAccountTx_WithoutProfileDeletesNoCache(t *testing.T) {
	f := newFixture(t)
	other := seedAccount(t, f.ctx, f.pool, 0xB2, "other")

	_, err := deleteInTx(t, f.ctx, f.pool, f.id, testNow)

	require.NoError(t, err)
	assert.Equal(t, "deleted", f.status(t))
	for _, table := range cacheTables {
		assert.Equal(t, 1, countRows(t, f.ctx, f.pool, `SELECT count(*) FROM `+table+` WHERE birth_hash = $1`, other.birthHash), table)
	}
}

func TestDeleteAccountTx_TalliesReactions(t *testing.T) {
	f := newFixture(t)
	target := seedAccount(t, f.ctx, f.pool, 0xA1, "target")
	exec := func(sql string, args ...any) {
		t.Helper()
		_, err := f.pool.Exec(f.ctx, sql, args...)
		require.NoError(t, err, sql)
	}
	// seedAccount가 넣은 (msg.a, v1) like 하나에, 같은 문장의 다른 날 like 하나와 취소한 like 하나를 더합니다.
	var second, third int64
	require.NoError(t, f.pool.QueryRow(f.ctx, `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, '2026-10-13', 'overall', $2, 'msg.a', 'v1', 'seed-v1') RETURNING id`, target.id, target.birthHash).Scan(&second))
	require.NoError(t, f.pool.QueryRow(f.ctx, `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, '2026-10-14', 'overall', $2, 'msg.b', 'v1', 'seed-v1') RETURNING id`, target.id, target.birthHash).Scan(&third))
	exec(`INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'like')`, second)
	exec(`INSERT INTO reactions (selection_id, reaction, deleted_at) VALUES ($1, 'like', $2)`, third, testNow)
	// 이미 다른 계정이 남긴 집계가 있습니다.
	exec(`INSERT INTO reaction_tallies (message_key, variant, reaction, count) VALUES ('msg.a', 'v1', 'like', 3)`)

	_, err := deleteInTx(t, f.ctx, f.pool, target.id, testNow)
	require.NoError(t, err)

	tallies := map[string]int64{}
	rows, err := f.pool.Query(f.ctx, `SELECT message_key || '/' || variant || '/' || reaction, count FROM reaction_tallies`)
	require.NoError(t, err)
	for rows.Next() {
		var key string
		var count int64
		require.NoError(t, rows.Scan(&key, &count))
		tallies[key] = count
	}
	require.NoError(t, rows.Err())
	assert.Equal(t, map[string]int64{"msg.a/v1/like": 5}, tallies, "취소한 반응(msg.b)은 더하지 않습니다")
}

func TestDeleteAccountTx_QueuesKakaoAndAppleOnly(t *testing.T) {
	f := newFixture(t)
	exec := func(sql string, args ...any) {
		t.Helper()
		_, err := f.pool.Exec(f.ctx, sql, args...)
		require.NoError(t, err, sql)
	}
	kakaoID, appleID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	appleToken := []byte("encrypted-apple-refresh")
	exec(`INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'K1')`, kakaoID, f.id)
	exec(`INSERT INTO auth_identities (id, account_id, provider, subject, apple_refresh_token, apple_token_key_id, apple_client_id)
		VALUES ($1, $2, 'apple', 'A1', $3, 'box-1', 'app.client')`, appleID, f.id, appleToken)
	exec(`INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'line', 'L1')`, uuid.Must(uuid.NewV7()), f.id)
	exec(`INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'google', 'G1')`, uuid.Must(uuid.NewV7()), f.id)

	ids, err := deleteInTx(t, f.ctx, f.pool, f.id, testNow)

	require.NoError(t, err)
	require.Len(t, ids, 2)
	type revocation struct {
		provider      string
		subject       *string
		identityID    uuid.UUID
		token         []byte
		keyID         *string
		clientID      *string
		attempts      int
		nextAttemptAt time.Time
		createdAt     time.Time
	}
	got := map[string]revocation{}
	rows, err := f.pool.Query(f.ctx, `SELECT provider, subject, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id,
			attempts, next_attempt_at, created_at
		FROM provider_revocations WHERE id = ANY($1)`, ids)
	require.NoError(t, err)
	for rows.Next() {
		var r revocation
		require.NoError(t, rows.Scan(&r.provider, &r.subject, &r.identityID, &r.token, &r.keyID, &r.clientID, &r.attempts, &r.nextAttemptAt, &r.createdAt))
		got[r.provider] = r
	}
	require.NoError(t, rows.Err())
	require.Len(t, got, 2)

	kakao := got["kakao"]
	require.NotNil(t, kakao.subject)
	assert.Equal(t, "K1", *kakao.subject)
	assert.Equal(t, kakaoID, kakao.identityID)
	assert.Nil(t, kakao.token)

	apple := got["apple"]
	assert.Nil(t, apple.subject, "Apple은 subject를 남기지 않습니다")
	assert.Equal(t, appleID, apple.identityID, "Apple token 복호화의 aad입니다")
	assert.Equal(t, appleToken, apple.token)
	require.NotNil(t, apple.keyID)
	assert.Equal(t, "box-1", *apple.keyID)
	require.NotNil(t, apple.clientID)
	assert.Equal(t, "app.client", *apple.clientID)

	for provider, r := range got {
		assert.Zero(t, r.attempts, provider)
		assert.True(t, testNow.Equal(r.nextAttemptAt), "%s는 바로 시도할 수 있습니다", provider)
		assert.True(t, testNow.Equal(r.createdAt), "%s의 created_at은 앱 시각입니다(30일 포기 기준)", provider)
	}
}

// 저장한 Apple token이 없으면 끊을 허가가 없으므로 대기 행을 넣지 않습니다(spec §4.2 4).
func TestDeleteAccountTx_SkipsAppleWithoutStoredToken(t *testing.T) {
	f := newFixture(t)
	_, err := f.pool.Exec(f.ctx, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'apple', 'A1')`,
		uuid.Must(uuid.NewV7()), f.id)
	require.NoError(t, err)

	ids, err := deleteInTx(t, f.ctx, f.pool, f.id, testNow)

	require.NoError(t, err)
	assert.Empty(t, ids)
	assert.Zero(t, countRows(t, f.ctx, f.pool, `SELECT count(*) FROM provider_revocations`))
}

func TestDeleteAccountTx_AlreadyDeletedIsNoop(t *testing.T) {
	f := newFixture(t)
	_, err := f.pool.Exec(f.ctx, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'K1')`,
		uuid.Must(uuid.NewV7()), f.id)
	require.NoError(t, err)
	_, err = deleteInTx(t, f.ctx, f.pool, f.id, testNow)
	require.NoError(t, err)

	ids, err := deleteInTx(t, f.ctx, f.pool, f.id, testNow.Add(time.Hour))

	require.NoError(t, err)
	assert.Nil(t, ids)
	assert.Equal(t, 1, countRows(t, f.ctx, f.pool, `SELECT count(*) FROM provider_revocations`), "대기 행을 다시 넣지 않습니다")
	var deletedAt time.Time
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT deleted_at FROM accounts WHERE id = $1`, f.id).Scan(&deletedAt))
	assert.True(t, testNow.Equal(deletedAt), "처음 지운 시각을 유지합니다")
}

// 지운 계정의 껍데기는 요청이 와도 last_active_at을 갱신하지 않습니다.
func TestAccess_DeletedAccountDoesNotTouchLastActive(t *testing.T) {
	f := newFixture(t)
	_, err := deleteInTx(t, f.ctx, f.pool, f.id, testNow)
	require.NoError(t, err)

	f.clk.Set(testNow.Add(48 * time.Hour))
	got, err := f.service.Access(f.ctx, f.id)

	require.NoError(t, err)
	assert.Equal(t, account.StatusDeleted, got.Status)
	assert.True(t, testNow.Equal(f.lastActiveAt(t)), "last_active_at = %v", f.lastActiveAt(t))
}

func TestDeleteAccountTx_UnknownAccountIsNotFound(t *testing.T) {
	f := newFixture(t)

	_, err := deleteInTx(t, f.ctx, f.pool, uuid.New(), testNow)

	assert.ErrorIs(t, err, account.ErrNotFound)
}

// requireDeletedAccountError는 err가 지운 계정에 쓰려다 trigger가 낸 오류인지 확인합니다.
func requireDeletedAccountError(t *testing.T, err error) {
	t.Helper()
	var pgErr *pgconn.PgError
	require.ErrorAs(t, err, &pgErr)
	assert.Equal(t, account.SQLStateAccountDeleted, pgErr.Code)
	assert.True(t, account.IsAccountDeletedError(err))
}

// 지운 계정에 개인 데이터 행을 새로 붙이는 쓰기는 표마다 trigger가 막습니다(S105).
func TestDeletedAccount_RejectsPersonalWrites(t *testing.T) {
	f := newFixture(t)
	target := seedAccount(t, f.ctx, f.pool, 0xA1, "target")
	other := seedAccount(t, f.ctx, f.pool, 0xB2, "other")
	_, err := deleteInTx(t, f.ctx, f.pool, target.id, testNow)
	require.NoError(t, err)

	hash := bytes.Repeat([]byte{0xA1}, 32)
	writes := map[string]struct {
		sql  string
		args []any
	}{
		"profiles insert": {`INSERT INTO profiles (account_id, honorific, language, current_timezone, calendar, is_leap_month,
			birth_year, birth_month, birth_day, birth_time_status, gender, birth_timezone, birth_place_status,
			notify_status, birth_hash)
			VALUES ($1, '벗', 'ko', 'Asia/Seoul', 'solar', false, 1990, 3, 14, 'unknown', 'female', 'Asia/Seoul',
			'not_asked', 'not_asked', $2)`, []any{target.id, hash}},
		"diary_days insert": {`INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version)
			VALUES ($1, '2026-10-20', '{}', '[]', 'r1')`, []any{target.id}},
		"schedules insert": {`INSERT INTO schedules (id, account_id, date, all_day, title) VALUES ($1, $2, '2026-10-21', true, 't')`,
			[]any{uuid.Must(uuid.NewV7()), target.id}},
		"daily_selections insert": {`INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
			VALUES ($1, '2026-10-20', 'overall', $2, 'msg.a', 'v1', 'seed-v1')`, []any{target.id, hash}},
		"rotation_state insert": {`INSERT INTO rotation_state (account_id, message_key, next_variant) VALUES ($1, 'msg.z', 'v1')`,
			[]any{target.id}},
		"consents insert": {`INSERT INTO consents (id, account_id, document, version, agreed_at) VALUES ($1, $2, 'privacy', '1', now())`,
			[]any{uuid.Must(uuid.NewV7()), target.id}},
		"auth_identities insert": {`INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'line', 'L-new')`,
			[]any{uuid.Must(uuid.NewV7()), target.id}},
		"refresh_tokens insert": {`INSERT INTO refresh_tokens (id, account_id, token_hash, family_id, expires_at) VALUES ($1, $2, $3, $4, now())`,
			[]any{uuid.Must(uuid.NewV7()), target.id, bytes.Repeat([]byte{0xEE}, 32), uuid.Must(uuid.NewV7())}},
		"idempotency_keys insert": {`INSERT INTO idempotency_keys (account_id, key, request_hash, created_at) VALUES ($1, 'k2', $2, now())`,
			[]any{target.id, bytes.Repeat([]byte{1}, 32)}},
		"devices insert": {`INSERT INTO devices (id, account_id, fcm_token, token_hash, platform, active, last_seen_at) VALUES ($1, $2, 'fcm-new', sha256('fcm-new'), 'ios', true, now())`,
			[]any{uuid.Must(uuid.NewV7()), target.id}},
		// 나중 합치기처럼 account_id를 바꾸는 UPDATE도 지운 계정으로는 옮기지 못합니다.
		"diaries account_id update": {`UPDATE diaries SET account_id = $1 WHERE account_id = $2`, []any{target.id, other.id}},
		"auth_identities account_id update": {`UPDATE auth_identities SET account_id = $1 WHERE account_id = $2`,
			[]any{target.id, other.id}},
		"devices account_id update": {`UPDATE devices SET account_id = $1 WHERE account_id = $2`, []any{target.id, other.id}},
	}
	for name, w := range writes {
		t.Run(name, func(t *testing.T) {
			_, err := f.pool.Exec(f.ctx, w.sql, w.args...)
			requireDeletedAccountError(t, err)
		})
	}

	t.Run("diaries insert", func(t *testing.T) {
		// diaries는 diary_days FK보다 trigger가 먼저 걸리는지 보려고, 지운 계정의 날짜 기록 없이 넣습니다.
		_, err := f.pool.Exec(f.ctx, `INSERT INTO diaries (id, account_id, date, body) VALUES ($1, $2, '2026-10-12', 'x')`,
			uuid.Must(uuid.NewV7()), target.id)
		requireDeletedAccountError(t, err)
	})

	// 다른 계정의 쓰기와 account_id를 바꾸지 않는 UPDATE는 막지 않습니다.
	_, err = f.pool.Exec(f.ctx, `UPDATE diaries SET body = '고침' WHERE account_id = $1`, other.id)
	require.NoError(t, err)
	_, err = f.pool.Exec(f.ctx, `INSERT INTO rotation_state (account_id, message_key, next_variant) VALUES ($1, 'msg.z', 'v1')`, other.id)
	require.NoError(t, err)
}

// 지우기 직전에 읽어 둔 선택 기록에 반응을 붙이는 쓰기도 막습니다. reactions는 account_id가 없어 선택 기록으로 계정을 찾습니다.
func TestDeletedAccount_RejectsReactionOnStaleSelection(t *testing.T) {
	f := newFixture(t)
	target := seedAccount(t, f.ctx, f.pool, 0xA1, "target")
	_, err := f.pool.Exec(f.ctx, `UPDATE reactions SET deleted_at = now() WHERE selection_id = $1`, target.selectionID)
	require.NoError(t, err)

	tx, err := f.pool.Begin(f.ctx)
	require.NoError(t, err)
	t.Cleanup(func() { _ = tx.Rollback(context.Background()) })
	_, err = account.DeleteAccountTx(f.ctx, tx, target.id, testNow)
	require.NoError(t, err)

	done := make(chan error, 1)
	go func() {
		_, err := f.pool.Exec(f.ctx, `INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'like')`, target.selectionID)
		done <- err
	}()
	waitForLockWaiter(t, f.ctx, f.pool)
	require.NoError(t, tx.Commit(f.ctx))

	requireDeletedAccountError(t, <-done)
}

// 자식 행을 먼저 잠그는 쓰기(PutReaction: 선택 기록 FOR UPDATE 뒤 반응 INSERT)와 계정 삭제는 서로를 기다려 deadlock이 납니다.
// PostgreSQL이 한쪽을 40P01로 끝내고, 삭제 쪽이면 InTx가 다시 실행해 끝냅니다. 어느 쪽이 끝나든 삭제는 성공하고
// 지운 계정의 반응·선택 기록은 남지 않습니다.
func TestService_Delete_DeadlockWithReactionWriteResolves(t *testing.T) {
	f := newFixture(t)
	target := seedAccount(t, f.ctx, f.pool, 0xA1, "target")
	// 활성 반응은 하나뿐이라(부분 unique) 기존 반응을 미리 취소해 둡니다.
	_, err := f.pool.Exec(f.ctx, `UPDATE reactions SET deleted_at = now() WHERE selection_id = $1`, target.selectionID)
	require.NoError(t, err)

	// PutReaction처럼 선택 기록을 먼저 잠급니다.
	writer, err := f.pool.Begin(f.ctx)
	require.NoError(t, err)
	t.Cleanup(func() { _ = writer.Rollback(context.Background()) })
	_, err = writer.Exec(f.ctx, `SELECT 1 FROM daily_selections WHERE id = $1 FOR UPDATE`, target.selectionID)
	require.NoError(t, err)

	deleted := make(chan error, 1)
	go func() { deleted <- f.service.Delete(f.ctx, target.id) }()
	// 삭제가 계정 행을 잡은 뒤 선택 기록 삭제에서 writer를 기다립니다.
	waitForLockWaiter(t, f.ctx, f.pool)

	// writer의 반응 INSERT는 trigger가 계정 행을 FOR KEY SHARE로 읽다 삭제를 기다리므로 deadlock입니다.
	_, insertErr := writer.Exec(f.ctx, `INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'dislike')`, target.selectionID)
	if insertErr == nil {
		// 삭제가 deadlock으로 끝나고 다시 실행되는 중입니다. writer가 commit하면 그 뒤에 지웁니다.
		t.Log("deadlock으로 끝난 쪽: 계정 삭제(InTx가 다시 실행)")
		require.NoError(t, writer.Commit(f.ctx))
	} else {
		var pgErr *pgconn.PgError
		require.ErrorAs(t, insertErr, &pgErr)
		assert.Equal(t, "40P01", pgErr.Code, "writer 쪽이 deadlock으로 끝났습니다")
		t.Log("deadlock으로 끝난 쪽: writer")
		require.NoError(t, writer.Rollback(f.ctx))
	}

	require.NoError(t, <-deleted)
	assert.Equal(t, "deleted", f.statusOf(t, target.id))
	assert.Zero(t, countRows(t, f.ctx, f.pool, deletedTables["reactions"], target.id))
	assert.Zero(t, countRows(t, f.ctx, f.pool, deletedTables["daily_selections"], target.id))
}

// waitForLockWaiter는 이 DB에서 잠금을 기다리는 세션이 하나 생길 때까지 기다립니다.
func waitForLockWaiter(t *testing.T, ctx context.Context, pool *pgxpool.Pool) {
	t.Helper()
	require.Eventually(t, func() bool {
		return countRows(t, ctx, pool, `SELECT count(*) FROM pg_stat_activity
			WHERE datname = current_database() AND wait_event_type = 'Lock'`) == 1
	}, 10*time.Second, 20*time.Millisecond)
}

// 삭제 트랜잭션이 계정 행을 잡은 동안 시작한 쓰기는 잠금을 기다렸다가, 삭제가 commit되면 지운 계정 오류로 실패합니다.
// 미들웨어를 이미 통과한 요청이 껍데기 계정에 행을 남기지 않는지 결정적으로 재현합니다(Review Focus 1).
// HTTP 401 변환은 internal/cli의 TestService_Delete_ConcurrentWriteGets401이 확인합니다.
func TestDeleteAccountTx_ConcurrentWriteFailsAfterCommit(t *testing.T) {
	f := newFixture(t)
	target := seedAccount(t, f.ctx, f.pool, 0xA1, "target")

	tx, err := f.pool.Begin(f.ctx)
	require.NoError(t, err)
	t.Cleanup(func() { _ = tx.Rollback(context.Background()) })
	_, err = account.DeleteAccountTx(f.ctx, tx, target.id, testNow)
	require.NoError(t, err)

	done := make(chan error, 1)
	go func() {
		_, err := f.pool.Exec(f.ctx, `INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version)
			VALUES ($1, '2026-10-20', '{}', '[]', 'r1')`, target.id)
		done <- err
	}()
	waitForLockWaiter(t, f.ctx, f.pool)
	require.NoError(t, tx.Commit(f.ctx))

	requireDeletedAccountError(t, <-done)
	assert.Zero(t, countRows(t, f.ctx, f.pool, `SELECT count(*) FROM diary_days WHERE account_id = $1`, target.id))
}

// 삭제가 rollback되면 기다리던 쓰기는 그대로 성공합니다.
func TestDeleteAccountTx_ConcurrentWriteSucceedsAfterRollback(t *testing.T) {
	f := newFixture(t)
	target := seedAccount(t, f.ctx, f.pool, 0xA1, "target")

	tx, err := f.pool.Begin(f.ctx)
	require.NoError(t, err)
	_, err = account.DeleteAccountTx(f.ctx, tx, target.id, testNow)
	require.NoError(t, err)

	done := make(chan error, 1)
	go func() {
		_, err := f.pool.Exec(f.ctx, `INSERT INTO rotation_state (account_id, message_key, next_variant) VALUES ($1, 'msg.z', 'v1')`, target.id)
		done <- err
	}()
	waitForLockWaiter(t, f.ctx, f.pool)
	require.NoError(t, tx.Rollback(f.ctx))

	require.NoError(t, <-done)
	assert.Equal(t, 2, countRows(t, f.ctx, f.pool, `SELECT count(*) FROM rotation_state WHERE account_id = $1`, target.id))
}

func TestService_Delete_AttemptsQueuedRevocationsAfterCommit(t *testing.T) {
	f := newFixture(t)
	_, err := f.pool.Exec(f.ctx, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'K1')`,
		uuid.Must(uuid.NewV7()), f.id)
	require.NoError(t, err)
	// Attempt가 불릴 때 대기 행이 이미 commit돼 다른 연결에서 보여야 합니다.
	f.revoker.onAttempt = func(ids []int64) {
		assert.Equal(t, len(ids), countRows(t, f.ctx, f.pool, `SELECT count(*) FROM provider_revocations WHERE id = ANY($1)`, ids))
		assert.Equal(t, "deleted", f.status(t))
	}

	require.NoError(t, f.service.Delete(f.ctx, f.id))

	calls := f.revoker.calls()
	require.Len(t, calls, 1)
	assert.Len(t, calls[0].ids, 1)
}

// commit 뒤 계정 id와 대기 행 수만 Info로 남깁니다.
func TestService_Delete_LogsAccountAndRevocationCount(t *testing.T) {
	f := newFixture(t)
	_, err := f.pool.Exec(f.ctx, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'K-secret-subject')`,
		uuid.Must(uuid.NewV7()), f.id)
	require.NoError(t, err)

	require.NoError(t, f.service.Delete(f.ctx, f.id))

	logs := f.logs.String()
	assert.Contains(t, logs, `"msg":"계정 삭제"`)
	assert.Contains(t, logs, `"accountId":"`+f.id.String()+`"`)
	assert.Contains(t, logs, `"revocations":1`)
	assert.NotContains(t, logs, "K-secret-subject", "subject는 남기지 않습니다")
}

func TestService_Delete_NoRevocationsSkipsAttempt(t *testing.T) {
	f := newFixture(t)

	require.NoError(t, f.service.Delete(f.ctx, f.id))

	assert.Equal(t, "deleted", f.status(t))
	assert.Empty(t, f.revoker.calls())
}

func TestService_Delete_AttemptIgnoresCallerCancellation(t *testing.T) {
	f := newFixture(t)
	_, err := f.pool.Exec(f.ctx, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'K1')`,
		uuid.Must(uuid.NewV7()), f.id)
	require.NoError(t, err)
	ctx, cancel := context.WithCancel(f.ctx)
	defer cancel()
	// commit 직후 호출자가 떠난 상황입니다.
	f.revoker.beforeAttempt = cancel

	require.NoError(t, f.service.Delete(ctx, f.id))

	calls := f.revoker.calls()
	require.Len(t, calls, 1)
	assert.NoError(t, calls[0].ctxErr, "허가 취소 시도는 취소되지 않은 ctx를 받습니다")
}

func TestService_Delete_AlreadyDeletedIsNoop(t *testing.T) {
	f := newFixture(t)
	require.NoError(t, f.service.Delete(f.ctx, f.id))

	f.logs.Reset()

	require.NoError(t, f.service.Delete(f.ctx, f.id))

	assert.Equal(t, "deleted", f.status(t))
	assert.NotContains(t, f.logs.String(), "계정 삭제", "이미 지운 계정에는 삭제 로그를 남기지 않습니다")
}

func TestService_Delete_UnknownAccountIsNotFound(t *testing.T) {
	f := newFixture(t)

	err := f.service.Delete(f.ctx, uuid.New())

	assert.True(t, errors.Is(err, account.ErrNotFound), "err = %v", err)
	assert.Empty(t, f.revoker.calls())
}
