package httpapi

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// 계약 검증이 막는 형식 오류가 변환까지 오면 조용히 지나가지 않고 오류로 드러납니다.
func TestToProfile_MalformedClockIsError(t *testing.T) {
	bad := "7시"
	_, err := toProfile(gen.ProfileInput{Notification: gen.NotificationSetting{Status: gen.NotificationSettingStatusEnabled, Time: &bad}})
	require.Error(t, err)

	_, err = toPatch(gen.ProfilePatch{Notification: &gen.NotificationSetting{Time: &bad}})
	assert.Error(t, err)
}
