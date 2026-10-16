// Package convert는 writing 원고 트리를 seed.Seed로 변환합니다.
//
// 입력 트리 구조(기준 구현은 docs/identity/writing/tools/src/mlw):
//
//	slots/content/*.yaml     콘텐츠 슬롯 명세
//	content/<lang>/*.yaml    원고 줄 {slot, key, type, variant, text}
//	content/hanja.yaml       용어 한자 표기 {term, hanja}(언어 무관 한 벌, 없으면 빈 사전)
//
// 슬롯 명세에 없는 슬롯(ui 슬롯 등)의 줄과 예시 파일(example.yaml)은 시드에 넣지 않습니다.
package convert

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/june20516/myungli-diary/server/seed"
)

const (
	// exampleFile은 라운드 전 임시 원고라 시드에 넣지 않는 파일 이름입니다.
	exampleFile = "example.yaml"
	// hanjaFile은 content/ 바로 아래의 용어 한자 표기 파일입니다.
	hanjaFile = "hanja.yaml"

	glossarySlot  = "glossary.value_name"
	tagLabelSlot  = "daily.tag_label"
	tagKeyPrefix  = "tag."
	listPrefix    = "list:"
	tokenOpen     = "[["
	tokenClose    = "]]"
	termSeparator = "|"
)

// termCategories는 용어 토큰이 가리킬 수 있는 glossary 범주입니다(writing glossary.py TERM_CATEGORIES와 같습니다).
// glossary.value_name에는 방향처럼 용어가 아닌 범주도 있어 이름 사전에는 이 범주만 넣습니다.
var termCategories = map[string]bool{
	"element": true, "stem": true, "branch": true, "ten_god": true, "ten_god_group": true,
	"shinsal": true, "day_kind": true, "relation": true, "role": true, "luck": true,
}

// supportedLangs는 원고 디렉터리로 받는 언어입니다. 그 밖 디렉터리는 오타일 가능성이 커서 오류로 봅니다.
var supportedLangs = []string{"ko", "en", "ja"}

// Report는 변환 중 발견했지만 실패는 아닌 사항입니다.
type Report struct {
	// Missing은 슬롯 명세가 요구하지만 원고가 없는 항목입니다. 형식은 "슬롯/키/variant/언어"이고 정렬되어 있습니다.
	Missing []string
}

// slotSpec은 슬롯 명세 YAML 중 변환에 필요한 필드입니다.
type slotSpec struct {
	ID       string   `yaml:"id"`
	Vocative bool     `yaml:"vocative"`
	Types    []string `yaml:"types"`
	Variants struct {
		Count int `yaml:"count"`
	} `yaml:"variants"`
	Keys []keyGroup `yaml:"keys"`
}

// keyGroup은 keys 목록의 항목입니다. 문자열 하나(매개변수 없는 키) 또는 {params, keys} 묶음입니다.
type keyGroup struct {
	Params map[string]yaml.Node
	Keys   []string
}

// UnmarshalYAML은 문자열 항목과 맵 항목을 모두 읽습니다.
func (g *keyGroup) UnmarshalYAML(node *yaml.Node) error {
	if node.Kind == yaml.ScalarNode {
		g.Keys = []string{node.Value}
		return nil
	}
	var raw struct {
		Params map[string]yaml.Node `yaml:"params"`
		Keys   []string             `yaml:"keys"`
	}
	if err := node.Decode(&raw); err != nil {
		return fmt.Errorf("keys 항목(줄 %d): %w", node.Line, err)
	}
	g.Params, g.Keys = raw.Params, raw.Keys
	return nil
}

// entry는 원고 줄 하나입니다.
type entry struct {
	Slot    string `yaml:"slot"`
	Key     string `yaml:"key"`
	Type    string `yaml:"type"`
	Variant int    `yaml:"variant"`
	Text    string `yaml:"text"`

	file string
	line int
	lang string
}

// where는 오류 메시지에 쓰는 파일:줄 위치입니다. 원고 본문은 싣지 않습니다.
func (e entry) where() string { return fmt.Sprintf("%s:%d", e.file, e.line) }

