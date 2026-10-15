// build는 GeoNames 원본에서 internal/city/data/cities.json.gz를 만드는 생성기입니다.
// 원본은 직접 받아 경로로 넘깁니다(다운로드하지 않음). 사용법은 internal/city/README.md를 봅니다.
//
// 같은 입력이면 같은 바이트가 나옵니다(정렬된 키, gzip header의 mtime 0·이름 없음).
package main

import (
	"archive/zip"
	"bufio"
	"compress/gzip"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path"
	"sort"
	"strconv"
	"strings"
)

// languages는 자료에 담는 언어입니다. isolanguage가 정확히 같은 것만 씁니다(ja-Hira 등 제외).
var languages = []string{"ko", "en", "ja"}

// record는 출력 JSON의 한 도시이며 internal/city.City의 JSON 모양과 같아야 합니다.
// city 패키지는 출력 파일을 go:embed하므로 생성기가 그 패키지를 import하지 않습니다.
type record struct {
	ID          string            `json:"id"`
	Names       map[string]string `json:"names"`
	Country     string            `json:"country"`
	CountryName map[string]string `json:"countryName"`
	RegionName  map[string]string `json:"regionName,omitempty"`
	Timezone    string            `json:"timezone"`
	Longitude   float64           `json:"longitude"`
}

// place는 이름이 필요한 GeoNames 개체(도시·나라·1차 행정구역)입니다.
type place struct {
	geonameID string
	fallback  string // GeoNames 기본 이름(en도 없을 때)
}

// picker는 한 개체의 한 언어에서 이름을 고릅니다.
// isPreferredName인 첫 값이 우선이고, 없으면 isShortName이 아닌 첫 값입니다.
// 파일 순서(alternateNameId 오름차순)로 처음 나온 값을 쓰므로 결과가 재현됩니다.
type picker struct{ preferred, plain string }

func (p *picker) offer(name string, isPreferred, isShort bool) {
	switch {
	case isPreferred:
		if p.preferred == "" {
			p.preferred = name
		}
	case !isShort:
		if p.plain == "" {
			p.plain = name
		}
	}
}

func (p *picker) value() string {
	if p.preferred != "" {
		return p.preferred
	}
	return p.plain
}

// names는 geonameid → 언어 → picker입니다.
type names map[string]map[string]*picker

func main() {
	var citiesZip, countries, admin1, alternatesZip, out string
	flag.StringVar(&citiesZip, "cities", "", "cities15000.zip 경로")
	flag.StringVar(&countries, "countries", "", "countryInfo.txt 경로")
	flag.StringVar(&admin1, "admin1", "", "admin1CodesASCII.txt 경로")
	flag.StringVar(&alternatesZip, "alternates", "", "alternateNamesV2.zip 경로")
	flag.StringVar(&out, "out", "", "출력 cities.json.gz 경로")
	flag.Parse()
	if citiesZip == "" || countries == "" || admin1 == "" || alternatesZip == "" || out == "" {
		flag.Usage()
		os.Exit(2)
	}
	if err := run(citiesZip, countries, admin1, alternatesZip, out); err != nil {
		fmt.Fprintln(os.Stderr, "build:", err)
		os.Exit(1)
	}
}

type rawCity struct {
	place
	country, admin1, timezone string
	longitude                 float64
}

func run(citiesZip, countriesPath, admin1Path, alternatesZip, out string) error {
	cities, err := readCities(citiesZip)
	if err != nil {
		return err
	}
	countryByCode, err := readCountries(countriesPath)
	if err != nil {
		return err
	}
	admin1ByKey, err := readAdmin1(admin1Path)
	if err != nil {
		return err
	}

	// 이름이 필요한 geonameid만 모읍니다. 대안 이름 파일이 수백 MB라 거르면서 읽습니다.
	wanted := names{}
	want := func(id string) {
		if id == "" {
			return
		}
		wanted[id] = map[string]*picker{}
		for _, lang := range languages {
			wanted[id][lang] = &picker{}
		}
	}
	for _, c := range cities {
		want(c.geonameID)
		want(countryByCode[c.country].geonameID)
		want(admin1ByKey[c.country+"."+c.admin1].geonameID)
	}
	if err := readAlternates(alternatesZip, wanted); err != nil {
		return err
	}

	records := make([]record, 0, len(cities))
	for _, c := range cities {
		if _, ok := countryByCode[c.country]; !ok {
			return fmt.Errorf("도시 %s의 나라 %q가 countryInfo에 없음", c.geonameID, c.country)
		}
		r := record{
			ID:          c.geonameID,
			Names:       resolve(wanted, c.place),
			Country:     c.country,
			CountryName: resolve(wanted, countryByCode[c.country]),
			Timezone:    c.timezone,
			Longitude:   c.longitude,
		}
		if region, ok := admin1ByKey[c.country+"."+c.admin1]; ok {
			r.RegionName = resolve(wanted, region)
		}
		records = append(records, r)
	}
	sortByEnglishName(records)
	return write(out, records)
}

// resolve는 세 언어 이름을 채웁니다. 없는 언어는 en, en도 없으면 GeoNames 기본 이름입니다.
func resolve(wanted names, p place) map[string]string {
	result := make(map[string]string, len(languages))
	en := p.fallback
	if v := wantedValue(wanted, p.geonameID, "en"); v != "" {
		en = v
	}
	for _, lang := range languages {
		if v := wantedValue(wanted, p.geonameID, lang); v != "" {
			result[lang] = v
		} else {
			result[lang] = en
		}
	}
	return result
}

