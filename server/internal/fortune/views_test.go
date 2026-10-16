package fortune_test

import (
	"bytes"
	"context"
	"log/slog"
	"maps"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/seed"
)

// viewDate는 화면 묶음 테스트의 기준 날짜입니다.
var viewDate = profile.LocalDate{Year: 2026, Month: 10, Day: 16}

// viewSlots는 테스트 시드의 슬롯 명세입니다. 화면 묶음이 쓰는 슬롯과 근거 문장 슬롯을 담습니다.
var viewSlots = map[string]seed.Slot{
	fortune.SlotFortuneHead: {ID: fortune.SlotFortuneHead, Vocative: true, Rotation: seed.RotationType},
	fortune.SlotFortuneTag:  {ID: fortune.SlotFortuneTag, Rotation: seed.RotationType},
	fortune.SlotGuide:       {ID: fortune.SlotGuide, Rotation: seed.RotationVariant},
	fortune.SlotColor: {ID: fortune.SlotColor, Rotation: seed.RotationNone, Params: map[string]seed.ParamKind{
		"element": {Kind: seed.KindCategory, Categories: []string{"element"}},
	}},
	fortune.SlotDirection:       {ID: fortune.SlotDirection, Rotation: seed.RotationNone},
	fortune.SlotNumber:          {ID: fortune.SlotNumber, Rotation: seed.RotationNone, Params: map[string]seed.ParamKind{"number": {Kind: seed.KindNumber}}},
	fortune.SlotFocusTime:       {ID: fortune.SlotFocusTime, Rotation: seed.RotationNone},
	fortune.SlotCharacterReason: {ID: fortune.SlotCharacterReason, Rotation: seed.RotationNone},
	fortune.SlotDayLevel:        {ID: fortune.SlotDayLevel, Rotation: seed.RotationNone, Params: map[string]seed.ParamKind{"score": {Kind: seed.KindNumber}}},
	fortune.SlotYongsinMethod:   {ID: fortune.SlotYongsinMethod, Rotation: seed.RotationNone},
	"explain.today_reason":      {ID: "explain.today_reason", Rotation: seed.RotationNone},
	"evidence.basis":            {ID: "evidence.basis", Rotation: seed.RotationNone},
	"evidence.source":           {ID: "evidence.source", Rotation: seed.RotationNone},
}

// tpl은 시드 문장 틀 하나를 만듭니다.
func tpl(slot, key, variant, lang, body string) seed.Template {
	return seed.Template{Slot: slot, Key: key, Variant: variant, Lang: lang, Body: body}
}

