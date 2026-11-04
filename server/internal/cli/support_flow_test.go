package cli

import (
	"context"
	"net/http"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/support"
)

// capturingMailer는 보낸 메일을 모으는 대역입니다. 요청 고루틴에서 부르므로 잠급니다.
type capturingMailer struct {
	mu   sync.Mutex
	sent []support.Mail
}

func (m *capturingMailer) Send(_ context.Context, mail support.Mail) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sent = append(m.sent, mail)
	return nil
}

func (m *capturingMailer) count() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.sent)
}

func inquiryFlowBody() map[string]any {
	return map[string]any{
		"message": "결제했는데 광고가 나와요.", "replyEmail": "user@example.com",
		"appVersion": "1.0.0+4", "os": "Android 15", "deviceModel": "Pixel 8",
	}
}

// serve 조립(newServer)에 문의 접수, 멱등, 계정당 한도(실제 rate_limits 표)가 들어 있는지 확인합니다(S134).
func TestSupportFlow_SendsAndLimitsPerAccount(t *testing.T) {
	mailer := &capturingMailer{}
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		deps.Support = supportMail{To: "support@myungli-diary.app", Mailer: mailer}
	})
	access := env.loginAgreed(env.loginKakao("support-flow-subject"))

	first := env.doWithKey(http.MethodPost, "/v1/support/inquiries", access, "inquiry-key-1", inquiryFlowBody())
	require.Equal(t, http.StatusNoContent, first.status, "접수 본문: %v", first.body)
	require.Equal(t, 1, mailer.count())
	assert.Equal(t, "support@myungli-diary.app", mailer.sent[0].To)
	assert.Equal(t, "user@example.com", mailer.sent[0].ReplyTo)

	// 같은 키의 재시도는 메일을 다시 보내지 않고 처음 응답을 돌려줍니다.
	replay := env.doWithKey(http.MethodPost, "/v1/support/inquiries", access, "inquiry-key-1", inquiryFlowBody())
	require.Equal(t, http.StatusNoContent, replay.status, "재시도 본문: %v", replay.body)
	assert.Equal(t, 1, mailer.count())

	// 1시간 5번까지입니다. 첫 요청을 포함해 네 번 더 보내면 다섯 번이고, 여섯 번째는 429입니다.
	for range 4 {
		ok := env.do(http.MethodPost, "/v1/support/inquiries", access, inquiryFlowBody())
		require.Equal(t, http.StatusNoContent, ok.status, "접수 본문: %v", ok.body)
	}
	limited := env.do(http.MethodPost, "/v1/support/inquiries", access, inquiryFlowBody())
	limited.requireProblem(t, http.StatusTooManyRequests, "rate_limited")
	assert.Equal(t, 5, mailer.count())

	// 한도는 계정마다 따로입니다.
	other := env.loginAgreed(env.loginKakao("support-flow-other"))
	otherOK := env.do(http.MethodPost, "/v1/support/inquiries", other, inquiryFlowBody())
	require.Equal(t, http.StatusNoContent, otherOK.status, "다른 계정 본문: %v", otherOK.body)
}

// 발송 설정이 없으면 503 service.unavailable입니다.
func TestSupportFlow_UnconfiguredIs503(t *testing.T) {
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		deps.Support = supportMail{To: "support@myungli-diary.app"}
	})
	access := env.loginAgreed(env.loginKakao("support-flow-unconfigured"))

	env.do(http.MethodPost, "/v1/support/inquiries", access, inquiryFlowBody()).requireProblem(t, http.StatusServiceUnavailable, "service.unavailable")
}
