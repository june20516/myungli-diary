package auth_test

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
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

// newFixture는 fixture를 만듭니다. opts로 서비스 의존성을 바꿀 수 있습니다(예: 제공자 호출을 감싸 끼어들기).
func newFixture(t *testing.T, opts ...func(*auth.ServiceDeps)) *fixture {
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
	deps := auth.ServiceDeps{
		Kakao:       kakao,
		Apple:       fake.NewApple(t, clk),
		KakaoUnlink: kakao,
		Access:      access,
		Box:         box,
		Clock:       clk,
	}
	for _, opt := range opts {
		opt(&deps)
	}
	service := auth.NewService(pool, deps)
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
	res, err := f.service.LoginApple(f.ctx, idToken, providertest.AppleCode(subject), testNonce, provider.AppleNative)
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
	// 삭제 요청 뒤 세션 폐기가 실패했더라도(markPendingDeletion은 토큰을 건드리지 않음) 복구가 이전 세션을 되살리지 않습니다.
	_, err := f.service.Refresh(f.ctx, first.Tokens.RefreshToken)
	require.ErrorIs(t, err, auth.ErrRefreshInvalid, "복구 전에 받은 refresh token")
	_, err = f.service.Refresh(f.ctx, res.Tokens.RefreshToken)
	require.NoError(t, err, "복구 로그인이 새로 받은 refresh token")
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
	f.fake.SetAppleRefreshToken("second-refresh")
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

			_, err := f.service.LoginApple(f.ctx, idToken, providertest.AppleCode("apple-1"), testNonce, provider.AppleNative)

			require.ErrorIs(t, err, tt.want)
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM accounts`))
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM auth_identities`))
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM refresh_tokens`))
		})
	}
}

// 교환 응답 id_token의 sub가 로그인 id_token과 다르면(다른 사용자의 code) 로그인을 거절하고 아무것도 남기지 않습니다.
func TestLoginApple_ExchangedSubjectMismatchCreatesNothing(t *testing.T) {
	f := newFixture(t)
	idToken := f.fake.SignIDToken(providertest.AppleClaims("apple-1", testNonce, provider.AppleNative, f.clk.Now()))

	_, err := f.service.LoginApple(f.ctx, idToken, providertest.AppleCode("apple-2"), testNonce, provider.AppleNative)

	require.ErrorIs(t, err, auth.ErrProviderTokenInvalid)
	assert.NotErrorIs(t, err, provider.ErrTokenInvalid, "제공자 오류 원인을 응답 경로로 넘기지 않습니다")
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM accounts`))
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM auth_identities`))
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM refresh_tokens`))
}

// 트랜잭션이 실패해도 교환한 토큰을 revoke하지 않습니다. revoke는 사용자의 앱 승인 전체를 끊기 때문입니다.
func TestLoginApple_FailedTransactionDoesNotRevoke(t *testing.T) {
	f := newFixture(t)
	first := f.loginApple(t, "apple-1")
	f.exec(t, `UPDATE accounts SET status = 'deleted', deletion_requested_at = $2, anonymized_at = $2 WHERE id = $1`, first.AccountID, testNow)
	f.fake.SetAppleRefreshToken("unsaved-refresh")
	idToken := f.fake.SignIDToken(providertest.AppleClaims("apple-1", testNonce, provider.AppleNative, f.clk.Now()))

	_, err := f.service.LoginApple(f.ctx, idToken, providertest.AppleCode("apple-1"), testNonce, provider.AppleNative)

	require.ErrorContains(t, err, "익명화된 계정", "원래 오류(트랜잭션 실패)를 그대로 돌려줍니다")
	assert.NotErrorIs(t, err, auth.ErrProviderTokenInvalid)
	assert.NotErrorIs(t, err, auth.ErrProviderUnavailable)
	assert.Empty(t, f.fake.AppleRevokeRequests())
}

func TestLoginApple_SuccessDoesNotRevoke(t *testing.T) {
	f := newFixture(t)

	f.loginApple(t, "apple-1")

	assert.Empty(t, f.fake.AppleRevokeRequests())
}

// 시계에 마이크로초 미만 값이 있어도 응답의 refresh 만료 시각은 DB에 저장한 값과 같습니다.
func TestLogin_RefreshExpiresAtMatchesDB(t *testing.T) {
	f := newFixture(t)
	f.clk.Advance(1234567891 * time.Nanosecond)

	res := f.loginKakao(t, "kakao-1")

	stored := f.refreshRow(t, res.Tokens.RefreshToken).expiresAt
	assert.True(t, stored.Equal(res.Tokens.RefreshExpiresAt), "DB %v, 응답 %v", stored, res.Tokens.RefreshExpiresAt)
	exp := f.clk.Now().Add(token.AccessTTL).Truncate(time.Second)
	assert.True(t, exp.Equal(res.Tokens.AccessExpiresAt), "access 만료는 초 단위입니다")
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
	f.clk.Advance(auth.RefreshReuseGrace + time.Second) // 유예 시간 밖

	_, err = f.service.Refresh(f.ctx, a)
	require.ErrorIs(t, err, auth.ErrRefreshReused)

	_, err = f.service.Refresh(f.ctx, b.RefreshToken)
	require.ErrorIs(t, err, auth.ErrRefreshInvalid, "재사용 감지 뒤 family 전체가 폐기됩니다(commit됨)")
	assert.NotNil(t, f.refreshRow(t, b.RefreshToken).revokedAt)

	_, err = f.service.Refresh(f.ctx, other.Tokens.RefreshToken)
	require.NoError(t, err, "다른 family는 그대로입니다")
}