// viewTemplates는 테스트 시드의 문장 틀입니다. suffix는 시드 버전을 바꿀 때 ko·en 본문 끝에 붙입니다.
// skip에 든 (slot) 문장 틀은 모든 언어에서 뺍니다.
func viewTemplates(suffix string, skip ...string) []seed.Template {
	all := []seed.Template{
		tpl(fortune.SlotFortuneHead, "fortune.gwiin_day.inseong", content.VariantAdvice, "ko", "{name}님, 천천히 해 보세요."+suffix),
		tpl(fortune.SlotFortuneHead, "fortune.gwiin_day.inseong", content.VariantAdvice, "en", "{name}, take it slow."+suffix),
		tpl(fortune.SlotFortuneTag, "fortune.tag.dohwa", content.VariantAdvice, "ko", "사람을 만나 보세요."+suffix),
		tpl(fortune.SlotFortuneTag, "fortune.tag.dohwa", content.VariantAdvice, "en", "Meet someone."+suffix),
		tpl(fortune.SlotGuide, "guide.dohwa", "1", "ko", "눈길이 간 사람을 적어 볼까요?"+suffix),
		tpl(fortune.SlotGuide, "guide.dohwa", "1", "en", "Who caught your eye?"+suffix),
		tpl(fortune.SlotColor, "color.gwiin_day", seed.VariantSingle, "ko", "{element}색이 잘 맞아요."+suffix),
		tpl(fortune.SlotColor, "color.gwiin_day", seed.VariantSingle, "en", "{element} suits you."+suffix),
		tpl(fortune.SlotDirection, "direction.gwiin_day", seed.VariantSingle, "ko", "동쪽이 좋아요."+suffix),
		tpl(fortune.SlotDirection, "direction.gwiin_day", seed.VariantSingle, "en", "East is good."+suffix),
		tpl(fortune.SlotNumber, "number.gwiin_day", seed.VariantSingle, "ko", "행운의 숫자는 {number}예요."+suffix),
		tpl(fortune.SlotNumber, "number.gwiin_day", seed.VariantSingle, "en", "Your number is {number}."+suffix),
		tpl(fortune.SlotFocusTime, "focus_time.pick", seed.VariantSingle, "ko", "오전에 집중해 보세요."+suffix),
		tpl(fortune.SlotFocusTime, "focus_time.pick", seed.VariantSingle, "en", "Focus in the morning."+suffix),
		tpl(fortune.SlotCharacterReason, "character.reason.gwiin_day", seed.VariantSingle, "ko", "도움이 드는 날이에요."+suffix),
		tpl(fortune.SlotCharacterReason, "character.reason.gwiin_day", seed.VariantSingle, "en", "Help comes your way."+suffix),
		tpl(fortune.SlotCharacterReason, "character.reason.ordinary_day", seed.VariantSingle, "ko", "평범한 날이에요."+suffix),
		tpl(fortune.SlotDayLevel, "calendar.good", seed.VariantSingle, "ko", "잘 풀리는 날 {score}"+suffix),
		tpl(fortune.SlotDayLevel, "calendar.neutral", seed.VariantSingle, "ko", "보통인 날 {score}"+suffix),
		tpl(fortune.SlotYongsinMethod, "yongsin.method.eokbu", seed.VariantSingle, "ko", "힘의 균형으로 정했어요."+suffix),
		tpl("explain.today_reason", "reason.rule/a", seed.VariantSingle, "ko", "오늘 그런 이유예요."+suffix),
		tpl("explain.today_reason", "reason.rule/a", seed.VariantSingle, "en", "Here is why."+suffix),
		tpl("evidence.basis", "basis.rule/a", seed.VariantSingle, "ko", "판정 근거예요."+suffix),
		tpl("evidence.basis", "basis.rule/a", seed.VariantSingle, "en", "The basis."+suffix),
		tpl("glossary.value_name", "element.wood", seed.VariantSingle, "ko", "초록"),
		tpl("glossary.value_name", "element.wood", seed.VariantSingle, "en", "Green"),
	}
	out := make([]seed.Template, 0, len(all))
	for _, t := range all {
		if !slices.Contains(skip, t.Slot) {
			out = append(out, t)
		}
	}
	return out
}

// viewSeed는 테스트 시드를 만듭니다.
func viewSeed(t *testing.T, suffix string, skip ...string) seed.Seed {
	t.Helper()
	return viewSeedWithSlots(t, viewSlots, suffix, skip...)
}

// viewSeedWithSlots는 슬롯 명세를 바꾼 테스트 시드를 만듭니다.
func viewSeedWithSlots(t *testing.T, slots map[string]seed.Slot, suffix string, skip ...string) seed.Seed {
	t.Helper()
	s := seed.Seed{Slots: slots, Templates: viewTemplates(suffix, skip...)}
	require.NoError(t, s.Normalize())
	return s
}

// judgment는 근거 하나(rule/a)를 단 판정입니다.
func judgment(key string, params map[string]*enginev1.Param) *enginev1.Judgment {
	return &enginev1.Judgment{MessageKey: key, Params: params, Evidence: []*enginev1.Evidence{{RuleId: "rule/a"}}}
}

func textParam(s string) *enginev1.Param {
	return &enginev1.Param{Value: &enginev1.Param_Text{Text: s}}
}
func intParam(n int64) *enginev1.Param {
	return &enginev1.Param{Value: &enginev1.Param_Integer{Integer: n}}
}

// plain은 조각 배열을 이은 문장입니다.
func plain(segs []render.Segment) string {
	var b strings.Builder
	for _, s := range segs {
		b.WriteString(s.Text)
	}
	return b.String()
}

