package convert_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/legal"
	"github.com/june20516/myungli-diary/server/legal/convert"
)

// write는 dir 아래 rel 경로에 원문을 씁니다.
func write(t *testing.T, dir, rel, body string) {
	t.Helper()
	path := filepath.Join(dir, rel)
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o750))
	require.NoError(t, os.WriteFile(path, []byte(body), 0o600))
}

const termsKo = `# 이용약관 *명리일기*

시행일: 2026-11-01

<script>alert(1)</script>

| 항목 | 내용 |
| --- | --- |
| 수집 | 생년월일 |
`

func TestRun_ConvertsExistingDocuments(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "README.md", "# 안내\n")
	write(t, dir, "ko/terms.md", termsKo)
	write(t, dir, "en/privacy.md", "Intro\n\n# Privacy Policy\n\n## Data\n")

	docs, err := convert.Run(dir)
	require.NoError(t, err)

	require.Len(t, docs, 2)
	ko := docs[0]
	assert.Equal(t, "ko", ko.Lang)
	assert.Equal(t, legal.Terms, ko.Name)
	assert.Equal(t, "이용약관 명리일기", ko.Title, "꾸밈은 글자만 남김")
	assert.Contains(t, ko.HTML, "<table>")
	assert.Contains(t, ko.HTML, "<td>생년월일</td>")
	assert.NotContains(t, ko.HTML, "<script>", "raw HTML은 걸러 냄")
	en := docs[1]
	assert.Equal(t, "en", en.Lang)
	assert.Equal(t, legal.Privacy, en.Name)
	assert.Equal(t, "Privacy Policy", en.Title, "첫 1단계 제목")
}

func TestRun_EmptyDirectoryHasNoDocuments(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "README.md", "# 안내\n")

	docs, err := convert.Run(dir)
	require.NoError(t, err)
	assert.Empty(t, docs)
}

func TestRun_Rejects(t *testing.T) {
	t.Run("디렉터리 없음", func(t *testing.T) {
		_, err := convert.Run(filepath.Join(t.TempDir(), "nope"))
		assert.Error(t, err)
	})
	t.Run("모르는 문서 이름", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "ko/term.md", "# 약관\n")
		_, err := convert.Run(dir)
		assert.ErrorContains(t, err, "모르는 법적 문서")
	})
	t.Run("1단계 제목 없음", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "ja/terms.md", "## 利用規約\n")
		_, err := convert.Run(dir)
		assert.ErrorContains(t, err, "1단계 제목")
	})
}
