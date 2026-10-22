package provider_test

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

const googleSubject = "110169484474386276334"

func newGoogle(t *testing.T) (*provider.Google, *providertest.Server) {
	t.Helper()
	fake := providertest.New(t)
	return fake.NewGoogle(t, clocktest.New(testNow)), fake
}

func TestGoogle_VerifyAcceptsBothIssuerForms(t *testing.T) {
	for _, iss := range provider.GoogleIssuers {
		t.Run(iss, func(t *testing.T) {
			google, fake := newGoogle(t)
			claims := providertest.GoogleClaims(googleSubject, testRawNonce, providertest.GoogleClientIDs[0], iss, testNow)

			got, err := google.Verify(context.Background(), fake.SignIDToken(claims), testRawNonce)

			require.NoError(t, err)
			assert.Equal(t, provider.Identity{Subject: googleSubject}, got)
		})
	}
}

func TestGoogle_VerifyAcceptsEveryConfiguredAudience(t *testing.T) {
	for _, aud := range providertest.GoogleClientIDs {
		t.Run(aud, func(t *testing.T) {
			google, fake := newGoogle(t)
			claims := providertest.GoogleClaims(googleSubject, testRawNonce, aud, provider.GoogleIssuers[0], testNow)

			_, err := google.Verify(context.Background(), fake.SignIDToken(claims), testRawNonce)

			require.NoError(t, err)
		})
	}
}

func TestGoogle_VerifyRejectsUnknownAudienceIssuerNonce(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(claims map[string]any)
	}{
		{"모르는 aud", func(c map[string]any) { c["aud"] = "other.apps.googleusercontent.com" }},
		{"모르는 iss", func(c map[string]any) { c["iss"] = "https://evil.example" }},
		{"다른 nonce", func(c map[string]any) { c["nonce"] = providertest.HashNonce("other-nonce") }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			google, fake := newGoogle(t)
			claims := providertest.GoogleClaims(googleSubject, testRawNonce, providertest.GoogleClientIDs[0], provider.GoogleIssuers[0], testNow)
			tt.mutate(claims)

			_, err := google.Verify(context.Background(), fake.SignIDToken(claims), testRawNonce)

			require.ErrorIs(t, err, provider.ErrTokenInvalid)
		})
	}
}

func TestGoogle_VerifyAcceptsRepeatedNonce(t *testing.T) {
	google, fake := newGoogle(t)
	claims := providertest.GoogleClaims(googleSubject, testRawNonce, providertest.GoogleClientIDs[0], provider.GoogleIssuers[0], testNow)

	for range 2 {
		_, err := google.Verify(context.Background(), fake.SignIDToken(claims), testRawNonce)
		require.NoError(t, err)
	}
}

func TestGoogle_VerifyRejectsES256AndExpired(t *testing.T) {
	tests := []struct {
		name string
		sign func(fake *providertest.Server, claims map[string]any) string
		exp  bool
	}{
		{name: "ES256 서명", sign: func(fake *providertest.Server, c map[string]any) string { return fake.SignES256IDToken(c) }},
		{name: "만료", sign: func(fake *providertest.Server, c map[string]any) string { return fake.SignIDToken(c) }, exp: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			google, fake := newGoogle(t)
			claims := providertest.GoogleClaims(googleSubject, testRawNonce, providertest.GoogleClientIDs[0], provider.GoogleIssuers[0], testNow)
			if tt.exp {
				claims["exp"] = testNow.Add(-time.Second).Unix()
			}

			_, err := google.Verify(context.Background(), tt.sign(fake, claims), testRawNonce)

			require.ErrorIs(t, err, provider.ErrTokenInvalid)
		})
	}
}

func TestGoogle_JWKSFailureIsUnavailable(t *testing.T) {
	google, fake := newGoogle(t)
	fake.SetJWKSStatus(http.StatusInternalServerError)
	claims := providertest.GoogleClaims(googleSubject, testRawNonce, providertest.GoogleClientIDs[0], provider.GoogleIssuers[0], testNow)

	_, err := google.Verify(context.Background(), fake.SignIDToken(claims), testRawNonce)

	require.ErrorIs(t, err, provider.ErrUnavailable)
}

func TestGoogle_VerifyHandlesArrayAudience(t *testing.T) {
	multi := []string{"other.apps.googleusercontent.com", providertest.GoogleClientIDs[1]}
	tests := []struct {
		name    string
		aud     []string
		azp     string // 빈 문자열이면 azp claim을 넣지 않습니다.
		wantErr bool
	}{
		{"배열 aud에 설정된 client ID가 있고 azp도 목록 안", multi, providertest.GoogleClientIDs[1], false},
		{"배열 aud인데 azp가 없음", multi, "", true},
		{"배열 aud인데 azp가 목록 밖", multi, "other.apps.googleusercontent.com", true},
		{"배열에 설정된 client ID가 없음", []string{"a.example", "b.example"}, providertest.GoogleClientIDs[1], true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			google, fake := newGoogle(t)
			claims := providertest.GoogleClaims(googleSubject, testRawNonce, "", provider.GoogleIssuers[0], testNow)
			claims["aud"] = tt.aud
			if tt.azp != "" {
				claims["azp"] = tt.azp
			}

			_, err := google.Verify(context.Background(), fake.SignIDToken(claims), testRawNonce)

			if tt.wantErr {
				require.ErrorIs(t, err, provider.ErrTokenInvalid)
				return
			}
			require.NoError(t, err)
		})
	}
}
