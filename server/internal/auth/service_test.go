package auth_test

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"errors"
	"net/http"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/auth/secretbox"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

var testNow = time.Date(2026, 10, 13, 9, 0, 0, 0, time.UTC)

const testNonce = "raw-nonce-1"

// fixture는 서비스 하나와 그것이 쓰는 DB·제공자 대역·시계를 묶습니다.
type fixture struct {
	ctx     context.Context
	pool    *pgxpool.Pool
	clk     *clocktest.Fake
	fake    *providertest.Server
	box     *secretbox.Box
	service *auth.Service
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	clk := clocktest.New(testNow)
	fake := providertest.New(t)
	pool := dbtest.New(t)

	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)
	access, err := token.NewAccessIssuer(token.SigningKey{ID: "k1", Private: priv}, nil, clk)
	require.NoError(t, err)
	box, err := secretbox.New(secretbox.Key{ID: "b1", Bytes: bytes.Repeat([]byte{7}, 32)}, nil)
	require.NoError(t, err)

	kakao := fake.NewKakao(t, clk)
	service := auth.NewService(pool, auth.ServiceDeps{
		Kakao:       kakao,
		Apple:       fake.NewApple(t, clk),
		KakaoUnlink: kakao,
		Access:      access,
		Box:         box,
		Clock:       clk,
	})
	return &fixture{ctx: context.Background(), pool: pool, clk: clk, fake: fake, box: box, service: service}
}

// kakaoToken은 subject로 검증을 통과하는 카카오 id_token을 만듭니다.
func (f *fixture) kakaoToken(subject string) string {
	return f.fake.SignIDToken(providertest.KakaoClaims(subject, testNonce, f.clk.Now()))
}

// loginKakao는 subject로 카카오 로그인을 하고 성공을 확인합니다.
func (f *fixture) loginKakao(t *testing.T, subject string) auth.LoginResult {
	t.Helper()
	res, err := f.service.LoginKakao(f.ctx, f.kakaoToken(subject), testNonce)
	require.NoError(t, err)
	return res
}

// loginApple은 subject로 Apple native 로그인을 하고 성공을 확인합니다.
func (f *fixture) loginApple(t *testing.T, subject string) auth.LoginResult {
	t.Helper()
	idToken := f.fake.SignIDToken(providertest.AppleClaims(subject, testNonce, provider.AppleNative, f.clk.Now()))
	res, err := f.service.LoginApple(f.ctx, idToken, "auth-code", testNonce, provider.AppleNative)
	require.NoError(t, err)
	return res
}

// count는 SQL(SELECT count(*) ...)의 결과를 돌려줍니다.
func (f *fixture) count(t *testing.T, sql string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, f.pool.QueryRow(f.ctx, sql, args...).Scan(&n))
	return n
}

// exec는 테스트 준비용 SQL을 실행합니다.
func (f *fixture) exec(t *testing.T, sql string, args ...any) {
	t.Helper()
	_, err := f.pool.Exec(f.ctx, sql, args...)
	require.NoError(t, err)
}

// markPendingDeletion은 계정을 삭제 대기로 바꾸고 제공자 연결 해제 시각을 기록합니다(DELETE /v1/me 직후 상태).
func (f *fixture) markPendingDeletion(t *testing.T, accountID uuid.UUID) {
	t.Helper()
	f.exec(t, `UPDATE accounts SET status = 'pending_deletion', deletion_requested_at = $2 WHERE id = $1`, accountID, f.clk.Now())
	f.exec(t, `UPDATE auth_identities SET provider_disconnected_at = $2 WHERE account_id = $1`, accountID, f.clk.Now())
}

// refreshRow는 refresh token 원문으로 DB 행의 family·만료·사용 시각을 읽습니다.
type refreshRow struct {
	familyID  uuid.UUID
	expiresAt time.Time
	usedAt    *time.Time
	revokedAt *time.Time
}

