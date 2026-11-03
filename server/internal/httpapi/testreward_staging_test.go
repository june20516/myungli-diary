//go:build staging

package httpapi_test

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
)

// testRewardPath는 staging 보상형 광고 보상(S131)의 경로입니다.
const testRewardPath = "/test/v1/billing/rewarded-ad"

// fakeTestRewards는 받은 계정과 콜백을 기록하고 정해 둔 결과를 돌려주는 대역입니다.
type fakeTestRewards struct {
	calls     int
	gotAcct   uuid.UUID
	gotReward billing.RewardCallback
	status    billing.Status
	err       error
}

func (f *fakeTestRewards) GrantTestReward(_ context.Context, accountID uuid.UUID, cb billing.RewardCallback) (billing.Status, error) {
	f.calls++
	f.gotAcct, f.gotReward = accountID, cb
	return f.status, f.err
}

func newTestRewardFixture(t *testing.T, service *fakeTestRewards) testLoginFixture {
	t.Helper()
	api := &httpapi.API{}
	api.EnableTestReward(service)
	handler, spec, logs := newHandlerAPIWithLogs(t, api)
	return testLoginFixture{handler: handler, spec: spec, logs: logs}
}

func testRewardRequest(t *testing.T, method, body string) *http.Request {
	t.Helper()
	return newBodyRequest(t, method, testRewardPath, contentTypeJSON, body)
}

// 인증된 계정에 본문의 값으로 보상을 주고 계약 Entitlements를 돌려줍니다.
func TestTestReward_GrantsToAuthenticatedAccount(t *testing.T) {
	expires := handlerNow.Add(3 * time.Hour)
	service := &fakeTestRewards{status: billing.Status{Insight: billing.State{Active: true, ExpiresAt: &expires, Source: billing.SourceRewardedAd}}}
	f := newTestRewardFixture(t, service)

	got := f.entitlementsOf(t, testRewardRequest(t, http.MethodPost,
		`{"transactionId":"tx-1","adUnit":"ca-app-pub-1/2","rewardItem":"insight","timestamp":1792497600000}`))

	assert.True(t, got.Insight.Active)
	require.Equal(t, 1, service.calls)
	assert.Equal(t, fixedAccountID, service.gotAcct)
	assert.Equal(t, billing.RewardCallback{
		TransactionID: "tx-1", AdUnit: "ca-app-pub-1/2", RewardItem: "insight",
		Timestamp: time.UnixMilli(1792497600000),
	}, service.gotReward)
}

// adUnit, rewardItem은 없어도 됩니다(빈 값으로 기록).
func TestTestReward_OptionalFields(t *testing.T) {
	service := &fakeTestRewards{}
	f := newTestRewardFixture(t, service)

	f.entitlementsOf(t, testRewardRequest(t, http.MethodPost, `{"transactionId":"tx-1","adUnit":null,"timestamp":1792497600000}`))

	assert.Empty(t, service.gotReward.AdUnit)
	assert.Empty(t, service.gotReward.RewardItem)
}

// 본문이 틀리면 400 request.invalid이고 서비스를 부르지 않습니다.
func TestTestReward_InvalidRequest(t *testing.T) {
	long := `"` + strings.Repeat("가", 257) + `"`
	cases := map[string]struct{ body, field, code string }{
		"transactionId 없음":   {`{"timestamp":1}`, "/transactionId", "required"},
		"transactionId 빈 값":  {`{"transactionId":"","timestamp":1}`, "/transactionId", "minLength"},
		"transactionId 타입":   {`{"transactionId":1,"timestamp":1}`, "/transactionId", "type"},
		"transactionId 너무 김": {`{"transactionId":` + long + `,"timestamp":1}`, "/transactionId", "maxLength"},
		"adUnit 타입":          {`{"transactionId":"tx","adUnit":1,"timestamp":1}`, "/adUnit", "type"},
		"rewardItem 타입":      {`{"transactionId":"tx","rewardItem":true,"timestamp":1}`, "/rewardItem", "type"},
		"timestamp 없음":       {`{"transactionId":"tx"}`, "/timestamp", "required"},
		"timestamp 문자열":      {`{"transactionId":"tx","timestamp":"1"}`, "/timestamp", "type"},
		"timestamp 소수":       {`{"transactionId":"tx","timestamp":1.5}`, "/timestamp", "type"},
	}
	for name, tc := range cases {
		service := &fakeTestRewards{}
		f := newTestRewardFixture(t, service)
		rec := serve(f.handler, testRewardRequest(t, http.MethodPost, tc.body))
		require.Equal(t, http.StatusBadRequest, rec.Code, "%s: %s", name, rec.Body.String())
		p := decodeProblem(t, rec)
		assert.Equal(t, "request.invalid", p.Code, name)
		require.Len(t, p.Errors, 1, name)
		assert.Equal(t, tc.field, p.Errors[0].Field, name)
		assert.Equal(t, tc.code, p.Errors[0].Code, name)
		assert.Zero(t, service.calls, name)
	}
}

// timestamp가 허용 차이 밖이면(billing.ErrRewardExpired) 401이 아니라 400 /timestamp expired입니다(토큰 문제로 보이지 않게).
func TestTestReward_ExpiredTimestampIsBadRequest(t *testing.T) {
	f := newTestRewardFixture(t, &fakeTestRewards{err: billing.ErrRewardExpired})

	rec := serve(f.handler, testRewardRequest(t, http.MethodPost, `{"transactionId":"tx","timestamp":1}`))

	require.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	require.Len(t, p.Errors, 1)
	assert.Equal(t, "/timestamp", p.Errors[0].Field)
	assert.Equal(t, "expired", p.Errors[0].Code)
}

// 그 밖의 서비스 오류는 핸들러 오류 규칙(500)입니다.
func TestTestReward_ServiceErrorIsInternal(t *testing.T) {
	f := newTestRewardFixture(t, &fakeTestRewards{err: errors.New("db down")})

	rec := serve(f.handler, testRewardRequest(t, http.MethodPost, `{"transactionId":"tx","timestamp":1}`))

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
	assert.Equal(t, "internal", decodeProblem(t, rec).Code)
}

// POST가 아니면 405이고 Allow는 POST입니다.
func TestTestReward_MethodNotAllowed(t *testing.T) {
	service := &fakeTestRewards{}
	f := newTestRewardFixture(t, service)

	rec := serve(f.handler, testRewardRequest(t, http.MethodGet, ""))

	require.Equal(t, http.StatusMethodNotAllowed, rec.Code, rec.Body.String())
	assert.Equal(t, http.MethodPost, rec.Header().Get("Allow"))
	assert.Equal(t, "method.not_allowed", decodeProblem(t, rec).Code)
	assert.Zero(t, service.calls)
}

// 켜지 않으면 경로가 없습니다.
func TestTestReward_NotEnabledIsRouteNotFound(t *testing.T) {
	handler, _, _ := newHandlerAPIWithLogs(t, &httpapi.API{})

	rec := serve(handler, testRewardRequest(t, http.MethodPost, `{}`))

	require.Equal(t, http.StatusNotFound, rec.Code, rec.Body.String())
	assert.Equal(t, "route.not_found", decodeProblem(t, rec).Code)
}

// 서비스 없이 켜면 조립 버그라 panic합니다.
func TestTestReward_EnableRequiresService(t *testing.T) {
	assert.Panics(t, func() { (&httpapi.API{}).EnableTestReward(nil) })
}
