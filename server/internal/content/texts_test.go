package content_test

import (
	"bytes"
	"context"
	"log/slog"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	enginev1 "github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/seed"
)

// fakeTemplates는 DB 없이 쓰는 content.Templates입니다.
type fakeTemplates struct {
	lang   string
	bodies map[[3]string]string
	names  map[string]string
}

func (f fakeTemplates) Lang() string { return f.lang }

func (f fakeTemplates) Body(slot, key, variant string) (string, bool) {
	b, ok := f.bodies[[3]string{slot, key, variant}]
	return b, ok
}

func (f fakeTemplates) ValueName(category, value string) (string, bool) {
	n, ok := f.names[category+"."+value]
	return n, ok
}

// textSlots는 Renderer에 넘기는 슬롯 정의입니다.
var textSlots = map[string]seed.Slot{
	"daily.color": {ID: "daily.color", Params: map[string]seed.ParamKind{
		"element": {Kind: seed.KindCategory, Categories: []string{"element"}},
		"score":   {Kind: seed.KindNumber},
	}},
	"daily.fortune.head":   {ID: "daily.fortune.head", Vocative: true, Rotation: seed.RotationType},
	"explain.today_reason": {ID: "explain.today_reason"},
	"evidence.basis": {ID: "evidence.basis", Params: map[string]seed.ParamKind{
		"element": {Kind: seed.KindNone},
	}},
	"evidence.source": {ID: "evidence.source"},
}

func newTestTemplates() fakeTemplates {
	return fakeTemplates{
		lang: "ko",
		bodies: map[[3]string]string{
			{"daily.color", "color.yongsin_day", "single"}:                             "{element}색이 좋아요. 점수는 {score}점이에요.",
			{"daily.fortune.head", "fortune.x", "advice"}:                              "{name}님, 오늘은 쉬어 가요.",
			{"explain.today_reason", "reason.color/lucky_element", "single"}:           "[[용신|tag.yongsin]]이 들어와서 그래요.",
			{"evidence.basis", "basis.color/lucky_element", "single"}:                  "행운 오행으로 봤어요.",
			{"evidence.source", "source.gungtong-bogam/five_elements#color", "single"}: "궁통보감 오행 편",
		},
		names: map[string]string{"element.wood": "초록"},
	}
}

func newTestJudgment() *enginev1.Judgment {
	return &enginev1.Judgment{
		MessageKey: "color.yongsin_day",
		Params: map[string]*enginev1.Param{
			"element": {Value: &enginev1.Param_Text{Text: "wood"}},
			"score":   {Value: &enginev1.Param_Integer{Integer: 80}},
		},
	}
}

func joinSegments(segs []render.Segment) string {
	var b bytes.Buffer
	for _, s := range segs {
		b.WriteString(s.Text)
	}
	return b.String()
}

func newTestRenderer() (*content.Renderer, *bytes.Buffer) {
	var logs bytes.Buffer
	log := slog.New(slog.NewTextHandler(&logs, nil))
	return content.NewRenderer(log, textSlots), &logs
}

func TestSlot_RendersJudgmentWithParams(t *testing.T) {
	r, logs := newTestRenderer()
	tpl := newTestTemplates()

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, newTestJudgment(), "")
	require.True(t, ok)
	assert.Equal(t, "daily.color", got.Slot)
	assert.Equal(t, "color.yongsin_day", got.MessageKey)
	assert.Equal(t, seed.VariantSingle, got.Variant)
	assert.Equal(t, "초록색이 좋아요. 점수는 80점이에요.", joinSegments(got.Text))
	assert.Nil(t, got.TodayReason)
	assert.Empty(t, got.Evidence)
	assert.Empty(t, logs.String())
}

func TestSlot_VocativeOnlyForVocativeSlots(t *testing.T) {
	r, _ := newTestRenderer()
	tpl := newTestTemplates()
	j := &enginev1.Judgment{MessageKey: "fortune.x"}

	got, ok := r.Slot(context.Background(), tpl, "daily.fortune.head", "advice", j, "민지")
	require.True(t, ok)
	assert.Equal(t, "민지님, 오늘은 쉬어 가요.", joinSegments(got.Text))

	// 호칭이 없으면 맨 앞 호칭 덩어리가 지워집니다.
	got, ok = r.Slot(context.Background(), tpl, "daily.fortune.head", "advice", j, "")
	require.True(t, ok)
	assert.Equal(t, "오늘은 쉬어 가요.", joinSegments(got.Text))
}

