package provider_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

const testAppleSubject = "001234.abcdef0123456789.0123"

// testAppleCode는 testAppleSubject의 authorization code입니다. 대역은 교환하면 이 subject의 id_token을 돌려줍니다.
var testAppleCode = providertest.AppleCode(testAppleSubject)

func newApple(t *testing.T) (*provider.Apple, *providertest.Server) {
	t.Helper()
	fake := providertest.New(t)
	return mustApple(t, fake.AppleConfig(clocktest.New(testNow))), fake
}

func TestApple_VerifyAcceptsValidTokenPerClient(t *testing.T) {
	for _, client := range []provider.AppleClient{provider.AppleNative, provider.AppleWeb} {
		t.Run(string(client), func(t *testing.T) {
			apple, fake := newApple(t)
			idToken := fake.SignIDToken(providertest.AppleClaims(testAppleSubject, testRawNonce, client, testNow))

			got, err := apple.Verify(context.Background(), idToken, testRawNonce, client)

			require.NoError(t, err)
			assert.Equal(t, provider.Identity{Subject: testAppleSubject}, got)
		})
	}
}

func TestApple_VerifyUsesAudiencePerClient(t *testing.T) {
	tests := []struct {
		name      string
		tokenFor  provider.AppleClient
		verifyFor provider.AppleClient
	}{
		{"native 토큰을 web으로", provider.AppleNative, provider.AppleWeb},
		{"web 토큰을 native로", provider.AppleWeb, provider.AppleNative},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			apple, fake := newApple(t)
			idToken := fake.SignIDToken(providertest.AppleClaims(testAppleSubject, testRawNonce, tt.tokenFor, testNow))

			_, err := apple.Verify(context.Background(), idToken, testRawNonce, tt.verifyFor)

			require.ErrorIs(t, err, provider.ErrTokenInvalid)
		})
	}
}

func TestApple_VerifyRejectsWrongIssuerNonceExpiry(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(claims map[string]any)
	}{
		{"다른 iss", func(c map[string]any) { c["iss"] = providertest.KakaoIssuer }},
		{"nonce 원문", func(c map[string]any) { c["nonce"] = testRawNonce }},
		{"만료", func(c map[string]any) { c["exp"] = testNow.Add(-time.Second).Unix() }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			apple, fake := newApple(t)
			claims := providertest.AppleClaims(testAppleSubject, testRawNonce, provider.AppleNative, testNow)
			tt.mutate(claims)

			_, err := apple.Verify(context.Background(), fake.SignIDToken(claims), testRawNonce, provider.AppleNative)

			require.ErrorIs(t, err, provider.ErrTokenInvalid)
		})
	}
}

func TestApple_VerifyRejectsUnknownClient(t *testing.T) {
	apple, fake := newApple(t)
	idToken := fake.SignIDToken(providertest.AppleClaims(testAppleSubject, testRawNonce, provider.AppleNative, testNow))

	_, err := apple.Verify(context.Background(), idToken, testRawNonce, provider.AppleClient("tv"))

	require.Error(t, err)
}

func TestApple_JWKSDownIsUnavailable(t *testing.T) {
	apple, fake := newApple(t)
	fake.SetJWKSStatus(http.StatusBadGateway)
	idToken := fake.SignIDToken(providertest.AppleClaims(testAppleSubject, testRawNonce, provider.AppleNative, testNow))

	_, err := apple.Verify(context.Background(), idToken, testRawNonce, provider.AppleNative)

	require.ErrorIs(t, err, provider.ErrUnavailable)
}

