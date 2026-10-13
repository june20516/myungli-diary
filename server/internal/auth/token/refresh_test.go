package token_test

import (
	"crypto/sha256"
	"encoding/base64"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/token"
)

func TestRefresh_TokenHas256BitsAndHashIsSHA256(t *testing.T) {
	raw, hash, err := token.NewRefreshToken()
	require.NoError(t, err)

	decoded, err := base64.RawURLEncoding.DecodeString(raw)
	require.NoError(t, err)
	assert.Len(t, decoded, 32)

	sum := sha256.Sum256([]byte(raw))
	assert.Equal(t, sum[:], hash)
	assert.Equal(t, hash, token.HashRefreshToken(raw))

	other, _, err := token.NewRefreshToken()
	require.NoError(t, err)
	assert.NotEqual(t, raw, other)
}
