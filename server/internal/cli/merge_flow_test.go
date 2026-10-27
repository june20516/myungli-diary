package cli

import (
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
)

// 두 계정이 각자 구매한 뒤 A가 B의 LINE으로 요약을 받아 합치면, 같은 Idempotency-Key 재전송은 같은 응답이고
// 다른 키는 토큰이 일회용이라 422이며, B의 세션은 끝나고 B의 구매는 A 구간으로 A의 구매 목록에 보입니다(S111).
func TestMergeFlow_MergeAccounts(t *testing.T) {
	revenueCat, revenueCatURL := newFakeRevenueCat(t)
	_, keysURL := newFakeAdMobKeys(t)
	cfg := config.BillingConfig{
		RevenueCatProjectID:   "proj-flow",
		RevenueCatAPIKey:      flowRevenueCatToken,
		RevenueCatWebhookAuth: flowWebhookAuth,
		AdFreeProductIDs:      []string{flowProductID},
		ProductionOnly:        true,
	}
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		deps.Charts = okCharts{}
		wireBillingReadings(t, deps, newFlowFortuneService(t, deps))
		deps.Billing = newBillingParts(cfg, deps.Pool, deps.HTTP, billingURLs{RevenueCat: revenueCatURL, AdMobKeys: keysURL}, deps.Clock, deps.Logger)
	})
	now := env.clk.Now()

	// A(카카오)는 이틀 전에 산 광고 제거권을 쓰는 중입니다.
	accessA, accountA := env.signUp("merge-flow-a")
	revenueCat.add(accountA, "purchase-merge-a", now.Add(-48*time.Hour))
	require.Equal(t, http.StatusOK, env.do(http.MethodPost, "/v1/billing/restore", accessA, nil).status)

	// B(LINE)는 하루 전에 산 광고 제거권을 쓰는 중입니다.
	lineToken := env.fake.SignES256IDToken(providertest.LINEClaims("merge-flow-b", flowNonce, now))
	loginB := env.do(http.MethodPost, "/v1/auth/line", "", map[string]string{"idToken": lineToken, "nonce": flowNonce})
	accessB := env.loginAgreed(loginB)
	_, refreshB := loginB.tokens(t)
	meB := env.do(http.MethodGet, "/v1/me", accessB, nil)
	require.Equal(t, http.StatusOK, meB.status, "B me 본문: %v", meB.body)
	accountB, _ := meB.body["accountId"].(string)
	revenueCat.add(accountB, "purchase-merge-b", now.Add(-24*time.Hour))
	// B가 예전에 산 광고 제거권은 합치기 전에 끝났습니다.
	revenueCat.add(accountB, "purchase-merge-b-old", now.AddDate(0, -3, 0))
	require.Equal(t, http.StatusOK, env.do(http.MethodPost, "/v1/billing/restore", accessB, nil).status)

	preview := env.do(http.MethodPost, "/v1/me/merge/preview", accessA, map[string]string{"provider": "line", "idToken": lineToken, "nonce": flowNonce})
	require.Equal(t, http.StatusOK, preview.status, "요약 본문: %v", preview.body)
	mergeToken, _ := preview.body["mergeToken"].(string)
	body := map[string]any{"mergeToken": mergeToken, "profile": "current"}

	merged := env.doWithKey(http.MethodPost, "/v1/me/merge", accessA, "merge-key-1", body)
	require.Equal(t, http.StatusOK, merged.status, "합치기 본문: %v", merged.body)
	assert.Equal(t, accountA, merged.body["accountId"], "남는 계정은 A입니다")
	adFree, _ := merged.body["adFree"].(map[string]any)
	assert.Equal(t, true, adFree["active"])

	// 같은 키로 다시 보내면 처음 응답을 그대로 돌려줍니다(Review Focus 5).
	replayed := env.doWithKey(http.MethodPost, "/v1/me/merge", accessA, "merge-key-1", body)
	require.Equal(t, http.StatusOK, replayed.status, "재전송 본문: %v", replayed.body)
	assert.Equal(t, merged.body, replayed.body)
	// 다른 키나 키 없이 같은 토큰을 다시 보내도 합치기 영수증으로 다시 합치지 않고 200 Me입니다(S115, #552).
	otherKey := env.doWithKey(http.MethodPost, "/v1/me/merge", accessA, "merge-key-2", body)
	require.Equal(t, http.StatusOK, otherKey.status, "다른 키 재전송 본문: %v", otherKey.body)
	assert.Equal(t, merged.body, otherKey.body)
	noKey := env.do(http.MethodPost, "/v1/me/merge", accessA, body)
	require.Equal(t, http.StatusOK, noKey.status, "키 없는 재전송 본문: %v", noKey.body)
	assert.Equal(t, merged.body, noKey.body)

	// B는 지워져 세션이 끝납니다.
	env.do(http.MethodPost, "/v1/auth/refresh", "", map[string]string{"refreshToken": refreshB}).
		requireProblem(t, http.StatusUnauthorized, "auth.token_invalid")
	env.do(http.MethodGet, "/v1/me", accessB, nil).requireProblem(t, http.StatusUnauthorized, "auth.token_invalid")

	// A의 구매 목록에 B의 구매가 A 구간(A의 사용 중 구간 끝부터)으로 보입니다. A 쪽에 expired가 생기지 않습니다.
	listed := env.do(http.MethodGet, "/v1/me/purchases", accessA, nil)
	require.Equal(t, http.StatusOK, listed.status, "목록 본문: %v", listed.body)
	items, _ := listed.body["items"].([]any)
	require.Len(t, items, 3)
	moved, _ := items[0].(map[string]any)
	own, _ := items[1].(map[string]any)
	ended, _ := items[2].(map[string]any)
	assert.Equal(t, "expired", ended["status"], "합치기 전에 끝난 B 구매는 A 목록에서 expired입니다: %v", ended)
	assert.NotContains(t, ended, "period", "A 구간이 없습니다")
	assert.Equal(t, "pending", moved["status"], "B 구매는 A 구간 뒤에 대기합니다: %v", moved)
	assert.Equal(t, "active", own["status"], "A 구매는 그대로 사용 중입니다: %v", own)
	movedPeriod, _ := moved["period"].(map[string]any)
	ownPeriod, _ := own["period"].(map[string]any)
	require.NotNil(t, movedPeriod, "moved: %v", moved)
	require.NotNil(t, ownPeriod, "own: %v", own)
	assert.Equal(t, ownPeriod["endsAt"], movedPeriod["startsAt"], "B 구간은 A 구간 끝에서 시작합니다")
}
