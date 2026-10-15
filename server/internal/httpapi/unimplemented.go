package httpapi

import (
	"context"
	"errors"

	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// ErrNotImplemented는 아직 구현하지 않은 operation이 돌려주는 오류입니다.
// RegisterAPI가 이 오류를 501 not_implemented problem으로 바꿉니다.
var ErrNotImplemented = errors.New("operation이 아직 구현되지 않았습니다")

// Unimplemented는 gen.StrictServerInterface의 기본 구현입니다.
// 헬스 체크를 뺀 모든 operation이 ErrNotImplemented(501 not_implemented)를 돌려줍니다.
// 이후 계획은 이 타입을 embed한 구조체에서 메서드를 하나씩 덮어씁니다.
type Unimplemented struct{}

var _ gen.StrictServerInterface = Unimplemented{}

// GetHealth는 프로세스가 요청을 받을 수 있으면 200 {"status":"ok"}입니다.
// 의존성 점검(503)은 의존성이 생기는 계획에서 덮어씁니다.
func (Unimplemented) GetHealth(context.Context, gen.GetHealthRequestObject) (gen.GetHealthResponseObject, error) {
	return gen.GetHealth200JSONResponse{Status: gen.Ok}, nil
}

func (Unimplemented) GetAppConfig(context.Context, gen.GetAppConfigRequestObject) (gen.GetAppConfigResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) LoginApple(context.Context, gen.LoginAppleRequestObject) (gen.LoginAppleResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) AppleCallback(context.Context, gen.AppleCallbackRequestObject) (gen.AppleCallbackResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) CompleteAppleWebLogin(context.Context, gen.CompleteAppleWebLoginRequestObject) (gen.CompleteAppleWebLoginResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) LoginKakao(context.Context, gen.LoginKakaoRequestObject) (gen.LoginKakaoResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) GetProfile(context.Context, gen.GetProfileRequestObject) (gen.GetProfileResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) ConvertLunarDate(context.Context, gen.ConvertLunarDateRequestObject) (gen.ConvertLunarDateResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) Logout(context.Context, gen.LogoutRequestObject) (gen.LogoutResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) RefreshToken(context.Context, gen.RefreshTokenRequestObject) (gen.RefreshTokenResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) RestorePurchases(context.Context, gen.RestorePurchasesRequestObject) (gen.RestorePurchasesResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) GetBirthHour(context.Context, gen.GetBirthHourRequestObject) (gen.GetBirthHourResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) GetCalendar(context.Context, gen.GetCalendarRequestObject) (gen.GetCalendarResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) GetChart(context.Context, gen.GetChartRequestObject) (gen.GetChartResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) ListCities(context.Context, gen.ListCitiesRequestObject) (gen.ListCitiesResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) GetDaily(context.Context, gen.GetDailyRequestObject) (gen.GetDailyResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) DeleteReaction(context.Context, gen.DeleteReactionRequestObject) (gen.DeleteReactionResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) PutReaction(context.Context, gen.PutReactionRequestObject) (gen.PutReactionResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) RegisterDevice(context.Context, gen.RegisterDeviceRequestObject) (gen.RegisterDeviceResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) DeleteDevice(context.Context, gen.DeleteDeviceRequestObject) (gen.DeleteDeviceResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) ListDiaries(context.Context, gen.ListDiariesRequestObject) (gen.ListDiariesResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) DeleteDiary(context.Context, gen.DeleteDiaryRequestObject) (gen.DeleteDiaryResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) GetDiary(context.Context, gen.GetDiaryRequestObject) (gen.GetDiaryResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) PutDiary(context.Context, gen.PutDiaryRequestObject) (gen.PutDiaryResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) RestoreDiary(context.Context, gen.RestoreDiaryRequestObject) (gen.RestoreDiaryResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) GetGlossary(context.Context, gen.GetGlossaryRequestObject) (gen.GetGlossaryResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) DeleteMe(context.Context, gen.DeleteMeRequestObject) (gen.DeleteMeResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) GetMe(context.Context, gen.GetMeRequestObject) (gen.GetMeResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) AgreeConsents(context.Context, gen.AgreeConsentsRequestObject) (gen.AgreeConsentsResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) GetEntitlements(context.Context, gen.GetEntitlementsRequestObject) (gen.GetEntitlementsResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) UpdateProfile(context.Context, gen.UpdateProfileRequestObject) (gen.UpdateProfileResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) CreateProfile(context.Context, gen.CreateProfileRequestObject) (gen.CreateProfileResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) CreatePreview(context.Context, gen.CreatePreviewRequestObject) (gen.CreatePreviewResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) ListSchedules(context.Context, gen.ListSchedulesRequestObject) (gen.ListSchedulesResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) CreateSchedule(context.Context, gen.CreateScheduleRequestObject) (gen.CreateScheduleResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) DeleteSchedule(context.Context, gen.DeleteScheduleRequestObject) (gen.DeleteScheduleResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) UpdateSchedule(context.Context, gen.UpdateScheduleRequestObject) (gen.UpdateScheduleResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) RestoreSchedule(context.Context, gen.RestoreScheduleRequestObject) (gen.RestoreScheduleResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) AdmobRewardCallback(context.Context, gen.AdmobRewardCallbackRequestObject) (gen.AdmobRewardCallbackResponseObject, error) {
	return nil, ErrNotImplemented
}

func (Unimplemented) RevenuecatWebhook(context.Context, gen.RevenuecatWebhookRequestObject) (gen.RevenuecatWebhookResponseObject, error) {
	return nil, ErrNotImplemented
}
