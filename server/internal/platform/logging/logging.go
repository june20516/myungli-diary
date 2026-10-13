// Package logging은 Cloud Logging이 읽는 구조화 JSON 로그와 요청 trace id를 제공합니다.
// 로그에 출생 정보, 호칭, 일기·일정 본문, 토큰, 요청 본문을 남기지 않습니다.
package logging

import (
	"context"
	"io"
	"log/slog"
	"slices"
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
	return slog.New(newTraceHandler(jsonHandler, projectID))
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

// severity는 slog 레벨을 가장 가까운 Cloud Logging 표준 severity로 바꿉니다.
func severity(level slog.Level) string {
	switch {
	case level >= slog.LevelError:
		return "ERROR"
	case level >= slog.LevelWarn:
		return "WARNING"
	case level >= slog.LevelInfo:
		return "INFO"
	default:
		return "DEBUG"
	}
}

// frame은 WithGroup 하나로 열린 범위입니다. group이 비어 있으면 최상위 범위입니다.
type frame struct {
	group string
	attrs []slog.Attr
}

// traceHandler는 ctx의 trace id를 최상위 속성으로 붙이는 slog.Handler입니다.
// WithGroup이 trace 키를 group 안으로 밀어 넣지 않도록, group·attr 연산을 직접 보관했다가
// Handle에서 중첩 group으로 조립해 base handler에 넘깁니다.
type traceHandler struct {
	base      slog.Handler
	projectID string
	frames    []frame // 항상 최상위 frame을 첫 원소로 가집니다.
}

func newTraceHandler(base slog.Handler, projectID string) *traceHandler {
	return &traceHandler{base: base, projectID: projectID, frames: []frame{{}}}
}

func (h *traceHandler) Enabled(ctx context.Context, level slog.Level) bool {
	return h.base.Enabled(ctx, level)
}

func (h *traceHandler) Handle(ctx context.Context, record slog.Record) error {
	attrs := make([]slog.Attr, 0, record.NumAttrs())
	record.Attrs(func(attr slog.Attr) bool {
		attrs = append(attrs, attr)
		return true
	})
	for i := len(h.frames) - 1; i >= 0; i-- {
		f := h.frames[i]
		attrs = append(slices.Clone(f.attrs), attrs...)
		if f.group != "" {
			attrs = []slog.Attr{{Key: f.group, Value: slog.GroupValue(attrs...)}}
		}
	}

	// 원본 record는 건드리지 않고 새 record를 만듭니다.
	out := slog.NewRecord(record.Time, record.Level, record.Message, record.PC)
	out.AddAttrs(attrs...)
	if traceID := TraceID(ctx); traceID != "" {
		out.AddAttrs(slog.String(traceIDAttr, traceID))
		if h.projectID != "" {
			out.AddAttrs(slog.String(cloudTrace, "projects/"+h.projectID+"/traces/"+traceID))
		}
	}
	return h.base.Handle(ctx, out)
}

func (h *traceHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	if len(attrs) == 0 {
		return h
	}
	frames := slices.Clone(h.frames)
	last := &frames[len(frames)-1]
	last.attrs = append(slices.Clone(last.attrs), attrs...)
	return &traceHandler{base: h.base, projectID: h.projectID, frames: frames}
}

func (h *traceHandler) WithGroup(name string) slog.Handler {
	if name == "" {
		return h
	}
	frames := append(slices.Clone(h.frames), frame{group: name})
	return &traceHandler{base: h.base, projectID: h.projectID, frames: frames}
}
