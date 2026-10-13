package httpapi_test

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

const (
	contentTypeJSON       = "application/json"
	contentTypeMergePatch = "application/merge-patch+json"
	contentTypeForm       = "application/x-www-form-urlencoded"
)

// newAPIHandler는 계약 라우트 전체를 미구현 핸들러로 등록한 Handler를 만듭니다.
// bearer 라우트는 토큰을 보지 않고 고정 계정(active, 동의 완료)을 ctx에 넣어 통과시키므로,
// 계약 검증과 라우팅만 확인하는 테스트가 인증을 신경 쓰지 않아도 됩니다.
func newAPIHandler(t *testing.T) (http.Handler, *bytes.Buffer) {
	t.Helper()
	spec, err := gen.GetSpec()
	if err != nil {
		t.Fatalf("계약 읽기: %v", err)
	}
	deps, logs := newTestDeps()
	routes := httpapi.Routes{
		Spec:         spec,
		Validate:     httpapi.ValidateRequests(spec, deps.Logger),
		Authenticate: authenticateFixedAccount,
	}
	handler := httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, httpapi.Unimplemented{}, deps, routes)
	})
	return handler, logs
}

// fixedAccountID는 authenticateFixedAccount가 ctx에 넣는 계정 id입니다.
var fixedAccountID = uuid.MustParse("0192f0a0-0000-7000-8000-0000000000aa")

// authenticateFixedAccount는 토큰 검사 없이 fixedAccountID와 active 상태를 ctx에 넣는 Authenticate입니다.
func authenticateFixedAccount(_ httpapi.Operation, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := httpapi.WithAccount(r.Context(), fixedAccountID, account.Access{Status: account.StatusActive})
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func newBodyRequest(t *testing.T, method, target, contentType, body string) *http.Request {
	t.Helper()
	req := httptest.NewRequestWithContext(t.Context(), method, target, strings.NewReader(body))
	req.Header.Set("Content-Type", contentType)
	return req
}

// fieldsOf는 problem의 errors[].field 목록입니다.
func fieldsOf(p problem.Problem) []string {
	fields := make([]string, 0, len(p.Errors))
	for _, fieldError := range p.Errors {
		fields = append(fields, fieldError.Field)
	}
	return fields
}

// expectInvalid는 400 request.invalid이고 errors에 field가 있는지 확인합니다.
func expectInvalid(t *testing.T, rec *httptest.ResponseRecorder, field string) {
	t.Helper()
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400, body = %s", rec.Code, rec.Body.String())
	}
	p := decodeProblem(t, rec)
	if p.Code != "request.invalid" {
		t.Errorf("code = %q, want request.invalid", p.Code)
	}
	if !slices.Contains(fieldsOf(p), field) {
		t.Errorf("errors[].field = %v, want %q 포함", fieldsOf(p), field)
	}
	for _, fieldError := range p.Errors {
		if fieldError.Code == "" {
			t.Errorf("errors[].code가 비어 있습니다: %+v", p.Errors)
		}
	}
	if got := rec.Header().Get("WWW-Authenticate"); got != "" {
		t.Errorf("WWW-Authenticate = %q, want empty", got)
	}
}

const validBirth = `{"calendar":"solar","date":{"year":1990,"month":5,"day":17},"isLeapMonth":false,` +
	`"time":{"status":"known","value":"07:30"},"gender":"female","timezone":"Asia/Seoul","place":{"status":"not_asked"}}`

// profileWithNotificationTime은 알림 시각만 바꾼 유효한 프로필 본문입니다.
func profileWithNotificationTime(clock string) string {
	return `{"honorific":"민지","language":"ko","currentTimezone":"Asia/Seoul","birth":` + validBirth +
		`,"notification":{"status":"enabled","time":"` + clock + `"}}`
}

func TestAPI_ValidRequestReturns501(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil))

	if rec.Code != http.StatusNotImplemented {
		t.Fatalf("status = %d, want 501, body = %s", rec.Code, rec.Body.String())
	}
	if p := decodeProblem(t, rec); p.Code != "not_implemented" {
		t.Errorf("code = %q, want not_implemented", p.Code)
	}
}

