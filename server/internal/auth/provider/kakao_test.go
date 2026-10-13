package provider_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

var testNow = time.Date(2026, 10, 13, 9, 0, 0, 0, time.UTC)

const (
	testSubject  = "4123456789"
	testRawNonce = "raw-nonce-from-app"
)

func newKakao(t *testing.T) (*provider.Kakao, *providertest.Server) {
	t.Helper()
	fake := providertest.New(t)
	return provider.NewKakao(fake.KakaoConfig(clocktest.New(testNow))), fake
}

func TestKakao_VerifyAcceptsValidToken(t *testing.T) {
	kakao, fake := newKakao(t)
	idToken := fake.SignIDToken(providertest.KakaoClaims(testSubject, testRawNonce, testNow))

	got, err := kakao.Verify(context.Background(), idToken, testRawNonce)

	require.NoError(t, err)
	assert.Equal(t, provider.Identity{Subject: testSubject}, got)
}

func TestKakao_VerifyRejectsWrongAudienceIssuerNonceExpiry(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(claims map[string]any)
	}{
		{"다른 aud", func(c map[string]any) { c["aud"] = "other-app-key" }},
		{"다른 iss", func(c map[string]any) { c["iss"] = "https://evil.example.com" }},
		{"다른 nonce", func(c map[string]any) { c["nonce"] = providertest.HashNonce("other-nonce") }},
		{"nonce 없음", func(c map[string]any) { delete(c, "nonce") }},
		{"만료", func(c map[string]any) { c["exp"] = testNow.Add(-time.Second).Unix() }},
		{"sub 없음", func(c map[string]any) { delete(c, "sub") }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kakao, fake := newKakao(t)
			claims := providertest.KakaoClaims(testSubject, testRawNonce, testNow)
			tt.mutate(claims)

			_, err := kakao.Verify(context.Background(), fake.SignIDToken(claims), testRawNonce)

			require.ErrorIs(t, err, provider.ErrTokenInvalid)
			assert.NotErrorIs(t, err, provider.ErrUnavailable)
		})
	}
}

func TestKakao_VerifyRejectsMalformedAndForeignSignature(t *testing.T) {
	kakao, _ := newKakao(t)
	other := providertest.New(t) // 다른 키로 서명한 토큰
	foreign := other.SignIDToken(providertest.KakaoClaims(testSubject, testRawNonce, testNow))

	for name, idToken := range map[string]string{"형식 오류": "not-a-jwt", "다른 키 서명": foreign} {
		t.Run(name, func(t *testing.T) {
			_, err := kakao.Verify(context.Background(), idToken, testRawNonce)
			require.ErrorIs(t, err, provider.ErrTokenInvalid)
			assert.NotErrorIs(t, err, provider.ErrUnavailable)
		})
	}
}

func TestKakao_NonceComparesSHA256Hex(t *testing.T) {
	tests := []struct {
		name       string
		tokenNonce string
		wantErr    error
	}{
		{"원문 그대로면 거절", testRawNonce, provider.ErrTokenInvalid},
		{"hex(sha256(원문))이면 통과", providertest.HashNonce(testRawNonce), nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kakao, fake := newKakao(t)
			claims := providertest.KakaoClaims(testSubject, testRawNonce, testNow)
			claims["nonce"] = tt.tokenNonce

			_, err := kakao.Verify(context.Background(), fake.SignIDToken(claims), testRawNonce)

			if tt.wantErr == nil {
				require.NoError(t, err)
				return
			}
			require.ErrorIs(t, err, tt.wantErr)
		})
	}
}

func TestKakao_JWKSDownIsUnavailable(t *testing.T) {
	tests := []struct {
		name  string
		setup func(t *testing.T, fake *providertest.Server) provider.KakaoConfig
	}{
		{"JWKS 500", func(t *testing.T, fake *providertest.Server) provider.KakaoConfig {
			fake.SetJWKSStatus(http.StatusInternalServerError)
			return fake.KakaoConfig(clocktest.New(testNow))
		}},
		{"JWKS 연결 거부", func(t *testing.T, fake *providertest.Server) provider.KakaoConfig {
			closed := httptest.NewServer(http.NotFoundHandler())
			closed.Close()
			cfg := fake.KakaoConfig(clocktest.New(testNow))
			cfg.JWKSURL = closed.URL
			return cfg
		}},
		{"JWKS 응답 지연(요청 deadline 초과)", func(t *testing.T, fake *providertest.Server) provider.KakaoConfig {
			cfg := fake.KakaoConfig(clocktest.New(testNow))
			cfg.JWKSURL = hangingServer(t).URL
			return cfg
		}},
		{"JWKS 200 이지만 JSON 아님", func(t *testing.T, fake *providertest.Server) provider.KakaoConfig {
			garbage := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				_, err := w.Write([]byte("<html>maintenance</html>"))
				assert.NoError(t, err)
			}))
			t.Cleanup(garbage.Close)
			cfg := fake.KakaoConfig(clocktest.New(testNow))
			cfg.JWKSURL = garbage.URL
			return cfg
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := providertest.New(t)
			kakao := provider.NewKakao(tt.setup(t, fake))
			idToken := fake.SignIDToken(providertest.KakaoClaims(testSubject, testRawNonce, testNow))

			ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
			defer cancel()
			_, err := kakao.Verify(ctx, idToken, testRawNonce)

			require.ErrorIs(t, err, provider.ErrUnavailable)
			assert.NotErrorIs(t, err, provider.ErrTokenInvalid)
		})
	}
}