// dailyResponse는 슬롯 판정을 모두 채운 데일리 응답입니다. withTag면 총운 보조 문장(fortune[1])을 더합니다.
func dailyResponse(withTag bool, notices ...enginev1.NoticeCode) *enginev1.DailyResponse {
	fortunes := []*enginev1.Judgment{judgment("fortune.gwiin_day.inseong", nil)}
	if withTag {
		fortunes = append(fortunes, judgment("fortune.tag.dohwa", nil))
	}
	meta := &enginev1.ResponseMeta{RulesetVersion: "rs-1"}
	for _, code := range notices {
		meta.Notices = append(meta.Notices, &enginev1.Notice{Code: code})
	}
	return &enginev1.DailyResponse{
		Kind:      enginev1.DayKind_DAY_KIND_GWIIN_DAY,
		Fortune:   fortunes,
		Guide:     judgment("guide.dohwa", nil),
		Color:     &enginev1.ColorCard{Judgment: judgment("color.gwiin_day", map[string]*enginev1.Param{"element": textParam("WOOD")})},
		Direction: &enginev1.DirectionCard{Judgment: judgment("direction.gwiin_day", nil)},
		Number:    &enginev1.NumberCard{Judgment: judgment("number.gwiin_day", map[string]*enginev1.Param{"number": intParam(3)})},
		FocusTime: &enginev1.FocusTimeCard{Judgment: judgment("focus_time.pick", nil)},
		Meta:      meta,
	}
}

// fakeInsight는 정해진 권한을 돌려주는 fortune.Insight입니다.
type fakeInsight struct{ unlocked bool }

func (f fakeInsight) Unlocked(context.Context, uuid.UUID) (bool, error) { return f.unlocked, nil }

// viewsFixture는 화면 묶음 테스트 환경입니다.
type viewsFixture struct {
	pool    *pgxpool.Pool
	views   *fortune.Views
	account uuid.UUID
	logs    *bytes.Buffer
	// restart는 빈 캐시의 콘텐츠 저장소로 Views를 새로 만듭니다(새 시드를 배포한 뒤 뜬 새 인스턴스).
	restart func() *fortune.Views
}

// newViewsFixture는 s를 적용한 DB(s.Version이 비면 적용하지 않음)와 fake 엔진으로 Views를 만듭니다.
func newViewsFixture(t *testing.T, fake *enginetest.Fake, s seed.Seed, insight fortune.Insight) *viewsFixture {
	t.Helper()
	ctx := context.Background()
	pool := dbtest.New(t)
	if s.Version != "" {
		_, err := content.Apply(ctx, pool, s)
		require.NoError(t, err)
	}
	var account uuid.UUID
	require.NoError(t, pool.QueryRow(ctx,
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&account))

	var logs bytes.Buffer
	log := slog.New(slog.NewTextHandler(&logs, nil))
	clk := clocktest.New(time.Date(2026, 10, 16, 0, 30, 0, 0, time.UTC))
	service := fortune.NewService(fake, newVersions(t, fake), fortune.NewPostgresCache(pool), discardLogger())
	build := func() *fortune.Views {
		return fortune.NewViews(service, content.NewStore(pool, clk, log), content.NewRenderer(log), insight, clk, log)
	}
	return &viewsFixture{pool: pool, views: build(), account: account, logs: &logs, restart: build}
}

func viewProfile(lang string) profile.Profile {
	return profile.Profile{Honorific: "민지", Language: lang, CurrentTimezone: "Asia/Seoul", Birth: testBirth()}
}

func dailyFake(withTag bool, notices ...enginev1.NoticeCode) *enginetest.Fake {
	return &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		return dailyResponse(withTag, notices...), nil
	}}
}

