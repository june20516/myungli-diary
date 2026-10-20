package auth_test

import (
	"context"
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

// identityState는 auth_identities 한 행의 연결 해제 관련 열입니다.
type identityState struct {
	hasAppleToken  bool
	disconnectedAt *time.Time
}

func (f *fixture) identityState(t *testing.T, accountID uuid.UUID, prov string) identityState {
	t.Helper()
	var s identityState
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT apple_refresh_token IS NOT NULL OR apple_token_key_id IS NOT NULL OR apple_client_id IS NOT NULL, provider_disconnected_at
		 FROM auth_identities WHERE account_id = $1 AND provider = $2`, accountID, prov).Scan(&s.hasAppleToken, &s.disconnectedAt))
	return s
}

// requestDeletion은 계정만 삭제 대기로 바꿉니다(DELETE /v1/me가 commit한 직후, 연결 해제 전 상태).
func (f *fixture) requestDeletion(t *testing.T, accountID uuid.UUID) {
	t.Helper()
	f.exec(t, `UPDATE accounts SET status = 'pending_deletion', deletion_requested_at = $2 WHERE id = $1`, accountID, f.clk.Now())
}

// appleAndKakaoAccount는 Apple로 로그인한 계정에 카카오 연결을 하나 더 붙이고 삭제 대기로 바꿉니다(계정 하나에 제공자 여럿, D55④).
func (f *fixture) appleAndKakaoAccount(t *testing.T) uuid.UUID {
	t.Helper()
	res := f.loginApple(t, "apple-1")
	f.exec(t, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'kakao-1')`,
		uuid.Must(uuid.NewV7()), res.AccountID)
	f.requestDeletion(t, res.AccountID)
	return res.AccountID
}

func TestDisconnectProviders_RevokesAppleAndUnlinksKakao(t *testing.T) {
	f := newFixture(t)
	accountID := f.appleAndKakaoAccount(t)
	f.clk.Advance(time.Minute)

	require.NoError(t, f.service.DisconnectProviders(f.ctx, accountID))

	revokes := f.fake.AppleRevokeRequests()
	require.Len(t, revokes, 1)
	assert.Equal(t, providertest.AppleRefreshToken, revokes[0].Form.Get("token"), "복호화한 토큰으로 revoke합니다")
	assert.Equal(t, providertest.AppleBundleID, revokes[0].Form.Get("client_id"))

	unlinks := f.fake.KakaoUnlinkRequests()
	require.Len(t, unlinks, 1)
	assert.Equal(t, "kakao-1", unlinks[0].Form.Get("target_id"))

	now := testNow.Add(time.Minute)
	for _, prov := range []string{"apple", "kakao"} {
		s := f.identityState(t, accountID, prov)
		assert.False(t, s.hasAppleToken, prov)
		require.NotNil(t, s.disconnectedAt, prov)
		assert.True(t, s.disconnectedAt.Equal(now), prov)
	}

	// 이미 처리된 연결은 다시 부르지 않습니다.
	require.NoError(t, f.service.DisconnectProviders(f.ctx, accountID))
	assert.Len(t, f.fake.AppleRevokeRequests(), 1)
	assert.Len(t, f.fake.KakaoUnlinkRequests(), 1)
}