// slotInfo는 슬롯 명세에서 읽은 검증용 정보입니다.
type slotInfo struct {
	spec     slotSpec
	keys     map[string]bool
	variants int
}

// labels는 이 슬롯이 키마다·언어마다 갖춰야 하는 variant 이름입니다.
func (s slotInfo) labels() []string {
	switch {
	case len(s.spec.Types) > 0:
		return s.spec.Types
	case s.variants > 1:
		labels := make([]string, s.variants)
		for i := range labels {
			labels[i] = strconv.Itoa(i + 1)
		}
		return labels
	default:
		return []string{seed.VariantSingle}
	}
}

// variantOf는 원고 줄의 variant 이름을 정합니다. 슬롯 명세와 맞지 않으면 오류입니다.
func (s slotInfo) variantOf(e entry) (string, error) {
	if len(s.spec.Types) > 0 {
		if !slices.Contains(s.spec.Types, e.Type) {
			return "", fmt.Errorf("%s: 슬롯 %s의 type은 %s 중 하나여야 합니다 (현재 %q)",
				e.where(), e.Slot, strings.Join(s.spec.Types, ", "), e.Type)
		}
		return e.Type, nil
	}
	if e.Type != "" {
		return "", fmt.Errorf("%s: 슬롯 %s은(는) type을 쓰지 않습니다", e.where(), e.Slot)
	}
	if e.Variant > s.variants {
		return "", fmt.Errorf("%s: 슬롯 %s의 변주는 %d개까지입니다 (현재 %d)", e.where(), e.Slot, s.variants, e.Variant)
	}
	if s.variants > 1 {
		return strconv.Itoa(e.Variant), nil
	}
	return seed.VariantSingle, nil
}

// Run은 writingDir 아래 슬롯 명세와 원고를 읽어 시드를 만듭니다.
// 형식 오류, 모호한 용어 토큰, 중복 원고는 파일·줄 위치를 담은 오류로 돌려줍니다.
func Run(writingDir string) (seed.Seed, Report, error) {
	slots, err := loadSlots(filepath.Join(writingDir, "slots", "content"))
	if err != nil {
		return seed.Seed{}, Report{}, err
	}
	entries, langs, err := loadEntries(filepath.Join(writingDir, "content"), slots)
	if err != nil {
		return seed.Seed{}, Report{}, err
	}
	hanja, hanjaLines, err := loadHanja(filepath.Join(writingDir, "content", hanjaFile))
	if err != nil {
		return seed.Seed{}, Report{}, err
	}
	names := nameIndex(entries)
	if err := checkHanjaTerms(hanjaLines, names); err != nil {
		return seed.Seed{}, Report{}, err
	}

	out := seed.Seed{Slots: make(map[string]seed.Slot, len(slots)), Hanja: hanja}
	for id, info := range slots {
		slot, err := toSeedSlot(info)
		if err != nil {
			return seed.Seed{}, Report{}, err
		}
		out.Slots[id] = slot
	}

	present := map[string]bool{}
	for _, e := range entries {
		variant, err := slots[e.Slot].variantOf(e)
		if err != nil {
			return seed.Seed{}, Report{}, err
		}
		if !slots[e.Slot].keys[e.Key] {
			return seed.Seed{}, Report{}, fmt.Errorf("%s: 슬롯 %s에 없는 키 %s입니다", e.where(), e.Slot, e.Key)
		}
		id := missingID(e.Slot, e.Key, variant, e.lang)
		if present[id] {
			return seed.Seed{}, Report{}, fmt.Errorf("%s: 같은 원고가 중복됩니다 (%s)", e.where(), id)
		}
		present[id] = true
		body, err := resolveTokens(e, names)
		if err != nil {
			return seed.Seed{}, Report{}, err
		}
		out.Templates = append(out.Templates, seed.Template{
			Slot: e.Slot, Key: e.Key, Variant: variant, Lang: e.lang, Body: body,
		})
	}
	if err := out.Normalize(); err != nil {
		return seed.Seed{}, Report{}, err
	}
	return out, Report{Missing: findMissing(slots, langs, present)}, nil
}

func missingID(slot, key, variant, lang string) string {
	return strings.Join([]string{slot, key, variant, lang}, "/")
}

