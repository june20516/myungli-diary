package httpapi_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// fakeReadings는 화면 묶음을 미리 정해 돌려주는 Readings 대역입니다. 받은 인자를 기록합니다.
type fakeReadings struct {
	daily    fortune.DailyView
	calendar fortune.CalendarView
	chart    fortune.ChartView
	err      error

	gotDate        profile.LocalDate
	gotYear        int
	gotMonth       int
	gotAccountID   uuid.UUID
	gotProfileLang string
}

func (f *fakeReadings) Daily(_ context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (fortune.DailyView, error) {
	f.gotAccountID, f.gotProfileLang, f.gotDate = accountID, p.Language, date
	return f.daily, f.err
}

func (f *fakeReadings) Calendar(_ context.Context, accountID uuid.UUID, p profile.Profile, year, month int) (fortune.CalendarView, error) {
	f.gotAccountID, f.gotProfileLang, f.gotYear, f.gotMonth = accountID, p.Language, year, month
	return f.calendar, f.err
}

func (f *fakeReadings) Chart(_ context.Context, accountID uuid.UUID, p profile.Profile) (fortune.ChartView, error) {
	f.gotAccountID, f.gotProfileLang = accountID, p.Language
	return f.chart, f.err
}

// rawEvidenceRule은 엔진 판정에만 있는 근거 규칙 id입니다. 응답 어디에도 나오면 안 됩니다(잠금, D60).
const rawEvidenceRule = "raw.rule.must_not_leak"

// rawJudgment는 근거가 달린 엔진 판정입니다. 변환이 판정 근거를 옮기지 않는지 확인하는 데 씁니다.
func rawJudgment(key string) *enginev1.Judgment {
	return &enginev1.Judgment{
		MessageKey: key,
		Evidence:   []*enginev1.Evidence{{RuleId: rawEvidenceRule, SourceRef: "raw/source#key", Detail: map[string]string{"secret": "x"}}},
	}
}

// text는 조각 하나짜리 문장을 가진 SlotText입니다.
func text(slot, key, variant, body string) content.SlotText {
	return content.SlotText{
		Slot: slot, MessageKey: key, Variant: variant,
		Text:      []render.Segment{{Text: body}},
		Reactable: content.Reactable(slot),
	}
}

// pillar는 엔진 간지 한 기둥입니다.
func pillar(s enginev1.Stem, b enginev1.Branch) *enginev1.Pillar {
	return &enginev1.Pillar{Stem: s, Branch: b}
}

// seoulOffset은 Asia/Seoul의 UTC offset입니다(서머타임 없음).
var seoulOffset = time.FixedZone("KST", 9*60*60)

// dailyResponse는 필드를 고루 채운 엔진 데일리 응답입니다.
func dailyResponse() *enginev1.DailyResponse {
	return &enginev1.DailyResponse{
		Day:  pillar(enginev1.Stem_STEM_GAP, enginev1.Branch_BRANCH_IN),
		Kind: enginev1.DayKind_DAY_KIND_YONGSIN_DAY,
		Color: &enginev1.ColorCard{
			Judgment: rawJudgment("color.wood"), Element: enginev1.Element_ELEMENT_WOOD, Role: enginev1.ElementRole_ELEMENT_ROLE_YONGSIN,
		},
		Direction: &enginev1.DirectionCard{Judgment: rawJudgment("direction.e"), Direction: enginev1.Direction8_DIRECTION8_E, RuleId: "direction.rule"},
		Number:    &enginev1.NumberCard{Judgment: rawJudgment("number.3"), Number: 3},
		FocusTime: &enginev1.FocusTimeCard{
			Judgment: rawJudgment("focus_time.picked"),
			Picks: []*enginev1.FocusSlot{{
				Branch:        enginev1.Branch_BRANCH_SA,
				Pillar:        pillar(enginev1.Stem_STEM_GI, enginev1.Branch_BRANCH_SA),
				Start:         timestamppb.New(time.Date(2026, 10, 13, 0, 30, 0, 0, time.UTC)),
				End:           timestamppb.New(time.Date(2026, 10, 13, 2, 30, 0, 0, time.UTC)),
				HuangdaoLucky: true,
				Score:         3,
				Reasons:       []string{"gwiin", "hap"},
			}},
		},
		Relations: []*enginev1.Relation{
			{Kind: enginev1.RelationKind_RELATION_KIND_BRANCH_HAP, NatalPosition: enginev1.Position_POSITION_DAY_BRANCH},
			{
				Kind: enginev1.RelationKind_RELATION_KIND_CHUNG, NatalPosition: enginev1.Position_POSITION_MONTH_BRANCH,
				SuppressedBy: enginev1.RelationKind_RELATION_KIND_BRANCH_HAP,
			},
		},
		FeaturedTags: []string{"tag.cheoneul_gwiin", "tag.ten_god_rush.gwanseong"},
		AllTags:      []string{"tag.cheoneul_gwiin", "tag.ten_god_rush.gwanseong", "tag.yongsin_day"},
		TagEvidence:  []*enginev1.Evidence{{RuleId: rawEvidenceRule}},
		Fortune:      []*enginev1.Judgment{rawJudgment("fortune.yongsin_day.inseong"), rawJudgment("fortune.tag.cheoneul_gwiin")},
		Guide:        rawJudgment("guide.cheoneul_gwiin"),
		Meta: &enginev1.ResponseMeta{
			RulesetVersion: "r1",
			Notices:        []*enginev1.Notice{{Code: enginev1.NoticeCode_NOTICE_CODE_TIME_UNKNOWN}},
		},
	}
}

// dailyView는 잠긴(근거 없음) 오늘 화면 묶음입니다. 가이드 문장은 원고가 없어 빈 조각 배열입니다.
func dailyView() fortune.DailyView {
	head := text(fortune.SlotFortuneHead, "fortune.yongsin_day.inseong", "advice", "민지님, 오늘은")
	head.Text = []render.Segment{{Text: "민지님, "}, {Text: "인성", Term: "ten_god_group.inseong"}, {Text: "의 날"}}
	head.TodayReason = []render.Segment{{Text: "용신의 날이라서"}}
	guide := text(fortune.SlotGuide, "guide.cheoneul_gwiin", "1", "")
	guide.Text = []render.Segment{}
	return fortune.DailyView{
		Response: dailyResponse(),
		Texts: map[string]content.SlotText{
			fortune.SlotFortuneHead:     head,
			fortune.SlotFortuneTag:      text(fortune.SlotFortuneTag, "fortune.tag.cheoneul_gwiin", "state", "귀인"),
			fortune.SlotGuide:           guide,
			fortune.SlotColor:           text(fortune.SlotColor, "color.wood", "single", "초록"),
			fortune.SlotDirection:       text(fortune.SlotDirection, "direction.e", "single", "동쪽"),
			fortune.SlotNumber:          text(fortune.SlotNumber, "number.3", "single", "3"),
			fortune.SlotFocusTime:       text(fortune.SlotFocusTime, "focus_time.picked", "single", "오전"),
			fortune.SlotCharacterReason: text(fortune.SlotCharacterReason, "character.reason.yongsin_day", "single", "도움"),
		},
		Notices: []content.Notice{{Code: "time_unknown", Text: []render.Segment{}}},
	}
}

// getFortune은 운세 operation 요청을 보내고 요청·응답·로그를 돌려줍니다.
func getFortune(t *testing.T, api *httpapi.API, target string) (*http.Request, *httptest.ResponseRecorder, *bytes.Buffer) {
	t.Helper()
	handler, _, logs := newHandlerAPIWithLogs(t, api)
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, target, nil)
	return req, serve(handler, req), logs
}

