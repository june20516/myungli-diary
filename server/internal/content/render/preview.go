package render

import (
	"unicode"
	"unicode/utf8"
)

// 잠긴 근거 문장 미리보기의 상한입니다(D106, S141).
const (
	// previewMaxWords는 띄어쓰기로 단어를 나누는 언어(ko, en)의 미리보기 단어 수 상한입니다.
	previewMaxWords = 3
	// previewMaxRunes는 띄어쓰기가 없는 언어(ja)의 미리보기 글자 수 상한입니다. 공백은 세지 않습니다.
	previewMaxRunes = 8
)

// spacelessLangs는 띄어쓰기로 단어를 나누지 않아 글자 수로 자르는 언어입니다.
var spacelessLangs = map[string]bool{"ja": true}

// Preview는 렌더된 문장의 앞부분만 돌려줍니다(D106). 잠긴 문장의 나머지는 응답에 담지 않으려고 server에서 자릅니다.
//
// ko, en은 띄어쓰기 단어 previewMaxWords개까지, ja는 공백을 뺀 글자 previewMaxRunes개까지이고,
// 어느 언어든 문장 전체가 드러나지 않게 ko, en은 한 단어 이상, ja는 절반 이상을 늘 남깁니다.
// 남길 수 없을 만큼 짧은 문장(한 단어, 한 글자)은 nil입니다.
// 경계에 걸려 잘린 조각은 글자만 남기고 용어 id(Term)를 뺍니다. 용어의 일부만 칩으로 보이지 않게 하려는 것입니다.
// 경계 앞에서 끝나는 조각은 용어 id를 그대로 둡니다.
func Preview(lang string, segments []Segment) []Segment {
	text := concatText(segments)
	cut := wordCut(text)
	if spacelessLangs[lang] {
		cut = runeCut(text)
	}
	if cut <= 0 {
		return nil
	}
	var out []Segment
	offset := 0
	for _, s := range segments {
		if offset >= cut {
			break
		}
		end := offset + len(s.Text)
		if end <= cut {
			out = append(out, s)
		} else {
			out = append(out, Segment{Text: s.Text[:cut-offset]})
		}
		offset = end
	}
	return out
}

// concatText는 조각의 글자를 이어 붙입니다.
func concatText(segments []Segment) string {
	n := 0
	for _, s := range segments {
		n += len(s.Text)
	}
	b := make([]byte, 0, n)
	for _, s := range segments {
		b = append(b, s.Text...)
	}
	return string(b)
}

// wordCut은 띄어쓰기 단어 기준으로 자를 바이트 위치입니다. 자를 수 없으면 0입니다.
func wordCut(text string) int {
	var ends []int
	inWord := false
	for i, r := range text {
		if unicode.IsSpace(r) {
			if inWord {
				ends = append(ends, i)
				inWord = false
			}
			continue
		}
		inWord = true
	}
	if inWord {
		ends = append(ends, len(text))
	}
	n := min(previewMaxWords, len(ends)-1)
	if n < 1 {
		return 0
	}
	return ends[n-1]
}

// runeCut은 공백을 뺀 글자 수 기준으로 자를 바이트 위치입니다. 자를 수 없으면 0입니다.
func runeCut(text string) int {
	total := 0
	for _, r := range text {
		if !unicode.IsSpace(r) {
			total++
		}
	}
	n := min(previewMaxRunes, total/2)
	if n < 1 {
		return 0
	}
	seen := 0
	for i, r := range text {
		if unicode.IsSpace(r) {
			continue
		}
		seen++
		if seen == n {
			return i + utf8.RuneLen(r)
		}
	}
	return 0
}
