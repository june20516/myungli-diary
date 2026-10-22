package httpapi_test

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

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
