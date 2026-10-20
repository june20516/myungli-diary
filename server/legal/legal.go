// Package legal은 이용약관·개인정보 처리방침 원문(docs/legal/<언어>/, D80)을 변환해 내장한 문서 묶음입니다.
// 원문은 지휘가 쓰고 사용자가 확정하며, server는 go generate로 HTML로 바꿔 바이너리에 담아 정적 페이지로 내줍니다.
package legal

import (
	"encoding/json"
	"errors"
	"fmt"
	"slices"
)

// 문서 이름입니다. 원문 파일 이름(<이름>.md)이자 경로(/legal/<이름>)의 마지막 마디입니다.
const (
	Terms   = "terms"
	Privacy = "privacy"
)

// Names는 내주는 문서 이름입니다.
var Names = []string{Terms, Privacy}

// Languages는 원문 언어입니다(D27·D28).
var Languages = []string{"ko", "en", "ja"}

// Document는 변환한 문서 하나입니다.
type Document struct {
	Lang string `json:"lang"`
	Name string `json:"name"`
	// Title은 원문의 첫 1단계 제목입니다. 페이지 <title>에 씁니다.
	Title string `json:"title"`
	// HTML은 원문 본문을 변환한 HTML 조각입니다. 원문의 raw HTML은 변환 때 걸러 냅니다.
	HTML string `json:"html"`
}

// Documents는 (언어, 이름) → 문서입니다. 원문이 없는 조합은 없습니다.
type Documents struct {
	docs map[[2]string]Document
}

// New는 문서 목록으로 Documents를 만듭니다. 모르는 언어·이름이나 겹치는 조합이면 오류입니다.
func New(docs []Document) (Documents, error) {
	out := Documents{docs: make(map[[2]string]Document, len(docs))}
	for _, d := range docs {
		if !slices.Contains(Languages, d.Lang) || !slices.Contains(Names, d.Name) {
			return Documents{}, fmt.Errorf("모르는 문서 %s/%s", d.Lang, d.Name)
		}
		key := [2]string{d.Lang, d.Name}
		if _, ok := out.docs[key]; ok {
			return Documents{}, fmt.Errorf("겹치는 문서 %s/%s", d.Lang, d.Name)
		}
		if d.Title == "" || d.HTML == "" {
			return Documents{}, fmt.Errorf("문서 %s/%s의 제목이나 본문이 비었습니다", d.Lang, d.Name)
		}
		out.docs[key] = d
	}
	return out, nil
}

// Get은 lang·name 문서를 돌려줍니다. 원문이 없으면 false입니다.
func (d Documents) Get(lang, name string) (Document, bool) {
	doc, ok := d.docs[[2]string{lang, name}]
	return doc, ok
}

// file은 내장 파일(data/legal.json)의 형식입니다. 문서는 (언어, 이름) 순서입니다.
type file struct {
	Documents []Document `json:"documents"`
}

// Marshal은 문서 목록을 내장 파일 형식으로 씁니다. 순서는 Languages·Names 순서라 같은 원문이면 같은 바이트입니다.
func Marshal(docs []Document) ([]byte, error) {
	sorted := slices.Clone(docs)
	slices.SortFunc(sorted, func(a, b Document) int {
		if c := slices.Index(Languages, a.Lang) - slices.Index(Languages, b.Lang); c != 0 {
			return c
		}
		return slices.Index(Names, a.Name) - slices.Index(Names, b.Name)
	})
	if sorted == nil {
		sorted = []Document{}
	}
	data, err := json.MarshalIndent(file{Documents: sorted}, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(data, '\n'), nil
}

// Parse는 내장 파일 형식을 읽습니다.
func Parse(data []byte) (Documents, error) {
	var f file
	if err := json.Unmarshal(data, &f); err != nil {
		return Documents{}, fmt.Errorf("법적 문서 JSON: %w", err)
	}
	if f.Documents == nil {
		return Documents{}, errors.New("법적 문서 JSON에 documents가 없습니다")
	}
	return New(f.Documents)
}