// expectFortuneContract는 응답이 계약을 지키는지 확인합니다.
func expectFortuneContract(t *testing.T, req *http.Request, rec *httptest.ResponseRecorder) {
	t.Helper()
	spec, err := gen.GetSpec()
	require.NoError(t, err)
	expectContractResponse(t, spec, req, rec)
}

// decodeMap은 응답 본문을 일반 JSON 값으로 읽습니다. 키가 없는지(생략) 확인할 때 씁니다.
func decodeMap(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var m map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &m))
	return m
}

// handlerErrorLogs는 핸들러가 남긴 Error 로그 수입니다.
func handlerErrorLogs(t *testing.T, logs *bytes.Buffer) int {
	t.Helper()
	count := 0
	for _, line := range strings.Split(strings.TrimSpace(logs.String()), "\n") {
		var entry map[string]any
		require.NoError(t, json.Unmarshal([]byte(line), &entry), line)
		if entry["severity"] == "ERROR" && entry["message"] != "request" {
			count++
		}
	}
	return count
}

func TestGetDaily_Returns200(t *testing.T) {
	view := dailyView()
	// 잠긴 묶음에 근거가 섞여 있어도 옮기지 않습니다(방어).
	leaked := view.Texts[fortune.SlotFortuneHead]
	leaked.Evidence = []content.Evidence{{RuleID: rawEvidenceRule, SourceRef: "s", Basis: []render.Segment{{Text: "근거"}}}}
	view.Texts[fortune.SlotFortuneHead] = leaked
	readings := &fakeReadings{daily: view}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: readings, Contents: &fakeContents{}}

	req, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 13}, readings.gotDate)
	assert.Equal(t, "ko", readings.gotProfileLang)

	var got gen.Daily
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, "2026-10-13", got.Date.String())
	assert.Equal(t, "r1", got.RulesetVersion)
	assert.Equal(t, gen.Locked, got.EvidenceAccess)
	assert.Equal(t, gen.Pillar{Stem: gen.StemGap, Branch: gen.BranchIn}, got.DayPillar)
	assert.Equal(t, gen.YongsinDay, got.DayKind)

	// 문장: 조각과 용어 id, 오늘 그런 이유, 반응 대상.
	head := got.Fortune.Head
	assert.Equal(t, "daily.fortune.head", head.Slot)
	assert.Equal(t, gen.Advice, head.Variant)
	assert.True(t, head.Reactable)
	require.Len(t, head.Text.Segments, 3)
	require.NotNil(t, head.Text.Segments[1].Term)
	assert.Equal(t, "ten_god_group.inseong", *head.Text.Segments[1].Term)
	assert.Nil(t, head.Text.Segments[0].Term)
	require.NotNil(t, head.TodayReason)
	assert.Equal(t, "용신의 날이라서", head.TodayReason.Segments[0].Text)
	require.NotNil(t, got.Fortune.Tag)
	assert.Equal(t, gen.State, got.Fortune.Tag.Variant)
	assert.False(t, got.Cards.Color.Text.Reactable)

	// 카드 원본 값.
	assert.Equal(t, gen.Wood, got.Cards.Color.Element)
	assert.Equal(t, gen.ElementRoleYongsin, got.Cards.Color.Role)
	assert.Equal(t, gen.E, got.Cards.Direction.Direction)
	assert.Equal(t, 3, got.Cards.Number.Number)
	require.Len(t, got.Cards.FocusTime.Picks, 1)
	pick := got.Cards.FocusTime.Picks[0]
	assert.Equal(t, gen.BranchSa, pick.Branch)
	assert.Equal(t, []gen.FocusSlotReasons{gen.FocusSlotReasonsGwiin, gen.FocusSlotReasonsHap}, pick.Reasons)
	assert.True(t, pick.HuangdaoLucky)
	assert.Equal(t, 3, pick.Score)

	// 태그: 접두어를 뗀 키와 spec §7.7 길흉.
	assert.Equal(t, []gen.Tag{
		{Key: "cheoneul_gwiin", Polarity: gen.TagPolarityGood},
		{Key: "ten_god_rush.gwanseong", Polarity: gen.TagPolarityBad},
	}, got.Tags.Featured)
	assert.Equal(t, []string{"cheoneul_gwiin", "ten_god_rush.gwanseong", "yongsin_day"}, got.Tags.All)

	// 관계: suppressed는 suppressed_by가 있을 때만 true, suppressedBy는 그때만 있음.
	require.Len(t, got.Relations, 2)
	assert.Equal(t, gen.Relation{Kind: gen.BranchHap, NatalPosition: gen.DayBranch}, got.Relations[0])
	suppressedBy := gen.BranchHap
	assert.Equal(t, gen.Relation{Kind: gen.Chung, NatalPosition: gen.MonthBranch, Suppressed: true, SuppressedBy: &suppressedBy}, got.Relations[1])

	assert.Equal(t, []gen.Notice{{Code: gen.TimeUnknown, Text: gen.RenderedText{Segments: []gen.Segment{}}}}, got.Notices)

	body := rec.Body.String()
	// 시각은 프로필 현재 시간대(Asia/Seoul)의 offset으로 나갑니다.
	assert.Contains(t, body, `"start":"2026-10-13T09:30:00+09:00"`)
	assert.Contains(t, body, `"end":"2026-10-13T11:30:00+09:00"`)
	assert.True(t, pick.Start.Equal(time.Date(2026, 10, 13, 9, 30, 0, 0, seoulOffset)))
	// 원고가 없는 필수 문장은 null이 아니라 빈 배열입니다.
	assert.Contains(t, body, `"slot":"daily.guide","text":{"segments":[]}`)
	assert.Contains(t, body, `"notices":[{"code":"time_unknown","text":{"segments":[]}}]`)
	// 잠금(D60): 근거와 엔진 판정 근거가 응답에 없습니다.
	assert.NotContains(t, body, `"evidence"`)
	assert.NotContains(t, body, `"basis"`)
	assert.NotContains(t, body, rawEvidenceRule)
}

