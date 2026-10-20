package fortune

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/seed"
)

// 화면 묶음이 쓰는 writing 슬롯 id입니다. 원본은 writing 슬롯 명세(docs/identity/writing/slots/content/)입니다.
const (
	SlotFortuneHead     = content.SlotFortuneHead
	SlotFortuneTag      = content.SlotFortuneTag
	SlotGuide           = "daily.guide"
	SlotColor           = "daily.color"
	SlotDirection       = "daily.direction"
	SlotNumber          = "daily.number"
	SlotFocusTime       = "daily.focus_time"
	SlotCharacterReason = "character.reason"
	SlotDayLevel        = "calendar.day_level"
	SlotYongsinMethod   = "chart.yongsin_method"
	SlotNotice          = "system.notice"
)

// characterReasonPrefix는 날의 성격 이유 키의 앞부분입니다. 키는 character.reason.<day_kind>입니다(슬롯 명세 select).
const characterReasonPrefix = "character.reason."

// personalKeyPrefix는 개인 해석 판정 키의 앞부분입니다. 슬롯 id는 키의 앞 두 마디입니다(예: personal.day_master.gap → personal.day_master).
const personalKeyPrefix = "personal."

// noticeKeyPrefix는 엔진 안내 문구 키의 앞부분입니다. 키는 notice.<계약 NoticeCode 값>입니다(슬롯 명세 select).
const noticeKeyPrefix = "notice."

// ContentStore는 Views가 쓰는 콘텐츠 저장소 기능입니다. *content.Store가 만족합니다.
type ContentStore interface {
	Active(ctx context.Context) (string, error)
	Templates(ctx context.Context, version, lang string) (content.Templates, error)
	Select(ctx context.Context, accountID uuid.UUID, date time.Time, birthHash [32]byte,
		reqs []content.SlotRequest) ([]content.Selection, error)
}

var _ ContentStore = (*content.Store)(nil)

// DailyView는 오늘 화면 하나의 묶음입니다. 엔진 응답과 슬롯 id별 문장을 함께 담습니다.
type DailyView struct {
	Response *enginev1.DailyResponse
	// Texts는 슬롯 id → 문장입니다. 총운 보조 문장(SlotFortuneTag)은 엔진이 보조 판정을 줬고 원고가 있을 때만 있습니다.
	// 나머지 슬롯은 늘 있고, 원고가 없으면 Text가 빈 조각 배열입니다.
	Texts   map[string]content.SlotText
	Notices []content.Notice
	// Unlocked는 근거 열람 권한입니다. false면 모든 Texts의 Evidence가 nil입니다(근거를 렌더하지 않음).
	Unlocked bool
	// SelectionIDs는 슬롯 id → 그 슬롯 선택 기록(daily_selections)의 ID입니다. 문장 반응을 표시·저장할 때 씁니다.
	// 선택 기록은 문장 슬롯마다 남으므로, 원고가 없어 Texts에서 빠진 선택 슬롯도 여기에는 있습니다.
	SelectionIDs map[string]int64
}

// DayTexts는 달력 하루의 문장입니다. 계약에서 둘 다 필수라 원고가 없으면 Text가 빈 조각 배열입니다.
type DayTexts struct {
	// CharacterReason은 날의 성격 이유(character.reason.<day_kind>)입니다.
	CharacterReason content.SlotText
	// Level은 길흉 수준(calendar.day_level, 키는 MonthDay.judgment의 메시지 키)입니다.
	Level content.SlotText
}

// CalendarView는 한 달 달력의 묶음입니다. Days는 Response.Days와 같은 순서·길이입니다.
type CalendarView struct {
	Response *enginev1.MonthResponse
	Days     []DayTexts
	Notices  []content.Notice
	Unlocked bool
}

// ChartView는 나의 사주 화면의 묶음입니다.
type ChartView struct {
	Response *enginev1.ChartResponse
	// YongsinBasis는 용신 근거 문장(chart.yongsin_method)입니다. evidence 깊이라 잠겨 있거나 원고가 없으면 nil입니다.
	// 이 문장이 곧 근거라 그 안의 Evidence(판정 근거·원전 문장)는 렌더하지 않아 늘 nil입니다(계약 Yongsin.basis는 문장 하나).
	YongsinBasis *content.SlotText
	// PersonalReadings는 원국 개인 해석("내 사주에서는")입니다. 엔진 순서를 따릅니다.
	// evidence 깊이라 잠겨 있으면 nil이고, 원고가 없거나 키가 잘못된 항목은 빠집니다.
	PersonalReadings []PersonalReadingText
	Notices          []content.Notice
	Unlocked         bool
}

