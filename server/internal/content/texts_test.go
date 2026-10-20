package content_test

import (
	"bytes"
	"context"
	"log/slog"
	"math"
	"strings"
	"sync"
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
	slots  map[string]seed.Slot
}

func (f fakeTemplates) Lang() string { return f.lang }

func (f fakeTemplates) Slot(id string) (seed.Slot, bool) {
	slot, ok := f.slots[id]
	return slot, ok
}

func (f fakeTemplates) Body(slot, key, variant string) (string, bool) {
	b, ok := f.bodies[[3]string{slot, key, variant}]
	return b, ok
}

func (f fakeTemplates) ValueName(category, value string) (string, bool) {
	n, ok := f.names[category+"."+value]
	return n, ok
}

// textSlots는 테스트 문장 틀(newTestTemplates)의 슬롯 명세입니다.
var textSlots = map[string]seed.Slot{
	"daily.color": {ID: "daily.color", Params: map[string]seed.ParamKind{
		"element": {Kind: seed.KindCategory, Categories: []string{"element"}},
		"score":   {Kind: seed.KindNumber},
	}},
	"daily.fortune.head":   {ID: "daily.fortune.head", Vocative: true, Rotation: seed.RotationType},
	"explain.today_reason": {ID: "explain.today_reason"},
	"evidence.basis": {ID: "evidence.basis", Params: map[string]seed.ParamKind{
		"element":        {Kind: seed.KindCategory, Categories: []string{"element"}},
		"strength_score": {Kind: seed.KindNumber},
		"unused":         {Kind: seed.KindNone},
	}},
	"evidence.source": {ID: "evidence.source"},
}

