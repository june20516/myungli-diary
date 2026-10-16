// Command convert는 writing 원고 트리를 콘텐츠 시드 JSON으로 변환합니다.
//
// 사용: convert -writing <dir> -out <file> [-strict]
// 빠진 원고 목록은 stderr에 쓰고, -strict면 빠진 것이 있을 때 종료 코드 1로 끝납니다.
package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/june20516/myungli-diary/server/seed/convert"
)

func main() {
	os.Exit(run(os.Args[1:], os.Stderr))
}

// run은 명령 본체입니다. 종료 코드를 돌려주고 모든 메시지를 stderr에 씁니다.
func run(args []string, stderr io.Writer) int {
	if err := execute(args, stderr); err != nil {
		log.New(stderr, "", 0).Println("convert:", err)
		return 1
	}
	return 0
}

func execute(args []string, stderr io.Writer) error {
	fs := flag.NewFlagSet("convert", flag.ContinueOnError)
	fs.SetOutput(stderr)
	writing := fs.String("writing", "", "writing 트리 경로 (slots/content, content/<lang>이 있는 곳)")
	out := fs.String("out", "", "시드 JSON 출력 파일")
	strict := fs.Bool("strict", false, "빠진 원고가 있으면 실패")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *writing == "" || *out == "" {
		return fmt.Errorf("-writing과 -out이 필요합니다")
	}

	s, report, err := convert.Run(*writing)
	if err != nil {
		return err
	}
	data, err := s.MarshalIndent()
	if err != nil {
		return err
	}
	if err := os.WriteFile(*out, data, 0o644); err != nil { //nolint:gosec // 소스에 커밋하는 생성 파일이라 읽기 권한이 필요합니다.
		return fmt.Errorf("시드 쓰기: %w", err)
	}

	logger := log.New(stderr, "", 0)
	for _, m := range report.Missing {
		logger.Println("missing:", m)
	}
	logger.Printf("version %s: 템플릿 %d개, 빠진 원고 %d개\n", s.Version, len(s.Templates), len(report.Missing))
	if *strict && len(report.Missing) > 0 {
		return fmt.Errorf("-strict: 빠진 원고 %d개", len(report.Missing))
	}
	return nil
}
