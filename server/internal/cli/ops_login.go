package cli

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
	"time"

	"golang.org/x/oauth2"
)

// `server ops login`입니다. 데스크톱 OAuth 클라이언트로 브라우저 로그인(루프백 리디렉션, PKCE S256)을 한 번 하고,
// 받은 refresh token을 운영 API 주소와 함께 로컬 값 파일(권한 600)에 둡니다.

const (
	// opsLoginTimeout은 브라우저 로그인을 기다리는 시간입니다.
	opsLoginTimeout = 5 * time.Minute
	// opsStateBytes는 state 값의 무작위 바이트 수입니다.
	opsStateBytes = 32
	// opsCallbackShutdownTimeout은 콜백 서버가 응답을 마저 보내고 닫기를 기다리는 시간입니다.
	opsCallbackShutdownTimeout = 3 * time.Second
)

// opsOAuthScopes는 ID token에 메일을 담기 위한 scope입니다.
var opsOAuthScopes = []string{"openid", "email"}

func runOpsLogin(ctx context.Context, deps opsDeps, args []string, getenv func(string) string, stderr io.Writer) error {
	flags := flag.NewFlagSet("login", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	env := flags.String("env", "", "환경 staging|prod(필수)")
	apiURL := flags.String("api-url", "", "운영 API 주소(https, 필수)")
	if err := flags.Parse(args); err != nil {
		return usageErrorf("ops login: %v\n%s", err, opsUsageText)
	}
	if flags.NArg() != 0 {
		return usageErrorf("ops login: 알 수 없는 인자 %q\n%s", flags.Arg(0), opsUsageText)
	}
	if !slices.Contains(opsEnvironments, *env) {
		return usageErrorf("ops login: --env는 staging 또는 prod여야 합니다")
	}
	if *apiURL == "" {
		return usageErrorf("ops login: --api-url이 필요합니다")
	}
	baseURL, err := validateOpsAPIURL(*apiURL)
	if err != nil {
		return usageErrorf("ops login: --api-url: %v", err)
	}

	dir, err := opsLocalDir(getenv, *env)
	if err != nil {
		return err
	}
	if err := ensureOpsDir(dir); err != nil {
		return err
	}
	client, err := readOpsOAuthClient(filepath.Join(dir, opsClientFile))
	if err != nil {
		return err
	}
	refreshToken, err := authorizeOps(ctx, deps, client, stderr)
	if err != nil {
		return err
	}
	path := filepath.Join(dir, opsCredentialsFile)
	credentials := opsCredentials{APIURL: baseURL, ClientID: client.ClientID, ClientSecret: client.ClientSecret, RefreshToken: refreshToken}
	if err := writeOpsCredentials(path, credentials); err != nil {
		return err
	}
	_, _ = fmt.Fprintf(stderr, "로그인했습니다. %s에 저장했습니다.\n", path)
	return nil
}

// opsOAuthClient는 데스크톱 OAuth 클라이언트 id와 secret입니다.
type opsOAuthClient struct {
	ClientID     string `json:"client_id"`
	ClientSecret string `json:"client_secret"`
}

// readOpsOAuthClient는 Google 콘솔에서 내려받은 데스크톱 클라이언트 JSON의 installed 칸을 읽습니다. 내용은 출력하지 않습니다.
func readOpsOAuthClient(path string) (opsOAuthClient, error) {
	raw, err := os.ReadFile(path) //nolint:gosec // 경로는 로컬 값 폴더와 고정 파일 이름으로 만듭니다.
	if errors.Is(err, fs.ErrNotExist) {
		return opsOAuthClient{}, fmt.Errorf("%s가 없습니다. Google Cloud 콘솔에서 데스크톱 앱 OAuth 클라이언트 JSON을 내려받아 그 이름으로 두세요", path)
	}
	if err != nil {
		return opsOAuthClient{}, fmt.Errorf("%s를 읽지 못했습니다: %w", path, err)
	}
	var file struct {
		Installed opsOAuthClient `json:"installed"`
	}
	if json.Unmarshal(raw, &file) != nil || file.Installed.ClientID == "" || file.Installed.ClientSecret == "" {
		return opsOAuthClient{}, fmt.Errorf("%s에 installed.client_id와 installed.client_secret이 없습니다(데스크톱 앱 OAuth 클라이언트 JSON이어야 합니다)", path)
	}
	return file.Installed, nil
}

// opsCallback은 루프백 리디렉션으로 받은 결과입니다.
type opsCallback struct {
	code string
	err  error
}

// authorizeOps는 브라우저 로그인을 거쳐 refresh token을 받습니다.
func authorizeOps(ctx context.Context, deps opsDeps, client opsOAuthClient, stderr io.Writer) (string, error) {
	listener, err := (&net.ListenConfig{}).Listen(ctx, "tcp", "127.0.0.1:0")
	if err != nil {
		return "", fmt.Errorf("로그인 응답을 받을 루프백 포트를 열지 못했습니다: %w", err)
	}
	state, err := randomOpsState()
	if err != nil {
		_ = listener.Close()
		return "", err
	}
	verifier := oauth2.GenerateVerifier()
	config := oauth2.Config{
		ClientID:     client.ClientID,
		ClientSecret: client.ClientSecret,
		Endpoint:     oauth2.Endpoint{AuthURL: deps.authURL, TokenURL: deps.tokenURL, AuthStyle: oauth2.AuthStyleInParams},
		RedirectURL:  "http://" + listener.Addr().String() + "/",
		Scopes:       opsOAuthScopes,
	}
	// prompt=consent는 이미 동의한 계정에도 refresh token을 다시 받으려는 것입니다.
	authURL := config.AuthCodeURL(state, oauth2.AccessTypeOffline, oauth2.S256ChallengeOption(verifier),
		oauth2.SetAuthURLParam("prompt", "consent"))

	results := make(chan opsCallback, 1)
	server := &http.Server{Handler: opsCallbackHandler(state, results), ReadHeaderTimeout: 10 * time.Second}
	go func() { _ = server.Serve(listener) }()
	// 콜백 응답을 브라우저에 다 보낸 뒤 닫도록 Shutdown을 쓰고, 시간 안에 못 끝나면 Close합니다.
	defer func() {
		shutdownCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), opsCallbackShutdownTimeout)
		defer cancel()
		if server.Shutdown(shutdownCtx) != nil {
			_ = server.Close()
		}
	}()

	_, _ = fmt.Fprintf(stderr, "브라우저에서 Google 계정으로 로그인하세요. 브라우저가 열리지 않으면 아래 주소를 여세요.\n%s\n", authURL)
	if err := deps.openBrowser(ctx, authURL); err != nil {
		_, _ = fmt.Fprintf(stderr, "브라우저를 열지 못했습니다: %v\n", err)
	}

	waitCtx, cancel := context.WithTimeout(ctx, opsLoginTimeout)
	defer cancel()
	var result opsCallback
	select {
	case <-waitCtx.Done():
		return "", fmt.Errorf("로그인을 %s 안에 마치지 못했습니다", opsLoginTimeout)
	case result = <-results:
	}
	if result.err != nil {
		return "", result.err
	}

	exchangeCtx := context.WithValue(ctx, oauth2.HTTPClient, deps.httpClient)
	token, err := config.Exchange(exchangeCtx, result.code, oauth2.VerifierOption(verifier))
	if err != nil {
		return "", fmt.Errorf("인가 코드를 토큰으로 바꾸지 못했습니다(%s)", describeTokenError(err))
	}
	if token.RefreshToken == "" {
		return "", errors.New("refresh token을 받지 못했습니다. Google 계정의 서드파티 앱 접근에서 이 앱을 지운 뒤 다시 로그인하세요")
	}
	return token.RefreshToken, nil
}

