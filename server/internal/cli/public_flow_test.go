package cli

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

const stubAppCheckValue = "valid-app-check-stub"

// fakeAppCheck는 정해진 토큰만 통과시키는 App Check 검증기 대역입니다.
type fakeAppCheck struct{}

func (fakeAppCheck) Verify(_ context.Context, token string) error {
	if token != stubAppCheckValue {
		return provider.ErrTokenInvalid
	}
	return nil
}

// fakePreviews는 엔진 없이 미리보기 화면을 돌려주는 대역입니다.
type fakePreviews struct{}

func (fakePreviews) Preview(context.Context, profile.Birth, string, string) (fortune.PreviewView, error) {
	return fortune.PreviewView{
		Response: &enginev1.DailyResponse{Day: &enginev1.Pillar{Stem: enginev1.Stem_STEM_GAP, Branch: enginev1.Branch_BRANCH_IN}, Kind: enginev1.DayKind_DAY_KIND_YONGSIN_DAY},
		Head: content.SlotText{
			Slot: fortune.SlotFortuneHead, MessageKey: "fortune.yongsin_day.inseong", Variant: "advice",
			Text: []render.Segment{{Text: "천천히 해 보세요."}},
		},
		DayKindName: "용신의 날",
		Notices:     []content.Notice{},
		Date:        profile.LocalDate{Year: 2026, Month: 10, Day: 20},
	}, nil
}

var _ httpapi.PreviewService = fakePreviews{}

// newPublicFlowEnv는 App Check·시진·미리보기 대역을 끼운 server를 띄웁니다.
func newPublicFlowEnv(t *testing.T) (*flowEnv, *enginetest.Fake) {
	t.Helper()
	engineFake := &enginetest.Fake{BirthHour: func(*enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error) {
		seoul := time.FixedZone("KST", 9*60*60)
		return &enginev1.BirthHourResponse{
			Branch: enginev1.Branch_BRANCH_JA,
			Start:  timestamppb.New(time.Date(2026, 10, 12, 23, 30, 0, 0, seoul)),
			End:    timestamppb.New(time.Date(2026, 10, 13, 1, 30, 0, 0, seoul)),
		}, nil
	}}
	env := newFlowEnvWith(t, func(deps *serverDeps) {
		deps.AppCheck = fakeAppCheck{}
		deps.BirthHour = engineFake
		deps.Lunar = engineFake
		deps.Previews = fakePreviews{}
		deps.AppConfig = httpapi.AppConfig{MinIOS: "1.2.0", MinAndroid: "1.3.0"}
	})
	return env, engineFake
}

const birthHourJSON = `{"installationId":"flow-installation","calendar":"solar","date":{"year":1990,"month":5,"day":15},"isLeapMonth":false,"time":"00:10"}`

const previewJSON = `{"installationId":"flow-installation","currentTimezone":"Asia/Seoul","birth":{"calendar":"solar",` +
	`"date":{"year":1990,"month":5,"day":17},"isLeapMonth":false,"time":{"status":"unknown"},"gender":"female",` +
	`"timezone":"Asia/Seoul","place":{"status":"not_asked"}}}`

// postPublic은 비로그인 operation에 JSON을 보냅니다. appCheck가 비어 있으면 App Check 헤더를 보내지 않습니다.
func (e *flowEnv) postPublic(path, body, appCheck string) flowResponse {
	e.t.Helper()
	req, err := http.NewRequestWithContext(e.t.Context(), http.MethodPost, e.url+path, bytes.NewReader([]byte(body)))
	require.NoError(e.t, err)
	req.Header.Set("Content-Type", "application/json")
	if appCheck != "" {
		req.Header.Set("X-Firebase-AppCheck", appCheck)
	}
	return e.send(req)
}

