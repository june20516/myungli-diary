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
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

var testNow = time.Date(2026, 10, 13, 9, 0, 0, 0, time.UTC)

func newKey(t *testing.T, id string) token.SigningKey {
	t.Helper()
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)
	return token.SigningKey{ID: id, Private: priv}
}

func mustIssuer(t *testing.T, current token.SigningKey, previous []token.SigningKey, clk clock.Clock) *token.AccessIssuer {
	t.Helper()
	issuer, err := token.NewAccessIssuer(current, previous, clk)
	require.NoError(t, err)
	return issuer
}

func TestAccess_IssueThenVerifyReturnsAccount(t *testing.T) {
	issuer := mustIssuer(t, newKey(t, "k1"), nil, clocktest.New(testNow))
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

// 시계에 초 미만 값이 있어도 응답의 만료 시각은 JWT exp(초 단위)와 같습니다.
func TestAccess_IssueExpiresAtMatchesExpClaim(t *testing.T) {
	now := testNow.Add(1234567 * time.Microsecond)
	issuer := mustIssuer(t, newKey(t, "k1"), nil, clocktest.New(now))

	raw, expiresAt, err := issuer.Issue(uuid.Must(uuid.NewV7()))
	require.NoError(t, err)

	parsed, _, err := jwt.NewParser().ParseUnverified(raw, jwt.MapClaims{})
	require.NoError(t, err)
	exp, err := parsed.Claims.GetExpirationTime()
	require.NoError(t, err)
	assert.True(t, exp.Equal(expiresAt), "exp %v, expiresAt %v", exp.Time, expiresAt)
	assert.Equal(t, now.Add(token.AccessTTL).Truncate(time.Second), expiresAt)
}

func TestAccess_ExpiredAfter15Minutes(t *testing.T) {
	clk := clocktest.New(testNow)
	issuer := mustIssuer(t, newKey(t, "k1"), nil, clk)
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
	issuer := mustIssuer(t, key, nil, clocktest.New(testNow))
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

	raw, _, err := mustIssuer(t, oldKey, nil, clk).Issue(account)
	require.NoError(t, err)

	rotated := mustIssuer(t, newKey(t, "new"), []token.SigningKey{oldKey}, clk)
	got, err := rotated.Verify(raw)
	require.NoError(t, err)
	assert.Equal(t, account, got)
}

func TestAccess_UnknownKidIsInvalid(t *testing.T) {
	clk := clocktest.New(testNow)
	raw, _, err := mustIssuer(t, newKey(t, "other"), nil, clk).Issue(uuid.Must(uuid.NewV7()))
	require.NoError(t, err)

	_, err = mustIssuer(t, newKey(t, "k1"), nil, clk).Verify(raw)
	assert.ErrorIs(t, err, token.ErrAccessInvalid)
}

func TestAccess_SubjectMustBeUUID(t *testing.T) {
	key := newKey(t, "k1")
	issuer := mustIssuer(t, key, nil, clocktest.New(testNow))
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
	issuer := mustIssuer(t, newKey(t, "k1"), nil, clocktest.New(testNow))
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

func signRaw(t *testing.T, key token.SigningKey, kid string, claims jwt.MapClaims) string {
	t.Helper()
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	if kid != "" {
		tok.Header["kid"] = kid
	}
	raw, err := tok.SignedString(key.Private)
	require.NoError(t, err)
	return raw
}

func TestAccess_NilSubjectIsInvalid(t *testing.T) {
	key := newKey(t, "k1")
	issuer := mustIssuer(t, key, nil, clocktest.New(testNow))
	raw := signRaw(t, key, "k1", jwt.MapClaims{
		"sub": uuid.Nil.String(),
		"exp": testNow.Add(time.Minute).Unix(),
	})
	_, err := issuer.Verify(raw)
	assert.ErrorIs(t, err, token.ErrAccessInvalid)
}

func TestAccess_MissingKidIsInvalid(t *testing.T) {
	key := newKey(t, "k1")
	issuer := mustIssuer(t, key, nil, clocktest.New(testNow))
	raw := signRaw(t, key, "", jwt.MapClaims{
		"sub": uuid.Must(uuid.NewV7()).String(),
		"exp": testNow.Add(time.Minute).Unix(),
	})
	_, err := issuer.Verify(raw)
	assert.ErrorIs(t, err, token.ErrAccessInvalid)
}

func TestAccess_BadSignatureAndExpiredIsInvalidNotExpired(t *testing.T) {
	issuer := mustIssuer(t, newKey(t, "k1"), nil, clocktest.New(testNow))
	// kid는 맞지만 다른 개인 키로 서명했고, 이미 만료된 토큰입니다.
	raw := signRaw(t, newKey(t, "k1"), "k1", jwt.MapClaims{
		"sub": uuid.Must(uuid.NewV7()).String(),
		"exp": testNow.Add(-time.Minute).Unix(),
	})
	_, err := issuer.Verify(raw)
	assert.ErrorIs(t, err, token.ErrAccessInvalid)
	assert.NotErrorIs(t, err, token.ErrAccessExpired)
}

func TestNewAccessIssuer_RejectsBadKeys(t *testing.T) {
	k1 := newKey(t, "k1")
	tests := []struct {
		name     string
		current  token.SigningKey
		previous []token.SigningKey
	}{
		{"빈 ID", token.SigningKey{Private: k1.Private}, nil},
		{"previous가 current와 같은 ID", k1, []token.SigningKey{newKey(t, "k1")}},
		{"previous끼리 중복", k1, []token.SigningKey{newKey(t, "a"), newKey(t, "a")}},
		{"nil 개인 키", token.SigningKey{ID: "k1"}, nil},
		{"previous의 nil 개인 키", k1, []token.SigningKey{{ID: "old"}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := token.NewAccessIssuer(tt.current, tt.previous, clocktest.New(testNow))
			assert.Error(t, err)
		})
	}
}

func TestParseSigningKey_RejectsEmptyID(t *testing.T) {
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)
	der, err := x509.MarshalPKCS8PrivateKey(priv)
	require.NoError(t, err)
	_, err = token.ParseSigningKey("", string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})))
	assert.Error(t, err)
}