// PersonalReadingText는 개인 해석 한 항목과 그 렌더된 문장입니다. Reading의 식별자(종류·위치·순서·신살)로 앱이 항목을 찾습니다.
type PersonalReadingText struct {
	Reading *enginev1.PersonalReading
	Text    content.SlotText
}

// Views는 엔진 결과(Service)와 콘텐츠(문장 선택·렌더)를 묶어 화면별 묶음을 만듭니다.
type Views struct {
	service  *Service
	store    ContentStore
	renderer *content.Renderer
	insight  Insight
	clock    clock.Clock
	log      *slog.Logger
}

// NewViews는 Views를 만듭니다. 슬롯 명세는 렌더하는 시드 버전의 것을 store에서 읽습니다
// (문장 틀의 Templates.Slot, 문장 선택의 순환 방식은 Select 안에서).
func NewViews(service *Service, store ContentStore, renderer *content.Renderer, insight Insight, clk clock.Clock, log *slog.Logger) *Views {
	return &Views{service: service, store: store, renderer: renderer, insight: insight, clock: clk, log: log}
}

// dailySlot은 오늘 화면 슬롯 하나의 렌더 입력입니다.
type dailySlot struct {
	id  string
	key string
	// judgment가 nil이면 식별자 키 슬롯(character.reason)이라 key로 렌더합니다.
	judgment *enginev1.Judgment
	// required는 계약에서 필수 문장 필드인지입니다. 필수면 원고가 없어도 빈 문장으로 채웁니다.
	required bool
}

