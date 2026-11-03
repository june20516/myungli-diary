package notify

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

const (
	// FCMScope는 FCM HTTP v1 발송에 필요한 OAuth2 scope입니다.
	FCMScope = "https://www.googleapis.com/auth/firebase.messaging"
	// defaultFCMEndpoint는 FCM HTTP v1 주소입니다(테스트에서 바꿉니다).
	defaultFCMEndpoint = "https://fcm.googleapis.com"
	// fcmRequestTimeout은 요청 한 번의 상한입니다.
	fcmRequestTimeout = 10 * time.Second
	// fcmMaxErrorBody는 오류 응답에서 읽는 최대 바이트입니다.
	fcmMaxErrorBody = 64 << 10

	// morningKind는 아침 알림의 data.kind, Android 채널, 표시 알림 교체 키입니다(#603).
	morningKind = "morning"
)

// fcmRetryDelays는 일시 오류 뒤 다시 보내기 전에 기다리는 시간입니다(지수 backoff 3번, spec §8.2).
var fcmRetryDelays = []time.Duration{time.Second, 2 * time.Second, 4 * time.Second}

// ErrTokenInvalid는 FCM이 등록 토큰을 무효라고 답했다는 뜻입니다(UNREGISTERED, 또는 token 필드가 잘못된 INVALID_ARGUMENT).
// 호출자는 그 기기를 비활성으로 바꿉니다(S92).
var ErrTokenInvalid = errors.New("FCM 등록 토큰이 무효입니다")

// Message는 아침 알림 하나입니다.
type Message struct {
	Token string
	// Body는 알림 본문(평문)입니다. 제목은 없습니다(#603).
	Body string
	// Date는 알림의 현지 날짜(data.date)입니다.
	Date profile.LocalDate
	// Expire는 알림이 의미를 잃는 시각(그 날짜 다음 날 현지 00:00)입니다. Android ttl과 APNs 만료에 씁니다.
	Expire time.Time
}

// FCMConfig는 FCM 설정입니다.
type FCMConfig struct {
	// ProjectID는 Firebase(GCP) 프로젝트 id입니다. 필수입니다.
	ProjectID string
	// HTTPClient는 OAuth2 access token을 붙이는 client입니다(조립하는 쪽이 ADC로 만듦). nil이면 http.DefaultClient입니다.
	HTTPClient *http.Client
	// Endpoint가 비면 운영 주소입니다.
	Endpoint string
	// Clock이 nil이면 clock.System입니다.
	Clock clock.Clock
	// Sleep이 nil이면 timer로 기다립니다(ctx가 끝나면 그 오류).
	Sleep func(ctx context.Context, d time.Duration) error
}

// FCM은 FCM HTTP v1으로 메시지를 보냅니다.
type FCM struct {
	url    string
	client *http.Client
	clk    clock.Clock
	sleep  func(ctx context.Context, d time.Duration) error
}

// NewFCM은 FCM client를 만듭니다.
func NewFCM(cfg FCMConfig) (*FCM, error) {
	if cfg.ProjectID == "" {
		return nil, errors.New("FCM 프로젝트 id가 필요합니다")
	}
	endpoint := cfg.Endpoint
	if endpoint == "" {
		endpoint = defaultFCMEndpoint
	}
	client := cfg.HTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	clk := cfg.Clock
	if clk == nil {
		clk = clock.System{}
	}
	sleep := cfg.Sleep
	if sleep == nil {
		sleep = sleepContext
	}
	return &FCM{
		url:    strings.TrimRight(endpoint, "/") + "/v1/projects/" + cfg.ProjectID + "/messages:send",
		client: client,
		clk:    clk,
		sleep:  sleep,
	}, nil
}

// Send는 메시지를 보냅니다. 일시 오류(QUOTA_EXCEEDED, UNAVAILABLE, INTERNAL, HTTP 429·5xx)는 3번까지 다시 보냅니다.
// 토큰이 무효면 ErrTokenInvalid를 감싸 돌려줍니다. 오류에는 토큰과 본문을 담지 않습니다.
func (f *FCM) Send(ctx context.Context, m Message) error {
	payload, err := json.Marshal(f.request(m))
	if err != nil {
		return fmt.Errorf("FCM 요청 직렬화: %w", err)
	}
	for attempt := 0; ; attempt++ {
		retryable, err := f.post(ctx, payload)
		if err == nil || !retryable || attempt == len(fcmRetryDelays) {
			return err
		}
		if err := f.sleep(ctx, fcmRetryDelays[attempt]); err != nil {
			return err
		}
	}
}