func TestGetDaily_UnlockedIncludesEvidence(t *testing.T) {
	view := dailyView()
	view.Unlocked = true
	head := view.Texts[fortune.SlotFortuneHead]
	head.Evidence = []content.Evidence{{
		RuleID: "daily.kind.yongsin", SourceRef: "classics/a#b", Detail: map[string]string{"element": "wood"},
		Basis: []render.Segment{{Text: "용신이 목이라"}},
	}}
	view.Texts[fortune.SlotFortuneHead] = head
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: view}, Contents: &fakeContents{}}

	req, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	var got gen.Daily
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, gen.Unlocked, got.EvidenceAccess)
	require.NotNil(t, got.Fortune.Head.Evidence)
	evidence := *got.Fortune.Head.Evidence
	require.Len(t, evidence, 1)
	assert.Equal(t, "daily.kind.yongsin", evidence[0].RuleId)
	assert.Equal(t, "classics/a#b", evidence[0].SourceRef)
	require.NotNil(t, evidence[0].Detail)
	assert.Equal(t, map[string]string{"element": "wood"}, *evidence[0].Detail)
	require.NotNil(t, evidence[0].Basis)
	assert.Equal(t, "용신이 목이라", evidence[0].Basis.Segments[0].Text)
	assert.Nil(t, evidence[0].Source, "원전 문장이 없으면 생략합니다")
	// 열려 있어도 엔진 판정의 근거는 옮기지 않습니다(문장 근거만 계약에 있음).
	assert.NotContains(t, rec.Body.String(), rawEvidenceRule)
	// 근거가 없는 슬롯은 evidence를 생략합니다.
	assert.Nil(t, got.Guide.Evidence)
}

