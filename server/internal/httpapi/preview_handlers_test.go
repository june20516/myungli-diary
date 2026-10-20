package httpapi_test

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/preview"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// fakePreviews는 미리보기 묶음을 미리 정해 돌려주는 PreviewService 대역입니다. 받은 인자를 기록합니다.
type fakePreviews struct {
	view fortune.PreviewView
	// errs는 호출마다 차례로 돌려줄 오류입니다. 다 쓰면 view를 돌려줍니다.
	errs []error
	// panics는 앞의 호출 몇 번을 panic으로 끝낼지입니다.
	panics int

	calls    int
	gotBirth profile.Birth
	gotZone  string
	gotLang  string
}

func (f *fakePreviews) Preview(_ context.Context, b profile.Birth, zone, lang string) (fortune.PreviewView, error) {
	f.calls++
	f.gotBirth, f.gotZone, f.gotLang = b, zone, lang
	if f.panics > 0 {
		f.panics--
		panic("미리보기 대역 panic")
	}
	if len(f.errs) > 0 {
		err := f.errs[0]
		f.errs = f.errs[1:]
		if err != nil {
			return fortune.PreviewView{}, err
		}
	}
	return f.view, nil
}

func previewView() fortune.PreviewView {
	head := text(fortune.SlotFortuneHead, "fortune.yongsin_day.inseong", "advice", "천천히 해 보세요.")
	return fortune.PreviewView{
		Response:    dailyResponse(),
		Head:        head,
		Tag:         ptr(text(fortune.SlotFortuneTag, "fortune.tag.cheoneul_gwiin", "advice", "귀인을 만나요.")),
		DayKindName: "용신의 날",
		Notices:     []content.Notice{{Code: "time_unknown", Text: []render.Segment{{Text: "태어난 시간을 몰라 낮 12시로 계산했어요."}}}},
		Date:        profile.LocalDate{Year: 2026, Month: 10, Day: 20},
	}
}

func ptr[T any](v T) *T { return &v }

func previewBody(installationID string) gen.PreviewRequest {
	return gen.PreviewRequest{
		InstallationId:  installationID,
		CurrentTimezone: "Asia/Seoul",
		Birth: gen.Birth{
			Calendar: "solar",
			Date:     gen.LunarOrSolarDate{Year: 1990, Month: 5, Day: 17},
			Gender:   "female",
			Place:    gen.BirthPlace{Status: "not_asked"},
			Time:     gen.BirthTime{Status: "unknown"},
			Timezone: "Asia/Seoul",
		},
	}
}

// postPreview는 미리보기 요청을 보내고 요청·응답을 돌려줍니다. language가 비어 있지 않으면 Accept-Language로 보냅니다.
func postPreview(t *testing.T, api *httpapi.API, body gen.PreviewRequest, language string) (*http.Request, *httptest.ResponseRecorder) {
	t.Helper()
	raw, err := json.Marshal(body)
	require.NoError(t, err)
	handler, _ := newHandlerAPI(t, api)
	req := httptest.NewRequestWithContext(t.Context(), http.MethodPost, "/v1/preview", strings.NewReader(string(raw)))
	req.Header.Set("Content-Type", "application/json")
	if language != "" {
		req.Header.Set("Accept-Language", language)
	}
	return req, serve(handler, req)
}

func newPreviewAPI(t *testing.T, previews *fakePreviews) (*httpapi.API, *preview.Usage) {
	t.Helper()
	usage := preview.NewUsage(dbtest.New(t))
	return &httpapi.API{Previews: previews, PreviewUsage: usage}, usage
}

func TestCreatePreview_ReturnsLockedPreviewMatchingContract(t *testing.T) {
	previews := &fakePreviews{view: previewView()}
	api, _ := newPreviewAPI(t, previews)

	req, rec := postPreview(t, api, previewBody("install-1"), "ja;q=0.5, ko")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	var got gen.Preview
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, "2026-10-20", got.Date.Format("2006-01-02"))
	assert.Equal(t, gen.Locked, got.EvidenceAccess)
	assert.Equal(t, gen.DayKind("yongsin_day"), got.DayKind)
	assert.Equal(t, "용신의 날", got.DayKindName)
	assert.Equal(t, "천천히 해 보세요.", got.Fortune.Head.Text.Segments[0].Text)
	assert.Equal(t, gen.SlotTextVariant("advice"), got.Fortune.Head.Variant)
	require.NotNil(t, got.Fortune.Tag)
	assert.Equal(t, []gen.Tag{
		{Key: "cheoneul_gwiin", Polarity: gen.TagPolarityGood},
		{Key: "ten_god_rush.gwanseong", Polarity: gen.TagPolarityBad},
	}, got.FeaturedTags)
	require.Len(t, got.Notices, 1)
	assert.Equal(t, gen.NoticeCode("time_unknown"), got.Notices[0].Code)
	assert.NotContains(t, rec.Body.String(), rawEvidenceRule, "판정 근거는 응답에 없음")

	assert.Equal(t, "ko", previews.gotLang, "Accept-Language q값 순서")
	assert.Equal(t, "Asia/Seoul", previews.gotZone)
	assert.Equal(t, 1990, previews.gotBirth.Date.Year)
}