// findMissing은 명세가 요구하는 (슬롯, 키, variant, 언어) 중 원고가 없는 것을 정렬해 돌려줍니다.
func findMissing(slots map[string]slotInfo, langs []string, present map[string]bool) []string {
	var missing []string
	for id, info := range slots {
		for key := range info.keys {
			for _, lang := range langs {
				for _, label := range info.labels() {
					if !present[missingID(id, key, label, lang)] {
						missing = append(missing, missingID(id, key, label, lang))
					}
				}
			}
		}
	}
	sort.Strings(missing)
	return missing
}

// yamlFiles는 dir의 *.yaml 파일을 이름순으로 돌려줍니다.
func yamlFiles(dir string) ([]string, error) {
	files, err := filepath.Glob(filepath.Join(dir, "*.yaml"))
	if err != nil {
		return nil, fmt.Errorf("%s 목록: %w", dir, err)
	}
	sort.Strings(files)
	return files, nil
}

func loadSlots(dir string) (map[string]slotInfo, error) {
	files, err := yamlFiles(dir)
	if err != nil {
		return nil, err
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("%s에 슬롯 명세가 없습니다", dir)
	}
	slots := map[string]slotInfo{}
	for _, file := range files {
		data, err := os.ReadFile(file) //nolint:gosec // 호출자가 정한 writing 트리 경로입니다.
		if err != nil {
			return nil, fmt.Errorf("슬롯 명세 읽기: %w", err)
		}
		var specs []slotSpec
		if err := yaml.Unmarshal(data, &specs); err != nil {
			return nil, fmt.Errorf("%s: %w", file, err)
		}
		for _, spec := range specs {
			if _, dup := slots[spec.ID]; dup {
				return nil, fmt.Errorf("%s: 슬롯 id %s가 중복됩니다", file, spec.ID)
			}
			info := slotInfo{spec: spec, keys: map[string]bool{}, variants: max(spec.Variants.Count, 1)}
			for _, group := range spec.Keys {
				for _, key := range group.Keys {
					info.keys[key] = true
				}
			}
			slots[spec.ID] = info
		}
	}
	return slots, nil
}

// loadEntries는 content/<lang>/*.yaml에서 콘텐츠 슬롯의 원고 줄만 모읍니다. 두 번째 값은 발견한 언어 목록입니다.
func loadEntries(dir string, slots map[string]slotInfo) ([]entry, []string, error) {
	dirs, err := os.ReadDir(dir)
	if err != nil {
		return nil, nil, fmt.Errorf("원고 디렉터리 읽기: %w", err)
	}
	var entries []entry
	var langs []string
	for _, d := range dirs {
		if !d.IsDir() {
			continue
		}
		lang := d.Name()
		if !slices.Contains(supportedLangs, lang) {
			return nil, nil, fmt.Errorf("%s: 지원하지 않는 언어 디렉터리 %q입니다 (허용: %s)",
				dir, lang, strings.Join(supportedLangs, ", "))
		}
		langs = append(langs, lang)
		files, err := yamlFiles(filepath.Join(dir, lang))
		if err != nil {
			return nil, nil, err
		}
		for _, file := range files {
			if filepath.Base(file) == exampleFile {
				continue
			}
			found, err := readEntries(file, lang, slots)
			if err != nil {
				return nil, nil, err
			}
			entries = append(entries, found...)
		}
	}
	sort.Strings(langs)
	return entries, langs, nil
}

func readEntries(file, lang string, slots map[string]slotInfo) ([]entry, error) {
	data, err := os.ReadFile(file) //nolint:gosec // 호출자가 정한 writing 트리 경로입니다.
	if err != nil {
		return nil, fmt.Errorf("원고 읽기: %w", err)
	}
	var nodes []yaml.Node
	if err := yaml.Unmarshal(data, &nodes); err != nil {
		return nil, fmt.Errorf("%s: %w", file, err)
	}
	var entries []entry
	for i := range nodes {
		var e entry
		if err := nodes[i].Decode(&e); err != nil {
			return nil, fmt.Errorf("%s:%d: 원고 줄 형식 오류: %w", file, nodes[i].Line, err)
		}
		if _, ok := slots[e.Slot]; !ok {
			// ui 슬롯 등 콘텐츠 슬롯이 아닌 줄은 시드 대상이 아닙니다.
			continue
		}
		if e.Variant == 0 {
			e.Variant = 1
		}
		e.file, e.line, e.lang = file, nodes[i].Line, lang
		entries = append(entries, e)
	}
	return entries, nil
}

