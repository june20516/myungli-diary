package cli

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// serve 조립(newServer)에 알림 기기 저장소와 registerDevice 멱등이 들어 있는지 확인합니다.
// 조립이 빠지면 두 operation은 501 not_implemented 또는 503 service.unavailable로 답합니다.
func TestDeviceFlow_RegisterAndDelete(t *testing.T) {
	env := newFlowEnv(t)
	access := env.loginAgreed(env.loginKakao("device-flow-subject"))
	other := env.loginAgreed(env.loginKakao("device-flow-other"))

	body := map[string]any{"fcmToken": "flow-token-1", "platform": "android"}
	first := env.doWithKey(http.MethodPost, "/v1/devices", access, "device-key-1", body)
	require.Equal(t, http.StatusCreated, first.status, "등록 본문: %v", first.body)
	id, _ := first.body["id"].(string)
	require.NotEmpty(t, id)

	// 키 없이 같은 토큰을 다시 등록하면 200과 같은 id입니다.
	again := env.do(http.MethodPost, "/v1/devices", access, body)
	require.Equal(t, http.StatusOK, again.status, "재등록 본문: %v", again.body)
	assert.Equal(t, id, again.body["id"])

	// 같은 키의 재시도는 첫 응답(201)을 그대로 다시 줍니다.
	replay := env.doWithKey(http.MethodPost, "/v1/devices", access, "device-key-1", body)
	require.Equal(t, http.StatusCreated, replay.status, "재시도 본문: %v", replay.body)
	assert.Equal(t, id, replay.body["id"])

	// 다른 계정은 남의 기기를 해제하지 못합니다.
	env.do(http.MethodDelete, "/v1/devices/"+id, other, nil).requireProblem(t, http.StatusNotFound, "device.not_found")

	// 해제는 멱등입니다.
	for range 2 {
		deleted := env.do(http.MethodDelete, "/v1/devices/"+id, access, nil)
		require.Equal(t, http.StatusNoContent, deleted.status, "해제 본문: %v", deleted.body)
	}
}