func (f *fixture) refreshRow(t *testing.T, raw string) refreshRow {
	t.Helper()
	var r refreshRow
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT family_id, expires_at, used_at, revoked_at FROM refresh_tokens WHERE token_hash = $1`,
		token.HashRefreshToken(raw)).Scan(&r.familyID, &r.expiresAt, &r.usedAt, &r.revokedAt))
	return r
}

// startTogether는 n개의 goroutine을 시작 신호 하나로 동시에 풀어 fn을 부르고, 모두 끝날 때까지 기다립니다.
func startTogether(n int, fn func(i int)) {
	start := make(chan struct{})
	var wg sync.WaitGroup
	for i := range n {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			fn(i)
		}()
	}
	close(start)
	wg.Wait()
}

func TestLoginKakao_NewSubjectCreatesAccount(t *testing.T) {
	f := newFixture(t)

	res := f.loginKakao(t, "kakao-1")

	assert.True(t, res.IsNewAccount)
	assert.False(t, res.RestoredFromDeletion)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM accounts WHERE id = $1 AND status = 'active' AND last_active_at = $2`, res.AccountID, testNow))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities WHERE account_id = $1 AND provider = 'kakao' AND subject = 'kakao-1' AND apple_refresh_token IS NULL`, res.AccountID))

	assert.NotEmpty(t, res.Tokens.AccessToken)
	assert.Equal(t, testNow.Add(token.AccessTTL), res.Tokens.AccessExpiresAt)
	assert.Equal(t, testNow.Add(token.RefreshTTL), res.Tokens.RefreshExpiresAt)
	row := f.refreshRow(t, res.Tokens.RefreshToken)
	assert.True(t, row.expiresAt.Equal(res.Tokens.RefreshExpiresAt))
	assert.Nil(t, row.usedAt)
}

func TestLoginKakao_KnownSubjectReusesAccount(t *testing.T) {
	f := newFixture(t)
	first := f.loginKakao(t, "kakao-1")

	second := f.loginKakao(t, "kakao-1")

	assert.False(t, second.IsNewAccount)
	assert.False(t, second.RestoredFromDeletion, "active 계정은 RestoreAccount가 0행이므로 복구가 아닙니다")
	assert.Equal(t, first.AccountID, second.AccountID)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM accounts`))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities`))
	assert.NotEqual(t, f.refreshRow(t, first.Tokens.RefreshToken).familyID, f.refreshRow(t, second.Tokens.RefreshToken).familyID,
		"로그인마다 새 family를 만듭니다")
}

// Review Focus 2: 같은 subject의 첫 로그인이 동시에 와도 계정은 하나입니다.
func TestLoginKakao_ConcurrentFirstLoginsCreateOneAccount(t *testing.T) {
	f := newFixture(t)
	const workers = 2
	tokens := make([]string, workers)
	for i := range tokens {
		tokens[i] = f.kakaoToken("kakao-race")
	}

	results := make([]auth.LoginResult, workers)
	errs := make([]error, workers)
	startTogether(workers, func(i int) {
		results[i], errs[i] = f.service.LoginKakao(f.ctx, tokens[i], testNonce)
	})

	for _, err := range errs {
		require.NoError(t, err)
	}
	assert.Equal(t, results[0].AccountID, results[1].AccountID)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM accounts`))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities`))
	assert.Equal(t, 2, f.count(t, `SELECT count(*) FROM refresh_tokens WHERE account_id = $1`, results[0].AccountID))
	assert.True(t, results[0].IsNewAccount != results[1].IsNewAccount, "한쪽만 새 계정입니다")
}

// 동시 첫 로그인의 unique 위반 재시도 경로를 결정적으로 재현합니다.
// 다른 트랜잭션이 같은 (provider, subject)를 넣고 commit하지 않은 채로 있으면, 로그인은 identity insert에서 기다리다
// 그 트랜잭션이 commit되면 unique 위반을 받고, 처음부터 다시 실행해 이미 있는 계정을 씁니다.
func TestLoginKakao_UniqueConflictRetriesWithExistingIdentity(t *testing.T) {
	f := newFixture(t)
	other := uuid.Must(uuid.NewV7())
	tx, err := f.pool.Begin(f.ctx)
	require.NoError(t, err)
	t.Cleanup(func() { _ = tx.Rollback(context.Background()) })
	_, err = tx.Exec(f.ctx, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', $2)`, other, testNow)
	require.NoError(t, err)
	_, err = tx.Exec(f.ctx, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'kakao-race')`,
		uuid.Must(uuid.NewV7()), other)
	require.NoError(t, err)

	type outcome struct {
		res auth.LoginResult
		err error
	}
	done := make(chan outcome, 1)
	idToken := f.kakaoToken("kakao-race")
	go func() {
		res, err := f.service.LoginKakao(f.ctx, idToken, testNonce)
		done <- outcome{res, err}
	}()

	// 로그인이 identity insert에서 잠금을 기다릴 때까지 기다린 뒤 다른 트랜잭션을 commit합니다.
	require.Eventually(t, func() bool {
		return f.count(t, `SELECT count(*) FROM pg_stat_activity
			WHERE datname = current_database() AND wait_event_type = 'Lock' AND query LIKE '%INSERT INTO auth_identities%'`) == 1
	}, 10*time.Second, 20*time.Millisecond)
	require.NoError(t, tx.Commit(f.ctx))

	got := <-done
	require.NoError(t, got.err)
	assert.Equal(t, other, got.res.AccountID)
	assert.False(t, got.res.IsNewAccount)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM accounts`), "실패한 첫 시도의 계정 행은 rollback됩니다")
}

