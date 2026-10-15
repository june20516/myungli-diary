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
type City struct {
	ID          string            `json:"id"`                   // GeoNames geonameid
	Names       map[string]string `json:"names"`                // "ko"·"en"·"ja" → 이름
	Country     string            `json:"country"`              // ISO 3166-1 alpha-2
	CountryName map[string]string `json:"countryName"`          // "ko"·"en"·"ja" → 나라 이름
	RegionName  map[string]string `json:"regionName,omitempty"` // 1차 행정구역 이름, 없으면 nil
	Timezone    string            `json:"timezone"`             // IANA
	Longitude   float64           `json:"longitude"`
}

type index struct {
	all  []City
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

	var cities []City
	if err := json.NewDecoder(zr).Decode(&cities); err != nil {
		panic(fmt.Sprintf("city: 내장 자료 JSON 해석 실패: %v", err))
	}
	byID := make(map[string]City, len(cities))
	for _, c := range cities {
		byID[c.ID] = c
	}
	return index{all: cities, byID: byID}
})

// Lookup은 geonameid로 도시를 찾습니다.
func Lookup(id string) (City, bool) {
	c, ok := load().byID[id]
	return c, ok
}

// All은 모든 도시를 영어 이름 순으로 돌려줍니다. 호출자가 고쳐도 내장 자료는 바뀌지 않도록
// 목록은 복사합니다(각 도시의 맵은 읽기 전용으로 다룹니다).
func All() []City {
	return slices.Clone(load().all)
}

// DataVersion은 내장 파일 SHA-256의 앞 12자리 hex입니다.
func DataVersion() string {
	sum := sha256.Sum256(embeddedData)
	return hex.EncodeToString(sum[:])[:12]
}
