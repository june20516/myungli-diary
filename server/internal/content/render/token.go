package render

import (
	"errors"
	"strings"
)

const (
	tokenOpen  = "[["
	tokenClose = "]]"
	termSep    = "|"
)

var errTokenSyntax = errors.New("용어 토큰 문법이 올바르지 않습니다")

// token은 용어 토큰 [[글자]] 또는 [[글자|용어 id]]입니다.
type token struct {
	shown string // 화면에 보이는 원문. 자리표시자를 담을 수 있습니다.
	term  string // |뒤에 직접 적은 용어 id. 없으면 빈 문자열
}

// parseToken은 s가 "[["로 시작한다고 보고 "]]"까지 읽어 토큰과 소비한 바이트 수를 돌려줍니다.
// 닫힘이 없거나, 안쪽에 "[["가 있거나(중첩), 글자가 비거나, 용어 id가 비었거나 "|"가 둘 이상이면 오류입니다.
func parseToken(s string) (token, int, error) {
	closeAt := strings.Index(s[len(tokenOpen):], tokenClose)
	if closeAt < 0 {
		return token{}, 0, errTokenSyntax
	}
	inner := s[len(tokenOpen) : len(tokenOpen)+closeAt]
	shown, term, hasTerm := strings.Cut(inner, termSep)
	if strings.Contains(inner, tokenOpen) || strings.TrimSpace(shown) == "" ||
		(hasTerm && (strings.TrimSpace(term) == "" || strings.Contains(term, termSep))) {
		return token{}, 0, errTokenSyntax
	}
	return token{shown: shown, term: term}, len(tokenOpen) + closeAt + len(tokenClose), nil
}
