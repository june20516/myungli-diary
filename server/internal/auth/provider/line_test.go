package provider_test

import (
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

const lineSubject = "U4af4980629"

func newLINE(t *testing.T) (*provider.LINE, *providertest.Server) {
	t.Helper()
	fake := providertest.New(t)
	return fake.NewLINE(t, clocktest.New(testNow)), fake
}

func TestLINE_VerifyAcceptsValidES256Token(t *testing.T) {
	line, fake := newLINE(t)
	idToken := fake.SignES256IDToken(providertest.LINEClaims(lineSubject, testRawNonce, testNow))

	got, err := line.Verify(context.Background(), idToken, testRawNonce)

	require.NoError(t, err)
	assert.Equal(t, provider.Identity{Subject: lineSubject}, got)
}

func TestLINE_VerifyRejectsWrongAudienceIssuerNonceExpiryAndRS256(t *testing.T) {
	tests := []struct {
		name string
		// sign은 claims를 서명해 id_token을 돌려줍니다. nil이면 ES256입니다.
		sign   func(fake *providertest.Server, claims map[string]any) string
		mutate func(claims map[string]any)
	}{
		{name: "다른 aud", mutate: func(c map[string]any) { c["aud"] = "other" }},
		{name: "다른 iss", mutate: func(c map[string]any) { c["iss"] = "https://example.com" }},
		{name: "다른 nonce", mutate: func(c map[string]any) { c["nonce"] = providertest.HashNonce("other-nonce") }},
		{name: "만료", mutate: func(c map[string]any) { c["exp"] = testNow.Add(-1).Unix() }},
		{
			name:   "RS256 서명",
			sign:   func(fake *providertest.Server, c map[string]any) string { return fake.SignIDToken(c) },
			mutate: func(map[string]any) {},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			line, fake := newLINE(t)
			claims := providertest.LINEClaims(lineSubject, testRawNonce, testNow)
			tt.mutate(claims)
			idToken := fake.SignES256IDToken(claims)
			if tt.sign != nil {
				idToken = tt.sign(fake, claims)
			}

			_, err := line.Verify(context.Background(), idToken, testRawNonce)

			require.ErrorIs(t, err, provider.ErrTokenInvalid)
		})
	}
}

func TestLINE_JWKSFailureIsUnavailable(t *testing.T) {
	line, fake := newLINE(t)
	fake.SetJWKSStatus(http.StatusInternalServerError)
	idToken := fake.SignES256IDToken(providertest.LINEClaims(lineSubject, testRawNonce, testNow))

	_, err := line.Verify(context.Background(), idToken, testRawNonce)

	require.ErrorIs(t, err, provider.ErrUnavailable)
}