// hanjaEntry는 hanja.yaml의 항목 하나입니다.
type hanjaEntry struct {
	Term  string `yaml:"term"`
	Hanja string `yaml:"hanja"`
}

// hanjaLine은 한자 표기 항목 하나의 용어 id와 파일:줄 위치입니다.
type hanjaLine struct{ term, where string }

// loadHanja는 용어 한자 표기 파일을 용어 id -> 한자로 읽습니다. 둘째 값은 파일 순서의 항목 위치입니다.
// 파일이 없으면 빈 사전입니다. 목록이 아니거나, 항목 형식이 틀리거나(모르는 필드 포함), 용어 id 형식이 아니거나,
// 한자가 비었거나, 용어가 중복되면 파일:줄 위치를 담은 오류입니다.
func loadHanja(file string) (hanja map[string]string, lines []hanjaLine, err error) {
	hanja = map[string]string{}
	data, err := os.ReadFile(file) //nolint:gosec // 호출자가 정한 writing 트리 경로입니다.
	if errors.Is(err, os.ErrNotExist) {
		return hanja, nil, nil
	}
	if err != nil {
		return nil, nil, fmt.Errorf("한자 표기 읽기: %w", err)
	}
	var doc yaml.Node
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return nil, nil, fmt.Errorf("%s: %w", file, err)
	}
	if len(doc.Content) == 0 {
		return hanja, nil, nil
	}
	list := doc.Content[0]
	if list.Kind != yaml.SequenceNode {
		return nil, nil, fmt.Errorf("%s:%d: 한자 표기는 {term, hanja} 목록이어야 합니다", file, list.Line)
	}
	for _, node := range list.Content {
		at := fmt.Sprintf("%s:%d", file, node.Line)
		var e hanjaEntry
		if err := decodeStrict(node, &e); err != nil {
			return nil, nil, fmt.Errorf("%s: 한자 표기 항목 형식 오류: %w", at, err)
		}
		if !isTermID(e.Term) {
			return nil, nil, fmt.Errorf("%s: 용어 id %q의 형식이 <범주>.<값> 또는 tag.<키>가 아닙니다", at, e.Term)
		}
		if strings.TrimSpace(e.Hanja) == "" {
			return nil, nil, fmt.Errorf("%s: 용어 %s의 한자가 비어 있습니다", at, e.Term)
		}
		if _, dup := hanja[e.Term]; dup {
			return nil, nil, fmt.Errorf("%s: 용어 %s의 한자 표기가 중복됩니다", at, e.Term)
		}
		hanja[e.Term] = e.Hanja
		lines = append(lines, hanjaLine{term: e.Term, where: at})
	}
	return hanja, lines, nil
}

// checkHanjaTerms는 한자 표기의 용어 id가 이름 원고에 있는지 봅니다. 이름 원고가 갖춰진(complete) 언어 하나라도
// 그 용어의 이름이 없으면 오타나 사라진 용어로 보고 파일:줄 위치를 담은 오류입니다. 갖춰진 언어가 없으면 보지 않습니다
// (토큰 검사와 같은 기준). 오류는 파일 순서로 첫 항목입니다.
func checkHanjaTerms(lines []hanjaLine, index map[string]*termNames) error {
	langs := make([]string, 0, len(index))
	for lang, names := range index {
		if names.complete {
			langs = append(langs, lang)
		}
	}
	sort.Strings(langs)
	for _, line := range lines {
		for _, lang := range langs {
			if !index[lang].ids[line.term] {
				return fmt.Errorf("%s: 한자 표기의 용어 id %q가 %s 이름 원고에 없습니다", line.where, line.term, lang)
			}
		}
	}
	return nil
}

