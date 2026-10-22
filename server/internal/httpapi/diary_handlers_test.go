package httpapi_test

import (
	"context"
	"encoding/base64"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// fakeDiaries는 DiaryService 대역입니다. 받은 인자를 기록하고, 준비한 결과나 오류를 돌려줍니다.
type fakeDiaries struct {
	mu    sync.Mutex
	entry diary.Entry
	list  []diary.Entry
	err   error

	gotAccount   uuid.UUID
	gotID        uuid.UUID
	gotProfile   profile.Profile
	gotDate      profile.LocalDate
	gotBody      string
	gotQuery     diary.ListQuery
	createCalls  int
	listCalls    int
	deleteCalled bool
}

func (f *fakeDiaries) Create(_ context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (diary.Entry, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.createCalls++
	f.gotAccount, f.gotProfile, f.gotDate, f.gotBody = accountID, p, date, body
	return f.entry, f.err
}

func (f *fakeDiaries) Get(_ context.Context, accountID, id uuid.UUID) (diary.Entry, error) {
	f.gotAccount, f.gotID = accountID, id
	return f.entry, f.err
}

func (f *fakeDiaries) UpdateBody(_ context.Context, accountID, id uuid.UUID, body string) (diary.Entry, error) {
	f.gotAccount, f.gotID, f.gotBody = accountID, id, body
	updated := f.entry
	if f.err == nil {
		updated.Body = body
	}
	return updated, f.err
}

func (f *fakeDiaries) Delete(_ context.Context, accountID, id uuid.UUID) error {
	f.gotAccount, f.gotID, f.deleteCalled = accountID, id, true
	return f.err
}

func (f *fakeDiaries) Restore(_ context.Context, accountID, id uuid.UUID) (diary.Entry, error) {
	f.gotAccount, f.gotID = accountID, id
	return f.entry, f.err
}

func (f *fakeDiaries) List(_ context.Context, accountID uuid.UUID, q diary.ListQuery) ([]diary.Entry, error) {
	f.listCalls++
	f.gotAccount, f.gotQuery = accountID, q
	return f.list, f.err
}

var sampleDiaryID = uuid.MustParse("0198a000-0000-7000-8000-0000000000d1")

func sampleEntry() diary.Entry {
	return diary.Entry{
		ID:             sampleDiaryID,
		Date:           profile.LocalDate{Year: 2026, Month: 10, Day: 13},
		Body:           "오늘의 일기",
		AllTags:        []string{"tag.a", "tag.b"},
		Featured:       []fortune.FeaturedTag{{Key: "tag.a", Polarity: fortune.Polarity("good")}},
		GuideQuestion:  []render.Segment{{Text: "오늘은 "}, {Text: "비견", Term: "ten_god.bigyeon"}},
		RulesetVersion: "v1",
		CreatedAt:      time.Date(2026, 10, 13, 1, 0, 0, 123456000, time.UTC),
		UpdatedAt:      time.Date(2026, 10, 13, 2, 0, 0, 0, time.UTC),
	}
}

func diaryAPI(diaries *fakeDiaries) *httpapi.API {
	return &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Diaries: diaries}
}

const (
	diariesTarget = "/v1/diaries"
	diaryTarget   = "/v1/diaries/0198a000-0000-7000-8000-0000000000d1"
	createDiaryJS = `{"date":"2026-10-13","body":"오늘의 일기"}`
)

func base64URL(s string) string { return base64.RawURLEncoding.EncodeToString([]byte(s)) }

func TestCreateDiary_Returns201WithLocation(t *testing.T) {
	diaries := &fakeDiaries{entry: sampleEntry()}
	req, rec := sendRequest(t, diaryAPI(diaries), http.MethodPost, diariesTarget, createDiaryJS)

	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, "/v1/diaries/"+sampleDiaryID.String(), rec.Header().Get("Location"))
	assert.Equal(t, fixedAccountID, diaries.gotAccount)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 13}, diaries.gotDate)
	assert.Equal(t, "오늘의 일기", diaries.gotBody)
	assert.Equal(t, storedProfile().CurrentTimezone, diaries.gotProfile.CurrentTimezone)

	body := decodeMap(t, rec)
	assert.Equal(t, sampleDiaryID.String(), body["id"])
	assert.Equal(t, "2026-10-13", body["date"])
	assert.Equal(t, "v1", body["rulesetVersion"])
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
}

