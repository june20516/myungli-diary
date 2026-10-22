package cli

import (
	"bytes"
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// okCharts는 프로필 저장의 차트 확인을 늘 통과시키는 ChartChecker 대역입니다.
type okCharts struct{}

func (okCharts) Chart(context.Context, profile.Birth, profile.LocalDate) (*enginev1.ChartResponse, error) {
	return &enginev1.ChartResponse{}, nil
}

const flowProfileBody = `{"honorific":"벗","language":"ko","currentTimezone":"Asia/Seoul",` +
	`"birth":{"calendar":"solar","date":{"year":1990,"month":3,"day":14},"isLeapMonth":false,` +
	`"time":{"status":"known","value":"07:30"},"gender":"female","timezone":"Asia/Seoul","place":{"status":"not_asked"}},` +
	`"notification":{"status":"not_asked"}}`

// serve 조립(newServer)에 일정 서비스와 멱등 미들웨어가 들어 있는지 확인합니다.
// 조립이 빠지면 일정 operation은 501 not_implemented 또는 503 service.unavailable로 답합니다.
func TestScheduleFlow_AssembledOperationsAreNotStubbed(t *testing.T) {
	env := newFlowEnv(t)
	login := env.loginKakao("schedule-flow-subject")
	require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	access, _ := login.tokens(t)
	consent := env.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	require.Equal(t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)

	schedules := env.do(http.MethodGet, "/v1/schedules?from=2026-10-01&to=2026-10-31", access, nil)
	require.Equal(t, http.StatusOK, schedules.status, "일정 목록 본문: %v", schedules.body)

	// Idempotency-Key가 같은 일정 만들기는 한 번만 만들고 같은 응답을 다시 줍니다.
	body := map[string]any{"date": "2026-10-21", "allDay": true, "title": "회의"}
	first := env.doWithKey(http.MethodPost, "/v1/schedules", access, "flow-key-1", body)
	require.Equal(t, http.StatusCreated, first.status, "일정 만들기 본문: %v", first.body)
	second := env.doWithKey(http.MethodPost, "/v1/schedules", access, "flow-key-1", body)
	require.Equal(t, http.StatusCreated, second.status, "재시도 본문: %v", second.body)
	assert.Equal(t, first.body["id"], second.body["id"], "같은 키의 재시도는 같은 일정을 돌려줍니다")

	after := env.do(http.MethodGet, "/v1/schedules?from=2026-10-01&to=2026-10-31", access, nil)
	require.Equal(t, http.StatusOK, after.status)
	items, _ := after.body["items"].([]any)
	assert.Len(t, items, 1, "일정은 한 번만 만들어집니다")
}

// doWithKey는 do와 같되 Idempotency-Key 헤더를 더합니다.
func (e *flowEnv) doWithKey(method, path, accessToken, key string, body map[string]any) flowResponse {
	e.t.Helper()
	raw := mustJSON(e.t, body)
	req, err := http.NewRequestWithContext(e.t.Context(), method, e.url+path, bytes.NewReader(raw))
	require.NoError(e.t, err)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Idempotency-Key", key)
	return e.send(req)
}
