package httpapi_test

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/support"
)

const inquiryPath = "/v1/support/inquiries"

// fakeInquiries는 받은 문의를 기록하고 정해 둔 오류를 돌려주는 대역입니다.
type fakeInquiries struct {
	calls   int
	gotAcct uuid.UUID
	got     support.Inquiry
	err     error
}

func (f *fakeInquiries) Submit(_ context.Context, accountID uuid.UUID, in support.Inquiry) error {
	f.calls++
	f.gotAcct, f.got = accountID, in
	return f.err
}

func inquiryBody(overrides map[string]any) string {
	body := map[string]any{
		"message":     "결제했는데 광고가 나와요.",
		"replyEmail":  "user@example.com",
		"appVersion":  "1.0.0+4",
		"os":          "Android 15",
		"deviceModel": "Pixel 8",
	}
	for k, v := range overrides {
		if v == nil {
			delete(body, k)
			continue
		}
		body[k] = v
	}
	encoded, _ := json.Marshal(body)
	return string(encoded)
}

func postInquiry(t *testing.T, service *fakeInquiries, body string, language string) *httptest.ResponseRecorder {
	t.Helper()
	api := &httpapi.API{}
	if service != nil {
		api.Inquiries = service
	}
	handler, _, _ := newHandlerAPIWithLogs(t, api)
	req := newBodyRequest(t, http.MethodPost, inquiryPath, contentTypeJSON, body)
	if language != "" {
		req.Header.Set("Accept-Language", language)
	}
	return serve(handler, req)
}

// 문의를 토큰의 계정과 요청 언어로 넘기고 204입니다.
func TestCreateInquiry_SubmitsForAuthenticatedAccount(t *testing.T) {
	service := &fakeInquiries{}

	rec := postInquiry(t, service, inquiryBody(nil), "ja")

	require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
	require.Equal(t, 1, service.calls)
	assert.Equal(t, fixedAccountID, service.gotAcct)
	assert.Equal(t, support.Inquiry{
		Message: "결제했는데 광고가 나와요.", ReplyEmail: "user@example.com",
		AppVersion: "1.0.0+4", OS: "Android 15", DeviceModel: "Pixel 8", Language: "ja",
	}, service.got)
}

// 계약에 맞지 않는 본문은 400이고 서비스를 부르지 않습니다. 메일 헤더에 들어가는 값은 줄바꿈을 받지 않습니다.
func TestCreateInquiry_RejectsInvalidBody(t *testing.T) {
	cases := map[string]map[string]any{
		"내용 없음":       {"message": nil},
		"내용이 공백뿐":     {"message": " \n\t "},
		"내용 2000자 넘음": {"message": strings.Repeat("가", 2001)},
		"주소 형식":       {"replyEmail": "not-an-email"},
		"주소 없음":       {"replyEmail": nil},
		"앱 버전 줄바꿈":    {"appVersion": "1.0.0\r\nBcc: x@example.com"},
		"앱 버전 공백":     {"appVersion": "1.0 beta"},
		"기종 제어 문자":    {"deviceModel": "Pixel\u0007"},
		"OS 없음":       {"os": nil},
	}
	for name, overrides := range cases {
		service := &fakeInquiries{}
		rec := postInquiry(t, service, inquiryBody(overrides), "")
		require.Equal(t, http.StatusBadRequest, rec.Code, "%s: %s", name, rec.Body.String())
		assert.Equal(t, "request.invalid", decodeProblem(t, rec).Code, name)
		assert.Zero(t, service.calls, name)
	}
}

// 한도를 넘으면 429 rate_limited이고 Retry-After는 초 단위로 올립니다.
func TestCreateInquiry_RateLimited(t *testing.T) {
	service := &fakeInquiries{err: &support.RateLimitedError{RetryAfter: 90*time.Second + time.Millisecond}}

	rec := postInquiry(t, service, inquiryBody(nil), "")

	require.Equal(t, http.StatusTooManyRequests, rec.Code, rec.Body.String())
	assert.Equal(t, "rate_limited", decodeProblem(t, rec).Code)
	assert.Equal(t, "91", rec.Header().Get("Retry-After"))
}

// 서비스가 답장 주소를 읽지 못하면 400이고 /replyEmail format입니다.
func TestCreateInquiry_InvalidReplyEmailFromService(t *testing.T) {
	rec := postInquiry(t, &fakeInquiries{err: support.ErrInvalidReplyEmail}, inquiryBody(nil), "")

	require.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	require.Len(t, p.Errors, 1)
	assert.Equal(t, "/replyEmail", p.Errors[0].Field)
	assert.Equal(t, "format", p.Errors[0].Code)
}

// 메일을 보낼 수 없거나 서비스가 조립되지 않았으면 503 service.unavailable입니다.
func TestCreateInquiry_UnavailableIs503(t *testing.T) {
	for name, service := range map[string]*fakeInquiries{
		"발송 실패":  {err: errors.Join(support.ErrUnavailable, errors.New("provider 502"))},
		"서비스 없음": nil,
	} {
		rec := postInquiry(t, service, inquiryBody(nil), "")
		require.Equal(t, http.StatusServiceUnavailable, rec.Code, "%s: %s", name, rec.Body.String())
		assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code, name)
	}
}
