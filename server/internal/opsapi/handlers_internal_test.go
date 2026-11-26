package opsapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/ops"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

// serveFake는 가짜 command를 commandHandler에 넣어 한 번 호출합니다.
func serveFake(t *testing.T, run command) (*httptest.ResponseRecorder, string) {
	t.Helper()
	logs := &bytes.Buffer{}
	handler := commandHandler(Deps{Logger: slog.New(slog.NewJSONHandler(logs, nil))}, run)
	req := httptest.NewRequestWithContext(context.Background(), http.MethodPost, "/ops/v1/fake", strings.NewReader(`{}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	return rec, logs.String()
}

func TestCommandHandler_MarshalFailureIs500(t *testing.T) {
	const marker = "원문-표식-9"
	rec, logs := serveFake(t, func(context.Context, *ops.Service, ops.Actor, []byte) (any, error) {
		return map[string]any{"secret": marker, "bad": math.NaN()}, nil
	})
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
	var body errorResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body))
	assert.Equal(t, errorResponse{Code: "internal", Message: "내부 오류입니다"}, body)
	assert.NotContains(t, rec.Body.String(), marker)
	assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"))
	assert.Contains(t, logs, `"kind":"*json.UnsupportedValueError"`)
	assert.NotContains(t, logs, marker)
}

func TestCommandHandler_ActorErrorIs500(t *testing.T) {
	rec, logs := serveFake(t, func(context.Context, *ops.Service, ops.Actor, []byte) (any, error) {
		return nil, fmt.Errorf("감싼 오류: %w", ops.ErrActor)
	})
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
	var body errorResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body))
	assert.Equal(t, errorResponse{Code: "internal", Message: "내부 오류입니다"}, body)
	assert.Contains(t, logs, `"kind":"actor"`)
}

// 상한을 세는 콘텐츠 경로는 모두 등록된 명령 경로여야 합니다(오타면 상한이 걸리지 않음).
func TestContentPaths_AreCommands(t *testing.T) {
	registered := commands()
	assert.Len(t, contentPaths, 3)
	for path := range contentPaths {
		assert.Contains(t, registered, path)
	}
}

// 창이 지난 키는 다음 호출 때 지워져 map이 커지지 않습니다.
func TestRateLimiter_DropsEmptyKeys(t *testing.T) {
	clk := clocktest.New(time.Date(2026, 11, 26, 3, 0, 0, 0, time.UTC))
	limiter := newRateLimiter(clk, 2, time.Minute)
	assert.True(t, limiter.allow("a"))
	assert.True(t, limiter.allow("a"))
	assert.False(t, limiter.allow("a"), "상한을 넘으면 거절")
	assert.Len(t, limiter.hits["a"], 2, "거절한 요청은 세지 않음")

	clk.Advance(time.Minute)
	assert.True(t, limiter.allow("b"))
	assert.NotContains(t, limiter.hits, "a", "창이 빈 키는 지움")
	assert.Len(t, limiter.hits, 1)
}
