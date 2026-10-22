// Package providertest는 카카오·Apple·LINE·Google 연동을 테스트하기 위한 가짜 제공자 서버입니다.
//
// 하나의 httptest.Server가 다음 엔드포인트를 모두 내줍니다.
//   - JWKS(카카오·Apple·LINE·Google 공용): 테스트용 RSA 키와 ES256(P-256) 키의 공개 키 목록
//     (카카오·Apple·Google은 RSA 키로, LINE은 ES256 키로 서명한 토큰을 씁니다)
//   - Apple /auth/token, /auth/revoke
//     (/auth/token은 AppleCode로 만든 code를 받으면 그 subject로 서명한 id_token과 refresh token을 돌려줍니다)
//   - 카카오 /v1/user/unlink
//
// 받은 요청의 form을 기록하고, 응답 상태·본문을 바꿀 수 있어 장애 상황을 흉내 낼 수 있습니다.
// 카카오와 Apple이 서로 다른 키를 써야 하는 테스트는 Server를 두 개 만들면 됩니다.
package providertest

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// 대역 서버가 내주는 엔드포인트 경로입니다.
const (
	JWKSPath        = "/jwks"
	AppleTokenPath  = "/apple/auth/token" //nolint:gosec // 대역 서버 경로이며 자격 증명이 아닙니다
	AppleRevokePath = "/apple/auth/revoke"
	KakaoUnlinkPath = "/kakao/v1/user/unlink"
)

// KakaoConfig·AppleConfig가 채우는 테스트용 설정 값입니다.
const (
	KakaoIssuer         = "https://kauth.kakao.com"
	KakaoAppKey         = "test-kakao-app-key"
	KakaoAdminKey       = "test-kakao-admin-key"
	AppleIssuer         = "https://appleid.apple.com"
	AppleTeamID         = "TESTTEAM01"
	AppleKeyID          = "TESTKEY001"
	AppleBundleID       = "app.myungli.diary"
	AppleServicesID     = "app.myungli.diary.web"
	AppleWebRedirectURI = "https://api.example.test/v1/auth/apple/callback"
	// AppleRefreshToken은 Apple token 엔드포인트 대역이 기본으로 돌려주는 refresh token입니다.
	AppleRefreshToken = "providertest-apple-refresh-token"
)

// LINEConfig·GoogleConfig가 채우는 테스트용 설정 값입니다.
const (
	LINEChannelID = "1650000000"
	// es256KeyID는 JWKS가 내주는 ES256 키의 kid입니다. RSA 키와 달리 RotateKey로 바뀌지 않습니다.
	es256KeyID = "providertest-es256"
)

// GoogleClientIDs는 GoogleConfig가 받는 테스트용 OAuth client ID(aud) 목록입니다.
var GoogleClientIDs = []string{"test-ios.apps.googleusercontent.com", "test-web.apps.googleusercontent.com"}

// appleCodePrefix는 AppleCode가 만드는 authorization code의 앞부분입니다. 뒤에 subject가 붙습니다.
const appleCodePrefix = "providertest-code:"

// AppleCode는 subject의 Apple authorization code를 만듭니다.
// 실제 Apple code가 한 사용자에게 묶이듯, token 대역은 이 code를 교환하면 sub가 subject인 id_token을 돌려줍니다.
func AppleCode(subject string) string { return appleCodePrefix + subject }

// Request는 대역 엔드포인트가 받은 요청 한 건입니다.
type Request struct {
	Header http.Header
	Form   url.Values
}

// endpoint는 엔드포인트 하나의 응답 설정과 받은 요청 기록입니다.
type endpoint struct {
	status   int
	body     string
	requests []Request
}

// signingKey는 kid가 붙은 RSA 서명 키입니다.
type signingKey struct {
	id      string
	private *rsa.PrivateKey
}

// Server는 카카오·Apple 대역 서버입니다. 모든 메서드는 여러 고루틴에서 동시에 불러도 안전합니다.
type Server struct {
	srv      *httptest.Server
	appleKey *ecdsa.PrivateKey
	// es256Key는 LINE id_token 서명용 키입니다. kid는 es256KeyID로 고정입니다.
	es256Key *ecdsa.PrivateKey

	mu         sync.Mutex
	keyCount   int
	current    signingKey
	jwksStatus int
	jwksHits   int
	token      endpoint
	// tokenOverride가 true면 token 엔드포인트가 SetAppleTokenResponse로 정한 상태·본문을 그대로 돌려줍니다.
	tokenOverride bool
	// appleRefresh는 token 엔드포인트가 기본 응답에 담는 refresh token입니다.
	appleRefresh string
	// clock은 token 엔드포인트가 만드는 id_token의 iat·exp 기준 시각입니다. AppleConfig가 정합니다.
	clock  clock.Clock
	revoke endpoint
	unlink endpoint
}

