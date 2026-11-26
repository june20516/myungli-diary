package cli

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"golang.org/x/oauth2"
)

// 운영 API 클라이언트입니다(#1321). 운영자는 `server ops login`으로 한 번 로그인해 refresh token을 로컬 값 파일에 두고,
// 명령마다 그 refresh token으로 Google ID token을 받아 `Authorization: Bearer`로 보냅니다. IAP가 이 ID token을 확인합니다.
// refresh token, client secret, ID token은 어떤 출력이나 오류 문구에도 넣지 않습니다.

const (
	// opsGoogleAuthURL과 opsGoogleTokenURL은 Google OAuth endpoint입니다.
	opsGoogleAuthURL  = "https://accounts.google.com/o/oauth2/v2/auth"
	opsGoogleTokenURL = "https://oauth2.googleapis.com/token" //nolint:gosec // 공개 엔드포인트 URL이며 자격 증명이 아닙니다

	// opsCredentialsFile은 login이 쓰고 다른 명령이 읽는 로컬 값 파일입니다(권한 600).
	opsCredentialsFile = "ops-oauth.json" //nolint:gosec // 파일 이름이며 자격 증명이 아닙니다
	// opsClientFile은 Google 콘솔에서 내려받은 데스크톱 OAuth 클라이언트 파일입니다.
	opsClientFile = "ops-oauth-client.json"

	// opsHeader는 운영 API가 요구하는 사용자 정의 헤더입니다(브라우저 교차 출처 요청 차단).
	opsHeader = "X-Myungli-Ops"
	// opsHTTPTimeout은 API와 token endpoint 요청 하나의 상한입니다.
	opsHTTPTimeout = time.Minute
	// opsMaxResponseBytes는 읽을 응답 본문의 상한입니다. 감사 기록 1000건에 전후 값이 있어도 넉넉합니다.
	opsMaxResponseBytes = 32 << 20
	// opsMaxCredentialsBytes는 로컬 값 파일을 읽는 상한입니다.
	opsMaxCredentialsBytes = 64 << 10
)

// opsDeps는 운영 명령이 바깥과 닿는 곳입니다. 시험에서 가짜 서버와 브라우저로 바꿉니다.
type opsDeps struct {
	// httpClient는 운영 API와 token endpoint를 부를 때 씁니다.
	httpClient *http.Client
	authURL    string
	tokenURL   string
	// openBrowser는 login에서 인증 주소를 브라우저로 엽니다.
	openBrowser func(ctx context.Context, target string) error
}

func defaultOpsDeps() opsDeps {
	return opsDeps{
		httpClient:  &http.Client{Timeout: opsHTTPTimeout},
		authURL:     opsGoogleAuthURL,
		tokenURL:    opsGoogleTokenURL,
		openBrowser: openSystemBrowser,
	}
}

// newOpsCommand는 주어진 의존성으로 `server ops` 명령을 만듭니다.
// 인자 해석이 끝난 뒤에야 로컬 값 파일을 읽고 네트워크에 붙으므로, 사용법 오류는 네트워크 전에 종료 코드 2로 끝납니다.
func newOpsCommand(deps opsDeps) Command {
	return func(ctx context.Context, args []string, getenv func(string) string, stdout, stderr io.Writer) error {
		if len(args) > 0 && args[0] == "login" {
			return runOpsLogin(ctx, deps, args[1:], getenv, stderr)
		}
		command, err := parseOps(args)
		if err != nil {
			return err
		}
		dir, err := opsLocalDir(getenv, command.env)
		if err != nil {
			return err
		}
		credentials, err := loadOpsCredentials(filepath.Join(dir, opsCredentialsFile), command.env)
		if err != nil {
			return err
		}
		return command.action(ctx, newOpsClient(deps, credentials, command.env), stdout)
	}
}

// opsLocalDir는 환경의 로컬 값 폴더 `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/server/<env>`입니다(D98).
func opsLocalDir(getenv func(string) string, env string) (string, error) {
	base := getenv("MYUNGLI_LOCAL_DIR")
	if base == "" {
		home := getenv("HOME")
		if home == "" {
			return "", errors.New("MYUNGLI_LOCAL_DIR와 HOME이 모두 비어 있어 로컬 값 폴더를 찾을 수 없습니다")
		}
		base = filepath.Join(home, ".config", "myungli")
	}
	return filepath.Join(base, "server", env), nil
}

