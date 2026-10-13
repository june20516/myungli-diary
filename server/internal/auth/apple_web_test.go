package auth_test

import (
	"crypto/sha256"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
)

// appleWebToken은 subject와 nonce 원문으로 웹 콜백 검증(aud=ServicesID)을 통과하는 Apple id_token을 만듭니다.
func (f *fixture) appleWebToken(subject string) string {
	return f.fake.SignIDToken(providertest.AppleClaims(subject, testNonce, provider.AppleWeb, f.clk.Now()))
}

// beginAppleWeb은 subject로 Apple 웹 로그인을 시작하고 교환 코드를 돌려줍니다.
func (f *fixture) beginAppleWeb(t *testing.T, subject string) string {
	t.Helper()
	code, err := f.service.BeginAppleWebLogin(f.ctx, f.appleWebToken(subject), providertest.AppleCode(subject))
	require.NoError(t, err)
	return code
}

// appleWebRow는 교환 코드로 찾은 apple_web_logins 행입니다.
type appleWebRow struct {
	id         uuid.UUID
	subject    string
	nonceHash  string
	sealed     []byte
	keyID      string
	clientID   string
	expiresAt  time.Time
	consumedAt *time.Time
}

func (f *fixture) appleWebRow(t *testing.T, exchangeCode string) appleWebRow {
	t.Helper()
	hash := sha256.Sum256([]byte(exchangeCode))
	var r appleWebRow
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT id, subject, nonce_hash, apple_refresh_token, apple_token_key_id, apple_client_id, expires_at, consumed_at
		 FROM apple_web_logins WHERE exchange_hash = $1`, hash[:]).
		Scan(&r.id, &r.subject, &r.nonceHash, &r.sealed, &r.keyID, &r.clientID, &r.expiresAt, &r.consumedAt))
	return r
}

func TestBeginAppleWebLogin_StoresSealedTokenAndReturnsCode(t *testing.T) {
	f := newFixture(t)

	code := f.beginAppleWeb(t, "apple-1")

	assert.Len(t, code, 43, "256비트 난수의 base64url(패딩 없음)은 43자입니다")
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM apple_web_logins`))
	row := f.appleWebRow(t, code)
	assert.Equal(t, "apple-1", row.subject)
	assert.Equal(t, providertest.HashNonce(testNonce), row.nonceHash, "id_token의 nonce claim을 그대로 저장합니다")
	assert.Equal(t, providertest.AppleServicesID, row.clientID)
	assert.True(t, row.expiresAt.Equal(testNow.Add(auth.AppleWebExchangeTTL)))
	assert.Nil(t, row.consumedAt)
	assert.NotContains(t, string(row.sealed), providertest.AppleRefreshToken)
	plain, err := f.box.Open(row.sealed, row.keyID, row.id[:])
	require.NoError(t, err, "aad는 행 id입니다")
	assert.Equal(t, providertest.AppleRefreshToken, string(plain))

	// 로그인은 아직 끝나지 않았으므로 계정을 만들지 않습니다.
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM accounts`))
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM refresh_tokens`))

	// 교환은 web client(ServicesID)로 했습니다.
	requests := f.fake.AppleTokenRequests()
	require.Len(t, requests, 1)
	assert.Equal(t, providertest.AppleServicesID, requests[0].Form.Get("client_id"))
}

