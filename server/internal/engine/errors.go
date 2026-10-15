package engine

import (
	"context"
	"fmt"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// classify는 gRPC 오류를 sentinel로 바꿉니다. 상태의 상세 메시지에 입력 값이 담길 수 있어
// 원래 오류는 체인에 남기지 않고 상태 코드만 반영합니다.
// 호출자 ctx가 취소·만료됐거나 상태가 Canceled이면 엔진 탓이 아니므로 sentinel 대신 ctx 오류를 돌려줍니다.
// 엔진 쪽 3초 deadline 초과(호출자 ctx는 살아 있음)는 ErrTimeout입니다.
func classify(ctx context.Context, name string, err error) error {
	if ctxErr := callerContextError(ctx); ctxErr != nil {
		return fmt.Errorf("엔진 %s: %w", name, ctxErr)
	}
	if status.Code(err) == codes.Canceled {
		return fmt.Errorf("엔진 %s: %w", name, context.Canceled)
	}
	var sentinel error
	switch status.Code(err) {
	case codes.InvalidArgument:
		sentinel = ErrInvalidArgument
	case codes.OutOfRange:
		sentinel = ErrOutOfRange
	case codes.DeadlineExceeded:
		sentinel = ErrTimeout
	case codes.Unavailable:
		sentinel = ErrUnavailable
	default:
		sentinel = ErrInternal
	}
	return fmt.Errorf("엔진 %s: %w", name, sentinel)
}

// callerContextError는 호출자 ctx가 끝났으면 그 오류를 돌려줍니다. gRPC가 ctx의 타이머보다 먼저
// deadline을 감지해 ctx.Err()가 아직 비어 있을 수 있어, 호출자 deadline이 지났는지도 시각으로 봅니다.
func callerContextError(ctx context.Context) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if deadline, ok := ctx.Deadline(); ok && !time.Now().Before(deadline) {
		return context.DeadlineExceeded
	}
	return nil
}
