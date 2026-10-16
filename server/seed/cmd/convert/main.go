// Command convert는 writing 원고 트리를 콘텐츠 시드 JSON으로 변환합니다.
//
// 사용: convert -writing <dir> -out <file> [-strict]
// 빠진 원고 목록은 stderr에 쓰고, -strict면 빠진 것이 있을 때 종료 코드 1로 끝납니다.
package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/june20516/myungli-diary/server/seed/convert"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "convert:", err)
		os.Exit(1)
	}
}

func run() error {
	writing := flag.String("writing", "", "writing 트리 경로 (slots/content, content/<lang>이 있는 곳)")
	out := flag.String("out", "", "시드 JSON 출력 파일")
	strict := flag.Bool("strict", false, "빠진 원고가 있으면 실패")
	flag.Parse()
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

	for _, m := range report.Missing {
		fmt.Fprintln(os.Stderr, "missing:", m)
	}
	fmt.Fprintf(os.Stderr, "version %s: 템플릿 %d개, 빠진 원고 %d개\n", s.Version, len(s.Templates), len(report.Missing))
	if *strict && len(report.Missing) > 0 {
		return fmt.Errorf("-strict: 빠진 원고 %d개", len(report.Missing))
	}
	return nil
}
