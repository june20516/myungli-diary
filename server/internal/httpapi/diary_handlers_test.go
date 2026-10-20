package httpapi_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// fakeDiaries는 DiaryService 대역입니다. 받은 인자를 기록하고, 준비한 결과나 오류를 돌려줍니다.
type fakeDiaries struct {
	entry   diary.Entry
	created bool
	list    []diary.Entry
	err     error

	gotAccount uuid.UUID
	gotProfile profile.Profile
	gotDate    profile.LocalDate
	gotBody    string
	gotQuery   diary.ListQuery
	putCalls   int
}

func (f *fakeDiaries) Put(_ context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (diary.Entry, bool, error) {
	f.putCalls++
	f.gotAccount, f.gotProfile, f.gotDate, f.gotBody = accountID, p, date, body
	return f.entry, f.created, f.err
}

func (f *fakeDiaries) Get(_ context.Context, accountID uuid.UUID, date profile.LocalDate) (diary.Entry, error) {
	f.gotAccount, f.gotDate = accountID, date
	return f.entry, f.err
}

func (f *fakeDiaries) Delete(_ context.Context, accountID uuid.UUID, date profile.LocalDate) error {
	f.gotAccount, f.gotDate = accountID, date
	return f.err
}

func (f *fakeDiaries) Restore(_ context.Context, accountID uuid.UUID, date profile.LocalDate) (diary.Entry, error) {
	f.gotAccount, f.gotDate = accountID, date
	return f.entry, f.err
}

func (f *fakeDiaries) List(_ context.Context, accountID uuid.UUID, q diary.ListQuery) ([]diary.Entry, error) {
	f.gotAccount, f.gotQuery = accountID, q
	return f.list, f.err
}

func sampleEntry() diary.Entry {
	return diary.Entry{
		Date:           profile.LocalDate{Year: 2026, Month: 10, Day: 13},
		Body:           "오늘의 일기",
		AllTags:        []string{"tag.a", "tag.b"},
		Featured:       []fortune.FeaturedTag{{Key: "tag.a", Polarity: fortune.Polarity("good")}},
		GuideQuestion:  []render.Segment{{Text: "오늘은 "}, {Text: "비견", Term: "ten_god.bigyeon"}},
		RulesetVersion: "v1",
		CreatedAt:      time.Date(2026, 10, 13, 1, 0, 0, 0, time.UTC),
		UpdatedAt:      time.Date(2026, 10, 13, 2, 0, 0, 0, time.UTC),
	}
}

func diaryAPI(diaries *fakeDiaries) *httpapi.API {
	return &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Diaries: diaries}
}

const diaryTarget = "/v1/diaries/2026-10-13"

// sendDiary는 일기 요청을 보내고 요청과 응답을 돌려줍니다. body가 비어 있으면 본문 없는 요청입니다.
func sendDiary(t *testing.T, api *httpapi.API, method, target, body string) (*http.Request, *httptest.ResponseRecorder) {
	t.Helper()
	handler, _ := newHandlerAPI(t, api)
	var req *http.Request
	if body == "" {
		req = httptest.NewRequestWithContext(t.Context(), method, target, nil)
	} else {
		req = newBodyRequest(t, method, target, contentTypeJSON, body)
	}
	return req, serve(handler, req)
}

func TestPutDiary_CreatedAndUpdated(t *testing.T) {
	tests := []struct {
		name    string
		created bool
		status  int
	}{
		{"새로 만들면 201", true, http.StatusCreated},
		{"고치면 200", false, http.StatusOK},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			diaries := &fakeDiaries{entry: sampleEntry(), created: tt.created}
			req, rec := sendDiary(t, diaryAPI(diaries), http.MethodPut, diaryTarget, `{"body":"오늘의 일기"}`)

			require.Equal(t, tt.status, rec.Code, rec.Body.String())
			expectFortuneContract(t, req, rec)
			assert.Equal(t, fixedAccountID, diaries.gotAccount)
			assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 13}, diaries.gotDate)
			assert.Equal(t, "오늘의 일기", diaries.gotBody)
			assert.Equal(t, storedProfile().CurrentTimezone, diaries.gotProfile.CurrentTimezone)

			body := decodeMap(t, rec)
			assert.Equal(t, "v1", body["rulesetVersion"])
			assert.Equal(t, "2026-10-13", body["date"])
			tags, ok := body["tags"].(map[string]any)
			require.True(t, ok)
			assert.Equal(t, []any{"tag.a", "tag.b"}, tags["all"])
			assert.Equal(t, []any{map[string]any{"key": "tag.a", "polarity": "good"}}, tags["featured"])
			guide, ok := body["guideQuestion"].(map[string]any)
			require.True(t, ok)
			assert.Equal(t, []any{
				map[string]any{"text": "오늘은 "},
				map[string]any{"text": "비견", "term": "ten_god.bigyeon"},
			}, guide["segments"])
		})
	}
}

