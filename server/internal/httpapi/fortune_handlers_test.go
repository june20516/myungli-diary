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
		GuideCandidates: []content.SlotText{guide},
		Notices:         []content.Notice{{Code: "time_unknown", Text: []render.Segment{}}},
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
	// 1.11.0 부속 카드는 엔진과 View에 없으면 생략하고, 덕일은 빈 배열입니다.
	for _, key := range []string{`"secondColor"`, `"nightFocusTime"`, `"previousNightFocusTime"`, `"dayDate"`, `"hours"`} {
		assert.NotContains(t, body, key)
	}
	assert.Contains(t, body, `"dayVirtues":[]`)
}

// TestGetDaily_LuckyCardsAndVirtues는 1.11.0의 둘째 색(D119), 밤과 전날 밤 집중 시간(D122), 시진의 날짜와 일진, 택일 덕일(D124 ⑤)을 봅니다.
func TestGetDaily_LuckyCardsAndVirtues(t *testing.T) {
	night := func(day int32, key string) *enginev1.FocusTimeCard {
		return &enginev1.FocusTimeCard{
			Judgment: rawJudgment(key),
			Period:   enginev1.FocusPeriod_FOCUS_PERIOD_NIGHT,
			Picks: []*enginev1.FocusSlot{{
				Branch:    enginev1.Branch_BRANCH_JA,
				Start:     timestamppb.New(time.Date(2026, 10, int(day), 14, 30, 0, 0, time.UTC)),
				End:       timestamppb.New(time.Date(2026, 10, int(day), 16, 30, 0, 0, time.UTC)),
				DayDate:   &enginev1.LocalDate{Year: 2026, Month: 10, Day: day + 1},
				DayPillar: pillar(enginev1.Stem_STEM_BYEONG, enginev1.Branch_BRANCH_JA),
			}},
		}
	}
	view := dailyView()
	view.Response.SecondColor = &enginev1.ColorCard{
		Judgment: rawJudgment("color.source.yongsin_day"), Element: enginev1.Element_ELEMENT_FIRE, Role: enginev1.ElementRole_ELEMENT_ROLE_YONGSIN,
		Basis: enginev1.ColorBasis_COLOR_BASIS_SOURCE,
	}
	view.Response.NightFocusTime = night(13, "focus_time.night")
	// 구간 시진 전부(#1064): 낮 카드에만 넣어, 없는 카드는 생략하는지도 봅니다.
	// 낮 일곱 칸(진시~술시), 서울 07:30부터 두 시간씩. 둘째 칸 사시가 고른 시진(picks)입니다.
	dayBranches := []enginev1.Branch{
		enginev1.Branch_BRANCH_JIN, enginev1.Branch_BRANCH_SA, enginev1.Branch_BRANCH_O, enginev1.Branch_BRANCH_MI,
		enginev1.Branch_BRANCH_SHIN, enginev1.Branch_BRANCH_YU, enginev1.Branch_BRANCH_SUL,
	}
	for i, branch := range dayBranches {
		if branch == enginev1.Branch_BRANCH_SA {
			view.Response.FocusTime.Hours = append(view.Response.FocusTime.Hours, view.Response.FocusTime.Picks[0])
			continue
		}
		start := time.Date(2026, 10, 12, 22, 30, 0, 0, time.UTC).Add(time.Duration(2*i) * time.Hour)
		view.Response.FocusTime.Hours = append(view.Response.FocusTime.Hours, &enginev1.FocusSlot{
			Branch: branch, Start: timestamppb.New(start), End: timestamppb.New(start.Add(2 * time.Hour)),
		})
	}
	view.Response.DayVirtues = []*enginev1.DayVirtueCard{
		{Kind: enginev1.DayVirtue_DAY_VIRTUE_CHEONDEOK_DAY, Judgment: rawJudgment("day_virtue.cheondeok")},
		{Kind: enginev1.DayVirtue_DAY_VIRTUE_WOLDEOK_DAY, Judgment: rawJudgment("day_virtue.woldeok")},
	}
	second := text(fortune.SlotColor, "color.source.yongsin_day", "single", "빨강")
	nightText := text(fortune.SlotFocusTime, "focus_time.night", "single", "밤")
	view.SecondColor = &second
	view.NightFocusTime = &nightText
	view.PreviousNight = &fortune.FocusTimeText{Card: night(12, "focus_time.night"), Text: text(fortune.SlotFocusTime, "focus_time.night", "single", "어젯밤")}
	view.DayVirtues = []fortune.DayVirtueText{
		{Card: view.Response.DayVirtues[0], Text: text(fortune.SlotDayVirtue, "day_virtue.cheondeok", "single", "천덕일")},
		{Card: view.Response.DayVirtues[1], Text: text(fortune.SlotDayVirtue, "day_virtue.woldeok", "single", "월덕일")},
	}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: view}, Contents: &fakeContents{}}

	req, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	var got gen.Daily
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))

	require.NotNil(t, got.Cards.SecondColor)
	assert.Equal(t, gen.Fire, got.Cards.SecondColor.Element)
	assert.Equal(t, "color.source.yongsin_day", got.Cards.SecondColor.Text.MessageKey)
	assert.Equal(t, "color.wood", got.Cards.Color.Text.MessageKey)

	require.NotNil(t, got.Cards.NightFocusTime)
	assert.Equal(t, "밤", got.Cards.NightFocusTime.Text.Text.Segments[0].Text)
	pick := got.Cards.NightFocusTime.Picks[0]
	require.NotNil(t, pick.DayDate)
	assert.Equal(t, "2026-10-14", pick.DayDate.String())
	require.NotNil(t, pick.DayPillar)
	assert.Equal(t, gen.Pillar{Stem: gen.StemByeong, Branch: gen.BranchJa}, *pick.DayPillar)
	require.NotNil(t, got.Cards.PreviousNightFocusTime)
	assert.Equal(t, "어젯밤", got.Cards.PreviousNightFocusTime.Text.Text.Segments[0].Text)
	assert.Equal(t, "2026-10-13", got.Cards.PreviousNightFocusTime.Picks[0].DayDate.String())
	assert.Nil(t, got.Cards.FocusTime.Picks[0].DayDate, "날짜를 내지 않는 엔진의 시진은 dayDate를 생략합니다")
	require.NotNil(t, got.Cards.FocusTime.Hours)
	hours := *got.Cards.FocusTime.Hours
	require.Len(t, hours, 7)
	assert.Equal(t, gen.BranchJin, hours[0].Branch)
	assert.True(t, hours[0].Start.Equal(time.Date(2026, 10, 13, 7, 30, 0, 0, seoulOffset)), "전환 시각은 진시 시작, 프로필 시간대 offset")
	assert.Equal(t, got.Cards.FocusTime.Picks[0], hours[1])
	assert.Nil(t, got.Cards.NightFocusTime.Hours, "엔진이 hours를 내지 않은 카드는 생략합니다")

	require.Len(t, got.DayVirtues, 2)
	assert.Equal(t, gen.CheondeokDay, got.DayVirtues[0].Kind)
	assert.Equal(t, "explain.day_virtue", got.DayVirtues[0].Text.Slot)
	assert.Equal(t, gen.WoldeokDay, got.DayVirtues[1].Kind)
}

