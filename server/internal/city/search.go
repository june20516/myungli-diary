package city

import (
	"slices"
	"strings"
	"sync"

	"golang.org/x/text/unicode/norm"
)

// searchEntry는 도시와 그 이름을 검색용으로 맞춘(NFC·소문자) 값입니다.
type searchEntry struct {
	city  City
	names map[string]string // 언어 → 맞춘 이름
}

// searchEntries는 검색용 색인이며 처음 검색할 때 한 번만 만듭니다. 읽기 전용입니다.
var searchEntries = sync.OnceValue(func() []searchEntry {
	all := load().all
	entries := make([]searchEntry, 0, len(all))
	for _, c := range all {
		names := make(map[string]string, len(c.names))
		for lang, name := range c.names {
			names[lang] = normalizeForSearch(name)
		}
		entries = append(entries, searchEntry{city: c, names: names})
	}
	return entries
})

// normalizeForSearch는 검색어와 이름을 같은 꼴(NFC·소문자)로 맞춥니다.
func normalizeForSearch(s string) string {
	return strings.ToLower(norm.NFC.String(s))
}

// Search는 q로 도시를 찾습니다(P6-9). NFC·소문자로 맞춘 q가 ko·en·ja 이름 중 하나의 앞부분과 같으면 후보입니다.
// 정렬은 ① 요청 언어 이름이 앞부분 일치인 도시 먼저 ② 요청 언어 이름(소문자) 순(같으면 id 순)이고, limit개까지 자릅니다.
// lang이 ko·en·ja가 아니면 en으로 봅니다. 결과가 없으면 빈 슬라이스입니다.
func Search(q, lang string, limit int) []City {
	if !isSupported(lang) {
		lang = "en"
	}
	query := strings.TrimSpace(normalizeForSearch(q))
	if query == "" {
		return []City{}
	}

	type match struct {
		city        City
		name        string // 요청 언어 이름(맞춘 꼴)
		langMatches bool
	}
	var matches []match
	for _, entry := range searchEntries() {
		if !hasNamePrefix(entry.names, query) {
			continue
		}
		name := normalizeForSearch(entry.city.Name(lang)) // 이름이 없으면 en으로 대체합니다.
		matches = append(matches, match{
			city:        entry.city,
			name:        name,
			langMatches: strings.HasPrefix(name, query),
		})
	}
	slices.SortFunc(matches, func(a, b match) int {
		if a.langMatches != b.langMatches {
			if a.langMatches {
				return -1
			}
			return 1
		}
		if c := strings.Compare(a.name, b.name); c != 0 {
			return c
		}
		return strings.Compare(a.city.ID, b.city.ID)
	})

	result := make([]City, 0, min(limit, len(matches)))
	for _, m := range matches[:min(max(limit, 0), len(matches))] {
		result = append(result, m.city)
	}
	return result
}

func hasNamePrefix(names map[string]string, query string) bool {
	for _, name := range names {
		if strings.HasPrefix(name, query) {
			return true
		}
	}
	return false
}
