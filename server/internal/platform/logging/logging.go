// Package logging은 Cloud Logging이 읽는 구조화 JSON 로그와 요청 trace id를 제공합니다.
// 로그에 출생 정보, 호칭, 일기·일정 본문, 토큰, 요청 본문을 남기지 않습니다.
package logging

import (
	"context"
	"io"
	"log/slog"
)

const (
	severityKey = "severity"
	messageKey  = "message"
	traceIDAttr = "traceId"
	cloudTrace  = "logging.googleapis.com/trace"
)

// New는 Cloud Logging 형식의 JSON 로거를 만듭니다.
// 레벨 키는 severity, 메시지 키는 message로 내보냅니다.
// ctx에 trace id가 있으면 traceId를 붙이고, projectID가 있으면 Cloud Logging trace 키도 붙입니다.
func New(w io.Writer, level slog.Level, projectID string) *slog.Logger {
	jsonHandler := slog.NewJSONHandler(w, &slog.HandlerOptions{
		Level:       level,
		ReplaceAttr: replaceForCloudLogging,
	})
	return slog.New(&traceHandler{Handler: jsonHandler, projectID: projectID})
}

// replaceForCloudLogging은 최상위 level, msg 키를 Cloud Logging 키로 바꿉니다.
func replaceForCloudLogging(groups []string, attr slog.Attr) slog.Attr {
	if len(groups) > 0 {
		return attr
	}
	switch attr.Key {
	case slog.LevelKey:
		level, ok := attr.Value.Any().(slog.Level)
		if !ok {
			return attr
		}
		return slog.String(severityKey, severity(level))
	case slog.MessageKey:
		return slog.Attr{Key: messageKey, Value: attr.Value}
	}
	return attr
}

// severity는 slog 레벨을 Cloud Logging severity 이름으로 바꿉니다.
func severity(level slog.Level) string {
	if level == slog.LevelWarn {
		return "WARNING"
	}
	return level.String()
}

// traceHandler는 ctx의 trace id를 로그 속성으로 붙이는 slog.Handler wrapper입니다.
type traceHandler struct {
	slog.Handler
	projectID string
}

func (h *traceHandler) Handle(ctx context.Context, record slog.Record) error {
	if traceID := TraceID(ctx); traceID != "" {
		record.AddAttrs(slog.String(traceIDAttr, traceID))
		if h.projectID != "" {
			record.AddAttrs(slog.String(cloudTrace, "projects/"+h.projectID+"/traces/"+traceID))
		}
	}
	return h.Handler.Handle(ctx, record)
}

func (h *traceHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &traceHandler{Handler: h.Handler.WithAttrs(attrs), projectID: h.projectID}
}

func (h *traceHandler) WithGroup(name string) slog.Handler {
	return &traceHandler{Handler: h.Handler.WithGroup(name), projectID: h.projectID}
}