// TestGetDaily_PartWithoutTextIsOmitted는 엔진이 둘째 색이나 밤 카드를 내도 문장이 없으면(View가 nil) 카드를 생략하는지 봅니다.
func TestGetDaily_PartWithoutTextIsOmitted(t *testing.T) {
	view := dailyView()
	view.Response.SecondColor = &enginev1.ColorCard{Judgment: rawJudgment("color.source.yongsin_day"), Element: enginev1.Element_ELEMENT_FIRE, Role: enginev1.ElementRole_ELEMENT_ROLE_YONGSIN}
	view.Response.NightFocusTime = &enginev1.FocusTimeCard{Judgment: rawJudgment("focus_time.night")}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: view}, Contents: &fakeContents{}}

	req, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.NotContains(t, rec.Body.String(), `"secondColor"`)
	assert.NotContains(t, rec.Body.String(), `"nightFocusTime"`)
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

// 일진 천간의 십성과 묶음(ruleset 2026.11.0, #806 ③)은 엔진이 내면 담고, 옛 규칙 버전처럼 둘 다 없으면 생략합니다.
func TestGetDaily_DayStemTenGod(t *testing.T) {
	t.Run("엔진이 내면 담음", func(t *testing.T) {
		view := dailyView()
		view.Response.DayStemTenGod = enginev1.TenGod_TEN_GOD_SIKSIN
		view.Response.DayStemTenGodGroup = enginev1.TenGodGroup_TEN_GOD_GROUP_SIKSANG
		api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: view}, Contents: &fakeContents{}}

		req, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

		require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
		expectFortuneContract(t, req, rec)
		var got gen.Daily
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
		require.NotNil(t, got.DayStemTenGod)
		require.NotNil(t, got.DayStemTenGodGroup)
		assert.Equal(t, gen.Siksin, *got.DayStemTenGod)
		assert.Equal(t, gen.Siksang, *got.DayStemTenGodGroup)
	})
	t.Run("둘 다 없으면 생략", func(t *testing.T) {
		api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: dailyView()}, Contents: &fakeContents{}}

		_, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

		require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
		assert.NotContains(t, rec.Body.String(), "dayStemTenGod")
	})
	t.Run("하나만 오면 500", func(t *testing.T) {
		view := dailyView()
		view.Response.DayStemTenGod = enginev1.TenGod_TEN_GOD_SIKSIN
		api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: view}, Contents: &fakeContents{}}

		_, rec, logs := getFortune(t, api, "/v1/daily/2026-10-13")

		require.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
		assert.Equal(t, 1, handlerErrorLogs(t, logs), logs.String())
	})
}

