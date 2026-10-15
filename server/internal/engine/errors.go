package engine

import (
	"fmt"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// classify는 gRPC 오류를 sentinel로 바꿉니다. 상태의 상세 메시지에 입력 값이 담길 수 있어
// 원래 오류는 체인에 남기지 않고 상태 코드만 반영합니다.
func classify(name string, err error) error {
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