func TestAPI_InvalidDatePathReturns400(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/daily/2026-13-40", nil))

	expectInvalid(t, rec, "date")
}

// format: date 정규식은 2026-02-30을 통과시키므로, 생성 코드가 Go 타입으로 바꿀 때 400이 되어야 합니다.
// expectFormatViolation은 400 request.invalid이고 errors가 정확히 [{field, code: "format"}]인지 확인합니다.
func expectFormatViolation(t *testing.T, rec *httptest.ResponseRecorder, field string) {
	t.Helper()
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400, body = %s", rec.Code, rec.Body.String())
	}
	p := decodeProblem(t, rec)
	if p.Code != "request.invalid" {
		t.Errorf("code = %q, want request.invalid", p.Code)
	}
	want := []problem.FieldError{{Field: field, Code: "format"}}
	if !slices.Equal(p.Errors, want) {
		t.Errorf("errors = %+v, want %+v", p.Errors, want)
	}
}

// 달력에 없는 날짜는 생성 코드 디코드가 아니라 검증 단계에서 format 위반으로 잡힙니다.
func TestAPI_NonexistentDateReturns400(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/daily/2026-02-30", nil))
	expectFormatViolation(t, rec, "date")

	rec = serve(handler, newBodyRequest(t, http.MethodPost, "/v1/schedules", contentTypeJSON, `{"date":"2026-02-30","allDay":true,"title":"점심"}`))
	expectFormatViolation(t, rec, "/date")
}

// 윤일은 윤년에만 유효합니다.
func TestAPI_LeapDayIsValidOnlyInLeapYears(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/daily/2028-02-29", nil))
	if rec.Code != http.StatusNotImplemented {
		t.Errorf("2028-02-29 status = %d, want 501, body = %s", rec.Code, rec.Body.String())
	}

	rec = serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/daily/2027-02-29", nil))
	expectFormatViolation(t, rec, "date")
}

func TestAPI_InvalidQueryReturns400WithParameterName(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/diaries?limit=0", nil))

	expectInvalid(t, rec, "limit")
}

func TestAPI_MissingRequiredQueryReturns400(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/schedules?from=2026-10-01", nil))

	expectInvalid(t, rec, "to")
}

func TestAPI_MissingRequiredFieldReturns400(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, newBodyRequest(t, http.MethodPut, "/v1/diaries/2026-10-11", contentTypeJSON, `{}`))

	expectInvalid(t, rec, "/body")
}

func TestAPI_NestedFieldErrorUsesJSONPointer(t *testing.T) {
	handler, _ := newAPIHandler(t)
	body := strings.Replace(profileWithNotificationTime("07:05"), `"day":17`, `"day":40`, 1)

	rec := serve(handler, newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, body))

	expectInvalid(t, rec, "/birth/date/day")
}

func TestAPI_WrongContentTypeReturns415(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, newBodyRequest(t, http.MethodPut, "/v1/diaries/2026-10-11", "text/plain", `{"body":"오늘"}`))

	if rec.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("status = %d, want 415, body = %s", rec.Code, rec.Body.String())
	}
	if p := decodeProblem(t, rec); p.Code != "request.unsupported_media_type" {
		t.Errorf("code = %q", p.Code)
	}
}

// 415 판정은 요청 media type(파라미터 제외)이 계약 content에 있는지로 합니다.
func TestAPI_ContentTypeIsJudgedByMediaType(t *testing.T) {
	handler, _ := newAPIHandler(t)
	cases := []struct {
		name, contentType, body string
		want                    int
	}{
		{"charset 파라미터는 무시", "application/json; charset=utf-8", `{"body":"오늘"}`, http.StatusNotImplemented},
		{"Content-Type 없음", "", `{"body":"오늘"}`, http.StatusUnsupportedMediaType},
		{"PUT에 merge-patch", contentTypeMergePatch, `{"body":"오늘"}`, http.StatusUnsupportedMediaType},
		{"빈 본문은 형식과 관계없이 400", "text/plain", "", http.StatusBadRequest},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequestWithContext(t.Context(), http.MethodPut, "/v1/diaries/2026-10-11", strings.NewReader(tc.body))
			if tc.contentType != "" {
				req.Header.Set("Content-Type", tc.contentType)
			}

			rec := serve(handler, req)

			if rec.Code != tc.want {
				t.Fatalf("status = %d, want %d, body = %s", rec.Code, tc.want, rec.Body.String())
			}
		})
	}
}