// 운세 세 operation은 앞부분(프로필, 조립, 활성 시드) 오류를 같은 문제 코드로 돌려줍니다.
func TestFortuneOperations_CommonErrors(t *testing.T) {
	targets := []struct{ name, target string }{
		{"getDaily", "/v1/daily/2026-10-13"},
		{"getCalendar", "/v1/calendar/2026/10"},
		{"getChart", "/v1/chart"},
	}
	cases := []struct {
		name     string
		api      func() *httpapi.API
		status   int
		code     string
		errorLog bool
	}{
		{
			name: "프로필 없음",
			api: func() *httpapi.API {
				return &httpapi.API{Profiles: &fakeProfiles{err: profile.ErrNotFound}, Readings: &fakeReadings{}, Contents: &fakeContents{}}
			},
			status: http.StatusConflict, code: "profile.required",
		},
		{
			name: "활성 시드 없음",
			api: func() *httpapi.API {
				return &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{err: content.ErrNoActiveSeed}, Contents: &fakeContents{}}
			},
			status: http.StatusServiceUnavailable, code: "service.unavailable", errorLog: true,
		},
		{
			name: "Readings 미조립",
			api: func() *httpapi.API {
				return &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Contents: &fakeContents{}}
			},
			status: http.StatusServiceUnavailable, code: "service.unavailable",
		},
	}
	for _, target := range targets {
		for _, tc := range cases {
			t.Run(target.name+"/"+tc.name, func(t *testing.T) {
				req, rec, logs := getFortune(t, tc.api(), target.target)

				require.Equal(t, tc.status, rec.Code, rec.Body.String())
				assert.Equal(t, tc.code, decodeProblem(t, rec).Code)
				expectFortuneContract(t, req, rec)
				if tc.errorLog {
					assert.Equal(t, 1, handlerErrorLogs(t, logs), logs.String())
				}
			})
		}
	}
}

