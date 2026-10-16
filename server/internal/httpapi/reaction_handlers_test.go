package httpapi_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// selectionQuery는 fakeContents.SelectionFor가 받은 인자입니다.
type selectionQuery struct {
	accountID uuid.UUID
	date      time.Time
	slot      string
	birthHash [32]byte
}

// fakeContents는 Contents 대역입니다. 반응은 메모리 맵에 두고, 받은 인자를 기록합니다.
type fakeContents struct {
	active   string
	glossary content.Glossary
	// selections는 슬롯 id -> 선택 기록입니다. 없으면 ErrSelectionNotFound입니다.
	selections map[string]content.Selection
	reactions  map[int64]string

	gotGlossaryLang  string
	glossaryCalls    int
	gotSelection     []selectionQuery
	activeCalls      int
	gotActiveIDs     []int64
	putCalls, delete int
}

func (f *fakeContents) Active(context.Context) (string, error) { return f.active, nil }

func (f *fakeContents) Glossary(_ context.Context, version, lang string) (content.Glossary, error) {
	f.glossaryCalls++
	f.gotGlossaryLang = lang
	g := f.glossary
	g.SeedVersion, g.Lang = version, lang
	return g, nil
}

func (f *fakeContents) SelectionFor(_ context.Context, accountID uuid.UUID, date time.Time, slot string, birthHash [32]byte) (content.Selection, error) {
	f.gotSelection = append(f.gotSelection, selectionQuery{accountID, date, slot, birthHash})
	sel, ok := f.selections[slot]
	if !ok {
		return content.Selection{}, content.ErrSelectionNotFound
	}
	return sel, nil
}

func (f *fakeContents) PutReaction(_ context.Context, selectionID int64, reaction string) error {
	f.putCalls++
	if f.reactions == nil {
		f.reactions = map[int64]string{}
	}
	f.reactions[selectionID] = reaction
	return nil
}

func (f *fakeContents) DeleteReaction(_ context.Context, selectionID int64) error {
	f.delete++
	delete(f.reactions, selectionID)
	return nil
}

func (f *fakeContents) ActiveReactions(_ context.Context, selectionIDs []int64) (map[int64]string, error) {
	f.activeCalls++
	f.gotActiveIDs = selectionIDs
	out := map[int64]string{}
	for _, id := range selectionIDs {
		if r, ok := f.reactions[id]; ok {
			out[id] = r
		}
	}
	return out, nil
}

const reactionTarget = "/v1/daily/2026-10-13/slots/daily.fortune.head/reaction"

// sendReaction은 반응 요청(put이면 like)을 보내고 요청과 응답을 돌려줍니다.
func sendReaction(t *testing.T, api *httpapi.API, method, target string) (*http.Request, *httptest.ResponseRecorder) {
	t.Helper()
	handler, _ := newHandlerAPI(t, api)
	var req *http.Request
	if method == http.MethodPut {
		req = newBodyRequest(t, method, target, contentTypeJSON, `{"reaction":"like"}`)
	} else {
		req = httptest.NewRequestWithContext(t.Context(), method, target, nil)
	}
	return req, serve(handler, req)
}

func reactionAPI(contents *fakeContents) *httpapi.API {
	return &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Contents: contents}
}

func TestPutReaction_IsIdempotent(t *testing.T) {
	contents := &fakeContents{selections: map[string]content.Selection{fortune.SlotFortuneHead: {ID: 7, Slot: fortune.SlotFortuneHead}}}
	api := reactionAPI(contents)

	for range 2 {
		req, rec := sendReaction(t, api, http.MethodPut, reactionTarget)
		require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
		expectFortuneContract(t, req, rec)
	}
	assert.Equal(t, map[int64]string{7: "like"}, contents.reactions)

	// 오늘 기록은 그 날짜·슬롯·현재 프로필 지문으로 찾습니다.
	require.NotEmpty(t, contents.gotSelection)
	got := contents.gotSelection[0]
	assert.Equal(t, fixedAccountID, got.accountID)
	assert.Equal(t, "2026-10-13", got.date.Format(time.DateOnly))
	assert.Equal(t, fortune.SlotFortuneHead, got.slot)
	assert.Equal(t, profile.BirthHash(storedProfile().Birth), got.birthHash)
}