// opsCallbackHandler는 루프백 리디렉션을 받아 state가 맞는 첫 결과 하나만 넘깁니다.
// 경로가 콜백이 아니거나 state가 맞지 않는 요청은 400만 답하고 결과로 넘기지 않습니다.
// 같은 컴퓨터의 다른 프로그램이 엉뚱한 요청을 보내도 로그인이 끝나지 않고 올바른 콜백을 계속 기다립니다.
func opsCallbackHandler(state string, results chan<- opsCallback) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query()
		if r.URL.Path != "/" || subtle.ConstantTimeCompare([]byte(query.Get("state")), []byte(state)) != 1 {
			http.Error(w, "로그인 응답이 아닙니다.", http.StatusBadRequest)
			return
		}
		var result opsCallback
		switch {
		case query.Get("error") != "":
			result.err = fmt.Errorf("로그인이 거절되었습니다(%s)", cell(query.Get("error")))
		case query.Get("code") == "":
			result.err = errors.New("로그인 응답에 code가 없습니다")
		default:
			result.code = query.Get("code")
		}

		page := "로그인을 마쳤습니다. 이 창을 닫고 터미널로 돌아가세요."
		if result.err != nil {
			page = "로그인하지 못했습니다. 터미널을 확인하세요."
		}
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		_, _ = io.WriteString(w, page)

		select {
		case results <- result:
		default:
		}
	})
}