// liveTokens는 family에서 아직 쓸 수 있는(미사용·미폐기) refresh token 수를 셉니다.
func (f *fixture) liveTokens(t *testing.T, familyID uuid.UUID) int {
	t.Helper()
	return f.count(t, `SELECT count(*) FROM refresh_tokens WHERE family_id = $1 AND used_at IS NULL AND revoked_at IS NULL`, familyID)
}

func TestRefresh_RetryWithinGraceIssuesNewToken(t *testing.T) {
	f := newFixture(t)
	login := f.loginKakao(t, "kakao-1")
	a := login.Tokens.RefreshToken
	b, err := f.service.Refresh(f.ctx, a)
	require.NoError(t, err)
	usedAt := *f.refreshRow(t, a).usedAt
	f.clk.Advance(10 * time.Second)

	// 응답(b)을 받지 못한 앱이 a로 다시 갱신합니다.
	c, err := f.service.Refresh(f.ctx, a)

	require.NoError(t, err, "유예 시간 안의 재전송은 성공합니다")
	assert.NotEqual(t, b.RefreshToken, c.RefreshToken)
	now := testNow.Add(10 * time.Second)
	assert.Equal(t, now.Add(token.RefreshTTL), c.RefreshExpiresAt)
	assert.Equal(t, now.Add(token.AccessTTL), c.AccessExpiresAt)
	assert.NotEmpty(t, c.AccessToken)

	family := f.refreshRow(t, a).familyID
	assert.Equal(t, family, f.refreshRow(t, c.RefreshToken).familyID, "같은 family에서 발급합니다")
	assert.True(t, f.refreshRow(t, a).usedAt.Equal(usedAt), "a의 첫 사용 시각은 바뀌지 않습니다")
	assert.Equal(t, 1, f.count(t,
		`SELECT count(*) FROM refresh_tokens a JOIN refresh_tokens c ON c.id = a.replaced_by_id
		 WHERE a.token_hash = $1 AND c.token_hash = $2`,
		token.HashRefreshToken(a), token.HashRefreshToken(c.RefreshToken)), "a의 다음 token은 c입니다")

	// b를 다시 보내면 family가 폐기되므로(TestRefresh_GraceReplacedTokenReuseRevokesFamily) 여기서는 DB로 확인합니다.
	assert.NotNil(t, f.refreshRow(t, b.RefreshToken).revokedAt, "유실된 응답의 token(b)은 폐기됩니다")
	_, err = f.service.Refresh(f.ctx, c.RefreshToken)
	require.NoError(t, err, "c는 갱신할 수 있습니다")
	assert.Equal(t, 1, f.liveTokens(t, family))
}

func TestRefresh_GraceBoundary(t *testing.T) {
	tests := []struct {
		name    string
		elapsed time.Duration
		wantErr error
	}{
		{name: "정확히 유예 시간이면 유예", elapsed: auth.RefreshReuseGrace},
		{name: "유예 시간을 1ns 넘으면 재사용", elapsed: auth.RefreshReuseGrace + time.Nanosecond, wantErr: auth.ErrRefreshReused},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			login := f.loginKakao(t, "kakao-1")
			a := login.Tokens.RefreshToken
			b, err := f.service.Refresh(f.ctx, a)
			require.NoError(t, err)
			f.clk.Advance(tt.elapsed)

			_, err = f.service.Refresh(f.ctx, a)

			if tt.wantErr == nil {
				require.NoError(t, err)
				return
			}
			require.ErrorIs(t, err, tt.wantErr)
			_, err = f.service.Refresh(f.ctx, b.RefreshToken)
			require.ErrorIs(t, err, auth.ErrRefreshInvalid, "family가 폐기되어 b도 무효입니다")
			assert.Equal(t, 0, f.liveTokens(t, f.refreshRow(t, a).familyID))
		})
	}
}

func TestRefresh_ReuseAfterSuccessorUsedRevokesFamily(t *testing.T) {
	f := newFixture(t)
	login := f.loginKakao(t, "kakao-1")
	a := login.Tokens.RefreshToken
	b, err := f.service.Refresh(f.ctx, a)
	require.NoError(t, err)
	c, err := f.service.Refresh(f.ctx, b.RefreshToken)
	require.NoError(t, err)
	f.clk.Advance(5 * time.Second)

	// b가 이미 쓰였으므로 a의 재전송은 응답 유실 재시도가 아닙니다.
	_, err = f.service.Refresh(f.ctx, a)
	require.ErrorIs(t, err, auth.ErrRefreshReused)

	_, err = f.service.Refresh(f.ctx, c.RefreshToken)
	require.ErrorIs(t, err, auth.ErrRefreshInvalid, "family가 폐기되어 c도 무효입니다")
}