func wantedValue(wanted names, id, lang string) string {
	if p, ok := wanted[id][lang]; ok {
		return p.value()
	}
	return ""
}

// sortByEnglishName은 소문자 en 이름, 같으면 geonameid 숫자 순으로 고정합니다.
func sortByEnglishName(records []record) {
	sort.Slice(records, func(i, j int) bool {
		a, b := strings.ToLower(records[i].Names["en"]), strings.ToLower(records[j].Names["en"])
		if a != b {
			return a < b
		}
		ai, _ := strconv.Atoi(records[i].ID)
		bi, _ := strconv.Atoi(records[j].ID)
		return ai < bi
	})
}

func write(out string, records []record) error {
	f, err := os.Create(out) //nolint:gosec // 생성기 인자로 받은 경로
	if err != nil {
		return err
	}
	// Header를 비워 두면 mtime 0, 이름 없음으로 써서 바이트가 재현됩니다.
	zw, err := gzip.NewWriterLevel(f, gzip.BestCompression)
	if err != nil {
		_ = f.Close()
		return err
	}
	enc := json.NewEncoder(zw) // 맵 키는 정렬되어 나옵니다.
	if err := enc.Encode(records); err != nil {
		_ = f.Close()
		return err
	}
	if err := zw.Close(); err != nil {
		_ = f.Close()
		return err
	}
	return f.Close()
}

// tsvLines는 탭 구분 텍스트를 한 줄씩 읽어 fields로 넘깁니다. '#' 줄과 빈 줄은 건너뜁니다.
func tsvLines(r io.Reader, minFields int, fn func(fields []string) error) error {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 1<<20), 16<<20)
	for lineNo := 1; sc.Scan(); lineNo++ {
		line := sc.Text()
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.Split(line, "\t")
		if len(fields) < minFields {
			return fmt.Errorf("%d번째 줄의 열이 %d개 미만", lineNo, minFields)
		}
		if err := fn(fields); err != nil {
			return fmt.Errorf("%d번째 줄: %w", lineNo, err)
		}
	}
	return sc.Err()
}

// openZipEntry는 zip 안에서 base 이름이 name인 파일을 엽니다.
func openZipEntry(zipPath, name string) (io.ReadCloser, func() error, error) {
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return nil, nil, err
	}
	for _, f := range zr.File {
		if path.Base(f.Name) == name {
			rc, err := f.Open()
			if err != nil {
				_ = zr.Close()
				return nil, nil, err
			}
			return rc, zr.Close, nil
		}
	}
	_ = zr.Close()
	return nil, nil, fmt.Errorf("%s 안에 %s 없음", zipPath, name)
}

// cities15000 열: 0 geonameid, 1 name, 4 lat, 5 lon, 8 country code, 10 admin1, 17 timezone.
func readCities(zipPath string) ([]rawCity, error) {
	rc, closeZip, err := openZipEntry(zipPath, "cities15000.txt")
	if err != nil {
		return nil, err
	}
	defer func() { _ = closeZip() }()
	defer func() { _ = rc.Close() }()

	var cities []rawCity
	seen := map[string]bool{}
	err = tsvLines(rc, 19, func(f []string) error {
		lon, err := strconv.ParseFloat(f[5], 64)
		if err != nil {
			return fmt.Errorf("경도: %w", err)
		}
		if seen[f[0]] {
			return errors.New("geonameid 중복")
		}
		seen[f[0]] = true
		cities = append(cities, rawCity{
			place:     place{geonameID: f[0], fallback: f[1]},
			country:   f[8],
			admin1:    f[10],
			timezone:  f[17],
			longitude: lon,
		})
		return nil
	})
	return cities, err
}

// countryInfo 열: 0 ISO, 4 Country, 16 geonameid.
func readCountries(p string) (map[string]place, error) {
	f, err := os.Open(p) //nolint:gosec // 생성기 인자로 받은 경로
	if err != nil {
		return nil, err
	}
	defer func() { _ = f.Close() }()
	result := map[string]place{}
	err = tsvLines(f, 17, func(fields []string) error {
		result[fields[0]] = place{geonameID: fields[16], fallback: fields[4]}
		return nil
	})
	return result, err
}

// admin1CodesASCII 열: 0 code(CC.A1), 1 name, 3 geonameid.
func readAdmin1(p string) (map[string]place, error) {
	f, err := os.Open(p) //nolint:gosec // 생성기 인자로 받은 경로
	if err != nil {
		return nil, err
	}
	defer func() { _ = f.Close() }()
	result := map[string]place{}
	err = tsvLines(f, 4, func(fields []string) error {
		result[fields[0]] = place{geonameID: fields[3], fallback: fields[1]}
		return nil
	})
	return result, err
}

// alternateNamesV2 열: 0 alternateNameId, 1 geonameid, 2 isolanguage, 3 name,
// 4 isPreferredName, 5 isShortName, 6 isColloquial, 7 isHistoric.
func readAlternates(zipPath string, wanted names) error {
	rc, closeZip, err := openZipEntry(zipPath, "alternateNamesV2.txt")
	if err != nil {
		return err
	}
	defer func() { _ = closeZip() }()
	defer func() { _ = rc.Close() }()

	return tsvLines(rc, 8, func(f []string) error {
		byLang, ok := wanted[f[1]]
		if !ok {
			return nil
		}
		p, ok := byLang[f[2]] // 정확히 ko·en·ja인 것만
		if !ok {
			return nil
		}
		if f[6] == "1" || f[7] == "1" || f[3] == "" {
			return nil
		}
		p.offer(f[3], f[4] == "1", f[5] == "1")
		return nil
	})
}
