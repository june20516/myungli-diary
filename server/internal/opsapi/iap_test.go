package opsapi_test

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
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

func mustVerifier(t *testing.T, keys opsapi.KeySource, clk *clocktest.Fake) *opsapi.Verifier {
	t.Helper()
	v, err := opsapi.NewVerifier(keys, testAudience, clk)
	if err != nil {
		t.Fatalf("NewVerifier: %v", err)
	}
	return v
}

func mustKeySource(t *testing.T, srv *jwkServer, clk *clocktest.Fake) opsapi.KeySource {
	t.Helper()
	src, err := opsapi.NewHTTPKeySource(srv.Client(), srv.URL, clk)
	if err != nil {
		t.Fatalf("NewHTTPKeySource: %v", err)
	}
	return src
}

func newVerifier(t *testing.T, key *ecdsa.PrivateKey) *opsapi.Verifier {
	t.Helper()
	keys := staticKeys{keys: map[string]*ecdsa.PublicKey{"k1": &key.PublicKey}}
	return mustVerifier(t, keys, clocktest.New(testNow))
}

func TestVerifier_Valid(t *testing.T) {
	key := newKey(t)
	got, err := newVerifier(t, key).Verify(context.Background(), sign(t, key, "k1", validClaims()))
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
	if _, err := newVerifier(t, key).Verify(context.Background(), sign(t, key, "k1", claims)); err != nil {
		t.Fatalf("aud 배열 안에 일치하는 값이 있으면 통과해야 합니다: %v", err)
	}
}

func TestVerifier_NoAssertion(t *testing.T) {
	_, err := newVerifier(t, newKey(t)).Verify(context.Background(), "  ")
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
			_, err := newVerifier(t, key).Verify(context.Background(), tt.assertion)
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
	if _, err := newVerifier(t, key).Verify(context.Background(), sign(t, key, "k1", claims)); err != nil {
		t.Errorf("허용 오차 30초 안은 통과해야 합니다: %v", err)
	}
}

func TestVerifier_UnknownKid(t *testing.T) {
	key := newKey(t)
	_, err := newVerifier(t, key).Verify(context.Background(), sign(t, key, "nope", validClaims()))
	if !errors.Is(err, opsapi.ErrInvalidAssertion) {
		t.Errorf("err = %v, want ErrInvalidAssertion", err)
	}
}

func TestVerifier_KeyFetchFailure(t *testing.T) {
	key := newKey(t)
	token := sign(t, key, "k1", validClaims())
	v := mustVerifier(t, staticKeys{err: errors.New("down")}, clocktest.New(testNow))
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
	entries []map[string]string // 지정하면 keys 대신 이 JWK 항목을 그대로 내줌
	block   chan struct{}       // 지정하면 닫힐 때까지 응답을 미룸
}

func newJWKServer(t *testing.T, keys map[string]*ecdsa.PublicKey) *jwkServer {
	t.Helper()
	s := &jwkServer{keys: keys}
	s.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		s.hits.Add(1)
		s.mu.Lock()
		block := s.block
		s.mu.Unlock()
		if block != nil {
			select {
			case <-block:
			case <-r.Context().Done():
				return
			}
		}
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
		if s.entries != nil {
			set.Keys = s.entries
		}
		for kid, pub := range s.keys {
			if s.entries != nil {
				break
			}
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
	v := mustVerifier(t, mustKeySource(t, srv, clk), clk)

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

func waitHits(t *testing.T, srv *jwkServer, want int32) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for srv.hits.Load() < want {
		if time.Now().After(deadline) {
			t.Fatalf("공개키 요청 %d회, want %d", srv.hits.Load(), want)
		}
		time.Sleep(time.Millisecond)
	}
}

func jwkEntry(kid string, pub *ecdsa.PublicKey) map[string]string {
	raw, _ := pub.Bytes()
	return map[string]string{
		"kty": "EC", "crv": "P-256", "kid": kid, "alg": "ES256", "use": "sig",
		"x": base64.RawURLEncoding.EncodeToString(raw[1:33]),
		"y": base64.RawURLEncoding.EncodeToString(raw[33:]),
	}
}

func TestHTTPKeySource_RefreshesAfterTTLInBackground(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"k1": &key.PublicKey})
	clk := clocktest.New(testNow)
	src := mustKeySource(t, srv, clk)

	if _, err := src.Keys(context.Background()); err != nil {
		t.Fatal(err)
	}
	clk.Advance(61 * time.Minute)
	keys, err := src.Keys(context.Background())
	if err != nil || keys["k1"] == nil {
		t.Fatalf("낡은 캐시를 바로 돌려줘야 합니다: %v", err)
	}
	waitHits(t, srv, 2)
}

