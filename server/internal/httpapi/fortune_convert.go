package httpapi

import (
	"errors"
	"fmt"
	"maps"
	"strings"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"
	"google.golang.org/protobuf/reflect/protoreflect"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// 이 파일은 운세 화면 묶음(fortune.DailyView·CalendarView·ChartView)을 계약 타입으로 옮깁니다.
//
// 잠금(D60): 문장의 근거는 View가 권한에 따라 이미 비웠고, 여기서는 View의 문장만 옮깁니다.
// 엔진 응답의 판정 근거(Judgment.evidence, DailyResponse.tag_evidence)와 원국 개인 해석
// (ChartResponse.personal_readings)은 계약에 자리가 없어 옮기지 않습니다.
// 엔진 값이 계약 enum에 없으면(UNSPECIFIED, 모르는 번호) 엔진 계약 위반이라 오류(500)입니다.

// tagPrefix는 엔진 태그 키의 앞부분입니다. 계약 Tag.key는 이 접두어를 뗀 glossary `tag` 범주의 키입니다.
const tagPrefix = "tag."

// tagPolarity는 태그 키 → 길흉입니다(P4-6). proto에 길흉이 없어 server가 고정 표로 둡니다.
// 원본: core/docs/specs/2026-10-10-myungli-engine-design.md §7.7 "해시태그" 표의 길흉 열(15키).
// 길=good, 흉=bad, 중립=neutral입니다.
var tagPolarity = map[string]gen.TagPolarity{
	// 1. 합·충
	"tag.big_change": gen.TagPolarityBad,
	"tag.clash":      gen.TagPolarityBad,
	"tag.harmony":    gen.TagPolarityGood,
	// 2. 십성 쏠림: 관성=흉, 재성·인성·식상=길, 비겁=중립
	"tag.ten_god_rush.bigyeop":   gen.TagPolarityNeutral,
	"tag.ten_god_rush.siksang":   gen.TagPolarityGood,
	"tag.ten_god_rush.jaeseong":  gen.TagPolarityGood,
	"tag.ten_god_rush.gwanseong": gen.TagPolarityBad,
	"tag.ten_god_rush.inseong":   gen.TagPolarityGood,
	// 3. 신살: 귀인·도화=길, 역마·화개=중립, 공망=흉
	"tag.cheoneul_gwiin": gen.TagPolarityGood,
	"tag.dohwa":          gen.TagPolarityGood,
	"tag.yeokma":         gen.TagPolarityNeutral,
	"tag.hwagae":         gen.TagPolarityNeutral,
	"tag.gongmang":       gen.TagPolarityBad,
	// 보조
	"tag.yongsin_day": gen.TagPolarityGood,
	"tag.gwiin_day":   gen.TagPolarityGood,
}

// contractEnum은 생성 코드의 계약 enum 타입입니다.
type contractEnum interface {
	~string
	Valid() bool
}

// converter는 변환 중 첫 오류를 모읍니다. 필드가 많아 단계마다 오류를 돌려받는 대신, 끝에 err 하나만 확인합니다.
type converter struct {
	err error
	// loc은 시각(FocusSlot.start·end, SolarTerm.at)을 나타낼 프로필 현재 시간대입니다.
	loc *time.Location
	// unlocked는 근거 열람 권한입니다. false면 View에 근거가 남아 있어도 옮기지 않습니다.
	unlocked bool
	// reactions는 슬롯 id -> 이 사용자가 남긴 반응입니다(오늘 화면만). 반응할 수 있는 슬롯에만 옮깁니다.
	reactions map[string]string
}

// fail은 첫 오류만 남깁니다.
func (c *converter) fail(err error) {
	if c.err == nil {
		c.err = err
	}
}

// enumValue는 proto enum 값을 계약 enum으로 바꿉니다. 이름에서 enum 접두어(UNSPECIFIED 값 이름의 앞부분)를 떼고
// 소문자로 바꿉니다. 예: BRANCH_SHIN → shin, ELEMENT_ROLE_TONGGWAN → tonggwan.
// UNSPECIFIED, 모르는 번호, 계약 enum 목록에 없는 값은 오류입니다.
func enumValue[T contractEnum](c *converter, v protoreflect.Enum) T {
	values := v.Descriptor().Values()
	unspecified := values.ByNumber(0)
	value := values.ByNumber(v.Number())
	if unspecified == nil || value == nil || v.Number() == 0 {
		c.fail(fmt.Errorf("엔진 %s 값 %d는 계약 값이 아닙니다", v.Descriptor().Name(), v.Number()))
		return ""
	}
	prefix := strings.TrimSuffix(string(unspecified.Name()), "UNSPECIFIED")
	out := T(strings.ToLower(strings.TrimPrefix(string(value.Name()), prefix)))
	if !out.Valid() {
		c.fail(fmt.Errorf("엔진 %s 값 %s가 계약 enum에 없습니다", v.Descriptor().Name(), value.Name()))
		return ""
	}
	return out
}

// contractValue는 문자열을 계약 enum으로 바꿉니다. 목록에 없으면 오류입니다. what은 오류 문구에 쓰는 필드 이름입니다.
func contractValue[T contractEnum](c *converter, what, s string) T {
	out := T(s)
	if !out.Valid() {
		c.fail(fmt.Errorf("%s 값 %q가 계약 enum에 없습니다", what, s))
		return ""
	}
	return out
}

// convertAll은 목록의 항목마다 convert를 적용합니다. 결과는 nil이 아닌 slice라 빈 목록도 []로 나갑니다.
func convertAll[S, T any](items []S, convert func(S) T) []T {
	out := make([]T, 0, len(items))
	for _, item := range items {
		out = append(out, convert(item))
	}
	return out
}

// evidenceAccess는 근거 열람 권한을 계약 값으로 바꿉니다.
func evidenceAccess(unlocked bool) gen.EvidenceAccess {
	if unlocked {
		return gen.Unlocked
	}
	return gen.Locked
}

// rulesetVersion은 엔진 응답 메타의 규칙 버전입니다. 비어 있으면 엔진 계약 위반이라 오류입니다.
func (c *converter) rulesetVersion(meta *enginev1.ResponseMeta) string {
	if meta.GetRulesetVersion() == "" {
		c.fail(errors.New("엔진 응답에 규칙 버전이 없습니다"))
	}
	return meta.GetRulesetVersion()
}

// pillar는 간지 한 기둥을 바꿉니다. 기둥이 없으면 오류입니다.
func (c *converter) pillar(p *enginev1.Pillar) gen.Pillar {
	if p == nil {
		c.fail(errors.New("엔진 응답에 간지 기둥이 없습니다"))
		return gen.Pillar{}
	}
	return gen.Pillar{Stem: enumValue[gen.Stem](c, p.GetStem()), Branch: enumValue[gen.Branch](c, p.GetBranch())}
}

// localDate는 엔진 달력 날짜를 계약 날짜로 바꿉니다. 날짜가 없으면 오류입니다.
func (c *converter) localDate(d *enginev1.LocalDate) openapi_types.Date {
	if d == nil {
		c.fail(errors.New("엔진 응답에 날짜가 없습니다"))
		return openapi_types.Date{}
	}
	return openapi_types.Date{Time: time.Date(int(d.GetYear()), time.Month(d.GetMonth()), int(d.GetDay()), 0, 0, 0, 0, time.UTC)}
}

// instant는 엔진 절대 시각을 프로필 현재 시간대의 시각으로 바꿉니다. JSON에는 그 시간대 offset의 RFC 3339로 나갑니다.
func (c *converter) instant(ts *timestamppb.Timestamp) time.Time {
	if ts == nil {
		c.fail(errors.New("엔진 응답에 시각이 없습니다"))
		return time.Time{}
	}
	if err := ts.CheckValid(); err != nil {
		c.fail(fmt.Errorf("엔진 응답의 시각이 올바르지 않습니다: %w", err))
		return time.Time{}
	}
	return ts.AsTime().In(c.loc)
}

// tag는 엔진 태그 키를 계약 Tag(접두어를 뗀 키와 길흉)로 바꿉니다. 표에 없는 키는 오류입니다.
func (c *converter) tag(key string) gen.Tag {
	polarity, ok := tagPolarity[key]
	if !ok {
		c.fail(fmt.Errorf("엔진 태그 키 %q의 길흉을 모릅니다", key))
		return gen.Tag{}
	}
	return gen.Tag{Key: strings.TrimPrefix(key, tagPrefix), Polarity: polarity}
}

// tagKey는 엔진 태그 키에서 접두어를 뗍니다. 표에 없는 키는 오류입니다.
func (c *converter) tagKey(key string) string {
	return c.tag(key).Key
}

// renderedText는 렌더된 조각 배열을 옮깁니다. 빈 문장도 null이 아닌 빈 segments로 나갑니다.
func renderedText(segments []render.Segment) gen.RenderedText {
	return gen.RenderedText{Segments: convertAll(segments, func(s render.Segment) gen.Segment {
		out := gen.Segment{Text: s.Text}
		if s.Term != "" {
			term := s.Term
			out.Term = &term
		}
		return out
	})}
}

// optionalText는 선택 문장 필드를 옮깁니다. 문장이 없으면 nil이라 필드를 생략합니다.
func optionalText(segments []render.Segment) *gen.RenderedText {
	if len(segments) == 0 {
		return nil
	}
	text := renderedText(segments)
	return &text
}

// slotText는 슬롯 문장 하나를 옮깁니다. 근거는 권한이 있고 근거가 있을 때만 담습니다.
func (c *converter) slotText(t content.SlotText) gen.SlotText {
	out := gen.SlotText{
		Slot:        t.Slot,
		MessageKey:  t.MessageKey,
		Variant:     contractValue[gen.SlotTextVariant](c, "SlotText.variant", t.Variant),
		Text:        renderedText(t.Text),
		Reactable:   t.Reactable,
		TodayReason: optionalText(t.TodayReason),
	}
	if c.unlocked && len(t.Evidence) > 0 {
		evidence := convertAll(t.Evidence, evidenceOf)
		out.Evidence = &evidence
	}
	if reaction, ok := c.reactions[t.Slot]; ok && t.Reactable {
		value := contractValue[gen.SlotTextReaction](c, "SlotText.reaction", reaction)
		out.Reaction = &value
	}
	return out
}

// evidenceOf는 판정 근거 하나를 옮깁니다. detail·basis·source는 있을 때만 담습니다.
func evidenceOf(e content.Evidence) gen.Evidence {
	out := gen.Evidence{
		RuleId:    e.RuleID,
		SourceRef: e.SourceRef,
		Basis:     optionalText(e.Basis),
		Source:    optionalText(e.Source),
	}
	if len(e.Detail) > 0 {
		detail := maps.Clone(e.Detail)
		out.Detail = &detail
	}
	return out
}

// requiredText는 View의 필수 슬롯 문장을 찾습니다. View가 늘 채우는 슬롯이라 없으면 오류입니다.
func (c *converter) requiredText(texts map[string]content.SlotText, slot string) gen.SlotText {
	t, ok := texts[slot]
	if !ok {
		c.fail(fmt.Errorf("오늘 화면 묶음에 필수 슬롯 %s 문장이 없습니다", slot))
		return gen.SlotText{}
	}
	return c.slotText(t)
}

// notices는 엔진 안내를 옮깁니다.
func (c *converter) notices(notices []content.Notice) []gen.Notice {
	return convertAll(notices, func(n content.Notice) gen.Notice {
		return gen.Notice{Code: contractValue[gen.NoticeCode](c, "Notice.code", n.Code), Text: renderedText(n.Text)}
	})
}

// toDaily는 오늘 화면 묶음을 계약 Daily로 바꿉니다. reactions는 슬롯 id -> 이 사용자가 남긴 반응입니다.
func toDaily(view fortune.DailyView, reactions map[string]string, date openapi_types.Date, loc *time.Location) (gen.Daily, error) {
	c := &converter{loc: loc, unlocked: view.Unlocked, reactions: reactions}
	r := view.Response
	out := gen.Daily{
		Date:            date,
		RulesetVersion:  c.rulesetVersion(r.GetMeta()),
		EvidenceAccess:  evidenceAccess(view.Unlocked),
		DayPillar:       c.pillar(r.GetDay()),
		DayKind:         enumValue[gen.DayKind](c, r.GetKind()),
		CharacterReason: c.requiredText(view.Texts, fortune.SlotCharacterReason),
		Fortune:         gen.Fortune{Head: c.requiredText(view.Texts, fortune.SlotFortuneHead)},
		Guide:           c.requiredText(view.Texts, fortune.SlotGuide),
		Cards:           c.dailyCards(view),
		Tags: gen.DayTags{
			Featured: convertAll(r.GetFeaturedTags(), c.tag),
			All:      convertAll(r.GetAllTags(), c.tagKey),
		},
		Relations: convertAll(r.GetRelations(), c.relation),
		Notices:   c.notices(view.Notices),
	}
	if tag, ok := view.Texts[fortune.SlotFortuneTag]; ok {
		text := c.slotText(tag)
		out.Fortune.Tag = &text
	}
	return out, c.err
}

// dailyCards는 카드 네 장을 옮깁니다.
func (c *converter) dailyCards(view fortune.DailyView) gen.DailyCards {
	r := view.Response
	focus := r.GetFocusTime()
	return gen.DailyCards{
		Color: gen.ColorCard{
			Element: enumValue[gen.FiveElement](c, r.GetColor().GetElement()),
			Role:    enumValue[gen.ElementRole](c, r.GetColor().GetRole()),
			Text:    c.requiredText(view.Texts, fortune.SlotColor),
		},
		Direction: gen.DirectionCard{
			Direction: enumValue[gen.Direction](c, r.GetDirection().GetDirection()),
			Text:      c.requiredText(view.Texts, fortune.SlotDirection),
		},
		Number: gen.NumberCard{
			Number: int(r.GetNumber().GetNumber()),
			Text:   c.requiredText(view.Texts, fortune.SlotNumber),
		},
		FocusTime: gen.FocusTimeCard{
			Picks:    convertAll(focus.GetPicks(), c.focusSlot),
			Fallback: focus.GetFallback(),
			Text:     c.requiredText(view.Texts, fortune.SlotFocusTime),
		},
	}
}

// focusSlot은 집중 시간 시진 하나를 옮깁니다.
func (c *converter) focusSlot(s *enginev1.FocusSlot) gen.FocusSlot {
	return gen.FocusSlot{
		Branch:        enumValue[gen.Branch](c, s.GetBranch()),
		Pillar:        c.pillar(s.GetPillar()),
		Start:         c.instant(s.GetStart()),
		End:           c.instant(s.GetEnd()),
		HuangdaoLucky: s.GetHuangdaoLucky(),
		Score:         int(s.GetScore()),
		Reasons: convertAll(s.GetReasons(), func(reason string) gen.FocusSlotReasons {
			return contractValue[gen.FocusSlotReasons](c, "FocusSlot.reasons", reason)
		}),
	}
}

// relation은 일진과 원국의 관계 하나를 옮깁니다. suppressed_by가 UNSPECIFIED가 아니면 무효가 된 관계입니다.
func (c *converter) relation(r *enginev1.Relation) gen.Relation {
	out := gen.Relation{
		Kind:          enumValue[gen.RelationKind](c, r.GetKind()),
		NatalPosition: enumValue[gen.Position](c, r.GetNatalPosition()),
	}
	if r.GetSuppressedBy() != enginev1.RelationKind_RELATION_KIND_UNSPECIFIED {
		by := enumValue[gen.RelationKind](c, r.GetSuppressedBy())
		out.Suppressed = true
		out.SuppressedBy = &by
	}
	return out
}

// toCalendar는 달력 묶음을 계약 Calendar로 바꿉니다. View.Days는 Response.Days와 같은 순서·길이입니다.
func toCalendar(view fortune.CalendarView, year, month int, loc *time.Location) (gen.Calendar, error) {
	c := &converter{loc: loc, unlocked: view.Unlocked}
	r := view.Response
	if len(view.Days) != len(r.GetDays()) {
		return gen.Calendar{}, fmt.Errorf("달력 묶음의 문장 수 %d가 날짜 수 %d와 다릅니다", len(view.Days), len(r.GetDays()))
	}
	days := make([]gen.CalendarDay, len(r.GetDays()))
	for i, d := range r.GetDays() {
		days[i] = c.calendarDay(d, view.Days[i])
	}
	out := gen.Calendar{
		Year:           year,
		Month:          month,
		RulesetVersion: c.rulesetVersion(r.GetMeta()),
		EvidenceAccess: evidenceAccess(view.Unlocked),
		Days:           days,
		Notices:        c.notices(view.Notices),
	}
	return out, c.err
}

// calendarDay는 달력 하루를 옮깁니다. solarTerm은 입절일에만, featuredTag는 대표 태그가 있는 날에만 담습니다.
func (c *converter) calendarDay(d *enginev1.MonthDay, texts fortune.DayTexts) gen.CalendarDay {
	out := gen.CalendarDay{
		Date:            c.localDate(d.GetDate()),
		Pillar:          c.pillar(d.GetPillar()),
		Lunar:           gen.LunarDate{Month: int(d.GetLunarMonth()), Day: int(d.GetLunarDay()), IsLeapMonth: d.GetIsLeapMonth()},
		DayKind:         enumValue[gen.DayKind](c, d.GetKind()),
		CharacterReason: c.slotText(texts.CharacterReason),
		LuckLevel:       enumValue[gen.LuckLevel](c, d.GetLuckLevel()),
		Score:           int(d.GetScore()),
		ScoreItems: convertAll(d.GetScoreItems(), func(s *enginev1.ScoreItem) gen.ScoreItem {
			return gen.ScoreItem{Id: s.GetId(), Score: int(s.GetScore())}
		}),
		Level: c.slotText(texts.Level),
	}
	if term := d.GetSolarTerm(); term != nil {
		out.SolarTerm = &gen.SolarTerm{Kind: enumValue[gen.SolarTermKind](c, term.GetKind()), At: c.instant(term.GetAt())}
	}
	if d.FeaturedTag != nil {
		tag := c.tag(d.GetFeaturedTag())
		out.FeaturedTag = &tag
	}
	return out
}

// toChart는 나의 사주 묶음을 계약 Chart로 바꿉니다. 원국 개인 해석(personal_readings)은 계약에 없어 옮기지 않습니다.
func toChart(view fortune.ChartView) (gen.Chart, error) {
	c := &converter{unlocked: view.Unlocked}
	r := view.Response
	out := gen.Chart{
		RulesetVersion: c.rulesetVersion(r.GetMeta()),
		EvidenceAccess: evidenceAccess(view.Unlocked),
		Pillars:        c.chartPillars(r.GetPillars()),
		TenGods: convertAll(r.GetTenGods(), func(t *enginev1.PositionTenGod) gen.TenGodAt {
			return gen.TenGodAt{Position: enumValue[gen.Position](c, t.GetPosition()), TenGod: enumValue[gen.TenGod](c, t.GetTenGod())}
		}),
		HiddenStems: convertAll(r.GetHiddenStems(), func(h *enginev1.PositionHiddenStems) gen.HiddenStemsAt {
			return gen.HiddenStemsAt{
				Position: enumValue[gen.Position](c, h.GetPosition()),
				Stems: convertAll(h.GetStems(), func(s *enginev1.HiddenStem) gen.HiddenStem {
					return gen.HiddenStem{Stem: enumValue[gen.Stem](c, s.GetStem()), TenGod: enumValue[gen.TenGod](c, s.GetTenGod())}
				}),
			}
		}),
		TwelveStages: convertAll(r.GetTwelveStages(), func(s *enginev1.PositionTwelveStage) gen.TwelveStageAt {
			return gen.TwelveStageAt{Position: enumValue[gen.Position](c, s.GetPosition()), Stage: enumValue[gen.TwelveStage](c, s.GetTwelveStage())}
		}),
		Shinsal: convertAll(r.GetShinsal(), func(s *enginev1.ShinsalHit) gen.ShinsalAt {
			return gen.ShinsalAt{Kind: enumValue[gen.ShinsalKind](c, s.GetKind()), Position: enumValue[gen.Position](c, s.GetPosition())}
		}),
		Gongmang: convertAll(r.GetGongmang(), func(b enginev1.Branch) gen.Branch { return enumValue[gen.Branch](c, b) }),
		ElementWeights: convertAll(r.GetElementWeights(), func(w *enginev1.ElementWeight) gen.ElementWeight {
			return gen.ElementWeight{Element: enumValue[gen.FiveElement](c, w.GetElement()), Weight: float32(w.GetWeight())}
		}),
		Strength: gen.Strength{
			Score: float32(r.GetStrength().GetScore()),
			Level: enumValue[gen.StrengthLevel](c, r.GetStrength().GetLevel()),
		},
		Yongsin: c.yongsin(r.GetYongsin(), view.YongsinBasis),
		Daeun:   c.daeun(r.GetDaeun()),
		Seun:    convertAll(r.GetSeun(), c.seunYear),
		Notices: c.notices(view.Notices),
	}
	return out, c.err
}

// chartPillars는 원국 네 기둥을 옮깁니다. 시간 모름이면 시주가 없어 hour를 생략합니다.
func (c *converter) chartPillars(p *enginev1.FourPillars) gen.ChartPillars {
	out := gen.ChartPillars{Year: c.pillar(p.GetYear()), Month: c.pillar(p.GetMonth()), Day: c.pillar(p.GetDay())}
	if p.GetHour() != nil {
		hour := c.pillar(p.GetHour())
		out.Hour = &hour
	}
	return out
}

// yongsin은 용신 정보를 옮깁니다. 조후 천간은 있을 때만, 용신 근거 문장은 권한이 있을 때만 담습니다.
func (c *converter) yongsin(y *enginev1.YongsinInfo, basis *content.SlotText) gen.Yongsin {
	out := gen.Yongsin{
		Yongsin:  enumValue[gen.FiveElement](c, y.GetYongsin()),
		Huisin:   enumValue[gen.FiveElement](c, y.GetHuisin()),
		Gisin:    enumValue[gen.FiveElement](c, y.GetGisin()),
		Tonggwan: enumValue[gen.FiveElement](c, y.GetTonggwan()),
		Method:   enumValue[gen.YongsinMethod](c, y.GetMethod()),
	}
	if y.GetJohuStem() != enginev1.Stem_STEM_UNSPECIFIED {
		stem := enumValue[gen.Stem](c, y.GetJohuStem())
		out.JohuStem = &stem
	}
	if c.unlocked && basis != nil {
		text := c.slotText(*basis)
		out.Basis = &text
	}
	return out
}

// daeun은 대운 표를 옮깁니다.
func (c *converter) daeun(d *enginev1.DaeunTable) gen.Daeun {
	return gen.Daeun{
		Forward:     d.GetForward(),
		StartYears:  int(d.GetStartYears()),
		StartMonths: int(d.GetStartMonths()),
		Periods: convertAll(d.GetPeriods(), func(p *enginev1.LuckPeriod) gen.DaeunPeriod {
			return gen.DaeunPeriod{
				Pillar:         c.pillar(p.GetPillar()),
				StartAge:       int(p.GetStartAge()),
				StartAgeKorean: int(p.GetStartAgeKorean()),
				StemTenGod:     enumValue[gen.TenGod](c, p.GetStemTenGod()),
				BranchTenGod:   enumValue[gen.TenGod](c, p.GetBranchTenGod()),
				TwelveStage:    enumValue[gen.TwelveStage](c, p.GetTwelveStage()),
			}
		}),
	}
}

// seunYear는 세운 한 해를 옮깁니다.
func (c *converter) seunYear(y *enginev1.YearLuck) gen.SeunYear {
	return gen.SeunYear{
		Year:   int(y.GetYear()),
		Pillar: c.pillar(y.GetPillar()),
		TenGod: enumValue[gen.TenGod](c, y.GetTenGod()),
		RelationsWithNatal: convertAll(y.GetRelationsWithNatal(), func(k enginev1.RelationKind) gen.RelationKind {
			return enumValue[gen.RelationKind](c, k)
		}),
	}
}