// 그날 음력(ruleset 2026.11.1, #806 ②)은 엔진이 내면 담고, 옛 규칙 버전처럼 달이 0이면 생략합니다.
func TestGetDaily_Lunar(t *testing.T) {
	t.Run("엔진이 내면 담음", func(t *testing.T) {
		view := dailyView()
		view.Response.LunarMonth = 9
		view.Response.LunarDay = 2
		view.Response.IsLeapMonth = true
		api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: view}, Contents: &fakeContents{}}

		req, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

		require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
		expectFortuneContract(t, req, rec)
		var got gen.Daily
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
		require.NotNil(t, got.Lunar)
		assert.Equal(t, gen.LunarDate{Month: 9, Day: 2, IsLeapMonth: true}, *got.Lunar)
	})
	t.Run("없으면 생략", func(t *testing.T) {
		api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: dailyView()}, Contents: &fakeContents{}}

		_, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

		require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
		assert.NotContains(t, rec.Body.String(), `"lunar":`)
	})
}

// calendarView는 이틀짜리 달력 묶음입니다. 첫날만 입절일이고 대표 태그가 있습니다.
func calendarView() fortune.CalendarView {
	day := func(d int32) *enginev1.MonthDay {
		return &enginev1.MonthDay{
			Date:       &enginev1.LocalDate{Year: 2026, Month: 10, Day: d},
			Pillar:     pillar(enginev1.Stem_STEM_GAP, enginev1.Branch_BRANCH_IN),
			LunarMonth: 8, LunarDay: d, IsLeapMonth: d == 2,
			Kind:      enginev1.DayKind_DAY_KIND_ORDINARY_DAY,
			LuckLevel: enginev1.LuckLevel_LUCK_LEVEL_GOOD,
			Score:     2,
			Judgment:  rawJudgment("calendar.good"),
		}
	}
	first := day(1)
	first.DayVirtues = []enginev1.DayVirtue{enginev1.DayVirtue_DAY_VIRTUE_CHEONDEOK_DAY}
	first.ScoreItems = []*enginev1.ScoreItem{{Id: "yongsin_day", Score: 2}}
	first.SolarTerm = &enginev1.SolarTerm{
		Name: "寒露", Kind: enginev1.SolarTermKind_SOLAR_TERM_KIND_HALLO,
		At: timestamppb.New(time.Date(2026, 10, 1, 3, 0, 0, 0, time.UTC)),
	}

	texts := func() fortune.DayTexts {
		return fortune.DayTexts{
			CharacterReason: text(fortune.SlotCharacterReason, "character.reason.ordinary_day", "single", "평범"),
			Level:           content.SlotText{Slot: fortune.SlotDayLevel, MessageKey: "calendar.good", Variant: "single", Text: []render.Segment{}},
		}
	}
	return fortune.CalendarView{
		Response: &enginev1.MonthResponse{Days: []*enginev1.MonthDay{first, day(2)}, Meta: &enginev1.ResponseMeta{RulesetVersion: "r1"}},
		Days:     []fortune.DayTexts{texts(), texts()},
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
	require.NotNil(t, first.SolarTerm)
	assert.Equal(t, gen.Hallo, first.SolarTerm.Kind)
	assert.Equal(t, "calendar.good", first.Level.MessageKey)
	assert.Equal(t, "평범", first.CharacterReason.Text.Segments[0].Text)
	assert.Equal(t, gen.LunarDate{Month: 8, Day: 2, IsLeapMonth: true}, got.Days[1].Lunar)

	m := decodeMap(t, rec)
	days, ok := m["days"].([]any)
	require.True(t, ok)
	second, ok := days[1].(map[string]any)
	require.True(t, ok)
	assert.NotContains(t, second, "solarTerm", "입절일이 아니면 solarTerm을 생략합니다")

	body := rec.Body.String()
	assert.Contains(t, body, `"at":"2026-10-01T12:00:00+09:00"`)
	assert.Contains(t, body, `"slot":"calendar.day_level","text":{"segments":[]}`)
	for _, key := range []string{`"notices"`, `"featuredTag"`} {
		assert.NotContains(t, body, key, "쓰지 않는 필드(S77)는 응답에 나가지 않습니다")
	}
	// 길흉 내역(#806 ①, 1.6.0)은 항목이 없는 날도 빈 배열로 나갑니다.
	assert.Contains(t, body, `"scoreItems":[{"id":"yongsin_day","score":2}]`)
	assert.Contains(t, body, `"scoreItems":[]`)
	// 택일 덕일(D124 ⑤, 1.11.0)도 없는 날은 빈 배열입니다.
	assert.Equal(t, []gen.DayVirtueKind{gen.CheondeokDay}, first.DayVirtues)
	assert.Equal(t, []gen.DayVirtueKind{}, got.Days[1].DayVirtues)
	assert.Contains(t, body, `"dayVirtues":[]`)
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
		TwelveStages: []*enginev1.PositionTwelveStage{{Position: enginev1.Position_POSITION_DAY_BRANCH, TwelveStage: enginev1.TwelveStage_TWELVE_STAGE_MOKYOK}},
		Shinsal: []*enginev1.ShinsalHit{
			// 2026.11.7 전 엔진은 걸친 자리(positions)를 내지 않습니다.
			{Kind: enginev1.Shinsal_SHINSAL_DOHWA, Position: enginev1.Position_POSITION_DAY_BRANCH},
			{
				Kind: enginev1.Shinsal_SHINSAL_GOEGANG, Position: enginev1.Position_POSITION_DAY_BRANCH,
				Positions: []enginev1.Position{enginev1.Position_POSITION_DAY_STEM, enginev1.Position_POSITION_DAY_BRANCH},
			},
		},
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
				Pillar: pillar(enginev1.Stem_STEM_IM, enginev1.Branch_BRANCH_O), StartAge: 3, StartAgeKorean: 4, StartYear: 1993,
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
	assert.Equal(t, []gen.ShinsalAt{
		{Kind: gen.Dohwa, Position: gen.DayBranch, Positions: []gen.Position{gen.DayBranch}},
		{Kind: gen.Goegang, Position: gen.DayBranch, Positions: []gen.Position{gen.DayStem, gen.DayBranch}},
	}, got.Shinsal)
	assert.Equal(t, []gen.Branch{gen.BranchSul, gen.BranchHae}, got.Gongmang)
	assert.Equal(t, []gen.ElementWeight{{Element: gen.Wood, Weight: 1.5}}, got.ElementWeights)
	assert.Equal(t, gen.Strength{Score: -0.5, Level: gen.StrengthLevelWeak}, got.Strength)
	assert.Equal(t, gen.Yongsin{
		Yongsin: gen.Water, Huisin: gen.Metal, Gisin: gen.Earth,
		Tonggwan: gen.Wood, Method: gen.Eokbu,
	}, got.Yongsin)
	assert.Equal(t, gen.Daeun{Forward: true, StartYears: 3, StartMonths: 4, Periods: []gen.DaeunPeriod{{
		Pillar: gen.Pillar{Stem: gen.StemIm, Branch: gen.BranchO}, StartAge: 3, StartAgeKorean: 4, StartYear: 1993,
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
	for _, field := range []string{"ilganHead", "ilganBody", "yongsinSummary"} {
		assert.NotContains(t, m, field, "문장이 없으면 생략합니다")
	}
	body := rec.Body.String()
	assert.NotContains(t, body, rawEvidenceRule)
	assert.NotContains(t, body, "personal")
}

// 나의 사주 문장 셋은 잠겨 있어도 옮깁니다(#329).
func TestGetChart_LockedIncludesChartTexts(t *testing.T) {
	head := text(fortune.SlotIlganHead, "ilgan.head.gap", "single", "민지님, 큰 나무를 닮았어요.")
	body := text(fortune.SlotIlganBody, "ilgan.body.gap", "single", "한번 정한 길을 가요.")
	summary := text(fortune.SlotYongsinSummary, "yongsin.summary", "single", "청록색이 어울려요.")
	view := fortune.ChartView{
		Response: chartResponse(), Notices: []content.Notice{},
		IlganHead: &head, IlganBody: &body, YongsinSummary: &summary,
	}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{chart: view}}

	req, rec, _ := getFortune(t, api, "/v1/chart")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	var got gen.Chart
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
	assert.Equal(t, gen.Locked, got.EvidenceAccess)
	for _, tc := range []struct {
		got       *gen.SlotText
		slot, key string
		want      string
	}{
		{got.IlganHead, fortune.SlotIlganHead, "ilgan.head.gap", "민지님, 큰 나무를 닮았어요."},
		{got.IlganBody, fortune.SlotIlganBody, "ilgan.body.gap", "한번 정한 길을 가요."},
		{got.YongsinSummary, fortune.SlotYongsinSummary, "yongsin.summary", "청록색이 어울려요."},
	} {
		require.NotNil(t, tc.got, tc.slot)
		assert.Equal(t, tc.slot, tc.got.Slot)
		assert.Equal(t, tc.key, tc.got.MessageKey)
		assert.Equal(t, gen.Single, tc.got.Variant)
		assert.False(t, tc.got.Reactable)
		require.Len(t, tc.got.Text.Segments, 1)
		assert.Equal(t, tc.want, tc.got.Text.Segments[0].Text)
	}
}

func TestGetChart_UnlockedIncludesYongsinBasis(t *testing.T) {
	response := chartResponse()
	response.Pillars.Hour = pillar(enginev1.Stem_STEM_BYEONG, enginev1.Branch_BRANCH_IN)
	response.Yongsin.Method = enginev1.YongsinMethod_YONGSIN_METHOD_JOHU
	response.Yongsin.JohuStem = enginev1.Stem_STEM_BYEONG
	basis := text(fortune.SlotYongsinMethod, "chart.yongsin_method.johu", "single", "조후로")
	view := fortune.ChartView{
		Response: response, YongsinBasis: &basis, Unlocked: true, Notices: []content.Notice{},
		PersonalReadings: []fortune.PersonalReadingText{
			{Reading: response.PersonalReadings[0], Text: text("personal.day_master", "personal.day_master.gap", "single", "내 일간은 큰 나무 같아요.")},
			{
				Reading: &enginev1.PersonalReading{
					Kind: enginev1.PersonalTermKind_PERSONAL_TERM_KIND_SHINSAL, Position: enginev1.Position_POSITION_DAY_BRANCH,
					Shinsal: enginev1.Shinsal_SHINSAL_DOHWA, Judgment: rawJudgment("personal.shinsal.dohwa"),
				},
				Text: text("personal.shinsal", "personal.shinsal.dohwa", "single", "도화가 있어요."),
			},
			{
				Reading: &enginev1.PersonalReading{
					Kind: enginev1.PersonalTermKind_PERSONAL_TERM_KIND_DAEUN_STEM_TEN_GOD, Judgment: rawJudgment("personal.luck.ten_god.bigyeon"),
				},
				Text: text("personal.luck", "personal.luck.ten_god.bigyeon", "single", "첫 대운이에요."),
			},
		},
	}
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
	require.NotNil(t, got.PersonalReadings)
	readings := *got.PersonalReadings
	require.Len(t, readings, 3)
	dayPos := gen.DayStem
	assert.Equal(t, gen.PersonalReadingKindDayMaster, readings[0].Kind)
	assert.Equal(t, &dayPos, readings[0].Position)
	assert.Nil(t, readings[0].Index, "의미 없는 index는 생략")
	assert.Nil(t, readings[0].Shinsal, "UNSPECIFIED 신살은 생략")
	assert.Equal(t, "내 일간은 큰 나무 같아요.", readings[0].Text.Segments[0].Text)
	branchPos, dohwa := gen.DayBranch, gen.Dohwa
	assert.Equal(t, gen.PersonalReadingKindShinsal, readings[1].Kind)
	assert.Equal(t, &branchPos, readings[1].Position)
	assert.Equal(t, &dohwa, readings[1].Shinsal)
	zero := 0
	assert.Equal(t, gen.PersonalReadingKindDaeunStemTenGod, readings[2].Kind)
	assert.Nil(t, readings[2].Position, "대운은 position이 없음")
	assert.Equal(t, &zero, readings[2].Index, "대운의 첫 번째 index 0은 담음")
	// 열려 있어도 판정 근거는 옮기지 않습니다.
	assert.NotContains(t, rec.Body.String(), rawEvidenceRule)
}

// 잠긴 응답에는 View가 자른 앞부분만 나가고(D106, S141), 열린 응답에는 미리보기 필드가 섞여 있어도 나가지 않습니다(방어).
func TestGetChart_PreviewsOnlyWhenLocked(t *testing.T) {
	response := chartResponse()
	prefix := []render.Segment{{Text: "조후로 보면"}}
	reading := fortune.PersonalReadingText{
		Reading: response.PersonalReadings[0],
		Text:    content.SlotText{Slot: "personal.day_master", MessageKey: "personal.day_master.gap", Variant: "single", Text: []render.Segment{{Text: "내 일간은"}}},
	}
	for _, unlocked := range []bool{false, true} {
		view := fortune.ChartView{
			Response: response, Unlocked: unlocked, Notices: []content.Notice{},
			YongsinBasisPreview: prefix, PersonalReadingPreviews: []fortune.PersonalReadingText{reading},
		}
		api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{chart: view}}

		req, rec, _ := getFortune(t, api, "/v1/chart")

		require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
		expectFortuneContract(t, req, rec)
		var got gen.Chart
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
		if unlocked {
			assert.Nil(t, got.Yongsin.BasisPreview)
			assert.Nil(t, got.PersonalReadingPreviews)
			continue
		}
		require.NotNil(t, got.Yongsin.BasisPreview)
		assert.Equal(t, "조후로 보면", got.Yongsin.BasisPreview.Segments[0].Text)
		assert.Nil(t, got.Yongsin.Basis)
		assert.Nil(t, got.PersonalReadings)
		require.NotNil(t, got.PersonalReadingPreviews)
		require.Len(t, *got.PersonalReadingPreviews, 1)
		assert.Equal(t, "내 일간은", (*got.PersonalReadingPreviews)[0].Text.Segments[0].Text)
	}
}

// 잠긴 오늘 화면은 근거 앞부분만 evidencePreview로 나가고 evidence는 없습니다. 열리면 evidencePreview가 섞여 있어도 나가지 않습니다.
func TestGetDaily_EvidencePreviewOnlyWhenLocked(t *testing.T) {
	for _, unlocked := range []bool{false, true} {
		view := dailyView()
		view.Unlocked = unlocked
		head := view.Texts[fortune.SlotFortuneHead]
		head.EvidencePreview = []content.EvidencePreview{{Basis: []render.Segment{{Text: "용신이 들어오는"}}}}
		view.Texts[fortune.SlotFortuneHead] = head
		api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{daily: view}, Contents: &fakeContents{}}

		req, rec, _ := getFortune(t, api, "/v1/daily/2026-10-13")

		require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
		expectFortuneContract(t, req, rec)
		body := rec.Body.String()
		if unlocked {
			assert.NotContains(t, body, "evidencePreview")
			continue
		}
		assert.Contains(t, body, `"evidencePreview":[{"basis":{"segments":[{"text":"용신이 들어오는"}]}}]`)
		assert.NotContains(t, body, `"evidence":`)
	}
}

func TestGetChart_UnknownPersonalReadingKindIs500(t *testing.T) {
	view := fortune.ChartView{
		Response: chartResponse(), Unlocked: true, Notices: []content.Notice{},
		PersonalReadings: []fortune.PersonalReadingText{{
			Reading: &enginev1.PersonalReading{Kind: enginev1.PersonalTermKind(99), Judgment: rawJudgment("personal.day_master.gap")},
			Text:    text("personal.day_master", "personal.day_master.gap", "single", "문장"),
		}},
	}
	api := &httpapi.API{Profiles: &fakeProfiles{profile: storedProfile()}, Readings: &fakeReadings{chart: view}}

	_, rec, _ := getFortune(t, api, "/v1/chart")

	assert.Equal(t, http.StatusInternalServerError, rec.Code, rec.Body.String())
}

func TestGetChart_PersonalReadingsIndexAndGates(t *testing.T) {
	reading := func(kind enginev1.PersonalTermKind, index int32, key string) fortune.PersonalReadingText {
		return fortune.PersonalReadingText{
			Reading: &enginev1.PersonalReading{Kind: kind, Position: enginev1.Position_POSITION_UNSPECIFIED, Index: index, Judgment: rawJudgment(key)},
			Text:    text("personal.x", key, "single", "문장"),
		}
	}
	hidden := reading(enginev1.PersonalTermKind_PERSONAL_TERM_KIND_HIDDEN_TEN_GOD, 1, "personal.hidden.a")
	hidden.Reading.Position = enginev1.Position_POSITION_DAY_BRANCH
	seun := reading(enginev1.PersonalTermKind_PERSONAL_TERM_KIND_SEUN_TEN_GOD, 2, "personal.luck.b")

	cases := []struct {
		name  string
		view  fortune.ChartView
		check func(t *testing.T, out gen.Chart, body string)
	}{
		{
			name: "index 담김",
			view: fortune.ChartView{Unlocked: true, PersonalReadings: []fortune.PersonalReadingText{hidden, seun}},
			check: func(t *testing.T, out gen.Chart, _ string) {
				require.NotNil(t, out.PersonalReadings)
				got := *out.PersonalReadings
				require.Len(t, got, 2)
				require.NotNil(t, got[0].Index)
				assert.Equal(t, 1, *got[0].Index)
				require.NotNil(t, got[1].Index)
				assert.Equal(t, 2, *got[1].Index)
				assert.Nil(t, got[1].Position)
			},
		},
		{
			name: "열림이고 비면 빈 배열",
			view: fortune.ChartView{Unlocked: true},
			check: func(t *testing.T, _ gen.Chart, body string) {
				assert.Contains(t, body, `"personalReadings":[]`)
			},
		},
		{
			name: "잠김이면 채워져 와도 뺌",
			view: fortune.ChartView{PersonalReadings: []fortune.PersonalReadingText{hidden}},
			check: func(t *testing.T, out gen.Chart, body string) {
				assert.Nil(t, out.PersonalReadings)
				assert.NotContains(t, body, "personalReadings")
			},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			tc.view.Response = chartResponse()
			tc.view.Notices = []content.Notice{}
			out, err := httpapi.ToChartForTest(tc.view)
			require.NoError(t, err)
			body, err := json.Marshal(out)
			require.NoError(t, err)
			tc.check(t, out, string(body))
		})
	}
}