func TestPutDiary_OmitsGuideQuestionWhenEmpty(t *testing.T) {
	entry := sampleEntry()
	entry.GuideQuestion = nil
	entry.Featured = nil
	entry.AllTags = nil
	req, rec := sendDiary(t, diaryAPI(&fakeDiaries{entry: entry, created: true}), http.MethodPut, diaryTarget, `{"body":"x"}`)

	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	body := decodeMap(t, rec)
	assert.NotContains(t, body, "guideQuestion")
	assert.Equal(t, map[string]any{"all": []any{}, "featured": []any{}}, body["tags"])
}

func TestPutDiary_ProfileRequired(t *testing.T) {
	diaries := &fakeDiaries{entry: sampleEntry()}
	api := &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}, Diaries: diaries}
	req, rec := sendDiary(t, api, http.MethodPut, diaryTarget, `{"body":"x"}`)

	require.Equal(t, http.StatusConflict, rec.Code)
	assert.Equal(t, "profile.required", decodeProblem(t, rec).Code)
	expectFortuneContract(t, req, rec)
	assert.Zero(t, diaries.putCalls)
}

func TestPutDiary_Errors(t *testing.T) {
	tests := []struct {
		name   string
		err    error
		status int
		code   string
		field  string
	}{
		{"미래 날짜", diary.ErrFutureDate, http.StatusUnprocessableEntity, "diary.future_date", "date"},
		{"엔진 범위 밖", engine.ErrOutOfRange, http.StatusUnprocessableEntity, "date.out_of_range", "date"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, rec := sendDiary(t, diaryAPI(&fakeDiaries{err: tt.err}), http.MethodPut, diaryTarget, `{"body":"x"}`)

			require.Equal(t, tt.status, rec.Code, rec.Body.String())
			p := decodeProblem(t, rec)
			assert.Equal(t, tt.code, p.Code)
			assert.Equal(t, []string{tt.field}, fieldsOf(p))
			expectFortuneContract(t, req, rec)
		})
	}
}

func TestDiary_Unavailable(t *testing.T) {
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}}
	targets := []struct{ method, target, body string }{
		{http.MethodGet, diaryTarget, ""},
		{http.MethodDelete, diaryTarget, ""},
		{http.MethodPut, diaryTarget, `{"body":"x"}`},
		{http.MethodPost, diaryTarget + "/restore", ""},
		{http.MethodGet, "/v1/diaries", ""},
	}
	for _, tt := range targets {
		_, rec := sendDiary(t, api, tt.method, tt.target, tt.body)
		require.Equal(t, http.StatusServiceUnavailable, rec.Code)
		assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	}
}

func TestGetDiary(t *testing.T) {
	diaries := &fakeDiaries{entry: sampleEntry()}
	req, rec := sendDiary(t, diaryAPI(diaries), http.MethodGet, diaryTarget, "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 13}, diaries.gotDate)
	assert.Equal(t, "오늘의 일기", decodeMap(t, rec)["body"])
}

func TestGetDiary_NotFound(t *testing.T) {
	// 프로필이 없어도 조회는 프로필을 요구하지 않습니다.
	api := &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}, Diaries: &fakeDiaries{err: diary.ErrNotFound}}
	req, rec := sendDiary(t, api, http.MethodGet, diaryTarget, "")

	require.Equal(t, http.StatusNotFound, rec.Code)
	assert.Equal(t, "diary.not_found", decodeProblem(t, rec).Code)
	expectFortuneContract(t, req, rec)
}

func TestDeleteDiary(t *testing.T) {
	diaries := &fakeDiaries{}
	req, rec := sendDiary(t, diaryAPI(diaries), http.MethodDelete, diaryTarget, "")

	require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 13}, diaries.gotDate)

	req, rec = sendDiary(t, diaryAPI(&fakeDiaries{err: diary.ErrNotFound}), http.MethodDelete, diaryTarget, "")
	require.Equal(t, http.StatusNotFound, rec.Code)
	assert.Equal(t, "diary.not_found", decodeProblem(t, rec).Code)
	expectFortuneContract(t, req, rec)
}

func TestRestoreDiary(t *testing.T) {
	tests := []struct {
		name   string
		err    error
		status int
		code   string
	}{
		{"되살림", nil, http.StatusOK, ""},
		{"그날 일기가 있음", diary.ErrDateTaken, http.StatusConflict, "diary.date_taken"},
		{"지운 일기 없음", diary.ErrNotFound, http.StatusNotFound, "diary.not_found"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			diaries := &fakeDiaries{entry: sampleEntry(), err: tt.err}
			req, rec := sendDiary(t, diaryAPI(diaries), http.MethodPost, diaryTarget+"/restore", "")

			require.Equal(t, tt.status, rec.Code, rec.Body.String())
			expectFortuneContract(t, req, rec)
			assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 13}, diaries.gotDate)
			if tt.code != "" {
				assert.Equal(t, tt.code, decodeProblem(t, rec).Code)
			}
		})
	}
}