func TestViews_DailyFillsAllSlots(t *testing.T) {
	cases := []struct {
		name    string
		withTag bool
		slots   []string
	}{
		{
			name: "보조 문장 있음", withTag: true,
			slots: []string{
				fortune.SlotFortuneHead, fortune.SlotFortuneTag, fortune.SlotGuide, fortune.SlotColor,
				fortune.SlotDirection, fortune.SlotNumber, fortune.SlotFocusTime, fortune.SlotCharacterReason,
			},
		},
		{
			name: "보조 문장 없음", withTag: false,
			slots: []string{
				fortune.SlotFortuneHead, fortune.SlotGuide, fortune.SlotColor,
				fortune.SlotDirection, fortune.SlotNumber, fortune.SlotFocusTime, fortune.SlotCharacterReason,
			},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s := viewSeed(t, "")
			f := newViewsFixture(t, dailyFake(tc.withTag), s, fortune.AlwaysLocked{})

			view, err := f.views.Daily(context.Background(), f.account, viewProfile("ko"), viewDate)
			require.NoError(t, err)

			got := make([]string, 0, len(view.Texts))
			for slot := range view.Texts {
				got = append(got, slot)
			}
			assert.ElementsMatch(t, tc.slots, got)
			assert.Equal(t, "rs-1", view.Response.GetMeta().GetRulesetVersion())
			assert.Empty(t, f.logs.String())

			head := view.Texts[fortune.SlotFortuneHead]
			assert.Equal(t, "민지님, 천천히 해 보세요.", plain(head.Text), "호칭은 호칭 슬롯에만")
			assert.Equal(t, content.VariantAdvice, head.Variant)
			assert.True(t, head.Reactable)
			assert.Equal(t, "1", view.Texts[fortune.SlotGuide].Variant)
			assert.Equal(t, "초록색이 잘 맞아요.", plain(view.Texts[fortune.SlotColor].Text))
			assert.Equal(t, "행운의 숫자는 3예요.", plain(view.Texts[fortune.SlotNumber].Text))
			reason := view.Texts[fortune.SlotCharacterReason]
			assert.Equal(t, "character.reason.gwiin_day", reason.MessageKey)
			assert.Equal(t, "도움이 드는 날이에요.", plain(reason.Text))

			// 선택 기록은 문장 슬롯마다 하나씩이고, SelectionIDs는 그 기록의 ID와 같습니다.
			recorded := map[string]int64{}
			rows, err := f.pool.Query(context.Background(),
				"SELECT slot, id FROM daily_selections WHERE account_id = $1", f.account)
			require.NoError(t, err)
			for rows.Next() {
				var slot string
				var id int64
				require.NoError(t, rows.Scan(&slot, &id))
				recorded[slot] = id
			}
			require.NoError(t, rows.Err())
			assert.Len(t, recorded, len(tc.slots))
			assert.Equal(t, recorded, view.SelectionIDs)
			assert.NotZero(t, view.SelectionIDs[fortune.SlotFortuneHead], "반응 대상 슬롯의 기록 ID")
		})
	}
}

func TestViews_DailyLockedDropsEvidence(t *testing.T) {
	f := newViewsFixture(t, dailyFake(true), viewSeed(t, ""), fortune.AlwaysLocked{})

	view, err := f.views.Daily(context.Background(), f.account, viewProfile("ko"), viewDate)
	require.NoError(t, err)

	assert.False(t, view.Unlocked)
	for slot, text := range view.Texts {
		assert.Nil(t, text.Evidence, slot)
	}
	// 오늘 그런 이유는 explain 깊이라 잠그지 않습니다.
	assert.Equal(t, "오늘 그런 이유예요.", plain(view.Texts[fortune.SlotFortuneHead].TodayReason))
}

func TestViews_DailyUnlockedKeepsEvidence(t *testing.T) {
	f := newViewsFixture(t, dailyFake(true), viewSeed(t, ""), fakeInsight{unlocked: true})

	view, err := f.views.Daily(context.Background(), f.account, viewProfile("ko"), viewDate)
	require.NoError(t, err)

	assert.True(t, view.Unlocked)
	head := view.Texts[fortune.SlotFortuneHead]
	require.Len(t, head.Evidence, 1)
	assert.Equal(t, "rule/a", head.Evidence[0].RuleID)
	assert.Equal(t, "판정 근거예요.", plain(head.Evidence[0].Basis))
	assert.Equal(t, "오늘 그런 이유예요.", plain(head.TodayReason))
}