func TestHTTPKeySource_UnknownKidRefetchesOnceWithMinInterval(t *testing.T) {
	oldKey, newK := newKey(t), newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"old": &oldKey.PublicKey})
	clk := clocktest.New(testNow)
	v := mustVerifier(t, mustKeySource(t, srv, clk), clk)
	ctx := context.Background()

	if _, err := v.Verify(ctx, sign(t, oldKey, "old", validClaims())); err != nil {
		t.Fatal(err)
	}
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
	src := mustKeySource(t, srv, clk)
	if _, err := src.Keys(context.Background()); err != nil {
		t.Fatal(err)
	}
	srv.set(func(s *jwkServer) { s.fail = true })
	clk.Advance(2 * time.Hour)

	keys, err := src.Keys(context.Background())
	if err != nil || keys["k1"] == nil {
		t.Fatalf("캐시로 응답해야 합니다: keys=%v err=%v", keys, err)
	}
	waitHits(t, srv, 2)
}

func TestHTTPKeySource_StaleCacheExpiresAfter24Hours(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"k1": &key.PublicKey})
	clk := clocktest.New(testNow)
	src := mustKeySource(t, srv, clk)
	if _, err := src.Keys(context.Background()); err != nil {
		t.Fatal(err)
	}
	srv.set(func(s *jwkServer) { s.fail = true })
	clk.Advance(24*time.Hour + time.Minute)

	if _, err := src.Keys(context.Background()); !errors.Is(err, opsapi.ErrKeysUnavailable) {
		t.Errorf("24시간 뒤 갱신 실패: err = %v, want ErrKeysUnavailable", err)
	}
}

func TestHTTPKeySource_FailureWithoutCache(t *testing.T) {
	srv := newJWKServer(t, nil)
	srv.set(func(s *jwkServer) { s.fail = true })
	src := mustKeySource(t, srv, clocktest.New(testNow))
	if _, err := src.Keys(context.Background()); !errors.Is(err, opsapi.ErrKeysUnavailable) {
		t.Errorf("err = %v, want ErrKeysUnavailable", err)
	}
}

func TestHTTPKeySource_RepeatedFailureWithoutCacheFetchesOnce(t *testing.T) {
	srv := newJWKServer(t, nil)
	srv.set(func(s *jwkServer) { s.fail = true })
	clk := clocktest.New(testNow)
	src := mustKeySource(t, srv, clk)

	for i := range 20 {
		if _, err := src.Keys(context.Background()); !errors.Is(err, opsapi.ErrKeysUnavailable) {
			t.Fatalf("요청 %d: err = %v, want ErrKeysUnavailable", i, err)
		}
	}
	if got := srv.hits.Load(); got != 1 {
		t.Errorf("1분 안 요청 %d회, want 1", got)
	}
	clk.Advance(61 * time.Second)
	if _, err := src.Keys(context.Background()); !errors.Is(err, opsapi.ErrKeysUnavailable) {
		t.Fatal(err)
	}
	if got := srv.hits.Load(); got != 2 {
		t.Errorf("1분 뒤 요청 %d회, want 2", got)
	}
}

func TestHTTPKeySource_CacheHitNotBlockedByRefresh(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"k1": &key.PublicKey})
	clk := clocktest.New(testNow)
	src := mustKeySource(t, srv, clk)
	if _, err := src.Keys(context.Background()); err != nil {
		t.Fatal(err)
	}
	release := make(chan struct{})
	srv.set(func(s *jwkServer) { s.block = release })
	clk.Advance(61 * time.Minute)
	t.Cleanup(func() { close(release) })

	for range 3 {
		done := make(chan error, 1)
		go func() {
			_, err := src.Keys(context.Background())
			done <- err
		}()
		select {
		case err := <-done:
			if err != nil {
				t.Fatal(err)
			}
		case <-time.After(time.Second):
			t.Fatal("재조회가 느린 동안 낡은 캐시 요청이 막혔습니다")
		}
	}
	waitHits(t, srv, 2)
}

