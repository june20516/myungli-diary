package httpapi_test

import (
	"context"
	"net/http"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/device"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
)

// fakeDevices는 DeviceService 대역입니다. 받은 인자를 기록하고, 준비한 결과나 오류를 돌려줍니다.
type fakeDevices struct {
	item    device.Device
	created bool
	err     error

	gotAccount  uuid.UUID
	gotID       uuid.UUID
	gotToken    string
	gotPlatform device.Platform
}

func (f *fakeDevices) Register(_ context.Context, accountID uuid.UUID, token string, platform device.Platform) (device.Device, bool, error) {
	f.gotAccount, f.gotToken, f.gotPlatform = accountID, token, platform
	return f.item, f.created, f.err
}

func (f *fakeDevices) Deactivate(_ context.Context, accountID, id uuid.UUID) error {
	f.gotAccount, f.gotID = accountID, id
	return f.err
}

var sampleDeviceID = uuid.MustParse("0198a000-0000-7000-8000-000000000002")

const deviceTarget = "/v1/devices/0198a000-0000-7000-8000-000000000002"

// 알림 기기 API는 프로필이 필요 없으므로 Profiles를 두지 않습니다.
func deviceAPI(devices *fakeDevices) *httpapi.API {
	return &httpapi.API{Devices: devices}
}

func TestRegisterDevice_NewIs201(t *testing.T) {
	devices := &fakeDevices{item: device.Device{ID: sampleDeviceID, Platform: device.PlatformIOS}, created: true}
	req, rec := sendRequest(t, deviceAPI(devices), http.MethodPost, "/v1/devices", `{"fcmToken":"token-1","platform":"ios"}`)

	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, fixedAccountID, devices.gotAccount)
	assert.Equal(t, "token-1", devices.gotToken)
	assert.Equal(t, device.PlatformIOS, devices.gotPlatform)
	body := decodeMap(t, rec)
	assert.Equal(t, sampleDeviceID.String(), body["id"])
	assert.Equal(t, "ios", body["platform"])
}

func TestRegisterDevice_ExistingIs200(t *testing.T) {
	devices := &fakeDevices{item: device.Device{ID: sampleDeviceID, Platform: device.PlatformAndroid}}
	req, rec := sendRequest(t, deviceAPI(devices), http.MethodPost, "/v1/devices", `{"fcmToken":"token-1","platform":"android"}`)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, sampleDeviceID.String(), decodeMap(t, rec)["id"])
}

func TestDeleteDevice_Is204(t *testing.T) {
	devices := &fakeDevices{}
	req, rec := sendRequest(t, deviceAPI(devices), http.MethodDelete, deviceTarget, "")

	require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, fixedAccountID, devices.gotAccount)
	assert.Equal(t, sampleDeviceID, devices.gotID)
}

func TestDeleteDevice_NotFoundIs404(t *testing.T) {
	req, rec := sendRequest(t, deviceAPI(&fakeDevices{err: device.ErrNotFound}), http.MethodDelete, deviceTarget, "")

	require.Equal(t, http.StatusNotFound, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, "device.not_found", decodeProblem(t, rec).Code)
}

func TestDevices_NilServiceIs503(t *testing.T) {
	for _, tt := range []struct{ method, target, body string }{
		{http.MethodPost, "/v1/devices", `{"fcmToken":"token-1","platform":"ios"}`},
		{http.MethodDelete, deviceTarget, ""},
	} {
		req, rec := sendRequest(t, &httpapi.API{}, tt.method, tt.target, tt.body)

		require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
		expectFortuneContract(t, req, rec)
		assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	}
}
