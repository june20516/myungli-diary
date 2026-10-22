package auth_test

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
)

// newRevocations는 fixture의 제공자 대역·시계·상자로 Revocations를 만듭니다.
func (f *fixture) newRevocations(t *testing.T) *auth.Revocations {
	t.Helper()
	return auth.NewRevocations(f.pool, f.fake.NewKakao(t, f.clk), f.fake.NewApple(t, f.clk), f.box, f.clk,
		slog.New(slog.NewTextHandler(io.Discard, nil)))
}

// queueKakao는 카카오 허가 취소 대기 행을 넣고 id를 돌려줍니다. created_at은 fixture 시계의 지금입니다.
func (f *fixture) queueKakao(t *testing.T, subject string) int64 {
	t.Helper()
	var id int64
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`INSERT INTO provider_revocations (provider, subject, identity_id, next_attempt_at, created_at)
		 VALUES ('kakao', $1, $2, $3, $3) RETURNING id`, subject, uuid.Must(uuid.NewV7()), f.clk.Now()).Scan(&id))
	return id
}

// queueApple은 Apple 허가 취소 대기 행을 넣습니다. token은 원래 인증 계정 id를 aad로 묶어 암호화합니다.
func (f *fixture) queueApple(t *testing.T) int64 {
	t.Helper()
	identityID := uuid.Must(uuid.NewV7())
	sealed, keyID, err := f.box.Seal([]byte(providertest.AppleRefreshToken), identityID[:])
	require.NoError(t, err)
	var id int64
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`INSERT INTO provider_revocations (provider, identity_id, apple_refresh_token, apple_token_key_id, apple_client_id, next_attempt_at, created_at)
		 VALUES ('apple', $1, $2, $3, $4, $5, $5) RETURNING id`,
		identityID, sealed, keyID, providertest.AppleBundleID, f.clk.Now()).Scan(&id))
	return id
}

type revocationRow struct {
	attempts      int
	nextAttemptAt time.Time
}

