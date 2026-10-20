// Package convert는 법적 문서 원문(docs/legal/<언어>/<이름>.md)을 내장 문서(legal.Document)로 바꿉니다.
package convert

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/extension"
	"github.com/yuin/goldmark/text"

	"github.com/june20516/myungli-diary/server/legal"
)

// markdown은 원문 변환기입니다. GFM(표·취소선·자동 링크)을 켜고, raw HTML은 기본값대로 걸러 냅니다(html.WithUnsafe를 쓰지 않음).
var markdown = goldmark.New(goldmark.WithExtensions(extension.GFM))

// Run은 dir(docs/legal) 아래 언어 디렉터리의 원문을 모두 변환합니다. 원문이 없는 (언어, 이름)은 건너뜁니다.
// 언어 디렉터리에 모르는 .md 파일이 있거나, 원문에 1단계 제목이 없으면 오류입니다.
func Run(dir string) ([]legal.Document, error) {
	if info, err := os.Stat(dir); err != nil || !info.IsDir() {
		return nil, fmt.Errorf("법적 문서 디렉터리 %s가 없습니다", dir)
	}
	var docs []legal.Document
	for _, lang := range legal.Languages {
		langDir := filepath.Join(dir, lang)
		if err := checkNames(langDir); err != nil {
			return nil, err
		}
		for _, name := range legal.Names {
			source, err := os.ReadFile(filepath.Join(langDir, name+".md")) //nolint:gosec // 저장소 안 원문 경로입니다.
			if errors.Is(err, fs.ErrNotExist) {
				continue
			}
			if err != nil {
				return nil, fmt.Errorf("%s/%s 읽기: %w", lang, name, err)
			}
			doc, err := Convert(lang, name, source)
			if err != nil {
				return nil, err
			}
			docs = append(docs, doc)
		}
	}
	return docs, nil
}

// checkNames는 언어 디렉터리의 .md 파일이 모두 아는 문서 이름인지 봅니다. 디렉터리가 없으면 통과합니다.
func checkNames(langDir string) error {
	entries, err := os.ReadDir(langDir)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("%s 읽기: %w", langDir, err)
	}
	for _, e := range entries {
		name, ok := strings.CutSuffix(e.Name(), ".md")
		if ok && !e.IsDir() && !slices.Contains(legal.Names, name) {
			return fmt.Errorf("모르는 법적 문서 %s (문서 이름은 %s)", filepath.Join(langDir, e.Name()), strings.Join(legal.Names, ", "))
		}
	}
	return nil
}

// Convert는 원문 하나를 HTML로 바꾸고 첫 1단계 제목을 Title로 뽑습니다.
func Convert(lang, name string, source []byte) (legal.Document, error) {
	root := markdown.Parser().Parse(text.NewReader(source))
	title := firstTitle(root, source)
	if title == "" {
		return legal.Document{}, fmt.Errorf("%s/%s: 1단계 제목(# …)이 없습니다", lang, name)
	}
	var html bytes.Buffer
	if err := markdown.Renderer().Render(&html, source, root); err != nil {
		return legal.Document{}, fmt.Errorf("%s/%s 변환: %w", lang, name, err)
	}
	return legal.Document{Lang: lang, Name: name, Title: title, HTML: html.String()}, nil
}

// firstTitle은 문서에서 처음 나오는 1단계 제목의 글자입니다. 없으면 빈 문자열입니다.
func firstTitle(root ast.Node, source []byte) string {
	var title string
	_ = ast.Walk(root, func(n ast.Node, entering bool) (ast.WalkStatus, error) {
		if heading, ok := n.(*ast.Heading); ok && entering && heading.Level == 1 {
			title = strings.TrimSpace(plainText(heading, source))
			return ast.WalkStop, nil
		}
		return ast.WalkContinue, nil
	})
	return title
}

// plainText는 노드 아래 글자 조각을 이은 문자열입니다(강조·링크 같은 꾸밈은 글자만 남김).
func plainText(n ast.Node, source []byte) string {
	var b strings.Builder
	_ = ast.Walk(n, func(child ast.Node, entering bool) (ast.WalkStatus, error) {
		if !entering {
			return ast.WalkContinue, nil
		}
		switch t := child.(type) {
		case *ast.Text:
			b.Write(t.Segment.Value(source))
			if t.SoftLineBreak() || t.HardLineBreak() {
				b.WriteByte(' ')
			}
		case *ast.String:
			b.Write(t.Value)
		}
		return ast.WalkContinue, nil
	})
	return b.String()
}
