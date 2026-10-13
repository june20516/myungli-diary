package secretbox_test

import (
	"bytes"
	"encoding/base64"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/secretbox"
)

func key(t *testing.T, id string, fill byte) secretbox.Key {
	t.Helper()
	k, err := secretbox.ParseKey(id, base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{fill}, 32)))
	require.NoError(t, err)
	return k
}

func TestSecretbox_SealOpenRoundTrip(t *testing.T) {
	box := secretbox.New(key(t, "k1", 1), nil)
	plain := []byte("apple-refresh-token")

	ct, keyID, err := box.Seal(plain)
	require.NoError(t, err)
	assert.Equal(t, "k1", keyID)
	assert.NotContains(t, string(ct), string(plain))

	got, err := box.Open(ct, keyID)
	require.NoError(t, err)
	assert.Equal(t, plain, got)

	ct2, _, err := box.Seal(plain)
	require.NoError(t, err)
	assert.NotEqual(t, ct, ct2, "nonce가 매번 달라야 합니다")
}

func TestSecretbox_OpenWithPreviousKey(t *testing.T) {
	oldKey := key(t, "old", 1)
	ct, keyID, err := secretbox.New(oldKey, nil).Seal([]byte("secret"))
	require.NoError(t, err)

	rotated := secretbox.New(key(t, "new", 2), []secretbox.Key{oldKey})
	got, err := rotated.Open(ct, keyID)
	require.NoError(t, err)
	assert.Equal(t, []byte("secret"), got)

	_, err = rotated.Open(ct, "unknown")
	assert.Error(t, err)
}

func TestSecretbox_TamperedCiphertextFails(t *testing.T) {
	box := secretbox.New(key(t, "k1", 1), nil)
	ct, keyID, err := box.Seal([]byte("secret"))
	require.NoError(t, err)

	ct[len(ct)-1] ^= 0xff
	_, err = box.Open(ct, keyID)
	assert.Error(t, err)

	_, err = box.Open([]byte("short"), keyID)
	assert.Error(t, err)
}

func TestSecretbox_ParseKeyRejectsWrongLength(t *testing.T) {
	tests := []struct {
		name string
		in   string
	}{
		{"16바이트", base64.StdEncoding.EncodeToString(make([]byte, 16))},
		{"base64 아님", "!!!"},
		{"빈 값", ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := secretbox.ParseKey("k1", tt.in)
			assert.Error(t, err)
		})
	}
}
