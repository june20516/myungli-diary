package httpapi

import (
	"context"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/device"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// RegisterDevice는 알림 기기를 등록합니다. 처음 보는 토큰이면 201, 이미 등록된 토큰이면 같은 id로 200입니다(S92).
// Idempotency-Key는 핸들러가 아니라 멱등 미들웨어가 다룹니다.
func (a *API) RegisterDevice(ctx context.Context, req gen.RegisterDeviceRequestObject) (gen.RegisterDeviceResponseObject, error) {
	id, err := a.deviceAccountID(ctx)
	if err != nil {
		return nil, err
	}
	registered, created, err := a.Devices.Register(ctx, id, req.Body.FcmToken, device.Platform(req.Body.Platform))
	if err != nil {
		return nil, err
	}
	body := gen.Device{Id: registered.ID, Platform: gen.DevicePlatform(registered.Platform)}
	if created {
		return gen.RegisterDevice201JSONResponse(body), nil
	}
	return gen.RegisterDevice200JSONResponse(body), nil
}

// DeleteDevice는 알림 기기를 해제합니다. 이미 해제한 자기 기기도 204이고, 없거나 남의 기기면 404 device.not_found입니다.
func (a *API) DeleteDevice(ctx context.Context, req gen.DeleteDeviceRequestObject) (gen.DeleteDeviceResponseObject, error) {
	id, err := a.deviceAccountID(ctx)
	if err != nil {
		return nil, err
	}
	if err := a.Devices.Deactivate(ctx, id, req.Id); err != nil {
		return nil, err
	}
	return gen.DeleteDevice204Response{}, nil
}

// deviceAccountID는 알림 기기 operation 공통 앞부분으로, 인증된 계정 id를 돌려줍니다. 알림 기기는 프로필을 요구하지 않습니다.
// Devices가 조립되지 않은 것은 조립 실수이므로 일정과 같게 503으로 드러냅니다.
func (a *API) deviceAccountID(ctx context.Context) (uuid.UUID, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return uuid.Nil, errNoAccount
	}
	if a.Devices == nil {
		return uuid.Nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	return id, nil
}
