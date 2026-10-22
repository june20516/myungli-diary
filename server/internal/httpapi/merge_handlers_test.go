package httpapi_test

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/merge"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// fakeMerges는 합치기 서비스 대역입니다. 받은 인자를 기록하고 정해 둔 결과를 돌려줍니다.
type fakeMerges struct {
	token     string
	expiresAt time.Time
	summary   merge.Summary
	err       error

	gotAccount  uuid.UUID
	gotProvider string
	gotProof    auth.LinkProof

	executed   int
	gotToken   string
	gotProfile merge.Profile
	// afterExecute가 있으면 Execute가 성공하기 직전에 불립니다(commit 뒤 클라이언트 연결이 끊기는 경우 재현).
	afterExecute func()
}

func (f *fakeMerges) Execute(_ context.Context, accountID uuid.UUID, token string, chosen merge.Profile) error {
	f.executed++
	if f.afterExecute != nil {
		f.afterExecute()
	}
	f.gotAccount, f.gotToken, f.gotProfile = accountID, token, chosen
	return f.err
}

func (f *fakeMerges) Preview(_ context.Context, accountID uuid.UUID, providerName string, proof auth.LinkProof) (string, time.Time, merge.Summary, error) {
	f.gotAccount, f.gotProvider, f.gotProof = accountID, providerName, proof
	return f.token, f.expiresAt, f.summary, f.err
}

const previewMergeBody = `{"provider":"line","idToken":"id","nonce":"0123456789abcdef"}`

func TestPreviewMerge_Handler(t *testing.T) {
	expiresAt := time.Date(2026, 10, 23, 9, 10, 0, 0, time.UTC)
	fm := &fakeMerges{
		token:     strings.Repeat("t", 43),
		expiresAt: expiresAt,
		summary: merge.Summary{
			Diaries: 3, Schedules: 2, DateRecords: 1, Reactions: 1, OverlapDays: 1,
			AddedDays: map[billing.Entitlement]int{billing.AdFree: 12, billing.Insight: 12},
			Current:   merge.ProfileSummary{},
			Other: merge.ProfileSummary{Saved: true, Honorific: "벗", Birth: profile.Birth{
				Calendar: profile.CalendarSolar, Date: profile.LocalDate{Year: 1990, Month: 3, Day: 14},
				TimeStatus: profile.TimeKnown, Time: &profile.LocalTime{Hour: 7, Minute: 5}, Gender: "female",
				Timezone: "Asia/Seoul", PlaceStatus: profile.PlaceCity, CityID: "seoul",
			}},
		},
	}
	handler, spec := newHandlerAPI(t, &httpapi.API{Merges: fm})

	req := postJSON(t, "/v1/me/merge/preview", previewMergeBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.Equal(t, fixedAccountID, fm.gotAccount)
	assert.Equal(t, "line", fm.gotProvider)
	assert.Equal(t, auth.LinkProof{IDToken: "id", RawNonce: "0123456789abcdef"}, fm.gotProof)

	var got gen.MergePreview
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, strings.Repeat("t", 43), got.MergeToken)
	assert.True(t, got.ExpiresAt.Equal(expiresAt))
	s := got.Summary
	assert.Equal(t, []int{3, 2, 1, 1, 1}, []int{s.Diaries, s.Schedules, s.DateRecords, s.Reactions, s.OverlapDays})
	assert.Equal(t, 12, s.AddedDays.AdFree)
	assert.Equal(t, gen.MergeProfileSummaryStatus("none"), s.Current.Status)
	assert.Nil(t, s.Current.Honorific)
	assert.Nil(t, s.Current.Birth)
	assert.Equal(t, gen.MergeProfileSummaryStatus("saved"), s.Other.Status)
	require.NotNil(t, s.Other.Honorific)
	assert.Equal(t, "벗", *s.Other.Honorific)
	require.NotNil(t, s.Other.Birth)
	assert.Equal(t, gen.LunarOrSolarDate{Year: 1990, Month: 3, Day: 14}, s.Other.Birth.Date)
	require.NotNil(t, s.Other.Birth.Time.Value)
	assert.Equal(t, "07:05", *s.Other.Birth.Time.Value)
	require.NotNil(t, s.Other.Birth.Place.CityId)
	assert.Equal(t, "seoul", *s.Other.Birth.Place.CityId)
}

