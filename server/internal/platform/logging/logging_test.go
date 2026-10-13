package logging_test

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"testing"

	"github.com/june20516/myungli-diary/server/internal/platform/logging"
)

const sampleTraceID = "4bf92f3577b34da6a3ce929d0e0e4736"

func decodeLine(t *testing.T, buf *bytes.Buffer) map[string]any {
	t.Helper()
	var entry map[string]any
	if err := json.Unmarshal(buf.Bytes(), &entry); err != nil {
		t.Fatalf("로그가 JSON이 아닙니다: %v\n%s", err, buf.String())
	}
	return entry
}

func TestNew_UsesCloudLoggingKeys(t *testing.T) {
	var buf bytes.Buffer
	logger := logging.New(&buf, slog.LevelInfo, "")

	logger.Warn("x")

	entry := decodeLine(t, &buf)
	if entry["severity"] != "WARNING" {
		t.Errorf("severity = %v, want WARNING", entry["severity"])
	}
	if entry["message"] != "x" {
		t.Errorf("message = %v, want x", entry["message"])
	}
	for _, key := range []string{"level", "msg"} {
		if _, ok := entry[key]; ok {
			t.Errorf("기본 키 %q가 남아 있습니다", key)
		}
	}
}

func TestNew_AddsTraceFromContext(t *testing.T) {
	var buf bytes.Buffer
	logger := logging.New(&buf, slog.LevelInfo, "p")
	ctx := logging.ContextWithTraceID(context.Background(), sampleTraceID)

	logger.InfoContext(ctx, "x")

	entry := decodeLine(t, &buf)
	if entry["traceId"] != sampleTraceID {
		t.Errorf("traceId = %v, want %s", entry["traceId"], sampleTraceID)
	}
	want := "projects/p/traces/" + sampleTraceID
	if entry["logging.googleapis.com/trace"] != want {
		t.Errorf("trace = %v, want %s", entry["logging.googleapis.com/trace"], want)
	}
}

func TestNew_OmitsTraceWithoutContextValueOrProject(t *testing.T) {
	var buf bytes.Buffer
	logger := logging.New(&buf, slog.LevelInfo, "")
	logger.InfoContext(logging.ContextWithTraceID(context.Background(), sampleTraceID), "x")
	entry := decodeLine(t, &buf)
	if entry["traceId"] != sampleTraceID {
		t.Errorf("traceId = %v", entry["traceId"])
	}
	if _, ok := entry["logging.googleapis.com/trace"]; ok {
		t.Error("projectID가 없으면 trace 키를 붙이지 않아야 합니다")
	}

	buf.Reset()
	logger.Info("y")
	entry = decodeLine(t, &buf)
	if _, ok := entry["traceId"]; ok {
		t.Error("ctx에 trace id가 없으면 traceId를 붙이지 않아야 합니다")
	}
}

func TestNew_KeepsTraceAfterWith(t *testing.T) {
	var buf bytes.Buffer
	logger := logging.New(&buf, slog.LevelInfo, "p").With("k", "v")
	ctx := logging.ContextWithTraceID(context.Background(), sampleTraceID)

	logger.InfoContext(ctx, "x")

	entry := decodeLine(t, &buf)
	if entry["traceId"] != sampleTraceID || entry["k"] != "v" {
		t.Errorf("With 이후 속성이 유실되었습니다: %v", entry)
	}
}

func TestNew_RespectsLevel(t *testing.T) {
	var buf bytes.Buffer
	logger := logging.New(&buf, slog.LevelWarn, "")

	logger.Info("skipped")

	if buf.Len() != 0 {
		t.Errorf("레벨 미만 로그가 기록되었습니다: %s", buf.String())
	}
}

func TestNew_KeepsTraceTopLevelInsideGroup(t *testing.T) {
	var buf bytes.Buffer
	logger := logging.New(&buf, slog.LevelInfo, "p")
	ctx := logging.ContextWithTraceID(context.Background(), sampleTraceID)

	logger.WithGroup("g").With("a", 1).InfoContext(ctx, "x", "b", 2)

	entry := decodeLine(t, &buf)
	if entry["traceId"] != sampleTraceID {
		t.Errorf("최상위 traceId = %v", entry["traceId"])
	}
	if entry["logging.googleapis.com/trace"] != "projects/p/traces/"+sampleTraceID {
		t.Errorf("최상위 trace 키 = %v", entry["logging.googleapis.com/trace"])
	}
	group, ok := entry["g"].(map[string]any)
	if !ok {
		t.Fatalf("g group이 없습니다: %v", entry)
	}
	if group["a"] != float64(1) || group["b"] != float64(2) {
		t.Errorf("g = %v, want a=1 b=2", group)
	}
	if _, ok := group["traceId"]; ok {
		t.Error("traceId가 group 안에 들어갔습니다")
	}
}

func TestNew_MapsLevelsToSeverity(t *testing.T) {
	tests := []struct {
		level slog.Level
		want  string
	}{
		{slog.LevelDebug, "DEBUG"},
		{slog.LevelInfo, "INFO"},
		{slog.LevelWarn, "WARNING"},
		{slog.LevelError, "ERROR"},
		{slog.LevelInfo + 2, "INFO"},
		{slog.LevelError + 4, "ERROR"},
		{slog.LevelDebug - 4, "DEBUG"},
	}
	for _, tt := range tests {
		var buf bytes.Buffer
		logger := logging.New(&buf, slog.LevelDebug-8, "")
		logger.Log(context.Background(), tt.level, "x")
		if got := decodeLine(t, &buf)["severity"]; got != tt.want {
			t.Errorf("level %d: severity = %v, want %s", tt.level, got, tt.want)
		}
	}
}