func TestApple_ExchangeCodeSendsSignedClientSecret(t *testing.T) {
	tests := []struct {
		client       provider.AppleClient
		wantClientID string
		wantRedirect string
	}{
		{provider.AppleNative, providertest.AppleBundleID, ""},
		{provider.AppleWeb, providertest.AppleServicesID, providertest.AppleWebRedirectURI},
	}
	for _, tt := range tests {
		t.Run(string(tt.client), func(t *testing.T) {
			apple, fake := newApple(t)

			refreshToken, clientID, err := apple.ExchangeCode(context.Background(), testAppleCode, tt.client, testAppleSubject)

			require.NoError(t, err)
			assert.Equal(t, providertest.AppleRefreshToken, refreshToken)
			assert.Equal(t, tt.wantClientID, clientID)

			reqs := fake.AppleTokenRequests()
			require.Len(t, reqs, 1)
			form := reqs[0].Form
			assert.Equal(t, "authorization_code", form.Get("grant_type"))
			assert.Equal(t, testAppleCode, form.Get("code"))
			assert.Equal(t, tt.wantClientID, form.Get("client_id"))
			assert.Equal(t, tt.wantRedirect, form.Get("redirect_uri"))
			_, hasRedirect := form["redirect_uri"]
			assert.Equal(t, tt.client == provider.AppleWeb, hasRedirect)

			// client_secret: Apple 공개 키로 ES256 서명을 검증하고 claim을 확인합니다.
			var claims jwt.RegisteredClaims
			parsed, err := jwt.ParseWithClaims(form.Get("client_secret"), &claims,
				func(*jwt.Token) (any, error) { return &fake.ApplePrivateKey().PublicKey, nil },
				jwt.WithValidMethods([]string{"ES256"}),
				jwt.WithTimeFunc(func() time.Time { return testNow }),
			)
			require.NoError(t, err)
			assert.Equal(t, providertest.AppleKeyID, parsed.Header["kid"])
			assert.Equal(t, providertest.AppleTeamID, claims.Issuer)
			assert.Equal(t, tt.wantClientID, claims.Subject)
			assert.Equal(t, jwt.ClaimStrings{"https://appleid.apple.com"}, claims.Audience)
			assert.Equal(t, testNow, claims.IssuedAt.UTC())
			assert.Equal(t, testNow.Add(5*time.Minute), claims.ExpiresAt.UTC())
		})
	}
}

func TestApple_ExchangeInvalidGrantIsTokenInvalid(t *testing.T) {
	apple, fake := newApple(t)
	fake.SetAppleTokenResponse(http.StatusBadRequest, `{"error":"invalid_grant","error_description":"code expired"}`)

	_, _, err := apple.ExchangeCode(context.Background(), testAppleCode, provider.AppleNative, testAppleSubject)

	require.ErrorIs(t, err, provider.ErrTokenInvalid)
	assert.NotContains(t, err.Error(), testAppleCode)
	assert.NotContains(t, err.Error(), "code expired", "오류 문구에 응답 본문을 넣지 않습니다")
}

func TestApple_ExchangeOtherFailures(t *testing.T) {
	tests := []struct {
		name    string
		status  int
		body    string
		wantErr error // nil이면 두 sentinel 어느 쪽도 아닌 일반 오류
	}{
		{"refresh_token 없음은 장애", http.StatusOK, `{"access_token":"a","token_type":"Bearer","id_token":"x"}`, provider.ErrUnavailable},
		{"id_token 없음은 장애", http.StatusOK, `{"access_token":"a","token_type":"Bearer","refresh_token":"r"}`, provider.ErrUnavailable},
		{"id_token 서명이 틀리면 토큰 오류", http.StatusOK, `{"refresh_token":"r","id_token":"e30.e30.c2ln"}`, provider.ErrTokenInvalid},
		{"200 본문이 JSON 아님은 장애", http.StatusOK, `oops`, provider.ErrUnavailable},
		{"invalid_client는 설정 오류", http.StatusBadRequest, `{"error":"invalid_client"}`, nil},
		{"429는 장애", http.StatusTooManyRequests, ``, provider.ErrUnavailable},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			apple, fake := newApple(t)
			fake.SetAppleTokenResponse(tt.status, tt.body)

			refreshToken, _, err := apple.ExchangeCode(context.Background(), testAppleCode, provider.AppleNative, testAppleSubject)

			require.Error(t, err)
			assert.Empty(t, refreshToken)
			if tt.wantErr != nil {
				require.ErrorIs(t, err, tt.wantErr)
				return
			}
			assert.NotErrorIs(t, err, provider.ErrTokenInvalid)
			assert.NotErrorIs(t, err, provider.ErrUnavailable)
		})
	}
}

// 교환 응답 id_token의 sub가 로그인 id_token의 sub와 다르면 토큰 오류입니다(다른 사용자의 code).
func TestApple_ExchangeSubjectMismatchIsTokenInvalid(t *testing.T) {
	apple, _ := newApple(t)

	refreshToken, _, err := apple.ExchangeCode(context.Background(), providertest.AppleCode("other-subject"), provider.AppleNative, testAppleSubject)

	require.ErrorIs(t, err, provider.ErrTokenInvalid)
	assert.Empty(t, refreshToken)
	assert.NotContains(t, err.Error(), "other-subject", "오류 문구에 subject를 넣지 않습니다")
}