func TestLoginKakao_RestoresPendingDeletion(t *testing.T) {
	f := newFixture(t)
	first := f.loginKakao(t, "kakao-1")
	f.markPendingDeletion(t, first.AccountID)

	res := f.loginKakao(t, "kakao-1")

	assert.Equal(t, first.AccountID, res.AccountID)
	assert.True(t, res.RestoredFromDeletion)
	assert.False(t, res.IsNewAccount)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM accounts WHERE id = $1 AND status = 'active' AND deletion_requested_at IS NULL`, res.AccountID))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities WHERE account_id = $1 AND provider_disconnected_at IS NULL`, res.AccountID))
}

func TestLoginKakao_DeletedAccountIdentityFails(t *testing.T) {
	f := newFixture(t)
	first := f.loginKakao(t, "kakao-1")
	f.exec(t, `UPDATE accounts SET status = 'deleted', deletion_requested_at = $2, anonymized_at = $2 WHERE id = $1`, first.AccountID, testNow)

	_, err := f.service.LoginKakao(f.ctx, f.kakaoToken("kakao-1"), testNonce)

	require.Error(t, err)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM refresh_tokens`), "새 토큰을 만들지 않습니다")
}

func TestLoginKakao_ProviderErrorsMapToSentinels(t *testing.T) {
	tests := []struct {
		name    string
		prepare func(f *fixture) (idToken string)
		want    error
	}{
		{
			name: "nonce 불일치는 토큰 오류",
			prepare: func(f *fixture) string {
				return f.fake.SignIDToken(providertest.KakaoClaims("kakao-1", "other-nonce", f.clk.Now()))
			},
			want: auth.ErrProviderTokenInvalid,
		},
		{
			name: "JWKS 장애는 제공자 장애",
			prepare: func(f *fixture) string {
				f.fake.SetJWKSStatus(http.StatusInternalServerError)
				return f.kakaoToken("kakao-1")
			},
			want: auth.ErrProviderUnavailable,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			idToken := tt.prepare(f)

			_, err := f.service.LoginKakao(f.ctx, idToken, testNonce)

			require.ErrorIs(t, err, tt.want)
			assert.NotErrorIs(t, err, provider.ErrTokenInvalid, "제공자 오류 원인을 응답 경로로 넘기지 않습니다")
			assert.NotErrorIs(t, err, provider.ErrUnavailable)
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM accounts`))
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM auth_identities`))
		})
	}
}

func TestLoginApple_StoresEncryptedRefreshTokenAndClientID(t *testing.T) {
	f := newFixture(t)

	res := f.loginApple(t, "apple-1")

	assert.True(t, res.IsNewAccount)
	var (
		identityID uuid.UUID
		sealed     []byte
		keyID      string
		clientID   string
	)
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT id, apple_refresh_token, apple_token_key_id, apple_client_id FROM auth_identities WHERE account_id = $1 AND provider = 'apple'`,
		res.AccountID).Scan(&identityID, &sealed, &keyID, &clientID))
	assert.NotContains(t, string(sealed), providertest.AppleRefreshToken)
	plain, err := f.box.Open(sealed, keyID, identityID[:])
	require.NoError(t, err, "aad는 identity id입니다")
	assert.Equal(t, providertest.AppleRefreshToken, string(plain))
	assert.Equal(t, providertest.AppleBundleID, clientID)

	// 다시 로그인하면 새로 받은 refresh token으로 바꿔 저장합니다.
	f.fake.SetAppleTokenResponse(http.StatusOK, `{"refresh_token":"second-refresh"}`)
	again := f.loginApple(t, "apple-1")
	assert.Equal(t, res.AccountID, again.AccountID)
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT apple_refresh_token, apple_token_key_id FROM auth_identities WHERE id = $1`, identityID).Scan(&sealed, &keyID))
	plain, err = f.box.Open(sealed, keyID, identityID[:])
	require.NoError(t, err)
	assert.Equal(t, "second-refresh", string(plain))
}

func TestLoginApple_FailedCodeExchangeCreatesNothing(t *testing.T) {
	tests := []struct {
		name   string
		status int
		body   string
		want   error
	}{
		{name: "invalid_grant", status: http.StatusBadRequest, body: `{"error":"invalid_grant"}`, want: auth.ErrProviderTokenInvalid},
		{name: "Apple 장애", status: http.StatusServiceUnavailable, body: "", want: auth.ErrProviderUnavailable},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			f.fake.SetAppleTokenResponse(tt.status, tt.body)
			idToken := f.fake.SignIDToken(providertest.AppleClaims("apple-1", testNonce, provider.AppleNative, f.clk.Now()))

			_, err := f.service.LoginApple(f.ctx, idToken, "auth-code", testNonce, provider.AppleNative)

			require.ErrorIs(t, err, tt.want)
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM accounts`))
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM auth_identities`))
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM refresh_tokens`))
		})
	}
}