func TestCreatePreview_LanguageDefaultsToEnglish(t *testing.T) {
	previews := &fakePreviews{view: previewView()}
	api, _ := newPreviewAPI(t, previews)

	_, rec := postPreview(t, api, previewBody("install-1"), "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, "en", previews.gotLang)
}

func TestCreatePreview_SecondUseIs403PreviewUsed(t *testing.T) {
	previews := &fakePreviews{view: previewView()}
	api, _ := newPreviewAPI(t, previews)

	_, first := postPreview(t, api, previewBody("install-1"), "")
	require.Equal(t, http.StatusOK, first.Code, first.Body.String())

	req, second := postPreview(t, api, previewBody("install-1"), "")
	require.Equal(t, http.StatusForbidden, second.Code, second.Body.String())
	assert.Equal(t, problem.PreviewUsed.Value, decodeProblem(t, second).Code)
	expectFortuneContract(t, req, second)
	assert.Equal(t, 1, previews.calls, "두 번째는 엔진을 부르지 않음")

	_, other := postPreview(t, api, previewBody("install-2"), "")
	assert.Equal(t, http.StatusOK, other.Code, "다른 설치는 따로")
}

func TestCreatePreview_FailureReleasesClaimSoSameInstallationCanRetry(t *testing.T) {
	previews := &fakePreviews{view: previewView(), errs: []error{engine.ErrUnavailable}}
	api, _ := newPreviewAPI(t, previews)

	_, failed := postPreview(t, api, previewBody("install-1"), "")
	require.Equal(t, http.StatusServiceUnavailable, failed.Code, failed.Body.String())

	_, retried := postPreview(t, api, previewBody("install-1"), "")
	assert.Equal(t, http.StatusOK, retried.Code, "해제되어 같은 설치가 다시 쓸 수 있음")
}

func TestCreatePreview_EngineRejectingBirthIs422AndReleasesClaim(t *testing.T) {
	previews := &fakePreviews{view: previewView(), errs: []error{engine.ErrInvalidArgument}}
	api, _ := newPreviewAPI(t, previews)

	_, rec := postPreview(t, api, previewBody("install-1"), "")

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, problem.BirthInvalid.Value, p.Code)
	assert.Equal(t, []problem.FieldError{{Field: "/birth", Code: problem.BirthInvalid.Value}}, p.Errors)

	_, retried := postPreview(t, api, previewBody("install-1"), "")
	assert.Equal(t, http.StatusOK, retried.Code)
}

func TestCreatePreview_EngineOutOfRangeIs422AndReleasesClaim(t *testing.T) {
	previews := &fakePreviews{view: previewView(), errs: []error{engine.ErrOutOfRange}}
	api, _ := newPreviewAPI(t, previews)

	_, rec := postPreview(t, api, previewBody("install-1"), "")

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, problem.BirthOutOfRange.Value, p.Code)
	assert.Equal(t, []problem.FieldError{{Field: "/birth/date", Code: problem.BirthOutOfRange.Value}}, p.Errors)

	_, retried := postPreview(t, api, previewBody("install-1"), "")
	assert.Equal(t, http.StatusOK, retried.Code)
}

// panic으로 끝나도(recoverPanic이 500으로 바꿈) 선점은 풀립니다.
func TestCreatePreview_PanicReleasesClaim(t *testing.T) {
	previews := &fakePreviews{view: previewView(), panics: 1}
	api, _ := newPreviewAPI(t, previews)

	_, rec := postPreview(t, api, previewBody("install-1"), "")
	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())

	_, retried := postPreview(t, api, previewBody("install-1"), "")
	assert.Equal(t, http.StatusOK, retried.Code)
}

