// Package opsapi는 IAP로 막은 운영 API(server-ops)의 인증과 허용 목록을 다룹니다.
package opsapi

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

const (
	// AssertionHeader는 IAP가 서명한 신원 JWT를 담아 앱에 넘기는 헤더입니다.
	AssertionHeader = "x-goog-iap-jwt-assertion"
	// IAPPublicKeyURL은 IAP 서명 공개키(JWK Set) 주소입니다.
	IAPPublicKeyURL = "https://www.gstatic.com/iap/verify/public_key-jwk"

	iapIssuer = "https://cloud.google.com/iap"

	// 시각 비교 허용 오차(exp, iat, nbf).
	assertionLeeway = 30 * time.Second

	keyCacheTTL        = time.Hour
	keyRefetchInterval = time.Minute
	keyFetchTimeout    = 10 * time.Second
	keyResponseLimit   = 1 << 20 // 1 MiB

	p256CoordinateSize = 32
)

// 호출자가 errors.Is로 구분하는 오류입니다. 토큰 원문과 메일은 오류 문구에 담지 않습니다.
var (
	// ErrNoAssertion은 서명 헤더가 없거나 비어 있음을 뜻합니다(401).
	ErrNoAssertion = errors.New("opsapi: IAP 서명 헤더가 없습니다")
	// ErrInvalidAssertion은 서명 헤더가 검증을 통과하지 못했음을 뜻합니다(401).
	ErrInvalidAssertion = errors.New("opsapi: IAP 서명 헤더가 유효하지 않습니다")
	// ErrKeysUnavailable은 IAP 공개키를 구할 수 없음을 뜻합니다(503).
	ErrKeysUnavailable = errors.New("opsapi: IAP 공개키를 구할 수 없습니다")
)

// Identity는 검증을 통과한 운영자 신원입니다. Email은 trim과 소문자로 정규화한 값입니다.
type Identity struct {
	Email   string
	Subject string
}

// KeySource는 kid별 IAP 공개키를 내줍니다.
type KeySource interface {
	Keys(ctx context.Context) (map[string]*ecdsa.PublicKey, error)
}

// refresher는 모르는 kid를 만났을 때 캐시를 다시 받아 보는 KeySource의 선택 기능입니다.
type refresher interface {
	Refresh(ctx context.Context) (map[string]*ecdsa.PublicKey, error)
}

// Verifier는 IAP 서명 헤더를 검증해 운영자 신원을 돌려줍니다.
type Verifier struct {
	keys     KeySource
	audience string
	clock    clock.Clock
}

// NewVerifier는 audience(/projects/<번호>/locations/<리전>/services/<서비스>)와 정확히
// 일치하는 서명 헤더만 받는 Verifier를 만듭니다.
func NewVerifier(keys KeySource, audience string, clk clock.Clock) *Verifier {
	return &Verifier{keys: keys, audience: audience, clock: clk}
}

// Verify는 서명 헤더를 검증합니다. alg는 ES256만, iss와 aud는 정확 일치,
// exp와 iat는 필수(허용 오차 30초)이며 email과 sub가 비어 있으면 무효입니다.
func (v *Verifier) Verify(ctx context.Context, assertion string) (Identity, error) {
	assertion = strings.TrimSpace(assertion)
	if assertion == "" {
		return Identity{}, ErrNoAssertion
	}

	parser := jwt.NewParser(
		jwt.WithValidMethods([]string{jwt.SigningMethodES256.Alg()}),
		jwt.WithIssuer(iapIssuer),
		jwt.WithAudience(v.audience),
		jwt.WithExpirationRequired(),
		jwt.WithIssuedAt(),
		jwt.WithLeeway(assertionLeeway),
		jwt.WithTimeFunc(v.clock.Now),
	)
	claims := jwt.MapClaims{}
	_, err := parser.ParseWithClaims(assertion, claims, func(token *jwt.Token) (any, error) {
		return v.publicKey(ctx, token)
	})
	if err != nil {
		if errors.Is(err, ErrKeysUnavailable) {
			return Identity{}, ErrKeysUnavailable
		}
		return Identity{}, fmt.Errorf("%w: %w", ErrInvalidAssertion, err)
	}

	if iat, err := claims.GetIssuedAt(); err != nil || iat == nil {
		return Identity{}, fmt.Errorf("%w: iat가 없습니다", ErrInvalidAssertion)
	}
	email, _ := claims["email"].(string)
	subject, _ := claims["sub"].(string)
	email = normalizeEmail(email)
	if email == "" || strings.TrimSpace(subject) == "" {
		return Identity{}, fmt.Errorf("%w: email 또는 sub가 없습니다", ErrInvalidAssertion)
	}
	return Identity{Email: email, Subject: subject}, nil
}

// publicKey는 토큰 헤더의 kid로 공개키를 고릅니다. 모르는 kid면 한 번 다시 받아 봅니다.
func (v *Verifier) publicKey(ctx context.Context, token *jwt.Token) (any, error) {
	kid, _ := token.Header["kid"].(string)
	if kid == "" {
		return nil, errors.New("kid가 없습니다")
	}
	keys, err := v.keys.Keys(ctx)
	if err != nil {
		return nil, asKeysUnavailable(err)
	}
	if key, ok := keys[kid]; ok {
		return key, nil
	}
	if r, ok := v.keys.(refresher); ok {
		if keys, err = r.Refresh(ctx); err != nil {
			return nil, asKeysUnavailable(err)
		}
		if key, ok := keys[kid]; ok {
			return key, nil
		}
	}
	return nil, errors.New("알 수 없는 kid입니다")
}