// 비로그인 operation은 App Check을 거치고(헤더 없으면 401), 통과하면 구현된 핸들러가 답합니다(501이 아님).
func TestPublicFlow_AppCheckGuardsAnonymousOperations(t *testing.T) {
	env, _ := newPublicFlowEnv(t)

	for _, path := range []string{"/v1/birth-hour", "/v1/lunar-date", "/v1/preview"} {
		env.postPublic(path, "{}", "").requireProblem(t, http.StatusUnauthorized, "app_check.invalid")
		env.postPublic(path, "{}", "wrong-token").requireProblem(t, http.StatusUnauthorized, "app_check.invalid")
	}

	hour := env.postPublic("/v1/birth-hour", birthHourJSON, stubAppCheckValue)
	require.Equal(t, http.StatusOK, hour.status, "시진 확인 본문: %v", hour.body)
	assert.Equal(t, "23:30", hour.body["start"])
	assert.Equal(t, "01:30", hour.body["end"])
}

func TestPublicFlow_PreviewIsOncePerInstallation(t *testing.T) {
	env, _ := newPublicFlowEnv(t)

	first := env.postPublic("/v1/preview", previewJSON, stubAppCheckValue)
	require.Equal(t, http.StatusOK, first.status, "미리보기 본문: %v", first.body)
	env.postPublic("/v1/preview", previewJSON, stubAppCheckValue).requireProblem(t, http.StatusForbidden, "preview.used")
}

func TestPublicFlow_RateLimitsBirthHourPerClient(t *testing.T) {
	env, _ := newPublicFlowEnv(t)

	for range publicRateLimit {
		require.Equal(t, http.StatusOK, env.postPublic("/v1/birth-hour", birthHourJSON, stubAppCheckValue).status)
	}
	env.postPublic("/v1/birth-hour", birthHourJSON, stubAppCheckValue).requireProblem(t, http.StatusTooManyRequests, "rate_limited")
}

// 미리보기는 installationId를 바꿔 보내도 같은 IP면 한도에 걸립니다(installationId는 한도 키로 믿을 수 없음).
func TestPublicFlow_RateLimitsPreviewPerClient(t *testing.T) {
	env, _ := newPublicFlowEnv(t)

	for i := range publicRateLimit {
		body := strings.Replace(previewJSON, "flow-installation", fmt.Sprintf("flow-installation-%d", i), 1)
		require.Equal(t, http.StatusOK, env.postPublic("/v1/preview", body, stubAppCheckValue).status)
	}
	body := strings.Replace(previewJSON, "flow-installation", "flow-installation-extra", 1)
	env.postPublic("/v1/preview", body, stubAppCheckValue).requireProblem(t, http.StatusTooManyRequests, "rate_limited")
}

// 도시 검색과 앱 설정은 인증도 App Check도 필요 없습니다.
func TestPublicFlow_ReferenceOperationsNeedNoAuth(t *testing.T) {
	env, _ := newPublicFlowEnv(t)

	cities := env.do(http.MethodGet, "/v1/cities?q=서울", "", nil)
	assert.Equal(t, http.StatusOK, cities.status, "도시 본문: %v", cities.body)

	appConfig := env.do(http.MethodGet, "/v1/app-config", "", nil)
	require.Equal(t, http.StatusOK, appConfig.status, "앱 설정 본문: %v", appConfig.body)
	assert.Equal(t, map[string]any{"ios": "1.2.0", "android": "1.3.0"}, appConfig.body["minimumVersion"])
	assert.Equal(t, map[string]any{
		"terms":   "https://app.myungli.example/legal/terms",
		"privacy": "https://app.myungli.example/legal/privacy",
	}, appConfig.body["legal"], "법적 문서는 App Link와 같은 서비스 도메인")
}

// 검증기를 조립하지 않으면(프로젝트 번호 없음) App Check operation은 503입니다.
func TestPublicFlow_WithoutAppCheckVerifierIsUnavailable(t *testing.T) {
	env := newFlowEnvWith(t, func(deps *serverDeps) { deps.BirthHour = &enginetest.Fake{} })

	env.postPublic("/v1/birth-hour", birthHourJSON, stubAppCheckValue).requireProblem(t, http.StatusServiceUnavailable, "service.unavailable")
}
