package render

import (
	"errors"
	"strings"
	"unicode"
)

// nameParam은 호칭 자리표시자의 이름입니다. 슬롯 params에 적지 않고 모든 슬롯에서 같은 방식으로 씁니다.
const nameParam = "name"

// placeholder는 원고의 자리표시자 {param} 또는 {param:category}입니다.
type placeholder struct {
	name     string
	category string // 없으면 빈 문자열
}

var errPlaceholderSyntax = errors.New("자리표시자 문법이 올바르지 않습니다")

// parsePlaceholder는 s가 "{"로 시작한다고 보고 닫는 "}"까지 읽어 자리표시자와 소비한 바이트 수를 돌려줍니다.
// 안쪽에 "{"나 공백이 있거나 이름·범주가 비면 오류입니다. 오류에는 원고 본문을 싣지 않습니다.
func parsePlaceholder(s string) (placeholder, int, error) {
	end := strings.IndexByte(s, '}')
	if end < 0 {
		return placeholder{}, 0, errPlaceholderSyntax
	}
	inner := s[1:end]
	if strings.ContainsFunc(inner, unicode.IsSpace) || strings.ContainsRune(inner, '{') {
		return placeholder{}, 0, errPlaceholderSyntax
	}
	name, category, hasCategory := strings.Cut(inner, ":")
	if name == "" || (hasCategory && category == "") {
		return placeholder{}, 0, errPlaceholderSyntax
	}
	return placeholder{name: name, category: category}, end + 1, nil
}

// key는 오류 메시지에 쓰는 표기입니다.
func (p placeholder) key() string {
	if p.category == "" {
		return p.name
	}
	return p.name + ":" + p.category
}
