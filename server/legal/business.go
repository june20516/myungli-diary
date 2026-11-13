package legal

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"regexp"
	"slices"
	"strings"
)

// 원문의 사업자 정보 빈자리 표기입니다(D126 ②). 원문(docs/legal)에는 이 표기만 두고, 값은 server가 기동할 때
// 저장소 밖 값(Secret Manager LEGAL_BUSINESS_INFO, D98)으로 채웁니다. 변환 결과(data/legal.json)는 저장소에 들어가므로
// 변환 때 채우지 않습니다(D74).
const (
	PlaceholderName               = "{{business.name}}"
	PlaceholderRepresentative     = "{{business.representative}}"
	PlaceholderAddress            = "{{business.address}}"
	PlaceholderRegistrationNumber = "{{business.registrationNumber}}"
	PlaceholderMailOrderNumber    = "{{business.mailOrderNumber}}"
)

// BusinessInfo는 한 언어의 사업자 정보 다섯 값입니다. 번호도 언어마다 받아, 언어별 표기가 다른 값과 같은 모양으로 다룹니다.
type BusinessInfo struct {
	Name               string `json:"name"`
	Representative     string `json:"representative"`
	Address            string `json:"address"`
	RegistrationNumber string `json:"registrationNumber"`
	MailOrderNumber    string `json:"mailOrderNumber"`
}

// values는 빈자리 표기 → 값입니다.
func (b BusinessInfo) values() map[string]string {
	return map[string]string{
		PlaceholderName:               b.Name,
		PlaceholderRepresentative:     b.Representative,
		PlaceholderAddress:            b.Address,
		PlaceholderRegistrationNumber: b.RegistrationNumber,
		PlaceholderMailOrderNumber:    b.MailOrderNumber,
	}
}

// Business는 언어 → 사업자 정보입니다. nil이면 값이 없는 상태입니다.
type Business map[string]BusinessInfo

// ParseBusiness는 LEGAL_BUSINESS_INFO 값(JSON)을 읽습니다. 모든 언어(Languages)에 다섯 값이 모두 있어야 하고,
// 모르는 언어나 필드가 있으면 오류입니다. 오류에는 값 내용을 담지 않습니다(D98).
func ParseBusiness(data []byte) (Business, error) {
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var b Business
	if err := decoder.Decode(&b); err != nil {
		return nil, errors.New("사업자 정보는 언어 → {name, representative, address, registrationNumber, mailOrderNumber} JSON이어야 합니다")
	}
	var errs []error
	for lang := range b {
		if !slices.Contains(Languages, lang) {
			errs = append(errs, fmt.Errorf("사업자 정보에 모르는 언어 %q가 있습니다", lang))
		}
	}
	for _, lang := range Languages {
		info, ok := b[lang]
		if !ok {
			errs = append(errs, fmt.Errorf("사업자 정보에 %s 값이 없습니다", lang))
			continue
		}
		for placeholder, value := range info.values() {
			if strings.TrimSpace(value) == "" {
				errs = append(errs, fmt.Errorf("사업자 정보 %s의 %s 값이 비었습니다", lang, placeholder))
			} else if strings.Contains(value, "{{") || strings.Contains(value, "}}") {
				errs = append(errs, fmt.Errorf("사업자 정보 %s의 %s 값에 빈자리 표기가 들어 있습니다", lang, placeholder))
			}
		}
	}
	if err := errors.Join(errs...); err != nil {
		return nil, err
	}
	return b, nil
}

// placeholderPattern은 중괄호 두 겹 표기 하나입니다.
var placeholderPattern = regexp.MustCompile(`\{\{[^{}]*\}\}`)

// CheckPlaceholders는 s의 중괄호 두 겹 표기가 모두 아는 빈자리 표기인지 봅니다. 표기 밖에 남은 `{{`, `}}`도 오류입니다.
func CheckPlaceholders(s string) error {
	known := BusinessInfo{}.values()
	var unknown []string
	rest := placeholderPattern.ReplaceAllStringFunc(s, func(m string) string {
		if _, ok := known[m]; !ok {
			unknown = append(unknown, m)
		}
		return ""
	})
	if len(unknown) > 0 {
		return fmt.Errorf("모르는 빈자리 표기 %s", strings.Join(unknown, ", "))
	}
	if strings.Contains(rest, "{{") || strings.Contains(rest, "}}") {
		return errors.New("빈자리 표기 밖에 {{ 나 }}가 있습니다")
	}
	return nil
}

// hasPlaceholders는 s에 빈자리 표기가 있는지 알려 줍니다.
func hasPlaceholders(s string) bool {
	return placeholderPattern.MatchString(s)
}

// Fill은 문서의 빈자리를 그 언어의 사업자 정보로 채운 Documents를 돌려줍니다. 본문(HTML)에는 이스케이프한 값을,
// 제목에는 글자 그대로를 넣습니다(페이지 template이 제목을 이스케이프함).
// business가 nil이면 빈자리가 있는 문서를 빼고(준비 중 페이지가 됨) 뺀 문서를 "언어/이름"으로 돌려줍니다.
// 빈자리가 그대로 보이는 페이지는 내지 않습니다.
func (d Documents) Fill(business Business) (Documents, []string) {
	out := Documents{docs: make(map[[2]string]Document, len(d.docs))}
	var dropped []string
	for key, doc := range d.docs {
		if !hasPlaceholders(doc.Title) && !hasPlaceholders(doc.HTML) {
			out.docs[key] = doc
			continue
		}
		info, ok := business[doc.Lang]
		if !ok {
			dropped = append(dropped, doc.Lang+"/"+doc.Name)
			continue
		}
		values := info.values()
		doc.Title = placeholderPattern.ReplaceAllStringFunc(doc.Title, func(m string) string { return values[m] })
		doc.HTML = placeholderPattern.ReplaceAllStringFunc(doc.HTML, func(m string) string { return html.EscapeString(values[m]) })
		out.docs[key] = doc
	}
	slices.Sort(dropped)
	return out, dropped
}