func TestCreateDiary_OmitsGuideQuestionWhenEmpty(t *testing.T) {
	entry := sampleEntry()
	entry.GuideQuestion, entry.Featured, entry.AllTags = nil, nil, nil
	req, rec := sendRequest(t, diaryAPI(&fakeDiaries{entry: entry}), http.MethodPost, diariesTarget, createDiaryJS)

	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	body := decodeMap(t, rec)
	assert.NotContains(t, body, "guideQuestion")
	assert.Equal(t, map[string]any{"all": []any{}, "featured": []any{}}, body["tags"])
}

func TestCreateDiary_Errors(t *testing.T) {
	tests := []struct {
		name   string
		err    error
		status int
		code   string
	}{
		{"그날 10편", diary.ErrDayFull, http.StatusUnprocessableEntity, "diary.day_full"},
		{"미래 날짜", diary.ErrFutureDate, http.StatusUnprocessableEntity, "diary.future_date"},
		{"엔진 범위 밖", engine.ErrOutOfRange, http.StatusUnprocessableEntity, "date.out_of_range"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, rec := sendRequest(t, diaryAPI(&fakeDiaries{err: tt.err}), http.MethodPost, diariesTarget, createDiaryJS)

			require.Equal(t, tt.status, rec.Code, rec.Body.String())
			p := decodeProblem(t, rec)
			assert.Equal(t, tt.code, p.Code)
			assert.Equal(t, []string{"date"}, fieldsOf(p))
			expectFortuneContract(t, req, rec)
		})
	}
}

func TestCreateDiary_DayFullIs422(t *testing.T) {
	_, rec := sendRequest(t, diaryAPI(&fakeDiaries{err: diary.ErrDayFull}), http.MethodPost, diariesTarget, createDiaryJS)
	require.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	assert.Equal(t, "diary.day_full", decodeProblem(t, rec).Code)
}

func TestCreateDiary_WithoutProfileIs409(t *testing.T) {
	diaries := &fakeDiaries{entry: sampleEntry()}
	api := &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}, Diaries: diaries}
	req, rec := sendRequest(t, api, http.MethodPost, diariesTarget, createDiaryJS)

	require.Equal(t, http.StatusConflict, rec.Code)
	assert.Equal(t, "profile.required", decodeProblem(t, rec).Code)
	expectFortuneContract(t, req, rec)
	assert.Zero(t, diaries.createCalls)
}

func TestCreateDiary_IdempotentReplay(t *testing.T) {
	pool := dbtest.New(t)
	var accountID uuid.UUID
	require.NoError(t, pool.QueryRow(t.Context(),
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&accountID))
	clk := clocktest.New(time.Date(2026, 10, 20, 0, 0, 0, 0, time.UTC))

	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, _ := newTestDeps()
	diaries := &fakeDiaries{entry: sampleEntry()}
	api := diaryAPI(diaries)
	api.Logger, api.AppLink = deps.Logger, testAppLink(t)
	routes := httpapi.Routes{
		Spec:     spec,
		Validate: httpapi.ValidateRequests(spec, deps.Logger),
		Authenticate: func(_ httpapi.Operation, next http.Handler) http.Handler {
			return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				ctx := httpapi.WithAccount(r.Context(), accountID, account.Access{Status: account.StatusActive})
				next.ServeHTTP(w, r.WithContext(ctx))
			})
		},
		Idempotency: httpapi.Idempotency(httpapi.NewPgIdempotencyStore(pool), clk, deps.Logger, "createDiary"),
	}
	handler := httpapi.NewHandler(deps, func(mux *http.ServeMux) { httpapi.RegisterAPI(mux, api, deps, routes) })

	send := func() (int, string, string) {
		req := newBodyRequest(t, http.MethodPost, diariesTarget, contentTypeJSON, createDiaryJS)
		req.Header.Set("Idempotency-Key", "diary-key-0001")
		rec := serve(handler, req)
		return rec.Code, rec.Header().Get("Location"), rec.Body.String()
	}
	status1, location1, body1 := send()
	status2, location2, body2 := send()

	require.Equal(t, http.StatusCreated, status1, body1)
	assert.Equal(t, status1, status2)
	assert.Equal(t, location1, location2)
	assert.JSONEq(t, body1, body2)
	assert.Equal(t, 1, diaries.createCalls)
}

func TestUpdateDiary_ReturnsDiary(t *testing.T) {
	diaries := &fakeDiaries{entry: sampleEntry()}
	req, rec := sendRequest(t, diaryAPI(diaries), http.MethodPut, diaryTarget, `{"body":"고친 일기"}`)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, sampleDiaryID, diaries.gotID)
	assert.Equal(t, "고친 일기", decodeMap(t, rec)["body"])
}

