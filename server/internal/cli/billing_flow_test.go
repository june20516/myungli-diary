package cli

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
)

// flowChartResponse는 getChart 변환을 통과하는 최소 엔진 응답입니다.
func flowChartResponse() *enginev1.ChartResponse {
	pillar := func(s enginev1.Stem, b enginev1.Branch) *enginev1.Pillar { return &enginev1.Pillar{Stem: s, Branch: b} }
	return &enginev1.ChartResponse{
		Pillars: &enginev1.FourPillars{
			Year:  pillar(enginev1.Stem_STEM_GYEONG, enginev1.Branch_BRANCH_O),
			Month: pillar(enginev1.Stem_STEM_SIN, enginev1.Branch_BRANCH_SA),
			Day:   pillar(enginev1.Stem_STEM_GAP, enginev1.Branch_BRANCH_JA),
		},
		Strength: &enginev1.Strength{Score: -0.5, Level: enginev1.StrengthLevel_STRENGTH_LEVEL_WEAK},
		Yongsin: &enginev1.YongsinInfo{
			Yongsin: enginev1.Element_ELEMENT_WATER, Huisin: enginev1.Element_ELEMENT_METAL,
			Gisin: enginev1.Element_ELEMENT_EARTH, Tonggwan: enginev1.Element_ELEMENT_WOOD,
			Method: enginev1.YongsinMethod_YONGSIN_METHOD_EOKBU,
		},
		Daeun: &enginev1.DaeunTable{Forward: true},
		Meta:  &enginev1.ResponseMeta{RulesetVersion: "r1"},
	}
}

// newFlowFortuneService는 가짜 엔진이 flowChartResponse를 돌려주는 fortune.Service를 만듭니다.
func newFlowFortuneService(t *testing.T, deps *serverDeps) *fortune.Service {
	t.Helper()
	fake := &enginetest.Fake{Chart: func(*enginev1.ChartRequest) (*enginev1.ChartResponse, error) { return flowChartResponse(), nil }}
	versions := engine.NewVersions(fake, slog.New(slog.DiscardHandler))
	require.NoError(t, versions.Refresh(context.Background()))
	return fortune.NewService(fake, versions, fortune.NewPostgresCache(deps.Pool), deps.Logger)
}

// wireBillingReadings는 serve와 같이 한 billing.Store를 근거 판정과 권한 응답에 함께 붙이고 시드를 넣습니다.
func wireBillingReadings(t *testing.T, deps *serverDeps, service *fortune.Service) {
	t.Helper()
	contents := content.NewStore(deps.Pool, deps.Clock, deps.Logger)
	deps.Contents = contents
	store := billing.NewStore(deps.Pool, deps.Clock)
	deps.Entitlements = store
	deps.Readings = newReadings(contents, service, store, deps.Logger, deps.Clock)
	code, _, stderr := runCLIWithEnv(t, map[string]string{"DATABASE_URL": deps.Pool.Config().ConnString()}, "seed")
	require.Equal(t, 0, code, "seed stderr: %s", stderr)
}

