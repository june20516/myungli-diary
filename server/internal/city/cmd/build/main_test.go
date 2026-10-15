package main

import (
	"archive/zip"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestPicker(t *testing.T) {
	tests := []struct {
		name  string
		offer func(p *picker)
		want  string
	}{
		{"preferred가 plain보다 우선", func(p *picker) {
			p.offer(1, "plain", false, false)
			p.offer(2, "preferred", true, false)
		}, "preferred"},
		{"preferred 중 id가 작은 값", func(p *picker) {
			p.offer(5, "늦은", true, false)
			p.offer(3, "이른", true, false)
		}, "이른"},
		{"short는 제외", func(p *picker) {
			p.offer(1, "short", false, true)
			p.offer(2, "plain", false, false)
		}, "plain"},
		{"short만 있으면 비어 있음", func(p *picker) {
			p.offer(1, "short", false, true)
		}, ""},
		{"preferred이면 short여도 채택", func(p *picker) {
			p.offer(1, "both", true, true)
		}, "both"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var p picker
			tt.offer(&p)
			assert.Equal(t, tt.want, p.value())
		})
	}
}

func writeZip(t *testing.T, dir, entry, content string) string {
	t.Helper()
	path := filepath.Join(dir, "x.zip")
	f, err := os.Create(path) //nolint:gosec // 테스트 임시 경로
	require.NoError(t, err)
	zw := zip.NewWriter(f)
	w, err := zw.Create(entry)
	require.NoError(t, err)
	_, err = w.Write([]byte(content))
	require.NoError(t, err)
	require.NoError(t, zw.Close())
	require.NoError(t, f.Close())
	return path
}

// alt는 alternateNamesV2 한 줄입니다: id, geonameid, lang, name, preferred, short, colloquial, historic.
func alt(id, lang, name, preferred, short, colloquial, historic string) string {
	return strings.Join([]string{id, "100", lang, name, preferred, short, colloquial, historic}, "\t")
}

func TestReadAlternates(t *testing.T) {
	lines := []string{
		alt("10", "ko", "역사", "1", "", "", "1"),       // historic 제외
		alt("11", "ko", "구어", "1", "", "1", ""),       // colloquial 제외
		alt("12", "ko", "짧음", "", "1", "", ""),        // short 제외
		alt("13", "ko", "늦은일반", "", "", "", ""),       // plain 후보
		alt("14", "ko", "대표", "1", "", "", ""),        // preferred
		alt("15", "ko", "또대표", "1", "", "", ""),       // 동점: 먼저 나온 id가 이김
		alt("16", "ja-Hira", "ひらがな", "1", "", "", ""), // 정확히 ja가 아니라 제외
		alt("17", "ja", "일본어", "", "", "", ""),
		"18\t999\tko\t다른개체\t1\t\t\t", // 필요한 id가 아님
	}
	zipPath := writeZip(t, t.TempDir(), "alternateNamesV2.txt", strings.Join(lines, "\n")+"\n")
	wanted := names{"100": {"ko": &picker{}, "en": &picker{}, "ja": &picker{}}}

	require.NoError(t, readAlternates(zipPath, wanted))

	assert.Equal(t, "대표", wanted["100"]["ko"].value())
	assert.Equal(t, "일본어", wanted["100"]["ja"].value())
	assert.Empty(t, wanted["100"]["en"].value())
}

func TestReadAlternates_SameTieSmallerIDWinsRegardlessOfOrder(t *testing.T) {
	lines := []string{alt("20", "ko", "나중", "1", "", "", ""), alt("19", "ko", "먼저", "1", "", "", "")}
	zipPath := writeZip(t, t.TempDir(), "alternateNamesV2.txt", strings.Join(lines, "\n")+"\n")
	wanted := names{"100": {"ko": &picker{}}}

	require.NoError(t, readAlternates(zipPath, wanted))

	assert.Equal(t, "먼저", wanted["100"]["ko"].value())
}

func TestReadAlternates_NonNumericID(t *testing.T) {
	zipPath := writeZip(t, t.TempDir(), "alternateNamesV2.txt", alt("abc", "ko", "이름", "1", "", "", "")+"\n")
	wanted := names{"100": {"ko": &picker{}}}

	assert.Error(t, readAlternates(zipPath, wanted))
}

func TestReadCities_NonNumericGeonameID(t *testing.T) {
	row := make([]string, 19)
	row[0], row[1], row[5] = "abc", "X", "10"
	zipPath := writeZip(t, t.TempDir(), "cities15000.txt", strings.Join(row, "\t")+"\n")

	_, err := readCities(zipPath)

	assert.Error(t, err)
}

func TestWrite_ReplacesAtomicallyAndLeavesNoTemp(t *testing.T) {
	dir := t.TempDir()
	out := filepath.Join(dir, "cities.json.gz")
	require.NoError(t, os.WriteFile(out, []byte("old"), 0o600))

	require.NoError(t, write(out, []record{{ID: "1", Names: map[string]string{"en": "A"}}}))

	got, err := os.ReadFile(out) //nolint:gosec // 테스트 임시 경로
	require.NoError(t, err)
	assert.NotEqual(t, "old", string(got))
	entries, err := os.ReadDir(dir)
	require.NoError(t, err)
	assert.Len(t, entries, 1)
}

func TestWrite_FailureLeavesNoTemp(t *testing.T) {
	dir := t.TempDir()
	out := filepath.Join(dir, "target") // 디렉터리라 rename이 실패합니다.
	require.NoError(t, os.Mkdir(out, 0o750))
	require.NoError(t, os.WriteFile(filepath.Join(out, "keep"), nil, 0o600))

	assert.Error(t, write(out, nil))

	entries, err := os.ReadDir(dir)
	require.NoError(t, err)
	assert.Len(t, entries, 1)
}