// 언어를 바꾸면 같은 (키, 변주, 시드 버전)을 새 언어로 렌더합니다(Review Focus 5).
// 그 사이 새 시드가 활성이 되어도 이미 고른 문장은 고른 때의 시드 버전으로 렌더합니다.
func TestViews_LanguageChangeKeepsSelection(t *testing.T) {
	oldSeed := viewSeed(t, "")
	f := newViewsFixture(t, dailyFake(true), oldSeed, fortune.AlwaysLocked{})
	ctx := context.Background()

	first, err := f.views.Daily(ctx, f.account, viewProfile("ko"), viewDate)
	require.NoError(t, err)
	require.Equal(t, content.VariantAdvice, first.Texts[fortune.SlotFortuneHead].Variant)

	newSeed := viewSeed(t, " (new)")
	_, err = content.Apply(ctx, f.pool, newSeed)
	require.NoError(t, err)

	second, err := f.views.Daily(ctx, f.account, viewProfile("en"), viewDate)
	require.NoError(t, err)

	head := second.Texts[fortune.SlotFortuneHead]
	assert.Equal(t, content.VariantAdvice, head.Variant, "변주는 그대로")
	assert.Equal(t, "fortune.gwiin_day.inseong", head.MessageKey)
	assert.Equal(t, "민지, take it slow.", plain(head.Text), "옛 시드 버전의 en 문장")
	assert.Equal(t, "Who caught your eye?", plain(second.Texts[fortune.SlotGuide].Text))
	assert.Empty(t, f.logs.String())

	var next string
	require.NoError(t, f.pool.QueryRow(ctx,
		"SELECT next_variant FROM rotation_state WHERE account_id = $1 AND message_key = $2",
		f.account, "fortune.gwiin_day.inseong").Scan(&next))
	assert.Equal(t, content.VariantState, next, "다시 열어도 순환은 한 번만 넘어감")

	// 원고가 없는 언어(ja)로 바꿔도 오류가 아닙니다. 필수 슬롯은 빈 segments, 선택 슬롯(보조 문장)은 빠지고,
	// 고른 variant는 그대로이며, 원고가 없는 슬롯마다 Error 로그가 하나씩 남습니다(다른 언어로 폴백하지 않음).
	t.Run("원고 없는 언어", func(t *testing.T) {
		f.logs.Reset()
		third, err := f.views.Daily(ctx, f.account, viewProfile("ja"), viewDate)
		require.NoError(t, err)

		required := []string{
			fortune.SlotFortuneHead, fortune.SlotGuide, fortune.SlotColor, fortune.SlotDirection,
			fortune.SlotNumber, fortune.SlotFocusTime, fortune.SlotCharacterReason,
		}
		got := make([]string, 0, len(third.Texts))
		for slot := range third.Texts {
			got = append(got, slot)
		}
		assert.ElementsMatch(t, required, got, "선택 슬롯(보조 문장)은 생략")
		for _, slot := range required {
			text := third.Texts[slot]
			assert.NotNil(t, text.Text, slot)
			assert.Empty(t, text.Text, slot)
			assert.Equal(t, second.Texts[slot].Variant, text.Variant, slot)
		}
		assert.Contains(t, third.SelectionIDs, fortune.SlotFortuneTag, "선택 기록은 그대로 있음")

		logs := f.logs.String()
		assert.Equal(t, len(required)+1, strings.Count(logs, "level=ERROR"), logs)
		for _, slot := range append(required, fortune.SlotFortuneTag) {
			assert.Equal(t, 1, strings.Count(logs, "slot="+slot+" "), slot)
		}
	})
}

// 옛 시드 버전으로 고른 문장은 그 버전의 슬롯 명세로 렌더합니다.
// 새 시드에서 숫자 카드의 매개변수 값 종류를 none으로 바꾸면 새 명세로는 {number}를 렌더할 수 없습니다.
func TestViews_OldSelectionUsesOldSlotSpec(t *testing.T) {
	oldSeed := viewSeed(t, "")
	f := newViewsFixture(t, dailyFake(true), oldSeed, fortune.AlwaysLocked{})
	ctx := context.Background()

	_, err := f.views.Daily(ctx, f.account, viewProfile("ko"), viewDate)
	require.NoError(t, err)

	changed := maps.Clone(viewSlots)
	number := changed[fortune.SlotNumber]
	number.Params = map[string]seed.ParamKind{"number": {Kind: seed.KindNone}}
	changed[fortune.SlotNumber] = number
	newSeed := viewSeedWithSlots(t, changed, " (new)")
	_, err = content.Apply(ctx, f.pool, newSeed)
	require.NoError(t, err)

	// 새 인스턴스는 옛 버전의 문장 틀·명세를 아직 캐시하지 않았으므로, 옛 기록을 렌더할 때 DB에서 그 버전의 명세를 읽습니다.
	views := f.restart()
	again, err := views.Daily(ctx, f.account, viewProfile("ko"), viewDate)
	require.NoError(t, err)
	assert.Equal(t, "행운의 숫자는 3예요.", plain(again.Texts[fortune.SlotNumber].Text), "옛 버전의 문장 틀과 명세")
	assert.Empty(t, f.logs.String())

	// 다른 날은 새로 고르므로 새 시드의 명세로 렌더하고, {number}를 쓸 수 없어 빈 문장과 Error 로그가 됩니다(대조군).
	next, err := views.Daily(ctx, f.account, viewProfile("ko"), profile.LocalDate{Year: 2026, Month: 10, Day: 17})
	require.NoError(t, err)
	assert.Empty(t, next.Texts[fortune.SlotNumber].Text)
	assert.Contains(t, f.logs.String(), "slot="+fortune.SlotNumber)
}