// signUp은 가입해 동의·프로필까지 저장하고 access token과 계정 id를 돌려줍니다.
func (e *flowEnv) signUp(subject string) (access, accountID string) {
	e.t.Helper()
	login := e.loginKakao(subject)
	require.Equal(e.t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	access, _ = login.tokens(e.t)
	consent := e.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	require.Equal(e.t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)
	saved := e.do(http.MethodPut, "/v1/me/profile", access, json.RawMessage(flowProfileBody))
	require.Equal(e.t, http.StatusOK, saved.status, "프로필 본문: %v", saved.body)
	me := e.do(http.MethodGet, "/v1/me", access, nil)
	require.Equal(e.t, http.StatusOK, me.status, "me 본문: %v", me.body)
	accountID, _ = me.body["accountId"].(string)
	require.NotEmpty(e.t, accountID)
	return access, accountID
}

// 조립(newServer·newReadings)이 billing.Store를 근거 잠금과 권한 응답에 함께 쓰는지 확인합니다.
// 가짜 엔진이 personal_readings를 내지 않아도 열림 여부는 getChart의 personalReadings 유무와 evidenceAccess로 드러납니다.
func TestBillingFlow_InsightGrantUnlocksEvidence(t *testing.T) {
	var pool *pgxpool.Pool
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		pool = deps.Pool
		deps.Charts = okCharts{}
		service := newFlowFortuneService(t, deps)
		wireBillingReadings(t, deps, service)
	})

	withGrant, grantedID := env.signUp("billing-flow-granted")
	without, _ := env.signUp("billing-flow-plain")

	now := env.clk.Now()
	_, err := pool.Exec(t.Context(),
		`INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		 VALUES ($1, 'insight', 'rewarded_ad', 'flow-ref', $2, $3)`,
		grantedID, now.Add(-time.Hour), now.Add(time.Hour))
	require.NoError(t, err)

	granted := env.do(http.MethodGet, "/v1/chart", withGrant, nil)
	require.Equal(t, http.StatusOK, granted.status, "차트 본문: %v", granted.body)
	assert.Equal(t, "unlocked", granted.body["evidenceAccess"])
	assert.Contains(t, granted.body, "personalReadings", "권한이 있으면 원국 개인 해석이 열립니다")

	plain := env.do(http.MethodGet, "/v1/chart", without, nil)
	require.Equal(t, http.StatusOK, plain.status, "차트 본문: %v", plain.body)
	assert.Equal(t, "locked", plain.body["evidenceAccess"])
	assert.NotContains(t, plain.body, "personalReadings")

	// 같은 권한 행이 getMe·getEntitlements 응답에도 보입니다.
	me := env.do(http.MethodGet, "/v1/me", withGrant, nil)
	insight, _ := me.body["insight"].(map[string]any)
	assert.Equal(t, true, insight["active"])
	assert.Equal(t, "rewarded_ad", insight["source"])
	entitlements := env.do(http.MethodGet, "/v1/me/entitlements", withGrant, nil)
	require.Equal(t, http.StatusOK, entitlements.status, "권한 본문: %v", entitlements.body)
	assert.Equal(t, insight, entitlements.body["insight"])
	plainEnt := env.do(http.MethodGet, "/v1/me/entitlements", without, nil)
	assert.Equal(t, map[string]any{"active": false}, plainEnt.body["insight"])
}

// Entitlements가 빠진 조립은 숨기지 않고 getMe가 503 service.unavailable입니다(Readings·Contents와 같은 관례).
func TestBillingFlow_WithoutEntitlementsIsUnavailable(t *testing.T) {
	env := newFlowEnvWith(t, func(deps *serverDeps) { deps.Entitlements = nil })
	login := env.loginKakao("billing-flow-missing")
	require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	access, _ := login.tokens(t)
	consent := env.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	require.Equal(t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)

	env.do(http.MethodGet, "/v1/me", access, nil).requireProblem(t, http.StatusServiceUnavailable, "service.unavailable")
}

const (
	flowProductID       = "test.ad_free.month"
	flowWebhookAuth     = "Bearer flow-webhook-secret"
	flowRewardKeyID     = 3335741209
	flowRewardTxPrefix  = "tx-flow-"
	flowRevenueCatToken = "flow-rc-secret"
)

// fakeRevenueCat은 RevenueCat REST v2 구매 목록 대역입니다. 고객 id별로 구매 목록을 돌려줍니다.
type fakeRevenueCat struct {
	mu        sync.Mutex
	purchases map[string][]map[string]any
}

func newFakeRevenueCat(t *testing.T) (*fakeRevenueCat, string) {
	t.Helper()
	fake := &fakeRevenueCat{purchases: map[string][]map[string]any{}}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer "+flowRevenueCatToken {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		// /v2/projects/{project}/customers/{customer}/purchases
		parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
		if len(parts) != 6 || parts[4] == "" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		fake.mu.Lock()
		items := fake.purchases[parts[4]]
		fake.mu.Unlock()
		if items == nil {
			items = []map[string]any{}
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"object": "list", "items": items, "next_page": nil})
	}))
	t.Cleanup(srv.Close)
	return fake, srv.URL
}

// add는 고객에게 production 구매 하나를 더합니다.
func (f *fakeRevenueCat) add(customerID, purchaseID string, purchasedAt time.Time) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.purchases[customerID] = append(f.purchases[customerID], map[string]any{
		"id": purchaseID, "product_id": flowProductID, "purchased_at": purchasedAt.UnixMilli(),
		"status": "owned", "environment": "production",
	})
}

// newFakeAdMobKeys는 키 서버 대역과 서명 키를 만듭니다. 응답은 {"keys":[{"keyId":n,"base64":PKIX DER}]}입니다.
func newFakeAdMobKeys(t *testing.T) (*ecdsa.PrivateKey, string) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)
	der, err := x509.MarshalPKIXPublicKey(&key.PublicKey)
	require.NoError(t, err)
	body := mustJSON(t, map[string]any{"keys": []map[string]any{{"keyId": flowRewardKeyID, "base64": base64.StdEncoding.EncodeToString(der)}}})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(body)
	}))
	t.Cleanup(srv.Close)
	return key, srv.URL
}

