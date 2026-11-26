package opsapi_test

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/june20516/myungli-diary/server/internal/opsapi"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

const (
	testAudience = "/projects/123/locations/asia-northeast3/services/server-ops"
	testIssuer   = "https://cloud.google.com/iap"
)

var testNow = time.Date(2026, 11, 26, 3, 0, 0, 0, time.UTC)

func newKey(t *testing.T) *ecdsa.PrivateKey {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("키 생성: %v", err)
	}
	return key
}

type staticKeys struct {
	keys map[string]*ecdsa.PublicKey
	err  error
}

func (s staticKeys) Keys(context.Context) (map[string]*ecdsa.PublicKey, error) {
	return s.keys, s.err
}

func validClaims() jwt.MapClaims {
	return jwt.MapClaims{
		"iss":   testIssuer,
		"aud":   testAudience,
		"sub":   "accounts.google.com:1234",
		"email": "Op@Example.com",
		"iat":   testNow.Add(-time.Minute).Unix(),
		"exp":   testNow.Add(10 * time.Minute).Unix(),
	}
}

func sign(t *testing.T, key *ecdsa.PrivateKey, kid string, claims jwt.MapClaims) string {
	t.Helper()
	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = kid
	signed, err := token.SignedString(key)
	if err != nil {
		t.Fatalf("서명: %v", err)
	}
	return signed
}

func newVerifier(key *ecdsa.PrivateKey) *opsapi.Verifier {
	keys := staticKeys{keys: map[string]*ecdsa.PublicKey{"k1": &key.PublicKey}}
	return opsapi.NewVerifier(keys, testAudience, clocktest.New(testNow))
}

func TestVerifier_Valid(t *testing.T) {
	key := newKey(t)
	got, err := newVerifier(key).Verify(context.Background(), sign(t, key, "k1", validClaims()))
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	want := opsapi.Identity{Email: "op@example.com", Subject: "accounts.google.com:1234"}
	if got != want {
		t.Errorf("Identity = %+v, want %+v", got, want)
	}
}

func TestVerifier_AudienceArray(t *testing.T) {
	key := newKey(t)
	claims := validClaims()
	claims["aud"] = []string{"other", testAudience}
	if _, err := newVerifier(key).Verify(context.Background(), sign(t, key, "k1", claims)); err != nil {
		t.Fatalf("aud 배열 안에 일치하는 값이 있으면 통과해야 합니다: %v", err)
	}
}

func TestVerifier_NoAssertion(t *testing.T) {
	_, err := newVerifier(newKey(t)).Verify(context.Background(), "  ")
	if !errors.Is(err, opsapi.ErrNoAssertion) {
		t.Errorf("err = %v, want ErrNoAssertion", err)
	}
}

func TestVerifier_Invalid(t *testing.T) {
	key := newKey(t)
	other := newKey(t)

	mutate := func(f func(jwt.MapClaims)) string {
		c := validClaims()
		f(c)
		return sign(t, key, "k1", c)
	}

	hs256 := jwt.NewWithClaims(jwt.SigningMethodHS256, validClaims())
	hs256.Header["kid"] = "k1"
	hsSigned, err := hs256.SignedString([]byte("secret"))
	if err != nil {
		t.Fatal(err)
	}
	noneToken := jwt.NewWithClaims(jwt.SigningMethodNone, validClaims())
	noneToken.Header["kid"] = "k1"
	noneSigned, err := noneToken.SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		name      string
		assertion string
	}{
		{"서명 틀림", sign(t, other, "k1", validClaims())},
		{"HS256", hsSigned},
		{"none", noneSigned},
		{"aud 틀림", mutate(func(c jwt.MapClaims) { c["aud"] = "/projects/1/locations/x/services/y" })},
		{"iss 틀림", mutate(func(c jwt.MapClaims) { c["iss"] = "https://accounts.google.com" })},
		{"만료", mutate(func(c jwt.MapClaims) { c["exp"] = testNow.Add(-time.Minute).Unix() })},
		{"exp 없음", mutate(func(c jwt.MapClaims) { delete(c, "exp") })},
		{"미래 iat", mutate(func(c jwt.MapClaims) { c["iat"] = testNow.Add(5 * time.Minute).Unix() })},
		{"iat 없음", mutate(func(c jwt.MapClaims) { delete(c, "iat") })},
		{"미래 nbf", mutate(func(c jwt.MapClaims) { c["nbf"] = testNow.Add(5 * time.Minute).Unix() })},
		{"email 없음", mutate(func(c jwt.MapClaims) { delete(c, "email") })},
		{"email 공백", mutate(func(c jwt.MapClaims) { c["email"] = "  " })},
		{"sub 없음", mutate(func(c jwt.MapClaims) { delete(c, "sub") })},
		{"쓰레기", "not-a-jwt"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := newVerifier(key).Verify(context.Background(), tt.assertion)
			if !errors.Is(err, opsapi.ErrInvalidAssertion) {
				t.Errorf("err = %v, want ErrInvalidAssertion", err)
			}
		})
	}
}

