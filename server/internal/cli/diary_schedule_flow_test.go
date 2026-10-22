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

	profileSaved := env.do(http.MethodPut, "/v1/me/profile", access, json.RawMessage(flowProfileBody))
	require.Equal(t, http.StatusOK, profileSaved.status, "프로필 본문: %v", profileSaved.body)

	// 같은 날짜에 일기 두 편: id가 다르고 작성 순으로 나옵니다.
	const day = "/v1/diaries?from=2026-10-12&to=2026-10-12"
	one := env.do(http.MethodPost, "/v1/diaries", access, map[string]any{"date": "2026-10-12", "body": "첫째 편"})
	require.Equal(t, http.StatusCreated, one.status, "첫째 편 본문: %v", one.body)
	two := env.do(http.MethodPost, "/v1/diaries", access, map[string]any{"date": "2026-10-12", "body": "둘째 편"})
	require.Equal(t, http.StatusCreated, two.status, "둘째 편 본문: %v", two.body)
	id1, _ := one.body["id"].(string)
	id2, _ := two.body["id"].(string)
	require.NotEmpty(t, id1)
	require.NotEmpty(t, id2)
	require.NotEqual(t, id1, id2, "같은 날 두 편의 id는 다릅니다")
	assertDiaryIDs(t, env.do(http.MethodGet, day, access, nil), id1, id2)

	edited := env.do(http.MethodPut, "/v1/diaries/"+id1, access, map[string]any{"body": "고친 첫째 편"})
	require.Equal(t, http.StatusOK, edited.status, "수정 본문: %v", edited.body)
	assert.Equal(t, "고친 첫째 편", edited.body["body"])

	deleted := env.do(http.MethodDelete, "/v1/diaries/"+id1, access, nil)
	require.Equal(t, http.StatusNoContent, deleted.status, "삭제 본문: %v", deleted.body)
	env.do(http.MethodGet, "/v1/diaries/"+id1, access, nil).requireProblem(t, http.StatusNotFound, "diary.not_found")
	assertDiaryIDs(t, env.do(http.MethodGet, day, access, nil), id2)

	restored := env.do(http.MethodPost, "/v1/diaries/"+id1+"/restore", access, nil)
	require.Equal(t, http.StatusOK, restored.status, "복원 본문: %v", restored.body)
	assertDiaryIDs(t, env.do(http.MethodGet, day, access, nil), id1, id2)

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

// assertDiaryIDs는 일기 목록 응답이 주어진 id를 그 순서대로 담았는지 확인합니다.
func assertDiaryIDs(t *testing.T, list flowResponse, want ...string) {
	t.Helper()
	require.Equal(t, http.StatusOK, list.status, "일기 목록 본문: %v", list.body)
	items, _ := list.body["items"].([]any)
	got := make([]string, 0, len(items))
	for _, item := range items {
		entry, _ := item.(map[string]any)
		id, _ := entry["id"].(string)
		got = append(got, id)
	}
	assert.Equal(t, want, got, "일기 목록은 작성 순입니다")
}
