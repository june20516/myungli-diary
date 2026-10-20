package cli

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// fakeDays는 엔진 없이 그날 기록을 돌려주는 diary.Days 대역입니다.
type fakeDays struct{}

func (fakeDays) DayRecord(context.Context, uuid.UUID, profile.Profile, profile.LocalDate) (fortune.DayRecord, error) {
	return fortune.DayRecord{AllTags: []string{}, Featured: []fortune.FeaturedTag{}, RulesetVersion: "flow-1"}, nil
}

// okCharts는 프로필 저장의 차트 확인을 늘 통과시키는 ChartChecker 대역입니다.
type okCharts struct{}

func (okCharts) Chart(context.Context, profile.Birth, profile.LocalDate) (*enginev1.ChartResponse, error) {
	return &enginev1.ChartResponse{}, nil
}

const flowProfileBody = `{"honorific":"벗","language":"ko","currentTimezone":"Asia/Seoul",` +
	`"birth":{"calendar":"solar","date":{"year":1990,"month":3,"day":14},"isLeapMonth":false,` +
	`"time":{"status":"known","value":"07:30"},"gender":"female","timezone":"Asia/Seoul","place":{"status":"not_asked"}},` +
	`"notification":{"status":"not_asked"}}`

// Days를 연결하지 않으면 일기 operation은 503 service.unavailable입니다(Readings·Contents와 같은 관례).
func TestDiaryScheduleFlow_WithoutDaysDiariesAreUnavailable(t *testing.T) {
	env := newFlowEnv(t)
	login := env.loginKakao("diary-nodays-subject")
	require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	access, _ := login.tokens(t)
	consent := env.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	require.Equal(t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)

	env.do(http.MethodGet, "/v1/diaries", access, nil).requireProblem(t, http.StatusServiceUnavailable, "service.unavailable")
}

// serve 조립(newServer)에 일기·일정 서비스와 멱등 미들웨어가 들어 있는지 확인합니다.
// 조립이 빠지면 일기·일정 operation은 501 not_implemented 또는 503 service.unavailable로 답합니다.
func TestDiaryScheduleFlow_AssembledOperationsAreNotStubbed(t *testing.T) {
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		deps.Charts = okCharts{}
		deps.Days = fakeDays{}
	})
	login := env.loginKakao("diary-flow-subject")
	require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	access, _ := login.tokens(t)
	consent := env.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	require.Equal(t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)

	list := env.do(http.MethodGet, "/v1/diaries", access, nil)
	require.Equal(t, http.StatusOK, list.status, "일기 목록 본문: %v", list.body)

	env.do(http.MethodGet, "/v1/diaries/2026-10-12", access, nil).requireProblem(t, http.StatusNotFound, "diary.not_found")

	// 일기를 새로 쓰면 Days 연결을 지나 201이 됩니다.
	profileSaved := env.do(http.MethodPut, "/v1/me/profile", access, json.RawMessage(flowProfileBody))
	require.Equal(t, http.StatusOK, profileSaved.status, "프로필 본문: %v", profileSaved.body)
	written := env.do(http.MethodPut, "/v1/diaries/2026-10-12", access, map[string]any{"body": "오늘의 일기"})
	require.Equal(t, http.StatusCreated, written.status, "일기 쓰기 본문: %v", written.body)

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
