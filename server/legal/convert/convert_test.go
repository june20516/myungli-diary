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

	docs, err := convert.Run(dir, "")
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

	docs, err := convert.Run(dir, "")
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
		_, err := convert.Run(dir, "")
		assert.ErrorContains(t, err, "모르는 빈자리 표기 {{business.phone}}")
	})
	t.Run("표기 밖 중괄호", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "ko/terms.md", "# 약관\n\n{{ business.name }\n")
		_, err := convert.Run(dir, "")
		assert.ErrorContains(t, err, "빈자리 표기 밖")
	})
	t.Run("디렉터리 없음", func(t *testing.T) {
		_, err := convert.Run(filepath.Join(t.TempDir(), "nope"), "")
		assert.Error(t, err)
	})
	t.Run("모르는 문서 이름", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "ko/term.md", "# 약관\n")
		_, err := convert.Run(dir, "")
		assert.ErrorContains(t, err, "모르는 문서")
	})
	t.Run("1단계 제목 없음", func(t *testing.T) {
		dir := t.TempDir()
		write(t, dir, "ja/terms.md", "## 利用規約\n")
		_, err := convert.Run(dir, "")
		assert.ErrorContains(t, err, "1단계 제목")
	})
}

const supportKo = `# 고객 지원

앱 설정 > 문의하기에서 보내 주세요. 앱을 쓸 수 없으면 support@myungli-diary.app 또는
[메일](mailto:support@myungli-diary.app)로 보내 주세요.

계정 삭제는 [개인정보 처리방침](/legal/privacy?lang=ko) 9항을, 이용 조건은 [이용약관](/legal/terms?lang=ko)을 봅니다.
`

// 안내 페이지는 writing 원고 디렉터리에서 읽고, 법적 문서 뒤에 옵니다(D134).
func TestRun_ConvertsSupportPage(t *testing.T) {
	legalDir, pagesDir := t.TempDir(), t.TempDir()
	write(t, legalDir, "ko/terms.md", termsKo)
	write(t, pagesDir, "ko/support.md", supportKo)
	write(t, pagesDir, "README.md", "# 안내\n")

	docs, err := convert.Run(legalDir, pagesDir)
	require.NoError(t, err)

	require.Len(t, docs, 2)
	assert.Equal(t, legal.Terms, docs[0].Name)
	support := docs[1]
	assert.Equal(t, "ko", support.Lang)
	assert.Equal(t, legal.Support, support.Name)
	assert.Equal(t, "고객 지원", support.Title)
	assert.Contains(t, support.HTML, `<a href="/legal/privacy?lang=ko">개인정보 처리방침</a>`)
	assert.Contains(t, support.HTML, `<a href="mailto:support@myungli-diary.app">support@myungli-diary.app</a>`, "메일 주소 글자도 링크가 됨")
}

// writing 원고가 아직 없으면(디렉터리 없음) 안내 페이지 없이 변환합니다.
func TestRun_MissingPagesDirectoryIsEmpty(t *testing.T) {
	legalDir := t.TempDir()
	write(t, legalDir, "ko/terms.md", termsKo)

	docs, err := convert.Run(legalDir, filepath.Join(t.TempDir(), "pages"))
	require.NoError(t, err)
	assert.Len(t, docs, 1)
}

func TestRun_RejectsSupportPage(t *testing.T) {
	cases := map[string]struct{ rel, body, want string }{
		"바깥 링크":      {"ko/support.md", "# 지원\n\n[블로그](https://example.com)\n", "받지 않는 링크 https://example.com"},
		"다른 언어 처리방침": {"ko/support.md", "# 지원\n\n[방침](/legal/privacy?lang=en)\n", "받지 않는 링크 /legal/privacy?lang=en"},
		"다른 메일 주소":   {"en/support.md", "# Support\n\nhelp@example.com\n", "받지 않는 링크 mailto:help@example.com"},
		"이미지":        {"ja/support.md", "# サポート\n\n![図](/a.png)\n", "이미지 /a.png"},
		"법적 문서 이름":   {"ko/terms.md", "# 약관\n", "모르는 문서"},
		"1단계 제목 없음":  {"ko/support.md", "## 지원\n", "1단계 제목"},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			pagesDir := t.TempDir()
			write(t, pagesDir, tc.rel, tc.body)
			_, err := convert.Run(t.TempDir(), pagesDir)
			assert.ErrorContains(t, err, tc.want)
		})
	}
}

// 법적 문서는 링크를 검사하지 않습니다(원문은 지휘가 쓰고 사용자가 확정, D80).
func TestConvert_LegalDocumentLinksAreNotChecked(t *testing.T) {
	_, err := convert.Convert("ko", legal.Privacy, []byte("# 방침\n\n[위원회](https://www.pipc.go.kr)\n"))
	require.NoError(t, err)
}