func TestVerifier_Leeway(t *testing.T) {
	key := newKey(t)
	claims := validClaims()
	claims["exp"] = testNow.Add(-20 * time.Second).Unix()
	claims["iat"] = testNow.Add(20 * time.Second).Unix()
	if _, err := newVerifier(key).Verify(context.Background(), sign(t, key, "k1", claims)); err != nil {
		t.Errorf("허용 오차 30초 안은 통과해야 합니다: %v", err)
	}
}

func TestVerifier_UnknownKid(t *testing.T) {
	key := newKey(t)
	_, err := newVerifier(key).Verify(context.Background(), sign(t, key, "nope", validClaims()))
	if !errors.Is(err, opsapi.ErrInvalidAssertion) {
		t.Errorf("err = %v, want ErrInvalidAssertion", err)
	}
}

func TestVerifier_KeyFetchFailure(t *testing.T) {
	key := newKey(t)
	token := sign(t, key, "k1", validClaims())
	v := opsapi.NewVerifier(staticKeys{err: errors.New("down")}, testAudience, clocktest.New(testNow))
	if _, err := v.Verify(context.Background(), token); !errors.Is(err, opsapi.ErrKeysUnavailable) {
		t.Errorf("err = %v, want ErrKeysUnavailable", err)
	}
}

// jwkServer는 IAP 공개키 JWK Set을 내주는 테스트 서버입니다.
type jwkServer struct {
	*httptest.Server
	hits    atomic.Int32
	mu      sync.Mutex
	keys    map[string]*ecdsa.PublicKey
	fail    bool
	curve   string
	rawBody []byte
}

func newJWKServer(t *testing.T, keys map[string]*ecdsa.PublicKey) *jwkServer {
	t.Helper()
	s := &jwkServer{keys: keys}
	s.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		s.hits.Add(1)
		s.mu.Lock()
		defer s.mu.Unlock()
		if s.fail {
			http.Error(w, "boom", http.StatusInternalServerError)
			return
		}
		if s.rawBody != nil {
			_, _ = w.Write(s.rawBody)
			return
		}
		var set struct {
			Keys []map[string]string `json:"keys"`
		}
		for kid, pub := range s.keys {
			raw, err := pub.Bytes() // 0x04 || x || y
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			crv := "P-256"
			if s.curve != "" {
				crv = s.curve
			}
			set.Keys = append(set.Keys, map[string]string{
				"kty": "EC", "crv": crv, "kid": kid, "alg": "ES256", "use": "sig",
				"x": base64.RawURLEncoding.EncodeToString(raw[1:33]),
				"y": base64.RawURLEncoding.EncodeToString(raw[33:]),
			})
		}
		_ = json.NewEncoder(w).Encode(set)
	}))
	t.Cleanup(s.Close)
	return s
}

func (s *jwkServer) set(f func(*jwkServer)) {
	s.mu.Lock()
	defer s.mu.Unlock()
	f(s)
}

func TestHTTPKeySource_FetchesAndCaches(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"k1": &key.PublicKey})
	clk := clocktest.New(testNow)
	v := opsapi.NewVerifier(opsapi.NewHTTPKeySource(srv.Client(), srv.URL, clk), testAudience, clk)

	token := sign(t, key, "k1", validClaims())
	for range 3 {
		if _, err := v.Verify(context.Background(), token); err != nil {
			t.Fatalf("Verify: %v", err)
		}
	}
	if got := srv.hits.Load(); got != 1 {
		t.Errorf("공개키 요청 %d회, want 1(캐시)", got)
	}
}

func TestHTTPKeySource_RefreshesAfterTTL(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"k1": &key.PublicKey})
	clk := clocktest.New(testNow)
	src := opsapi.NewHTTPKeySource(srv.Client(), srv.URL, clk)

	if _, err := src.Keys(context.Background()); err != nil {
		t.Fatal(err)
	}
	clk.Advance(61 * time.Minute)
	if _, err := src.Keys(context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := srv.hits.Load(); got != 2 {
		t.Errorf("공개키 요청 %d회, want 2", got)
	}
}

