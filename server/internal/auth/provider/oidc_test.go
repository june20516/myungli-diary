package provider_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

func isErr(err, target error) bool { return errors.Is(err, target) }

// hangingServer는 테스트가 끝날 때까지 응답하지 않는 서버입니다.
// 요청 deadline이 지나면 호출 쪽이 먼저 포기하는지 확인할 때 씁니다.
func hangingServer(t *testing.T) *httptest.Server {
	t.Helper()
	release := make(chan struct{})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-release:
		case <-r.Context().Done():
		}
	}))
	// t.Cleanup은 나중에 등록한 것부터 실행하므로, handler를 먼저 풀어 준 뒤 서버를 닫습니다.
	t.Cleanup(srv.Close)
	t.Cleanup(func() { close(release) })
	return srv
}

func TestVerify_ErrorDoesNotLeakTokenOrNonce(t *testing.T) {
	fake := providertest.New(t)
	kakao := provider.NewKakao(fake.KakaoConfig(clocktest.New(testNow)))
	claims := providertest.KakaoClaims(testSubject, "other-nonce", testNow)
	idToken := fake.SignIDToken(claims)

	_, err := kakao.Verify(context.Background(), idToken, testRawNonce)

	require.ErrorIs(t, err, provider.ErrTokenInvalid)
	for _, secret := range []string{idToken, testRawNonce, providertest.HashNonce("other-nonce"), testSubject} {
		assert.NotContains(t, err.Error(), secret)
	}
}

func TestVerify_RejectsNonRS256(t *testing.T) {
	fake := providertest.New(t)
	kakao := provider.NewKakao(fake.KakaoConfig(clocktest.New(testNow)))
	// alg none 토큰: header {"alg":"none"}, payload는 유효한 claim이라도 거절해야 합니다.
	unsigned := "eyJhbGciOiJub25lIn0.eyJzdWIiOiJ4In0."

	_, err := kakao.Verify(context.Background(), unsigned, testRawNonce)

	require.ErrorIs(t, err, provider.ErrTokenInvalid)
}

func TestVerify_ConcurrentCallsAreSafe(t *testing.T) {
	fake := providertest.New(t)
	kakao := provider.NewKakao(fake.KakaoConfig(clocktest.New(testNow)))
	idToken := fake.SignIDToken(providertest.KakaoClaims(testSubject, testRawNonce, testNow))

	errs := make(chan error, 20)
	for range 20 {
		go func() {
			_, err := kakao.Verify(context.Background(), idToken, testRawNonce)
			errs <- err
		}()
	}
	for range 20 {
		require.NoError(t, <-errs)
	}
}
