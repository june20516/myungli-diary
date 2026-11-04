package support

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	// defaultResendEndpoint는 Resend API 주소입니다(테스트에서 바꿉니다).
	defaultResendEndpoint = "https://api.resend.com"
	// defaultResendTimeout은 요청 한 번의 상한입니다. 사용자가 보내기 버튼을 누른 채 기다리는 시간입니다.
	defaultResendTimeout = 10 * time.Second
	// resendMaxErrorBody는 오류 응답에서 읽는 최대 바이트입니다.
	resendMaxErrorBody = 16 << 10
)

// ResendConfig는 Resend 발송 설정입니다(E20, S134).
type ResendConfig struct {
	// APIKey는 Resend API 키입니다(Secret RESEND_API_KEY). 필수입니다.
	APIKey string
	// From은 보내는 주소입니다(인증한 도메인의 주소, 표시 이름 포함 가능). 필수입니다.
	From string
	// HTTPClient가 nil이면 http.DefaultClient입니다.
	HTTPClient *http.Client
	// Endpoint가 비면 운영 주소입니다.
	Endpoint string
	// Timeout이 0이면 10초입니다.
	Timeout time.Duration
}

// Resend는 Resend REST API(POST /emails)로 메일을 보내는 Mailer입니다.
type Resend struct {
	url     string
	apiKey  string
	from    string
	client  *http.Client
	timeout time.Duration
}

var _ Mailer = (*Resend)(nil)

// NewResend는 Resend Mailer를 만듭니다.
func NewResend(cfg ResendConfig) (*Resend, error) {
	if cfg.APIKey == "" || cfg.From == "" {
		return nil, errors.New("resend: API 키와 보내는 주소가 필요합니다")
	}
	endpoint := cfg.Endpoint
	if endpoint == "" {
		endpoint = defaultResendEndpoint
	}
	client := cfg.HTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	timeout := cfg.Timeout
	if timeout == 0 {
		timeout = defaultResendTimeout
	}
	return &Resend{url: strings.TrimRight(endpoint, "/") + "/emails", apiKey: cfg.APIKey, from: cfg.From, client: client, timeout: timeout}, nil
}

// resendRequest는 POST /emails 본문입니다.
type resendRequest struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	Text    string   `json:"text"`
	ReplyTo []string `json:"reply_to,omitempty"`
}

// resendError는 오류 응답에서 쓰는 필드입니다. message는 요청 값을 담을 수 있어 읽지 않습니다.
type resendError struct {
	Name string `json:"name"`
}

// Send는 메일 한 통을 보냅니다. 2xx면 nil이고, 아니면 상태와 Resend 오류 이름만 담은 오류입니다(본문, 주소, 키 없음).
// 다시 보내지 않습니다. 사용자의 재시도는 Idempotency-Key로 막고, 실패는 503으로 알립니다.
func (r *Resend) Send(ctx context.Context, m Mail) error {
	body := resendRequest{From: r.from, To: []string{m.To}, Subject: m.Subject, Text: m.Text}
	if m.ReplyTo != "" {
		body.ReplyTo = []string{m.ReplyTo}
	}
	payload, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("resend 요청 직렬화: %w", err)
	}
	ctx, cancel := context.WithTimeout(ctx, r.timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.url, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("resend 요청 생성: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	resp, err := r.client.Do(req)
	if err != nil {
		return fmt.Errorf("resend 요청 실패: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, resendMaxErrorBody))
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}
	var parsed resendError
	_ = json.Unmarshal(raw, &parsed)
	return fmt.Errorf("resend 응답 %d %s", resp.StatusCode, parsed.Name)
}