// Daily는 date의 오늘 화면 묶음을 만듭니다.
//
// 슬롯마다 선택 기록(content.Store.Select)이 정한 variant와 그 기록의 시드 버전(문장 틀과 슬롯 명세)으로 p.Language 문장을 렌더합니다.
// 그래서 언어를 바꿔 다시 열면 같은 (키, 변주, 시드 버전)이 새 언어로 나옵니다.
// 활성 시드가 없으면 content.ErrNoActiveSeed, 엔진 오류는 그대로 돌려줍니다.
func (v *Views) Daily(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (DailyView, error) {
	// 활성 시드가 없으면 엔진을 부르기 전에 빨리 503으로 끝내려고 먼저 봅니다. 렌더할 버전은 선택 기록이 정합니다.
	// 엔진 안내는 선택 기록이 없어 활성 시드로 렌더합니다.
	active, err := v.store.Active(ctx)
	if err != nil {
		return DailyView{}, err
	}
	response, err := v.service.Daily(ctx, p.Birth, date, p.CurrentTimezone)
	if err != nil {
		return DailyView{}, err
	}
	unlocked, err := v.unlocked(ctx, accountID)
	if err != nil {
		return DailyView{}, err
	}
	slots, err := dailySlots(response)
	if err != nil {
		return DailyView{}, err
	}

	reqs := make([]content.SlotRequest, len(slots))
	for i, s := range slots {
		reqs[i] = content.SlotRequest{Slot: s.id, MessageKey: s.key}
	}
	dateTime := time.Date(date.Year, time.Month(date.Month), date.Day, 0, 0, 0, 0, time.UTC)
	selections, err := v.store.Select(ctx, accountID, dateTime, profile.BirthHash(p.Birth), reqs)
	if err != nil {
		return DailyView{}, err
	}

	// 선택 기록마다 시드 버전이 다를 수 있어(그 사이 새 시드가 활성이 됨) 버전별 문장 틀·슬롯 명세를 한 번씩만 읽습니다.
	byVersion := map[string]content.Templates{}
	texts := make(map[string]content.SlotText, len(slots))
	ids := make(map[string]int64, len(selections))
	for i, sel := range selections {
		ids[sel.Slot] = sel.ID
		tpl, ok := byVersion[sel.SeedVersion]
		if !ok {
			tpl, err = v.store.Templates(ctx, sel.SeedVersion, p.Language)
			if err != nil {
				return DailyView{}, err
			}
			byVersion[sel.SeedVersion] = tpl
		}
		text, ok := v.renderDaily(ctx, tpl, slots[i], sel.Variant, p.Honorific, unlocked)
		if !ok {
			// 실패 로그는 Renderer가 이미 남겼습니다.
			if !slots[i].required {
				continue
			}
			text = emptyText(sel.Slot, sel.MessageKey, sel.Variant)
		}
		texts[sel.Slot] = text
	}
	notices, err := v.notices(ctx, active, p.Language, response.GetMeta())
	if err != nil {
		return DailyView{}, err
	}
	return DailyView{
		Response:     response,
		Texts:        texts,
		Notices:      notices,
		Unlocked:     unlocked,
		SelectionIDs: ids,
	}, nil
}

// renderDaily는 슬롯 하나를 렌더합니다. 호칭은 Renderer가 호칭 슬롯에만 씁니다.
// 근거는 권한이 있을 때(unlocked)만 렌더합니다. 식별자 키 슬롯에는 근거가 없습니다.
func (v *Views) renderDaily(ctx context.Context, tpl content.Templates, s dailySlot, variant, name string, unlocked bool) (content.SlotText, bool) {
	if s.judgment == nil {
		return v.renderer.Identifier(ctx, tpl, s.id, s.key, nil)
	}
	return v.renderer.Slot(ctx, tpl, s.id, variant, s.judgment, name, unlocked)
}

// dailySlots는 데일리 응답에서 문장 슬롯 목록을 만듭니다(P4-3의 8개 슬롯).
// 총운 보조 문장은 fortune[1]이 있을 때만 넣습니다. 그 뒤의 판정은 계약에 자리가 없어 쓰지 않습니다.
// 필수 판정이 빠진 응답은 엔진 계약 위반이라 오류입니다.
func dailySlots(r *enginev1.DailyResponse) ([]dailySlot, error) {
	fortunes := r.GetFortune()
	if len(fortunes) == 0 {
		return nil, errors.New("엔진 데일리 응답에 총운 판정이 없습니다")
	}
	slots := []dailySlot{{id: SlotFortuneHead, key: fortunes[0].GetMessageKey(), judgment: fortunes[0], required: true}}
	if len(fortunes) > 1 {
		slots = append(slots, dailySlot{id: SlotFortuneTag, key: fortunes[1].GetMessageKey(), judgment: fortunes[1]})
	}
	judged := []struct {
		id string
		j  *enginev1.Judgment
	}{
		{SlotGuide, r.GetGuide()},
		{SlotColor, r.GetColor().GetJudgment()},
		{SlotDirection, r.GetDirection().GetJudgment()},
		{SlotNumber, r.GetNumber().GetJudgment()},
		{SlotFocusTime, r.GetFocusTime().GetJudgment()},
	}
	for _, s := range judged {
		if s.j == nil {
			return nil, fmt.Errorf("엔진 데일리 응답에 %s 판정이 없습니다", s.id)
		}
		slots = append(slots, dailySlot{id: s.id, key: s.j.GetMessageKey(), judgment: s.j, required: true})
	}
	slots = append(slots, dailySlot{id: SlotCharacterReason, key: characterReasonKey(r.GetKind()), required: true})
	return slots, nil
}

// Calendar는 year년 month월 달력 묶음을 만듭니다. 선택 기록 없이 활성 시드의 single 문장으로 렌더합니다(P4-3).
func (v *Views) Calendar(ctx context.Context, accountID uuid.UUID, p profile.Profile, year, month int) (CalendarView, error) {
	version, err := v.store.Active(ctx)
	if err != nil {
		return CalendarView{}, err
	}
	response, err := v.service.Month(ctx, p.Birth, year, month, p.CurrentTimezone)
	if err != nil {
		return CalendarView{}, err
	}
	unlocked, err := v.unlocked(ctx, accountID)
	if err != nil {
		return CalendarView{}, err
	}
	tpl, err := v.store.Templates(ctx, version, p.Language)
	if err != nil {
		return CalendarView{}, err
	}

	days := make([]DayTexts, len(response.GetDays()))
	for i, d := range response.GetDays() {
		if d.GetJudgment() == nil {
			// 길흉 수준 문장은 계약 필수이고 키가 판정에 있어, 판정이 없는 응답은 엔진 계약 위반입니다.
			return CalendarView{}, fmt.Errorf("엔진 달력 응답 %d번째 날에 길흉 판정이 없습니다", i)
		}
		reasonKey := characterReasonKey(d.GetKind())
		reason, ok := v.renderer.Identifier(ctx, tpl, SlotCharacterReason, reasonKey, nil)
		if !ok {
			reason = emptyText(SlotCharacterReason, reasonKey, seed.VariantSingle)
		}
		level, ok := v.renderer.Slot(ctx, tpl, SlotDayLevel, seed.VariantSingle, d.GetJudgment(), "", unlocked)
		if !ok {
			level = emptyText(SlotDayLevel, d.GetJudgment().GetMessageKey(), seed.VariantSingle)
		}
		days[i] = DayTexts{CharacterReason: reason, Level: level}
	}
	return CalendarView{Response: response, Days: days, Notices: v.renderNotices(ctx, tpl, response.GetMeta()), Unlocked: unlocked}, nil
}

// Chart는 나의 사주 묶음을 만듭니다. 기준일은 p.CurrentTimezone의 오늘입니다.
// 용신 근거 문장과 원국 개인 해석은 evidence 깊이라 권한이 있을 때만 활성 시드로 렌더하고, 그 문장의 근거(Evidence)는 렌더하지 않습니다.
func (v *Views) Chart(ctx context.Context, accountID uuid.UUID, p profile.Profile) (ChartView, error) {
	version, err := v.store.Active(ctx)
	if err != nil {
		return ChartView{}, err
	}
	asOf, err := v.today(p.CurrentTimezone)
	if err != nil {
		return ChartView{}, err
	}
	response, err := v.service.Chart(ctx, p.Birth, asOf)
	if err != nil {
		return ChartView{}, err
	}
	unlocked, err := v.unlocked(ctx, accountID)
	if err != nil {
		return ChartView{}, err
	}
	notices, err := v.notices(ctx, version, p.Language, response.GetMeta())
	if err != nil {
		return ChartView{}, err
	}
	view := ChartView{Response: response, Notices: notices, Unlocked: unlocked}
	if !unlocked {
		return view, nil
	}
	tpl, err := v.store.Templates(ctx, version, p.Language)
	if err != nil {
		return ChartView{}, err
	}
	// 계약에서 선택 필드라 원고가 없으면 nil로 둡니다(로그는 Renderer가 남김).
	if basis, ok := v.renderer.Slot(ctx, tpl, SlotYongsinMethod, seed.VariantSingle, response.GetYongsin().GetJudgment(), "", false); ok {
		view.YongsinBasis = &basis
	}
	view.PersonalReadings = v.renderPersonalReadings(ctx, tpl, response.GetPersonalReadings())
	return view, nil
}

// renderPersonalReadings는 개인 해석을 활성 시드의 single 문장으로 렌더합니다. 호칭은 쓰지 않고 근거는 렌더하지 않습니다.
// 원고가 없으면(로그는 Renderer가 남김) 그 항목만 뺍니다. 키가 personal.로 시작하지 않거나 슬롯 id를 못 뽑으면 엔진 계약 위반이라 Error 로그를 남기고 뺍니다.
func (v *Views) renderPersonalReadings(ctx context.Context, tpl content.Templates, readings []*enginev1.PersonalReading) []PersonalReadingText {
	out := make([]PersonalReadingText, 0, len(readings))
	for _, reading := range readings {
		j := reading.GetJudgment()
		slot, ok := personalSlot(j.GetMessageKey())
		if !ok {
			v.log.ErrorContext(ctx, "개인 해석 판정 키가 personal.<종류>.…가 아니라 뺍니다", slog.String("message_key", j.GetMessageKey()))
			continue
		}
		text, ok := v.renderer.Slot(ctx, tpl, slot, seed.VariantSingle, j, "", false)
		if !ok {
			continue
		}
		out = append(out, PersonalReadingText{Reading: reading, Text: text})
	}
	return out
}

// personalSlot은 개인 해석 판정 키의 앞 두 마디(personal.<종류>)를 슬롯 id로 돌려줍니다.
func personalSlot(key string) (string, bool) {
	parts := strings.SplitN(key, ".", 3)
	if len(parts) < 3 || parts[0]+"." != personalKeyPrefix || parts[1] == "" {
		return "", false
	}
	return parts[0] + "." + parts[1], true
}

// unlocked는 근거 열람 권한을 묻습니다.
func (v *Views) unlocked(ctx context.Context, accountID uuid.UUID) (bool, error) {
	unlocked, err := v.insight.Unlocked(ctx, accountID)
	if err != nil {
		return false, fmt.Errorf("근거 열람 권한 확인: %w", err)
	}
	return unlocked, nil
}

// today는 timezone 기준 오늘 날짜입니다.
func (v *Views) today(timezone string) (profile.LocalDate, error) {
	loc, err := time.LoadLocation(timezone) // 프로필 저장 때 검사를 통과한 이름입니다.
	if err != nil {
		return profile.LocalDate{}, errors.New("시간대 로드 실패") // 오류에 시간대 이름이 들어 있어 감싸지 않습니다.
	}
	now := v.clock.Now().In(loc)
	return profile.LocalDate{Year: now.Year(), Month: int(now.Month()), Day: now.Day()}, nil
}

// notices는 version·lang 문장 틀로 엔진 안내를 렌더합니다(renderNotices). 안내가 없으면 문장 틀을 읽지 않습니다.
func (v *Views) notices(ctx context.Context, version, lang string, meta *enginev1.ResponseMeta) ([]content.Notice, error) {
	if len(meta.GetNotices()) == 0 {
		return []content.Notice{}, nil
	}
	tpl, err := v.store.Templates(ctx, version, lang)
	if err != nil {
		return nil, err
	}
	return v.renderNotices(ctx, tpl, meta), nil
}

// renderNotices는 엔진 안내를 응답 형태로 바꿉니다. 문구는 system.notice의 notice.<code> 문장입니다(#232).
// 원고가 없거나 렌더에 실패하면 Text는 빈 조각 배열이고 app이 Code로 자기 문구를 씁니다(계약 Notice 설명, 로그는 Renderer가 남김).
// 모르는 코드는 계약 enum에 없으므로 Warn을 남기고 뺍니다.
func (v *Views) renderNotices(ctx context.Context, tpl content.Templates, meta *enginev1.ResponseMeta) []content.Notice {
	out := make([]content.Notice, 0, len(meta.GetNotices()))
	for _, n := range meta.GetNotices() {
		code, ok := noticeCode(n.GetCode())
		if !ok {
			v.log.WarnContext(ctx, "모르는 엔진 안내 코드를 뺍니다", slog.Int("code", int(n.GetCode())))
			continue
		}
		text := []render.Segment{}
		if rendered, ok := v.renderer.Identifier(ctx, tpl, SlotNotice, noticeKeyPrefix+code, nil); ok {
			text = rendered.Text
		}
		out = append(out, content.Notice{Code: code, Text: text})
	}
	return out
}

// noticeCode는 proto NoticeCode를 계약 값(접두어를 떼고 소문자)으로 바꿉니다. UNSPECIFIED나 모르는 값은 false입니다.
func noticeCode(c enginev1.NoticeCode) (string, bool) {
	name, ok := enginev1.NoticeCode_name[int32(c)]
	if !ok || c == enginev1.NoticeCode_NOTICE_CODE_UNSPECIFIED {
		return "", false
	}
	return strings.ToLower(strings.TrimPrefix(name, "NOTICE_CODE_")), true
}

// characterReasonKey는 날의 성격으로 character.reason 키를 만듭니다. 예: DAY_KIND_GWIIN_DAY → character.reason.gwiin_day.
func characterReasonKey(k enginev1.DayKind) string {
	return characterReasonPrefix + strings.ToLower(strings.TrimPrefix(k.String(), "DAY_KIND_"))
}

// emptyText는 원고가 없는 필수 문장 필드의 자리입니다. Text는 nil이 아닌 빈 조각 배열이라 응답에 빈 segments로 나갑니다.
func emptyText(slot, key, variant string) content.SlotText {
	return content.SlotText{Slot: slot, MessageKey: key, Variant: variant, Text: []render.Segment{}, Reactable: content.Reactable(slot)}
}