// 교환 응답 id_token은 교환에 쓴 client의 aud로 검증합니다.
func TestApple_ExchangeVerifiesIDTokenAudiencePerClient(t *testing.T) {
	apple, fake := newApple(t)
	claims := providertest.AppleClaims(testAppleSubject, testRawNonce, provider.AppleWeb, testNow)
	fake.SetAppleTokenResponse(http.StatusOK, `{"refresh_token":"r","id_token":"`+fake.SignIDToken(claims)+`"}`)

	_, _, err := apple.ExchangeCode(context.Background(), testAppleCode, provider.AppleNative, testAppleSubject)

	require.ErrorIs(t, err, provider.ErrTokenInvalid)
}

func TestApple_TokenEndpoint5xxIsUnavailable(t *testing.T) {
	tests := []struct {
		name  string
		setup func(t *testing.T, fake *providertest.Server, cfg *provider.AppleConfig)
	}{
		{"500", func(_ *testing.T, fake *providertest.Server, _ *provider.AppleConfig) {
			fake.SetAppleTokenResponse(http.StatusInternalServerError, `{"error":"server_error"}`)
		}},
		{"503", func(_ *testing.T, fake *providertest.Server, _ *provider.AppleConfig) {
			fake.SetAppleTokenResponse(http.StatusServiceUnavailable, ``)
		}},
		{"연결 거부", func(_ *testing.T, _ *providertest.Server, cfg *provider.AppleConfig) {
			closed := httptest.NewServer(http.NotFoundHandler())
			closed.Close()
			cfg.TokenURL = closed.URL
		}},
		{"응답 지연(요청 deadline 초과)", func(t *testing.T, _ *providertest.Server, cfg *provider.AppleConfig) {
			cfg.TokenURL = hangingServer(t).URL
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := providertest.New(t)
			cfg := fake.AppleConfig(clocktest.New(testNow))
			tt.setup(t, fake, &cfg)
			apple := mustApple(t, cfg)
			ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
			defer cancel()

			_, _, err := apple.ExchangeCode(ctx, testAppleCode, provider.AppleNative, testAppleSubject)

			require.ErrorIs(t, err, provider.ErrUnavailable)
			assert.NotErrorIs(t, err, provider.ErrTokenInvalid)
		})
	}
}

func TestApple_RevokeSendsRefreshToken(t *testing.T) {
	apple, fake := newApple(t)

	err := apple.Revoke(context.Background(), "stored-refresh-token", providertest.AppleServicesID)

	require.NoError(t, err)
	reqs := fake.AppleRevokeRequests()
	require.Len(t, reqs, 1)
	form := reqs[0].Form
	assert.Equal(t, "stored-refresh-token", form.Get("token"))
	assert.Equal(t, "refresh_token", form.Get("token_type_hint"))
	assert.Equal(t, providertest.AppleServicesID, form.Get("client_id"))

	var claims jwt.RegisteredClaims
	_, err = jwt.ParseWithClaims(form.Get("client_secret"), &claims,
		func(*jwt.Token) (any, error) { return &fake.ApplePrivateKey().PublicKey, nil },
		jwt.WithValidMethods([]string{"ES256"}),
		jwt.WithTimeFunc(func() time.Time { return testNow }),
	)
	require.NoError(t, err)
	assert.Equal(t, providertest.AppleServicesID, claims.Subject)
}

func TestApple_RevokeFailures(t *testing.T) {
	tests := []struct {
		name    string
		status  int
		body    string
		wantErr error
	}{
		{"5xx는 장애", http.StatusInternalServerError, ``, provider.ErrUnavailable},
		{"invalid_grant는 토큰 무효", http.StatusBadRequest, `{"error":"invalid_grant"}`, provider.ErrTokenInvalid},
		{"invalid_client는 일반 오류", http.StatusBadRequest, `{"error":"invalid_client"}`, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			apple, fake := newApple(t)
			fake.SetAppleRevokeResponse(tt.status, tt.body)

			err := apple.Revoke(context.Background(), "stored-refresh-token", providertest.AppleBundleID)

			require.Error(t, err)
			assert.NotContains(t, err.Error(), "stored-refresh-token")
			if tt.wantErr != nil {
				require.ErrorIs(t, err, tt.wantErr)
				return
			}
			assert.NotErrorIs(t, err, provider.ErrTokenInvalid)
			assert.NotErrorIs(t, err, provider.ErrUnavailable)
		})
	}
}
