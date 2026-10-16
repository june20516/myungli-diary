package render

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/seed"
)

// fakeNames는 "<범주>.<값>" -> 이름 표입니다.
type fakeNames map[string]string

func (f fakeNames) ValueName(category, value string) (string, bool) {
	name, ok := f[category+"."+value]
	return name, ok
}

var testNames = fakeNames{
	"ten_god.siksin":   "식신",
	"element.wood":     "목",
	"color.wood":       "초록",
	"branch.ja":        "자",
	"branch.o":         "오",
	"day_kind.growth":  "성장하는 날",
	"day_kind.restful": "쉬어 가는 날",
}

var testKinds = map[string]seed.ParamKind{
	"ten_god":  {Kind: seed.KindCategory, Categories: []string{"ten_god"}},
	"element":  {Kind: seed.KindCategory, Categories: []string{"element", "color"}},
	"branches": {Kind: seed.KindList, ListCategory: "branch"},
	"score":    {Kind: seed.KindNumber},
	"start":    {Kind: seed.KindText},
	"day_kind": {Kind: seed.KindCategory, Categories: []string{"day_kind"}},
	"role":     {Kind: seed.KindNone},
}

func mustRender(t *testing.T, in Input) []Segment {
	t.Helper()
	segs, err := Render(in, testNames)
	require.NoError(t, err)
	return segs
}

func TestRender_TermSegments(t *testing.T) {
	segs := mustRender(t, Input{Lang: "ko", Body: "[[편관|ten_god.pyeongwan]](이)가 강해요."})
	assert.Equal(t, []Segment{
		{Text: "편관", Term: "ten_god.pyeongwan"},
		{Text: "이 강해요."},
	}, segs)
}

func TestRender_TermSegmentsAfterJosaLengthChange(t *testing.T) {
	// 조사가 "가"로 짧아져도 뒤 조각이 어긋나지 않습니다. 앞 토큰은 받침 없는 "식"이 아니라 "비"로 끝납니다.
	segs := mustRender(t, Input{Lang: "ko", Body: "[[비|x.b]](이)가 [[겁재|ten_god.geobjae]](을)를 봐요."})
	assert.Equal(t, []Segment{
		{Text: "비", Term: "x.b"},
		{Text: "가 "},
		{Text: "겁재", Term: "ten_god.geobjae"},
		{Text: "를 봐요."},
	}, segs)
}

func TestRender_BareTokenHasNoTerm(t *testing.T) {
	segs := mustRender(t, Input{Lang: "ko", Body: "[[편관]]이 와요."})
	// 용어 id가 없으면 조각을 나눌 이유가 없어 한 조각입니다.
	assert.Equal(t, []Segment{{Text: "편관이 와요."}}, segs)
}

func TestRender_ParamToken(t *testing.T) {
	segs := mustRender(t, Input{
		Lang:   "ko",
		Body:   "오늘은 [[{ten_god}]](이)가 좋아요.",
		Params: map[string]Value{"ten_god": {Kind: ValueEnum, Enum: "siksin"}},
		Kinds:  testKinds,
	})
	assert.Equal(t, []Segment{
		{Text: "오늘은 "},
		{Text: "식신", Term: "ten_god.siksin"},
		{Text: "이 좋아요."},
	}, segs)
}

func TestRender_ParamKinds(t *testing.T) {
	params := map[string]Value{
		"element":  {Kind: ValueEnum, Enum: "wood"},
		"branches": {Kind: ValueList, List: []string{"ja", "o"}},
		"score":    {Kind: ValueNumber, Text: "10"},
		"start":    {Kind: ValueText, Text: "09:00"},
	}
	tests := []struct{ name, body, want string }{
		{"범주 기본", "{element}(이)가", "목이"},
		{"범주 지정", "{element:color}(이)가", "초록이"},
		{"목록", "{branches}", "자, 오"},
		{"숫자", "{score}(은)는", "10은"},
		{"텍스트", "{start}부터", "09:00부터"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			segs := mustRender(t, Input{Lang: "ko", Body: tt.body, Params: params, Kinds: testKinds})
			require.Len(t, segs, 1)
			assert.Equal(t, tt.want, segs[0].Text)
			assert.Empty(t, segs[0].Term)
		})
	}
}

func TestRender_VocativeDroppedWithoutName(t *testing.T) {
	tests := []struct {
		name string
		in   Input
		want string
	}{
		{"ko", Input{Lang: "ko", Body: "{name}님, 오늘은 좋아요."}, "오늘은 좋아요."},
		{"ja", Input{Lang: "ja", Body: "{name}さん、今日は良い日です。"}, "今日は良い日です。"},
		{"en 대문자", Input{Lang: "en", Body: "{name}, today is good."}, "Today is good."},
		{"en 토큰 앞", Input{
			Lang:   "en",
			Body:   "{name}, [[{day_kind}]] brings luck.",
			Params: map[string]Value{"day_kind": {Kind: ValueEnum, Enum: "growth"}},
			Kinds:  testKinds,
		}, "성장하는 날 brings luck."},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			segs := mustRender(t, tt.in)
			assert.Equal(t, tt.want, joinText(segs))
		})
	}
}

