package cli

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
)

// loginAgreed는 로그인한 뒤 동의까지 마치고 access token을 돌려줍니다.
func (e *flowEnv) loginAgreed(login flowResponse) string {
	e.t.Helper()
	require.Equal(e.t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	access, _ := login.tokens(e.t)
	consent := e.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	require.Equal(e.t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)
	return access
}

// providersOf는 연결 목록 응답의 items[].provider를 순서대로 꺼냅니다.
func providersOf(t *testing.T, r flowResponse) []string {
	t.Helper()
	items, ok := r.body["items"].([]any)
	require.True(t, ok, "items: %v", r.body)
	providers := make([]string, 0, len(items))
	for _, item := range items {
		entry, ok := item.(map[string]any)
		require.True(t, ok, "item: %v", item)
		name, _ := entry["provider"].(string)
		providers = append(providers, name)
	}
	return providers
}

func TestIdentityFlow_LinkUnlinkAndInUse(t *testing.T) {
	env := newFlowEnv(t)
	access := env.loginAgreed(env.loginKakao("kakao-identity-flow"))

	// Google을 붙이면 201과 붙인 뒤의 목록입니다.
	googleToken := env.fake.SignIDToken(providertest.GoogleClaims(
		"google-identity-flow", flowNonce, providertest.GoogleClientIDs[0], provider.GoogleIssuers[0], env.clk.Now()))
	linked := env.do(http.MethodPost, "/v1/me/identities/google", access, map[string]string{"idToken": googleToken, "nonce": flowNonce})
	require.Equal(t, http.StatusCreated, linked.status, "붙이기 본문: %v", linked.body)
	assert.Equal(t, []string{"kakao", "google"}, providersOf(t, linked))

	listed := env.do(http.MethodGet, "/v1/me/identities", access, nil)
	require.Equal(t, http.StatusOK, listed.status, "목록 본문: %v", listed.body)
	assert.Equal(t, []string{"kakao", "google"}, providersOf(t, listed))

	// 같은 연결을 다시 붙이면 바꾸지 않고 200입니다.
	again := env.do(http.MethodPost, "/v1/me/identities/google", access, map[string]string{"idToken": googleToken, "nonce": flowNonce})
	require.Equal(t, http.StatusOK, again.status, "다시 붙이기 본문: %v", again.body)

	// 두 번째 계정을 LINE으로 만들고 동의까지 마칩니다.
	lineToken := env.fake.SignES256IDToken(providertest.LINEClaims("line-identity-flow", flowNonce, env.clk.Now()))
	lineLogin := env.do(http.MethodPost, "/v1/auth/line", "", map[string]string{"idToken": lineToken, "nonce": flowNonce})
	env.loginAgreed(lineLogin)

	// 첫 계정에서 그 LINE을 붙이면 다른 active 계정의 연결이라 409입니다. 합치기 토큰은 본문에 없습니다(draft.15).
	inUse := env.do(http.MethodPost, "/v1/me/identities/line", access, map[string]string{"idToken": lineToken, "nonce": flowNonce})
	inUse.requireProblem(t, http.StatusConflict, "auth.identity_in_use")
	assert.NotContains(t, inUse.body, "mergeToken")
	assert.NotContains(t, inUse.body, "expiresAt")

	// 합치기 operation은 아직 구현 전입니다(PR C).
	env.do(http.MethodPost, "/v1/me/merge/preview", access, map[string]string{"provider": "line", "idToken": lineToken, "nonce": flowNonce}).
		requireProblem(t, http.StatusNotImplemented, "not_implemented")

	// Google을 떼면 204, 마지막 하나인 카카오는 뗄 수 없습니다.
	unlinked := env.do(http.MethodDelete, "/v1/me/identities/google", access, nil)
	require.Equal(t, http.StatusNoContent, unlinked.status, "떼기 본문: %v", unlinked.body)
	env.do(http.MethodDelete, "/v1/me/identities/kakao", access, nil).requireProblem(t, http.StatusConflict, "auth.last_identity")
	env.do(http.MethodDelete, "/v1/me/identities/google", access, nil).requireProblem(t, http.StatusNotFound, "auth.identity_not_found")
}
