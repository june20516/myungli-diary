package support_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/support"
)

var (
	now       = time.Date(2026, 11, 4, 1, 2, 3, 0, time.UTC)
	accountID = uuid.MustParse("0192f0a0-1234-7000-8000-0000000000aa")
)

type fakeMailer struct {
	sent []support.Mail
	err  error
}

func (f *fakeMailer) Send(_ context.Context, m support.Mail) error {
	f.sent = append(f.sent, m)
	return f.err
}

type fakeLimiter struct {
	gotKey    string
	gotLimit  int
	gotWindow time.Duration
	calls     int
	deny      bool
	err       error
}

func (f *fakeLimiter) Allow(_ context.Context, key string, limit int, window time.Duration) (bool, time.Duration, error) {
	f.calls++
	f.gotKey, f.gotLimit, f.gotWindow = key, limit, window
	if f.err != nil {
		return false, 0, f.err
	}
	if f.deny {
		return false, 42 * time.Minute, nil
	}
	return true, 0, nil
}

func inquiry() support.Inquiry {
	return support.Inquiry{
		Message:     "결제했는데 광고가 나와요.\n확인 부탁드립니다.",
		ReplyEmail:  "user@example.com",
		AppVersion:  "1.0.0+4",
		OS:          "Android 15",
		DeviceModel: "Pixel 8",
		Language:    "ko",
	}
}

func newService(mailer support.Mailer, limiter *fakeLimiter) *support.Service {
	return support.NewService(support.Config{To: "support@myungli-diary.app", Mailer: mailer, Limiter: limiter, Clock: clocktest.New(now)})
}

// 문의는 운영 메일함으로 가고 Reply-To는 사용자 주소이며, 본문에 계정, 앱, 기기, 언어, 접수 시각과 내용이 담깁니다.
func TestSubmit_SendsMailToSupportWithReplyTo(t *testing.T) {
	mailer := &fakeMailer{}
	limiter := &fakeLimiter{}

	require.NoError(t, newService(mailer, limiter).Submit(context.Background(), accountID, inquiry()))

	require.Len(t, mailer.sent, 1)
	m := mailer.sent[0]
	assert.Equal(t, "support@myungli-diary.app", m.To)
	assert.Equal(t, "user@example.com", m.ReplyTo)
	assert.Equal(t, "명리일기 문의 (계정 0192f0a0, 1.0.0+4)", m.Subject)
	assert.Equal(t, `계정 id: 0192f0a0-1234-7000-8000-0000000000aa
답장 주소: user@example.com
앱 버전: 1.0.0+4
기기: Android 15, Pixel 8
언어: ko
접수 시각: 2026-11-04 10:02:03 KST (2026-11-04T01:02:03Z)

문의 내용:
결제했는데 광고가 나와요.
확인 부탁드립니다.
`, m.Text)
	assert.Equal(t, "createInquiry:"+accountID.String(), limiter.gotKey)
	assert.Equal(t, 5, limiter.gotLimit)
	assert.Equal(t, time.Hour, limiter.gotWindow)
}

// 한도를 넘으면 보내지 않고 다시 보낼 수 있는 시간을 돌려줍니다.
func TestSubmit_RateLimited(t *testing.T) {
	mailer := &fakeMailer{}

	err := newService(mailer, &fakeLimiter{deny: true}).Submit(context.Background(), accountID, inquiry())

	var limited *support.RateLimitedError
	require.ErrorAs(t, err, &limited)
	assert.Equal(t, 42*time.Minute, limited.RetryAfter)
	assert.Empty(t, mailer.sent)
}

// 발송 서비스가 없으면 한도를 쓰지 않고 ErrUnavailable입니다.
func TestSubmit_NoMailerIsUnavailableWithoutUsingLimit(t *testing.T) {
	limiter := &fakeLimiter{}

	err := newService(nil, limiter).Submit(context.Background(), accountID, inquiry())

	require.ErrorIs(t, err, support.ErrUnavailable)
	assert.Zero(t, limiter.calls)
}

// 발송이 실패하면 ErrUnavailable과 원인을 함께 돌려줍니다.
func TestSubmit_MailerFailureIsUnavailable(t *testing.T) {
	cause := errors.New("provider 502")

	err := newService(&fakeMailer{err: cause}, &fakeLimiter{}).Submit(context.Background(), accountID, inquiry())

	require.ErrorIs(t, err, support.ErrUnavailable)
	require.ErrorIs(t, err, cause)
}

// 한도 저장소 오류는 그대로 올립니다(ErrUnavailable이 아님).
func TestSubmit_LimiterErrorIsReturned(t *testing.T) {
	cause := errors.New("db down")

	err := newService(&fakeMailer{}, &fakeLimiter{err: cause}).Submit(context.Background(), accountID, inquiry())

	require.ErrorIs(t, err, cause)
	assert.NotErrorIs(t, err, support.ErrUnavailable)
}

// 답장 주소는 표시 이름 없는 주소 하나여야 합니다. 메일 헤더에 들어가므로 줄바꿈과 여러 주소를 막습니다.
func TestSubmit_RejectsReplyEmailThatIsNotOneBareAddress(t *testing.T) {
	for name, email := range map[string]string{
		"표시 이름":     "Kim <user@example.com>",
		"여러 주소":     "a@example.com, b@example.com",
		"줄바꿈 헤더 주입": "user@example.com\r\nBcc: x@example.com",
		"주소 아님":     "not-an-email",
	} {
		mailer := &fakeMailer{}
		in := inquiry()
		in.ReplyEmail = email
		err := newService(mailer, &fakeLimiter{}).Submit(context.Background(), accountID, in)
		require.ErrorIs(t, err, support.ErrInvalidReplyEmail, name)
		assert.Empty(t, mailer.sent, name)
	}
}

// 필수 설정이 비면 조립 버그라 panic합니다.
func TestNewService_RequiresConfig(t *testing.T) {
	assert.Panics(t, func() { support.NewService(support.Config{Limiter: &fakeLimiter{}, Clock: clocktest.New(now)}) })
	assert.Panics(t, func() { support.NewService(support.Config{To: "a@b.co", Clock: clocktest.New(now)}) })
}
