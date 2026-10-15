// Package engine은 명리 엔진(core, gRPC 서비스) 클라이언트와 오류 분류를 담습니다.
package engine

import (
	"context"
	"errors"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
)

// Engine은 server가 쓰는 엔진 RPC입니다. 요청·응답은 proto 타입 그대로입니다(계약이 proto).
type Engine interface {
	GetChart(ctx context.Context, req *enginev1.ChartRequest) (*enginev1.ChartResponse, error)
	GetDaily(ctx context.Context, req *enginev1.DailyRequest) (*enginev1.DailyResponse, error)
	GetMonthCalendar(ctx context.Context, req *enginev1.MonthRequest) (*enginev1.MonthResponse, error)
	GetBirthHour(ctx context.Context, req *enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error)
	GetInfo(ctx context.Context) (*enginev1.InfoResponse, error)
}

// 엔진 호출 오류의 분류입니다. 호출자는 errors.Is로 구분합니다.
var (
	ErrUnavailable     = errors.New("engine unavailable")      // UNAVAILABLE(재시도 뒤), 연결 실패
	ErrTimeout         = errors.New("engine timeout")          // DEADLINE_EXCEEDED
	ErrInternal        = errors.New("engine internal error")   // INTERNAL, 그 밖의 상태
	ErrInvalidArgument = errors.New("engine invalid argument") // INVALID_ARGUMENT
	ErrOutOfRange      = errors.New("engine out of range")     // OUT_OF_RANGE
)
