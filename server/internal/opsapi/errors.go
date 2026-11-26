package opsapi

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5/pgconn"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/ops"
)

// 오류 응답의 code입니다.
const (
	codeInvalidInput    = "invalid_input"
	codeUnauthenticated = "unauthenticated"
	codeForbidden       = "forbidden"
	codeNotFound        = "not_found"
	codeProfileNotFound = "profile_not_found"
	codeConflict        = "conflict"
	codeUnavailable     = "unavailable"
	codeInternal        = "internal"
)

// internalMessage는 500 응답의 고정 문구입니다. 내부 오류 원문은 응답에도 로그에도 넣지 않습니다.
const internalMessage = "내부 오류입니다"

// errorResponse는 오류 응답 본문입니다.
type errorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// apiError는 상태 코드와 응답 본문을 가진 오류입니다.
type apiError struct {
	status int
	body   errorResponse
}

func (e *apiError) Error() string { return e.body.Code }

func newAPIError(status int, code, message string) *apiError {
	return &apiError{status: status, body: errorResponse{Code: code, Message: message}}
}

// inputErrorf는 400 invalid_input 오류를 만듭니다.
func inputErrorf(format string, args ...any) *apiError {
	return newAPIError(http.StatusBadRequest, codeInvalidInput, fmt.Sprintf(format, args...))
}

// writeJSON은 JSON 응답을 씁니다. 모든 응답은 캐시하지 않습니다.
func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body) //nolint:errchkjson // 응답 쓰기 실패는 호출자가 할 수 있는 일이 없습니다.
}

func writeError(w http.ResponseWriter, e *apiError) {
	writeJSON(w, e.status, e.body)
}

// classify는 Service 오류를 API 오류로 바꿉니다. 모르는 오류는 ok=false이고 500으로 다룹니다.
// 문구는 모두 정해진 한국어 문장이거나 계정 id뿐이라 개인정보를 담지 않습니다.
func classify(err error) (*apiError, bool) {
	var apiErr *apiError
	if errors.As(err, &apiErr) {
		return apiErr, true
	}
	var ambiguous ops.AmbiguousTransactionError
	if errors.As(err, &ambiguous) {
		ids := make([]string, len(ambiguous.AccountIDs))
		for i, id := range ambiguous.AccountIDs {
			ids[i] = id.String()
		}
		return newAPIError(http.StatusConflict, codeConflict,
			fmt.Sprintf("%s: %s", ambiguous.Error(), strings.Join(ids, ", "))), true
	}
	for _, input := range []error{
		ops.ErrReason, ops.ErrPurpose, ops.ErrActor, ops.ErrAccountKey, ops.ErrStoreTransaction,
		ops.ErrAuditFilter, ops.ErrGrantPeriod, ops.ErrGrantKind, ops.ErrContentTarget,
	} {
		if errors.Is(err, input) {
			return newAPIError(http.StatusBadRequest, codeInvalidInput, input.Error()), true
		}
	}
	switch {
	case errors.Is(err, ops.ErrAccountNotFound):
		return newAPIError(http.StatusNotFound, codeNotFound, ops.ErrAccountNotFound.Error()), true
	case errors.Is(err, billing.ErrGrantNotFound):
		return newAPIError(http.StatusNotFound, codeNotFound, billing.ErrGrantNotFound.Error()), true
	case errors.Is(err, ops.ErrProfileNotFound):
		return newAPIError(http.StatusNotFound, codeProfileNotFound, ops.ErrProfileNotFound.Error()), true
	}
	for _, conflict := range []error{billing.ErrAccountNotActive, billing.ErrGrantNotRevocable, billing.ErrGrantAlreadyEnded} {
		if errors.Is(err, conflict) {
			return newAPIError(http.StatusConflict, codeConflict, conflict.Error()), true
		}
	}
	return nil, false
}

// errorKind는 500 로그에 남길 오류 종류입니다. 원문 대신 SQLSTATE나 타입 이름만 씁니다.
func errorKind(err error) string {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return "sqlstate:" + pgErr.Code
	}
	return fmt.Sprintf("%T", err)
}
