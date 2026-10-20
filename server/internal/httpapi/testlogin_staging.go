//go:build staging

package httpapi

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/json"
	"net/http"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// staging E2E 테스트 로그인(S24, spec §13.2)입니다. 이 파일은 build tag staging에만 있어 prod 바이너리에는
// 라우트와 핸들러가 없습니다(prod 빌드는 testlogin_prod.go의 빈 구현). REST 계약 밖이라 staticRoutes로 등록합니다.

// testLoginPath는 테스트 로그인 경로입니다.
const testLoginPath = "/test/v1/auth/login"

// testLoginSecretHeader는 TEST_LOGIN_SECRET과 비교하는 요청 헤더입니다.
const testLoginSecretHeader = "X-Test-Login-Secret" //nolint:gosec // 헤더 이름이며 비밀 값이 아닙니다

// TestLoginService는 테스트 로그인 핸들러가 쓰는 인증 서비스입니다. staging 빌드의 *auth.Service가 만족합니다.
type TestLoginService interface {
	LoginTest(ctx context.Context, label string) (auth.LoginResult, error)
}

var _ TestLoginService = (*auth.Service)(nil)

// testLoginHolder는 API에 embed되는 테스트 로그인 상태입니다. EnableTestLogin만 채우고, nil이면 라우트를 등록하지 않습니다.
type testLoginHolder struct {
	testLogin *testLoginState
}

// testLoginState는 켜진 테스트 로그인의 비밀(SHA-256)과 서비스입니다.
type testLoginState struct {
	// secretHash는 비밀의 SHA-256입니다. 길이가 같은 값끼리 상수 시간으로 비교하려고 원문 대신 둡니다.
	secretHash [sha256.Size]byte
	service    TestLoginService
}

// EnableTestLogin은 테스트 로그인 라우트를 켭니다. RegisterAPI 전에 불러야 하며, serve 조립이 staging 빌드에서만 부릅니다.
// 비밀이나 서비스가 비어 있으면 시작 시점의 조립 버그이므로 panic합니다(비밀 형식은 config.LoadTestLogin이 검사합니다).
func (a *API) EnableTestLogin(secret string, service TestLoginService) {
	if secret == "" || service == nil {
		panic("httpapi.API: EnableTestLogin에는 비밀과 서비스가 모두 있어야 합니다")
	}
	a.testLogin = &testLoginState{secretHash: sha256.Sum256([]byte(secret)), service: service}
}

// testLoginRoutes는 테스트 로그인이 켜져 있으면 그 경로 하나를 돌려줍니다.
// 메서드 없이 등록해, 비밀이 틀린 요청은 메서드와 관계없이 404를 받습니다(405로 경로의 존재를 드러내지 않음).
func (a *API) testLoginRoutes() []staticRoute {
	state := a.testLogin
	if state == nil {
		return nil
	}
	return []staticRoute{{pattern: testLoginPath, handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		a.serveTestLogin(state, w, r)
	})}}
}

// secretMatches는 헤더 값이 비밀과 같은지 상수 시간으로 비교합니다. 두 값을 SHA-256으로 맞춰 길이도 드러내지 않습니다.
func (s *testLoginState) secretMatches(got string) bool {
	gotHash := sha256.Sum256([]byte(got))
	return subtle.ConstantTimeCompare(gotHash[:], s.secretHash[:]) == 1
}

// testLoginRequest는 테스트 로그인 본문입니다. 없음·null·타입 오류를 구분하려고 원문으로 받습니다.
type testLoginRequest struct {
	Label json.RawMessage `json:"label"`
}

// serveTestLogin은 비밀을 먼저 확인하고(틀리면 404 route.not_found), label로 테스트 계정에 로그인해
// 정상 로그인과 같은 LoginResponse를 돌려줍니다. 비밀과 label은 로그에 남기지 않습니다.
func (a *API) serveTestLogin(state *testLoginState, w http.ResponseWriter, r *http.Request) {
	if !state.secretMatches(r.Header.Get(testLoginSecretHeader)) {
		writeRouteNotFound(w, r)
		return
	}
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		problem.Write(w, r, problem.MethodNotAllowed.Problem("Method not allowed"))
		return
	}

	var body testLoginRequest
	if !DecodeJSON(w, r, &body) {
		return
	}
	label, fieldCode := testLoginLabel(body.Label)
	if fieldCode != "" {
		p := problem.RequestInvalid.Problem("Request does not match the contract")
		p.Errors = []problem.FieldError{{Field: "/label", Code: fieldCode}}
		problem.Write(w, r, p)
		return
	}

	logger := a.logger()
	deps := Deps{Logger: logger}
	res, err := state.service.LoginTest(r.Context(), label)
	if err != nil {
		writeHandlerError(deps, w, r, err)
		return
	}
	response, err := a.loginResponse(r.Context(), res)
	if err != nil {
		writeHandlerError(deps, w, r, err)
		return
	}
	encoded, err := json.Marshal(response)
	if err != nil {
		writeHandlerError(deps, w, r, err)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	// 토큰이 담긴 응답이라 어디에도 캐시하지 않습니다.
	w.Header().Set("Cache-Control", "no-store")
	writeBody(logger, w, r, encoded)
}

// testLoginLabel은 본문의 label 원문을 검사합니다. 맞으면 label과 빈 코드, 틀리면 JSON Schema keyword 이름의
// 오류 코드(required·type·pattern, 계약 검증의 errors[].code와 같은 표기)를 돌려줍니다.
func testLoginLabel(raw json.RawMessage) (label, fieldCode string) {
	if len(raw) == 0 || string(raw) == "null" {
		return "", "required"
	}
	if err := json.Unmarshal(raw, &label); err != nil {
		return "", "type"
	}
	if !auth.ValidTestLabel(label) {
		return "", "pattern"
	}
	return label, ""
}