// 원고가 없는 슬롯은 응답 전체를 실패시키지 않습니다(Review Focus 4).
// 필수 문장 필드는 빈 segments로 채우고 선택 필드는 빼며, 로그는 Renderer가 남긴 하나뿐입니다.
func TestViews_DailyMissingTemplate(t *testing.T) {
	cases := []struct {
		name    string
		slot    string
		present bool
		variant string // present일 때 기대하는 variant(선택 기록의 variant)
	}{
		{name: "필수 필드(숫자 카드)", slot: fortune.SlotNumber, present: true, variant: seed.VariantSingle},
		{name: "필수 필드(날의 성격 이유)", slot: fortune.SlotCharacterReason, present: true, variant: seed.VariantSingle},
		{name: "필수 필드(호칭·순환 슬롯 총운)", slot: fortune.SlotFortuneHead, present: true, variant: content.VariantAdvice},
		{name: "선택 필드(총운 보조 문장)", slot: fortune.SlotFortuneTag, present: false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newViewsFixture(t, dailyFake(true), viewSeed(t, "", tc.slot), fortune.AlwaysLocked{})

			view, err := f.views.Daily(context.Background(), f.account, viewProfile("ko"), viewDate)
			require.NoError(t, err)

			text, ok := view.Texts[tc.slot]
			require.Equal(t, tc.present, ok)
			if tc.present {
				assert.NotNil(t, text.Text)
				assert.Empty(t, text.Text)
				assert.Equal(t, tc.slot, text.Slot)
				assert.NotEmpty(t, text.MessageKey)
				assert.Equal(t, tc.variant, text.Variant)
				assert.Equal(t, content.Reactable(tc.slot), text.Reactable)
			}
			assert.Equal(t, 1, strings.Count(f.logs.String(), "level=ERROR"), f.logs.String())
		})
	}
}

func TestViews_CalendarDaysRenderLevelAndReason(t *testing.T) {
	fake := &enginetest.Fake{MonthCalendar: func(*enginev1.MonthRequest) (*enginev1.MonthResponse, error) {
		return &enginev1.MonthResponse{
			Meta: &enginev1.ResponseMeta{RulesetVersion: "rs-1"},
			Days: []*enginev1.MonthDay{
				{Kind: enginev1.DayKind_DAY_KIND_GWIIN_DAY, Judgment: judgment("calendar.good", map[string]*enginev1.Param{"score": intParam(80)})},
				{Kind: enginev1.DayKind_DAY_KIND_ORDINARY_DAY, Judgment: judgment("calendar.neutral", map[string]*enginev1.Param{"score": intParam(50)})},
			},
		}, nil
	}}
	cases := []struct {
		name     string
		unlocked bool
	}{
		{name: "잠김", unlocked: false},
		{name: "열림", unlocked: true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newViewsFixture(t, fake, viewSeed(t, ""), fakeInsight{unlocked: tc.unlocked})

			view, err := f.views.Calendar(context.Background(), f.account, viewProfile("ko"), 2026, 10)
			require.NoError(t, err)

			assert.Equal(t, tc.unlocked, view.Unlocked)
			require.Len(t, view.Days, 2)
			assert.Equal(t, "도움이 드는 날이에요.", plain(view.Days[0].CharacterReason.Text))
			assert.Equal(t, "잘 풀리는 날 80", plain(view.Days[0].Level.Text))
			assert.Equal(t, "평범한 날이에요.", plain(view.Days[1].CharacterReason.Text))
			assert.Equal(t, "보통인 날 50", plain(view.Days[1].Level.Text))
			assert.Equal(t, seed.VariantSingle, view.Days[0].Level.Variant)
			// 오늘 그런 이유는 데일리처럼 잠금과 상관없이 남습니다.
			assert.Equal(t, "오늘 그런 이유예요.", plain(view.Days[0].Level.TodayReason))
			if tc.unlocked {
				assert.Len(t, view.Days[0].Level.Evidence, 1)
			} else {
				assert.Nil(t, view.Days[0].Level.Evidence)
			}

			var rows int
			require.NoError(t, f.pool.QueryRow(context.Background(),
				"SELECT count(*) FROM daily_selections WHERE account_id = $1", f.account).Scan(&rows))
			assert.Zero(t, rows, "캘린더는 선택 기록을 남기지 않음")
		})
	}
}

