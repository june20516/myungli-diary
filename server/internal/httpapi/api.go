package httpapi

import (
	"context"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/internal/schedule"
	"github.com/june20516/myungli-diary/server/legal"
)

// healthPingTimeout은 헬스 체크가 DB 응답을 기다리는 최대 시간입니다.
const healthPingTimeout = time.Second

// AuthService는 핸들러가 쓰는 인증 서비스입니다. *auth.Service가 만족합니다.
type AuthService interface {
	LoginKakao(ctx context.Context, idToken, rawNonce string) (auth.LoginResult, error)
	LoginApple(ctx context.Context, idToken, authorizationCode, rawNonce string) (auth.LoginResult, error)
	LoginLine(ctx context.Context, idToken, rawNonce string) (auth.LoginResult, error)
	LoginGoogle(ctx context.Context, idToken, rawNonce string) (auth.LoginResult, error)
	// ListIdentities는 계정에 붙은 로그인 제공자를 붙인 순서로 돌려줍니다.
	ListIdentities(ctx context.Context, accountID uuid.UUID) ([]auth.LinkedIdentity, error)
	// LinkIdentity는 계정에 제공자 연결을 붙입니다. 제공자별 증명 조합 검사는 서비스가 합니다.
	LinkIdentity(ctx context.Context, accountID uuid.UUID, providerName string, proof auth.LinkProof) (auth.LinkResult, error)
	UnlinkIdentity(ctx context.Context, accountID uuid.UUID, providerName string) error
	// BeginAppleWebLogin은 Apple 웹 콜백의 값을 검증·교환해 저장하고 일회용 교환 코드를 돌려줍니다.
	BeginAppleWebLogin(ctx context.Context, idToken, authorizationCode string) (exchangeCode string, err error)
	// CompleteAppleWebLogin은 교환 코드와 nonce 원문으로 로그인을 마칩니다.
	CompleteAppleWebLogin(ctx context.Context, exchangeCode, rawNonce string) (auth.LoginResult, error)
	Refresh(ctx context.Context, rawRefresh string) (auth.TokenPair, error)
	Logout(ctx context.Context, accountID uuid.UUID, rawRefresh string) error
}

// AccountService는 핸들러가 쓰는 계정 서비스입니다. *account.Service가 만족합니다.
type AccountService interface {
	Me(ctx context.Context, id uuid.UUID) (account.Me, error)
	AgreeConsents(ctx context.Context, id uuid.UUID, docs []account.ConsentDocument) error
	// Delete는 계정을 바로 지웁니다. 이미 지운 계정이면 아무것도 하지 않습니다.
	Delete(ctx context.Context, id uuid.UUID) error
}

// ProfileService는 핸들러가 쓰는 프로필 서비스입니다. *profile.Service가 만족합니다.
type ProfileService interface {
	Get(ctx context.Context, accountID uuid.UUID) (profile.Profile, error)
	Exists(ctx context.Context, accountID uuid.UUID) (bool, error)
	Put(ctx context.Context, accountID uuid.UUID, p profile.Profile) (profile.Saved, error)
	Patch(ctx context.Context, accountID uuid.UUID, p profile.Patch) (profile.Saved, error)
}

// LunarConverter는 음력 변환 핸들러가 쓰는 엔진 RPC입니다. *engine.Client가 만족합니다.
type LunarConverter interface {
	ConvertLunarDate(ctx context.Context, req *enginev1.LunarDateRequest) (*enginev1.LunarDateResponse, error)
}