// opsCredentials는 login이 남기는 로컬 값입니다.
type opsCredentials struct {
	APIURL       string `json:"apiUrl"`
	ClientID     string `json:"clientId"`
	ClientSecret string `json:"clientSecret"`
	RefreshToken string `json:"refreshToken"`
}

// loadOpsCredentials는 로컬 값 파일을 읽습니다. 그룹이나 기타 사용자에게 권한이 있으면 거절합니다.
// 오류 문구에는 파일 경로만 넣고 내용은 넣지 않습니다.
func loadOpsCredentials(path, env string) (opsCredentials, error) {
	relogin := fmt.Sprintf("server ops login --env %s --api-url <운영 API 주소>를 실행하세요", env)
	file, err := os.Open(path) //nolint:gosec // 경로는 로컬 값 폴더와 고정 파일 이름으로 만듭니다.
	if errors.Is(err, fs.ErrNotExist) {
		return opsCredentials{}, fmt.Errorf("%s가 없습니다. 먼저 %s", path, relogin)
	}
	if err != nil {
		return opsCredentials{}, fmt.Errorf("%s를 열지 못했습니다: %w", path, err)
	}
	defer func() { _ = file.Close() }()

	info, err := file.Stat()
	if err != nil {
		return opsCredentials{}, fmt.Errorf("%s 정보를 읽지 못했습니다: %w", path, err)
	}
	if !info.Mode().IsRegular() {
		return opsCredentials{}, fmt.Errorf("%s가 보통 파일이 아닙니다", path)
	}
	if perm := info.Mode().Perm(); perm&0o077 != 0 {
		return opsCredentials{}, fmt.Errorf("%s 권한이 %04o입니다. 본인만 읽을 수 있게 600으로 바꾸세요(chmod 600 %s)", path, perm, path)
	}

	raw, err := io.ReadAll(io.LimitReader(file, opsMaxCredentialsBytes))
	if err != nil {
		return opsCredentials{}, fmt.Errorf("%s를 읽지 못했습니다: %w", path, err)
	}
	var credentials opsCredentials
	if json.Unmarshal(raw, &credentials) != nil ||
		credentials.APIURL == "" || credentials.ClientID == "" || credentials.ClientSecret == "" || credentials.RefreshToken == "" {
		return opsCredentials{}, fmt.Errorf("%s 형식이 올바르지 않습니다(apiUrl, clientId, clientSecret, refreshToken 필요). 다시 %s", path, relogin)
	}
	if credentials.APIURL, err = validateOpsAPIURL(credentials.APIURL); err != nil {
		return opsCredentials{}, fmt.Errorf("%s의 apiUrl: %w. 다시 %s", path, err, relogin)
	}
	return credentials, nil
}

// validateOpsAPIURL은 운영 API 주소를 검사하고 끝의 /를 뗀 주소를 돌려줍니다.
// https만 받고, 시험용으로 루프백(127.0.0.1, ::1, localhost)의 http는 허용합니다. 사용자 정보, query, fragment는 거절합니다.
func validateOpsAPIURL(raw string) (string, error) {
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Host == "" {
		return "", errors.New("https 주소여야 합니다")
	}
	switch parsed.Scheme {
	case "https":
	case "http":
		if !isLoopbackHost(parsed.Hostname()) {
			return "", errors.New("https 주소여야 합니다(http는 127.0.0.1과 localhost만)")
		}
	default:
		return "", errors.New("https 주소여야 합니다")
	}
	if parsed.User != nil || parsed.RawQuery != "" || parsed.ForceQuery || parsed.Fragment != "" {
		return "", errors.New("사용자 정보, query, fragment를 넣지 않습니다")
	}
	parsed.Path = strings.TrimRight(parsed.Path, "/")
	parsed.RawPath = ""
	return parsed.String(), nil
}

func isLoopbackHost(host string) bool {
	return host == "127.0.0.1" || host == "::1" || host == "localhost"
}

// opsClient는 운영 API를 부릅니다.
type opsClient struct {
	baseURL     string
	env         string
	httpClient  *http.Client
	oauth       oauth2.Config
	credentials opsCredentials
}

// newOpsClient는 클라이언트를 만듭니다. 리디렉션은 따르지 않습니다.
// IAP가 로그인 페이지로 돌리는 응답을 따라가면 Bearer 없이 다른 곳에 요청하게 되므로, 3xx는 그대로 실패로 다룹니다.
func newOpsClient(deps opsDeps, credentials opsCredentials, env string) *opsClient {
	httpClient := *deps.httpClient
	httpClient.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	return &opsClient{
		baseURL:    credentials.APIURL,
		env:        env,
		httpClient: &httpClient,
		oauth: oauth2.Config{
			ClientID:     credentials.ClientID,
			ClientSecret: credentials.ClientSecret,
			Endpoint:     oauth2.Endpoint{TokenURL: deps.tokenURL, AuthStyle: oauth2.AuthStyleInParams},
		},
		credentials: credentials,
	}
}