func TestHTTPKeySource_WaiterFollowsOwnContext(t *testing.T) {
	srv := newJWKServer(t, nil)
	release := make(chan struct{})
	srv.set(func(s *jwkServer) { s.block = release })
	t.Cleanup(func() { close(release) })
	src := mustKeySource(t, srv, clocktest.New(testNow))

	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	start := time.Now()
	_, err := src.Keys(ctx)
	if !errors.Is(err, opsapi.ErrKeysUnavailable) || !errors.Is(err, context.DeadlineExceeded) {
		t.Errorf("err = %v, want ErrKeysUnavailable(DeadlineExceeded)", err)
	}
	if time.Since(start) > 2*time.Second {
		t.Error("자기 ctx 취소를 따르지 않았습니다")
	}
}

func TestHTTPKeySource_SkipsUnsupportedEntries(t *testing.T) {
	good, dup, other := newKey(t), newKey(t), newKey(t)
	badPoint := jwkEntry("badpoint", &good.PublicKey)
	badPoint["y"] = badPoint["x"]
	shortX := jwkEntry("shortx", &good.PublicKey)
	shortX["x"] = "AAAA"
	entries := []map[string]string{
		{"kty": "RSA", "kid": "rsa", "n": "AQAB", "e": "AQAB"},
		func() map[string]string { e := jwkEntry("p384", &good.PublicKey); e["crv"] = "P-384"; return e }(),
		func() map[string]string { e := jwkEntry("", &good.PublicKey); return e }(),
		badPoint,
		shortX,
		jwkEntry("dup", &good.PublicKey),
		jwkEntry("dup", &dup.PublicKey), // 같은 kid는 첫 항목 유지
		jwkEntry("other", &other.PublicKey),
	}
	srv := newJWKServer(t, nil)
	srv.set(func(s *jwkServer) { s.entries = entries })
	keys, err := mustKeySource(t, srv, clocktest.New(testNow)).Keys(context.Background())
	if err != nil {
		t.Fatalf("쓸 수 있는 키가 있으면 성공해야 합니다: %v", err)
	}
	if len(keys) != 2 || keys["dup"] == nil || keys["other"] == nil {
		t.Fatalf("keys = %v, want dup, other만", keys)
	}
	if !keys["dup"].Equal(&good.PublicKey) {
		t.Error("같은 kid는 첫 항목을 유지해야 합니다")
	}
}

func TestHTTPKeySource_NoUsableKeysFails(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, nil)
	srv.set(func(s *jwkServer) {
		e := jwkEntry("k", &key.PublicKey)
		e["crv"] = "P-384"
		s.entries = []map[string]string{e}
	})
	if _, err := mustKeySource(t, srv, clocktest.New(testNow)).Keys(context.Background()); !errors.Is(err, opsapi.ErrKeysUnavailable) {
		t.Errorf("err = %v, want ErrKeysUnavailable", err)
	}
}

func TestHTTPKeySource_RejectsOversizeResponse(t *testing.T) {
	big := newJWKServer(t, nil)
	big.set(func(s *jwkServer) { s.rawBody = make([]byte, 2<<20) })
	src := mustKeySource(t, big, clocktest.New(testNow))
	if _, err := src.Keys(context.Background()); !errors.Is(err, opsapi.ErrKeysUnavailable) {
		t.Errorf("1MiB 초과: err = %v, want ErrKeysUnavailable", err)
	}
}

