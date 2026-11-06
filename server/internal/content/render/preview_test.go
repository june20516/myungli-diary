package render_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/june20516/myungli-diary/server/internal/content/render"
)

func plainSegments(texts ...string) []render.Segment {
	out := make([]render.Segment, len(texts))
	for i, t := range texts {
		out[i] = render.Segment{Text: t}
	}
	return out
}

func TestPreview(t *testing.T) {
	tests := []struct {
		name string
		lang string
		in   []render.Segment
		want []render.Segment
	}{
		{"ko 다섯 단어는 세 단어", "ko", plainSegments("용신이 들어오는 날이라 기운이 살아나요."), plainSegments("용신이 들어오는 날이라")},
		{"ko 세 단어는 두 단어(한 단어는 남김)", "ko", plainSegments("기운이 살아나는 날"), plainSegments("기운이 살아나는")},
		{"ko 두 단어는 한 단어", "ko", plainSegments("기운이 살아나요"), plainSegments("기운이")},
		{"ko 한 단어는 없음", "ko", plainSegments("살아나요"), nil},
		{"en 세 단어까지", "en", plainSegments("The useful element comes in today."), plainSegments("The useful element")},
		{"ja 글자 여덟 개까지", "ja", plainSegments("今日は用神の気が入ってくる日です。"), plainSegments("今日は用神の気が")},
		{"ja 짧으면 절반", "ja", plainSegments("用神の日です"), plainSegments("用神の")},
		{"ja 한 글자는 없음", "ja", plainSegments("日"), nil},
		{"빈 문장은 없음", "ko", nil, nil},
		{
			"경계 앞에서 끝난 용어는 그대로",
			"ko",
			[]render.Segment{{Text: "오늘 "}, {Text: "용신", Term: "yongsin"}, {Text: "이 들어와 기운이 살아나요."}},
			[]render.Segment{{Text: "오늘 "}, {Text: "용신", Term: "yongsin"}, {Text: "이 들어와"}},
		},
		{
			"경계에 걸린 용어는 용어 id를 뺌",
			"ko",
			[]render.Segment{{Text: "오늘 "}, {Text: "편관 칠살 기운", Term: "ten_god.pyeongwan"}, {Text: "이 들어와요."}},
			[]render.Segment{{Text: "오늘 "}, {Text: "편관 칠살"}},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, render.Preview(tt.lang, tt.in))
		})
	}
}

// 미리보기는 원문의 앞부분이고, 나머지 글자는 담기지 않습니다.
func TestPreview_KeepsOnlyPrefix(t *testing.T) {
	full := "판정 근거는 일지와 월지의 충이라 마음이 흔들리기 쉬워요."
	got := render.Preview("ko", plainSegments(full))
	text := ""
	for _, s := range got {
		text += s.Text
	}
	assert.Equal(t, "판정 근거는 일지와", text)
	assert.NotContains(t, text, "월지의")
}