// asKeysUnavailable은 공개키 조회 실패를 ErrKeysUnavailable로 분류합니다.
func asKeysUnavailable(err error) error {
	if errors.Is(err, ErrKeysUnavailable) {
		return err
	}
	return fmt.Errorf("%w: %w", ErrKeysUnavailable, err)
}

// httpKeySource는 IAP 공개키를 HTTP로 받아 캐시합니다. 동시 요청에 안전합니다.
type httpKeySource struct {
	client *http.Client
	url    string
	clock  clock.Clock

	mu          sync.Mutex
	cache       map[string]*ecdsa.PublicKey
	fetchedAt   time.Time // 마지막으로 성공한 시각
	attemptedAt time.Time // 마지막으로 요청한 시각(성공과 실패 모두)
}

// NewHTTPKeySource는 url의 JWK Set을 1시간 캐시하는 KeySource를 만듭니다.
// 받기에 실패하면 캐시가 있을 때 캐시를 쓰고, 없으면 ErrKeysUnavailable을 돌려줍니다.
// 모르는 kid로 다시 받는 일은 최소 1분 간격으로 제한합니다.
func NewHTTPKeySource(client *http.Client, url string, clk clock.Clock) KeySource {
	return &httpKeySource{client: client, url: url, clock: clk}
}

func (s *httpKeySource) Keys(ctx context.Context) (map[string]*ecdsa.PublicKey, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.clock.Now()
	if s.cache != nil && now.Sub(s.fetchedAt) < keyCacheTTL {
		return s.cache, nil
	}
	return s.refreshLocked(ctx, now)
}

// Refresh는 캐시가 있어도 다시 받습니다. 직전 요청이 1분 안이면 받지 않고 캐시를 돌려줍니다.
func (s *httpKeySource) Refresh(ctx context.Context) (map[string]*ecdsa.PublicKey, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.refreshLocked(ctx, s.clock.Now())
}

func (s *httpKeySource) refreshLocked(ctx context.Context, now time.Time) (map[string]*ecdsa.PublicKey, error) {
	if s.cache != nil && now.Sub(s.attemptedAt) < keyRefetchInterval {
		return s.cache, nil
	}
	s.attemptedAt = now

	keys, err := s.fetch(ctx)
	if err != nil {
		if s.cache != nil {
			return s.cache, nil
		}
		return nil, fmt.Errorf("%w: %w", ErrKeysUnavailable, err)
	}
	s.cache = keys
	s.fetchedAt = now
	return keys, nil
}

type jwkSet struct {
	Keys []struct {
		Kty string `json:"kty"`
		Crv string `json:"crv"`
		Kid string `json:"kid"`
		X   string `json:"x"`
		Y   string `json:"y"`
	} `json:"keys"`
}

func (s *httpKeySource) fetch(ctx context.Context) (map[string]*ecdsa.PublicKey, error) {
	ctx, cancel := context.WithTimeout(ctx, keyFetchTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.url, nil)
	if err != nil {
		return nil, err
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("공개키 응답 상태 %d", resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, keyResponseLimit+1))
	if err != nil {
		return nil, err
	}
	if len(body) > keyResponseLimit {
		return nil, errors.New("공개키 응답이 너무 큽니다")
	}

	var set jwkSet
	if err := json.Unmarshal(body, &set); err != nil {
		return nil, fmt.Errorf("공개키 응답 해석: %w", err)
	}
	keys := make(map[string]*ecdsa.PublicKey, len(set.Keys))
	for _, k := range set.Keys {
		if k.Kty != "EC" || k.Crv != "P-256" || k.Kid == "" {
			return nil, errors.New("지원하지 않는 공개키입니다(EC P-256만 허용)")
		}
		key, err := p256PublicKey(k.X, k.Y)
		if err != nil {
			return nil, err
		}
		keys[k.Kid] = key
	}
	if len(keys) == 0 {
		return nil, errors.New("공개키가 비어 있습니다")
	}
	return keys, nil
}

// p256PublicKey는 JWK의 x, y(base64url, 각 32바이트)로 P-256 공개키를 만듭니다.
// 곡선 위의 점이 아니면 거절합니다.
func p256PublicKey(x, y string) (*ecdsa.PublicKey, error) {
	xBytes, err := base64.RawURLEncoding.DecodeString(x)
	if err != nil || len(xBytes) != p256CoordinateSize {
		return nil, errors.New("공개키 x 해석 실패")
	}
	yBytes, err := base64.RawURLEncoding.DecodeString(y)
	if err != nil || len(yBytes) != p256CoordinateSize {
		return nil, errors.New("공개키 y 해석 실패")
	}
	uncompressed := append([]byte{0x04}, xBytes...)
	uncompressed = append(uncompressed, yBytes...)
	key, err := ecdsa.ParseUncompressedPublicKey(elliptic.P256(), uncompressed)
	if err != nil {
		return nil, errors.New("공개키가 P-256 곡선 위의 점이 아닙니다")
	}
	return key, nil
}