func TestBeginAppleWebLogin_ProviderErrorsMapToSentinels(t *testing.T) {
	tests := []struct {
		name    string
		prepare func(f *fixture)
		idToken func(f *fixture) string
		want    error
	}{
		{
			name: "native aud의 id_token",
			idToken: func(f *fixture) string {
				return f.fake.SignIDToken(providertest.AppleClaims("apple-1", testNonce, provider.AppleNative, f.clk.Now()))
			},
			want: auth.ErrProviderTokenInvalid,
		},
		{
			name: "nonce claim이 SHA-256 소문자 hex가 아님",
			idToken: func(f *fixture) string {
				claims := providertest.AppleClaims("apple-1", testNonce, provider.AppleWeb, f.clk.Now())
				claims["nonce"] = "not-a-hex-nonce"
				return f.fake.SignIDToken(claims)
			},
			want: auth.ErrProviderTokenInvalid,
		},
		{
			name:    "code 교환 invalid_grant",
			prepare: func(f *fixture) { f.fake.SetAppleTokenResponse(http.StatusBadRequest, `{"error":"invalid_grant"}`) },
			want:    auth.ErrProviderTokenInvalid,
		},
		{
			name:    "code 교환 Apple 장애",
			prepare: func(f *fixture) { f.fake.SetAppleTokenResponse(http.StatusServiceUnavailable, "") },
			want:    auth.ErrProviderUnavailable,
		},
		{
			name:    "JWKS 장애",
			prepare: func(f *fixture) { f.fake.SetJWKSStatus(http.StatusInternalServerError) },
			want:    auth.ErrProviderUnavailable,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			if tt.prepare != nil {
				tt.prepare(f)
			}
			idToken := f.appleWebToken("apple-1")
			if tt.idToken != nil {
				idToken = tt.idToken(f)
			}

			code, err := f.service.BeginAppleWebLogin(f.ctx, idToken, providertest.AppleCode("apple-1"))

			require.ErrorIs(t, err, tt.want)
			assert.NotErrorIs(t, err, provider.ErrTokenInvalid, "제공자 오류 원인을 응답 경로로 넘기지 않습니다")
			assert.Empty(t, code)
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM apple_web_logins`))
		})
	}
}

func TestCompleteAppleWebLogin_CreatesAccountAndConsumes(t *testing.T) {
	f := newFixture(t)
	code := f.beginAppleWeb(t, "apple-1")

	res, err := f.service.CompleteAppleWebLogin(f.ctx, code, testNonce)

	require.NoError(t, err)
	assert.True(t, res.IsNewAccount)
	assert.False(t, res.RestoredFromDeletion)
	assert.NotEmpty(t, res.Tokens.AccessToken)
	assert.Equal(t, res.AccountID, f.refreshRowAccount(t, res.Tokens.RefreshToken))

	var (
		identityID uuid.UUID
		sealed     []byte
		keyID      string
		clientID   string
	)
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT id, apple_refresh_token, apple_token_key_id, apple_client_id FROM auth_identities
		 WHERE account_id = $1 AND provider = 'apple' AND subject = 'apple-1'`,
		res.AccountID).Scan(&identityID, &sealed, &keyID, &clientID))
	plain, err := f.box.Open(sealed, keyID, identityID[:])
	require.NoError(t, err, "identity에는 identity id를 aad로 다시 암호화해 저장합니다")
	assert.Equal(t, providertest.AppleRefreshToken, string(plain))
	assert.Equal(t, providertest.AppleServicesID, clientID, "revoke에 쓸 client_id는 교환에 쓴 ServicesID입니다")

	row := f.appleWebRow(t, code)
	require.NotNil(t, row.consumedAt)
	assert.True(t, row.consumedAt.Equal(testNow))
}

// refreshRowAccount는 refresh token 원문의 계정 id를 읽습니다.
func (f *fixture) refreshRowAccount(t *testing.T, raw string) uuid.UUID {
	t.Helper()
	hash := sha256.Sum256([]byte(raw))
	var id uuid.UUID
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT account_id FROM refresh_tokens WHERE token_hash = $1`, hash[:]).Scan(&id))
	return id
}

func TestCompleteAppleWebLogin_SecondUseIsInvalid(t *testing.T) {
	f := newFixture(t)
	code := f.beginAppleWeb(t, "apple-1")
	_, err := f.service.CompleteAppleWebLogin(f.ctx, code, testNonce)
	require.NoError(t, err)

	_, err = f.service.CompleteAppleWebLogin(f.ctx, code, testNonce)

	require.ErrorIs(t, err, auth.ErrExchangeInvalid)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM refresh_tokens`), "두 번째 사용은 토큰을 발급하지 않습니다")
}

func TestCompleteAppleWebLogin_UnknownCodeIsInvalid(t *testing.T) {
	f := newFixture(t)
	f.beginAppleWeb(t, "apple-1")

	_, err := f.service.CompleteAppleWebLogin(f.ctx, "unknown-exchange-code", testNonce)

	require.ErrorIs(t, err, auth.ErrExchangeInvalid)
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM accounts`))
}

// Review Focus 1: nonce가 틀려도 교환 코드를 소진하지 않습니다. 코드를 가로챈 쪽이 정상 사용자의 로그인을 망칠 수 없게 합니다.
func TestCompleteAppleWebLogin_WrongNonceDoesNotConsume(t *testing.T) {
	f := newFixture(t)
	code := f.beginAppleWeb(t, "apple-1")

	_, err := f.service.CompleteAppleWebLogin(f.ctx, code, "wrong-raw-nonce")

	require.ErrorIs(t, err, auth.ErrExchangeInvalid)
	assert.Nil(t, f.appleWebRow(t, code).consumedAt)
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM accounts`))

	res, err := f.service.CompleteAppleWebLogin(f.ctx, code, testNonce)
	require.NoError(t, err, "맞는 nonce로 다시 시도하면 성공합니다")
	assert.True(t, res.IsNewAccount)
	assert.NotNil(t, f.appleWebRow(t, code).consumedAt)
}

