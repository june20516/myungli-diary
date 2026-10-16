package content

import (
	"context"
	"log/slog"

	"github.com/june20516/myungli-diary/server/internal/content/render"
	enginev1 "github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/seed"
)

// 근거 문장 슬롯입니다. 슬롯 id와 키 접두사는 writing 슬롯 명세(slots/content/evidence.yaml)가 원본입니다.
const (
	// todayReasonSlot은 "오늘 그런 이유" 슬롯입니다. 키는 reason.<rule_id>입니다.
	todayReasonSlot = "explain.today_reason"
	// basisSlot은 판정 근거 본문 슬롯입니다. 키는 basis.<rule_id>입니다.
	basisSlot = "evidence.basis"
	// sourceSlot은 원전 인용 슬롯입니다. 키는 source.<source_ref>입니다.
	sourceSlot = "evidence.source"
)

// SlotText는 슬롯 하나의 응답 문장입니다.
type SlotText struct {
	Slot       string
	MessageKey string
	// Variant는 문장 유형(advice, state, care), 가이드 변주(1, 2), 그 밖의 single 중 하나입니다.
	Variant string
	Text    []render.Segment
	// TodayReason은 "오늘 그런 이유" 문장입니다. nil이면 응답에서 필드를 뺍니다.
	TodayReason []render.Segment
	// Evidence는 판정 근거입니다. 근거 열람 권한 판정은 호출자가 합니다(D60).
	Evidence []Evidence
	// Reactable은 이 슬롯 문장에 반응(좋아요)을 남길 수 있는지입니다.
	Reactable bool
}

// Evidence는 판정 근거 하나와 그 문장입니다.
type Evidence struct {
	RuleID    string
	SourceRef string
	Detail    map[string]string
	// Basis는 판정 근거 문장입니다. 원고가 없으면 nil입니다.
	Basis []render.Segment
	// Source는 원전 문장입니다. SourceRef가 없거나 원고가 없으면 nil입니다.
	Source []render.Segment
}

// Reactable은 슬롯 문장에 반응을 남길 수 있는지 돌려줍니다(P4-4).
// 총운 슬롯(daily.fortune.head, daily.fortune.tag)만 true입니다.
func Reactable(slot string) bool {
	return slot == "daily.fortune.head" || slot == "daily.fortune.tag"
}

// Renderer는 판정과 문장 틀로 슬롯 문장을 만듭니다. 상태가 없어 동시에 써도 안전합니다.
type Renderer struct {
	log   *slog.Logger
	slots map[string]seed.Slot
}

// NewRenderer는 Renderer를 만듭니다. slots는 시드의 슬롯 명세(seed.Seed.Slots)로,
// 슬롯별 호칭 사용 여부와 매개변수 값 종류를 알려줍니다.
func NewRenderer(log *slog.Logger, slots map[string]seed.Slot) *Renderer {
	return &Renderer{log: log, slots: slots}
}

// Slot은 판정 j를 (slot, variant) 문장 틀로 렌더하고, 판정의 근거 문장을 덧붙여 돌려줍니다.
// 문장 키는 j.MessageKey입니다. 호칭 name은 호칭 슬롯(seed.Slot.Vocative)에만 넘기고, 나머지 슬롯은 빈 호칭으로 렌더합니다.
//
// 본문 틀이 없거나 렌더에 실패하면 false를 돌려주고 Error 로그를 하나 남깁니다. 호출자가 그 슬롯을 빼거나 빈 문장으로 채웁니다.
// 근거 문장(TodayReason, Evidence.Basis, Evidence.Source)은 선택 필드라 실패해도 본문은 살립니다.
func (r *Renderer) Slot(ctx context.Context, tpl Templates, slot, variant string, j *enginev1.Judgment, name string) (SlotText, bool) {
	def, ok := r.slots[slot]
	if !ok {
		r.logFailure(ctx, tpl, slot, j.GetMessageKey(), variant)
		return SlotText{}, false
	}
	if !def.Vocative {
		name = ""
	}
	params, err := ParamValues(j, def.Params)
	if err != nil {
		r.logFailure(ctx, tpl, slot, j.GetMessageKey(), variant)
		return SlotText{}, false
	}
	text, ok := r.render(ctx, tpl, def, j.GetMessageKey(), variant, params, name)
	if !ok {
		return SlotText{}, false
	}
	return SlotText{
		Slot:        slot,
		MessageKey:  j.GetMessageKey(),
		Variant:     variant,
		Text:        text,
		TodayReason: r.todayReason(ctx, tpl, j),
		Evidence:    r.evidence(ctx, tpl, j),
		Reactable:   Reactable(slot),
	}, true
}