func newTestTemplates() fakeTemplates {
	return fakeTemplates{
		lang: "ko",
		bodies: map[[3]string]string{
			{"daily.color", "color.yongsin_day", "single"}:                             "{element}색이 좋아요. 점수는 {score}점이에요.",
			{"daily.fortune.head", "fortune.x", "advice"}:                              "{name}님, 오늘은 쉬어 가요.",
			{"daily.fortune.head", "fortune.y", "single"}:                              "{name}님, 반가워요.",
			{"explain.today_reason", "reason.color/lucky_element", "single"}:           "[[용신|tag.yongsin]]이 들어와서 그래요.",
			{"evidence.basis", "basis.color/lucky_element", "single"}:                  "{element} 오행이 {strength_score}점이라 행운 오행으로 봤어요.",
			{"evidence.source", "source.gungtong-bogam/five_elements#color", "single"}: "궁통보감 오행 편",
		},
		names: map[string]string{"element.wood": "초록"},
		slots: textSlots,
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

// testLogs는 렌더러 로그를 텍스트로 쌓으면서 레코드의 속성도 따로 모읍니다.
// 텍스트는 레벨·키 같은 형식 검사에, 속성은 값이 새지 않았는지 검사(assertNotLogged)에 씁니다.
type testLogs struct {
	bytes.Buffer

	mu      sync.Mutex
	records []loggedAttrs
}

// loggedAttrs는 레코드 하나의 메시지와 속성(키 → 값 문자열)입니다. 레코드 시각은 속성이 아니라 들어가지 않습니다.
type loggedAttrs struct {
	message string
	attrs   map[string]string
}

// captureHandler는 텍스트 handler로 넘기기 전에 레코드 속성을 testLogs에 모읍니다.
type captureHandler struct {
	slog.Handler
	logs   *testLogs
	preset []slog.Attr
}

func (h captureHandler) Handle(ctx context.Context, r slog.Record) error {
	attrs := map[string]string{}
	for _, a := range h.preset {
		attrs[a.Key] = a.Value.String()
	}
	r.Attrs(func(a slog.Attr) bool {
		attrs[a.Key] = a.Value.String()
		return true
	})
	h.logs.mu.Lock()
	h.logs.records = append(h.logs.records, loggedAttrs{message: r.Message, attrs: attrs})
	h.logs.mu.Unlock()
	return h.Handler.Handle(ctx, r)
}

func (h captureHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	preset := append(append([]slog.Attr{}, h.preset...), attrs...)
	return captureHandler{Handler: h.Handler.WithAttrs(attrs), logs: h.logs, preset: preset}
}

func (h captureHandler) WithGroup(name string) slog.Handler {
	return captureHandler{Handler: h.Handler.WithGroup(name), logs: h.logs, preset: h.preset}
}

func newTestRenderer() (*content.Renderer, *testLogs) {
	logs := &testLogs{}
	log := slog.New(captureHandler{Handler: slog.NewTextHandler(logs, nil), logs: logs})
	return content.NewRenderer(log), logs
}

// assertNotLogged는 로그 레코드의 메시지와 속성 값 어디에도 secrets가 없는지 봅니다.
// 레코드 시각(time)은 속성이 아니라 보지 않습니다. 시각 숫자가 우연히 secret과 겹쳐 실패하는 일을 막습니다(#272).
func assertNotLogged(t *testing.T, logs *testLogs, secrets ...string) {
	t.Helper()
	logs.mu.Lock()
	defer logs.mu.Unlock()
	for i, rec := range logs.records {
		for _, secret := range secrets {
			assert.NotContains(t, rec.message, secret, "%d번째 로그의 메시지에 %q가 있습니다", i, secret)
			for key, value := range rec.attrs {
				assert.False(t, strings.Contains(value, secret), "%d번째 로그의 속성 %s에 %q가 있습니다: %q", i, key, secret, value)
			}
		}
	}
}

func TestSlot_RendersJudgmentWithParams(t *testing.T) {
	r, logs := newTestRenderer()
	tpl := newTestTemplates()

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, newTestJudgment(), "", true)
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

	got, ok := r.Slot(context.Background(), tpl, "daily.fortune.head", "advice", j, "민지", true)
	require.True(t, ok)
	assert.Equal(t, "민지님, 오늘은 쉬어 가요.", joinSegments(got.Text))

	// 호칭이 없으면 맨 앞 호칭 덩어리가 지워집니다.
	got, ok = r.Slot(context.Background(), tpl, "daily.fortune.head", "advice", j, "", true)
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

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "", true)
	require.True(t, ok)
	assert.Equal(t, []render.Segment{{Text: "용신", Term: "tag.yongsin"}, {Text: "이 들어와서 그래요."}}, got.TodayReason)

	j.Evidence = []*enginev1.Evidence{{RuleId: "calendar/score"}}
	got, ok = r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "", true)
	require.True(t, ok)
	assert.Nil(t, got.TodayReason)
}

func TestSlot_EvidenceBasisUsesDetailAsParams(t *testing.T) {
	r, logs := newTestRenderer()
	tpl := newTestTemplates()
	j := newTestJudgment()
	j.Evidence = []*enginev1.Evidence{{
		RuleId: "color/lucky_element",
		Detail: map[string]string{"element": "WOOD", "strength_score": "42.5", "unused": "무시"},
	}}

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "", true)
	require.True(t, ok)
	require.Len(t, got.Evidence, 1)
	assert.Equal(t, "color/lucky_element", got.Evidence[0].RuleID)
	assert.Equal(t, map[string]string{"element": "WOOD", "strength_score": "42.5", "unused": "무시"}, got.Evidence[0].Detail)
	assert.Equal(t, "초록 오행이 42.5점이라 행운 오행으로 봤어요.", joinSegments(got.Evidence[0].Basis))
	assert.Empty(t, logs.String())
}

func TestSlot_EvidenceSource(t *testing.T) {
	r, _ := newTestRenderer()
	tpl := newTestTemplates()
	j := newTestJudgment()
	ref := "gungtong-bogam/five_elements#color"
	j.Evidence = []*enginev1.Evidence{{RuleId: "color/lucky_element", SourceRef: ref}}

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "", true)
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

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "", true)
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

	got, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "민지", true)
	assert.False(t, ok)
	assert.Equal(t, content.SlotText{}, got)

	out := logs.String()
	assert.Contains(t, out, "level=ERROR")
	for _, want := range []string{"daily.color", "color.missing_key", "single", "lang=ko"} {
		assert.Contains(t, out, want)
	}
	assertNotLogged(t, logs, "민지")
	assert.Equal(t, 1, bytes.Count(logs.Bytes(), []byte("\n")), "로그는 한 줄만 남습니다")
}