// listEntries는 날짜가 2026-10-20부터 하루씩 앞서는 일기 n개입니다.
func listEntries(n int) []diary.Entry {
	entries := make([]diary.Entry, n)
	for i := range entries {
		entries[i] = diary.Entry{
			Date: profile.LocalDate{Year: 2026, Month: 10, Day: 20 - i},
			Body: "본문",
			Featured: []fortune.FeaturedTag{
				{Key: "tag.a", Polarity: fortune.Polarity("good")},
			},
		}
	}
	return entries
}

func TestListDiaries_Pagination(t *testing.T) {
	// limit 2에 3개가 오면 다음 쪽이 있습니다.
	diaries := &fakeDiaries{list: listEntries(3)}
	req, rec := sendDiary(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?limit=2", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, 3, diaries.gotQuery.Limit)
	assert.Nil(t, diaries.gotQuery.Before)
	body := decodeMap(t, rec)
	items, ok := body["items"].([]any)
	require.True(t, ok)
	assert.Len(t, items, 2)
	cursor, ok := body["nextCursor"].(string)
	require.True(t, ok, "nextCursor가 있어야 합니다")

	// 그 cursor로 다음 쪽을 요청하면 마지막 항목 날짜가 Before입니다. 2개만 오면 마지막 쪽입니다.
	diaries.list = listEntries(3)[2:]
	req, rec = sendDiary(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?limit=2&cursor="+cursor, "")
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	require.NotNil(t, diaries.gotQuery.Before)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 19}, *diaries.gotQuery.Before)
	assert.NotContains(t, decodeMap(t, rec), "nextCursor")
}

func TestListDiaries_DefaultLimitAndFilters(t *testing.T) {
	diaries := &fakeDiaries{}
	req, rec := sendDiary(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?from=2026-10-01&to=2026-10-31&tag=tag.a", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, 31, diaries.gotQuery.Limit)
	require.NotNil(t, diaries.gotQuery.From)
	require.NotNil(t, diaries.gotQuery.To)
	require.NotNil(t, diaries.gotQuery.Tag)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 1}, *diaries.gotQuery.From)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 31}, *diaries.gotQuery.To)
	assert.Equal(t, "tag.a", *diaries.gotQuery.Tag)
	// 빈 목록도 []로 나갑니다.
	assert.Equal(t, []any{}, decodeMap(t, rec)["items"])
}

func TestListDiaries_InvalidCursor(t *testing.T) {
	for _, cursor := range []string{"not-base64!", "bm90LWEtZGF0ZQ", "MjAyNi0xMy0wMQ"} {
		diaries := &fakeDiaries{}
		_, rec := sendDiary(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?cursor="+cursor, "")

		require.Equal(t, http.StatusBadRequest, rec.Code, cursor)
		expectInvalid(t, rec, "cursor")
	}
}

func TestListDiaries_FromAfterToIsEmpty(t *testing.T) {
	diaries := &fakeDiaries{}
	req, rec := sendDiary(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?from=2026-10-31&to=2026-10-01", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, []any{}, decodeMap(t, rec)["items"])
	assert.Equal(t, 0, diaries.gotQuery.Limit, "저장소를 부르지 않습니다")
}

func TestListDiaries_Excerpt(t *testing.T) {
	long := diary.Entry{Date: profile.LocalDate{Year: 2026, Month: 10, Day: 2}, Body: strings.Repeat("가", 101)}
	// "각"을 자모 결합(ㄱ+ㅏ+ㄱ)으로 쓴 본문은 NFC로 합쳐 센 100자입니다.
	decomposed := diary.Entry{Date: profile.LocalDate{Year: 2026, Month: 10, Day: 1}, Body: strings.Repeat("각", 101)}
	short := diary.Entry{Date: profile.LocalDate{Year: 2026, Month: 9, Day: 30}, Body: "짧은 글"}
	diaries := &fakeDiaries{list: []diary.Entry{long, decomposed, short}}

	req, rec := sendDiary(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries", "")
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)

	items, ok := decodeMap(t, rec)["items"].([]any)
	require.True(t, ok)
	excerpt := func(i int) string {
		item, ok := items[i].(map[string]any)
		require.True(t, ok)
		s, ok := item["excerpt"].(string)
		require.True(t, ok)
		return s
	}
	assert.Equal(t, strings.Repeat("가", 100), excerpt(0))
	assert.Equal(t, strings.Repeat("각", 100), excerpt(1))
	assert.Equal(t, "짧은 글", excerpt(2))
}