func TestSlot_TodayReasonFromFirstEvidenceRuleWithTemplate(t *testing.T) {
	r, _ := newTestRenderer()
	tpl := newTestTemplates()
	j := newTestJudgment()
	j.Evidence = []*enginev1.Evidence{
		{RuleId: "calendar/score"},            // 문장 없음
		{RuleId: "color/lucky_element"},       // 첫 문장
		{RuleId: "color/lucky_element_other"}, // 뒤에 있어도 쓰지 않음
	}

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "")
	require.True(t, ok)
	assert.Equal(t, []render.Segment{{Text: "용신", Term: "tag.yongsin"}, {Text: "이 들어와서 그래요."}}, got.TodayReason)

	j.Evidence = []*enginev1.Evidence{{RuleId: "calendar/score"}}
	got, ok = r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "")
	require.True(t, ok)
	assert.Nil(t, got.TodayReason)
}

func TestSlot_EvidenceBasisUsesDetailAsParams(t *testing.T) {
	r, logs := newTestRenderer()
	tpl := newTestTemplates()
	j := newTestJudgment()
	j.Evidence = []*enginev1.Evidence{{
		RuleId: "color/lucky_element",
		Detail: map[string]string{"element": "WOOD"},
	}}

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "")
	require.True(t, ok)
	require.Len(t, got.Evidence, 1)
	assert.Equal(t, "color/lucky_element", got.Evidence[0].RuleID)
	assert.Equal(t, map[string]string{"element": "WOOD"}, got.Evidence[0].Detail)
	assert.Equal(t, "행운 오행으로 봤어요.", joinSegments(got.Evidence[0].Basis))
	assert.Empty(t, logs.String())
}

func TestSlot_EvidenceSource(t *testing.T) {
	r, _ := newTestRenderer()
	tpl := newTestTemplates()
	j := newTestJudgment()
	ref := "gungtong-bogam/five_elements#color"
	j.Evidence = []*enginev1.Evidence{{RuleId: "color/lucky_element", SourceRef: ref}}

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "")
	require.True(t, ok)
	require.Len(t, got.Evidence, 1)
	assert.Equal(t, ref, got.Evidence[0].SourceRef)
	assert.Equal(t, "궁통보감 오행 편", joinSegments(got.Evidence[0].Source))
}

func TestSlot_MissingEvidenceTextIsOmittedAndLogs(t *testing.T) {
	r, logs := newTestRenderer()
	tpl := newTestTemplates()
	j := newTestJudgment()
	j.Evidence = []*enginev1.Evidence{{RuleId: "none/rule", SourceRef: "none/ref#x"}}

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "")
	require.True(t, ok)
	require.Len(t, got.Evidence, 1)
	assert.Nil(t, got.Evidence[0].Basis)
	assert.Nil(t, got.Evidence[0].Source)
	assert.Contains(t, logs.String(), "evidence.basis")
	assert.Contains(t, logs.String(), "evidence.source")
}

func TestSlot_MissingTemplateIsFalseAndLogs(t *testing.T) {
	r, logs := newTestRenderer()
	tpl := newTestTemplates()
	j := newTestJudgment()
	j.MessageKey = "color.missing_key"

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "민지")
	assert.False(t, ok)
	assert.Equal(t, content.SlotText{}, got)

	out := logs.String()
	assert.Contains(t, out, "level=ERROR")
	for _, want := range []string{"daily.color", "color.missing_key", "single", "lang=ko"} {
		assert.Contains(t, out, want)
	}
	assert.NotContains(t, out, "민지")
	assert.Equal(t, 1, bytes.Count(logs.Bytes(), []byte("\n")), "로그는 한 줄만 남습니다")
}

func TestSlot_RenderErrorIsFalseAndLogsWithoutParamValues(t *testing.T) {
	r, logs := newTestRenderer()
	tpl := newTestTemplates()
	j := newTestJudgment()
	j.Params["element"] = &enginev1.Param{Value: &enginev1.Param_Text{Text: "no_such_value"}}

	_, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "")
	assert.False(t, ok)
	assert.Contains(t, logs.String(), "level=ERROR")
	assert.NotContains(t, logs.String(), "no_such_value")
}

