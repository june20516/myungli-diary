// Command convert는 법적 문서 원문(docs/legal)을 내장 문서 JSON으로 변환합니다.
//
// 사용: convert -legal <dir> -out <file>
package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/june20516/myungli-diary/server/legal"
	"github.com/june20516/myungli-diary/server/legal/convert"
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
	dir := fs.String("legal", "", "법적 문서 원문 디렉터리 (<언어>/<이름>.md가 있는 곳)")
	out := fs.String("out", "", "내장 문서 JSON 출력 파일")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *dir == "" || *out == "" {
		return fmt.Errorf("-legal과 -out이 필요합니다")
	}

	docs, err := convert.Run(*dir)
	if err != nil {
		return err
	}
	data, err := legal.Marshal(docs)
	if err != nil {
		return err
	}
	if err := os.WriteFile(*out, data, 0o644); err != nil { //nolint:gosec // 소스에 커밋하는 생성 파일이라 읽기 권한이 필요합니다.
		return fmt.Errorf("법적 문서 쓰기: %w", err)
	}
	log.New(stderr, "", 0).Printf("법적 문서 %d개\n", len(docs))
	return nil
}