func TestCompleteAppleWebLogin_ExpiredIsInvalid(t *testing.T) {
	tests := []struct {
		name    string
		elapsed time.Duration
		wantErr error
	}{
		{name: "만료 직전", elapsed: auth.AppleWebExchangeTTL - time.Second},
		{name: "만료 시각과 같음", elapsed: auth.AppleWebExchangeTTL, wantErr: auth.ErrExchangeInvalid},
		{name: "만료 뒤", elapsed: auth.AppleWebExchangeTTL + time.Second, wantErr: auth.ErrExchangeInvalid},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			code := f.beginAppleWeb(t, "apple-1")
			f.clk.Advance(tt.elapsed)

			_, err := f.service.CompleteAppleWebLogin(f.ctx, code, testNonce)

			if tt.wantErr != nil {
				require.ErrorIs(t, err, tt.wantErr)
				assert.Nil(t, f.appleWebRow(t, code).consumedAt)
				assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM accounts`))
				return
			}
			require.NoError(t, err)
			assert.NotNil(t, f.appleWebRow(t, code).consumedAt)
		})
	}
}

// Review Focus 2: 같은 교환 코드로 동시에 완료하면 하나만 성공합니다.
func TestCompleteAppleWebLogin_ConcurrentSameCodeOneWins(t *testing.T) {
	f := newFixture(t)
	code := f.beginAppleWeb(t, "apple-race")
	const workers = 2

	errs := make([]error, workers)
	startTogether(workers, func(i int) {
		_, errs[i] = f.service.CompleteAppleWebLogin(f.ctx, code, testNonce)
	})

	var succeeded, invalid int
	for _, err := range errs {
		switch {
		case err == nil:
			succeeded++
		case assert.ErrorIs(t, err, auth.ErrExchangeInvalid):
			invalid++
		}
	}
	assert.Equal(t, 1, succeeded)
	assert.Equal(t, 1, invalid)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM accounts`))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM refresh_tokens`))
}

// Review Focus 3: 완료 트랜잭션이 실패하면 교환 코드가 소진되지 않아 다시 시도할 수 있습니다.
// 교환한 Apple 토큰은 그 행에 남아 있으므로 revoke하지 않습니다.
func TestCompleteAppleWebLogin_TxFailureKeepsCodeUsable(t *testing.T) {
	f := newFixture(t)
	code := f.beginAppleWeb(t, "apple-1")
	f.failRefreshTokenInserts(t)

	_, err := f.service.CompleteAppleWebLogin(f.ctx, code, testNonce)

	require.ErrorContains(t, err, "test: refresh token insert 실패")
	assert.NotErrorIs(t, err, auth.ErrExchangeInvalid)
	assert.Nil(t, f.appleWebRow(t, code).consumedAt)
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM accounts`))
	assert.Empty(t, f.fake.AppleRevokeRequests())

	f.exec(t, `DROP TRIGGER test_fail_refresh_insert ON refresh_tokens`)
	res, err := f.service.CompleteAppleWebLogin(f.ctx, code, testNonce)
	require.NoError(t, err)
	assert.True(t, res.IsNewAccount)
	assert.NotNil(t, f.appleWebRow(t, code).consumedAt)
}

func TestCompleteAppleWebLogin_RestoresPendingDeletion(t *testing.T) {
	f := newFixture(t)
	first := f.loginApple(t, "apple-1")
	f.markPendingDeletion(t, first.AccountID)
	f.fake.SetAppleRefreshToken("web-refresh")
	code := f.beginAppleWeb(t, "apple-1")

	res, err := f.service.CompleteAppleWebLogin(f.ctx, code, testNonce)

	require.NoError(t, err)
	assert.Equal(t, first.AccountID, res.AccountID)
	assert.False(t, res.IsNewAccount)
	assert.True(t, res.RestoredFromDeletion)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM accounts WHERE id = $1 AND status = 'active'`, first.AccountID))
	assert.NotNil(t, f.refreshRow(t, first.Tokens.RefreshToken).revokedAt, "복구 전 세션은 폐기합니다")

	var (
		identityID uuid.UUID
		sealed     []byte
		keyID      string
		clientID   string
	)
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT id, apple_refresh_token, apple_token_key_id, apple_client_id FROM auth_identities WHERE account_id = $1`,
		first.AccountID).Scan(&identityID, &sealed, &keyID, &clientID))
	plain, err := f.box.Open(sealed, keyID, identityID[:])
	require.NoError(t, err)
	assert.Equal(t, "web-refresh", string(plain), "웹 로그인에서 받은 토큰으로 바꿔 저장합니다")
	assert.Equal(t, providertest.AppleServicesID, clientID)
}
