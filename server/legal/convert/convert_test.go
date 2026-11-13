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

// 빈자리 표기는 본문, 표 칸, 목록 어디서든 변환 뒤에도 글자 그대로 남습니다(D126 ②).
func TestConvert_KeepsBusinessPlaceholders(t *testing.T) {
	source := "# 이용약관\n\n상호: {{business.name}}, 대표자 **{{business.representative}}**\n\n" +
		"| 주소 | 번호 |\n| --- | --- |\n| {{business.address}} | {{business.registrationNumber}} |\n\n" +
		"* 통신판매업 신고번호 {{business.mailOrderNumber}}\n"
	doc, err := convert.Convert("ko", legal.Terms, []byte(source))
	require.NoError(t, err)
	for _, placeholder := range []string{
		legal.PlaceholderName, legal.PlaceholderRepresentative, legal.PlaceholderAddress,
		legal.PlaceholderRegistrationNumber, legal.PlaceholderMailOrderNumber,
	} {
		assert.Contains(t, doc.HTML, placeholder)
	}
	assert.Contains(t, doc.HTML, "<td>{{business.address}}</td>")
}

func TestRun_Rejects(t *testing.T) {
	t.Run("모르는 빈자리 표기", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "ko/terms.md", "# 약관\n\n{{business.phone}}\n")
		_, err := convert.Run(dir)
		assert.ErrorContains(t, err, "모르는 빈자리 표기 {{business.phone}}")
	})
	t.Run("표기 밖 중괄호", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "ko/terms.md", "# 약관\n\n{{ business.name }\n")
		_, err := convert.Run(dir)
		assert.ErrorContains(t, err, "빈자리 표기 밖")
	})
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
