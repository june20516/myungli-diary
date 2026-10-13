package auth_test

import (
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

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

// appleAndKakaoAccount는 Apple로 로그인한 계정에 카카오 연결을 하나 더 붙입니다(계정 하나에 제공자 여럿, D55④).
func (f *fixture) appleAndKakaoAccount(t *testing.T) uuid.UUID {
	t.Helper()
	res := f.loginApple(t, "apple-1")
	f.exec(t, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'kakao', 'kakao-1')`,
		uuid.Must(uuid.NewV7()), res.AccountID)
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
	f.fake.SetKakaoUnlinkResponse(http.StatusServiceUnavailable, "")

	err := f.service.DisconnectProviders(f.ctx, res.AccountID)

	require.ErrorIs(t, err, provider.ErrUnavailable)
	assert.Nil(t, f.identityState(t, res.AccountID, "kakao").disconnectedAt)
}

func TestDisconnectProviders_AppleInvalidGrantCountsAsDone(t *testing.T) {
	f := newFixture(t)
	res := f.loginApple(t, "apple-1")
	f.fake.SetAppleRevokeResponse(http.StatusBadRequest, `{"error":"invalid_grant"}`)

	require.NoError(t, f.service.DisconnectProviders(f.ctx, res.AccountID))

	apple := f.identityState(t, res.AccountID, "apple")
	assert.False(t, apple.hasAppleToken, "이미 무효인 토큰은 다시 revoke할 수 없으므로 처리된 것으로 봅니다")
	assert.NotNil(t, apple.disconnectedAt)
}