// post는 요청을 한 번 보냅니다. 실패하면 다시 보낼 만한지와 오류를 돌려줍니다.
func (f *FCM) post(ctx context.Context, payload []byte) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, fcmRequestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.url, bytes.NewReader(payload))
	if err != nil {
		return false, fmt.Errorf("FCM 요청 생성: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := f.client.Do(req)
	if err != nil {
		// 연결 오류는 일시 오류로 봅니다. 상위 ctx가 끝났으면 다시 보내지 않습니다.
		return ctx.Err() == nil, fmt.Errorf("FCM 요청 실패: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode == http.StatusOK {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, fcmMaxErrorBody))
		return false, nil
	}
	body, _ := io.ReadAll(io.LimitReader(resp.Body, fcmMaxErrorBody))
	return classifyFCMError(resp.StatusCode, body)
}

// fcmErrorResponse는 FCM 오류 응답에서 쓰는 필드입니다.
type fcmErrorResponse struct {
	Error struct {
		Details []struct {
			Type            string `json:"@type"`
			ErrorCode       string `json:"errorCode"`
			FieldViolations []struct {
				Field string `json:"field"`
			} `json:"fieldViolations"`
		} `json:"details"`
	} `json:"error"`
}

// classifyFCMError는 오류 응답을 토큰 무효, 일시 오류, 그 밖의 오류로 나눕니다.
func classifyFCMError(status int, body []byte) (bool, error) {
	var parsed fcmErrorResponse
	_ = json.Unmarshal(body, &parsed)
	var code string
	tokenField := false
	for _, d := range parsed.Error.Details {
		switch {
		case strings.HasSuffix(d.Type, "google.firebase.fcm.v1.FcmError"):
			code = d.ErrorCode
		case strings.HasSuffix(d.Type, "google.rpc.BadRequest"):
			for _, v := range d.FieldViolations {
				if v.Field == "message.token" {
					tokenField = true
				}
			}
		}
	}
	err := fmt.Errorf("FCM 응답 %d %s", status, code)
	switch {
	case code == "UNREGISTERED", code == "INVALID_ARGUMENT" && tokenField:
		return false, fmt.Errorf("%w: %w", ErrTokenInvalid, err)
	case code == "QUOTA_EXCEEDED", code == "UNAVAILABLE", code == "INTERNAL":
		return true, err
	case status == http.StatusTooManyRequests, status >= http.StatusInternalServerError:
		return true, err
	default:
		return false, err
	}
}

// fcmRequest는 FCM HTTP v1 요청 본문입니다(#603에서 app과 정한 형식).
type fcmRequest struct {
	Message fcmMessage `json:"message"`
}

type fcmMessage struct {
	Token        string            `json:"token"`
	Notification fcmNotification   `json:"notification"`
	Data         map[string]string `json:"data"`
	Android      fcmAndroid        `json:"android"`
	APNS         fcmAPNS           `json:"apns"`
}

type fcmNotification struct {
	Body string `json:"body"`
}

type fcmAndroid struct {
	TTL          string                 `json:"ttl"`
	Notification fcmAndroidNotification `json:"notification"`
}

type fcmAndroidNotification struct {
	ChannelID string `json:"channel_id"`
	Tag       string `json:"tag"`
}

type fcmAPNS struct {
	Headers map[string]string `json:"headers"`
}

// request는 메시지를 요청 본문으로 바꿉니다. Android ttl은 지금부터 만료까지(최소 1초)이고 APNs 만료는 만료 시각의 unix 초입니다.
func (f *FCM) request(m Message) fcmRequest {
	ttlSeconds := max(int64(math.Ceil(m.Expire.Sub(f.clk.Now()).Seconds())), 1)
	return fcmRequest{Message: fcmMessage{
		Token:        m.Token,
		Notification: fcmNotification{Body: m.Body},
		Data: map[string]string{
			"kind": morningKind,
			"date": fmt.Sprintf("%04d-%02d-%02d", m.Date.Year, m.Date.Month, m.Date.Day),
		},
		Android: fcmAndroid{
			TTL:          strconv.FormatInt(ttlSeconds, 10) + "s",
			Notification: fcmAndroidNotification{ChannelID: morningKind, Tag: morningKind},
		},
		APNS: fcmAPNS{Headers: map[string]string{
			"apns-expiration":  strconv.FormatInt(m.Expire.Unix(), 10),
			"apns-collapse-id": morningKind,
		}},
	}}
}

// sleepContext는 d만큼 기다리고, 그 전에 ctx가 끝나면 그 오류를 돌려줍니다.
func sleepContext(ctx context.Context, d time.Duration) error {
	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return nil
	}
}