// signedRewardQuery는 AdMob SSV 콜백의 원본 쿼리를 만듭니다. 서명 대상은 "&signature=" 앞까지입니다.
func signedRewardQuery(t *testing.T, key *ecdsa.PrivateKey, userID, transactionID string, at time.Time) string {
	t.Helper()
	message := fmt.Sprintf("ad_network=5450213213286189855&ad_unit=1234&reward_amount=1&reward_item=insight&timestamp=%d&transaction_id=%s&user_id=%s",
		at.UnixMilli(), transactionID, userID)
	digest := sha256.Sum256([]byte(message))
	sig, err := ecdsa.SignASN1(rand.Reader, key, digest[:])
	require.NoError(t, err)
	return fmt.Sprintf("%s&signature=%s&key_id=%d", message, base64.RawURLEncoding.EncodeToString(sig), flowRewardKeyID)
}

// 구매 복원, RevenueCat webhook, 보상형 광고 콜백이 한 조립(newBillingParts)에서 끝까지 이어지는지 확인합니다.
func TestBillingFlow_RestoreWebhookAndRewardedAd(t *testing.T) {
	revenueCat, revenueCatURL := newFakeRevenueCat(t)
	rewardKey, keysURL := newFakeAdMobKeys(t)
	cfg := config.BillingConfig{
		RevenueCatProjectID:   "proj-flow",
		RevenueCatAPIKey:      flowRevenueCatToken,
		RevenueCatWebhookAuth: flowWebhookAuth,
		AdFreeProductIDs:      []string{flowProductID},
		ProductionOnly:        true,
	}
	var pool *pgxpool.Pool
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		pool = deps.Pool
		deps.Charts = okCharts{}
		wireBillingReadings(t, deps, newFlowFortuneService(t, deps))
		deps.Billing = newBillingParts(cfg, deps.Pool, deps.HTTP, billingURLs{RevenueCat: revenueCatURL, AdMobKeys: keysURL}, deps.Clock, deps.Logger)
	})
	purchasedAt := env.clk.Now().Add(-24 * time.Hour)

	adFreeOf := func(access string) map[string]any {
		me := env.do(http.MethodGet, "/v1/me", access, nil)
		require.Equal(t, http.StatusOK, me.status, "me 본문: %v", me.body)
		adFree, _ := me.body["adFree"].(map[string]any)
		return adFree
	}
	chartUnlocked := func(access string) bool {
		chart := env.do(http.MethodGet, "/v1/chart", access, nil)
		require.Equal(t, http.StatusOK, chart.status, "차트 본문: %v", chart.body)
		_, has := chart.body["personalReadings"]
		return chart.body["evidenceAccess"] == "unlocked" && has
	}

	t.Run("restorePurchases는 광고 제거권과 근거 열람을 연다", func(t *testing.T) {
		access, accountID := env.signUp("billing-flow-restore")
		assert.Equal(t, false, adFreeOf(access)["active"])
		assert.False(t, chartUnlocked(access))

		revenueCat.add(accountID, "purchase-restore", purchasedAt)
		restored := env.do(http.MethodPost, "/v1/billing/restore", access, nil)
		require.Equal(t, http.StatusOK, restored.status, "복원 본문: %v", restored.body)
		adFree, _ := restored.body["adFree"].(map[string]any)
		assert.Equal(t, true, adFree["active"])

		assert.Equal(t, true, adFreeOf(access)["active"])
		assert.True(t, chartUnlocked(access), "광고 제거권 기간의 insight가 근거를 엽니다")
	})

	t.Run("webhook도 같은 상태를 만든다", func(t *testing.T) {
		access, accountID := env.signUp("billing-flow-webhook")
		revenueCat.add(accountID, "purchase-webhook", purchasedAt)
		event := map[string]any{"api_version": "1.0", "event": map[string]any{
			"id": "evt-flow-1", "type": "INITIAL_PURCHASE", "app_user_id": accountID,
		}}

		denied := env.webhook(event, "Bearer wrong")
		denied.requireProblem(t, http.StatusUnauthorized, "auth.token_invalid")
		assert.Equal(t, false, adFreeOf(access)["active"], "틀린 Authorization은 아무것도 바꾸지 못합니다")

		accepted := env.webhook(event, flowWebhookAuth)
		require.Equal(t, http.StatusOK, accepted.status, "webhook 본문: %v", accepted.body)
		assert.Equal(t, true, adFreeOf(access)["active"])
		assert.True(t, chartUnlocked(access))

		// 같은 event.id를 다시 받아도 결과가 같고 200입니다.
		again := env.webhook(event, flowWebhookAuth)
		assert.Equal(t, http.StatusOK, again.status)
		var events int
		require.NoError(t, pool.QueryRow(t.Context(), `SELECT count(*) FROM billing_events WHERE event_id = $1`, "evt-flow-1").Scan(&events))
		assert.Equal(t, 1, events, "같은 event.id는 한 행만 남습니다")
		assert.Equal(t, true, adFreeOf(access)["active"])
	})

	t.Run("서명된 SSV 콜백은 insight를 rewarded_ad로 부여한다", func(t *testing.T) {
		access, accountID := env.signUp("billing-flow-reward")
		before := env.do(http.MethodGet, "/v1/me/entitlements", access, nil)
		require.Equal(t, http.StatusOK, before.status, "권한 본문: %v", before.body)
		assert.Equal(t, map[string]any{"active": false}, before.body["insight"])
		assert.Equal(t, false, adFreeOf(access)["active"])

		query := signedRewardQuery(t, rewardKey, accountID, flowRewardTxPrefix+"1", env.clk.Now())
		granted := env.get("/webhooks/admob-ssv?" + query)
		require.Equal(t, http.StatusOK, granted.status, "보상 본문: %v", granted.body)

		after := env.do(http.MethodGet, "/v1/me/entitlements", access, nil)
		insight, _ := after.body["insight"].(map[string]any)
		assert.Equal(t, true, insight["active"])
		assert.Equal(t, "rewarded_ad", insight["source"])
		assert.Equal(t, false, adFreeOf(access)["active"], "보상은 광고 제거권을 주지 않습니다")
		assert.True(t, chartUnlocked(access))

		// 같은 transaction_id는 한 번만 처리하고 200입니다. 서명이 틀리면 401입니다.
		assert.Equal(t, http.StatusOK, env.get("/webhooks/admob-ssv?"+query).status)
		tampered := strings.Replace(query, "reward_amount=1", "reward_amount=9", 1)
		env.get("/webhooks/admob-ssv?"+tampered).requireProblem(t, http.StatusUnauthorized, "reward.invalid_signature")
	})
}

