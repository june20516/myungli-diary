package provider_test

import (
	"net/http"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
)

const appCheckProjectNumber = "123456789012"

func appCheckClaims(now time.Time) map[string]any {
	return map[string]any{
		"iss": "https://firebaseappcheck.googleapis.com/" + appCheckProjectNumber,
		"aud": []string{"projects/" + appCheckProjectNumber, "projects/myungli-test"},
		"sub": "1:123456789012:android:abcdef",
		"iat": now.Unix(),
		"exp": now.Add(time.Hour).Unix(),
	}
}

func newTestAppCheck(t *testing.T, srv *providertest.Server) *provider.AppCheck {
	t.Helper()
	appCheck, err := provider.NewAppCheck(provider.AppCheckConfig{
		ProjectNumber: appCheckProjectNumber,
		HTTPClient:    srv.Client(),
		JWKSURL:       srv.JWKSURL(),
	})
	require.NoError(t, err)
	return appCheck
}

func TestNewAppCheck_RejectsInvalidProjectNumber(t *testing.T) {
	for _, number := range []string{"", "12ab", "projects/123", " 123"} {
		t.Run(number, func(t *testing.T) {
			appCheck, err := provider.NewAppCheck(provider.AppCheckConfig{ProjectNumber: number})

			require.Error(t, err)
			assert.Nil(t, appCheck)
			assert.Contains(t, err.Error(), "ProjectNumber")
		})
	}
}

func TestAppCheck_Verify_AcceptsValidToken(t *testing.T) {
	srv := providertest.New(t)
	appCheck := newTestAppCheck(t, srv)

	err := appCheck.Verify(t.Context(), srv.SignIDToken(appCheckClaims(time.Now())))

	require.NoError(t, err)
}

func TestAppCheck_Verify_RejectsInvalidToken(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(claims map[string]any)
	}{
		{"다른 프로젝트 iss", func(c map[string]any) {
			c["iss"] = "https://firebaseappcheck.googleapis.com/999999999999"
		}},
		{"aud에 프로젝트 번호 없음", func(c map[string]any) {
			c["aud"] = []string{"projects/999999999999", "projects/myungli-test"}
		}},
		{"aud 없음", func(c map[string]any) { delete(c, "aud") }},
		{"만료", func(c map[string]any) { c["exp"] = time.Now().Add(-time.Hour).Unix() }},
		{"sub 없음", func(c map[string]any) { delete(c, "sub") }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv := providertest.New(t)
			appCheck := newTestAppCheck(t, srv)
			claims := appCheckClaims(time.Now())
			tt.mutate(claims)

			err := appCheck.Verify(t.Context(), srv.SignIDToken(claims))

			require.ErrorIs(t, err, provider.ErrTokenInvalid)
			assert.NotErrorIs(t, err, provider.ErrUnavailable)
		})
	}
}

func TestAppCheck_Verify_RejectsWrongSigningKey(t *testing.T) {
	srv := providertest.New(t)
	appCheck := newTestAppCheck(t, srv)
	token := srv.SignIDToken(appCheckClaims(time.Now()))
	srv.RotateKey() // 토큰을 서명한 키가 JWKS에서 빠집니다.

	err := appCheck.Verify(t.Context(), token)

	require.ErrorIs(t, err, provider.ErrTokenInvalid)
}

func TestAppCheck_Verify_RejectsNonRS256(t *testing.T) {
	srv := providertest.New(t)
	appCheck := newTestAppCheck(t, srv)
	unsigned := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims(appCheckClaims(time.Now())))
	unsigned.Header["kid"] = srv.CurrentKeyID()
	token, err := unsigned.SignedString([]byte("shared-secret-for-test"))
	require.NoError(t, err)

	err = appCheck.Verify(t.Context(), token)

	require.ErrorIs(t, err, provider.ErrTokenInvalid)
}

func TestAppCheck_Verify_RejectsMalformedToken(t *testing.T) {
	srv := providertest.New(t)
	appCheck := newTestAppCheck(t, srv)

	err := appCheck.Verify(t.Context(), "not-a-jwt")

	require.ErrorIs(t, err, provider.ErrTokenInvalid)
}

func TestAppCheck_Verify_JWKSOutageIsUnavailable(t *testing.T) {
	srv := providertest.New(t)
	appCheck := newTestAppCheck(t, srv)
	srv.SetJWKSStatus(http.StatusInternalServerError)

	err := appCheck.Verify(t.Context(), srv.SignIDToken(appCheckClaims(time.Now())))

	require.ErrorIs(t, err, provider.ErrUnavailable)
	assert.NotErrorIs(t, err, provider.ErrTokenInvalid)
}