func TestKakao_JWKSRecoversAfterOutage(t *testing.T) {
	kakao, fake := newKakao(t)
	idToken := fake.SignIDToken(providertest.KakaoClaims(testSubject, testRawNonce, testNow))

	fake.SetJWKSStatus(http.StatusServiceUnavailable)
	_, err := kakao.Verify(context.Background(), idToken, testRawNonce)
	require.ErrorIs(t, err, provider.ErrUnavailable)

	fake.SetJWKSStatus(http.StatusOK)
	_, err = kakao.Verify(context.Background(), idToken, testRawNonce)
	require.NoError(t, err)
}

func TestKakao_UnknownKidRefetchesJWKS(t *testing.T) {
	kakao, fake := newKakao(t)
	first := fake.SignIDToken(providertest.KakaoClaims(testSubject, testRawNonce, testNow))
	_, err := kakao.Verify(context.Background(), first, testRawNonce)
	require.NoError(t, err)
	hitsBefore := fake.JWKSHits()

	fake.RotateKey()
	rotated := fake.SignIDToken(providertest.KakaoClaims(testSubject, testRawNonce, testNow))
	got, err := kakao.Verify(context.Background(), rotated, testRawNonce)

	require.NoError(t, err)
	assert.Equal(t, testSubject, got.Subject)
	assert.Greater(t, fake.JWKSHits(), hitsBefore, "새 kid를 보면 JWKS를 다시 받아야 합니다")
}

func TestKakao_UnlinkSendsAdminKeyAndTarget(t *testing.T) {
	kakao, fake := newKakao(t)

	err := kakao.Unlink(context.Background(), testSubject)

	require.NoError(t, err)
	reqs := fake.KakaoUnlinkRequests()
	require.Len(t, reqs, 1)
	assert.Equal(t, "KakaoAK "+providertest.KakaoAdminKey, reqs[0].Header.Get("Authorization"))
	assert.Equal(t, "user_id", reqs[0].Form.Get("target_id_type"))
	assert.Equal(t, testSubject, reqs[0].Form.Get("target_id"))
}

func TestKakao_UnlinkAlreadyUnlinkedIsSuccess(t *testing.T) {
	kakao, fake := newKakao(t)
	fake.SetKakaoUnlinkResponse(http.StatusBadRequest, `{"msg":"NotRegisteredUserException","code":-101}`)

	err := kakao.Unlink(context.Background(), testSubject)

	require.NoError(t, err)
}

func TestKakao_UnlinkFailures(t *testing.T) {
	tests := []struct {
		name            string
		status          int
		body            string
		wantUnavailable bool
	}{
		{"5xx는 장애", http.StatusInternalServerError, `{"msg":"internal","code":-1}`, true},
		{"429는 장애", http.StatusTooManyRequests, `{"msg":"limit","code":-10}`, true},
		{"다른 4xx는 일반 오류", http.StatusUnauthorized, `{"msg":"wrong admin key","code":-401}`, false},
		{"4xx 본문이 JSON 아님", http.StatusBadRequest, `oops`, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kakao, fake := newKakao(t)
			fake.SetKakaoUnlinkResponse(tt.status, tt.body)

			err := kakao.Unlink(context.Background(), testSubject)

			require.Error(t, err)
			assert.Equal(t, tt.wantUnavailable, isErr(err, provider.ErrUnavailable))
			assert.NotContains(t, err.Error(), testSubject, "오류 문구에 subject를 넣지 않습니다")
			assert.NotContains(t, err.Error(), "wrong admin key", "오류 문구에 응답 본문을 넣지 않습니다")
		})
	}
}

func TestKakao_UnlinkConnectionRefusedIsUnavailable(t *testing.T) {
	fake := providertest.New(t)
	closed := httptest.NewServer(http.NotFoundHandler())
	closed.Close()
	cfg := fake.KakaoConfig(clocktest.New(testNow))
	cfg.UnlinkURL = closed.URL
	kakao := provider.NewKakao(cfg)

	err := kakao.Unlink(context.Background(), testSubject)

	require.ErrorIs(t, err, provider.ErrUnavailable)
}