func TestIdentifier_RendersKeyWithGivenParams(t *testing.T) {
	r, _ := newTestRenderer()
	tpl := newTestTemplates()
	params := map[string]render.Value{
		"element": {Kind: render.ValueEnum, Enum: "wood"},
		"score":   {Kind: render.ValueNumber, Text: "7"},
	}

	got, ok := r.Identifier(context.Background(), tpl, "daily.color", "color.yongsin_day", params)
	require.True(t, ok)
	assert.Equal(t, "color.yongsin_day", got.MessageKey)
	assert.Equal(t, seed.VariantSingle, got.Variant)
	assert.Equal(t, "초록색이 좋아요. 점수는 7점이에요.", joinSegments(got.Text))

	_, ok = r.Identifier(context.Background(), tpl, "daily.color", "nope", params)
	assert.False(t, ok)
}

func TestSlot_ReactableOnlyFortuneSlots(t *testing.T) {
	tests := []struct {
		slot string
		want bool
	}{
		{"daily.fortune.head", true},
		{"daily.fortune.tag", true},
		{"daily.guide", false},
		{"daily.color", false},
		{"calendar.day_level", false},
		{"", false},
	}
	for _, tt := range tests {
		t.Run(tt.slot, func(t *testing.T) {
			assert.Equal(t, tt.want, content.Reactable(tt.slot))
		})
	}

	r, _ := newTestRenderer()
	got, ok := r.Slot(context.Background(), newTestTemplates(), "daily.fortune.head", "advice",
		&enginev1.Judgment{MessageKey: "fortune.x"}, "민지")
	require.True(t, ok)
	assert.True(t, got.Reactable)
}

func TestParamValues_EnumListNumber(t *testing.T) {
	kinds := map[string]seed.ParamKind{
		"element":  {Kind: seed.KindCategory, Categories: []string{"element"}},
		"branches": {Kind: seed.KindList, ListCategory: "branch"},
		"score":    {Kind: seed.KindNumber},
		"ratio":    {Kind: seed.KindNumber},
		"note":     {Kind: seed.KindText},
		"skipped":  {Kind: seed.KindNone},
	}
	j := &enginev1.Judgment{Params: map[string]*enginev1.Param{
		"element":  {Value: &enginev1.Param_Text{Text: "WOOD"}},
		"branches": {Value: &enginev1.Param_Text{Text: "JA,O"}},
		"score":    {Value: &enginev1.Param_Integer{Integer: 80}},
		"ratio":    {Value: &enginev1.Param_Number{Number: 0.25}},
		"note":     {Value: &enginev1.Param_Text{Text: "그대로"}},
		"skipped":  {Value: &enginev1.Param_Flag{Flag: true}},
		"unknown":  {Value: &enginev1.Param_Text{Text: "x"}},
	}}

	got, err := content.ParamValues(j, kinds)
	require.NoError(t, err)
	assert.Equal(t, map[string]render.Value{
		"element":  {Kind: render.ValueEnum, Enum: "wood"},
		"branches": {Kind: render.ValueList, List: []string{"ja", "o"}},
		"score":    {Kind: render.ValueNumber, Text: "80"},
		"ratio":    {Kind: render.ValueNumber, Text: "0.25"},
		"note":     {Kind: render.ValueText, Text: "그대로"},
	}, got)
}

func TestParamValues_Errors(t *testing.T) {
	kinds := map[string]seed.ParamKind{
		"element": {Kind: seed.KindCategory, Categories: []string{"element"}},
		"score":   {Kind: seed.KindNumber},
	}
	tests := []struct {
		name  string
		param *enginev1.Param
		key   string
	}{
		{"enum에 숫자", &enginev1.Param{Value: &enginev1.Param_Integer{Integer: 1}}, "element"},
		{"number에 문자열", &enginev1.Param{Value: &enginev1.Param_Text{Text: "80"}}, "score"},
		{"number에 flag", &enginev1.Param{Value: &enginev1.Param_Flag{Flag: true}}, "score"},
		{"값 없는 Param", &enginev1.Param{}, "score"},
		{"nil Param", nil, "score"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			j := &enginev1.Judgment{Params: map[string]*enginev1.Param{tt.key: tt.param}}
			_, err := content.ParamValues(j, kinds)
			assert.Error(t, err)
		})
	}
}