// 삭제 대기가 아닌(active) 계정에는 외부 해제 호출을 하지 않고 기록도 남기지 않습니다.
func TestDisconnectProviders_ActiveAccountCallsNothing(t *testing.T) {
	f := newFixture(t)
	res := f.loginApple(t, "apple-1")
	f.exec(t, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'kakao-1')`,
		uuid.Must(uuid.NewV7()), res.AccountID)

	require.NoError(t, f.service.DisconnectProviders(f.ctx, res.AccountID))

	assert.Empty(t, f.fake.AppleRevokeRequests())
	assert.Empty(t, f.fake.KakaoUnlinkRequests())
	for _, prov := range []string{"apple", "kakao"} {
		assert.Nil(t, f.identityState(t, res.AccountID, prov).disconnectedAt, prov)
	}
	assert.True(t, f.identityState(t, res.AccountID, "apple").hasAppleToken)
}

func TestDisconnectProviders_PartialFailureKeepsUndone(t *testing.T) {
	f := newFixture(t)
	accountID := f.appleAndKakaoAccount(t)
	f.fake.SetAppleRevokeResponse(http.StatusInternalServerError, "")

	err := f.service.DisconnectProviders(f.ctx, accountID)

	require.ErrorIs(t, err, provider.ErrUnavailable)
	apple := f.identityState(t, accountID, "apple")
	assert.True(t, apple.hasAppleToken, "실패한 Apple 연결은 토큰을 남겨 다시 시도할 수 있게 합니다")
	assert.Nil(t, apple.disconnectedAt)
	assert.NotNil(t, f.identityState(t, accountID, "kakao").disconnectedAt, "Apple이 실패해도 카카오는 처리합니다")

	f.fake.SetAppleRevokeResponse(http.StatusOK, "")
	require.NoError(t, f.service.DisconnectProviders(f.ctx, accountID))
	apple = f.identityState(t, accountID, "apple")
	assert.False(t, apple.hasAppleToken)
	assert.NotNil(t, apple.disconnectedAt)
	assert.Len(t, f.fake.AppleRevokeRequests(), 2)
	assert.Len(t, f.fake.KakaoUnlinkRequests(), 1, "처리된 카카오는 다시 부르지 않습니다")
}

func TestDisconnectProviders_KakaoFailureIsReported(t *testing.T) {
	f := newFixture(t)
	res := f.loginKakao(t, "kakao-1")
	f.requestDeletion(t, res.AccountID)
	f.fake.SetKakaoUnlinkResponse(http.StatusServiceUnavailable, "")

	err := f.service.DisconnectProviders(f.ctx, res.AccountID)

	require.ErrorIs(t, err, provider.ErrUnavailable)
	assert.Nil(t, f.identityState(t, res.AccountID, "kakao").disconnectedAt)
}

func TestDisconnectProviders_AppleInvalidGrantCountsAsDone(t *testing.T) {
	f := newFixture(t)
	res := f.loginApple(t, "apple-1")
	f.requestDeletion(t, res.AccountID)
	f.fake.SetAppleRevokeResponse(http.StatusBadRequest, `{"error":"invalid_grant"}`)

	require.NoError(t, f.service.DisconnectProviders(f.ctx, res.AccountID))

	apple := f.identityState(t, res.AccountID, "apple")
	assert.False(t, apple.hasAppleToken, "이미 무효인 토큰은 다시 revoke할 수 없으므로 처리된 것으로 봅니다")
	assert.NotNil(t, apple.disconnectedAt)
}

// hookedApple은 Revoke가 끝난 직후 hook을 불러, 제공자 호출과 해제 기록 사이에 다른 요청이 끼어든 상황을 만듭니다.
type hookedApple struct {
	auth.AppleClient
	afterRevoke func()
}

func (h hookedApple) Revoke(ctx context.Context, refreshToken, clientID string) error {
	err := h.AppleClient.Revoke(ctx, refreshToken, clientID)
	h.afterRevoke()
	return err
}

// 연결 해제 도중 복구 로그인이 끼어들면, 복구 로그인이 새로 저장한 Apple 연결을 '해제됨'으로 덮지 않습니다.
func TestDisconnectProviders_RestoredDuringRevokeKeepsNewConnection(t *testing.T) {
	var f *fixture
	restore := func() {
		// 복구 로그인과 같은 결과: 계정이 active로 돌아오고 새 Apple 토큰이 저장됩니다.
		idToken := f.fake.SignIDToken(providertest.AppleClaims("apple-1", testNonce, provider.AppleNative, f.clk.Now()))
		res, err := f.service.LoginApple(f.ctx, idToken, providertest.AppleCode("apple-1"), testNonce)
		require.NoError(t, err)
		require.True(t, res.RestoredFromDeletion)
	}
	revokeCalls := 0
	f = newFixture(t, func(deps *auth.ServiceDeps) {
		deps.Apple = hookedApple{AppleClient: deps.Apple, afterRevoke: func() {
			revokeCalls++
			if revokeCalls == 1 {
				restore()
			}
		}}
	})
	res := f.loginApple(t, "apple-1")
	f.requestDeletion(t, res.AccountID)
	f.fake.SetAppleRefreshToken("restored-refresh")

	require.NoError(t, f.service.DisconnectProviders(f.ctx, res.AccountID))

	apple := f.identityState(t, res.AccountID, "apple")
	assert.True(t, apple.hasAppleToken, "복구 로그인이 저장한 새 토큰을 지우지 않습니다")
	assert.Nil(t, apple.disconnectedAt)
	var (
		identityID uuid.UUID
		sealed     []byte
		keyID      string
	)
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT id, apple_refresh_token, apple_token_key_id FROM auth_identities WHERE account_id = $1`, res.AccountID).Scan(&identityID, &sealed, &keyID))
	plain, err := f.box.Open(sealed, keyID, identityID[:])
	require.NoError(t, err)
	assert.Equal(t, "restored-refresh", string(plain))
}

// staging 테스트 로그인(S24)의 test 연결은 외부 제공자가 없으므로 호출 없이 해제된 것으로 기록합니다.
// 기록하지 않으면 계정 삭제 뒤 retention이 같은 연결을 끝없이 다시 시도합니다.
func TestDisconnectProviders_TestProviderIsRecordedWithoutCalls(t *testing.T) {
	f := newFixture(t)
	accountID := uuid.Must(uuid.NewV7())
	f.exec(t, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', $2)`, accountID, f.clk.Now())
	f.exec(t, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'test', 'e2e01')`,
		uuid.Must(uuid.NewV7()), accountID)
	f.requestDeletion(t, accountID)

	require.NoError(t, f.service.DisconnectProviders(f.ctx, accountID))

	assert.Empty(t, f.fake.AppleRevokeRequests())
	assert.Empty(t, f.fake.KakaoUnlinkRequests())
	assert.NotNil(t, f.identityState(t, accountID, "test").disconnectedAt)
}

// auth_identities.provider는 kakao·apple·test만 받고, test 연결에는 Apple 토큰 열이 없습니다(00011, spec §13.2).
func TestAuthIdentities_ProviderCheckAllowsTest(t *testing.T) {
	f := newFixture(t)
	accountID := uuid.Must(uuid.NewV7())
	f.exec(t, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', $2)`, accountID, f.clk.Now())

	insert := func(prov, subject string, withApple bool) error {
		var token any
		var keyID, clientID any
		if withApple {
			token, keyID, clientID = []byte{1}, "b1", "client"
		}
		_, err := f.pool.Exec(f.ctx,
			`INSERT INTO auth_identities (id, account_id, provider, subject, apple_refresh_token, apple_token_key_id, apple_client_id)
			 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			uuid.Must(uuid.NewV7()), accountID, prov, subject, token, keyID, clientID)
		return err
	}
	require.NoError(t, insert("test", "e2e01", false))
	require.Error(t, insert("google", "g-1", false), "목록 밖 제공자는 거절합니다")
	require.Error(t, insert("test", "e2e02", true), "test 연결에는 Apple 토큰이 없습니다")
}
