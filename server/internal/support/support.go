// Package support는 앱 안 문의(D102)를 운영 메일함으로 보냅니다. 문의 내용은 저장하지 않습니다(S134).
package support

import (
	"context"
	"errors"
	"fmt"
	"net/mail"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

const (
	// hourlyLimit는 한 계정이 1시간에 보낼 수 있는 문의 수입니다(S134).
	hourlyLimit = 5
	// limitWindow는 hourlyLimit를 세는 창입니다.
	limitWindow = time.Hour
	// limitKeyPrefix는 요청 한도 키의 앞부분입니다. 뒤에 계정 id가 붙습니다.
	limitKeyPrefix = "createInquiry:"
)

// kst는 운영자가 읽는 접수 시각의 시간대입니다. 운영자가 한국에 있어 UTC와 함께 적습니다.
var kst = time.FixedZone("KST", 9*60*60)

var (
	// ErrUnavailable은 메일을 보낼 수 없다는 뜻입니다(발송 서비스 설정이 없거나 응답하지 않음).
	ErrUnavailable = errors.New("문의 메일을 보낼 수 없습니다")
	// ErrInvalidReplyEmail은 답장 주소를 메일 주소 하나로 읽을 수 없다는 뜻입니다.
	ErrInvalidReplyEmail = errors.New("답장 받을 메일 주소가 올바르지 않습니다")
)

// RateLimitedError는 계정의 문의 한도를 넘었다는 뜻입니다. RetryAfter 뒤에 다시 보낼 수 있습니다.
type RateLimitedError struct {
	RetryAfter time.Duration
}

func (e *RateLimitedError) Error() string {
	return fmt.Sprintf("문의 한도 초과(%s 뒤 다시)", e.RetryAfter)
}

// Inquiry는 문의 한 건입니다. Message와 ReplyEmail은 사용자가 쓰고 나머지는 app이 붙입니다.
type Inquiry struct {
	Message     string
	ReplyEmail  string
	AppVersion  string
	OS          string
	DeviceModel string
	// Language는 요청 언어(Accept-Language로 고른 ko, en, ja)입니다.
	Language string
}

// Mail은 발송 서비스에 넘기는 메일 한 통입니다. 본문은 평문입니다.
type Mail struct {
	To      string
	ReplyTo string
	Subject string
	Text    string
}

// Mailer는 메일 한 통을 보냅니다. 발송 서비스가 받으면 nil입니다.
type Mailer interface {
	Send(ctx context.Context, m Mail) error
}

// Limiter는 키별 요청 수를 셉니다. *ratelimit.Limiter가 만족합니다.
type Limiter interface {
	Allow(ctx context.Context, key string, limit int, window time.Duration) (allowed bool, retryAfter time.Duration, err error)
}

// Config는 Service 설정입니다.
type Config struct {
	// To는 받는 운영 메일함입니다(E14 support@myungli-diary.app).
	To string
	// Mailer가 nil이면 발송 서비스가 설정되지 않은 것이고 Submit은 ErrUnavailable입니다.
	Mailer  Mailer
	Limiter Limiter
	Clock   clock.Clock
}

// Service는 문의를 메일로 보냅니다.
type Service struct {
	to      string
	mailer  Mailer
	limiter Limiter
	clk     clock.Clock
}

// NewService는 Service를 만듭니다. To, Limiter, Clock이 비면 조립 버그이므로 panic합니다.
func NewService(cfg Config) *Service {
	if cfg.To == "" || cfg.Limiter == nil || cfg.Clock == nil {
		panic("support.NewService: To, Limiter, Clock이 모두 있어야 합니다")
	}
	return &Service{to: cfg.To, mailer: cfg.Mailer, limiter: cfg.Limiter, clk: cfg.Clock}
}

// Submit은 계정 accountID의 문의를 운영 메일함으로 보냅니다.
// 발송 서비스가 없으면 한도를 쓰지 않고 ErrUnavailable입니다. 한도를 넘으면 *RateLimitedError입니다.
// 한도는 보내기 전에 세므로, 발송이 실패해도 그 시도는 한도에 들어갑니다(실패한 서비스에 몰아 보내지 않게).
func (s *Service) Submit(ctx context.Context, accountID uuid.UUID, in Inquiry) error {
	replyTo, err := parseReplyEmail(in.ReplyEmail)
	if err != nil {
		return err
	}
	if s.mailer == nil {
		return ErrUnavailable
	}
	allowed, retryAfter, err := s.limiter.Allow(ctx, limitKeyPrefix+accountID.String(), hourlyLimit, limitWindow)
	if err != nil {
		return fmt.Errorf("문의 한도 확인: %w", err)
	}
	if !allowed {
		return &RateLimitedError{RetryAfter: retryAfter}
	}
	m := compose(s.to, replyTo, accountID, in, s.clk.Now())
	if err := s.mailer.Send(ctx, m); err != nil {
		return fmt.Errorf("%w: %w", ErrUnavailable, err)
	}
	return nil
}

// parseReplyEmail은 답장 주소가 표시 이름 없는 주소 하나인지 확인하고 그 주소를 돌려줍니다.
// 계약의 format email 검사를 지난 값이지만, 메일 헤더에 들어가므로 net/mail로 한 번 더 읽습니다.
func parseReplyEmail(raw string) (string, error) {
	if strings.ContainsAny(raw, "\r\n") {
		return "", ErrInvalidReplyEmail
	}
	addr, err := mail.ParseAddress(raw)
	if err != nil || addr.Name != "" || addr.Address != raw {
		return "", ErrInvalidReplyEmail
	}
	return addr.Address, nil
}

// compose는 운영자가 읽을 메일을 만듭니다. 제목에는 server가 검사한 값(계정 id 앞 8자, 앱 버전)만 넣습니다.
func compose(to, replyTo string, accountID uuid.UUID, in Inquiry, receivedAt time.Time) Mail {
	account := accountID.String()
	var text strings.Builder
	fmt.Fprintf(&text, "계정 id: %s\n", account)
	fmt.Fprintf(&text, "답장 주소: %s\n", replyTo)
	fmt.Fprintf(&text, "앱 버전: %s\n", in.AppVersion)
	fmt.Fprintf(&text, "기기: %s, %s\n", in.OS, in.DeviceModel)
	fmt.Fprintf(&text, "언어: %s\n", in.Language)
	fmt.Fprintf(&text, "접수 시각: %s (%s)\n", receivedAt.In(kst).Format("2006-01-02 15:04:05 MST"), receivedAt.UTC().Format(time.RFC3339))
	text.WriteString("\n문의 내용:\n")
	text.WriteString(in.Message)
	text.WriteString("\n")
	return Mail{
		To:      to,
		ReplyTo: replyTo,
		Subject: fmt.Sprintf("명리일기 문의 (계정 %s, %s)", account[:8], in.AppVersion),
		Text:    text.String(),
	}
}