func TestGetDiary_ReturnsDiary(t *testing.T) {
	diaries := &fakeDiaries{entry: sampleEntry()}
	req, rec := sendRequest(t, diaryAPI(diaries), http.MethodGet, diaryTarget, "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, sampleDiaryID, diaries.gotID)
	assert.Equal(t, sampleDiaryID.String(), decodeMap(t, rec)["id"])
}

func TestGetDiary_NotFoundIs404(t *testing.T) {
	// 프로필이 없어도 조회는 프로필을 요구하지 않습니다.
	api := &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}, Diaries: &fakeDiaries{err: diary.ErrNotFound}}
	req, rec := sendRequest(t, api, http.MethodGet, diaryTarget, "")

	require.Equal(t, http.StatusNotFound, rec.Code)
	assert.Equal(t, "diary.not_found", decodeProblem(t, rec).Code)
	expectFortuneContract(t, req, rec)
}

func TestDeleteDiary_Returns204(t *testing.T) {
	diaries := &fakeDiaries{}
	req, rec := sendRequest(t, diaryAPI(diaries), http.MethodDelete, diaryTarget, "")

	require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.True(t, diaries.deleteCalled)
	assert.Equal(t, sampleDiaryID, diaries.gotID)

	_, rec = sendRequest(t, diaryAPI(&fakeDiaries{err: diary.ErrNotFound}), http.MethodDelete, diaryTarget, "")
	require.Equal(t, http.StatusNotFound, rec.Code)
	assert.Equal(t, "diary.not_found", decodeProblem(t, rec).Code)
}

func TestRestoreDiary_Returns200(t *testing.T) {
	diaries := &fakeDiaries{entry: sampleEntry()}
	req, rec := sendRequest(t, diaryAPI(diaries), http.MethodPost, diaryTarget+"/restore", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, sampleDiaryID, diaries.gotID)
}

func TestRestoreDiary_DayFullIs422(t *testing.T) {
	req, rec := sendRequest(t, diaryAPI(&fakeDiaries{err: diary.ErrDayFull}), http.MethodPost, diaryTarget+"/restore", "")

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "diary.day_full", p.Code)
	assert.Equal(t, []string{"date"}, fieldsOf(p))
	expectFortuneContract(t, req, rec)
}

func TestDiary_Unavailable(t *testing.T) {
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}}
	targets := []struct{ method, target, body string }{
		{http.MethodGet, diaryTarget, ""},
		{http.MethodDelete, diaryTarget, ""},
		{http.MethodPut, diaryTarget, `{"body":"x"}`},
		{http.MethodPost, diaryTarget + "/restore", ""},
		{http.MethodPost, diariesTarget, createDiaryJS},
		{http.MethodGet, diariesTarget, ""},
	}
	for _, tt := range targets {
		_, rec := sendRequest(t, api, tt.method, tt.target, tt.body)
		require.Equal(t, http.StatusServiceUnavailable, rec.Code, tt.method+" "+tt.target)
		assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
	}
}

// listEntries는 날짜가 2026-10-20부터 하루씩 앞서는 일기 n개입니다.
func listEntries(n int) []diary.Entry {
	entries := make([]diary.Entry, n)
	for i := range entries {
		entries[i] = diary.Entry{
			ID:        uuid.MustParse("0198a000-0000-7000-8000-00000000010" + string(rune('0'+i))),
			Date:      profile.LocalDate{Year: 2026, Month: 10, Day: 20 - i},
			Body:      "본문",
			Featured:  []fortune.FeaturedTag{{Key: "tag.a", Polarity: fortune.Polarity("good")}},
			CreatedAt: time.Date(2026, 10, 20-i, 1, 2, 3, 456789000, time.UTC),
		}
	}
	return entries
}