func TestHTTPKeySource_UnknownKidRefetchesOnceWithMinInterval(t *testing.T) {
	oldKey, newK := newKey(t), newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"old": &oldKey.PublicKey})
	clk := clocktest.New(testNow)
	v := opsapi.NewVerifier(opsapi.NewHTTPKeySource(srv.Client(), srv.URL, clk), testAudience, clk)
	ctx := context.Background()

	if _, err := v.Verify(ctx, sign(t, oldKey, "old", validClaims())); err != nil {
		t.Fatal(err)
	}
	// 키가 회전되어 새 kid가 생김. 최소 간격 안에서는 다시 받지 않음.
	srv.set(func(s *jwkServer) {
		s.keys = map[string]*ecdsa.PublicKey{"old": &oldKey.PublicKey, "new": &newK.PublicKey}
	})
	newToken := sign(t, newK, "new", validClaims())
	if _, err := v.Verify(ctx, newToken); !errors.Is(err, opsapi.ErrInvalidAssertion) {
		t.Fatalf("최소 간격 안: err = %v, want ErrInvalidAssertion", err)
	}
	if got := srv.hits.Load(); got != 1 {
		t.Fatalf("최소 간격 안 요청 %d회, want 1", got)
	}
	// 간격이 지나면 모르는 kid로 한 번 다시 받아 성공.
	clk.Advance(2 * time.Minute)
	if _, err := v.Verify(ctx, newToken); err != nil {
		t.Fatalf("간격 뒤 Verify: %v", err)
	}
	if got := srv.hits.Load(); got != 2 {
		t.Errorf("요청 %d회, want 2", got)
	}
}

func TestHTTPKeySource_FailureUsesCache(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"k1": &key.PublicKey})
	clk := clocktest.New(testNow)
	src := opsapi.NewHTTPKeySource(srv.Client(), srv.URL, clk)
	if _, err := src.Keys(context.Background()); err != nil {
		t.Fatal(err)
	}
	srv.set(func(s *jwkServer) { s.fail = true })
	clk.Advance(2 * time.Hour)

	keys, err := src.Keys(context.Background())
	if err != nil || keys["k1"] == nil {
		t.Fatalf("캐시로 응답해야 합니다: keys=%v err=%v", keys, err)
	}
}

func TestHTTPKeySource_FailureWithoutCache(t *testing.T) {
	srv := newJWKServer(t, nil)
	srv.set(func(s *jwkServer) { s.fail = true })
	src := opsapi.NewHTTPKeySource(srv.Client(), srv.URL, clocktest.New(testNow))
	if _, err := src.Keys(context.Background()); !errors.Is(err, opsapi.ErrKeysUnavailable) {
		t.Errorf("err = %v, want ErrKeysUnavailable", err)
	}
}

func TestHTTPKeySource_RejectsNonP256AndOversize(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"k1": &key.PublicKey})
	srv.set(func(s *jwkServer) { s.curve = "P-384" })
	src := opsapi.NewHTTPKeySource(srv.Client(), srv.URL, clocktest.New(testNow))
	if _, err := src.Keys(context.Background()); !errors.Is(err, opsapi.ErrKeysUnavailable) {
		t.Errorf("P-384: err = %v, want ErrKeysUnavailable", err)
	}

	big := newJWKServer(t, nil)
	big.set(func(s *jwkServer) { s.rawBody = make([]byte, 2<<20) })
	src = opsapi.NewHTTPKeySource(big.Client(), big.URL, clocktest.New(testNow))
	if _, err := src.Keys(context.Background()); !errors.Is(err, opsapi.ErrKeysUnavailable) {
		t.Errorf("1MiB 초과: err = %v, want ErrKeysUnavailable", err)
	}
}

func TestHTTPKeySource_ConcurrentSafe(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"k1": &key.PublicKey})
	clk := clocktest.New(testNow)
	v := opsapi.NewVerifier(opsapi.NewHTTPKeySource(srv.Client(), srv.URL, clk), testAudience, clk)
	token := sign(t, key, "k1", validClaims())
	unknown := sign(t, key, "zzz", validClaims())

	var wg sync.WaitGroup
	for range 50 {
		wg.Add(2)
		go func() {
			defer wg.Done()
			if _, err := v.Verify(context.Background(), token); err != nil {
				t.Errorf("Verify: %v", err)
			}
		}()
		go func() {
			defer wg.Done()
			_, _ = v.Verify(context.Background(), unknown)
		}()
	}
	wg.Wait()
	if got := srv.hits.Load(); got > 2 {
		t.Errorf("동시 요청에서 공개키 요청 %d회, want <= 2", got)
	}
}
