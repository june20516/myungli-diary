package httpapi_test

import (
	"bytes"
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// fakeLimiter는 호출 키를 모으고 limit번째까지만 허용합니다.
type fakeLimiter struct {
	limit      int
	retryAfter time.Duration
	err        error
	keys       []string
}

func (f *fakeLimiter) Allow(_ context.Context, key string, limit int, _ time.Duration) (bool, time.Duration, error) {
	f.keys = append(f.keys, key)
	if f.err != nil {
		return false, 0, f.err
	}
	if len(f.keys) <= limit {
		return true, 0, nil
	}
	return false, f.retryAfter, nil
}

func newRateLimitHandler(t *testing.T, limiter httpapi.Limiter, verifier httpapi.AppCheckVerifier) (http.Handler, *bytes.Buffer) {
	t.Helper()
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, logs := newTestDeps()
	routes := httpapi.Routes{
		Spec:         spec,
		Validate:     httpapi.ValidateRequests(spec, deps.Logger),
		Authenticate: authenticateFixedAccount,
		AppCheck:     httpapi.RequireAppCheck(verifier, deps.Logger),
		RateLimit:    httpapi.RateLimit(limiter, 1, 30, time.Minute, "getBirthHour", "convertLunarDate"),
	}
	handler := httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, httpapi.Unimplemented{}, deps, routes)
	})
	return handler, logs
}

func rateLimitedRequest(t *testing.T, forwardedFor string) *http.Request {
	t.Helper()
	req := birthHourRequest(t, validAppCheckToken)
	req.RemoteAddr = "10.0.0.1:4000"
	req.Header.Set("X-Forwarded-For", forwardedFor)
	return req
}

func TestRateLimit_Rejects31stWith429AndRetryAfter(t *testing.T) {
	limiter := &fakeLimiter{limit: 30, retryAfter: 12300 * time.Millisecond}
	handler, _ := newRateLimitHandler(t, limiter, &fakeAppCheck{})

	for i := 1; i <= 30; i++ {
		rec := serve(handler, rateLimitedRequest(t, "1.1.1.1, 203.0.113.7"))
		require.Equal(t, http.StatusNotImplemented, rec.Code, "%d번째 요청은 한도를 지나 핸들러까지 갑니다", i)
	}
	rec := serve(handler, rateLimitedRequest(t, "1.1.1.1, 203.0.113.7"))

	require.Equal(t, http.StatusTooManyRequests, rec.Code, "body = %s", rec.Body.String())
	assert.Equal(t, "rate_limited", decodeProblem(t, rec).Code)
	assert.Equal(t, "13", rec.Header().Get("Retry-After"), "12.3초는 올림해 13초")
}

func TestRateLimit_KeyIsOperationAndHashedClientIP(t *testing.T) {
	limiter := &fakeLimiter{limit: 30}
	handler, logs := newRateLimitHandler(t, limiter, &fakeAppCheck{})

	serve(handler, rateLimitedRequest(t, "1.1.1.1, 203.0.113.7"))

	require.Len(t, limiter.keys, 1)
	assert.Regexp(t, `^getBirthHour:[0-9a-f]{64}$`, limiter.keys[0])
	assert.NotContains(t, limiter.keys[0], "203.0.113.7")
	assert.NotContains(t, logs.String(), "203.0.113.7")

	// 같은 IP는 같은 키, 다른 IP는 다른 키입니다.
	serve(handler, rateLimitedRequest(t, "9.9.9.9, 203.0.113.7"))
	serve(handler, rateLimitedRequest(t, "9.9.9.9, 203.0.113.8"))
	assert.Equal(t, limiter.keys[0], limiter.keys[1])
	assert.NotEqual(t, limiter.keys[0], limiter.keys[2])
}

func TestRateLimit_NonTargetOperationPasses(t *testing.T) {
	limiter := &fakeLimiter{limit: 0}
	handler, _ := newRateLimitHandler(t, limiter, &fakeAppCheck{})

	rec := serve(handler, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/v1/me", nil))

	assert.NotEqual(t, http.StatusTooManyRequests, rec.Code)
	assert.Empty(t, limiter.keys, "대상이 아닌 operation은 한도를 세지 않습니다")
}

func TestRateLimit_AppCheckFailureDoesNotUseLimit(t *testing.T) {
	limiter := &fakeLimiter{limit: 30}
	handler, _ := newRateLimitHandler(t, limiter, &fakeAppCheck{})
	req := rateLimitedRequest(t, "203.0.113.7")
	req.Header.Set("X-Firebase-AppCheck", "other")

	rec := serve(handler, req)

	require.Equal(t, http.StatusUnauthorized, rec.Code)
	assert.Empty(t, limiter.keys)
}

func TestRateLimit_StoreErrorIs500(t *testing.T) {
	limiter := &fakeLimiter{err: errors.New("db down")}
	handler, logs := newRateLimitHandler(t, limiter, &fakeAppCheck{})

	rec := serve(handler, rateLimitedRequest(t, "203.0.113.7"))

	require.Equal(t, http.StatusInternalServerError, rec.Code, "body = %s", rec.Body.String())
	assert.Equal(t, "internal", decodeProblem(t, rec).Code)
	assert.NotContains(t, logs.String(), "203.0.113.7")
}
