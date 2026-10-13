package token_test

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

var testNow = time.Date(2026, 10, 13, 9, 0, 0, 0, time.UTC)

func newKey(t *testing.T, id string) token.SigningKey {
	t.Helper()
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)
	return token.SigningKey{ID: id, Private: priv}
}

func TestAccess_IssueThenVerifyReturnsAccount(t *testing.T) {
	issuer := token.NewAccessIssuer(newKey(t, "k1"), nil, clocktest.New(testNow))
	account := uuid.Must(uuid.NewV7())

	raw, expiresAt, err := issuer.Issue(account)
	require.NoError(t, err)
	assert.Equal(t, testNow.Add(token.AccessTTL), expiresAt)

	got, err := issuer.Verify(raw)
	require.NoError(t, err)
	assert.Equal(t, account, got)

	parsed, _, err := jwt.NewParser().ParseUnverified(raw, jwt.MapClaims{})
	require.NoError(t, err)
	assert.Equal(t, "ES256", parsed.Header["alg"])
	assert.Equal(t, "k1", parsed.Header["kid"])
	claims := parsed.Claims.(jwt.MapClaims)
	jti, err := uuid.Parse(claims["jti"].(string))
	require.NoError(t, err)
	assert.Equal(t, uuid.Version(7), jti.Version())
}

func TestAccess_ExpiredAfter15Minutes(t *testing.T) {
	clk := clocktest.New(testNow)
	issuer := token.NewAccessIssuer(newKey(t, "k1"), nil, clk)
	raw, _, err := issuer.Issue(uuid.Must(uuid.NewV7()))
	require.NoError(t, err)

	clk.Advance(token.AccessTTL - time.Second)
	_, err = issuer.Verify(raw)
	require.NoError(t, err)

	clk.Advance(2 * time.Second)
	_, err = issuer.Verify(raw)
	assert.ErrorIs(t, err, token.ErrAccessExpired)
	assert.NotErrorIs(t, err, token.ErrAccessInvalid)
}

func TestAccess_RejectsOtherAlgorithms(t *testing.T) {
	key := newKey(t, "k1")
	issuer := token.NewAccessIssuer(key, nil, clocktest.New(testNow))
	claims := jwt.MapClaims{
		"sub": uuid.Must(uuid.NewV7()).String(),
		"iat": testNow.Unix(),
		"exp": testNow.Add(time.Minute).Unix(),
	}

	pubDER, err := x509.MarshalPKIXPublicKey(&key.Private.PublicKey)
	require.NoError(t, err)
	pubPEM := pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: pubDER})

	hs := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	hs.Header["kid"] = "k1"
	hsRaw, err := hs.SignedString(pubPEM)
	require.NoError(t, err)

	none := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	none.Header["kid"] = "k1"
	noneRaw, err := none.SignedString(jwt.UnsafeAllowNoneSignatureType)
	require.NoError(t, err)

	for name, raw := range map[string]string{"HS256": hsRaw, "none": noneRaw} {
		t.Run(name, func(t *testing.T) {
			_, err := issuer.Verify(raw)
			assert.ErrorIs(t, err, token.ErrAccessInvalid)
		})
	}
}

func TestAccess_VerifiesTokenSignedByPreviousKey(t *testing.T) {
	oldKey := newKey(t, "old")
	clk := clocktest.New(testNow)
	account := uuid.Must(uuid.NewV7())

	raw, _, err := token.NewAccessIssuer(oldKey, nil, clk).Issue(account)
	require.NoError(t, err)

	rotated := token.NewAccessIssuer(newKey(t, "new"), []token.SigningKey{oldKey}, clk)
	got, err := rotated.Verify(raw)
	require.NoError(t, err)
	assert.Equal(t, account, got)
}

func TestAccess_UnknownKidIsInvalid(t *testing.T) {
	clk := clocktest.New(testNow)
	raw, _, err := token.NewAccessIssuer(newKey(t, "other"), nil, clk).Issue(uuid.Must(uuid.NewV7()))
	require.NoError(t, err)

	_, err = token.NewAccessIssuer(newKey(t, "k1"), nil, clk).Verify(raw)
	assert.ErrorIs(t, err, token.ErrAccessInvalid)
}

func TestAccess_SubjectMustBeUUID(t *testing.T) {
	key := newKey(t, "k1")
	issuer := token.NewAccessIssuer(key, nil, clocktest.New(testNow))
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{
		"sub": "abc",
		"iat": testNow.Unix(),
		"exp": testNow.Add(time.Minute).Unix(),
	})
	tok.Header["kid"] = "k1"
	raw, err := tok.SignedString(key.Private)
	require.NoError(t, err)

	_, err = issuer.Verify(raw)
	assert.ErrorIs(t, err, token.ErrAccessInvalid)
}

func TestAccess_GarbageIsInvalid(t *testing.T) {
	issuer := token.NewAccessIssuer(newKey(t, "k1"), nil, clocktest.New(testNow))
	_, err := issuer.Verify("not-a-jwt")
	assert.ErrorIs(t, err, token.ErrAccessInvalid)
}

func TestParseSigningKey(t *testing.T) {
	pemOf := func(t *testing.T, curve elliptic.Curve) string {
		priv, err := ecdsa.GenerateKey(curve, rand.Reader)
		require.NoError(t, err)
		der, err := x509.MarshalPKCS8PrivateKey(priv)
		require.NoError(t, err)
		return string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))
	}

	tests := []struct {
		name    string
		pem     string
		wantErr bool
	}{
		{"P-256", pemOf(t, elliptic.P256()), false},
		{"P-384", pemOf(t, elliptic.P384()), true},
		{"PEM 아님", "garbage", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			key, err := token.ParseSigningKey("k1", tt.pem)
			if tt.wantErr {
				assert.Error(t, err)
				return
			}
			require.NoError(t, err)
			assert.Equal(t, "k1", key.ID)
			assert.NotNil(t, key.Private)
		})
	}
}