func TestHTTPKeySource_ConcurrentSafe(t *testing.T) {
	key := newKey(t)
	srv := newJWKServer(t, map[string]*ecdsa.PublicKey{"k1": &key.PublicKey})
	clk := clocktest.New(testNow)
	v := mustVerifier(t, mustKeySource(t, srv, clk), clk)
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

func TestConstructors_RejectInvalidArguments(t *testing.T) {
	if _, err := opsapi.NewVerifier(staticKeys{}, "  ", clocktest.New(testNow)); err == nil {
		t.Error("빈 audience를 받았습니다")
	}
	if _, err := opsapi.NewHTTPKeySource(nil, "http://x", clocktest.New(testNow)); err == nil {
		t.Error("nil client를 받았습니다")
	}
}

func TestHTTPKeySource_URLScheme(t *testing.T) {
	tests := []struct {
		url string
		ok  bool
	}{
		{"https://www.gstatic.com/iap/verify/public_key-jwk", true},
		{"http://127.0.0.1:8080/jwk", true},
		{"http://localhost:8080/jwk", true},
		{"http://www.gstatic.com/iap/verify/public_key-jwk", false},
		{"http://127.0.0.1.evil.example/jwk", false},
		{"ftp://127.0.0.1/jwk", false},
		{"https:///jwk", false},
		{"", false},
		{"%zz", false},
	}
	for _, tt := range tests {
		_, err := opsapi.NewHTTPKeySource(http.DefaultClient, tt.url, clocktest.New(testNow))
		if (err == nil) != tt.ok {
			t.Errorf("url %q: err = %v, want ok=%v", tt.url, err, tt.ok)
		}
	}
}

func TestVerifier_SubjectTrimmed(t *testing.T) {
	key := newKey(t)
	claims := validClaims()
	claims["sub"] = "  accounts.google.com:1234 "
	got, err := newVerifier(t, key).Verify(context.Background(), sign(t, key, "k1", claims))
	if err != nil || got.Subject != "accounts.google.com:1234" {
		t.Errorf("Subject = %q, err = %v", got.Subject, err)
	}
}

func TestVerifier_LeewayBoundary(t *testing.T) {
	key := newKey(t)
	claims := validClaims()
	claims["exp"] = testNow.Add(-31 * time.Second).Unix()
	if _, err := newVerifier(t, key).Verify(context.Background(), sign(t, key, "k1", claims)); !errors.Is(err, opsapi.ErrInvalidAssertion) {
		t.Errorf("exp 31초 초과: err = %v, want ErrInvalidAssertion", err)
	}
	claims = validClaims()
	claims["iat"] = testNow.Add(31 * time.Second).Unix()
	if _, err := newVerifier(t, key).Verify(context.Background(), sign(t, key, "k1", claims)); !errors.Is(err, opsapi.ErrInvalidAssertion) {
		t.Errorf("iat 31초 미래: err = %v, want ErrInvalidAssertion", err)
	}
}

func TestVerifier_RejectsOtherAlgorithmsAndMissingKid(t *testing.T) {
	key := newKey(t)
	rsaKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	p384, err := ecdsa.GenerateKey(elliptic.P384(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	signWith := func(method jwt.SigningMethod, k any, kid string) string {
		token := jwt.NewWithClaims(method, validClaims())
		if kid != "" {
			token.Header["kid"] = kid
		}
		signed, err := token.SignedString(k)
		if err != nil {
			t.Fatal(err)
		}
		return signed
	}
	tests := map[string]string{
		"RS256":  signWith(jwt.SigningMethodRS256, rsaKey, "k1"),
		"ES384":  signWith(jwt.SigningMethodES384, p384, "k1"),
		"kid 없음": signWith(jwt.SigningMethodES256, key, ""),
	}
	for name, assertion := range tests {
		t.Run(name, func(t *testing.T) {
			if _, err := newVerifier(t, key).Verify(context.Background(), assertion); !errors.Is(err, opsapi.ErrInvalidAssertion) {
				t.Errorf("err = %v, want ErrInvalidAssertion", err)
			}
		})
	}
}

func TestVerifier_ErrorsDoNotLeakTokenOrEmail(t *testing.T) {
	key := newKey(t)
	claims := validClaims()
	claims["email"] = "Secret.Person@Example.com"
	claims["aud"] = "wrong"
	token := sign(t, key, "k1", claims)

	_, err := newVerifier(t, key).Verify(context.Background(), token)
	if err == nil {
		t.Fatal("오류가 있어야 합니다")
	}
	msg := strings.ToLower(err.Error())
	for _, secret := range []string{strings.ToLower(token), "secret.person", strings.ToLower(strings.Split(token, ".")[1])} {
		if strings.Contains(msg, secret) {
			t.Errorf("오류 문구에 민감 값이 들어 있습니다: %q", err.Error())
		}
	}
}
