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
	"ten_god.siksin":        "식신",
	"element.wood":          "목",
	"color.wood":            "초록",
	"branch.ja":             "자",
	"branch.o":              "오",
	"day_kind.growth":       "growth day",
	"day_kind.restful":      "restful day",
	"ten_god_group.siksang": "식상",
}

var testKinds = map[string]seed.ParamKind{
	"ten_god":  {Kind: seed.KindCategory, Categories: []string{"ten_god", "ten_god_group"}},
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
	// 받침 없는 "비" 뒤 (이)가는 "가"로 짧아집니다. 그래도 뒤 토큰 "겁재"의 조각 위치가 어긋나지 않습니다.
	segs := mustRender(t, Input{Lang: "ko", Body: "[[비|x.b]](이)가 [[겁재|ten_god.geopjae]](을)를 봐요."})
	assert.Equal(t, []Segment{
		{Text: "비", Term: "x.b"},
		{Text: "가 "},
		{Text: "겁재", Term: "ten_god.geopjae"},
		{Text: "를 봐요."},
	}, segs)
}

// bare [[글자]]는 실행 중에 역조회하지 않으므로(plan P4-5, 변환 때 끝냄) 용어 id가 없고 평문입니다.
// 이름 원고가 덜 찬 언어에서만 남는 형태입니다.
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
		}, "Growth day brings luck."},
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
	// bare [[편관]]은 plan P4-5에 따라 용어 id 없는 평문 조각입니다.
	for _, seg := range segs {
		if strings.Contains(seg.Text, "편관") {
			assert.Empty(t, seg.Term)
		}
		for _, bad := range []string{"[[", "]]", "|"} {
			assert.NotContains(t, seg.Text, bad)
		}
	}
}

func TestRender_Errors(t *testing.T) {
	enum := func(v string) Value { return Value{Kind: ValueEnum, Enum: v} }
	tests := []struct {
		name    string
		in      Input
		wantErr error  // 있으면 ErrorIs로 확인
		wantMsg string // 있으면 메시지 일부로 확인
	}{
		{name: "이름 사전에 없는 enum 값", in: Input{Lang: "ko", Body: "{ten_god}", Kinds: testKinds,
			Params: map[string]Value{"ten_god": enum("unknown")}}, wantMsg: "ten_god.unknown"},
		{name: "매개변수 값 없음", in: Input{Lang: "ko", Body: "{ten_god}", Kinds: testKinds},
			wantMsg: "값이 없습니다"},
		{name: "값 종류 모름", in: Input{Lang: "ko", Body: "{mystery}",
			Params: map[string]Value{"mystery": enum("x")}}, wantMsg: "값 종류를 알 수 없습니다"},
		{name: "목록에 없는 범주", in: Input{Lang: "ko", Body: "{ten_god:color}", Kinds: testKinds,
			Params: map[string]Value{"ten_god": enum("siksin")}}, wantMsg: "쓸 수 없는 범주"},
		{name: "그룹으로 옮길 수 없는 값", in: Input{Lang: "ko", Body: "{ten_god:ten_god_group}", Kinds: testKinds,
			Params: map[string]Value{"ten_god": enum("wood")}}, wantMsg: "옮길 수 없는 값"},
		{name: "none 종류는 쓸 수 없음", in: Input{Lang: "ko", Body: "{role}", Kinds: testKinds,
			Params: map[string]Value{"role": enum("x")}}, wantMsg: "문장에 쓸 수 없습니다"},
		{name: "값 종류 불일치", in: Input{Lang: "ko", Body: "{score}", Kinds: testKinds,
			Params: map[string]Value{"score": enum("x")}}, wantMsg: "값 종류가 맞지 않습니다"},
		{name: "숫자에 범주", in: Input{Lang: "ko", Body: "{score:color}", Kinds: testKinds,
			Params: map[string]Value{"score": {Kind: ValueNumber, Text: "1"}}}, wantMsg: "범주를 붙일 수 없습니다"},
		{name: "호칭이 없는데 앞 덩어리 밖에서 {name}", in: Input{Lang: "ko", Body: "오늘 {name}님"},
			wantMsg: "호칭이 없는데"},
		{name: "호칭에 범주", in: Input{Lang: "ko", Name: "민지", Body: "{name:color}"},
			wantMsg: "범주를 붙일 수 없습니다"},
		{name: "자리표시자 문법", in: Input{Lang: "ko", Body: "{score"}, wantErr: errPlaceholderSyntax},
		{name: "토큰 닫힘 없음", in: Input{Lang: "ko", Body: "[[편관 와요"}, wantErr: errTokenSyntax},
		{name: "짝 없는 ]]", in: Input{Lang: "ko", Body: "편관]] 와요"}, wantErr: errTokenSyntax},
		{name: "빈 토큰", in: Input{Lang: "ko", Body: "[[]]"}, wantErr: errTokenSyntax},
		{name: "중첩 토큰", in: Input{Lang: "ko", Body: "[[a[[b]]]]"}, wantErr: errTokenSyntax},
		{name: "빈 용어 id", in: Input{Lang: "ko", Body: "[[편관|]]"}, wantErr: errTokenSyntax},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := Render(tt.in, testNames)
			require.Error(t, err)
			if tt.wantErr != nil {
				assert.ErrorIs(t, err, tt.wantErr)
			}
			if tt.wantMsg != "" {
				assert.ErrorContains(t, err, tt.wantMsg)
			}
		})
	}
}

func TestRender_TenGodGroupMapping(t *testing.T) {
	groups := map[string]string{
		"bigyeon": "bigyeop", "geopjae": "bigyeop",
		"siksin": "siksang", "sanggwan": "siksang",
		"pyeonjae": "jaeseong", "jeongjae": "jaeseong",
		"pyeongwan": "gwanseong", "jeonggwan": "gwanseong",
		"pyeonin": "inseong", "jeongin": "inseong",
	}
	require.Len(t, tenGodGroups, len(groups))
	for god, want := range groups {
		got, err := mapCategoryValue("ten_god_group", god)
		require.NoError(t, err, god)
		assert.Equal(t, want, got, god)
	}
	got, err := mapCategoryValue("color", "wood")
	require.NoError(t, err)
	assert.Equal(t, "wood", got)
}

func TestRender_GroupCategoryUsesMappedNameAndTerm(t *testing.T) {
	segs := mustRender(t, Input{
		Lang:   "ko",
		Body:   "[[{ten_god:ten_god_group}]](을)를 살려 보세요.",
		Params: map[string]Value{"ten_god": {Kind: ValueEnum, Enum: "siksin"}},
		Kinds:  testKinds,
	})
	assert.Equal(t, []Segment{
		{Text: "식상", Term: "ten_god_group.siksang"},
		{Text: "을 살려 보세요."},
	}, segs)
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
