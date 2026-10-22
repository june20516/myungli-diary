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
	// ErrProviderTaken은 현재 계정에 같은 제공자의 다른 사용자 연결이 이미 있어 붙이지 못할 때 돌려줍니다(409 auth.provider_taken).
	ErrProviderTaken = errors.New("auth: provider already linked")
	// ErrIdentityInUse는 붙이려는 연결이 다른 유저 계정에 있을 때 돌려줍니다(409 auth.identity_in_use, S110).
	ErrIdentityInUse = errors.New("auth: identity in use by another account")
	// ErrLastIdentity는 계정의 마지막 연결을 떼려 할 때 돌려줍니다(409 auth.last_identity).
	ErrLastIdentity = errors.New("auth: last identity")
	// ErrIdentityNotFound는 현재 계정에 떼려는 제공자 연결이 없을 때 돌려줍니다(404 auth.identity_not_found).
	ErrIdentityNotFound = errors.New("auth: identity not found")
	// ErrInvalidProof는 붙이기 증명의 필드 조합이 그 제공자에 맞지 않을 때 돌려줍니다(400 request.invalid).
	// 실제로는 어느 필드가 문제인지 담은 *InvalidProofError로 돌려주며, errors.Is(err, ErrInvalidProof)가 참입니다.
	ErrInvalidProof = errors.New("auth: invalid link proof")
)

// 증명 조합 오류의 Code 값입니다. request.invalid의 JSON Schema 키워드와 같습니다.
const (
	proofCodeRequired             = "required"
	proofCodeAdditionalProperties = "additionalProperties"
)

// InvalidProofError는 붙이기 증명에서 문제가 된 필드 하나입니다.
// Field는 요청 본문 기준 JSON Pointer("/idToken")이고, Code는 "required"(없음)·"additionalProperties"(그 제공자가 쓰지 않음)입니다.
type InvalidProofError struct {
	Field string
	Code  string
}

func (e *InvalidProofError) Error() string {
	return "auth: invalid link proof: " + e.Field + " " + e.Code
}

// Is는 errors.Is(err, ErrInvalidProof)가 참이 되게 합니다.
func (e *InvalidProofError) Is(target error) bool {
	return target == ErrInvalidProof
}