// 계약 router가 라우트를 찾지 못하면 404 problem을 쓰고, 요청 값 없이 오류 타입과 route 패턴만 로그로 남깁니다.
func TestValidateRequests_UnknownContractRouteIsLogged(t *testing.T) {
	spec, err := gen.GetSpec()
	if err != nil {
		t.Fatalf("계약 읽기: %v", err)
	}
	deps, logs := newTestDeps()
	validate := httpapi.ValidateRequests(spec, deps.Logger)
	called := false
	handler := httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		// ServeMux에는 있지만 계약에는 없는 라우트로 계약 router의 미발견 경로를 만듭니다.
		mux.Handle("GET /v1/extra/{id}", validate(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { called = true })))
	})

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/extra/secret-id?token=secret-value", nil))

	if rec.Code != http.StatusNotFound || called {
		t.Fatalf("status = %d, called = %v, want 404 and 핸들러 미호출", rec.Code, called)
	}
	if p := decodeProblem(t, rec); p.Code != "route.not_found" {
		t.Errorf("code = %q", p.Code)
	}
	var entry map[string]any
	if err := json.Unmarshal([]byte(strings.SplitN(logs.String(), "\n", 2)[0]), &entry); err != nil {
		t.Fatalf("로그 파싱: %v, logs = %q", err, logs.String())
	}
	if entry["severity"] != "ERROR" || entry["route"] != "GET /v1/extra/{id}" || entry["errorType"] == nil {
		t.Errorf("로그 = %v, want ERROR·route 패턴·errorType", entry)
	}
	if strings.Contains(logs.String(), "secret-id") || strings.Contains(logs.String(), "secret-value") {
		t.Errorf("로그에 요청 값이 남음: %q", logs.String())
	}
}

func TestAPI_MalformedJSONReturns400Malformed(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, newBodyRequest(t, http.MethodPut, "/v1/diaries/2026-10-11", contentTypeJSON, `{"body":`))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400, body = %s", rec.Code, rec.Body.String())
	}
	if p := decodeProblem(t, rec); p.Code != "request.malformed" {
		t.Errorf("code = %q, want request.malformed", p.Code)
	}
}

// DecodeJSON과 같게 JSON 값 하나만 허용합니다.
func TestAPI_TrailingDataReturns400Malformed(t *testing.T) {
	handler, _ := newAPIHandler(t)
	cases := []struct {
		name, method, target, contentType string
	}{
		{"json", http.MethodPut, "/v1/diaries/2026-10-11", contentTypeJSON},
		{"merge-patch", http.MethodPatch, "/v1/schedules/" + scheduleID, contentTypeMergePatch},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := serve(handler, newBodyRequest(t, tc.method, tc.target, tc.contentType, `{"body":"a","title":"a"} {}`))

			if rec.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400, body = %s", rec.Code, rec.Body.String())
			}
			if p := decodeProblem(t, rec); p.Code != "request.malformed" {
				t.Errorf("code = %q, want request.malformed", p.Code)
			}
		})
	}
}

func TestAPI_BodyTooLargeReturns413(t *testing.T) {
	handler, _ := newAPIHandler(t)
	// Content-Length를 알 수 없는 스트림으로 보내 검증이 본문을 읽는 도중 상한에 걸리게 합니다.
	body := io.MultiReader(strings.NewReader(`{"body":"`), strings.NewReader(strings.Repeat("x", 2<<20)), strings.NewReader(`"}`))
	req := httptest.NewRequestWithContext(t.Context(), http.MethodPut, "/v1/diaries/2026-10-11", body)
	req.Header.Set("Content-Type", contentTypeJSON)
	req.ContentLength = -1

	rec := serve(handler, req)

	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status = %d, want 413, body = %s", rec.Code, rec.Body.String())
	}
	if p := decodeProblem(t, rec); p.Code != "request.too_large" {
		t.Errorf("code = %q", p.Code)
	}
}

