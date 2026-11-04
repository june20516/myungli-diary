package support_test

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/support"
)

const testResendKey = "re_test_key" //nolint:gosec // 테스트 값이며 실제 자격 증명이 아닙니다

func newTestResend(t *testing.T, handler http.HandlerFunc) *support.Resend {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	r, err := support.NewResend(support.ResendConfig{APIKey: testResendKey, From: "명리일기 <noreply@myungli-diary.app>", Endpoint: srv.URL, HTTPClient: srv.Client(), Timeout: time.Second})
	require.NoError(t, err)
	return r
}

// POST /emails에 Bearer 키와 from, to, subject, text, reply_to를 보냅니다.
func TestResend_SendsEmail(t *testing.T) {
	var gotPath, gotAuth string
	var got map[string]any
	r := newTestResend(t, func(w http.ResponseWriter, req *http.Request) {
		gotPath, gotAuth = req.Method+" "+req.URL.Path, req.Header.Get("Authorization")
		raw, _ := io.ReadAll(req.Body)
		_ = json.Unmarshal(raw, &got)
		_, _ = w.Write([]byte(`{"id":"49a3999c-0ce1-4ea6-ab68-afcd6dc2e794"}`))
	})

	err := r.Send(context.Background(), support.Mail{To: "support@myungli-diary.app", ReplyTo: "user@example.com", Subject: "제목", Text: "본문"})

	require.NoError(t, err)
	assert.Equal(t, "POST /emails", gotPath)
	assert.Equal(t, "Bearer "+testResendKey, gotAuth)
	assert.Equal(t, map[string]any{
		"from":     "명리일기 <noreply@myungli-diary.app>",
		"to":       []any{"support@myungli-diary.app"},
		"subject":  "제목",
		"text":     "본문",
		"reply_to": []any{"user@example.com"},
	}, got)
}

// 2xx가 아니면 상태와 오류 이름만 담은 오류이고, 응답의 message(요청 값을 담을 수 있음)와 키는 담지 않습니다.
func TestResend_ErrorHasStatusAndNameOnly(t *testing.T) {
	r := newTestResend(t, func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`{"name":"validation_error","message":"user@example.com is not allowed"}`))
	})

	err := r.Send(context.Background(), support.Mail{To: "support@myungli-diary.app", Subject: "s", Text: "t"})

	require.Error(t, err)
	assert.Equal(t, "resend 응답 403 validation_error", err.Error())
	assert.NotContains(t, err.Error(), testResendKey)
}

// 응답이 늦으면 Timeout에서 끊고 오류입니다.
func TestResend_Timeout(t *testing.T) {
	r := newTestResend(t, func(w http.ResponseWriter, req *http.Request) {
		select {
		case <-req.Context().Done():
		case <-time.After(3 * time.Second):
		}
	})

	err := r.Send(context.Background(), support.Mail{To: "support@myungli-diary.app", Subject: "s", Text: "t"})

	require.Error(t, err)
}

// 키나 보내는 주소가 없으면 만들 수 없습니다.
func TestNewResend_RequiresKeyAndFrom(t *testing.T) {
	_, err := support.NewResend(support.ResendConfig{From: "a@b.co"})
	require.Error(t, err)
	_, err = support.NewResend(support.ResendConfig{APIKey: "k"})
	require.Error(t, err)
}