func TestDeleteReaction_SoftDeletes(t *testing.T) {
	contents := &fakeContents{
		selections: map[string]content.Selection{fortune.SlotFortuneHead: {ID: 7, Slot: fortune.SlotFortuneHead}},
		reactions:  map[int64]string{7: "like"},
	}
	api := reactionAPI(contents)

	for range 2 {
		req, rec := sendReaction(t, api, http.MethodDelete, reactionTarget)
		require.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
		expectFortuneContract(t, req, rec)
	}
	assert.Equal(t, 2, contents.delete, "반응이 없어도 지우기는 성공(멱등)")
	assert.Empty(t, contents.reactions)
}

func TestPutReaction_NoSelectionIs404(t *testing.T) {
	for _, method := range []string{http.MethodPut, http.MethodDelete} {
		t.Run(method, func(t *testing.T) {
			contents := &fakeContents{}
			req, rec := sendReaction(t, reactionAPI(contents), method, reactionTarget)

			require.Equal(t, http.StatusNotFound, rec.Code, rec.Body.String())
			assert.Equal(t, "reaction.not_found", decodeProblem(t, rec).Code)
			expectFortuneContract(t, req, rec)
			assert.Zero(t, contents.putCalls+contents.delete)
		})
	}
}

func TestPutReaction_NonReactableSlotIs404(t *testing.T) {
	for _, method := range []string{http.MethodPut, http.MethodDelete} {
		t.Run(method, func(t *testing.T) {
			// 선택 기록이 있어도 반응할 수 없는 슬롯이면 404입니다.
			contents := &fakeContents{selections: map[string]content.Selection{fortune.SlotGuide: {ID: 9, Slot: fortune.SlotGuide}}}
			req, rec := sendReaction(t, reactionAPI(contents), method, "/v1/daily/2026-10-13/slots/daily.guide/reaction")

			require.Equal(t, http.StatusNotFound, rec.Code, rec.Body.String())
			assert.Equal(t, "reaction.not_found", decodeProblem(t, rec).Code)
			expectFortuneContract(t, req, rec)
			assert.Zero(t, contents.putCalls+contents.delete)
		})
	}
}

func TestPutReaction_ProfileMissingIs409(t *testing.T) {
	api := &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}, Contents: &fakeContents{}}

	req, rec := sendReaction(t, api, http.MethodPut, reactionTarget)

	require.Equal(t, http.StatusConflict, rec.Code, rec.Body.String())
	assert.Equal(t, "profile.required", decodeProblem(t, rec).Code)
	expectFortuneContract(t, req, rec)
}

func TestPutReaction_ContentsMissingIs503(t *testing.T) {
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}}

	_, rec := sendReaction(t, api, http.MethodPut, reactionTarget)

	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
}

func TestGetDaily_ShowsReaction(t *testing.T) {
	view := dailyView()
	view.SelectionIDs = map[string]int64{fortune.SlotFortuneHead: 1, fortune.SlotFortuneTag: 2, fortune.SlotGuide: 3}
	contents := &fakeContents{reactions: map[int64]string{1: "like", 3: "like"}}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: view}, Contents: contents}

	req, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	body := decodeMap(t, rec)
	fortuneBody, ok := body["fortune"].(map[string]any)
	require.True(t, ok)
	head, ok := fortuneBody["head"].(map[string]any)
	require.True(t, ok)
	assert.Equal(t, "like", head["reaction"])
	tag, ok := fortuneBody["tag"].(map[string]any)
	require.True(t, ok)
	assert.NotContains(t, tag, "reaction", "반응이 없으면 생략")
	guide, ok := body["guide"].(map[string]any)
	require.True(t, ok)
	assert.NotContains(t, guide, "reaction", "반응할 수 없는 슬롯은 기록이 있어도 생략")

	assert.Equal(t, 1, contents.activeCalls, "반응은 한 번에 조회")
	assert.ElementsMatch(t, []int64{1, 2}, contents.gotActiveIDs, "reactable 슬롯의 기록만 조회")
}
