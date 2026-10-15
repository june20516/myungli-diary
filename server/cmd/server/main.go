// server는 명리일기 메인 API 서버의 진입점입니다.
package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	_ "time/tzdata" // distroless 이미지에는 시스템 tzdata가 없어 time.LoadLocation이 실패하므로 내장합니다.

	"github.com/june20516/myungli-diary/server/internal/cli"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	code := cli.Run(ctx, os.Args[1:], os.Getenv, os.Stdout, os.Stderr)
	stop()
	os.Exit(code)
}