// decodeStrict는 맵 노드를 out으로 읽되, out에 없는 필드가 있으면 오류입니다.
func decodeStrict(node *yaml.Node, out any) error {
	if node.Kind != yaml.MappingNode {
		return errors.New("맵이 아닙니다")
	}
	encoded, err := yaml.Marshal(node)
	if err != nil {
		return err
	}
	dec := yaml.NewDecoder(bytes.NewReader(encoded))
	dec.KnownFields(true)
	return dec.Decode(out)
}

// toSeedSlot은 슬롯 명세를 시드 슬롯으로 옮깁니다. 같은 매개변수 이름의 값 종류가 키마다 다르면 오류입니다.
func toSeedSlot(info slotInfo) (seed.Slot, error) {
	slot := seed.Slot{ID: info.spec.ID, Vocative: info.spec.Vocative, Rotation: seed.RotationNone}
	switch {
	case len(info.spec.Types) > 0:
		slot.Rotation = seed.RotationType
	case info.variants > 1:
		slot.Rotation = seed.RotationVariant
	}
	for _, group := range info.spec.Keys {
		for name, node := range group.Params {
			kind, err := parseParamKind(node)
			if err != nil {
				return seed.Slot{}, fmt.Errorf("슬롯 %s 매개변수 %s: %w", slot.ID, name, err)
			}
			if prev, ok := slot.Params[name]; ok && !sameKind(prev, kind) {
				return seed.Slot{}, fmt.Errorf("슬롯 %s 매개변수 %s의 값 종류가 키마다 다릅니다", slot.ID, name)
			}
			if slot.Params == nil {
				slot.Params = map[string]seed.ParamKind{}
			}
			slot.Params[name] = kind
		}
	}
	return slot, nil
}

func sameKind(a, b seed.ParamKind) bool {
	return a.Kind == b.Kind && a.ListCategory == b.ListCategory && slices.Equal(a.Categories, b.Categories)
}

// parseParamKind는 params 맵의 값(범주 목록, list:<범주>, number, text, none)을 읽습니다.
func parseParamKind(node yaml.Node) (seed.ParamKind, error) {
	if node.Kind == yaml.SequenceNode {
		var categories []string
		if err := node.Decode(&categories); err != nil || len(categories) == 0 {
			return seed.ParamKind{}, errors.New("범주 목록이 올바르지 않습니다")
		}
		return seed.ParamKind{Kind: seed.KindCategory, Categories: categories}, nil
	}
	switch value := node.Value; {
	case value == seed.KindNumber, value == seed.KindText, value == seed.KindNone:
		return seed.ParamKind{Kind: value}, nil
	case strings.HasPrefix(value, listPrefix) && len(value) > len(listPrefix):
		return seed.ParamKind{Kind: seed.KindList, ListCategory: strings.TrimPrefix(value, listPrefix)}, nil
	}
	return seed.ParamKind{}, fmt.Errorf("알 수 없는 값 종류 %q", node.Value)
}

// termNames는 한 언어의 이름 글자 -> 용어 id 집합입니다.
type termNames struct {
	byText map[string]map[string]bool
	// ids는 그 언어 사전에 이름이 있는 용어 id 전체입니다.
	ids map[string]bool
	// complete는 glossary와 태그 이름 원고가 둘 다 있어 '이름 없음'을 오류로 볼 수 있다는 뜻입니다.
	complete bool
}

// nameIndex는 언어별 역조회 사전을 만듭니다. glossary.value_name의 용어 범주 키(<범주>.<값>)와
// daily.tag_label의 태그 키(tag.*)가 용어 id입니다.
func nameIndex(entries []entry) map[string]*termNames {
	index := map[string]*termNames{}
	sources := map[string]map[string]bool{}
	for _, e := range entries {
		var id string
		switch e.Slot {
		case glossarySlot:
			category, _, _ := strings.Cut(e.Key, ".")
			if !termCategories[category] {
				continue
			}
			id = e.Key
		case tagLabelSlot:
			if !strings.HasPrefix(e.Key, tagKeyPrefix) {
				continue
			}
			id = e.Key
		default:
			continue
		}
		names := index[e.lang]
		if names == nil {
			names = &termNames{byText: map[string]map[string]bool{}, ids: map[string]bool{}}
			index[e.lang] = names
			sources[e.lang] = map[string]bool{}
		}
		if names.byText[e.Text] == nil {
			names.byText[e.Text] = map[string]bool{}
		}
		names.byText[e.Text][id] = true
		names.ids[id] = true
		sources[e.lang][e.Slot] = true
	}
	for lang, names := range index {
		names.complete = sources[lang][glossarySlot] && sources[lang][tagLabelSlot]
	}
	return index
}

