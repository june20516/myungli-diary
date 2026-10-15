// Package city는 출생지 도시 자료(GeoNames)를 바이너리에 내장하고 id로 조회합니다.
// 자료 출처와 라이선스, 생성 방법은 README.md를 봅니다.
package city

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"slices"
	"sync"
)

//go:embed data/cities.json.gz
var embeddedData []byte

// City는 출생지로 고를 수 있는 도시입니다.
//
// 이름 맵은 비공개 필드이고 값 복사로 전달되므로, 호출자가 내장 자료를 바꿀 수 없다는 것이
// 타입으로 보장됩니다(맵은 읽는 메서드로만 노출합니다).
type City struct {
	ID        string  // GeoNames geonameid
	Country   string  // ISO 3166-1 alpha-2
	Timezone  string  // IANA
	Longitude float64 // 도(degree), 동경이 양수

	names       map[string]string
	countryName map[string]string
	regionName  map[string]string // 1차 행정구역 이름, 없으면 nil
}

// Name은 도시 이름입니다. lang이 "ko"·"en"·"ja"가 아니면 en을 돌려줍니다.
func (c City) Name(lang string) string { return localized(c.names, lang) }

// CountryName은 나라 이름입니다. lang이 "ko"·"en"·"ja"가 아니면 en을 돌려줍니다.
func (c City) CountryName(lang string) string { return localized(c.countryName, lang) }

// RegionName은 1차 행정구역 이름입니다. 행정구역이 없으면 false입니다.
// lang이 "ko"·"en"·"ja"가 아니면 en을 돌려줍니다.
func (c City) RegionName(lang string) (string, bool) {
	if c.regionName == nil {
		return "", false
	}
	return localized(c.regionName, lang), true
}

func localized(m map[string]string, lang string) string {
	if v, ok := m[lang]; ok && isSupported(lang) {
		return v
	}
	return m["en"]
}

func isSupported(lang string) bool {
	return lang == "ko" || lang == "en" || lang == "ja"
}

// record는 내장 JSON의 한 도시이며 생성기(cmd/build)의 출력 모양과 같습니다.
type record struct {
	ID          string            `json:"id"`
	Names       map[string]string `json:"names"`
	Country     string            `json:"country"`
	CountryName map[string]string `json:"countryName"`
	RegionName  map[string]string `json:"regionName"`
	Timezone    string            `json:"timezone"`
	Longitude   float64           `json:"longitude"`
}

type index struct {
	all  []City // 영어 이름 순. 읽기 전용(All이 복사해 줍니다)
	byID map[string]City
}

// load는 내장 자료를 처음 쓸 때 한 번만 풉니다. init에서 풀면 이 패키지를 import만 해도
// 비용이 들기 때문입니다. 실패하면 빌드에 들어간 파일이 손상된 것(조립 오류)이므로 panic합니다.
var load = sync.OnceValue(func() index {
	zr, err := gzip.NewReader(bytes.NewReader(embeddedData))
	if err != nil {
		panic(fmt.Sprintf("city: 내장 자료 gzip 열기 실패: %v", err))
	}
	defer func() { _ = zr.Close() }()

	var records []record
	if err := json.NewDecoder(zr).Decode(&records); err != nil {
		panic(fmt.Sprintf("city: 내장 자료 JSON 해석 실패: %v", err))
	}
	cities := make([]City, 0, len(records))
	byID := make(map[string]City, len(records))
	for _, r := range records {
		c := City{
			ID:          r.ID,
			Country:     r.Country,
			Timezone:    r.Timezone,
			Longitude:   r.Longitude,
			names:       r.Names,
			countryName: r.CountryName,
			regionName:  r.RegionName,
		}
		cities = append(cities, c)
		byID[c.ID] = c
	}
	return index{all: cities, byID: byID}
})

// Lookup은 geonameid로 도시를 찾습니다.
func Lookup(id string) (City, bool) {
	c, ok := load().byID[id]
	return c, ok
}

// All은 모든 도시를 영어 이름 순으로 돌려줍니다. 슬라이스는 호출마다 복사하므로 순서를 바꾸거나
// 원소를 덮어써도 내장 자료에 영향이 없습니다. 이름 맵은 City가 공개하지 않아 바꿀 수 없습니다.
func All() []City {
	return slices.Clone(load().all)
}

var dataVersion = sync.OnceValue(func() string {
	sum := sha256.Sum256(embeddedData)
	return hex.EncodeToString(sum[:])[:12]
})

// DataVersion은 내장 파일 SHA-256의 앞 12자리 hex입니다.
func DataVersion() string { return dataVersion() }
