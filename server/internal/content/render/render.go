// Package render는 원고 문장(템플릿 Body)을 화면 문장 조각으로 바꾸는 순수 함수 모음입니다.
//
// DB와 로그에 의존하지 않습니다. 호칭 생략, 용어 토큰 조각 나누기, 값 치환, 조사 렌더를
// 호칭·조사 규칙 v1.1(docs/identity/writing/guide/honorific-josa.md)의 순서대로 처리합니다.
package render

import (
	"fmt"
	"strings"
	"unicode"
	"unicode/utf8"

	"golang.org/x/text/unicode/norm"

	"github.com/june20516/myungli-diary/server/seed"
)

// ValueKind는 Value가 담은 값의 종류입니다. 0값은 유효하지 않습니다.
type ValueKind int

const (
	// ValueEnum은 proto enum 값을 소문자로 바꾼 이름입니다(Value.Enum).
	ValueEnum ValueKind = iota + 1
	// ValueList는 enum 값 목록입니다(Value.List).
	ValueList
	// ValueNumber는 십진 문자열로 쓴 숫자입니다(Value.Text).
	ValueNumber
	// ValueText는 호출자가 만든 문자열입니다(Value.Text). 그대로 문장에 들어갑니다.
	ValueText
)

// Value는 템플릿 매개변수 값 하나입니다. Kind에 맞는 필드만 읽습니다.
type Value struct {
	Kind ValueKind
	// Enum은 proto enum 값을 소문자로 바꾼 것입니다. 예 "wood".
	Enum string
	// List는 ValueList의 원소들입니다. 각 원소는 Enum과 같은 형식입니다.
	List []string
	// Text는 ValueNumber(십진 문자열)와 ValueText의 값입니다.
	Text string
}

// Names는 범주 이름 사전(glossary.value_name)입니다.
// 범주를 바꿔 읽는 값(예 color는 element와 같은 값 집합, ten_god_group은 십성이 속한 그룹)의
// 대응은 구현체가 맡습니다. 렌더러는 받은 Enum 값을 그대로 넘깁니다.
type Names interface {
	// ValueName은 "<범주>.<값>"의 이름을 돌려줍니다. 사전에 없으면 false입니다.
	ValueName(category, value string) (string, bool)
}

// Input은 Render 한 번에 필요한 입력입니다.
type Input struct {
	Lang string
	// Body는 자리표시자와 용어 토큰을 담은 원고 문장입니다.
	Body string
	// Params는 매개변수 이름 -> 값입니다. 호칭({name})은 넣지 않고 Name으로 줍니다.
	Params map[string]Value
	// Kinds는 매개변수 이름 -> 값 종류입니다(슬롯 명세).
	Kinds map[string]seed.ParamKind
	// Name은 저장된 호칭입니다. 빈 문자열이면 호칭이 없는 것으로 보고 맨 앞 호칭 덩어리를 지웁니다.
	Name string
}

// Segment는 최종 문장의 조각입니다. Term이 비어 있지 않으면 용어 토큰이며 값은 용어 id입니다.
type Segment struct {
	Text, Term string
}

// vocativePrefix는 언어별 맨 앞 호칭 덩어리입니다. 호칭이 없으면 통째로 지웁니다.
var vocativePrefix = map[string]string{
	"ko": "{name}님, ",
	"ja": "{name}さん、",
	"en": "{name}, ",
}

// span은 치환된 문장 안의 용어 토큰 구간 [start, end)(바이트 위치)입니다.
type span struct {
	start, end int
	term       string
}

// renderer는 Render 한 번의 작업 상태입니다.
type renderer struct {
	in    Input
	names Names
	name  string // NFC로 정규화한 호칭
	out   strings.Builder
	spans []span
}

// Render는 in.Body를 렌더 순서(호칭 생략 -> NFC -> 토큰 구간 기억 -> 값 치환 -> 조사 -> 조각 나누기
// -> en 대문자)대로 처리해 문장 조각 배열을 돌려줍니다.
// 문법이 틀리거나 값이 맞지 않거나 이름 사전에 없는 값이면 오류입니다.
// 오류 메시지에는 원고 본문과 호칭을 싣지 않고 매개변수 이름과 값 종류만 싣습니다.
func Render(in Input, names Names) ([]Segment, error) {
	body := norm.NFC.String(in.Body)
	capitalize := false
	if in.Name == "" {
		if prefix, ok := vocativePrefix[in.Lang]; ok && strings.HasPrefix(body, prefix) {
			body = body[len(prefix):]
			capitalize = in.Lang == "en"
		}
	}

	r := &renderer{in: in, names: names, name: norm.NFC.String(in.Name)}
	if err := r.substitute(body); err != nil {
		return nil, err
	}

	text, edits := renderJosa(r.out.String())
	segments := splitSegments(text, remapSpans(r.spans, edits))
	if capitalize && len(segments) > 0 {
		segments[0].Text = upperFirst(segments[0].Text)
	}
	return segments, nil
}