func TestCreatePreview_ConversionFailureReleasesClaim(t *testing.T) {
	broken := previewView()
	broken.Head.Variant = "not-a-variant"
	previews := &fakePreviews{view: broken}
	api, _ := newPreviewAPI(t, previews)

	_, rec := postPreview(t, api, previewBody("install-1"), "")
	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())

	previews.view = previewView()
	_, retried := postPreview(t, api, previewBody("install-1"), "")
	assert.Equal(t, http.StatusOK, retried.Code)
}

func TestCreatePreview_ValidationFailureDoesNotClaim(t *testing.T) {
	tests := []struct {
		name     string
		mutate   func(*gen.PreviewRequest)
		wantCode string
		wantErr  problem.FieldError
	}{
		{
			name:     "양력 윤달",
			mutate:   func(b *gen.PreviewRequest) { b.Birth.IsLeapMonth = true },
			wantCode: problem.RequestInconsistent.Value,
			wantErr:  problem.FieldError{Field: "/birth/isLeapMonth", Code: "forbidden_by_status"},
		},
		{
			name:     "시간대 이름 오류",
			mutate:   func(b *gen.PreviewRequest) { b.CurrentTimezone = "Mars/Base" },
			wantCode: problem.TimezoneInvalid.Value,
			wantErr:  problem.FieldError{Field: "/currentTimezone", Code: problem.TimezoneInvalid.Value},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			previews := &fakePreviews{view: previewView()}
			api, usage := newPreviewAPI(t, previews)
			body := previewBody("install-1")
			tt.mutate(&body)

			_, rec := postPreview(t, api, body, "")

			require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
			p := decodeProblem(t, rec)
			assert.Equal(t, tt.wantCode, p.Code)
			assert.Equal(t, []problem.FieldError{tt.wantErr}, p.Errors)
			assert.Zero(t, previews.calls)

			claimed, err := usage.Claim(t.Context(), "install-1")
			require.NoError(t, err)
			assert.True(t, claimed, "검증 실패는 선점하지 않음")
		})
	}
}

func TestCreatePreview_UnassembledIs503(t *testing.T) {
	tests := []struct {
		name string
		api  func(t *testing.T) *httpapi.API
	}{
		{"Previews 없음", func(t *testing.T) *httpapi.API { return &httpapi.API{PreviewUsage: preview.NewUsage(dbtest.New(t))} }},
		{"PreviewUsage 없음", func(*testing.T) *httpapi.API { return &httpapi.API{Previews: &fakePreviews{}} }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, rec := postPreview(t, tt.api(t), previewBody("install-1"), "")
			require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
			assert.Equal(t, problem.ServiceUnavailable.Value, decodeProblem(t, rec).Code)
		})
	}
}

func TestCreatePreview_NoActiveSeedIs503AndReleasesClaim(t *testing.T) {
	previews := &fakePreviews{view: previewView(), errs: []error{content.ErrNoActiveSeed}}
	api, _ := newPreviewAPI(t, previews)

	_, rec := postPreview(t, api, previewBody("install-1"), "")
	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	assert.Equal(t, problem.ServiceUnavailable.Value, decodeProblem(t, rec).Code)

	_, retried := postPreview(t, api, previewBody("install-1"), "")
	assert.Equal(t, http.StatusOK, retried.Code)
}

// 요청 ctx가 취소돼도 선점은 풀립니다.
func TestCreatePreview_ReleaseSurvivesCanceledRequestContext(t *testing.T) {
	ctx, cancel := context.WithCancel(t.Context())
	previews := &fakePreviews{view: previewView(), errs: []error{errors.New("엔진 실패")}}
	api, usage := newPreviewAPI(t, previews)

	api.Previews = cancelingPreviews{inner: previews, cancel: cancel}
	_, err := api.CreatePreview(ctx, gen.CreatePreviewRequestObject{Body: ptr(previewBody("install-1"))})
	require.Error(t, err)

	claimed, err := usage.Claim(t.Context(), "install-1")
	require.NoError(t, err)
	assert.True(t, claimed)
}

// cancelingPreviews는 호출 중에 요청 ctx를 취소한 뒤 안쪽 대역의 결과를 돌려줍니다.
type cancelingPreviews struct {
	inner  *fakePreviews
	cancel context.CancelFunc
}

func (c cancelingPreviews) Preview(ctx context.Context, b profile.Birth, zone, lang string) (fortune.PreviewView, error) {
	c.cancel()
	return c.inner.Preview(ctx, b, zone, lang)
}