// Identifier는 판정이 아니라 식별자 키(예: 캐릭터 이유, 달력 일 수준)로 슬롯 문장을 만듭니다.
// 변주는 single이고 호칭과 근거는 없습니다. 실패 처리는 Slot과 같습니다.
func (r *Renderer) Identifier(ctx context.Context, tpl Templates, slot, key string, params map[string]render.Value) (SlotText, bool) {
	def, ok := r.slots[slot]
	if !ok {
		r.logFailure(ctx, tpl, slot, key, seed.VariantSingle)
		return SlotText{}, false
	}
	text, ok := r.render(ctx, tpl, def, key, seed.VariantSingle, params, "")
	if !ok {
		return SlotText{}, false
	}
	return SlotText{
		Slot:       slot,
		MessageKey: key,
		Variant:    seed.VariantSingle,
		Text:       text,
		Reactable:  Reactable(slot),
	}, true
}

// render는 (slot, key, variant) 본문을 찾아 렌더합니다. 실패하면 Error 로그를 하나 남기고 false를 돌려줍니다.
func (r *Renderer) render(ctx context.Context, tpl Templates, def seed.Slot, key, variant string, params map[string]render.Value, name string) ([]render.Segment, bool) {
	body, ok := tpl.Body(def.ID, key, variant)
	if !ok {
		r.logFailure(ctx, tpl, def.ID, key, variant)
		return nil, false
	}
	segments, err := render.Render(render.Input{
		Lang:   tpl.Lang(),
		Body:   body,
		Params: params,
		Kinds:  def.Params,
		Name:   name,
	}, tpl)
	if err != nil {
		r.logFailure(ctx, tpl, def.ID, key, variant)
		return nil, false
	}
	return segments, true
}

// todayReason은 근거를 순서대로 보며 reason.<rule_id> 원고가 있는 첫 근거의 문장을 돌려줍니다.
// 이 문장은 오늘 화면의 용어를 낸 규칙에만 있는 선택 문장이라, 규칙 대부분에는 원고가 없는 것이 정상입니다.
// 그래서 원고가 없을 때는 로그를 남기지 않고 nil(필드 생략)을 돌려줍니다. 렌더가 실패하면 Slot처럼 로그를 남깁니다.
func (r *Renderer) todayReason(ctx context.Context, tpl Templates, j *enginev1.Judgment) []render.Segment {
	def, ok := r.slots[todayReasonSlot]
	if !ok {
		return nil
	}
	for _, e := range j.GetEvidence() {
		key := "reason." + e.GetRuleId()
		if _, found := tpl.Body(todayReasonSlot, key, seed.VariantSingle); !found {
			continue
		}
		text, _ := r.render(ctx, tpl, def, key, seed.VariantSingle, nil, "")
		return text
	}
	return nil
}

// evidence는 판정의 근거마다 판정 근거 문장(basis.<rule_id>)과 원전 문장(source.<source_ref>)을 붙입니다.
// 두 문장은 writing 명세상 모든 규칙·원전에 있어야 하므로, 원고가 없거나 렌더가 실패하면 Error 로그를 남기고 그 필드만 뺍니다.
func (r *Renderer) evidence(ctx context.Context, tpl Templates, j *enginev1.Judgment) []Evidence {
	var out []Evidence
	for _, e := range j.GetEvidence() {
		item := Evidence{RuleID: e.GetRuleId(), SourceRef: e.GetSourceRef(), Detail: e.GetDetail()}
		if def, ok := r.slots[basisSlot]; ok {
			// detail은 명세의 값 종류가 none이 아닌 키만 매개변수가 됩니다.
			if params, err := detailValues(e.GetDetail(), def.Params); err != nil {
				r.logFailure(ctx, tpl, basisSlot, "basis."+e.GetRuleId(), seed.VariantSingle)
			} else {
				item.Basis, _ = r.render(ctx, tpl, def, "basis."+e.GetRuleId(), seed.VariantSingle, params, "")
			}
		}
		if def, ok := r.slots[sourceSlot]; ok && e.GetSourceRef() != "" {
			item.Source, _ = r.render(ctx, tpl, def, "source."+e.GetSourceRef(), seed.VariantSingle, nil, "")
		}
		out = append(out, item)
	}
	return out
}

// logFailure는 문장을 만들지 못한 이유를 Error 로그 하나로 남깁니다.
// 호칭, 매개변수 값, 문장 본문은 개인정보가 섞일 수 있어 싣지 않고 문장 틀 id와 언어만 싣습니다.
func (r *Renderer) logFailure(ctx context.Context, tpl Templates, slot, key, variant string) {
	r.log.ErrorContext(ctx, "슬롯 문장을 만들지 못했습니다",
		slog.String("slot", slot),
		slog.String("key", key),
		slog.String("variant", variant),
		slog.String("lang", tpl.Lang()),
	)
}
