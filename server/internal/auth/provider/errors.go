package provider

import "errors"

var (
	// ErrTokenInvalid는 제공자 토큰이나 authorization code가 올바르지 않을 때 돌려줍니다.
	ErrTokenInvalid = errors.New("provider token invalid")
	// ErrUnavailable은 제공자에 닿지 못했거나 제공자가 일시적으로 실패했을 때 돌려줍니다.
	ErrUnavailable = errors.New("provider unavailable")
	// ErrKakaoNotLinked는 카카오 unlink가 "이미 앱과 연결되지 않은 사용자"라고 답했을 때 돌려줍니다.
	// 허가 취소의 목적은 이미 이뤄졌으므로 호출하는 쪽은 성공으로 다룹니다.
	ErrKakaoNotLinked = errors.New("kakao user not linked to the app")
)