func TestRender_EnglishCapitalizesRenderedFirstLetter(t *testing.T) {
	names := fakeNames{"day_kind.growth": "growth day"}
	segs, err := Render(Input{
		Lang:   "en",
		Body:   "{name}, [[{day_kind}]] brings luck.",
		Params: map[string]Value{"day_kind": {Kind: ValueEnum, Enum: "growth"}},
		Kinds:  testKinds,
	}, names)
	require.NoError(t, err)
	assert.Equal(t, []Segment{
		{Text: "Growth day", Term: "day_kind.growth"},
		{Text: " brings luck."},
	}, segs)
}

func TestRender_EnglishWithNameIsNotCapitalized(t *testing.T) {
	segs := mustRender(t, Input{Lang: "en", Name: "Sam", Body: "{name}, today is good."})
	assert.Equal(t, "Sam, today is good.", joinText(segs))
}

func TestRender_NameKeepsSuffixFromBody(t *testing.T) {
	segs := mustRender(t, Input{Lang: "ko", Name: "민지", Body: "{name}님(이)가 왔어요. {name}님, 안녕하세요."})
	assert.Equal(t, "민지님이 왔어요. 민지님, 안녕하세요.", joinText(segs))
}

func TestRender_NameIsNormalizedToNFC(t *testing.T) {
	nfd := "민지" // 민지
	segs := mustRender(t, Input{Lang: "ko", Name: nfd, Body: "{name}님, 안녕"})
	assert.Equal(t, "민지님, 안녕", joinText(segs))
}

func TestRender_NoMarkupLeft(t *testing.T) {
	segs := mustRender(t, Input{
		Lang:   "ko",
		Name:   "민지",
		Body:   "{name}님, [[식신|ten_god.siksin]](이)가 [[{element}]](으)로 [[편관]] 와요.",
		Params: map[string]Value{"element": {Kind: ValueEnum, Enum: "wood"}},
		Kinds:  testKinds,
	})
	for _, seg := range segs {
		for _, bad := range []string{"[[", "]]", "|"} {
			assert.NotContains(t, seg.Text, bad)
		}
	}
}

func TestRender_Errors(t *testing.T) {
	enum := func(v string) Value { return Value{Kind: ValueEnum, Enum: v} }
	tests := []struct {
		name string
		in   Input
	}{
		{"이름 사전에 없는 enum 값", Input{Lang: "ko", Body: "{ten_god}", Kinds: testKinds,
			Params: map[string]Value{"ten_god": enum("unknown")}}},
		{"매개변수 값 없음", Input{Lang: "ko", Body: "{ten_god}", Kinds: testKinds}},
		{"값 종류 모름", Input{Lang: "ko", Body: "{mystery}",
			Params: map[string]Value{"mystery": enum("x")}}},
		{"목록에 없는 범주", Input{Lang: "ko", Body: "{ten_god:color}", Kinds: testKinds,
			Params: map[string]Value{"ten_god": enum("siksin")}}},
		{"none 종류는 쓸 수 없음", Input{Lang: "ko", Body: "{role}", Kinds: testKinds,
			Params: map[string]Value{"role": enum("x")}}},
		{"값 종류 불일치", Input{Lang: "ko", Body: "{score}", Kinds: testKinds,
			Params: map[string]Value{"score": enum("x")}}},
		{"숫자에 범주", Input{Lang: "ko", Body: "{score:color}", Kinds: testKinds,
			Params: map[string]Value{"score": {Kind: ValueNumber, Text: "1"}}}},
		{"호칭이 없는데 앞 덩어리 밖에서 {name}", Input{Lang: "ko", Body: "오늘 {name}님"}},
		{"호칭에 범주", Input{Lang: "ko", Name: "민지", Body: "{name:color}"}},
		{"자리표시자 문법", Input{Lang: "ko", Body: "{score"}},
		{"토큰 닫힘 없음", Input{Lang: "ko", Body: "[[편관 와요"}},
		{"짝 없는 ]]", Input{Lang: "ko", Body: "편관]] 와요"}},
		{"빈 토큰", Input{Lang: "ko", Body: "[[]]"}},
		{"중첩 토큰", Input{Lang: "ko", Body: "[[a[[b]]]]"}},
		{"빈 용어 id", Input{Lang: "ko", Body: "[[편관|]]"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := Render(tt.in, testNames)
			assert.Error(t, err)
		})
	}
}

func TestRender_MissingNameIsError(t *testing.T) {
	_, err := Render(Input{
		Lang:   "ko",
		Body:   "{ten_god}",
		Kinds:  testKinds,
		Params: map[string]Value{"ten_god": {Kind: ValueEnum, Enum: "unknown"}},
	}, testNames)
	require.Error(t, err)
}

func TestRender_ErrorDoesNotLeakBodyOrName(t *testing.T) {
	_, err := Render(Input{
		Lang: "ko", Name: "비밀이름", Body: "비밀문장 {score:color} {name}님",
		Kinds: testKinds, Params: map[string]Value{"score": {Kind: ValueNumber, Text: "1"}},
	}, testNames)
	require.Error(t, err)
	assert.False(t, strings.Contains(err.Error(), "비밀"), err.Error())
}

func joinText(segs []Segment) string {
	var b strings.Builder
	for _, s := range segs {
		b.WriteString(s.Text)
	}
	return b.String()
}
