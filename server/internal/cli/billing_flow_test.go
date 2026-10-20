package cli

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
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

// 조립(newServer·newReadings)이 billing.Store를 근거 잠금과 권한 응답에 함께 쓰는지 확인합니다.
// 가짜 엔진이 personal_readings를 내지 않아도 열림 여부는 getChart의 personalReadings 유무와 evidenceAccess로 드러납니다.
func TestBillingFlow_InsightGrantUnlocksEvidence(t *testing.T) {
	var pool *pgxpool.Pool
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		pool = deps.Pool
		deps.Charts = okCharts{}
		fake := &enginetest.Fake{Chart: func(*enginev1.ChartRequest) (*enginev1.ChartResponse, error) { return flowChartResponse(), nil }}
		versions := engine.NewVersions(fake, slog.New(slog.DiscardHandler))
		require.NoError(t, versions.Refresh(context.Background()))
		service := fortune.NewService(fake, versions, fortune.NewPostgresCache(deps.Pool), deps.Logger)

		contents := content.NewStore(deps.Pool, deps.Clock, deps.Logger)
		deps.Contents = contents
		// serve와 같이 한 Store를 근거 판정과 권한 응답에 함께 씁니다.
		store := billing.NewStore(deps.Pool, deps.Clock)
		deps.Entitlements = store
		deps.Readings = newReadings(contents, service, store, deps.Logger, deps.Clock)
		code, _, stderr := runCLIWithEnv(t, map[string]string{"DATABASE_URL": deps.Pool.Config().ConnString()}, "seed")
		require.Equal(t, 0, code, "seed stderr: %s", stderr)
	})

	// signUp은 가입해 프로필까지 저장하고 access token과 계정 id를 돌려줍니다.
	signUp := func(subject string) (access, accountID string) {
		login := env.loginKakao(subject)
		require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
		access, _ = login.tokens(t)
		consent := env.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
		require.Equal(t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)
		saved := env.do(http.MethodPut, "/v1/me/profile", access, json.RawMessage(flowProfileBody))
		require.Equal(t, http.StatusOK, saved.status, "프로필 본문: %v", saved.body)
		me := env.do(http.MethodGet, "/v1/me", access, nil)
		require.Equal(t, http.StatusOK, me.status, "me 본문: %v", me.body)
		accountID, _ = me.body["accountId"].(string)
		require.NotEmpty(t, accountID)
		return access, accountID
	}
	withGrant, grantedID := signUp("billing-flow-granted")
	without, _ := signUp("billing-flow-plain")

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
