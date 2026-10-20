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
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/seed"
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

func TestServe_RequiresEngineAddr(t *testing.T) {
	env := testAuthEnv(t)
	delete(env, "ENGINE_ADDR")
	env["PORT"] = freePort(t)
	env["DATABASE_URL"] = "postgres://x@127.0.0.1:1/x"
	var stdout, stderr bytes.Buffer

	code := Run(t.Context(), []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
	if code != 1 {
		t.Errorf("종료 코드 = %d, want 1", code)
	}
	if !strings.Contains(stderr.String(), "ENGINE_ADDR") {
		t.Errorf("stderr에 ENGINE_ADDR가 없습니다: %q", stderr.String())
	}
}

// 엔진이 닫혀 있어 시작 때 GetInfo가 실패해도 serve는 시작하고, 로그에는 연결 방식만 남고 주소는 남지 않습니다.
func TestServe_StartsWhenEngineInfoFails(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	env := testAuthEnv(t)
	env["PORT"] = freePort(t)
	env["DATABASE_URL"] = dbtest.NewURL(t)
	var stdout, stderr bytes.Buffer

	done := make(chan int, 1)
	go func() {
		done <- Run(ctx, []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
	}()

	waitForHealthz(t, "http://127.0.0.1:"+env["PORT"]+"/healthz")
	cancel()

	select {
	case code := <-done:
		if code != 0 {
			t.Errorf("종료 코드 = %d, stderr = %q", code, stderr.String())
		}
	case <-time.After(10 * time.Second):
		t.Fatal("ctx 취소 뒤 serve가 종료되지 않았습니다")
	}
	logs := stderr.String()
	if !strings.Contains(logs, `"engine":"h2c"`) {
		t.Errorf("시작 로그에 엔진 연결 방식이 없습니다: %q", logs)
	}
	if strings.Contains(logs, testClosedEngineAddr) {
		t.Errorf("로그에 엔진 주소가 남았습니다: %q", logs)
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
		{"App Link 주소가 http", "APP_LINK_BASE", "http://" + secret + ".example"},
		{"App Link 주소에 host가 없음", "APP_LINK_BASE", "https:///" + secret},
		{"App Link 주소에 path가 있음", "APP_LINK_BASE", "https://app.myungli.example/" + secret},
		{"App Link 주소에 query가 있음", "APP_LINK_BASE", "https://app.myungli.example/?q=" + secret},
		{"App Link 주소를 해석할 수 없음", "APP_LINK_BASE", "https://app.myungli.example/%zz" + secret},
		{"App Link 주소가 scheme 없는 값", "APP_LINK_BASE", secret},
		{"스토어 주소가 http", "ANDROID_STORE_URL", "http://play.example/" + secret},
		{"스토어 주소에 host가 없음", "ANDROID_STORE_URL", "https:///" + secret},
		{"스토어 주소가 javascript", "ANDROID_STORE_URL", "javascript:alert('" + secret + "')"},
		{"패키지 이름에 점이 없음", "ANDROID_APP_PACKAGE", "leakchecksecretvalue"},
		{"패키지 이름이 숫자로 시작하는 조각", "ANDROID_APP_PACKAGE", "app.1" + "leakchecksecret"},
		{"패키지 이름에 쓸 수 없는 문자", "ANDROID_APP_PACKAGE", "app.myungli-" + secret},
		{"지문이 hex 형식이 아님", "ANDROID_CERT_SHA256", secret},
		{"지문이 소문자", "ANDROID_CERT_SHA256", strings.ToLower(testCertSHA256)},
		{"지문 길이가 31바이트", "ANDROID_CERT_SHA256", testCertSHA256[3:]},
		{"지문 목록에 빈 값", "ANDROID_CERT_SHA256", testCertSHA256 + ","},
		{"지문 목록의 두 번째 값이 틀림", "ANDROID_CERT_SHA256", testCertSHA256 + "," + secret},
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

func TestParseAuthSettings_AcceptsAppLinkSettings(t *testing.T) {
	tests := []struct {
		name, base, certs string
		wantCerts         []string
	}{
		{"path 없음, 지문 하나", "https://app.myungli.example", testCertSHA256, []string{testCertSHA256}},
		{"path가 /, 지문 둘(공백 포함)", "https://app.myungli.example:8443/", testCertSHA256 + " , " + otherCertSHA256, []string{testCertSHA256, otherCertSHA256}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := testAuthEnv(t)
			env["APP_LINK_BASE"] = tt.base
			env["ANDROID_CERT_SHA256"] = tt.certs
			cfg, err := config.LoadAuth(func(key string) string { return env[key] })
			if err != nil {
				t.Fatalf("LoadAuth: %v", err)
			}

			settings, err := parseAuthSettings(cfg)
			if err != nil {
				t.Fatalf("parseAuthSettings error = %v, want nil", err)
			}
			if got := settings.appLink.Base.String(); got != tt.base {
				t.Errorf("Base = %q, want %q", got, tt.base)
			}
			if got := settings.appLink.CertSHA256; !slices.Equal(got, tt.wantCerts) {
				t.Errorf("CertSHA256 = %v, want %v", got, tt.wantCerts)
			}
			if settings.appLink.Package != "app.myungli.test" || settings.appLink.StoreURL != testStoreURL {
				t.Errorf("Package·StoreURL = %q·%q", settings.appLink.Package, settings.appLink.StoreURL)
			}
		})
	}
}

func TestNewProviderHTTPClient_HasTimeout(t *testing.T) {
	if got := newProviderHTTPClient().Timeout; got != 5*time.Second {
		t.Errorf("Timeout = %v, want 5s", got)
	}
}

// testCertSHA256·otherCertSHA256은 Android 서명 인증서 SHA-256 지문 형식의 테스트 값입니다.
const (
	testCertSHA256  = "14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"
	otherCertSHA256 = "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
)

// testStoreURL은 테스트의 Play 스토어 주소입니다.
const testStoreURL = "https://play.google.com/store/apps/details?id=app.myungli.test"

// testClosedEngineAddr는 아무도 듣지 않는 엔진 주소입니다.
const testClosedEngineAddr = "127.0.0.1:1"

// testAuthEnv는 인증 설정 20개 중 필수 값 16개와 ENGINE_ADDR, TEST_LOGIN_SECRET(staging 빌드만 읽음)을 채운 환경을 만듭니다.
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
		"APP_LINK_BASE":           "https://app.myungli.example",
		"ANDROID_APP_PACKAGE":     "app.myungli.test",
		"ANDROID_CERT_SHA256":     testCertSHA256,
		"ANDROID_STORE_URL":       testStoreURL,
		// 닫힌 로컬 포트입니다. 엔진 연결은 lazy라 서버는 시작합니다.
		"ENGINE_ADDR": testClosedEngineAddr,
		// staging 빌드에서만 읽는 테스트 로그인 비밀입니다(S24). prod 빌드는 읽지 않습니다.
		"TEST_LOGIN_SECRET": "staging-test-login-secret-0123456789",
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

func TestServe_AssemblesContentRoutes(t *testing.T) {
	// serve와 같은 조립으로 콘텐츠 저장소와 운세 화면 묶음을 붙이고, seed 명령으로 시드를 넣은 DB에서 용어 사전을 받습니다.
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		code, _, stderr := runCLIWithEnv(t, map[string]string{"DATABASE_URL": deps.Pool.Config().ConnString()}, "seed")
		require.Equal(t, 0, code, "seed stderr: %s", stderr)

		contents := content.NewStore(deps.Pool, deps.Clock, deps.Logger)
		deps.Contents = contents
		deps.Readings = newReadings(contents, nil, fortune.AlwaysLocked{}, deps.Logger, deps.Clock)
	})

	login := env.loginKakao("kakao-content-subject")
	require.Equal(t, http.StatusOK, login.status, "로그인 본문: %v", login.body)
	access, _ := login.tokens(t)
	consent := env.do(http.MethodPost, "/v1/me/consents", access, currentConsents())
	require.Equal(t, http.StatusNoContent, consent.status, "동의 본문: %v", consent.body)

	// lang을 주면 프로필 없이 받습니다.
	glossary := env.do(http.MethodGet, "/v1/glossary?lang=ko", access, nil)
	require.Equal(t, http.StatusOK, glossary.status, "용어 사전 본문: %v", glossary.body)
	embedded, err := seed.Load()
	require.NoError(t, err, "seed.Load")
	assert.Equal(t, embedded.Version, glossary.body["seedVersion"], "seed 명령이 넣은 내장 시드가 활성입니다")
	assert.NotEmpty(t, glossary.body["values"], "내장 시드의 값 이름이 있습니다")
}