// opsErrorCode는 token endpoint 오류 코드로 출력에 넣어도 되는 모양입니다(예: invalid_grant).
var opsErrorCode = regexp.MustCompile(`^[a-z_]{1,64}$`)

// idToken은 refresh token으로 Google ID token을 받습니다.
func (c *opsClient) idToken(ctx context.Context) (string, error) {
	ctx = context.WithValue(ctx, oauth2.HTTPClient, c.httpClient)
	token, err := c.oauth.TokenSource(ctx, &oauth2.Token{RefreshToken: c.credentials.RefreshToken}).Token()
	if err != nil {
		return "", fmt.Errorf("ID token을 받지 못했습니다(%s). refresh token이 만료되었거나 취소되었으면 server ops login --env %s를 다시 실행하세요",
			describeTokenError(err), c.env)
	}
	idToken, _ := token.Extra("id_token").(string)
	if idToken == "" {
		return "", fmt.Errorf("토큰 서버 응답에 id_token이 없습니다. server ops login --env %s를 다시 실행하세요", c.env)
	}
	return idToken, nil
}

// describeTokenError는 token endpoint 오류를 비밀 값 없이 짧게 설명합니다.
// 응답 본문(error_description 등)은 넣지 않고 HTTP 상태와 정해진 모양의 오류 코드만 씁니다.
func describeTokenError(err error) string {
	var retrieve *oauth2.RetrieveError
	if !errors.As(err, &retrieve) {
		var urlErr *url.Error
		if errors.As(err, &urlErr) {
			return "토큰 서버에 연결하지 못했습니다: " + urlErr.Err.Error()
		}
		return "토큰 서버 응답을 읽지 못했습니다"
	}
	description := "토큰 서버 거절"
	if retrieve.Response != nil {
		description = fmt.Sprintf("HTTP %d", retrieve.Response.StatusCode)
	}
	if opsErrorCode.MatchString(retrieve.ErrorCode) {
		description += " " + retrieve.ErrorCode
	}
	return description
}

// opsErrorResponse는 운영 API의 오류 응답 본문입니다.
type opsErrorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// call은 운영 API 하나를 POST JSON으로 부르고 200 응답을 response로 읽습니다.
// 400은 사용법 오류(종료 코드 2), 그 밖의 실패는 실행 오류(1)이고, 출력은 응답의 message 한 줄입니다.
func (c *opsClient) call(ctx context.Context, path string, request, response any) error {
	idToken, err := c.idToken(ctx)
	if err != nil {
		return err
	}
	payload, err := json.Marshal(request)
	if err != nil {
		return fmt.Errorf("요청 본문을 만들지 못했습니다: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+path, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("요청을 만들지 못했습니다: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+idToken)
	req.Header.Set(opsHeader, "1")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		var urlErr *url.Error
		if errors.As(err, &urlErr) {
			err = urlErr.Err
		}
		return fmt.Errorf("운영 API에 연결하지 못했습니다: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	body := io.LimitReader(resp.Body, opsMaxResponseBytes)

	if resp.StatusCode != http.StatusOK {
		return opsStatusError(resp.StatusCode, body)
	}
	if err := json.NewDecoder(body).Decode(response); err != nil {
		return fmt.Errorf("운영 API 응답을 읽지 못했습니다: %w", err)
	}
	return nil
}

// opsStatusError는 실패 응답을 오류로 바꿉니다. message는 한 줄로 만들고 터미널 제어문자를 바꿉니다.
// JSON 오류 본문이 아니면(IAP가 막은 응답, 리디렉션 등) 상태 코드만 알립니다.
func opsStatusError(status int, body io.Reader) error {
	message := fmt.Sprintf("운영 API가 HTTP %d로 답했습니다", status)
	var decoded opsErrorResponse
	if json.NewDecoder(body).Decode(&decoded) == nil && strings.TrimSpace(decoded.Message) != "" {
		message = cell(decoded.Message)
	}
	if status == http.StatusBadRequest {
		return usageErrorf("ops: %s", message)
	}
	return errors.New(message)
}
