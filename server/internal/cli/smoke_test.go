package cli

import (
	"bytes"
	"log/slog"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/fortune"
)

// job smoke는 설정을 읽는 단계부터 실행합니다.
func TestRun_SmokeWithoutDatabaseURL_Exits1WithConfigError(t *testing.T) {
	code, stderr := runCLI(t, "job", "smoke")

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "DATABASE_URL")
}

// 문장을 만들지 못한 일이 하나라도 있으면 Job이 실패하고, 실패마다 칸을 로그에 남깁니다.
func TestSmokeOutcome_FailuresFail(t *testing.T) {
	var logs bytes.Buffer
	report := fortune.SmokeReport{Checks: 3, Failures: []fortune.SmokeFailure{
		{Message: "슬롯 문장을 만들지 못했습니다", Attrs: map[string]string{"slot": "today.number", "lang": "ja"}},
	}}

	err := smokeOutcome(t.Context(), slog.New(slog.NewTextHandler(&logs, nil)), report)

	require.Error(t, err)
	assert.Contains(t, logs.String(), "today.number")
	assert.Contains(t, logs.String(), "lang=ja")
}

func TestSmokeOutcome_NoFailuresPasses(t *testing.T) {
	var logs bytes.Buffer

	err := smokeOutcome(t.Context(), slog.New(slog.NewTextHandler(&logs, nil)), fortune.SmokeReport{Checks: 3})

	require.NoError(t, err)
	assert.Contains(t, logs.String(), "checks=3")
}