// Readings는 운세 operation(getDaily·getCalendar·getChart)이 쓰는 화면 묶음입니다. *fortune.Views가 만족합니다.
type Readings interface {
	Daily(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (fortune.DailyView, error)
	Calendar(ctx context.Context, accountID uuid.UUID, p profile.Profile, year, month int) (fortune.CalendarView, error)
	Chart(ctx context.Context, accountID uuid.UUID, p profile.Profile) (fortune.ChartView, error)
}

var _ Readings = (*fortune.Views)(nil)

// Contents는 용어 사전(getGlossary), 문장 반응(putReaction·deleteReaction, getDaily의 반응 표시), Apple 복귀 페이지 문구가 쓰는 콘텐츠 저장소입니다.
// *content.Store가 만족합니다.
type Contents interface {
	Active(ctx context.Context) (string, error)
	Templates(ctx context.Context, version, lang string) (content.Templates, error)
	Glossary(ctx context.Context, version, lang string) (content.Glossary, error)
	SelectionFor(ctx context.Context, accountID uuid.UUID, date time.Time, slot string, birthHash [32]byte) (content.Selection, error)
	PutReaction(ctx context.Context, selectionID int64, reaction string) error
	DeleteReaction(ctx context.Context, selectionID int64) error
	ActiveReactions(ctx context.Context, selectionIDs []int64) (map[int64]string, error)
}

var _ Contents = (*content.Store)(nil)

// EntitlementService는 getMe·getEntitlements가 쓰는 권한 판정입니다. *billing.Store가 만족합니다.
type EntitlementService interface {
	Status(ctx context.Context, accountID uuid.UUID) (billing.Status, error)
}

var _ EntitlementService = (*billing.Store)(nil)

// PurchaseRestorer는 restorePurchases가 쓰는 구매 복원입니다. *billing.Syncer가 만족합니다.
type PurchaseRestorer interface {
	Restore(ctx context.Context, accountID uuid.UUID) (billing.Status, error)
}

var _ PurchaseRestorer = (*billing.Syncer)(nil)

// RewardVerifier는 admobRewardCallback이 쓰는 SSV 서명·시각 검증입니다. *billing.RewardVerifier가 만족합니다.
type RewardVerifier interface {
	// Verify는 원본 쿼리의 서명과 timestamp를 검증합니다. 오류는 billing.ErrRewardSignature·ErrRewardExpired·ErrRewardKeysUnavailable입니다.
	Verify(ctx context.Context, rawQuery string) (billing.RewardCallback, error)
}

var _ RewardVerifier = (*billing.RewardVerifier)(nil)

// RewardGranter는 검증된 보상 콜백을 기록하고 권한을 부여합니다. *billing.Rewards가 만족합니다.
type RewardGranter interface {
	Grant(ctx context.Context, cb billing.RewardCallback, rawQuery string) error
}

var _ RewardGranter = (*billing.Rewards)(nil)

// RevenueCatWebhooks는 revenuecatWebhook이 쓰는 webhook 검증·처리입니다. *billing.Webhooks가 만족합니다.
type RevenueCatWebhooks interface {
	// Authorized는 Authorization 헤더 값이 설정 값과 같은지 봅니다.
	Authorized(header string) bool
	// Handle은 이벤트를 기록하고 계정을 동기화합니다. 형식 오류는 billing.ErrWebhookInvalid입니다.
	Handle(ctx context.Context, body map[string]any) error
}

var _ RevenueCatWebhooks = (*billing.Webhooks)(nil)

// DiaryService는 일기 operation이 쓰는 서비스입니다. *diary.Service가 만족합니다.
type DiaryService interface {
	Create(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (diary.Entry, error)
	Get(ctx context.Context, accountID, id uuid.UUID) (diary.Entry, error)
	UpdateBody(ctx context.Context, accountID, id uuid.UUID, body string) (diary.Entry, error)
	Delete(ctx context.Context, accountID, id uuid.UUID) error
	Restore(ctx context.Context, accountID, id uuid.UUID) (diary.Entry, error)
	List(ctx context.Context, accountID uuid.UUID, q diary.ListQuery) ([]diary.Entry, error)
}

var _ DiaryService = (*diary.Service)(nil)

// ScheduleService는 일정 operation이 쓰는 서비스입니다. *schedule.Service가 만족합니다.
type ScheduleService interface {
	List(ctx context.Context, accountID uuid.UUID, from, to profile.LocalDate) ([]schedule.Schedule, error)
	Create(ctx context.Context, accountID uuid.UUID, in schedule.Input) (schedule.Schedule, error)
	Update(ctx context.Context, accountID, id uuid.UUID, p schedule.Patch) (schedule.Schedule, error)
	Delete(ctx context.Context, accountID, id uuid.UUID) error
	Restore(ctx context.Context, accountID, id uuid.UUID) (schedule.Schedule, error)
}

var _ ScheduleService = (*schedule.Service)(nil)

// API는 gen.StrictServerInterface 구현입니다. 아직 구현하지 않은 operation은 Unimplemented가 501로 답합니다.
type API struct {
	Unimplemented
	// testLoginHolder는 staging 테스트 로그인(S24)의 상태 자리입니다. staging 빌드에서만 필드가 있고 prod 빌드에서는 빈 struct입니다.
	testLoginHolder

	Auth     AuthService
	Accounts AccountService
	Profiles ProfileService
	Lunar    LunarConverter
	// BirthHour는 시진 확인(getBirthHour)이 쓰는 엔진입니다. 조립에서 반드시 넣습니다.
	BirthHour BirthHourChecker
	// Readings는 운세 화면 묶음입니다. 비어 있으면 운세 operation은 503 service.unavailable입니다.
	Readings Readings
	// Previews와 PreviewUsage는 비로그인 미리보기(createPreview)의 화면 묶음과 설치별 1회 기록입니다. 하나라도 비어 있으면 503 service.unavailable입니다.
	Previews     PreviewService
	PreviewUsage PreviewUsage
	// Contents는 콘텐츠 저장소입니다. 비어 있으면 getGlossary·반응 operation·getDaily는 503 service.unavailable입니다.
	Contents Contents
	// Entitlements는 권한 판정입니다. 비어 있으면 getMe·getEntitlements는 503 service.unavailable입니다.
	Entitlements EntitlementService
	// Purchases는 구매 복원입니다. 비어 있으면(결제 설정 없음) restorePurchases는 503 billing.provider_unavailable입니다(P7-16).
	Purchases PurchaseRestorer
	// Webhooks는 RevenueCat webhook 처리입니다. 비어 있으면(결제 설정 없음) revenuecatWebhook은 500이고 Error 로그를 남깁니다(P7-16).
	Webhooks RevenueCatWebhooks
	// RewardVerifier와 Rewards는 AdMob SSV 콜백의 서명 검증과 권한 부여입니다. 하나라도 비어 있으면 admobRewardCallback은 503 service.unavailable입니다.
	RewardVerifier RewardVerifier
	Rewards        RewardGranter
	// Diaries는 일기 서비스입니다. 비어 있으면 일기 operation은 503 service.unavailable입니다.
	Diaries DiaryService
	// Schedules는 일정 서비스입니다. 비어 있으면 일정 operation은 503 service.unavailable입니다.
	Schedules ScheduleService
	// DB는 헬스 체크의 ping에 씁니다.
	DB *pgxpool.Pool
	// Logger는 오류를 응답 대신 redirect로 알리는 핸들러(Apple 웹 콜백)와 결제 핸들러(webhook·구매 복원)가 원인을 남길 때 씁니다.
	Logger *slog.Logger
	// AppLink는 Apple 웹 콜백의 redirect 주소, 안내 페이지, assetlinks.json을 만드는 Android App Link 설정입니다.
	AppLink AppLinkConfig
	// AppConfig는 getAppConfig가 돌려주는 플랫폼별 최소 앱 버전입니다. 조립에서 설정 값을 넣습니다.
	AppConfig AppConfig
	// Legal은 /legal/<문서>가 내주는 이용약관·개인정보 처리방침입니다(D80). 비어 있으면 모든 문서가 준비 중(404)입니다.
	Legal legal.Documents
}

// AppConfig는 플랫폼별 최소 앱 버전(semver 문자열)입니다(P6-10).
type AppConfig struct {
	MinIOS, MinAndroid string
}

var _ gen.StrictServerInterface = (*API)(nil)

// GetHealth는 DB ping이 1초 안에 성공하면 200, 아니면 503 service.unavailable입니다.
// DB가 설정되지 않은 것도 조립 실수이므로 503으로 드러냅니다.
func (a *API) GetHealth(ctx context.Context, _ gen.GetHealthRequestObject) (gen.GetHealthResponseObject, error) {
	if a.DB == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	pingCtx, cancel := context.WithTimeout(ctx, healthPingTimeout)
	defer cancel()
	if err := a.DB.Ping(pingCtx); err != nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	return gen.GetHealth200JSONResponse{Status: gen.Ok}, nil
}