func TestAPI_NotificationTimeGranularity(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:03")))

	expectInvalid(t, rec, "/notification/time")
}

func TestAPI_MergePatchBodiesAreAccepted(t *testing.T) {
	handler, _ := newAPIHandler(t)
	cases := []struct {
		name   string
		target string
		body   string
	}{
		{"updateProfile", "/v1/me/profile", `{"honorific":"민지"}`},
		{"updateSchedule", "/v1/schedules/0b6f8b52-3a4f-4f0e-9f57-0d2f7c3c1a10", `{"title":"점심"}`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := serve(handler, newBodyRequest(t, http.MethodPatch, tc.target, contentTypeMergePatch, tc.body))

			if rec.Code != http.StatusNotImplemented {
				t.Fatalf("status = %d, want 501, body = %s", rec.Code, rec.Body.String())
			}
		})
	}
}

func TestAPI_MergePatchBodyIsValidated(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, newBodyRequest(t, http.MethodPatch, "/v1/me/profile", contentTypeMergePatch, `{"honorific":""}`))

	expectInvalid(t, rec, "/honorific")
}

// ServeMux는 GET 라우트로 HEAD도 받으므로, 검증은 HEAD를 GET으로 바꾼 사본으로 검증하고 그 사본을 핸들러에 넘깁니다.
// 그래야 HEAD로 검증을 우회하는 경로가 생기지 않습니다.
func TestAPI_HeadIsValidatedLikeGet(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodHead, "/v1/daily/2026-13-40", nil))
	if rec.Code != http.StatusBadRequest {
		t.Errorf("잘못된 날짜 status = %d, want 400", rec.Code)
	}

	// 검증을 통과한 HEAD는 경로 값을 그대로 가진 채 핸들러에 닿습니다.
	rec = serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodHead, "/v1/daily/2026-10-11", nil))
	if rec.Code != http.StatusNotImplemented {
		t.Errorf("유효한 날짜 status = %d, want 501", rec.Code)
	}
}

func TestAPI_UnknownRouteStaysProblem404(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/nope", nil))

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
	if p := decodeProblem(t, rec); p.Code != "route.not_found" {
		t.Errorf("code = %q", p.Code)
	}
}

func TestAPI_WrongMethodStaysProblem405(t *testing.T) {
	handler, _ := newAPIHandler(t)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/v1/me", nil))

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want 405", rec.Code)
	}
	if p := decodeProblem(t, rec); p.Code != "method.not_allowed" {
		t.Errorf("code = %q", p.Code)
	}
}

func TestAPI_AccessLogUsesContractRoute(t *testing.T) {
	handler, logs := newAPIHandler(t)

	serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/diaries/2026-10-11", nil))

	if got := lastAccessLog(t, logs)["route"]; got != "GET /v1/diaries/{date}" {
		t.Errorf("route = %v", got)
	}
}

func TestNewHandler_HealthzIsOnlyContractRoute(t *testing.T) {
	handler, _ := newTestHandler(t, nil)

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/healthz", nil))

	if rec.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (healthz는 RegisterAPI가 등록합니다)", rec.Code)
	}
}

// operationRequest는 operation 하나에 보낼 유효한 최소 요청입니다.
type operationRequest struct {
	method, target, contentType, body string
}

const scheduleID = "0b6f8b52-3a4f-4f0e-9f57-0d2f7c3c1a10"