// 남은 기간 상품이 없으면 addedDays.adFree는 0입니다.
func TestPreviewMerge_NoRemainingDaysIsZero(t *testing.T) {
	handler, spec := newHandlerAPI(t, &httpapi.API{Merges: &fakeMerges{token: strings.Repeat("t", 43), expiresAt: time.Now()}})

	req := postJSON(t, "/v1/me/merge/preview", previewMergeBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	var got gen.MergePreview
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Zero(t, got.Summary.AddedDays.AdFree)
	assert.Equal(t, gen.MergeProfileSummaryStatus("none"), got.Summary.Other.Status)
}

func TestPreviewMerge_Errors(t *testing.T) {
	cases := []struct {
		name   string
		err    error
		status int
		code   string
	}{
		{"같은 계정", merge.ErrSameAccount, http.StatusUnprocessableEntity, "merge.same_account"},
		{"계정 없음", merge.ErrNoAccount, http.StatusUnprocessableEntity, "merge.no_account"},
		{"증명 오류", auth.ErrProviderTokenInvalid, http.StatusUnauthorized, "auth.provider_token_invalid"},
		{"교환 코드 오류", auth.ErrExchangeInvalid, http.StatusUnauthorized, "auth.exchange_invalid"},
		{"증명 조합 오류", &auth.InvalidProofError{Field: "/idToken", Code: "required"}, http.StatusBadRequest, "request.invalid"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			handler, spec := newHandlerAPI(t, &httpapi.API{Merges: &fakeMerges{err: tc.err}})

			req := postJSON(t, "/v1/me/merge/preview", previewMergeBody)
			rec := serve(handler, req)

			require.Equal(t, tc.status, rec.Code, rec.Body.String())
			assert.Equal(t, tc.code, decodeProblem(t, rec).Code)
			assert.Empty(t, rec.Header().Get("WWW-Authenticate"), "현재 세션은 유효합니다")
			expectContractResponse(t, spec, req, rec)
		})
	}
}

func TestPreviewMerge_Unconfigured_503(t *testing.T) {
	handler, _ := newHandlerAPI(t, &httpapi.API{})

	rec := serve(handler, postJSON(t, "/v1/me/merge/preview", previewMergeBody))

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
}

const mergeAccountsBody = `{"mergeToken":"merge-token","profile":"other"}`

// mergeAPI는 합치기 실행 뒤 A의 Me를 만들 수 있는 API입니다.
func mergeAPI(fm *fakeMerges) *httpapi.API {
	api := meAPI(fakeEntitlements{})
	api.Merges = fm
	return api
}

func TestMergeAccounts_Handler(t *testing.T) {
	fm := &fakeMerges{}
	api := mergeAPI(fm)
	api.Profiles = &fakeProfiles{exists: true}
	handler, spec := newHandlerAPI(t, api)

	req := postJSON(t, "/v1/me/merge", mergeAccountsBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, req, rec)
	assert.Equal(t, fixedAccountID, fm.gotAccount)
	assert.Equal(t, "merge-token", fm.gotToken)
	assert.Equal(t, merge.ProfileOther, fm.gotProfile)
	var got gen.Me
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, fixedAccountID, got.AccountId, "남는 계정 A의 Me입니다")
	assert.True(t, got.HasProfile)
	assert.False(t, got.AdFree.Active)
}

func TestMergeAccounts_TokenInvalid(t *testing.T) {
	handler, spec := newHandlerAPI(t, mergeAPI(&fakeMerges{err: merge.ErrTokenInvalid}))

	req := postJSON(t, "/v1/me/merge", mergeAccountsBody)
	rec := serve(handler, req)

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	assert.Equal(t, "merge.token_invalid", decodeProblem(t, rec).Code)
	assert.Empty(t, rec.Header().Get("WWW-Authenticate"), "현재 세션은 유효합니다")
	expectContractResponse(t, spec, req, rec)
}

