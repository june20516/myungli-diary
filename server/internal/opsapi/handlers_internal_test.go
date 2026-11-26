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

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/ops"
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
