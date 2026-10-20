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
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
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

func TestAppCheck_Verify_UsesInjectedClock(t *testing.T) {
	srv := providertest.New(t)
	future := clocktest.New(time.Now().Add(48 * time.Hour))
	appCheck, err := provider.NewAppCheck(provider.AppCheckConfig{
		ProjectNumber: appCheckProjectNumber,
		HTTPClient:    srv.Client(),
		JWKSURL:       srv.JWKSURL(),
		Clock:         future,
	})
	require.NoError(t, err)

	// 실제 시각으로는 한 시간 더 유효하지만 주입한 시계로는 만료된 토큰입니다.
	err = appCheck.Verify(t.Context(), srv.SignIDToken(appCheckClaims(time.Now())))

	require.ErrorIs(t, err, provider.ErrTokenInvalid)
}

func TestAppCheck_Verify_AudienceBoundaries(t *testing.T) {
	tests := []struct {
		name    string
		aud     any
		wantErr bool
	}{
		{"번호 뒤에 숫자가 붙음", []string{"projects/" + appCheckProjectNumber + "9"}, true},
		{"번호 앞부분만", []string{"projects/" + appCheckProjectNumber[:6]}, true},
		{"접두어 없음", []string{appCheckProjectNumber}, true},
		{"문자열 단일 aud", "projects/" + appCheckProjectNumber, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv := providertest.New(t)
			appCheck := newTestAppCheck(t, srv)
			claims := appCheckClaims(time.Now())
			claims["aud"] = tt.aud

			err := appCheck.Verify(t.Context(), srv.SignIDToken(claims))

			if tt.wantErr {
				require.ErrorIs(t, err, provider.ErrTokenInvalid)
				return
			}
			require.NoError(t, err)
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
	tests := []struct {
		name  string
		build func(t *testing.T, srv *providertest.Server) string
	}{
		{"HS256", func(t *testing.T, srv *providertest.Server) string {
			unsigned := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims(appCheckClaims(time.Now())))
			unsigned.Header["kid"] = srv.CurrentKeyID()
			token, err := unsigned.SignedString([]byte("shared-secret-for-test"))
			require.NoError(t, err)
			return token
		}},
		{"none", func(t *testing.T, srv *providertest.Server) string {
			unsigned := jwt.NewWithClaims(jwt.SigningMethodNone, jwt.MapClaims(appCheckClaims(time.Now())))
			unsigned.Header["kid"] = srv.CurrentKeyID()
			token, err := unsigned.SignedString(jwt.UnsafeAllowNoneSignatureType)
			require.NoError(t, err)
			return token
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv := providertest.New(t)
			appCheck := newTestAppCheck(t, srv)

			err := appCheck.Verify(t.Context(), tt.build(t, srv))

			require.ErrorIs(t, err, provider.ErrTokenInvalid)
			assert.Contains(t, err.Error(), "unexpected signature algorithm", "alg 검사에서 거부돼야 합니다")
			assert.NotContains(t, err.Error(), "id_token")
		})
	}
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
