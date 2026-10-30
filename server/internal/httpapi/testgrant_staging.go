//go:build staging

package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// staging 테스트 광고 제거 기간(S125)입니다. 결제 없이 계정에 실제 광고 제거권과 같은 권한을 주고 거둡니다.
// build tag staging에만 있고, 테스트 로그인(S24)의 비밀 헤더로 보호합니다. REST 계약 밖이라 staticRoutes로 등록합니다.

// testGrantPath는 테스트 광고 제거 기간 경로입니다. POST는 부여, DELETE는 회수입니다.
const testGrantPath = "/test/v1/billing/ad-free"

// TestGrantService는 테스트 광고 제거 기간 핸들러가 쓰는 서비스입니다. staging 빌드의 *billing.Store가 만족합니다.
type TestGrantService interface {
	GrantTest(ctx context.Context, accountID uuid.UUID, days int) (billing.Status, error)
	RevokeTest(ctx context.Context, accountID uuid.UUID) (billing.Status, error)
}

var _ TestGrantService = (*billing.Store)(nil)

// EnableTestGrant는 테스트 광고 제거 기간 경로를 켭니다. EnableTestLogin 뒤, RegisterAPI 전에 불러야 합니다.
// 테스트 로그인이 꺼져 있거나 서비스가 비어 있으면 시작 시점의 조립 버그이므로 panic합니다.
func (a *API) EnableTestGrant(service TestGrantService) {
	if a.testLogin == nil || service == nil {
		panic("httpapi.API: EnableTestGrant에는 먼저 켠 테스트 로그인과 서비스가 있어야 합니다")
	}
	a.testGrant = service
}

// testGrantRequest는 부여 본문입니다. 없음·null·타입 오류를 구분하려고 원문으로 받습니다.
type testGrantRequest struct {
	AccountID json.RawMessage `json:"accountId"`
	Days      json.RawMessage `json:"days"`
}

// serveTestGrant는 비밀을 먼저 확인하고(틀리면 404 route.not_found), POST면 부여, DELETE면 회수한 뒤
// 계약 Entitlements와 같은 권한 상태를 돌려줍니다. 비밀은 로그에 남기지 않습니다.
func (a *API) serveTestGrant(state *testLoginState, w http.ResponseWriter, r *http.Request) {
	if !state.secretMatches(r.Header.Get(testLoginSecretHeader)) {
		writeRouteNotFound(w, r)
		return
	}
	var status billing.Status
	var err error
	switch r.Method {
	case http.MethodPost:
		accountID, days, ok := decodeTestGrant(w, r)
		if !ok {
			return
		}
		status, err = a.testGrant.GrantTest(r.Context(), accountID, days)
	case http.MethodDelete:
		accountID, ok := testGrantQueryAccountID(w, r)
		if !ok {
			return
		}
		status, err = a.testGrant.RevokeTest(r.Context(), accountID)
	default:
		w.Header().Set("Allow", http.MethodPost+", "+http.MethodDelete)
		problem.Write(w, r, problem.MethodNotAllowed.Problem("Method not allowed"))
		return
	}

	if errors.Is(err, billing.ErrTestGrantAccount) {
		writeTestGrantInvalid(w, r, "/accountId", "not_found")
		return
	}
	logger := a.logger()
	deps := Deps{Logger: logger}
	if err != nil {
		writeHandlerError(deps, w, r, err)
		return
	}
	encoded, err := json.Marshal(toEntitlements(status))
	if err != nil {
		writeHandlerError(deps, w, r, err)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	writeBody(logger, w, r, encoded)
}

// decodeTestGrant는 부여 본문을 읽고 검사합니다. 틀리면 400을 쓰고 ok = false입니다.
func decodeTestGrant(w http.ResponseWriter, r *http.Request) (accountID uuid.UUID, days int, ok bool) {
	var body testGrantRequest
	if !DecodeJSON(w, r, &body) {
		return uuid.Nil, 0, false
	}
	accountID, code := testGrantAccountID(body.AccountID)
	if code != "" {
		writeTestGrantInvalid(w, r, "/accountId", code)
		return uuid.Nil, 0, false
	}
	days, code = testGrantDays(body.Days)
	if code != "" {
		writeTestGrantInvalid(w, r, "/days", code)
		return uuid.Nil, 0, false
	}
	return accountID, days, true
}

// testGrantQueryAccountID는 회수 요청의 accountId 쿼리를 읽고 검사합니다. 틀리면 400을 쓰고 ok = false입니다.
func testGrantQueryAccountID(w http.ResponseWriter, r *http.Request) (accountID uuid.UUID, ok bool) {
	text := r.URL.Query().Get("accountId")
	if text == "" {
		writeTestGrantInvalid(w, r, "/accountId", "required")
		return uuid.Nil, false
	}
	accountID, err := uuid.Parse(text)
	if err != nil {
		writeTestGrantInvalid(w, r, "/accountId", "format")
		return uuid.Nil, false
	}
	return accountID, true
}

// testGrantAccountID는 본문의 accountId 원문을 검사합니다. 틀리면 JSON Schema keyword 이름의 코드를 돌려줍니다.
func testGrantAccountID(raw json.RawMessage) (accountID uuid.UUID, code string) {
	if len(raw) == 0 || string(raw) == "null" {
		return uuid.Nil, "required"
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return uuid.Nil, "type"
	}
	accountID, err := uuid.Parse(text)
	if err != nil {
		return uuid.Nil, "format"
	}
	return accountID, ""
}

// testGrantDays는 본문의 days 원문을 검사합니다. 1~billing.MaxTestGrantDays 정수가 아니면 코드를 돌려줍니다.
func testGrantDays(raw json.RawMessage) (days int, code string) {
	if len(raw) == 0 || string(raw) == "null" {
		return 0, "required"
	}
	if err := json.Unmarshal(raw, &days); err != nil {
		return 0, "type"
	}
	if days < 1 {
		return 0, "minimum"
	}
	if days > billing.MaxTestGrantDays {
		return 0, "maximum"
	}
	return days, ""
}

// writeTestGrantInvalid는 필드 하나의 400 request.invalid를 씁니다.
func writeTestGrantInvalid(w http.ResponseWriter, r *http.Request, field, code string) {
	p := problem.RequestInvalid.Problem("Request does not match the contract")
	p.Errors = []problem.FieldError{{Field: field, Code: code}}
	problem.Write(w, r, p)
}