// substitute는 body를 왼쪽부터 읽으며 토큰 표기를 벗기고 자리표시자를 값으로 바꿔 r.out에 쌓습니다.
// 조사 표기는 이 단계에서 건드리지 않습니다.
func (r *renderer) substitute(body string) error {
	for i := 0; i < len(body); {
		switch {
		case strings.HasPrefix(body[i:], tokenOpen):
			tok, n, err := parseToken(body[i:])
			if err != nil {
				return err
			}
			if err := r.writeToken(tok); err != nil {
				return err
			}
			i += n
		case strings.HasPrefix(body[i:], tokenClose):
			return errTokenSyntax
		case body[i] == '{':
			ph, n, err := parsePlaceholder(body[i:])
			if err != nil {
				return err
			}
			text, _, err := r.value(ph)
			if err != nil {
				return err
			}
			r.out.WriteString(text)
			i += n
		case body[i] == '}':
			return errPlaceholderSyntax
		default:
			r.out.WriteByte(body[i])
			i++
		}
	}
	return nil
}

// writeToken은 토큰의 보이는 글자를 쓰고 그 구간과 용어 id를 기억합니다.
// 용어 id는 직접 적은 것이 우선이고, 없으면 [[{param}]]의 값에서 구하며, 둘 다 없으면 빈 문자열입니다.
func (r *renderer) writeToken(tok token) error {
	start := r.out.Len()
	term := strings.TrimSpace(tok.term)
	shown := tok.shown

	if ph, n, err := parsePlaceholder(shown); err == nil && n == len(shown) {
		text, valueTerm, err := r.value(ph)
		if err != nil {
			return err
		}
		r.out.WriteString(text)
		if term == "" {
			term = valueTerm
		}
	} else {
		// 자리표시자가 섞인 일반 글자: 풀어 쓰되 용어 id는 직접 적은 것만 따릅니다.
		sub := &renderer{in: r.in, names: r.names, name: r.name}
		if err := sub.substitute(shown); err != nil {
			return err
		}
		r.out.WriteString(sub.out.String())
	}

	if term != "" {
		r.spans = append(r.spans, span{start: start, end: r.out.Len(), term: term})
	}
	return nil
}

// value는 자리표시자의 문장 속 글자와, 범주 값이면 그 용어 id("<범주>.<값>")를 돌려줍니다.
func (r *renderer) value(ph placeholder) (text, term string, err error) {
	if ph.name == nameParam {
		return r.nameValue(ph)
	}
	kind, ok := r.in.Kinds[ph.name]
	if !ok {
		return "", "", fmt.Errorf("매개변수 %q의 값 종류를 알 수 없습니다", ph.name)
	}
	val, ok := r.in.Params[ph.name]
	if !ok {
		return "", "", fmt.Errorf("매개변수 %q의 값이 없습니다", ph.name)
	}

	switch kind.Kind {
	case seed.KindCategory:
		return r.categoryValue(ph, kind, val)
	case seed.KindList:
		return r.listValue(ph, kind, val)
	case seed.KindNumber:
		return plainValue(ph, val, ValueNumber)
	case seed.KindText:
		return plainValue(ph, val, ValueText)
	default:
		return "", "", fmt.Errorf("매개변수 %q의 값 종류 %q는 문장에 쓸 수 없습니다", ph.name, kind.Kind)
	}
}

// nameValue는 {name}을 저장된 호칭으로 바꿉니다. 접미사(님, さん)는 원고에 있으므로 붙이지 않습니다.
// 호칭이 없는데 호칭 덩어리 밖에서 {name}을 쓰면 오류입니다.
func (r *renderer) nameValue(ph placeholder) (string, string, error) {
	if ph.category != "" {
		return "", "", fmt.Errorf("매개변수 %q에는 범주를 붙일 수 없습니다", ph.name)
	}
	if r.name == "" {
		return "", "", fmt.Errorf("호칭이 없는데 매개변수 %q가 맨 앞 호칭 덩어리 밖에 있습니다", ph.name)
	}
	return r.name, "", nil
}