// randomOpsState는 CSRF를 막는 state 값을 만듭니다.
func randomOpsState() (string, error) {
	buf := make([]byte, opsStateBytes)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("state를 만들지 못했습니다: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

// ensureOpsDir는 로컬 값 폴더를 확인합니다. 없으면 0700으로 만들고, 있는데 그룹이나 기타 사용자에게 쓰기 권한이 있으면 거절합니다.
// 다른 사용자가 자격 파일을 바꿔치기하지 못하게 하려는 것입니다.
func ensureOpsDir(dir string) error {
	info, err := os.Stat(dir)
	if errors.Is(err, fs.ErrNotExist) {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			return fmt.Errorf("%s 폴더를 만들지 못했습니다: %w", dir, err)
		}
		return nil
	}
	if err != nil {
		return fmt.Errorf("%s 폴더 정보를 읽지 못했습니다: %w", dir, err)
	}
	if !info.IsDir() {
		return fmt.Errorf("%s가 폴더가 아닙니다", dir)
	}
	if perm := info.Mode().Perm(); perm&0o022 != 0 {
		return fmt.Errorf("%s 폴더 권한이 %04o입니다. 그룹과 기타 사용자의 쓰기 권한을 빼세요(chmod go-w %s)", dir, perm, dir)
	}
	return nil
}

// writeOpsCredentials는 로컬 값 파일을 권한 600으로 씁니다. 같은 폴더의 임시 파일에 쓴 뒤 rename해 반쯤 쓴 파일이 남지 않게 합니다.
func writeOpsCredentials(path string, credentials opsCredentials) (err error) {
	dir := filepath.Dir(path)
	if err := ensureOpsDir(dir); err != nil {
		return err
	}
	payload, err := json.MarshalIndent(credentials, "", "  ") //nolint:gosec // 로컬 값 파일(권한 600)에 쓰려고 직렬화합니다. 출력하지 않습니다
	if err != nil {
		return fmt.Errorf("로컬 값을 만들지 못했습니다: %w", err)
	}
	tmp, err := os.CreateTemp(dir, ".ops-oauth-*.json")
	if err != nil {
		return fmt.Errorf("%s에 임시 파일을 만들지 못했습니다: %w", dir, err)
	}
	defer func() {
		if err != nil {
			_ = tmp.Close()
			_ = os.Remove(tmp.Name())
		}
	}()
	if err := tmp.Chmod(0o600); err != nil {
		return fmt.Errorf("임시 파일 권한을 바꾸지 못했습니다: %w", err)
	}
	if _, err := tmp.Write(append(payload, '\n')); err != nil {
		return fmt.Errorf("임시 파일에 쓰지 못했습니다: %w", err)
	}
	if err := tmp.Sync(); err != nil {
		return fmt.Errorf("임시 파일을 저장하지 못했습니다: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("임시 파일을 닫지 못했습니다: %w", err)
	}
	if err := os.Rename(tmp.Name(), path); err != nil {
		return fmt.Errorf("%s로 옮기지 못했습니다: %w", path, err)
	}
	return nil
}

// openSystemBrowser는 운영체제 기본 브라우저로 주소를 엽니다. 끝나기를 기다리지 않고, 프로세스는 goroutine에서 거둡니다.
func openSystemBrowser(ctx context.Context, target string) error {
	var command *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		command = exec.CommandContext(ctx, "open", target) //nolint:gosec // 고정 실행 파일에 login이 만든 인증 주소만 넘깁니다
	case "windows":
		command = exec.CommandContext(ctx, "rundll32", "url.dll,FileProtocolHandler", target) //nolint:gosec // 고정 실행 파일에 login이 만든 인증 주소만 넘깁니다
	default:
		command = exec.CommandContext(ctx, "xdg-open", target) //nolint:gosec // 고정 실행 파일에 login이 만든 인증 주소만 넘깁니다
	}
	if err := command.Start(); err != nil {
		return err
	}
	go func() { _ = command.Wait() }()
	return nil
}