// minimalRequests는 계약의 모든 operation에 대한 유효한 최소 요청입니다.
var minimalRequests = map[string]operationRequest{
	"loginKakao":     {http.MethodPost, "/v1/auth/kakao", contentTypeJSON, `{"idToken":"t","nonce":"nonce-0123456789ab"}`},
	"loginApple":     {http.MethodPost, "/v1/auth/apple", contentTypeJSON, `{"idToken":"t","authorizationCode":"c","nonce":"nonce-0123456789ab","clientType":"native"}`},
	"appleCallback":  {http.MethodPost, "/v1/auth/apple/callback", contentTypeForm, `code=c&id_token=t&state=s`},
	"refreshToken":   {http.MethodPost, "/v1/auth/refresh", contentTypeJSON, `{"refreshToken":"r"}`},
	"logout":         {http.MethodPost, "/v1/auth/logout", contentTypeJSON, `{"refreshToken":"r"}`},
	"getMe":          {http.MethodGet, "/v1/me", "", ""},
	"deleteMe":       {http.MethodDelete, "/v1/me", "", ""},
	"agreeConsents":  {http.MethodPost, "/v1/me/consents", contentTypeJSON, `{"documents":[{"document":"terms","version":"1"}]}`},
	"createProfile":  {http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05")},
	"updateProfile":  {http.MethodPatch, "/v1/me/profile", contentTypeMergePatch, `{"honorific":"민지"}`},
	"getDaily":       {http.MethodGet, "/v1/daily/2026-10-11", "", ""},
	"getChart":       {http.MethodGet, "/v1/chart", "", ""},
	"getCalendar":    {http.MethodGet, "/v1/calendar/2026/10", "", ""},
	"putReaction":    {http.MethodPut, "/v1/daily/2026-10-11/slots/daily.fortune.head/reaction", contentTypeJSON, `{"reaction":"like"}`},
	"deleteReaction": {http.MethodDelete, "/v1/daily/2026-10-11/slots/daily.fortune.head/reaction", "", ""},
	"getGlossary":    {http.MethodGet, "/v1/glossary", "", ""},
	"createPreview": {http.MethodPost, "/v1/preview", contentTypeJSON,
		`{"installationId":"i","currentTimezone":"Asia/Seoul","birth":` + validBirth + `}`},
	"getBirthHour": {http.MethodPost, "/v1/birth-hour", contentTypeJSON,
		`{"installationId":"i","calendar":"solar","date":{"year":1990,"month":5,"day":17},"isLeapMonth":false,"time":"07:30"}`},
	"listDiaries":       {http.MethodGet, "/v1/diaries", "", ""},
	"getDiary":          {http.MethodGet, "/v1/diaries/2026-10-11", "", ""},
	"putDiary":          {http.MethodPut, "/v1/diaries/2026-10-11", contentTypeJSON, `{"body":"오늘"}`},
	"deleteDiary":       {http.MethodDelete, "/v1/diaries/2026-10-11", "", ""},
	"restoreDiary":      {http.MethodPost, "/v1/diaries/2026-10-11/restore", "", ""},
	"listSchedules":     {http.MethodGet, "/v1/schedules?from=2026-10-01&to=2026-10-31", "", ""},
	"createSchedule":    {http.MethodPost, "/v1/schedules", contentTypeJSON, `{"date":"2026-10-11","allDay":true,"title":"점심"}`},
	"updateSchedule":    {http.MethodPatch, "/v1/schedules/" + scheduleID, contentTypeMergePatch, `{"title":"점심"}`},
	"deleteSchedule":    {http.MethodDelete, "/v1/schedules/" + scheduleID, "", ""},
	"restoreSchedule":   {http.MethodPost, "/v1/schedules/" + scheduleID + "/restore", "", ""},
	"registerDevice":    {http.MethodPost, "/v1/devices", contentTypeJSON, `{"fcmToken":"f","platform":"ios"}`},
	"deleteDevice":      {http.MethodDelete, "/v1/devices/" + scheduleID, "", ""},
	"getEntitlements":   {http.MethodGet, "/v1/me/entitlements", "", ""},
	"restorePurchases":  {http.MethodPost, "/v1/billing/restore", "", ""},
	"revenuecatWebhook": {http.MethodPost, "/webhooks/revenuecat", contentTypeJSON, `{"event":{"type":"TEST"}}`},
	"admobRewardCallback": {http.MethodGet,
		"/webhooks/admob-ssv?ad_network=1&key_id=3335741209&signature=MEUCIQ&timestamp=1507770365237823&transaction_id=18fa792de1bca816048293fc71035638", "", ""},
	"listCities":   {http.MethodGet, "/v1/cities?q=Seoul", "", ""},
	"getAppConfig": {http.MethodGet, "/v1/app-config", "", ""},
	"getHealth":    {http.MethodGet, "/healthz", "", ""},
}

func TestAPI_EveryOperationIsRouted(t *testing.T) {
	spec, err := gen.GetSpec()
	if err != nil {
		t.Fatalf("계약 읽기: %v", err)
	}
	handler, _ := newAPIHandler(t)

	// oapi-codegen은 내장 spec의 operationId 첫 글자를 대문자로 바꾸므로 계약 표기(lowerCamel)로 되돌립니다.
	var operationIDs []string
	for _, pathItem := range spec.Paths.Map() {
		for _, op := range pathItem.Operations() {
			operationIDs = append(operationIDs, strings.ToLower(op.OperationID[:1])+op.OperationID[1:])
		}
	}
	if len(operationIDs) != len(minimalRequests) {
		t.Errorf("operation %d개, 최소 요청 %d개", len(operationIDs), len(minimalRequests))
	}

	for _, operationID := range operationIDs {
		t.Run(operationID, func(t *testing.T) {
			fixture, ok := minimalRequests[operationID]
			if !ok {
				t.Fatalf("최소 요청이 없습니다")
			}
			var req *http.Request
			if fixture.body == "" {
				req = httptest.NewRequestWithContext(t.Context(), fixture.method, fixture.target, nil)
			} else {
				req = newBodyRequest(t, fixture.method, fixture.target, fixture.contentType, fixture.body)
			}

			rec := serve(handler, req)

			want := http.StatusNotImplemented
			if operationID == "getHealth" {
				want = http.StatusOK
			}
			if rec.Code != want {
				t.Fatalf("status = %d, want %d, body = %s", rec.Code, want, rec.Body.String())
			}
		})
	}
}

// TestValidateRequests_KeepsRawQueryAndBody는 검증이 원본 쿼리 문자열과 본문을 바꾸지 않는지 확인합니다.
// admobRewardCallback은 원본 쿼리 문자열로 서명을 검증하므로 순서·인코딩이 그대로여야 합니다.
func TestValidateRequests_KeepsRawQueryAndBody(t *testing.T) {
	spec, err := gen.GetSpec()
	if err != nil {
		t.Fatalf("계약 읽기: %v", err)
	}
	var gotQuery, gotBody string
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotQuery = r.URL.RawQuery
		data, _ := io.ReadAll(r.Body)
		gotBody = string(data)
		w.WriteHeader(http.StatusNoContent)
	})
	deps, _ := newTestDeps()
	handler := httpapi.ValidateRequests(spec, deps.Logger)(next)

	rawQuery := "transaction_id=t%2Bx&timestamp=1&key_id=1&signature=s%3D%3D&custom_data=a+b"
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/webhooks/admob-ssv?"+rawQuery, nil))
	if rec.Code != http.StatusNoContent || gotQuery != rawQuery {
		t.Errorf("status = %d, RawQuery = %q, want %q", rec.Code, gotQuery, rawQuery)
	}

	// limit에는 default가 있지만 검증은 쿼리에 채워 넣지 않습니다.
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/diaries", nil))
	if rec.Code != http.StatusNoContent || gotQuery != "" {
		t.Errorf("status = %d, RawQuery = %q, want empty", rec.Code, gotQuery)
	}

	body := `{"body":"오늘"}`
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, newBodyRequest(t, http.MethodPut, "/v1/diaries/2026-10-11", contentTypeJSON, body))
	if rec.Code != http.StatusNoContent || gotBody != body {
		t.Errorf("status = %d, body = %q, want %q", rec.Code, gotBody, body)
	}
}
