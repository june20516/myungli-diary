package notify_test

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/notify"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// fcmReply는 가짜 FCM 서버의 응답 하나입니다.
type fcmReply struct {
	status int
	body   string
}

// fakeFCM은 요청 경로와 본문을 기록하고 replies를 차례로 돌려줍니다. 다 쓰면 마지막 응답을 되풀이합니다.
type fakeFCM struct {
	*httptest.Server
	mu      sync.Mutex
	replies []fcmReply
	paths   []string
	bodies  []map[string]any
}

func newFakeFCM(t *testing.T, replies ...fcmReply) *fakeFCM {
	t.Helper()
	f := &fakeFCM{replies: replies}
	f.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		var body map[string]any
		_ = json.Unmarshal(raw, &body)
		f.mu.Lock()
		f.paths = append(f.paths, r.Method+" "+r.URL.Path)
		f.bodies = append(f.bodies, body)
		reply := f.replies[min(len(f.paths), len(f.replies))-1]
		f.mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(reply.status)
		_, _ = w.Write([]byte(reply.body))
	}))
	t.Cleanup(f.Close)
	return f
}

func (f *fakeFCM) calls() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.paths)
}

var fcmOK = fcmReply{status: http.StatusOK, body: `{"name":"projects/proj-1/messages/1"}`}

func fcmError(status int, code string, extra string) fcmReply {
	details := `{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"` + code + `"}`
	if extra != "" {
		details += "," + extra
	}
	return fcmReply{status: status, body: `{"error":{"code":` + jsonInt(status) + `,"message":"x","status":"X","details":[` + details + `]}}`}
}

func jsonInt(n int) string {
	raw, _ := json.Marshal(n)
	return string(raw)
}

// sleeps는 FCM이 재시도 전에 기다린 시간을 기록합니다(실제로 기다리지 않음).
type sleeps struct {
	mu   sync.Mutex
	list []time.Duration
}

func (s *sleeps) sleep(_ context.Context, d time.Duration) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.list = append(s.list, d)
	return nil
}

var fcmNow = time.Date(2026, 11, 3, 22, 0, 0, 0, time.UTC) // 2026-11-04 07:00 KST

// testDeviceToken은 가짜 FCM 등록 토큰입니다. 오류에 새지 않는지 찾을 수 있게 고유한 값을 씁니다.
const testDeviceToken = "device-7f3a" //nolint:gosec // 테스트용 가짜 값이며 비밀이 아닙니다

func newTestFCM(t *testing.T, server *fakeFCM, waits *sleeps) *notify.FCM {
	t.Helper()
	fcm, err := notify.NewFCM(notify.FCMConfig{
		ProjectID:  "proj-1",
		HTTPClient: server.Client(),
		Endpoint:   server.URL,
		Clock:      clocktest.New(fcmNow),
		Sleep:      waits.sleep,
	})
	require.NoError(t, err)
	return fcm
}

func morningMessage(t *testing.T) notify.Message {
	t.Helper()
	seoul := mustLocation(t, "Asia/Seoul")
	return notify.Message{
		Token:  testDeviceToken,
		Body:   "말과 글에 힘이 실리는 날이에요.",
		Date:   profile.LocalDate{Year: 2026, Month: 11, Day: 4},
		Expire: time.Date(2026, 11, 5, 0, 0, 0, 0, seoul),
	}
}

func TestFCM_SendsAgreedShape(t *testing.T) {
	server := newFakeFCM(t, fcmOK)
	waits := &sleeps{}

	require.NoError(t, newTestFCM(t, server, waits).Send(context.Background(), morningMessage(t)))

	require.Equal(t, []string{"POST /v1/projects/proj-1/messages:send"}, server.paths)
	want := map[string]any{"message": map[string]any{ //nolint:gosec // 요청 본문 기대값이며 비밀이 아닙니다
		"token":        testDeviceToken,
		"notification": map[string]any{"body": "말과 글에 힘이 실리는 날이에요."},
		"data":         map[string]any{"kind": "morning", "date": "2026-11-04"},
		"android": map[string]any{
			"ttl":          "61200s",
			"notification": map[string]any{"channel_id": "morning", "tag": "morning"},
		},
		"apns": map[string]any{"headers": map[string]any{"apns-expiration": "1793804400", "apns-collapse-id": "morning"}},
	}}
	assert.Equal(t, want, server.bodies[0])
}