func (f *fixture) revocation(t *testing.T, id int64) revocationRow {
	t.Helper()
	var row revocationRow
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT attempts, next_attempt_at FROM provider_revocations WHERE id = $1`, id).Scan(&row.attempts, &row.nextAttemptAt))
	return row
}

func (f *fixture) revocationCount(t *testing.T) int {
	t.Helper()
	return f.count(t, `SELECT count(*) FROM provider_revocations`)
}

func TestRevocations_SuccessDeletesRow(t *testing.T) {
	f := newFixture(t)
	revocations := f.newRevocations(t)
	f.queueKakao(t, "kakao-1")
	f.queueApple(t)

	attempted, err := revocations.RetryDue(f.ctx)

	require.NoError(t, err)
	assert.Equal(t, 2, attempted)
	assert.Zero(t, f.revocationCount(t))
	unlinks := f.fake.KakaoUnlinkRequests()
	require.Len(t, unlinks, 1)
	assert.Equal(t, "kakao-1", unlinks[0].Form.Get("target_id"))
	revokes := f.fake.AppleRevokeRequests()
	require.Len(t, revokes, 1)
	assert.Equal(t, providertest.AppleRefreshToken, revokes[0].Form.Get("token"), "복호화한 토큰으로 revoke합니다")
}

func TestRevocations_AttemptHandlesGivenIDsEvenIfNotDue(t *testing.T) {
	f := newFixture(t)
	revocations := f.newRevocations(t)
	id := f.queueKakao(t, "kakao-1")
	other := f.queueKakao(t, "kakao-2")
	f.exec(t, `UPDATE provider_revocations SET next_attempt_at = $2 WHERE id = $1`, id, f.clk.Now().Add(time.Hour))

	revocations.Attempt(f.ctx, []int64{id})

	assert.Equal(t, 1, f.revocationCount(t), "넘긴 id만 처리합니다")
	assert.Equal(t, 0, f.revocation(t, other).attempts)
}

func TestRevocations_FailureSchedulesBackoff(t *testing.T) {
	f := newFixture(t)
	revocations := f.newRevocations(t)
	id := f.queueKakao(t, "kakao-1")
	f.fake.SetKakaoUnlinkResponse(http.StatusServiceUnavailable, "")

	// 1분 x 2^(attempts-1), 최대 1일입니다.
	want := map[int]time.Duration{1: time.Minute, 2: 2 * time.Minute, 3: 4 * time.Minute, 11: 1024 * time.Minute, 12: 24 * time.Hour, 13: 24 * time.Hour}
	for n := 1; n <= 13; n++ {
		before := f.revocation(t, id)
		f.clk.Set(before.nextAttemptAt)
		attempted, err := revocations.RetryDue(f.ctx)
		require.NoError(t, err)
		require.Equal(t, 1, attempted, "시도 %d", n)

		after := f.revocation(t, id)
		assert.Equal(t, n, after.attempts)
		if d, ok := want[n]; ok {
			assert.Equal(t, d, after.nextAttemptAt.Sub(f.clk.Now()), "시도 %d", n)
		}
	}
	attempted, err := revocations.RetryDue(f.ctx)
	require.NoError(t, err)
	assert.Zero(t, attempted, "아직 시각이 안 된 행은 건드리지 않습니다")
}

func TestRevocations_AlreadyRevokedCountsAsSuccess(t *testing.T) {
	f := newFixture(t)
	revocations := f.newRevocations(t)

	// Apple invalid_grant
	f.queueApple(t)
	f.fake.SetAppleRevokeResponse(http.StatusBadRequest, `{"error":"invalid_grant"}`)
	// 카카오가 이미 앱과 연결되지 않은 사용자라고 답함
	f.queueKakao(t, "kakao-1")
	f.fake.SetKakaoUnlinkResponse(http.StatusBadRequest, `{"msg":"NotRegisteredUserException","code":-101}`)

	attempted, err := revocations.RetryDue(f.ctx)

	require.NoError(t, err)
	assert.Equal(t, 2, attempted)
	assert.Zero(t, f.revocationCount(t))
}

func TestRevocations_NoStoredAppleTokenIsDone(t *testing.T) {
	f := newFixture(t)
	revocations := f.newRevocations(t)
	// CHECK 제약 때문에 정상 경로로는 Apple 행에 token이 항상 있지만, 열이 비면 부를 것이 없는 것으로 봅니다.
	// 제약을 잠시 빼고 token 없는 Apple 행을 만듭니다.
	f.exec(t, `ALTER TABLE provider_revocations DROP CONSTRAINT provider_revocations_provider_columns`)
	f.exec(t, `INSERT INTO provider_revocations (provider, identity_id, next_attempt_at, created_at) VALUES ('apple', $1, $2, $2)`,
		uuid.Must(uuid.NewV7()), f.clk.Now())

	_, err := revocations.RetryDue(f.ctx)

	require.NoError(t, err)
	assert.Zero(t, f.revocationCount(t))
	assert.Empty(t, f.fake.AppleRevokeRequests())
}

func TestRevocations_GiveUpAfter30Days(t *testing.T) {
	f := newFixture(t)
	revocations := f.newRevocations(t)
	old := f.queueKakao(t, "kakao-old")
	fresh := f.queueKakao(t, "kakao-fresh")
	f.exec(t, `UPDATE provider_revocations SET created_at = $2 WHERE id = $1`, old, f.clk.Now().Add(-30*24*time.Hour-time.Second))
	f.exec(t, `UPDATE provider_revocations SET created_at = $2 WHERE id = $1`, fresh, f.clk.Now().Add(-30*24*time.Hour+time.Minute))
	f.fake.SetKakaoUnlinkResponse(http.StatusServiceUnavailable, "")

	attempted, err := revocations.RetryDue(f.ctx)

	require.NoError(t, err)
	assert.Equal(t, 2, attempted)
	requests := f.fake.KakaoUnlinkRequests()
	require.Len(t, requests, 1, "30일 지난 행은 제공자를 부르지 않습니다")
	assert.Equal(t, "kakao-fresh", requests[0].Form.Get("target_id"))
	assert.Equal(t, 1, f.revocationCount(t))
	assert.Equal(t, 1, f.revocation(t, fresh).attempts)
}

func TestRevocations_RetryDueSkipsLocked(t *testing.T) {
	f := newFixture(t)
	revocations := f.newRevocations(t)
	const rows = 12
	for i := range rows {
		f.queueKakao(t, "kakao-"+string(rune('a'+i)))
	}

	startTogether(2, func(int) {
		_, err := revocations.RetryDue(context.Background())
		assert.NoError(t, err)
	})

	assert.Len(t, f.fake.KakaoUnlinkRequests(), rows, "겹쳐 돈 job이 같은 행을 두 번 부르지 않습니다")
	assert.Zero(t, f.revocationCount(t))
}

// 다른 트랜잭션이 잡고 있는 행은 기다리지 않고 건너뛰고, 놓은 뒤 다음 실행이 처리합니다.
func TestRevocations_RetryDueSkipsRowsLockedElsewhere(t *testing.T) {
	f := newFixture(t)
	revocations := f.newRevocations(t)
	locked := f.queueKakao(t, "kakao-locked")
	f.queueKakao(t, "kakao-free")

	tx, err := f.pool.Begin(f.ctx)
	require.NoError(t, err)
	var id int64
	require.NoError(t, tx.QueryRow(f.ctx, `SELECT id FROM provider_revocations WHERE id = $1 FOR UPDATE`, locked).Scan(&id))

	attempted, err := revocations.RetryDue(f.ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, attempted)
	requests := f.fake.KakaoUnlinkRequests()
	require.Len(t, requests, 1)
	assert.Equal(t, "kakao-free", requests[0].Form.Get("target_id"))

	require.NoError(t, tx.Commit(f.ctx))
	attempted, err = revocations.RetryDue(f.ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, attempted)
	assert.Zero(t, f.revocationCount(t))
}

// RetryDue가 이미 실패 처리한 행은 Attempt가 곧바로 다시 부르지 않습니다.
func TestRevocations_AttemptSkipsRowsAlreadyFailed(t *testing.T) {
	f := newFixture(t)
	revocations := f.newRevocations(t)
	id := f.queueKakao(t, "kakao-1")
	f.fake.SetKakaoUnlinkResponse(http.StatusServiceUnavailable, "")
	_, err := revocations.RetryDue(f.ctx)
	require.NoError(t, err)
	require.Len(t, f.fake.KakaoUnlinkRequests(), 1)

	revocations.Attempt(f.ctx, []int64{id})

	assert.Len(t, f.fake.KakaoUnlinkRequests(), 1, "이미 실패 처리된 행은 부르지 않습니다")
	assert.Equal(t, 1, f.revocation(t, id).attempts)
}

// cancelingKakao는 호출되면 호출한 쪽 ctx를 취소하고 실패를 돌려주는 KakaoUnlinker입니다.
type cancelingKakao struct{ cancel context.CancelFunc }

func (k cancelingKakao) Unlink(context.Context, string) error {
	k.cancel()
	return context.Canceled
}

// 외부 호출 중 호출한 쪽 ctx가 취소되면 실패로 세지 않아 attempts·다음 시각이 그대로입니다.
func TestRevocations_CanceledContextDoesNotCountAsFailure(t *testing.T) {
	tests := []struct {
		name string
		run  func(t *testing.T, r *auth.Revocations, ctx context.Context, id int64)
	}{
		{"RetryDue", func(t *testing.T, r *auth.Revocations, ctx context.Context, _ int64) {
			_, err := r.RetryDue(ctx)
			require.ErrorIs(t, err, context.Canceled)
		}},
		{"Attempt", func(_ *testing.T, r *auth.Revocations, ctx context.Context, id int64) {
			r.Attempt(ctx, []int64{id})
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			id := f.queueKakao(t, "kakao-1")
			before := f.revocation(t, id)
			ctx, cancel := context.WithCancel(f.ctx)
			defer cancel()
			r := auth.NewRevocations(f.pool, cancelingKakao{cancel: cancel}, f.fake.NewApple(t, f.clk), f.box, f.clk, nil)

			tt.run(t, r, ctx, id)

			after := f.revocation(t, id)
			assert.Equal(t, 0, after.attempts)
			assert.True(t, after.nextAttemptAt.Equal(before.nextAttemptAt))
		})
	}
}
