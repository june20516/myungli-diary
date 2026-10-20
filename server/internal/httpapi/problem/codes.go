package problem

import "net/http"

// Code는 응답의 problem `code` 값과, 그 code가 항상 함께 가는 HTTP 상태입니다.
//
// server가 내보내는 모든 code는 이 파일에 모읍니다. 계약(api/openapi.yaml)의
// Problem.code `x-problem-codes`와 같은 목록이며, internal/httpapi의 테스트가 둘을 대조합니다.
// code를 더하거나 바꾸면 계약과 server spec §11.2·§11.3 표도 함께 고칩니다.
type Code struct {
	// Value는 응답 본문의 `code` 문자열입니다(예 "request.invalid").
	Value string
	// Status는 이 code를 내보낼 때 쓰는 HTTP 상태입니다.
	Status int
}

// Problem은 이 code의 상태로 Problem을 만듭니다. title은 개발자용 영어 제목입니다.
func (c Code) Problem(title string) Problem {
	return New(c.Status, c.Value, title)
}

// 요청 처리 (spec §11.2).
var (
	RequestMalformed         = Code{"request.malformed", http.StatusBadRequest}
	RequestInvalid           = Code{"request.invalid", http.StatusBadRequest}
	RouteNotFound            = Code{"route.not_found", http.StatusNotFound}
	MethodNotAllowed         = Code{"method.not_allowed", http.StatusMethodNotAllowed}
	RequestTooLarge          = Code{"request.too_large", http.StatusRequestEntityTooLarge}
	UnsupportedMediaType     = Code{"request.unsupported_media_type", http.StatusUnsupportedMediaType}
	DateOutOfRange           = Code{"date.out_of_range", http.StatusUnprocessableEntity}
	BirthOutOfRange          = Code{"birth.out_of_range", http.StatusUnprocessableEntity}
	DateInvalid              = Code{"date.invalid", http.StatusUnprocessableEntity}
	RequestInconsistent      = Code{"request.inconsistent", http.StatusUnprocessableEntity}
	BirthInvalid             = Code{"birth.invalid", http.StatusUnprocessableEntity}
	DiaryFutureDate          = Code{"diary.future_date", http.StatusUnprocessableEntity}
	NameEmpty                = Code{"name.empty", http.StatusUnprocessableEntity}
	NameTooLong              = Code{"name.too_long", http.StatusUnprocessableEntity}
	NameEmoji                = Code{"name.emoji", http.StatusUnprocessableEntity}
	NameControl              = Code{"name.control", http.StatusUnprocessableEntity}
	NameInvalidChar          = Code{"name.invalid_char", http.StatusUnprocessableEntity}
	IdempotencyMismatch      = Code{"idempotency.mismatch", http.StatusUnprocessableEntity}
	ConsentVersionMismatch   = Code{"consent.version_mismatch", http.StatusUnprocessableEntity}
	TimezoneInvalid          = Code{"timezone.invalid", http.StatusUnprocessableEntity}
	CityNotFound             = Code{"city.not_found", http.StatusUnprocessableEntity}
	RangeTooLong             = Code{"range.too_long", http.StatusUnprocessableEntity}
	AuthTokenExpired         = Code{"auth.token_expired", http.StatusUnauthorized}
	AuthTokenInvalid         = Code{"auth.token_invalid", http.StatusUnauthorized} //nolint:gosec // 오류 코드 문자열이며 자격 증명이 아닙니다
	AuthRefreshReused        = Code{"auth.refresh_reused", http.StatusUnauthorized}
	AuthProviderTokenInvalid = Code{"auth.provider_token_invalid", http.StatusUnauthorized}
	AuthExchangeInvalid      = Code{"auth.exchange_invalid", http.StatusUnauthorized}
	AppCheckInvalid          = Code{"app_check.invalid", http.StatusUnauthorized}
	ConsentRequired          = Code{"consent.required", http.StatusForbidden}
	PreviewUsed              = Code{"preview.used", http.StatusForbidden}
	DiaryNotFound            = Code{"diary.not_found", http.StatusNotFound}
	ReactionNotFound         = Code{"reaction.not_found", http.StatusNotFound}
	ScheduleNotFound         = Code{"schedule.not_found", http.StatusNotFound}
	DeviceNotFound           = Code{"device.not_found", http.StatusNotFound}
	ProfileRequired          = Code{"profile.required", http.StatusConflict}
	DiaryDateTaken           = Code{"diary.date_taken", http.StatusConflict}
	IdempotencyInProgress    = Code{"idempotency.in_progress", http.StatusConflict}
	RateLimited              = Code{"rate_limited", http.StatusTooManyRequests}
	NotImplemented           = Code{"not_implemented", http.StatusNotImplemented}
)

// 외부 의존과 서버 오류 (spec §11.3).
var (
	EngineUnavailable       = Code{"engine.unavailable", http.StatusServiceUnavailable}
	EngineTimeout           = Code{"engine.timeout", http.StatusGatewayTimeout}
	EngineError             = Code{"engine.error", http.StatusBadGateway}
	AuthProviderUnavailable = Code{"auth.provider_unavailable", http.StatusServiceUnavailable}
	BillingUnavailable      = Code{"billing.provider_unavailable", http.StatusServiceUnavailable}
	RewardInvalidSignature  = Code{"reward.invalid_signature", http.StatusUnauthorized}
	RewardExpired           = Code{"reward.expired", http.StatusUnauthorized}
	ServiceUnavailable      = Code{"service.unavailable", http.StatusServiceUnavailable}
	Internal                = Code{"internal", http.StatusInternalServerError}
)

// AllCodes는 server가 내보내는 모든 code입니다. 새 code는 위 var 블록과 이 목록에 함께 더합니다.
func AllCodes() []Code {
	return []Code{
		RequestMalformed, RequestInvalid, RouteNotFound, MethodNotAllowed, RequestTooLarge, UnsupportedMediaType,
		DateOutOfRange, BirthOutOfRange, DateInvalid, RequestInconsistent, BirthInvalid, DiaryFutureDate,
		NameEmpty, NameTooLong, NameEmoji, NameControl, NameInvalidChar, IdempotencyMismatch, ConsentVersionMismatch,
		TimezoneInvalid, CityNotFound, RangeTooLong,
		AuthTokenExpired, AuthTokenInvalid, AuthRefreshReused, AuthProviderTokenInvalid, AuthExchangeInvalid, AppCheckInvalid,
		ConsentRequired, PreviewUsed, DiaryNotFound, ReactionNotFound, ScheduleNotFound, DeviceNotFound, ProfileRequired, DiaryDateTaken, IdempotencyInProgress,
		RateLimited, NotImplemented,
		EngineUnavailable, EngineTimeout, EngineError, AuthProviderUnavailable, BillingUnavailable,
		RewardInvalidSignature, RewardExpired, ServiceUnavailable, Internal,
	}
}