// 결제 설정이 없으면(local) 구매 복원은 503, webhook은 500이고 보상 콜백은 그대로 동작합니다(typed nil을 넣지 않음).
func TestBillingFlow_WithoutRevenueCatConfig(t *testing.T) {
	rewardKey, keysURL := newFakeAdMobKeys(t)
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		deps.Charts = okCharts{}
		deps.Billing = newBillingParts(config.BillingConfig{}, deps.Pool, deps.HTTP, billingURLs{AdMobKeys: keysURL}, deps.Clock, deps.Logger)
	})
	access, accountID := env.signUp("billing-flow-unconfigured")

	env.do(http.MethodPost, "/v1/billing/restore", access, nil).requireProblem(t, http.StatusServiceUnavailable, "billing.provider_unavailable")
	env.webhook(map[string]any{"event": map[string]any{"id": "evt-x", "type": "TEST"}}, flowWebhookAuth).requireProblem(t, http.StatusInternalServerError, "internal")

	query := signedRewardQuery(t, rewardKey, accountID, flowRewardTxPrefix+"2", env.clk.Now())
	assert.Equal(t, http.StatusOK, env.get("/webhooks/admob-ssv?"+query).status)
}

// webhook은 RevenueCat이 보내는 Authorization 헤더와 함께 webhook 본문을 보냅니다.
func (e *flowEnv) webhook(body any, authorization string) flowResponse {
	e.t.Helper()
	req, err := http.NewRequestWithContext(e.t.Context(), http.MethodPost, e.url+"/webhooks/revenuecat", bytes.NewReader(mustJSON(e.t, body)))
	require.NoError(e.t, err)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", authorization)
	return e.send(req)
}

// get는 인증 없이 경로(쿼리 포함, 그대로)를 GET합니다.
func (e *flowEnv) get(pathAndQuery string) flowResponse {
	e.t.Helper()
	req, err := http.NewRequestWithContext(e.t.Context(), http.MethodGet, e.url+pathAndQuery, nil)
	require.NoError(e.t, err)
	return e.send(req)
}