// New는 대역 서버를 띄우고, 테스트가 끝나면 닫도록 t.Cleanup에 등록합니다.
func New(t testing.TB) *Server {
	t.Helper()
	appleKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("providertest: Apple 키 생성 실패: %v", err)
	}
	es256Key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("providertest: ES256 키 생성 실패: %v", err)
	}
	s := &Server{
		appleKey:     appleKey,
		es256Key:     es256Key,
		jwksStatus:   http.StatusOK,
		appleRefresh: AppleRefreshToken,
		clock:        clock.System{},
		revoke:       endpoint{status: http.StatusOK},
		unlink:       endpoint{status: http.StatusOK, body: `{"id":1}`},
	}
	if err := s.rotate(); err != nil {
		t.Fatalf("providertest: RSA 키 생성 실패: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET "+JWKSPath, s.serveJWKS)
	mux.HandleFunc("POST "+AppleTokenPath, s.serveAppleToken)
	mux.HandleFunc("POST "+AppleRevokePath, s.recordAndRespond(&s.revoke))
	mux.HandleFunc("POST "+KakaoUnlinkPath, s.recordAndRespond(&s.unlink))
	s.srv = httptest.NewServer(mux)
	t.Cleanup(s.srv.Close)
	return s
}

// URL은 대역 서버의 기본 URL입니다.
func (s *Server) URL() string { return s.srv.URL }

// Client는 대역 서버에 붙는 http.Client입니다.
func (s *Server) Client() *http.Client { return s.srv.Client() }

// JWKSURL은 JWKS 엔드포인트 URL입니다.
func (s *Server) JWKSURL() string { return s.srv.URL + JWKSPath }

// AppleTokenURL은 Apple /auth/token 대역 URL입니다.
func (s *Server) AppleTokenURL() string { return s.srv.URL + AppleTokenPath }

// AppleRevokeURL은 Apple /auth/revoke 대역 URL입니다.
func (s *Server) AppleRevokeURL() string { return s.srv.URL + AppleRevokePath }

// KakaoUnlinkURL은 카카오 unlink 대역 URL입니다.
func (s *Server) KakaoUnlinkURL() string { return s.srv.URL + KakaoUnlinkPath }

// ApplePrivateKey는 AppleConfig가 client_secret 서명에 쓰는 ES256 개인 키입니다.
// 테스트는 이 키의 공개 키로 client_secret을 검증할 수 있습니다.
func (s *Server) ApplePrivateKey() *ecdsa.PrivateKey { return s.appleKey }

// KakaoConfig는 이 대역 서버를 가리키는 카카오 설정을 돌려줍니다.
// id_token의 exp는 clk 기준으로 검사합니다.
func (s *Server) KakaoConfig(clk clock.Clock) provider.KakaoConfig {
	return provider.KakaoConfig{
		AppKey:    KakaoAppKey,
		AdminKey:  KakaoAdminKey,
		Issuer:    KakaoIssuer,
		JWKSURL:   s.JWKSURL(),
		UnlinkURL: s.KakaoUnlinkURL(),
		HTTP:      s.Client(),
		Clock:     clk,
	}
}

// AppleConfig는 이 대역 서버를 가리키는 Apple 설정을 돌려줍니다.
// client_secret의 iat·exp는 clk에서 읽습니다. token 대역이 돌려주는 id_token의 iat·exp도 clk를 기준으로 합니다.
func (s *Server) AppleConfig(clk clock.Clock) provider.AppleConfig {
	s.SetClock(clk)
	return provider.AppleConfig{
		TeamID:         AppleTeamID,
		KeyID:          AppleKeyID,
		PrivateKey:     s.appleKey,
		BundleID:       AppleBundleID,
		ServicesID:     AppleServicesID,
		WebRedirectURI: AppleWebRedirectURI,
		Issuer:         AppleIssuer,
		JWKSURL:        s.JWKSURL(),
		TokenURL:       s.AppleTokenURL(),
		RevokeURL:      s.AppleRevokeURL(),
		HTTP:           s.Client(),
		Clock:          clk,
	}
}