func TestViews_ChartYongsinBasisLocked(t *testing.T) {
	fake := &enginetest.Fake{Chart: func(*enginev1.ChartRequest) (*enginev1.ChartResponse, error) {
		return &enginev1.ChartResponse{
			Meta:    &enginev1.ResponseMeta{RulesetVersion: "rs-1"},
			Yongsin: &enginev1.YongsinInfo{Judgment: judgment("yongsin.method.eokbu", nil)},
		}, nil
	}}
	cases := []struct {
		name     string
		unlocked bool
	}{
		{name: "잠김", unlocked: false},
		{name: "열림", unlocked: true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newViewsFixture(t, fake, viewSeed(t, ""), fakeInsight{unlocked: tc.unlocked})

			view, err := f.views.Chart(context.Background(), f.account, viewProfile("ko"))
			require.NoError(t, err)

			assert.Equal(t, tc.unlocked, view.Unlocked)
			require.NotNil(t, view.Response)
			if !tc.unlocked {
				assert.Nil(t, view.YongsinBasis)
				return
			}
			require.NotNil(t, view.YongsinBasis)
			assert.Equal(t, "힘의 균형으로 정했어요.", plain(view.YongsinBasis.Text))
			assert.Nil(t, view.YongsinBasis.Evidence, "용신 근거 문장 자체가 근거라 그 안의 근거는 렌더하지 않음")
		})
	}
}

func TestViews_ChartAsOfIsTodayInCurrentTimezone(t *testing.T) {
	var got *enginev1.LocalDate
	fake := &enginetest.Fake{Chart: func(req *enginev1.ChartRequest) (*enginev1.ChartResponse, error) {
		got = req.GetAsOf()
		return &enginev1.ChartResponse{Meta: &enginev1.ResponseMeta{RulesetVersion: "rs-1"}}, nil
	}}
	f := newViewsFixture(t, fake, viewSeed(t, ""), fortune.AlwaysLocked{})
	p := viewProfile("ko")
	p.CurrentTimezone = "America/Los_Angeles" // 시계는 UTC 2026-10-16 00:30, 이 시간대로는 10월 15일

	_, err := f.views.Chart(context.Background(), f.account, p)
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.EqualValues(t, 15, got.GetDay())
}

// 잠긴 요청은 근거를 렌더하지 않으므로, 근거 원고가 없어도 Error 로그가 남지 않습니다.
// 열린 요청은 같은 조건에서 로그가 남습니다(대조군).
func TestViews_LockedSkipsEvidenceRendering(t *testing.T) {
	fake := dailyFake(true)
	fake.MonthCalendar = func(*enginev1.MonthRequest) (*enginev1.MonthResponse, error) {
		return &enginev1.MonthResponse{
			Meta: &enginev1.ResponseMeta{RulesetVersion: "rs-1"},
			Days: []*enginev1.MonthDay{{Kind: enginev1.DayKind_DAY_KIND_GWIIN_DAY,
				Judgment: judgment("calendar.good", map[string]*enginev1.Param{"score": intParam(80)})}},
		}, nil
	}
	cases := []struct {
		name     string
		unlocked bool
		call     func(f *viewsFixture) error
	}{
		{name: "daily 잠김", call: func(f *viewsFixture) error {
			_, err := f.views.Daily(context.Background(), f.account, viewProfile("ko"), viewDate)
			return err
		}},
		{name: "calendar 잠김", call: func(f *viewsFixture) error {
			_, err := f.views.Calendar(context.Background(), f.account, viewProfile("ko"), 2026, 10)
			return err
		}},
		{name: "daily 열림", unlocked: true, call: func(f *viewsFixture) error {
			_, err := f.views.Daily(context.Background(), f.account, viewProfile("ko"), viewDate)
			return err
		}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newViewsFixture(t, fake, viewSeed(t, "", "evidence.basis"), fakeInsight{unlocked: tc.unlocked})

			require.NoError(t, tc.call(f))
			if tc.unlocked {
				assert.Contains(t, f.logs.String(), "evidence.basis")
			} else {
				assert.Empty(t, f.logs.String())
			}
		})
	}
}