// 렌더 실패 로그에는 원인 오류를 싣습니다. 이름 사전 누락의 "범주.값"은 enum 값이라 싣고,
// 호칭·문장 본문·숫자 매개변수 값은 싣지 않습니다.
func TestSlot_RenderErrorIsFalseAndLogsCauseWithoutBodyOrValues(t *testing.T) {
	r, logs := newTestRenderer()
	tpl := newTestTemplates()
	j := newTestJudgment()
	j.Params["element"] = &enginev1.Param{Value: &enginev1.Param_Text{Text: "no_such_value"}}

	_, ok := r.Slot(context.Background(), tpl, "daily.color", seed.VariantSingle, j, "민지", true)
	assert.False(t, ok)
	out := logs.String()
	assert.Equal(t, 1, bytes.Count(logs.Bytes(), []byte("level=ERROR")), out)
	assert.Contains(t, out, `error="이름 사전에 element.no_such_value가 없습니다"`)
	assertNotLogged(t, logs, "민지", "좋아요", "80")
}

func TestIdentifier_RendersKeyWithGivenParams(t *testing.T) {
	r, _ := newTestRenderer()
	tpl := newTestTemplates()
	params := map[string]render.Value{
		"element": {Kind: render.ValueEnum, Enum: "wood"},
		"score":   {Kind: render.ValueNumber, Text: "7"},
	}

	got, ok := r.Identifier(context.Background(), tpl, "daily.color", "color.yongsin_day", params, "")
	require.True(t, ok)
	assert.Equal(t, "color.yongsin_day", got.MessageKey)
	assert.Equal(t, seed.VariantSingle, got.Variant)
	assert.Equal(t, "초록색이 좋아요. 점수는 7점이에요.", joinSegments(got.Text))

	_, ok = r.Identifier(context.Background(), tpl, "daily.color", "nope", params, "")
	assert.False(t, ok)
}

// 호칭은 호칭 슬롯에만 넘기고, 호칭이 비면 호칭 덩어리를 지운 문장이 됩니다.
func TestIdentifier_VocativeOnlyForVocativeSlot(t *testing.T) {
	r, _ := newTestRenderer()
	tpl := newTestTemplates()

	got, ok := r.Identifier(context.Background(), tpl, "daily.fortune.head", "fortune.y", nil, "민지")
	require.True(t, ok)
	assert.Equal(t, "민지님, 반가워요.", joinSegments(got.Text))

	got, ok = r.Identifier(context.Background(), tpl, "daily.fortune.head", "fortune.y", nil, "")
	require.True(t, ok)
	assert.Equal(t, "반가워요.", joinSegments(got.Text))
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
		&enginev1.Judgment{MessageKey: "fortune.x"}, "민지", true)
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

func TestSlot_EvidenceDetailMismatchOmitsBasisAndLogs(t *testing.T) {
	r, logs := newTestRenderer()
	j := newTestJudgment()
	j.Evidence = []*enginev1.Evidence{{
		RuleId: "color/lucky_element",
		Detail: map[string]string{"strength_score": "비밀값"},
	}}

	got, ok := r.Slot(context.Background(), newTestTemplates(), "daily.color", seed.VariantSingle, j, "", true)
	require.True(t, ok)
	require.Len(t, got.Evidence, 1)
	assert.Nil(t, got.Evidence[0].Basis)
	assert.Equal(t, 1, bytes.Count(logs.Bytes(), []byte("level=ERROR")))
	assert.Contains(t, logs.String(), "strength_score")
	assert.NotContains(t, logs.String(), "비밀값")
}