func TestFCM_TTLAtLeastOneSecond(t *testing.T) {
	server := newFakeFCM(t, fcmOK)
	message := morningMessage(t)
	message.Expire = fcmNow.Add(-time.Minute)

	require.NoError(t, newTestFCM(t, server, &sleeps{}).Send(context.Background(), message))

	android := server.bodies[0]["message"].(map[string]any)["android"].(map[string]any)
	assert.Equal(t, "1s", android["ttl"])
}

func TestFCM_UnregisteredIsTokenInvalid(t *testing.T) {
	server := newFakeFCM(t, fcmError(http.StatusNotFound, "UNREGISTERED", ""))

	err := newTestFCM(t, server, &sleeps{}).Send(context.Background(), morningMessage(t))

	require.ErrorIs(t, err, notify.ErrTokenInvalid)
	assert.Equal(t, 1, server.calls())
}

func TestFCM_InvalidTokenArgumentIsTokenInvalid(t *testing.T) {
	tokenViolation := `{"@type":"type.googleapis.com/google.rpc.BadRequest","fieldViolations":[{"field":"message.token","description":"x"}]}` //nolint:gosec // FCM 오류 응답 예시이며 비밀이 아닙니다
	server := newFakeFCM(t, fcmError(http.StatusBadRequest, "INVALID_ARGUMENT", tokenViolation))
	err := newTestFCM(t, server, &sleeps{}).Send(context.Background(), morningMessage(t))
	require.ErrorIs(t, err, notify.ErrTokenInvalid)

	badTTL := `{"@type":"type.googleapis.com/google.rpc.BadRequest","fieldViolations":[{"field":"message.android.ttl","description":"x"}]}`
	other := newFakeFCM(t, fcmError(http.StatusBadRequest, "INVALID_ARGUMENT", badTTL))
	err = newTestFCM(t, other, &sleeps{}).Send(context.Background(), morningMessage(t))
	require.Error(t, err)
	assert.False(t, errors.Is(err, notify.ErrTokenInvalid))
	assert.Equal(t, 1, other.calls(), "잘못된 요청은 다시 보내지 않습니다")
}

func TestFCM_RetriesTransient(t *testing.T) {
	server := newFakeFCM(t,
		fcmError(http.StatusServiceUnavailable, "UNAVAILABLE", ""),
		fcmError(http.StatusTooManyRequests, "QUOTA_EXCEEDED", ""),
		fcmError(http.StatusInternalServerError, "INTERNAL", ""),
		fcmOK,
	)
	waits := &sleeps{}

	require.NoError(t, newTestFCM(t, server, waits).Send(context.Background(), morningMessage(t)))

	assert.Equal(t, 4, server.calls())
	assert.Equal(t, []time.Duration{time.Second, 2 * time.Second, 4 * time.Second}, waits.list)
}

func TestFCM_GivesUpAfterThreeRetries(t *testing.T) {
	server := newFakeFCM(t, fcmError(http.StatusServiceUnavailable, "UNAVAILABLE", ""))

	err := newTestFCM(t, server, &sleeps{}).Send(context.Background(), morningMessage(t))

	require.Error(t, err)
	assert.False(t, errors.Is(err, notify.ErrTokenInvalid))
	assert.Equal(t, 4, server.calls())
}

func TestFCM_DoesNotRetryAuthErrors(t *testing.T) {
	server := newFakeFCM(t, fcmError(http.StatusUnauthorized, "THIRD_PARTY_AUTH_ERROR", ""))

	err := newTestFCM(t, server, &sleeps{}).Send(context.Background(), morningMessage(t))

	require.Error(t, err)
	assert.Equal(t, 1, server.calls())
}

func TestFCM_ErrorDoesNotLeakTokenOrBody(t *testing.T) {
	server := newFakeFCM(t, fcmError(http.StatusUnauthorized, "THIRD_PARTY_AUTH_ERROR", ""))

	err := newTestFCM(t, server, &sleeps{}).Send(context.Background(), morningMessage(t))

	require.Error(t, err)
	assert.NotContains(t, err.Error(), testDeviceToken)
	assert.NotContains(t, err.Error(), "힘이 실리는")
}

func TestNewFCM_RequiresProjectID(t *testing.T) {
	_, err := notify.NewFCM(notify.FCMConfig{})
	require.Error(t, err)
}
