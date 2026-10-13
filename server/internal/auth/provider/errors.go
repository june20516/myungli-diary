package provider

import "errors"

var (
	// ErrTokenInvalid는 제공자 토큰이나 authorization code가 올바르지 않을 때 돌려줍니다.
	ErrTokenInvalid = errors.New("provider token invalid")
	// ErrUnavailable은 제공자에 닿지 못했거나 제공자가 일시적으로 실패했을 때 돌려줍니다.
	ErrUnavailable = errors.New("provider unavailable")
)