func TestRefresh_GraceDoesNotExtendWindow(t *testing.T) {
	f := newFixture(t)
	login := f.loginKakao(t, "kakao-1")
	a := login.Tokens.RefreshToken
	_, err := f.service.Refresh(f.ctx, a)
	require.NoError(t, err)

	f.clk.Advance(20 * time.Second)
	c, err := f.service.Refresh(f.ctx, a)
	require.NoError(t, err, "첫 사용 뒤 20초: 유예")

	f.clk.Advance(20 * time.Second)
	_, err = f.service.Refresh(f.ctx, a)
	require.ErrorIs(t, err, auth.ErrRefreshReused, "첫 사용 뒤 40초: 유예 창은 다시 열리지 않습니다")
	_, err = f.service.Refresh(f.ctx, c.RefreshToken)
	require.ErrorIs(t, err, auth.ErrRefreshInvalid, "family가 폐기되어 c도 무효입니다")
}

func TestRefresh_GraceReplacedTokenReuseRevokesFamily(t *testing.T) {
	f := newFixture(t)
	login := f.loginKakao(t, "kakao-1")
	a := login.Tokens.RefreshToken
	b, err := f.service.Refresh(f.ctx, a)
	require.NoError(t, err)
	f.clk.Advance(10 * time.Second)
	c, err := f.service.Refresh(f.ctx, a)
	require.NoError(t, err, "유예로 c를 발급하고 b를 폐기합니다")

	// 유예로 대체된 b가 다시 오면, b를 받은 쪽이 따로 있었다는 뜻이므로 탈취로 봅니다.
	_, err = f.service.Refresh(f.ctx, b.RefreshToken)

	require.ErrorIs(t, err, auth.ErrRefreshReused)
	_, err = f.service.Refresh(f.ctx, c.RefreshToken)
	require.ErrorIs(t, err, auth.ErrRefreshInvalid, "family가 폐기되어 c도 무효입니다")
	assert.Equal(t, 0, f.liveTokens(t, f.refreshRow(t, a).familyID))
}

func TestRefresh_LoggedOutTokenIsInvalid(t *testing.T) {
	f := newFixture(t)
	login := f.loginKakao(t, "kakao-1")
	require.NoError(t, f.service.Logout(f.ctx, login.AccountID, login.Tokens.RefreshToken))

	_, err := f.service.Refresh(f.ctx, login.Tokens.RefreshToken)

	require.ErrorIs(t, err, auth.ErrRefreshInvalid, "family 전체가 폐기된 token은 재사용이 아니라 무효입니다")
}

// Review Focus 1: 같은 refresh token으로 동시에 여러 번 갱신하면 모두 성공합니다.
// 하나는 정상 갱신, 나머지는 행 잠금을 기다린 뒤 차례로 유예 처리(앞서 발급한 token 폐기 후 새로 발급)됩니다.
// 그래서 family에 살아 있는 token은 마지막에 끝난 쪽 하나뿐이고, 폐기된 token이 다시 오면 탈취로 봅니다.
func TestRefresh_ConcurrentSameTokenAllSucceed(t *testing.T) {
	tests := []struct {
		name    string
		workers int
	}{
		{name: "2회", workers: 2},
		{name: "3회", workers: 3},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			login := f.loginKakao(t, "kakao-1")
			family := f.refreshRow(t, login.Tokens.RefreshToken).familyID

			pairs := make([]auth.TokenPair, tt.workers)
			errs := make([]error, tt.workers)
			startTogether(tt.workers, func(i int) {
				pairs[i], errs[i] = f.service.Refresh(f.ctx, login.Tokens.RefreshToken)
			})

			for i, err := range errs {
				require.NoError(t, err, "요청 %d", i)
			}
			require.Equal(t, 1, f.liveTokens(t, family), "family에 살아 있는 token은 하나입니다")

			// 어느 쪽이 마지막에 끝났는지는 DB에 살아 있는 token으로 알아냅니다.
			var live, revoked []auth.TokenPair
			for _, pair := range pairs {
				if f.refreshRow(t, pair.RefreshToken).revokedAt == nil {
					live = append(live, pair)
				} else {
					revoked = append(revoked, pair)
				}
			}
			require.Len(t, live, 1)
			_, err := f.service.Refresh(f.ctx, revoked[0].RefreshToken)
			require.ErrorIs(t, err, auth.ErrRefreshReused, "유예로 대체된 token이 다시 오면 탈취로 봅니다")
			_, err = f.service.Refresh(f.ctx, live[0].RefreshToken)
			require.ErrorIs(t, err, auth.ErrRefreshInvalid, "family가 폐기되어 남은 token도 무효입니다")
		})
	}
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