func TestViews_CalendarMissingJudgmentIsError(t *testing.T) {
	fake := &enginetest.Fake{MonthCalendar: func(*enginev1.MonthRequest) (*enginev1.MonthResponse, error) {
		return &enginev1.MonthResponse{
			Meta: &enginev1.ResponseMeta{RulesetVersion: "rs-1"},
			Days: []*enginev1.MonthDay{{Kind: enginev1.DayKind_DAY_KIND_GWIIN_DAY}},
		}, nil
	}}
	f := newViewsFixture(t, fake, viewSeed(t, ""), fortune.AlwaysLocked{})

	_, err := f.views.Calendar(context.Background(), f.account, viewProfile("ko"), 2026, 10)
	assert.ErrorContains(t, err, "길흉 판정이 없습니다")
}

// 엔진 안내 문구 슬롯이 아직 없어 notice는 code와 빈(nil 아닌) segments로 나갑니다(P4-9).
func TestViews_NoticeWithoutTemplateHasEmptyText(t *testing.T) {
	notices := []enginev1.NoticeCode{enginev1.NoticeCode_NOTICE_CODE_TIME_UNKNOWN, enginev1.NoticeCode_NOTICE_CODE_FOCUS_TIME_FALLBACK}
	fake := dailyFake(false, notices...)
	fake.Chart = func(*enginev1.ChartRequest) (*enginev1.ChartResponse, error) {
		return &enginev1.ChartResponse{Meta: &enginev1.ResponseMeta{
			RulesetVersion: "rs-1",
			Notices:        []*enginev1.Notice{{Code: enginev1.NoticeCode_NOTICE_CODE_DAYUN_START_APPROXIMATE}},
		}}, nil
	}
	f := newViewsFixture(t, fake, viewSeed(t, ""), fortune.AlwaysLocked{})
	ctx := context.Background()

	daily, err := f.views.Daily(ctx, f.account, viewProfile("ko"), viewDate)
	require.NoError(t, err)
	require.Len(t, daily.Notices, 2)
	assert.Equal(t, "time_unknown", daily.Notices[0].Code)
	assert.Equal(t, "focus_time_fallback", daily.Notices[1].Code)
	for _, n := range daily.Notices {
		assert.NotNil(t, n.Text)
		assert.Empty(t, n.Text)
	}

	chart, err := f.views.Chart(ctx, f.account, viewProfile("ko"))
	require.NoError(t, err)
	require.Len(t, chart.Notices, 1)
	assert.Equal(t, "dayun_start_approximate", chart.Notices[0].Code)
	assert.NotNil(t, chart.Notices[0].Text)
}

func TestViews_NoActiveSeedIsErrNoActiveSeed(t *testing.T) {
	f := newViewsFixture(t, dailyFake(true), seed.Seed{}, fortune.AlwaysLocked{})
	ctx := context.Background()
	p := viewProfile("ko")

	cases := []struct {
		name string
		call func() error
	}{
		{name: "daily", call: func() error { _, err := f.views.Daily(ctx, f.account, p, viewDate); return err }},
		{name: "calendar", call: func() error { _, err := f.views.Calendar(ctx, f.account, p, 2026, 10); return err }},
		{name: "chart", call: func() error { _, err := f.views.Chart(ctx, f.account, p); return err }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			assert.ErrorIs(t, tc.call(), content.ErrNoActiveSeed)
		})
	}
}

func TestViews_EngineErrorPassesThrough(t *testing.T) {
	fake := &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		return nil, engine.ErrOutOfRange
	}}
	f := newViewsFixture(t, fake, viewSeed(t, ""), fortune.AlwaysLocked{})

	_, err := f.views.Daily(context.Background(), f.account, viewProfile("ko"), viewDate)
	assert.ErrorIs(t, err, engine.ErrOutOfRange)
}

func TestAlwaysLocked_IsLocked(t *testing.T) {
	unlocked, err := fortune.AlwaysLocked{}.Unlocked(context.Background(), uuid.New())
	require.NoError(t, err)
	assert.False(t, unlocked)
}