// 프로필 현재 시간대를 읽지 못하면 화면 묶음(엔진·선택 기록)을 부르기 전에 500으로 끝냅니다.
func TestFortuneOperations_BadTimezoneStopsBeforeReadings(t *testing.T) {
	for _, target := range []string{"/v1/daily/2026-10-13", "/v1/calendar/2026/10"} {
		t.Run(target, func(t *testing.T) {
			p := storedProfile()
			p.CurrentTimezone = "Not/AZone"
			readings := &fakeReadings{daily: dailyView(), calendar: calendarView()}
			api := &httpapi.API{Profiles: &fakeProfiles{profile: p}, Readings: readings, Contents: &fakeContents{}}

			_, rec, _ := getFortune(t, api, target)

			require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
			assert.Equal(t, uuid.Nil, readings.gotAccountID, "Readings를 부르지 않음")
		})
	}
}

func TestGetDaily_OutOfRangeIs422(t *testing.T) {
	readings := &fakeReadings{err: fmt.Errorf("엔진 데일리: %w", engine.ErrOutOfRange)}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: readings, Contents: &fakeContents{}}

	req, rec, _ := getFortune(t, api, "/v1/daily/2100-01-01")

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "date.out_of_range", p.Code)
	require.Len(t, p.Errors, 1)
	assert.Equal(t, "date", p.Errors[0].Field)
	expectFortuneContract(t, req, rec)
}

func TestGetDaily_UnknownEngineEnumIs500(t *testing.T) {
	view := dailyView()
	view.Response.Day.Stem = enginev1.Stem_STEM_UNSPECIFIED
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: view}, Contents: &fakeContents{}}

	req, rec, logs := getFortune(t, api, "/v1/daily/2026-10-13")

	require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
	assert.Equal(t, "internal", decodeProblem(t, rec).Code)
	expectFortuneContract(t, req, rec)
	assert.Equal(t, 1, handlerErrorLogs(t, logs), logs.String())
}

// calendarView는 이틀짜리 달력 묶음입니다. 첫날만 입절일이고 대표 태그가 있습니다.
func calendarView() fortune.CalendarView {
	day := func(d int32) *enginev1.MonthDay {
		return &enginev1.MonthDay{
			Date:       &enginev1.LocalDate{Year: 2026, Month: 10, Day: d},
			Pillar:     pillar(enginev1.Stem_STEM_GAP, enginev1.Branch_BRANCH_IN),
			LunarMonth: 8, LunarDay: d, IsLeapMonth: d == 2,
			Kind:       enginev1.DayKind_DAY_KIND_ORDINARY_DAY,
			LuckLevel:  enginev1.LuckLevel_LUCK_LEVEL_GOOD,
			Score:      2,
			ScoreItems: []*enginev1.ScoreItem{{Id: "gwiin_day", Score: 2}},
			Judgment:   rawJudgment("calendar.good"),
		}
	}
	first := day(1)
	first.SolarTerm = &enginev1.SolarTerm{
		Name: "寒露", Kind: enginev1.SolarTermKind_SOLAR_TERM_KIND_HALLO,
		At: timestamppb.New(time.Date(2026, 10, 1, 3, 0, 0, 0, time.UTC)),
	}
	featured := "tag.gongmang"
	first.FeaturedTag = &featured

	texts := func() fortune.DayTexts {
		return fortune.DayTexts{
			CharacterReason: text(fortune.SlotCharacterReason, "character.reason.ordinary_day", "single", "평범"),
			Level:           content.SlotText{Slot: fortune.SlotDayLevel, MessageKey: "calendar.good", Variant: "single", Text: []render.Segment{}},
		}
	}
	return fortune.CalendarView{
		Response: &enginev1.MonthResponse{Days: []*enginev1.MonthDay{first, day(2)}, Meta: &enginev1.ResponseMeta{RulesetVersion: "r1"}},
		Days:     []fortune.DayTexts{texts(), texts()},
		Notices:  []content.Notice{},
	}
}