// resolveTokens는 본문의 [[글자]]를 [[글자|용어 id]]로 바꿉니다.
// 토큰 문법은 writing의 parse_tokens와 같습니다. 짝 없는 ]], 닫히지 않거나 중첩된 [[, 빈 글자, 빈 id,
// id 안의 |는 오류입니다. [[{param}]] 꼴은 그대로 둡니다.
func resolveTokens(e entry, index map[string]*termNames) (string, error) {
	var b strings.Builder
	rest := e.Text
	for {
		start := strings.Index(rest, tokenOpen)
		limit := start
		if start < 0 {
			limit = len(rest)
		}
		if strings.Contains(rest[:limit], tokenClose) {
			return "", fmt.Errorf("%s: 짝이 없는 ]]가 있습니다", e.where())
		}
		if start < 0 {
			b.WriteString(rest)
			return b.String(), nil
		}
		afterOpen := rest[start+len(tokenOpen):]
		end := strings.Index(afterOpen, tokenClose)
		if end < 0 {
			return "", fmt.Errorf("%s: 용어 토큰의 닫는 ]]가 없습니다", e.where())
		}
		replaced, err := resolveToken(e, afterOpen[:end], index[e.lang])
		if err != nil {
			return "", err
		}
		b.WriteString(rest[:start] + tokenOpen + replaced + tokenClose)
		rest = afterOpen[end+len(tokenClose):]
	}
}

// isTermID는 id가 용어 id 형식(<범주>.<값> 또는 tag.<키>)인지 봅니다.
func isTermID(id string) bool {
	category, value, ok := strings.Cut(id, ".")
	return ok && value != "" && (termCategories[category] || category+"." == tagKeyPrefix)
}

// resolveToken은 대괄호 안쪽 하나를 풀어 돌려줍니다.
func resolveToken(e entry, inner string, names *termNames) (string, error) {
	shown, id, hasID := strings.Cut(inner, termSeparator)
	if strings.Contains(inner, tokenOpen) || strings.TrimSpace(shown) == "" ||
		(hasID && (strings.TrimSpace(id) == "" || strings.Contains(id, termSeparator))) {
		return "", fmt.Errorf("%s: 용어 토큰 문법이 올바르지 않습니다", e.where())
	}
	if hasID {
		if !isTermID(id) {
			return "", fmt.Errorf("%s: 용어 id %q의 형식이 <범주>.<값> 또는 tag.<키>가 아닙니다", e.where(), id)
		}
		if names != nil && names.complete && !names.ids[id] {
			return "", fmt.Errorf("%s: 용어 id %q가 이 언어 사전에 없습니다", e.where(), id)
		}
		return inner, nil
	}
	if strings.HasPrefix(shown, "{") {
		return inner, nil
	}
	var ids map[string]bool
	if names != nil {
		ids = names.byText[inner]
	}
	switch {
	case len(ids) == 1:
		for id := range ids {
			return inner + termSeparator + id, nil
		}
	case len(ids) > 1:
		sorted := make([]string, 0, len(ids))
		for id := range ids {
			sorted = append(sorted, id)
		}
		sort.Strings(sorted)
		return "", fmt.Errorf("%s: 용어 토큰 [[%s]]이(가) 용어 %s 중 하나로 정해지지 않습니다. [[글자|용어 id]]로 적어야 합니다",
			e.where(), inner, strings.Join(sorted, ", "))
	}
	if names != nil && names.complete {
		return "", fmt.Errorf("%s: 용어 토큰 [[%s]]을(를) 이름으로 가진 용어가 없습니다", e.where(), inner)
	}
	// 그 언어의 이름 원고가 아직 다 차지 않았으면 풀지 않고 둡니다(writing 검사기와 같은 기준).
	return inner, nil
}