func TestRefresh_RotatesWithinFamily(t *testing.T) {
	f := newFixture(t)
	login := f.loginKakao(t, "kakao-1")
	f.clk.Advance(time.Hour)

	pair, err := f.service.Refresh(f.ctx, login.Tokens.RefreshToken)

	require.NoError(t, err)
	now := testNow.Add(time.Hour)
	assert.NotEqual(t, login.Tokens.RefreshToken, pair.RefreshToken)
	assert.Equal(t, now.Add(token.RefreshTTL), pair.RefreshExpiresAt)
	assert.Equal(t, now.Add(token.AccessTTL), pair.AccessExpiresAt)
	assert.NotEmpty(t, pair.AccessToken)

	old := f.refreshRow(t, login.Tokens.RefreshToken)
	fresh := f.refreshRow(t, pair.RefreshToken)
	assert.Equal(t, old.familyID, fresh.familyID)
	require.NotNil(t, old.usedAt)
	assert.True(t, old.usedAt.Equal(now))
	assert.True(t, fresh.expiresAt.Equal(now.Add(token.RefreshTTL)))
	assert.Nil(t, fresh.usedAt)
}

func TestRefresh_ReuseRevokesFamily(t *testing.T) {
	f := newFixture(t)
	login := f.loginKakao(t, "kakao-1")
	other := f.loginKakao(t, "kakao-1") // 같은 계정의 다른 기기(다른 family)
	a := login.Tokens.RefreshToken
	b, err := f.service.Refresh(f.ctx, a)
	require.NoError(t, err)

	_, err = f.service.Refresh(f.ctx, a)
	require.ErrorIs(t, err, auth.ErrRefreshReused)

	_, err = f.service.Refresh(f.ctx, b.RefreshToken)
	require.ErrorIs(t, err, auth.ErrRefreshInvalid, "재사용 감지 뒤 family 전체가 폐기됩니다(commit됨)")
	assert.NotNil(t, f.refreshRow(t, b.RefreshToken).revokedAt)

	_, err = f.service.Refresh(f.ctx, other.Tokens.RefreshToken)
	require.NoError(t, err, "다른 family는 그대로입니다")
}

// Review Focus 1: 같은 refresh token으로 동시에 두 번 갱신하면 하나만 성공하고, 다른 하나는 재사용으로 family를 폐기합니다.
func TestRefresh_ConcurrentSameTokenOneWins(t *testing.T) {
	f := newFixture(t)
	login := f.loginKakao(t, "kakao-1")

	const workers = 2
	pairs := make([]auth.TokenPair, workers)
	errs := make([]error, workers)
	startTogether(workers, func(i int) {
		pairs[i], errs[i] = f.service.Refresh(f.ctx, login.Tokens.RefreshToken)
	})

	var winner auth.TokenPair
	successes, reused := 0, 0
	for i, err := range errs {
		switch {
		case err == nil:
			successes++
			winner = pairs[i]
		case errors.Is(err, auth.ErrRefreshReused):
			reused++
		default:
			t.Fatalf("예상하지 못한 오류: %v", err)
		}
	}
	assert.Equal(t, 1, successes)
	assert.Equal(t, 1, reused)

	_, err := f.service.Refresh(f.ctx, winner.RefreshToken)
	require.ErrorIs(t, err, auth.ErrRefreshInvalid, "성공한 쪽이 받은 새 토큰도 폐기됩니다")
}