// 합치기 서비스나 Me를 만들 권한 판정이 없으면 합치기 전에 503입니다.
func TestMergeAccounts_Unconfigured_503(t *testing.T) {
	fm := &fakeMerges{}
	cases := map[string]*httpapi.API{
		"합치기 없음":   {Accounts: &fakeAccounts{me: account.Me{AccountID: fixedAccountID}}, Profiles: &fakeProfiles{}, Entitlements: fakeEntitlements{}},
		"권한 판정 없음": {Merges: fm, Accounts: &fakeAccounts{}, Profiles: &fakeProfiles{}},
	}
	for name, api := range cases {
		t.Run(name, func(t *testing.T) {
			handler, _ := newHandlerAPI(t, api)

			rec := serve(handler, postJSON(t, "/v1/me/merge", mergeAccountsBody))

			require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
			assert.Equal(t, "service.unavailable", decodeProblem(t, rec).Code)
		})
	}
	assert.Zero(t, fm.executed, "합치지 않습니다")
}

// flakyAccounts는 Me가 처음 failures번 실패하고 그 뒤 성공하는 AccountService 대역입니다.
type flakyAccounts struct {
	fakeAccounts
	failures int
	calls    int
}

func (f *flakyAccounts) Me(ctx context.Context, id uuid.UUID) (account.Me, error) {
	f.calls++
	if f.calls <= f.failures {
		return account.Me{}, errors.New("db blip")
	}
	return f.fakeAccounts.Me(ctx, id)
}

// 합친 뒤 Me 읽기가 한 번 실패하면 다시 읽어 200이고, 두 번 실패하면 500입니다. 합치기는 한 번만 합니다.
func TestMergeAccounts_RetriesMeOnce(t *testing.T) {
	for _, tc := range []struct {
		failures, status int
	}{{1, http.StatusOK}, {2, http.StatusInternalServerError}} {
		fm := &fakeMerges{}
		accounts := &flakyAccounts{fakeAccounts: fakeAccounts{me: account.Me{AccountID: fixedAccountID}}, failures: tc.failures}
		api := mergeAPI(fm)
		api.Accounts = accounts
		handler, _ := newHandlerAPI(t, api)

		rec := serve(handler, postJSON(t, "/v1/me/merge", mergeAccountsBody))

		assert.Equal(t, tc.status, rec.Code, "실패 %d번: %s", tc.failures, rec.Body.String())
		assert.Equal(t, 1, fm.executed)
		assert.Equal(t, 2, accounts.calls)
	}
}

// ctxAccounts는 받은 ctx가 취소됐으면 그 오류로 실패하는 AccountService 대역입니다(DB 조회처럼).
type ctxAccounts struct {
	fakeAccounts
}

func (f *ctxAccounts) Me(ctx context.Context, id uuid.UUID) (account.Me, error) {
	if err := ctx.Err(); err != nil {
		return account.Me{}, err
	}
	return f.fakeAccounts.Me(ctx, id)
}

// 합치기가 commit된 뒤 클라이언트가 연결을 끊어 요청 ctx가 취소돼도 Me를 읽어 200으로 끝냅니다.
// 그래야 멱등 미들웨어가 응답을 저장해 같은 키 재전송이 422가 아니라 저장 응답이 됩니다(Review Focus 5).
func TestMergeAccounts_CanceledAfterCommitStillAnswersMe(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	fm := &fakeMerges{afterExecute: cancel}
	api := mergeAPI(fm)
	api.Accounts = &ctxAccounts{fakeAccounts: fakeAccounts{me: account.Me{AccountID: fixedAccountID}}}
	handler, _ := newHandlerAPI(t, api)

	rec := serve(handler, postJSON(t, "/v1/me/merge", mergeAccountsBody).WithContext(ctx))

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	var got gen.Me
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, fixedAccountID, got.AccountId)
}