func TestGetCalendar_Returns200(t *testing.T) {
	readings := &fakeReadings{calendar: calendarView()}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: readings}

	req, rec, _ := getFortune(t, api, "/v1/calendar/2026/10")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, 2026, readings.gotYear)
	assert.Equal(t, 10, readings.gotMonth)

	var got gen.Calendar
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, 2026, got.Year)
	assert.Equal(t, 10, got.Month)
	assert.Equal(t, "r1", got.RulesetVersion)
	assert.Equal(t, gen.Locked, got.EvidenceAccess)
	require.Len(t, got.Days, 2)

	first := got.Days[0]
	assert.Equal(t, "2026-10-01", first.Date.String())
	assert.Equal(t, gen.LunarDate{Month: 8, Day: 1}, first.Lunar)
	assert.Equal(t, gen.OrdinaryDay, first.DayKind)
	assert.Equal(t, gen.LuckLevelGood, first.LuckLevel)
	assert.Equal(t, 2, first.Score)
	assert.Equal(t, []gen.ScoreItem{{Id: "gwiin_day", Score: 2}}, first.ScoreItems)
	require.NotNil(t, first.SolarTerm)
	assert.Equal(t, gen.Hallo, first.SolarTerm.Kind)
	require.NotNil(t, first.FeaturedTag)
	assert.Equal(t, gen.Tag{Key: "gongmang", Polarity: gen.TagPolarityBad}, *first.FeaturedTag)
	assert.Equal(t, "calendar.good", first.Level.MessageKey)
	assert.Equal(t, "평범", first.CharacterReason.Text.Segments[0].Text)
	assert.Equal(t, gen.LunarDate{Month: 8, Day: 2, IsLeapMonth: true}, got.Days[1].Lunar)

	m := decodeMap(t, rec)
	days, ok := m["days"].([]any)
	require.True(t, ok)
	second, ok := days[1].(map[string]any)
	require.True(t, ok)
	assert.NotContains(t, second, "solarTerm", "입절일이 아니면 solarTerm을 생략합니다")
	assert.NotContains(t, second, "featuredTag")

	body := rec.Body.String()
	assert.Contains(t, body, `"at":"2026-10-01T12:00:00+09:00"`)
	assert.Contains(t, body, `"slot":"calendar.day_level","text":{"segments":[]}`)
	assert.Contains(t, body, `"notices":[]`)
	assert.NotContains(t, body, `"evidence"`)
	assert.NotContains(t, body, rawEvidenceRule)
}

func TestGetCalendar_OutOfRangeIs422(t *testing.T) {
	readings := &fakeReadings{err: engine.ErrOutOfRange}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: readings}

	req, rec, _ := getFortune(t, api, "/v1/calendar/1900/1")

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	p := decodeProblem(t, rec)
	assert.Equal(t, "date.out_of_range", p.Code)
	require.Len(t, p.Errors, 1)
	assert.Equal(t, "year", p.Errors[0].Field)
	expectFortuneContract(t, req, rec)
}

