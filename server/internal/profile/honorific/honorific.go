// Package honorific은 사용자가 입력한 호칭을 저장값으로 정규화하고 거부·경고 사유를 정합니다.
// 규칙의 기준은 docs/identity/writing/rules/josa.yaml의 name_rules와 mlw/josa.py의 normalize_name입니다.
package honorific

//go:generate go run ./gen

import (
	"strings"
	"unicode"
	"unicode/utf8"

	"golang.org/x/text/unicode/norm"
)

// Code는 거부 사유와 경고입니다. 0은 "없음"입니다.
// problem code 문자열로의 변환은 httpapi가 맡습니다.
type Code int

const (
	None Code = iota
	// 거부
	Empty
	TooLong
	Emoji
	Control
	InvalidChar
	// 경고
	SuffixStripped
	SuffixWarning
)

// Result는 정규화 결과입니다.
type Result struct {
	Value    string // 거부면 ""
	Rejected Code   // 거부 사유, 통과면 None
	Warnings []Code // 통과일 때의 경고(순서: SuffixStripped, SuffixWarning)
}

// 규칙 값입니다. TestRulesMatchJosaYAML이 josa.yaml과 같은지 확인합니다.
var (
	maxLength   = map[string]int{"ko": 10, "ja": 10, "en": 20}
	stripSuffix = map[string][]string{"ko": {"님"}}
	warnSuffix  = map[string][]string{"ja": {"さん", "様", "ちゃん"}}
)

const forbiddenChars = "{}[]()"

// 이모지를 만드는 보조 문자입니다.
const (
	zeroWidthJoiner     = '‍'
	variationSelector16 = '️'
	combiningKeycap     = '⃣'
)

// Normalize는 호칭 입력을 저장값으로 정규화합니다. 거부하면 Value가 비고 Rejected에 사유가 담깁니다.
// 입력은 유효한 UTF-8이라고 가정합니다(JSON 디코딩이 보장합니다).
func Normalize(lang string, raw string) Result {
	name := strings.TrimFunc(norm.NFC.String(raw), isStripSpace)

	if strings.IndexFunc(name, unicode.IsControl) >= 0 {
		return Result{Rejected: Control}
	}
	if strings.IndexFunc(name, isEmojiRune) >= 0 {
		return Result{Rejected: Emoji}
	}
	if strings.ContainsAny(name, forbiddenChars) {
		return Result{Rejected: InvalidChar}
	}

	var warnings []Code
	stripped := false
	for {
		suffix, found := matchSuffix(name, stripSuffix[lang])
		if !found {
			break
		}
		name = strings.TrimRightFunc(strings.TrimSuffix(name, suffix), isStripSpace)
		stripped = true
	}
	if stripped {
		warnings = append(warnings, SuffixStripped)
	}

	if name == "" {
		return Result{Rejected: Empty}
	}
	if limit, ok := maxLength[lang]; ok && utf8.RuneCountInString(name) > limit {
		return Result{Rejected: TooLong}
	}
	if _, found := matchSuffix(name, warnSuffix[lang]); found {
		warnings = append(warnings, SuffixWarning)
	}
	return Result{Value: name, Warnings: warnings}
}

// isStripSpace는 Python str.strip()·isspace()와 같은 공백 판정입니다.
// Python은 U+001C~U+001F(FS/GS/RS/US)도 공백으로 보지만 unicode.IsSpace는 보지 않아 맞춥니다.
func isStripSpace(r rune) bool {
	return unicode.IsSpace(r) || (r >= 0x1c && r <= 0x1f)
}

func matchSuffix(name string, suffixes []string) (string, bool) {
	for _, suffix := range suffixes {
		if strings.HasSuffix(name, suffix) {
			return suffix, true
		}
	}
	return "", false
}

func isEmojiRune(r rune) bool {
	switch r {
	case zeroWidthJoiner, variationSelector16, combiningKeycap:
		return true
	}
	// Regional_Indicator(국기)
	if r >= 0x1F1E6 && r <= 0x1F1FF {
		return true
	}
	return unicode.Is(extendedPictographic, r)
}