func TestRefresh_ExpiredOrUnknownIsInvalid(t *testing.T) {
	tests := []struct {
		name    string
		prepare func(f *fixture, raw string) string
	}{
		{name: "만료", prepare: func(f *fixture, raw string) string {
			f.clk.Advance(token.RefreshTTL + time.Second)
			return raw
		}},
		{name: "만료 시각 정각", prepare: func(f *fixture, raw string) string {
			f.clk.Advance(token.RefreshTTL)
			return raw
		}},
		{name: "모르는 토큰", prepare: func(*fixture, string) string { return "unknown-token" }},
		{name: "빈 토큰", prepare: func(*fixture, string) string { return "" }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			login := f.loginKakao(t, "kakao-1")
			raw := tt.prepare(f, login.Tokens.RefreshToken)

			_, err := f.service.Refresh(f.ctx, raw)

			require.ErrorIs(t, err, auth.ErrRefreshInvalid)
			assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM refresh_tokens`), "새 토큰을 만들지 않습니다")
		})
	}
}

func TestRefresh_PendingDeletionAccountIsInvalid(t *testing.T) {
	f := newFixture(t)
	login := f.loginKakao(t, "kakao-1")
	f.markPendingDeletion(t, login.AccountID)

	_, err := f.service.Refresh(f.ctx, login.Tokens.RefreshToken)

	require.ErrorIs(t, err, auth.ErrRefreshInvalid)
	assert.Nil(t, f.refreshRow(t, login.Tokens.RefreshToken).usedAt)
}

func TestLogout_RevokesOnlyOwnFamily(t *testing.T) {
	f := newFixture(t)
	mine := f.loginKakao(t, "kakao-mine")
	mineOtherDevice := f.loginKakao(t, "kakao-mine")
	theirs := f.loginKakao(t, "kakao-theirs")

	// 남의 토큰과 모르는 토큰은 존재를 드러내지 않고 nil입니다.
	require.NoError(t, f.service.Logout(f.ctx, mine.AccountID, theirs.Tokens.RefreshToken))
	require.NoError(t, f.service.Logout(f.ctx, mine.AccountID, "unknown-token"))
	_, err := f.service.Refresh(f.ctx, theirs.Tokens.RefreshToken)
	require.NoError(t, err, "남의 토큰은 여전히 갱신 가능합니다")

	// 내 토큰은 그 family만 폐기합니다. 회전된 뒤의 토큰으로 로그아웃해도 family 전체가 폐기됩니다.
	rotated, err := f.service.Refresh(f.ctx, mine.Tokens.RefreshToken)
	require.NoError(t, err)
	require.NoError(t, f.service.Logout(f.ctx, mine.AccountID, rotated.RefreshToken))
	_, err = f.service.Refresh(f.ctx, rotated.RefreshToken)
	require.ErrorIs(t, err, auth.ErrRefreshInvalid)
	_, err = f.service.Refresh(f.ctx, mineOtherDevice.Tokens.RefreshToken)
	require.NoError(t, err, "같은 계정의 다른 family는 그대로입니다")
}

func TestRevokeAllSessions_RevokesEveryFamilyOfAccount(t *testing.T) {
	f := newFixture(t)
	first := f.loginKakao(t, "kakao-mine")
	second := f.loginKakao(t, "kakao-mine")
	theirs := f.loginKakao(t, "kakao-theirs")

	require.NoError(t, f.service.RevokeAllSessions(f.ctx, first.AccountID))

	for _, raw := range []string{first.Tokens.RefreshToken, second.Tokens.RefreshToken} {
		_, err := f.service.Refresh(f.ctx, raw)
		require.ErrorIs(t, err, auth.ErrRefreshInvalid)
	}
	_, err := f.service.Refresh(f.ctx, theirs.Tokens.RefreshToken)
	require.NoError(t, err)
}