// chartResponse는 시간 모름 사주의 엔진 응답입니다. 개인 해석(근거 깊이)이 있습니다.
func chartResponse() *enginev1.ChartResponse {
	return &enginev1.ChartResponse{
		Pillars: &enginev1.FourPillars{
			Year:  pillar(enginev1.Stem_STEM_GYEONG, enginev1.Branch_BRANCH_O),
			Month: pillar(enginev1.Stem_STEM_SIN, enginev1.Branch_BRANCH_SA),
			Day:   pillar(enginev1.Stem_STEM_GAP, enginev1.Branch_BRANCH_JA),
		},
		TenGods: []*enginev1.PositionTenGod{{Position: enginev1.Position_POSITION_YEAR_STEM, TenGod: enginev1.TenGod_TEN_GOD_PYEONGWAN}},
		HiddenStems: []*enginev1.PositionHiddenStems{{
			Position: enginev1.Position_POSITION_DAY_BRANCH,
			Stems:    []*enginev1.HiddenStem{{Stem: enginev1.Stem_STEM_GYE, TenGod: enginev1.TenGod_TEN_GOD_JEONGIN}},
		}},
		TwelveStages:   []*enginev1.PositionTwelveStage{{Position: enginev1.Position_POSITION_DAY_BRANCH, TwelveStage: enginev1.TwelveStage_TWELVE_STAGE_MOKYOK}},
		Shinsal:        []*enginev1.ShinsalHit{{Kind: enginev1.Shinsal_SHINSAL_DOHWA, Position: enginev1.Position_POSITION_DAY_BRANCH}},
		Gongmang:       []enginev1.Branch{enginev1.Branch_BRANCH_SUL, enginev1.Branch_BRANCH_HAE},
		ElementWeights: []*enginev1.ElementWeight{{Element: enginev1.Element_ELEMENT_WOOD, Weight: 1.5}},
		Strength:       &enginev1.Strength{Score: -0.5, Level: enginev1.StrengthLevel_STRENGTH_LEVEL_WEAK},
		Yongsin: &enginev1.YongsinInfo{
			Yongsin: enginev1.Element_ELEMENT_WATER, Huisin: enginev1.Element_ELEMENT_METAL,
			Gisin: enginev1.Element_ELEMENT_EARTH, Tonggwan: enginev1.Element_ELEMENT_WOOD,
			Method:   enginev1.YongsinMethod_YONGSIN_METHOD_EOKBU,
			Judgment: rawJudgment("chart.yongsin_method.eokbu"),
		},
		Daeun: &enginev1.DaeunTable{
			Forward: true, StartYears: 3, StartMonths: 4,
			Periods: []*enginev1.LuckPeriod{{
				Pillar: pillar(enginev1.Stem_STEM_IM, enginev1.Branch_BRANCH_O), StartAge: 3, StartAgeKorean: 4,
				StemTenGod: enginev1.TenGod_TEN_GOD_PYEONIN, BranchTenGod: enginev1.TenGod_TEN_GOD_SANGGWAN,
				TwelveStage: enginev1.TwelveStage_TWELVE_STAGE_SA,
			}},
		},
		Seun: []*enginev1.YearLuck{{
			Year: 2026, Pillar: pillar(enginev1.Stem_STEM_BYEONG, enginev1.Branch_BRANCH_O),
			TenGod: enginev1.TenGod_TEN_GOD_SIKSIN, RelationsWithNatal: []enginev1.RelationKind{enginev1.RelationKind_RELATION_KIND_CHUNG},
		}},
		Meta: &enginev1.ResponseMeta{
			RulesetVersion: "r1",
			Notices:        []*enginev1.Notice{{Code: enginev1.NoticeCode_NOTICE_CODE_TIME_UNKNOWN}},
		},
		PersonalReadings: []*enginev1.PersonalReading{{
			Kind: enginev1.PersonalTermKind_PERSONAL_TERM_KIND_DAY_MASTER, Position: enginev1.Position_POSITION_DAY_STEM,
			Judgment: rawJudgment("personal.day_master.gap"),
		}},
	}
}