// categoryValue는 범주 목록 값을 이름으로 바꿉니다. 범주를 적지 않으면 첫째(기본) 범주입니다.
func (r *renderer) categoryValue(ph placeholder, kind seed.ParamKind, val Value) (string, string, error) {
	if val.Kind != ValueEnum {
		return "", "", kindMismatch(ph)
	}
	category := ph.category
	if category == "" {
		if len(kind.Categories) == 0 {
			return "", "", fmt.Errorf("매개변수 %q의 범주 목록이 비어 있습니다", ph.name)
		}
		category = kind.Categories[0]
	}
	if !contains(kind.Categories, category) {
		return "", "", fmt.Errorf("매개변수 %q에 쓸 수 없는 범주 %q입니다", ph.name, category)
	}
	name, err := r.valueName(category, val.Enum)
	if err != nil {
		return "", "", err
	}
	return name, category + "." + val.Enum, nil
}

// listValue는 목록의 원소마다 이름으로 바꿔 ", "로 잇습니다. 목록에는 범주를 붙일 수 없습니다.
func (r *renderer) listValue(ph placeholder, kind seed.ParamKind, val Value) (string, string, error) {
	if ph.category != "" {
		return "", "", fmt.Errorf("매개변수 %q에는 범주를 붙일 수 없습니다", ph.name)
	}
	if val.Kind != ValueList {
		return "", "", kindMismatch(ph)
	}
	names := make([]string, 0, len(val.List))
	for _, v := range val.List {
		name, err := r.valueName(kind.ListCategory, v)
		if err != nil {
			return "", "", err
		}
		names = append(names, name)
	}
	return strings.Join(names, ", "), "", nil
}

// plainValue는 숫자·텍스트 값을 그대로 씁니다. 범주를 붙일 수 없습니다.
func plainValue(ph placeholder, val Value, want ValueKind) (string, string, error) {
	if ph.category != "" {
		return "", "", fmt.Errorf("매개변수 %q에는 범주를 붙일 수 없습니다", ph.name)
	}
	if val.Kind != want {
		return "", "", kindMismatch(ph)
	}
	return norm.NFC.String(val.Text), "", nil
}

// valueName은 이름 사전에서 이름을 찾습니다. 사전이 없거나 값이 없으면 오류입니다.
func (r *renderer) valueName(category, value string) (string, error) {
	if r.names != nil {
		if name, ok := r.names.ValueName(category, value); ok {
			return norm.NFC.String(name), nil
		}
	}
	return "", fmt.Errorf("이름 사전에 %s.%s가 없습니다", category, value)
}

func kindMismatch(ph placeholder) error {
	return fmt.Errorf("매개변수 %q의 값 종류가 맞지 않습니다", ph.key())
}

func contains(list []string, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}

// remapSpans는 조사 치환으로 달라진 글자 위치에 맞춰 토큰 구간을 다시 계산합니다.
func remapSpans(spans []span, edits []edit) []span {
	remapped := make([]span, len(spans))
	for i, s := range spans {
		remapped[i] = span{start: remapPos(s.start, edits), end: remapPos(s.end, edits), term: s.term}
	}
	return remapped
}

// remapPos는 치환 전 위치 p를 치환 후 위치로 옮깁니다. 치환이 끝난 만큼 길이 차이를 더하고,
// 치환된 표기 한가운데라면 치환 결과의 끝으로 옮깁니다.
func remapPos(p int, edits []edit) int {
	delta := 0
	for _, e := range edits {
		switch {
		case e.oldEnd <= p:
			delta += e.newLen - (e.oldEnd - e.oldStart)
		case e.oldStart < p:
			return e.oldStart + delta + e.newLen
		}
	}
	return p + delta
}

// splitSegments는 text를 토큰 구간 기준으로 조각으로 나눕니다. 빈 조각은 만들지 않습니다.
func splitSegments(text string, spans []span) []Segment {
	var segments []Segment
	add := func(s, term string) {
		if s != "" {
			segments = append(segments, Segment{Text: s, Term: term})
		}
	}
	pos := 0
	for _, s := range spans {
		add(text[pos:s.start], "")
		add(text[s.start:s.end], s.term)
		pos = s.end
	}
	add(text[pos:], "")
	return segments
}

// upperFirst는 s의 첫 글자를 대문자로 바꿉니다.
func upperFirst(s string) string {
	r, size := utf8.DecodeRuneInString(s)
	if size == 0 {
		return s
	}
	return string(unicode.ToUpper(r)) + s[size:]
}