// NewKakao는 KakaoConfig(clk)로 provider.Kakao를 만듭니다. 설정 오류면 테스트를 멈춥니다.
func (s *Server) NewKakao(t testing.TB, clk clock.Clock) *provider.Kakao {
	t.Helper()
	kakao, err := provider.NewKakao(s.KakaoConfig(clk))
	if err != nil {
		t.Fatalf("providertest: NewKakao: %v", err)
	}
	return kakao
}

// NewApple은 AppleConfig(clk)로 provider.Apple을 만듭니다. 설정 오류면 테스트를 멈춥니다.
func (s *Server) NewApple(t testing.TB, clk clock.Clock) *provider.Apple {
	t.Helper()
	apple, err := provider.NewApple(s.AppleConfig(clk))
	if err != nil {
		t.Fatalf("providertest: NewApple: %v", err)
	}
	return apple
}

// LINEConfig는 이 대역 서버를 가리키는 LINE 설정을 돌려줍니다.
// id_token의 exp는 clk 기준으로 검사합니다.
func (s *Server) LINEConfig(clk clock.Clock) provider.LINEConfig {
	return provider.LINEConfig{
		ChannelID: LINEChannelID,
		Issuer:    provider.DefaultLINEIssuer,
		JWKSURL:   s.JWKSURL(),
		HTTP:      s.Client(),
		Clock:     clk,
	}
}

// GoogleConfig는 이 대역 서버를 가리키는 Google 설정을 돌려줍니다.
// id_token의 exp는 clk 기준으로 검사합니다.
func (s *Server) GoogleConfig(clk clock.Clock) provider.GoogleConfig {
	return provider.GoogleConfig{
		ClientIDs: GoogleClientIDs,
		JWKSURL:   s.JWKSURL(),
		HTTP:      s.Client(),
		Clock:     clk,
	}
}

// NewLINE은 LINEConfig(clk)로 provider.LINE을 만듭니다. 설정 오류면 테스트를 멈춥니다.
func (s *Server) NewLINE(t testing.TB, clk clock.Clock) *provider.LINE {
	t.Helper()
	line, err := provider.NewLINE(s.LINEConfig(clk))
	if err != nil {
		t.Fatalf("providertest: NewLINE: %v", err)
	}
	return line
}

// NewGoogle은 GoogleConfig(clk)로 provider.Google을 만듭니다. 설정 오류면 테스트를 멈춥니다.
func (s *Server) NewGoogle(t testing.TB, clk clock.Clock) *provider.Google {
	t.Helper()
	google, err := provider.NewGoogle(s.GoogleConfig(clk))
	if err != nil {
		t.Fatalf("providertest: NewGoogle: %v", err)
	}
	return google
}

// HashNonce는 nonce 원문을 id_token의 nonce claim 값(hex(sha256(원문)))으로 바꿉니다.
func HashNonce(rawNonce string) string {
	sum := sha256.Sum256([]byte(rawNonce))
	return hex.EncodeToString(sum[:])
}

// KakaoClaims는 KakaoConfig로 검증을 통과하는 id_token claim을 만듭니다. exp는 now+1시간입니다.
func KakaoClaims(subject, rawNonce string, now time.Time) map[string]any {
	return map[string]any{
		"iss":   KakaoIssuer,
		"aud":   KakaoAppKey,
		"sub":   subject,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
		"nonce": HashNonce(rawNonce),
	}
}

// LINEClaims는 LINEConfig로 검증을 통과하는 id_token claim을 만듭니다. exp는 now+1시간입니다.
func LINEClaims(subject, rawNonce string, now time.Time) map[string]any {
	return map[string]any{
		"iss":   provider.DefaultLINEIssuer,
		"aud":   LINEChannelID,
		"sub":   subject,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
		"nonce": HashNonce(rawNonce),
	}
}

// GoogleClaims는 GoogleConfig로 검증을 통과하는 id_token claim을 만듭니다. exp는 now+1시간입니다.
// aud와 iss는 호출하는 쪽이 정해, 허용 범위 안팎을 모두 만들 수 있습니다.
func GoogleClaims(subject, rawNonce, aud, iss string, now time.Time) map[string]any {
	return map[string]any{
		"iss":   iss,
		"aud":   aud,
		"sub":   subject,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
		"nonce": HashNonce(rawNonce),
	}
}

// AppleClaims는 AppleConfig로 검증을 통과하는 id_token claim을 만듭니다.
// aud는 native면 AppleBundleID, web이면 AppleServicesID입니다. exp는 now+1시간입니다.
func AppleClaims(subject, rawNonce string, client provider.AppleClient, now time.Time) map[string]any {
	aud := AppleBundleID
	if client == provider.AppleWeb {
		aud = AppleServicesID
	}
	return map[string]any{
		"iss":   AppleIssuer,
		"aud":   aud,
		"sub":   subject,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
		"nonce": HashNonce(rawNonce),
	}
}

