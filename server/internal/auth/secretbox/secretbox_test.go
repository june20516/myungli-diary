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

var aad = []byte("identity-row-id")

func mustBox(t *testing.T, current secretbox.Key, previous []secretbox.Key) *secretbox.Box {
	t.Helper()
	box, err := secretbox.New(current, previous)
	require.NoError(t, err)
	return box
}

func TestSecretbox_SealOpenRoundTrip(t *testing.T) {
	box := mustBox(t, key(t, "k1", 1), nil)
	plain := []byte("apple-refresh-token")

	ct, keyID, err := box.Seal(plain, aad)
	require.NoError(t, err)
	assert.Equal(t, "k1", keyID)
	assert.NotContains(t, string(ct), string(plain))

	got, err := box.Open(ct, keyID, aad)
	require.NoError(t, err)
	assert.Equal(t, plain, got)

	ct2, _, err := box.Seal(plain, aad)
	require.NoError(t, err)
	assert.NotEqual(t, ct, ct2, "nonce가 매번 달라야 합니다")
}

func TestSecretbox_OpenWithPreviousKey(t *testing.T) {
	oldKey := key(t, "old", 1)
	ct, keyID, err := mustBox(t, oldKey, nil).Seal([]byte("secret"), aad)
	require.NoError(t, err)

	rotated := mustBox(t, key(t, "new", 2), []secretbox.Key{oldKey})
	got, err := rotated.Open(ct, keyID, aad)
	require.NoError(t, err)
	assert.Equal(t, []byte("secret"), got)

	_, err = rotated.Open(ct, "unknown", aad)
	assert.Error(t, err)
}

func TestSecretbox_TamperedCiphertextFails(t *testing.T) {
	box := mustBox(t, key(t, "k1", 1), nil)
	ct, keyID, err := box.Seal([]byte("secret"), aad)
	require.NoError(t, err)

	ct[len(ct)-1] ^= 0xff
	_, err = box.Open(ct, keyID, aad)
	assert.Error(t, err)

	_, err = box.Open([]byte("short"), keyID, aad)
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

func TestSecretbox_OpenWithDifferentAADFails(t *testing.T) {
	box := mustBox(t, key(t, "k1", 1), nil)
	ct, keyID, err := box.Seal([]byte("secret"), aad)
	require.NoError(t, err)

	_, err = box.Open(ct, keyID, []byte("other-row"))
	assert.Error(t, err)
	_, err = box.Open(ct, keyID, nil)
	assert.Error(t, err)
}

func TestSecretbox_NewRejectsBadKeys(t *testing.T) {
	k1 := key(t, "k1", 1)
	tests := []struct {
		name     string
		current  secretbox.Key
		previous []secretbox.Key
	}{
		{"빈 ID", secretbox.Key{ID: "", Bytes: k1.Bytes}, nil},
		{"previous가 current와 같은 ID", k1, []secretbox.Key{key(t, "k1", 2)}},
		{"previous끼리 중복", k1, []secretbox.Key{key(t, "a", 2), key(t, "a", 3)}},
		{"짧은 키", secretbox.Key{ID: "k1", Bytes: make([]byte, 16)}, nil},
		{"nil 키", secretbox.Key{ID: "k1"}, nil},
		{"previous의 짧은 키", k1, []secretbox.Key{{ID: "old", Bytes: []byte{1}}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := secretbox.New(tt.current, tt.previous)
			assert.Error(t, err)
		})
	}
}

func TestSecretbox_ParseKeyRejectsEmptyID(t *testing.T) {
	_, err := secretbox.ParseKey("", base64.StdEncoding.EncodeToString(make([]byte, 32)))
	assert.Error(t, err)
}
