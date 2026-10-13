package auth

import "errors"

// 이 패키지가 돌려주는 도메인 오류입니다. httpapi가 errors.Is로 찾아 problem 응답으로 바꿉니다.
// 오류 문구에는 토큰·code·nonce·subject를 넣지 않습니다.
var (
	// ErrProviderTokenInvalid는 제공자 id_token이나 authorization code가 올바르지 않을 때 돌려줍니다(401 auth.provider_token_invalid).
	ErrProviderTokenInvalid = errors.New("auth: provider token invalid")
	// ErrProviderUnavailable은 제공자 장애로 로그인을 끝내지 못했을 때 돌려줍니다(503 auth.provider_unavailable).
	ErrProviderUnavailable = errors.New("auth: provider unavailable")
	// ErrRefreshInvalid는 refresh token이 없거나 만료·폐기됐거나 계정이 active가 아닐 때 돌려줍니다(401 auth.token_invalid).
	ErrRefreshInvalid = errors.New("auth: refresh token invalid")
	// ErrRefreshReused는 이미 쓴 refresh token이 다시 와서 그 family를 폐기했을 때 돌려줍니다(401 auth.refresh_reused).
	ErrRefreshReused = errors.New("auth: refresh token reused")
	// ErrExchangeInvalid는 Apple 웹 로그인 교환 코드가 없거나 만료됐거나 이미 쓰였거나 nonce가 맞지 않을 때 돌려줍니다
	// (401 auth.exchange_invalid). 넷을 구분하지 않아 교환 코드의 상태를 드러내지 않습니다.
	ErrExchangeInvalid = errors.New("auth: exchange code invalid")
)