func TestListDiaries_CursorRoundTrip(t *testing.T) {
	// limit 2에 3개가 오면 다음 쪽이 있고, cursor는 쪽의 마지막 항목입니다.
	all := listEntries(3)
	diaries := &fakeDiaries{list: all}
	req, rec := sendRequest(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?limit=2", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, 3, diaries.gotQuery.Limit)
	assert.Nil(t, diaries.gotQuery.After)
	body := decodeMap(t, rec)
	items, ok := body["items"].([]any)
	require.True(t, ok)
	assert.Len(t, items, 2)
	cursor, ok := body["nextCursor"].(string)
	require.True(t, ok, "nextCursor가 있어야 합니다")

	decoded, err := httpapi.DecodeDiaryCursorForTest(cursor)
	require.NoError(t, err)
	assert.Equal(t, diary.Cursor{Date: all[1].Date, CreatedAt: all[1].CreatedAt, ID: all[1].ID}, decoded)
	assert.True(t, decoded.CreatedAt.Equal(all[1].CreatedAt), "마이크로초 정밀도를 잃지 않아야 합니다")

	// 그 cursor로 다음 쪽을 요청하면 서비스가 같은 위치를 받습니다. 1개만 오면 마지막 쪽입니다.
	diaries.list = all[2:]
	_, rec = sendRequest(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?limit=2&cursor="+cursor, "")
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	require.NotNil(t, diaries.gotQuery.After)
	assert.Equal(t, decoded, *diaries.gotQuery.After)
	assert.NotContains(t, decodeMap(t, rec), "nextCursor")
}

func TestListDiaries_OldDateCursorIs400(t *testing.T) {
	diaries := &fakeDiaries{}
	_, rec := sendRequest(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?cursor="+base64URL("2026-10-12"), "")

	require.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())
	expectInvalid(t, rec, "cursor")
	assert.Zero(t, diaries.listCalls)
}

func TestListDiaries_BadCursorIs400(t *testing.T) {
	const goodTime, goodID = "2026-10-13T01:00:00Z", "0198a000-0000-7000-8000-0000000000d1"
	cursors := []string{
		"!!!",
		base64URL("{}"),
		base64URL(`{"d":"2026-02-30","c":"` + goodTime + `","i":"` + goodID + `"}`),
		base64URL(`{"d":"2026-10-13","c":"어제","i":"` + goodID + `"}`),
		base64URL(`{"d":"2026-10-13","c":"` + goodTime + `","i":"id"}`),
		base64URL(`{"d":"2026-10-13","c":"` + goodTime + `"}`),
		base64URL("not json"),
	}
	for _, cursor := range cursors {
		diaries := &fakeDiaries{}
		_, rec := sendRequest(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?cursor="+cursor, "")

		require.Equal(t, http.StatusBadRequest, rec.Code, cursor)
		expectInvalid(t, rec, "cursor")
		assert.Zero(t, diaries.listCalls)
	}
}

func TestListDiaries_SummaryHasIDAndCreatedAt(t *testing.T) {
	entries := listEntries(1)
	req, rec := sendRequest(t, diaryAPI(&fakeDiaries{list: entries}), http.MethodGet, diariesTarget, "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	item, ok := decodeMap(t, rec)["items"].([]any)[0].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, entries[0].ID.String(), item["id"])
	assert.Equal(t, "2026-10-20T01:02:03.456789Z", item["createdAt"])
}

func TestListDiaries_DefaultLimitAndFilters(t *testing.T) {
	diaries := &fakeDiaries{}
	req, rec := sendRequest(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?from=2026-10-01&to=2026-10-31&tag=tag.a", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, 31, diaries.gotQuery.Limit)
	require.NotNil(t, diaries.gotQuery.From)
	require.NotNil(t, diaries.gotQuery.To)
	require.NotNil(t, diaries.gotQuery.Tag)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 1}, *diaries.gotQuery.From)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 31}, *diaries.gotQuery.To)
	assert.Equal(t, "tag.a", *diaries.gotQuery.Tag)
	assert.Equal(t, []any{}, decodeMap(t, rec)["items"])
}

func TestListDiaries_FromAfterToIsEmpty(t *testing.T) {
	diaries := &fakeDiaries{}
	req, rec := sendRequest(t, diaryAPI(diaries), http.MethodGet, "/v1/diaries?from=2026-10-31&to=2026-10-01", "")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, []any{}, decodeMap(t, rec)["items"])
	assert.Zero(t, diaries.listCalls, "저장소를 부르지 않습니다")
}

func TestListDiaries_Excerpt(t *testing.T) {
	long := diary.Entry{Date: profile.LocalDate{Year: 2026, Month: 10, Day: 2}, Body: strings.Repeat("가", 101)}
	// "각"을 자모 결합(ㄱ+ㅏ+ㄱ)으로 쓴 본문은 NFC로 합쳐 센 100자입니다.
	decomposed := diary.Entry{Date: profile.LocalDate{Year: 2026, Month: 10, Day: 1}, Body: strings.Repeat("각", 101)}
	short := diary.Entry{Date: profile.LocalDate{Year: 2026, Month: 9, Day: 30}, Body: "짧은 글"}
	diaries := &fakeDiaries{list: []diary.Entry{long, decomposed, short}}

	req, rec := sendRequest(t, diaryAPI(diaries), http.MethodGet, diariesTarget, "")
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
