package provider_test

import (
	"context"
	"testing"

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