func TestGetChart_Returns200(t *testing.T) {
	view := fortune.ChartView{
		Response: chartResponse(),
		Notices:  []content.Notice{{Code: "time_unknown", Text: []render.Segment{}}},
	}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{chart: view}}

	req, rec, _ := getFortune(t, api, "/v1/chart")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	var got gen.Chart
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, "r1", got.RulesetVersion)
	assert.Equal(t, gen.Locked, got.EvidenceAccess)
	assert.Equal(t, gen.Pillar{Stem: gen.StemGap, Branch: gen.BranchJa}, got.Pillars.Day)
	assert.Equal(t, gen.Pillar{Stem: gen.StemGyeong, Branch: gen.BranchO}, got.Pillars.Year)
	assert.Nil(t, got.Pillars.Hour)
	assert.Equal(t, []gen.TenGodAt{{Position: gen.YearStem, TenGod: gen.Pyeongwan}}, got.TenGods)
	assert.Equal(t, []gen.HiddenStemsAt{{Position: gen.DayBranch, Stems: []gen.HiddenStem{{Stem: gen.StemGye, TenGod: gen.Jeongin}}}}, got.HiddenStems)
	assert.Equal(t, []gen.TwelveStageAt{{Position: gen.DayBranch, Stage: gen.TwelveStageMokyok}}, got.TwelveStages)
	assert.Equal(t, []gen.ShinsalAt{{Kind: gen.Dohwa, Position: gen.DayBranch}}, got.Shinsal)
	assert.Equal(t, []gen.Branch{gen.BranchSul, gen.BranchHae}, got.Gongmang)
	assert.Equal(t, []gen.ElementWeight{{Element: gen.Wood, Weight: 1.5}}, got.ElementWeights)
	assert.Equal(t, gen.Strength{Score: -0.5, Level: gen.StrengthLevelWeak}, got.Strength)
	assert.Equal(t, gen.Yongsin{
		Yongsin: gen.Water, Huisin: gen.Metal, Gisin: gen.Earth,
		Tonggwan: gen.Wood, Method: gen.Eokbu,
	}, got.Yongsin)
	assert.Equal(t, gen.Daeun{Forward: true, StartYears: 3, StartMonths: 4, Periods: []gen.DaeunPeriod{{
		Pillar: gen.Pillar{Stem: gen.StemIm, Branch: gen.BranchO}, StartAge: 3, StartAgeKorean: 4,
		StemTenGod: gen.Pyeonin, BranchTenGod: gen.Sanggwan, TwelveStage: gen.TwelveStageSa,
	}}}, got.Daeun)
	assert.Equal(t, []gen.SeunYear{{
		Year: 2026, Pillar: gen.Pillar{Stem: gen.StemByeong, Branch: gen.BranchO},
		TenGod: gen.Siksin, RelationsWithNatal: []gen.RelationKind{gen.Chung},
	}}, got.Seun)

	m := decodeMap(t, rec)
	pillars, ok := m["pillars"].(map[string]any)
	require.True(t, ok)
	assert.NotContains(t, pillars, "hour", "시간 모름이면 hour를 생략합니다")
	yongsin, ok := m["yongsin"].(map[string]any)
	require.True(t, ok)
	assert.NotContains(t, yongsin, "johuStem", "조후 천간이 없으면 생략합니다")
	assert.NotContains(t, yongsin, "basis", "잠겨 있으면 용신 근거를 생략합니다")
	body := rec.Body.String()
	assert.NotContains(t, body, rawEvidenceRule)
	assert.NotContains(t, body, "personal")
}

func TestGetChart_UnlockedIncludesYongsinBasis(t *testing.T) {
	response := chartResponse()
	response.Pillars.Hour = pillar(enginev1.Stem_STEM_BYEONG, enginev1.Branch_BRANCH_IN)
	response.Yongsin.Method = enginev1.YongsinMethod_YONGSIN_METHOD_JOHU
	response.Yongsin.JohuStem = enginev1.Stem_STEM_BYEONG
	basis := text(fortune.SlotYongsinMethod, "chart.yongsin_method.johu", "single", "조후로")
	view := fortune.ChartView{Response: response, YongsinBasis: &basis, Unlocked: true, Notices: []content.Notice{}}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{chart: view}}

	req, rec, _ := getFortune(t, api, "/v1/chart")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	var got gen.Chart
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, gen.Unlocked, got.EvidenceAccess)
	require.NotNil(t, got.Pillars.Hour)
	assert.Equal(t, gen.Pillar{Stem: gen.StemByeong, Branch: gen.BranchIn}, *got.Pillars.Hour)
	require.NotNil(t, got.Yongsin.JohuStem)
	assert.Equal(t, gen.StemByeong, *got.Yongsin.JohuStem)
	require.NotNil(t, got.Yongsin.Basis)
	assert.Equal(t, "chart.yongsin_method.johu", got.Yongsin.Basis.MessageKey)
	// 열려 있어도 계약에 없는 원국 개인 해석은 옮기지 않습니다.
	assert.NotContains(t, rec.Body.String(), rawEvidenceRule)
}
