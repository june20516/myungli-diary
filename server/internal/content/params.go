package content

import (
	"fmt"
	"math"
	"sort"
	"strconv"
	"strings"

	"github.com/june20516/myungli-diary/server/internal/content/render"
	enginev1 "github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/seed"
)

// listSeparator는 엔진이 목록 값(예: 집중 시간 지지들)을 한 문자열로 이을 때 쓰는 구분자입니다.
// core의 daily composer가 ",".join(...)으로 만듭니다.
const listSeparator = ","

// ParamValues는 엔진 판정의 매개변수(proto Param)를 렌더러가 받는 값(render.Value)으로 바꿉니다.
//
// kinds는 슬롯 명세의 매개변수 이름 -> 값 종류입니다. 슬롯 명세는 슬롯 안 모든 키의 매개변수를 합친 것이라
// 이 판정이 쓰지 않는 이름도 들어 있으므로, 판정에 실제로 있는 매개변수만 변환합니다.
// 판정에 없는 매개변수를 템플릿이 쓰면 render.Render가 오류를 냅니다.
//
// 변환 규칙:
//   - category: text 값을 소문자로 바꿔 ValueEnum으로 씁니다.
//   - list: text 값을 ","로 나눠 소문자로 바꾼 목록(ValueList)으로 씁니다.
//   - number: integer 또는 number 값을 십진 문자열(ValueNumber)로 씁니다.
//   - text: text 값을 그대로(ValueText) 씁니다.
//   - none이거나 kinds에 없는 이름: 문장에 쓰지 않으므로 건너뜁니다.
//
// 값의 종류가 맞지 않으면(예: category에 integer) 오류입니다. 오류에는 매개변수 이름만 싣고 값은 싣지 않습니다.
func ParamValues(j *enginev1.Judgment, kinds map[string]seed.ParamKind) (map[string]render.Value, error) {
	out := make(map[string]render.Value, len(j.GetParams()))
	for _, name := range sortedKeys(j.GetParams()) {
		kind, ok := kinds[name]
		if !ok || kind.Kind == seed.KindNone {
			continue
		}
		v, err := paramValue(kind, j.GetParams()[name])
		if err != nil {
			return nil, fmt.Errorf("매개변수 %q: %w", name, err)
		}
		out[name] = v
	}
	return out, nil
}

// paramValue는 proto Param 하나를 kind에 맞는 render.Value로 바꿉니다.
func paramValue(kind seed.ParamKind, p *enginev1.Param) (render.Value, error) {
	switch kind.Kind {
	case seed.KindNumber:
		switch v := p.GetValue().(type) {
		case *enginev1.Param_Integer:
			return render.Value{Kind: render.ValueNumber, Text: strconv.FormatInt(v.Integer, 10)}, nil
		case *enginev1.Param_Number:
			if math.IsNaN(v.Number) || math.IsInf(v.Number, 0) {
				return render.Value{}, errKindMismatch
			}
			return render.Value{Kind: render.ValueNumber, Text: strconv.FormatFloat(v.Number, 'f', -1, 64)}, nil
		}
		return render.Value{}, errKindMismatch
	case seed.KindCategory, seed.KindList, seed.KindText:
		text, ok := p.GetValue().(*enginev1.Param_Text)
		if !ok {
			return render.Value{}, errKindMismatch
		}
		return textValue(kind, text.Text)
	}
	return render.Value{}, fmt.Errorf("알 수 없는 값 종류 %q", kind.Kind)
}

// textValue는 문자열 하나를 kind에 맞는 render.Value로 바꿉니다.
// enum 이름은 엔진이 대문자로 줄 수 있어 소문자로 맞춥니다(이미 소문자면 그대로입니다).
func textValue(kind seed.ParamKind, s string) (render.Value, error) {
	switch kind.Kind {
	case seed.KindCategory:
		return render.Value{Kind: render.ValueEnum, Enum: strings.ToLower(s)}, nil
	case seed.KindList:
		var items []string
		if s != "" {
			for _, item := range strings.Split(s, listSeparator) {
				items = append(items, strings.ToLower(strings.TrimSpace(item)))
			}
		}
		return render.Value{Kind: render.ValueList, List: items}, nil
	case seed.KindText:
		return render.Value{Kind: render.ValueText, Text: s}, nil
	case seed.KindNumber:
		// ParseFloat는 "NaN"·"Inf"도 받아 주지만 문장에 쓸 수 있는 숫자가 아니므로 거부합니다.
		if f, err := strconv.ParseFloat(s, 64); err != nil || math.IsNaN(f) || math.IsInf(f, 0) {
			return render.Value{}, errKindMismatch
		}
		return render.Value{Kind: render.ValueNumber, Text: s}, nil
	}
	return render.Value{}, fmt.Errorf("알 수 없는 값 종류 %q", kind.Kind)
}

// detailValues는 Evidence.detail(문자열 맵)을 슬롯 명세의 값 종류에 따라 render.Value로 바꿉니다.
// 종류가 none이거나 명세에 없는 키는 문장에 쓰지 않으므로 건너뜁니다.
func detailValues(detail map[string]string, kinds map[string]seed.ParamKind) (map[string]render.Value, error) {
	out := make(map[string]render.Value, len(detail))
	for _, name := range sortedKeys(detail) {
		kind, ok := kinds[name]
		if !ok || kind.Kind == seed.KindNone {
			continue
		}
		v, err := textValue(kind, detail[name])
		if err != nil {
			return nil, fmt.Errorf("근거 detail %q: %w", name, err)
		}
		out[name] = v
	}
	return out, nil
}

// errKindMismatch는 엔진이 준 값의 형태가 슬롯 명세의 값 종류와 맞지 않을 때의 오류입니다.
var errKindMismatch = fmt.Errorf("값 형태가 명세의 값 종류와 맞지 않습니다")

// sortedKeys는 오류가 매번 같은 매개변수를 먼저 가리키도록 맵 키를 정렬해 돌려줍니다.
func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
