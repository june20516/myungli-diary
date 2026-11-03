//go:build staging

package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// staging 보상형 광고 보상(S131)입니다. 테스트 광고에는 SSV 콜백이 오지 않아, 앱이 광고를 다 본 뒤 SSV와 같은 값을
// 로그인 토큰과 함께 보내면 서명 검증만 건너뛰고 SSV와 같은 보상 처리를 탑니다. build tag staging에만 있고
// REST 계약 밖이라 staticRoutes로 등록하며, 인증은 계약 라우트와 같은 Routes.Authenticate(BearerAuth)입니다.

// testRewardPath는 staging 보상형 광고 보상 경로입니다. POST만 받습니다.
const testRewardPath = "/test/v1/billing/rewarded-ad"

// operationTestReward는 인증 middleware에 넘기는 operation id입니다. 계약에 없는 이름이라
// 동의가 필요한 계정은 403 consent.required를 받습니다.
const operationTestReward = "testRewardedAd"

// maxTestRewardTextLength는 transactionId, adUnit, rewardItem 글자 수 상한입니다.
const maxTestRewardTextLength = 256

// TestRewardService는 staging 보상 핸들러가 쓰는 서비스입니다. staging 빌드의 *billing.TestRewards가 만족합니다.
type TestRewardService interface {
	GrantTestReward(ctx context.Context, accountID uuid.UUID, cb billing.RewardCallback) (billing.Status, error)
}

var _ TestRewardService = (*billing.TestRewards)(nil)

// EnableTestReward는 staging 보상 경로를 켭니다. RegisterAPI 전에 불러야 합니다.
// 서비스가 비어 있으면 시작 시점의 조립 버그이므로 panic합니다.
func (a *API) EnableTestReward(service TestRewardService) {
	if service == nil {
		panic("httpapi.API: EnableTestReward에는 서비스가 있어야 합니다")
	}
	a.testReward = service
}

// testRewardRoute는 POST가 아니면 405, 맞으면 authenticate를 거쳐 serveTestReward로 가는 경로입니다.
// 메서드를 인증보다 먼저 보는 것은 계약 라우트(mux의 405)와 같습니다.
func (a *API) testRewardRoute(authenticate func(Operation, http.Handler) http.Handler) staticRoute {
	authed := authenticate(Operation{ID: operationTestReward, Bearer: true}, http.HandlerFunc(a.serveTestReward))
	return staticRoute{pattern: testRewardPath, handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.Header().Set("Allow", http.MethodPost)
			problem.Write(w, r, problem.MethodNotAllowed.Problem("Method not allowed"))
			return
		}
		authed.ServeHTTP(w, r)
	})}
}

// testRewardRequest는 보상 본문입니다. 없음·null·타입 오류를 구분하려고 원문으로 받습니다.
type testRewardRequest struct {
	TransactionID json.RawMessage `json:"transactionId"`
	AdUnit        json.RawMessage `json:"adUnit"`
	RewardItem    json.RawMessage `json:"rewardItem"`
	Timestamp     json.RawMessage `json:"timestamp"`
}

// serveTestReward는 인증된 계정에 본문의 보상을 주고 계약 Entitlements와 같은 권한 상태를 돌려줍니다.
func (a *API) serveTestReward(w http.ResponseWriter, r *http.Request) {
	accountID, _, ok := AccountFrom(r.Context())
	if !ok {
		writeTokenInvalid(w, r)
		return
	}
	callback, ok := decodeTestReward(w, r)
	if !ok {
		return
	}

	logger := a.logger()
	deps := Deps{Logger: logger}
	status, err := a.testReward.GrantTestReward(r.Context(), accountID, callback)
	if errors.Is(err, billing.ErrRewardExpired) {
		writeStagingFieldInvalid(w, r, "/timestamp", "expired")
		return
	}
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

// decodeTestReward는 보상 본문을 읽고 검사합니다. 틀리면 400을 쓰고 ok = false입니다.
func decodeTestReward(w http.ResponseWriter, r *http.Request) (billing.RewardCallback, bool) {
	var body testRewardRequest
	if !DecodeJSON(w, r, &body) {
		return billing.RewardCallback{}, false
	}
	var cb billing.RewardCallback
	for _, field := range []struct {
		name     string
		raw      json.RawMessage
		required bool
		dst      *string
	}{
		{"/transactionId", body.TransactionID, true, &cb.TransactionID},
		{"/adUnit", body.AdUnit, false, &cb.AdUnit},
		{"/rewardItem", body.RewardItem, false, &cb.RewardItem},
	} {
		value, code := testRewardText(field.raw, field.required)
		if code != "" {
			writeStagingFieldInvalid(w, r, field.name, code)
			return billing.RewardCallback{}, false
		}
		*field.dst = value
	}
	timestamp, code := testRewardTimestamp(body.Timestamp)
	if code != "" {
		writeStagingFieldInvalid(w, r, "/timestamp", code)
		return billing.RewardCallback{}, false
	}
	cb.Timestamp = timestamp
	return cb, true
}

// testRewardText는 문자열 필드 원문을 검사합니다. required면 비어 있을 수 없고, 아니면 없음·null이 빈 문자열입니다.
// 틀리면 JSON Schema keyword 이름의 코드를 돌려줍니다.
func testRewardText(raw json.RawMessage, required bool) (value, code string) {
	if len(raw) == 0 || string(raw) == "null" {
		if required {
			return "", "required"
		}
		return "", ""
	}
	if err := json.Unmarshal(raw, &value); err != nil {
		return "", "type"
	}
	if required && value == "" {
		return "", "minLength"
	}
	if utf8.RuneCountInString(value) > maxTestRewardTextLength {
		return "", "maxLength"
	}
	return value, ""
}

// testRewardTimestamp는 timestamp 원문(SSV와 같은 Unix 밀리초 정수)을 검사합니다.
func testRewardTimestamp(raw json.RawMessage) (time.Time, string) {
	if len(raw) == 0 || string(raw) == "null" {
		return time.Time{}, "required"
	}
	var millis int64
	if err := json.Unmarshal(raw, &millis); err != nil {
		return time.Time{}, "type"
	}
	return time.UnixMilli(millis), ""
}