// SignIDToken은 현재 키로 claims에 RS256 서명을 하고 header에 현재 kid를 넣은 JWT를 돌려줍니다.
func (s *Server) SignIDToken(claims map[string]any) string {
	s.mu.Lock()
	key := s.current
	s.mu.Unlock()

	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims(claims))
	tok.Header["kid"] = key.id
	signed, err := tok.SignedString(key.private)
	if err != nil {
		// 메모리 안의 RSA 키 서명은 실패할 일이 없습니다. 실패하면 테스트 환경 자체가 깨진 것입니다.
		panic(fmt.Sprintf("providertest: id_token 서명 실패: %v", err))
	}
	return signed
}

// SignES256IDToken은 ES256 키로 claims에 서명하고 header에 고정 kid를 넣은 JWT를 돌려줍니다.
// JWKS가 이 키의 공개 키도 내주므로 LINE처럼 ES256을 쓰는 제공자의 토큰을 만들 때 씁니다.
func (s *Server) SignES256IDToken(claims map[string]any) string {
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims(claims))
	tok.Header["kid"] = es256KeyID
	signed, err := tok.SignedString(s.es256Key)
	if err != nil {
		// 메모리 안의 EC 키 서명은 실패할 일이 없습니다. 실패하면 테스트 환경 자체가 깨진 것입니다.
		panic(fmt.Sprintf("providertest: ES256 id_token 서명 실패: %v", err))
	}
	return signed
}

// RotateKey는 새 RSA 키를 만들어 현재 키로 바꾸고 새 kid를 돌려줍니다.
// 이전 키는 JWKS에서 빠지므로, 이전 키로 서명한 토큰은 더 이상 검증되지 않습니다.
func (s *Server) RotateKey() string {
	if err := s.rotate(); err != nil {
		panic(fmt.Sprintf("providertest: RSA 키 생성 실패: %v", err))
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.current.id
}

// CurrentKeyID는 현재 서명 키의 kid입니다.
func (s *Server) CurrentKeyID() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.current.id
}

// SetJWKSStatus는 JWKS 엔드포인트의 응답 상태를 바꿉니다. 200이 아니면 본문 없이 그 상태만 돌려줍니다.
func (s *Server) SetJWKSStatus(status int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.jwksStatus = status
}

// JWKSHits는 JWKS 엔드포인트가 받은 요청 수입니다.
func (s *Server) JWKSHits() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.jwksHits
}

// SetAppleTokenResponse는 Apple /auth/token 대역이 code와 상관없이 이 상태와 본문(JSON)을 그대로 돌려주게 합니다.
// 장애나 깨진 응답을 흉내 낼 때 씁니다.
func (s *Server) SetAppleTokenResponse(status int, body string) {
	s.mu.Lock()
	s.tokenOverride = true
	s.mu.Unlock()
	s.setResponse(&s.token, status, body)
}

// SetClock은 token 대역이 만드는 id_token의 iat·exp 기준 시계를 바꿉니다.
// AppleConfig를 거치지 않고 Apple 설정을 직접 만드는 테스트가 검증 쪽과 같은 시계를 맞출 때 씁니다.
func (s *Server) SetClock(clk clock.Clock) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.clock = clk
}

// SetAppleRefreshToken은 Apple /auth/token 대역의 기본 응답이 담는 refresh token을 바꿉니다.
func (s *Server) SetAppleRefreshToken(refreshToken string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.appleRefresh = refreshToken
}

// AppleTokenRequests는 Apple /auth/token 대역이 받은 요청을 순서대로 돌려줍니다.
func (s *Server) AppleTokenRequests() []Request { return s.requests(&s.token) }

// SetAppleRevokeResponse는 Apple /auth/revoke 대역의 응답 상태와 본문을 바꿉니다.
func (s *Server) SetAppleRevokeResponse(status int, body string) {
	s.setResponse(&s.revoke, status, body)
}

// AppleRevokeRequests는 Apple /auth/revoke 대역이 받은 요청을 순서대로 돌려줍니다.
func (s *Server) AppleRevokeRequests() []Request { return s.requests(&s.revoke) }

// SetKakaoUnlinkResponse는 카카오 unlink 대역의 응답 상태와 본문(JSON)을 바꿉니다.
func (s *Server) SetKakaoUnlinkResponse(status int, body string) {
	s.setResponse(&s.unlink, status, body)
}

