// Package seed는 writing 원고를 서버가 읽는 콘텐츠 시드로 옮긴 형식과 읽기 함수를 둡니다.
//
// 시드는 writing 트리(docs/identity/writing)를 seed/convert가 변환해 만든
// data/content.json 하나이며, 바이너리에 내장됩니다. 이 시드를 DB에 적재하는 것은 `seed` 명령이고,
// serve는 시드를 넣지 않습니다(S37). 슬롯 명세도 시드 버전마다 DB에 함께 들어가 실행 중에는 DB의 것을 씁니다(S45).
package seed

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sort"
)

// Rotation은 같은 키가 반복해서 나올 때 문장을 고르는 순환 방식입니다.
type Rotation string

const (
	// RotationNone은 순환하지 않는 슬롯입니다(변주가 하나입니다).
	RotationNone Rotation = "none"
	// RotationType은 문장 유형을 advice, state, care 순으로 돕니다.
	RotationType Rotation = "type"
	// RotationVariant는 변주를 1, 2 순으로 돕니다.
	RotationVariant Rotation = "variant"
)

// 매개변수 값 종류(ParamKind.Kind)입니다.
const (
	KindCategory = "category"
	KindList     = "list"
	KindNumber   = "number"
	KindText     = "text"
	KindNone     = "none"
)

// 템플릿 Variant 값 중 변주를 고르지 않는 자리의 이름입니다.
const VariantSingle = "single"

// ParamKind는 템플릿 매개변수 값을 문장에 옮기는 방식입니다.
type ParamKind struct {
	// Kind는 category, list, number, text, none 중 하나입니다.
	Kind string `json:"kind"`
	// Categories는 Kind가 category일 때 glossary 범주 목록입니다. 첫째가 기본 범주입니다.
	Categories []string `json:"categories,omitempty"`
	// ListCategory는 Kind가 list일 때 원소를 바꿀 범주입니다.
	ListCategory string `json:"list_category,omitempty"`
}

// Slot은 콘텐츠 슬롯 명세 중 서버가 쓰는 부분입니다.
type Slot struct {
	ID string `json:"id"`
	// Vocative가 true인 슬롯만 문장 맨 앞 호칭 덩어리({name})를 씁니다.
	Vocative bool     `json:"vocative,omitempty"`
	Rotation Rotation `json:"rotation"`
	// Params는 슬롯 안 모든 키의 매개변수 이름 -> 값 종류를 합친 것입니다.
	Params map[string]ParamKind `json:"params,omitempty"`
}

// Template은 원고 문장 하나입니다. (Slot, Key, Variant, Lang)이 유일합니다.
type Template struct {
	Slot string `json:"slot"`
	Key  string `json:"key"`
	// Variant는 문장 유형 슬롯이면 advice/state/care, 변주 슬롯이면 "1"/"2", 그 밖에는 "single"입니다.
	Variant string `json:"variant"`
	Lang    string `json:"lang"`
	// Body는 자리표시자와 용어 토큰 [[글자|용어 id]]를 담은 원문입니다.
	Body string `json:"body"`
}

// Seed는 콘텐츠 시드 전체입니다.
type Seed struct {
	// Version은 Slots, Templates, Hanja 내용에서 계산한 지문입니다. 같은 내용이면 같습니다.
	Version   string          `json:"version"`
	Slots     map[string]Slot `json:"slots"`
	Templates []Template      `json:"templates"`
	// Hanja는 용어 id -> 한자 표기입니다. 언어와 상관없이 한 벌입니다(#226).
	Hanja map[string]string `json:"hanja"`
}

// Normalize는 Templates를 (Slot, Key, Variant, Lang) 순으로 정렬하고 Version을 다시 계산합니다.
// 같은 내용이면 항상 같은 바이트의 JSON이 나오게 하려고, 시드를 만들거나 바꾼 뒤 부릅니다.
func (s *Seed) Normalize() error {
	if s.Slots == nil {
		s.Slots = map[string]Slot{}
	}
	if s.Templates == nil {
		s.Templates = []Template{}
	}
	if s.Hanja == nil {
		s.Hanja = map[string]string{}
	}
	sort.Slice(s.Templates, func(i, j int) bool {
		a, b := s.Templates[i], s.Templates[j]
		if a.Slot != b.Slot {
			return a.Slot < b.Slot
		}
		if a.Key != b.Key {
			return a.Key < b.Key
		}
		if a.Variant != b.Variant {
			return a.Variant < b.Variant
		}
		return a.Lang < b.Lang
	})
	// encoding/json은 map 키를 정렬해 쓰므로 Slots·Hanja JSON도 결정적입니다.
	templates, err := json.Marshal(s.Templates)
	if err != nil {
		return fmt.Errorf("templates 직렬화: %w", err)
	}
	slots, err := json.Marshal(s.Slots)
	if err != nil {
		return fmt.Errorf("slots 직렬화: %w", err)
	}
	hanja, err := json.Marshal(s.Hanja)
	if err != nil {
		return fmt.Errorf("hanja 직렬화: %w", err)
	}
	sum := sha256.New()
	sum.Write(templates)
	sum.Write(slots)
	sum.Write(hanja)
	s.Version = hex.EncodeToString(sum.Sum(nil))[:16]
	return nil
}

// MarshalIndent는 시드를 사람이 diff로 읽기 쉬운 들여쓴 JSON(끝 개행 포함)으로 만듭니다.
func (s Seed) MarshalIndent() ([]byte, error) {
	out, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("시드 직렬화: %w", err)
	}
	return append(out, '\n'), nil
}

// Parse는 시드 JSON을 읽고 Version이 있는지 확인합니다.
func Parse(data []byte) (Seed, error) {
	var s Seed
	if err := json.Unmarshal(data, &s); err != nil {
		return Seed{}, fmt.Errorf("시드 파싱: %w", err)
	}
	if s.Version == "" {
		return Seed{}, fmt.Errorf("시드에 version이 없습니다")
	}
	return s, nil
}