func TestSlot_ParamValuesFailureLogsNameWithoutValue(t *testing.T) {
	r, logs := newTestRenderer()
	j := newTestJudgment()
	j.Params["score"] = &enginev1.Param{Value: &enginev1.Param_Text{Text: "비밀값"}}

	_, ok := r.Slot(context.Background(), newTestTemplates(), "daily.color", seed.VariantSingle, j, "", true)
	assert.False(t, ok)
	assert.Equal(t, 1, bytes.Count(logs.Bytes(), []byte("level=ERROR")))
	assert.Contains(t, logs.String(), "score")
	assert.NotContains(t, logs.String(), "비밀값")
}

// 렌더하는 문장 틀의 시드 버전 명세를 씁니다. 같은 Renderer라도 명세가 다른 문장 틀이면 결과가 다릅니다.
func TestSlot_UsesTemplatesSlotSpec(t *testing.T) {
	r, _ := newTestRenderer()
	j := &enginev1.Judgment{MessageKey: "fortune.x"}

	got, ok := r.Slot(context.Background(), newTestTemplates(), "daily.fortune.head", "advice", j, "민지", false)
	require.True(t, ok)
	assert.Equal(t, "민지님, 오늘은 쉬어 가요.", joinSegments(got.Text))

	tpl := newTestTemplates()
	tpl.slots = map[string]seed.Slot{"daily.fortune.head": {ID: "daily.fortune.head", Rotation: seed.RotationType}}
	got, ok = r.Slot(context.Background(), tpl, "daily.fortune.head", "advice", j, "민지", false)
	require.True(t, ok)
	assert.Equal(t, "오늘은 쉬어 가요.", joinSegments(got.Text), "호칭 슬롯이 아닌 명세면 호칭을 쓰지 않음")
}

func TestParamValues_RejectsNonFiniteNumbers(t *testing.T) {
	kinds := map[string]seed.ParamKind{"score": {Kind: seed.KindNumber}}
	for _, p := range []*enginev1.Param{
		{Value: &enginev1.Param_Number{Number: math.NaN()}},
		{Value: &enginev1.Param_Number{Number: math.Inf(1)}},
	} {
		_, err := content.ParamValues(&enginev1.Judgment{Params: map[string]*enginev1.Param{"score": p}}, kinds)
		assert.Error(t, err)
	}
	// 근거 detail 문자열 숫자도 같습니다.
	r, logs := newTestRenderer()
	j := newTestJudgment()
	// element는 올바른 값이라, 근거 문장이 빠지는 이유는 NaN 하나뿐입니다.
	j.Evidence = []*enginev1.Evidence{{RuleId: "color/lucky_element", Detail: map[string]string{"element": "wood", "strength_score": "NaN"}}}
	got, ok := r.Slot(context.Background(), newTestTemplates(), "daily.color", seed.VariantSingle, j, "", true)
	require.True(t, ok)
	assert.Nil(t, got.Evidence[0].Basis)
	assert.Contains(t, logs.String(), "level=ERROR")
}

// 근거를 빼고 렌더하면 근거 원고가 없어도 로그가 없고, 오늘 그런 이유는 그대로 렌더합니다.
func TestSlot_WithoutEvidenceSkipsEvidenceRendering(t *testing.T) {
	r, logs := newTestRenderer()
	j := newTestJudgment()
	j.Evidence = []*enginev1.Evidence{{RuleId: "color/lucky_element"}, {RuleId: "no/basis_template", SourceRef: "no/source#x"}}

	got, ok := r.Slot(context.Background(), newTestTemplates(), "daily.color", seed.VariantSingle, j, "", false)
	require.True(t, ok)
	assert.Nil(t, got.Evidence)
	assert.Equal(t, "용신이 들어와서 그래요.", joinSegments(got.TodayReason))
	assert.Empty(t, logs.String())

	// 같은 판정을 근거와 함께 렌더하면 원고가 없는 근거 문장마다 로그가 남습니다(대조군).
	got, ok = r.Slot(context.Background(), newTestTemplates(), "daily.color", seed.VariantSingle, j, "", true)
	require.True(t, ok)
	assert.Len(t, got.Evidence, 2)
	assert.NotEmpty(t, logs.String())
}