// KakaoUnlinkRequests는 카카오 unlink 대역이 받은 요청을 순서대로 돌려줍니다.
func (s *Server) KakaoUnlinkRequests() []Request { return s.requests(&s.unlink) }

func (s *Server) rotate() error {
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.keyCount++
	s.current = signingKey{id: fmt.Sprintf("test-key-%d", s.keyCount), private: priv}
	return nil
}

func (s *Server) setResponse(e *endpoint, status int, body string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e.status = status
	e.body = body
}

func (s *Server) requests(e *endpoint) []Request {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]Request, len(e.requests))
	copy(out, e.requests)
	return out
}

// serveJWKS는 현재 RSA 키와 ES256 키의 공개 키를 JWK Set으로 내줍니다.
func (s *Server) serveJWKS(w http.ResponseWriter, _ *http.Request) {
	s.mu.Lock()
	s.jwksHits++
	status := s.jwksStatus
	key := s.current
	s.mu.Unlock()

	if status != http.StatusOK {
		w.WriteHeader(status)
		return
	}
	pub := key.private.PublicKey
	ecPub := s.es256Key.PublicKey
	set := map[string]any{
		"keys": []map[string]string{{
			"kty": "RSA",
			"kid": key.id,
			"use": "sig",
			"alg": "RS256",
			"n":   base64.RawURLEncoding.EncodeToString(pub.N.Bytes()),
			"e":   base64.RawURLEncoding.EncodeToString(big.NewInt(int64(pub.E)).Bytes()),
		}, {
			"kty": "EC",
			"kid": es256KeyID,
			"use": "sig",
			"alg": "ES256",
			"crv": "P-256",
			// 좌표는 곡선 크기(32바이트)에 맞춰 앞을 0으로 채워야 합니다(RFC 7518 6.2.1.2).
			"x": base64.RawURLEncoding.EncodeToString(ecPub.X.FillBytes(make([]byte, 32))),
			"y": base64.RawURLEncoding.EncodeToString(ecPub.Y.FillBytes(make([]byte, 32))),
		}},
	}
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(set); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// serveAppleToken은 Apple /auth/token 대역입니다. 받은 요청을 기록합니다.
// SetAppleTokenResponse로 응답을 정했으면 그대로 돌려줍니다. 아니면 AppleCode로 만든 code만 받아,
// 그 subject와 요청의 client_id(aud)로 서명한 id_token과 refresh token을 돌려주고, 그 밖의 code는 400 invalid_grant입니다.
func (s *Server) serveAppleToken(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	override := s.tokenOverride
	s.mu.Unlock()
	if override {
		s.recordAndRespond(&s.token)(w, r)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	s.mu.Lock()
	s.token.requests = append(s.token.requests, Request{Header: r.Header.Clone(), Form: r.PostForm})
	refresh, now := s.appleRefresh, s.clock.Now()
	s.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	subject, ok := strings.CutPrefix(r.PostForm.Get("code"), appleCodePrefix)
	if !ok || subject == "" {
		w.WriteHeader(http.StatusBadRequest)
		// header를 이미 보냈으므로 쓰기 실패를 알릴 방법이 없습니다.
		_, _ = io.WriteString(w, `{"error":"invalid_grant"}`)
		return
	}
	idToken := s.SignIDToken(map[string]any{
		"iss": AppleIssuer,
		"aud": r.PostForm.Get("client_id"),
		"sub": subject,
		"iat": now.Unix(),
		"exp": now.Add(time.Hour).Unix(),
	})
	body := map[string]any{
		"access_token":  "providertest-access",
		"token_type":    "Bearer",
		"expires_in":    3600,
		"refresh_token": refresh,
		"id_token":      idToken,
	}
	if err := json.NewEncoder(w).Encode(body); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// recordAndRespond는 받은 form과 header를 기록하고 설정된 상태·본문으로 답하는 handler를 만듭니다.
func (s *Server) recordAndRespond(e *endpoint) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		s.mu.Lock()
		e.requests = append(e.requests, Request{Header: r.Header.Clone(), Form: r.PostForm})
		status, body := e.status, e.body
		s.mu.Unlock()

		if body != "" {
			w.Header().Set("Content-Type", "application/json")
		}
		w.WriteHeader(status)
		// header를 이미 보냈으므로 쓰기 실패를 알릴 방법이 없습니다. 실패는 클라이언트 쪽 읽기 오류로 드러납니다.
		_, _ = io.WriteString(w, body)
	}
}
