package cli

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"io"
	"log/slog"
	"net"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

func TestServe_GracefulShutdown(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	handler := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		close(started)
		<-release
		w.WriteHeader(http.StatusOK)
	})
	listener, err := (&net.ListenConfig{}).Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen: %v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	logger := slog.New(slog.NewJSONHandler(io.Discard, nil))

	serveDone := make(chan error, 1)
	go func() { serveDone <- serveHTTP(ctx, listener, handler, logger) }()

	statusCh := make(chan int, 1)
	go func() {
		resp, err := getWithContext(t.Context(), http.DefaultClient, "http://"+listener.Addr().String()+"/slow")
		if err != nil {
			statusCh <- -1
			return
		}
		_ = resp.Body.Close()
		statusCh <- resp.StatusCode
	}()

	<-started
	cancel()

	// 요청이 아직 처리 중이므로 serve는 반환하지 않아야 합니다.
	select {
	case err := <-serveDone:
		t.Fatalf("처리 중인 요청이 끝나기 전에 serve가 반환됨: %v", err)
	case <-time.After(200 * time.Millisecond):
	}

	close(release)

	if status := <-statusCh; status != http.StatusOK {
		t.Errorf("진행 중이던 요청 status = %d, want 200", status)
	}
	select {
	case err := <-serveDone:
		if err != nil {
			t.Errorf("serve 오류 = %v, want nil", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("요청이 끝난 뒤에도 serve가 반환되지 않았습니다")
	}
}

func TestRun_ServeStartsAndStopsOnCancel(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	env := testAuthEnv(t)
	env["PORT"] = freePort(t)
	env["DATABASE_URL"] = dbtest.NewURL(t)
	var stdout, stderr bytes.Buffer

	done := make(chan int, 1)
	finished := make(chan struct{})
	go func() {
		defer close(finished)
		done <- Run(ctx, []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
	}()

	// 테스트가 어떻게 끝나든 Run goroutine이 남지 않게 취소하고 종료를 기다립니다.
	t.Cleanup(func() {
		cancel()
		select {
		case <-finished:
		case <-time.After(5 * time.Second):
			t.Error("Run goroutine이 종료되지 않았습니다")
		}
	})

	waitForHealthz(t, "http://127.0.0.1:"+env["PORT"]+"/healthz")
	// 인증을 조립했으므로 bearer 라우트에 토큰 없이 보낸 요청은 401입니다.
	// 종료를 늦추지 않게 본문을 끝까지 읽고 유휴 연결을 닫습니다.
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := getWithContext(t.Context(), client, "http://127.0.0.1:"+env["PORT"]+"/v1/me")
	if err != nil {
		t.Fatalf("GET /v1/me: %v", err)
	}
	_, _ = io.Copy(io.Discard, resp.Body)
	_ = resp.Body.Close()
	client.CloseIdleConnections()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("GET /v1/me status = %d, want 401", resp.StatusCode)
	}
	cancel()

	select {
	case code := <-done:
		if code != 0 {
			t.Errorf("종료 코드 = %d, stderr = %q", code, stderr.String())
		}
	case <-time.After(5 * time.Second):
		t.Fatal("ctx 취소 뒤 serve가 종료되지 않았습니다")
	}
}

func TestRun_ServeRequiresDatabaseURL(t *testing.T) {
	env := testAuthEnv(t)
	env["PORT"] = freePort(t)
	var stdout, stderr bytes.Buffer

	code := Run(t.Context(), []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
	if code != 1 {
		t.Errorf("종료 코드 = %d, want 1", code)
	}
	if !strings.Contains(stderr.String(), "DATABASE_URL") {
		t.Errorf("stderr에 DATABASE_URL이 없습니다: %q", stderr.String())
	}
}

func TestRun_ServeFailsFastWhenDatabaseUnreachable(t *testing.T) {
	env := testAuthEnv(t)
	env["PORT"] = freePort(t)
	env["DATABASE_URL"] = "postgres://x:pw-secret@127.0.0.1:1/x"
	var stdout, stderr bytes.Buffer

	done := make(chan int, 1)
	go func() {
		done <- Run(t.Context(), []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
	}()

	select {
	case code := <-done:
		if code != 1 {
			t.Errorf("종료 코드 = %d, want 1", code)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("DB에 연결할 수 없는데 5초 안에 종료하지 않았습니다")
	}
	if !strings.Contains(stderr.String(), "DB 연결 실패") {
		t.Errorf("stderr에 \"DB 연결 실패\"가 없습니다: %q", stderr.String())
	}
	if strings.Contains(stderr.String(), "pw-secret") {
		t.Errorf("stderr에 연결 주소의 비밀번호가 남았습니다: %q", stderr.String())
	}
}

func TestRun_ServeRequiresAuthConfig(t *testing.T) {
	env := map[string]string{"PORT": freePort(t), "DATABASE_URL": "postgres://x@127.0.0.1:1/x"}
	var stdout, stderr bytes.Buffer

	code := Run(t.Context(), []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
	if code != 1 {
		t.Errorf("종료 코드 = %d, want 1", code)
	}
	if !strings.Contains(stderr.String(), "JWT_SIGNING_KEY") {
		t.Errorf("stderr에 누락된 변수 이름이 없습니다: %q", stderr.String())
	}
}

func TestRun_ServeRejectsUnparsableAuthSettings(t *testing.T) {
	// secret은 로그에 나오면 안 되는 값입니다. 오류에는 변수 이름만 있어야 합니다.
	const secret = "leak-check-secret-value" //nolint:gosec // 로그 유출 검사용 테스트 값이며 실제 자격 증명이 아닙니다
	tests := []struct {
		name, key, value string
	}{
		{"JWT 서명 키가 PEM이 아님", "JWT_SIGNING_KEY", secret},
		{"이전 JWT 키가 PEM이 아님", "JWT_PREVIOUS_KEY", secret},
		{"토큰 암호 키가 base64가 아님", "TOKEN_ENCRYPTION_KEY", secret + "!"},
		{"이전 토큰 암호 키가 base64가 아님", "TOKEN_PREVIOUS_KEY", secret + "!"},
		{"Apple 개인 키가 PEM이 아님", "APPLE_PRIVATE_KEY", secret},
		{"딥링크에 scheme이 없음", "APPLE_CALLBACK_DEEPLINK", "auth/apple/" + secret},
		{"딥링크를 해석할 수 없음", "APPLE_CALLBACK_DEEPLINK", "myungli://auth/%zz" + secret},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := testAuthEnv(t)
			env["PORT"] = freePort(t)
			// 키 검사는 DB 연결보다 먼저이므로 닿지 않는 주소여도 키 오류로 끝나야 합니다.
			env["DATABASE_URL"] = "postgres://x@127.0.0.1:1/x"
			env[tt.key] = tt.value
			if tt.key == "JWT_PREVIOUS_KEY" {
				env["JWT_PREVIOUS_KEY_ID"] = "jwt-prev"
			}
			if tt.key == "TOKEN_PREVIOUS_KEY" {
				env["TOKEN_PREVIOUS_KEY_ID"] = "tok-prev"
			}
			var stdout, stderr bytes.Buffer

			code := Run(t.Context(), []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
			if code != 1 {
				t.Errorf("종료 코드 = %d, want 1", code)
			}
			if !strings.Contains(stderr.String(), tt.key) {
				t.Errorf("stderr에 변수 이름 %s가 없습니다: %q", tt.key, stderr.String())
			}
			if strings.Contains(stderr.String(), secret) {
				t.Errorf("stderr에 설정 값이 남았습니다: %q", stderr.String())
			}
			if strings.Contains(stderr.String(), "DB 연결 실패") {
				t.Errorf("키 검사 전에 DB에 연결했습니다: %q", stderr.String())
			}
		})
	}
}

// testAuthEnv는 인증 설정 17개 중 필수 값을 채운 환경을 만듭니다.
// JWT 키는 실제로 파싱되는 P-256 PKCS8 PEM이고, 토큰 암호 키는 32바이트 난수의 base64(표준)입니다.
func testAuthEnv(t *testing.T) map[string]string {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("P-256 키 생성: %v", err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatalf("PKCS8 변환: %v", err)
	}
	keyPEM := string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))
	tokenKey := make([]byte, 32)
	if _, err := rand.Read(tokenKey); err != nil {
		t.Fatalf("난수 생성: %v", err)
	}
	return map[string]string{
		"JWT_SIGNING_KEY_ID":      "jwt-test-1",
		"JWT_SIGNING_KEY":         keyPEM,
		"TOKEN_ENCRYPTION_KEY_ID": "tok-test-1",
		"TOKEN_ENCRYPTION_KEY":    base64.StdEncoding.EncodeToString(tokenKey),
		"KAKAO_APP_KEY":           "kakao-app-key",
		"KAKAO_ADMIN_KEY":         "kakao-admin-key",
		"APPLE_TEAM_ID":           "TEAMID0001",
		"APPLE_KEY_ID":            "KEYID00001",
		"APPLE_PRIVATE_KEY":       keyPEM,
		"APPLE_BUNDLE_ID":         "app.myungli.test",
		"APPLE_SERVICES_ID":       "app.myungli.test.web",
		"APPLE_WEB_REDIRECT_URI":  "https://api.example.test/v1/auth/apple/callback",
		"APPLE_CALLBACK_DEEPLINK": "myungli://auth/apple",
	}
}

// freePort는 지금 비어 있는 포트 번호를 돌려줍니다.
func freePort(t *testing.T) string {
	t.Helper()
	listener, err := (&net.ListenConfig{}).Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen: %v", err)
	}
	defer func() { _ = listener.Close() }()
	return strconv.Itoa(listener.Addr().(*net.TCPAddr).Port)
}

// waitForHealthz는 url이 200을 줄 때까지 짧은 간격으로 확인합니다. 5초 안에 안 되면 실패합니다.
func waitForHealthz(t *testing.T, url string) {
	t.Helper()
	client := &http.Client{Timeout: 500 * time.Millisecond}
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		resp, err := getWithContext(t.Context(), client, url)
		if err == nil {
			_ = resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return
			}
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("%s가 5초 안에 200을 주지 않았습니다", url)
}

// getWithContext는 ctx를 실어 GET 요청을 보냅니다.
func getWithContext(ctx context.Context, client *http.Client, url string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	return client.Do(req)
}
