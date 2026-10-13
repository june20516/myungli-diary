// Package token은 서버 자체 토큰(access JWT, refresh 난수)을 만들고 검증합니다.
package token

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

const (
	// AccessTTL은 access token의 유효 기간입니다.
	AccessTTL = 15 * time.Minute
	// RefreshTTL은 refresh token의 유효 기간입니다.
	RefreshTTL = 30 * 24 * time.Hour
)

var (
	// ErrAccessExpired는 서명은 맞지만 만료된 access token일 때 돌려줍니다.
	ErrAccessExpired = errors.New("access token expired")
	// ErrAccessInvalid는 형식·서명·알고리즘·kid·sub가 올바르지 않은 access token일 때 돌려줍니다.
	ErrAccessInvalid = errors.New("access token invalid")
)

// SigningKey는 kid(ID)가 붙은 ES256 서명 키입니다.
type SigningKey struct {
	ID      string
	Private *ecdsa.PrivateKey
}

// ParseSigningKey는 PKCS8 PEM 형식의 EC 개인 키를 읽습니다. P-256 곡선이 아니면 오류입니다.
func ParseSigningKey(id, pemPKCS8 string) (SigningKey, error) {
	if id == "" {
		return SigningKey{}, errors.New("서명 키: id가 비어 있습니다")
	}
	block, _ := pem.Decode([]byte(pemPKCS8))
	if block == nil {
		return SigningKey{}, errors.New("서명 키: PEM 블록이 없습니다")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return SigningKey{}, fmt.Errorf("서명 키: PKCS8 해석 실패: %w", err)
	}
	priv, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		return SigningKey{}, errors.New("서명 키: EC 키가 아닙니다")
	}
	if priv.Curve != elliptic.P256() {
		return SigningKey{}, errors.New("서명 키: P-256 곡선이 아닙니다")
	}
	return SigningKey{ID: id, Private: priv}, nil
}

// AccessIssuer는 access token을 발급하고 검증합니다.
// 발급은 current 키로만, 검증은 current와 previous(키 교체 중 유효한 이전 키)로 합니다.
type AccessIssuer struct {
	current SigningKey
	keys    map[string]*ecdsa.PublicKey // kid -> 검증용 공개 키
	clk     clock.Clock
}

// NewAccessIssuer는 AccessIssuer를 만듭니다.
// 빈 ID, current를 포함한 중복 ID, 개인 키가 없는 항목은 오류입니다.
// (중복을 허용하면 한 kid가 다른 키로 덮여 새 토큰이 모두 무효가 될 수 있습니다.)
func NewAccessIssuer(current SigningKey, previous []SigningKey, clk clock.Clock) (*AccessIssuer, error) {
	keys := make(map[string]*ecdsa.PublicKey, len(previous)+1)
	for _, k := range append([]SigningKey{current}, previous...) {
		if k.ID == "" {
			return nil, errors.New("서명 키: id가 비어 있습니다")
		}
		if k.Private == nil {
			return nil, fmt.Errorf("서명 키 %q: 개인 키가 없습니다", k.ID)
		}
		if _, dup := keys[k.ID]; dup {
			return nil, fmt.Errorf("서명 키 %q: id가 중복됩니다", k.ID)
		}
		keys[k.ID] = &k.Private.PublicKey
	}
	return &AccessIssuer{current: current, keys: keys, clk: clk}, nil
}

// Issue는 계정의 access token을 발급합니다.
// JWT의 exp는 초 단위이므로 expiresAt도 초 단위로 내림해, 응답에 담는 만료 시각이 토큰의 exp와 정확히 같게 합니다.
func (i *AccessIssuer) Issue(accountID uuid.UUID) (string, time.Time, error) {
	jti, err := uuid.NewV7()
	if err != nil {
		return "", time.Time{}, fmt.Errorf("jti 생성: %w", err)
	}
	now := i.clk.Now()
	expiresAt := now.Add(AccessTTL).Truncate(time.Second)
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.RegisteredClaims{
		Subject:   accountID.String(),
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(expiresAt),
		ID:        jti.String(),
	})
	tok.Header["kid"] = i.current.ID
	raw, err := tok.SignedString(i.current.Private)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("access token 서명: %w", err)
	}
	return raw, expiresAt, nil
}

// Verify는 access token을 검증하고 계정 id를 돌려줍니다.
// 오류는 ErrAccessExpired 또는 ErrAccessInvalid 중 하나로 판별됩니다.
func (i *AccessIssuer) Verify(raw string) (uuid.UUID, error) {
	claims := &jwt.RegisteredClaims{}
	_, err := jwt.ParseWithClaims(raw, claims, i.keyFunc,
		jwt.WithValidMethods([]string{jwt.SigningMethodES256.Alg()}),
		jwt.WithTimeFunc(i.clk.Now),
		jwt.WithExpirationRequired(),
	)
	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return uuid.Nil, ErrAccessExpired
		}
		return uuid.Nil, ErrAccessInvalid
	}
	id, err := uuid.Parse(claims.Subject)
	if err != nil || id == uuid.Nil {
		return uuid.Nil, ErrAccessInvalid
	}
	return id, nil
}

// keyFunc는 헤더의 kid로 검증 키를 고릅니다. 모르는 kid는 거절합니다.
func (i *AccessIssuer) keyFunc(t *jwt.Token) (any, error) {
	kid, _ := t.Header["kid"].(string)
	key, ok := i.keys[kid]
	if !ok {
		return nil, errors.New("알 수 없는 kid")
	}
	return key, nil
}
