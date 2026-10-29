// Package cli는 server 바이너리의 하위 명령 진입점입니다.
package cli

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"slices"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/seed"
)

// ErrNotImplemented는 아직 채워지지 않은 하위 명령이 반환합니다(job *은 P8에서 채웁니다).
var ErrNotImplemented = errors.New("not implemented")

// 종료 코드입니다.
const (
	exitOK    = 0
	exitError = 1
	exitUsage = 2
)

// usageError는 사용법 오류를 실행 오류와 구분합니다.
type usageError struct{ msg string }

func (e *usageError) Error() string { return e.msg }

func usageErrorf(format string, args ...any) error {
	return &usageError{msg: fmt.Sprintf(format, args...)}
}

// loggedError는 이미 구조화 로그로 남긴 실행 오류입니다. Run이 같은 내용을 다시 출력하지 않도록 구분합니다.
type loggedError struct{ err error }

func (e *loggedError) Error() string { return e.err.Error() }
func (e *loggedError) Unwrap() error { return e.err }

// Command는 하위 명령 하나입니다. args에는 하위 명령 이름 뒤의 인자가 들어옵니다.
type Command func(ctx context.Context, args []string, getenv func(string) string, stdout, stderr io.Writer) error

// commands는 하위 명령 테이블입니다.
var commands = map[string]Command{
	"serve":   runServe,
	"migrate": runMigrate,
	"seed":    runSeed,
	"job":     runJob,
}

const usageText = `usage: server <command>

commands:
  serve                           HTTP 서버를 시작합니다
  migrate up|down|status          DB 마이그레이션을 실행합니다
  seed                            시드 데이터를 넣습니다
  job precompute|notify|retention 배치 작업을 실행합니다`

// Run은 하위 명령을 실행하고 종료 코드를 반환합니다.
// 0은 성공, 1은 실행 오류, 2는 사용법 오류입니다.
// getenv는 설정 값(환경 변수)을 읽는 함수이고, stdout·stderr는 각각 명령 결과와 로그·오류를 쓸 곳입니다.
// 모두 테스트에서 대체할 수 있도록 주입합니다.
func Run(ctx context.Context, args []string, getenv func(string) string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		_, _ = fmt.Fprintln(stderr, usageText)
		return exitUsage
	}

	command, ok := commands[args[0]]
	if !ok {
		_, _ = fmt.Fprintf(stderr, "unknown command %q\n%s\n", args[0], usageText)
		return exitUsage
	}

	err := command(ctx, args[1:], getenv, stdout, stderr)
	if err == nil {
		return exitOK
	}

	// 이미 구조화 로그로 남긴 오류는 다시 출력하지 않습니다.
	var logged *loggedError
	if errors.As(err, &logged) {
		return exitError
	}
	// 사용법 오류는 메시지가 이미 "usage: ..."이므로 접두어 없이 한 번만 출력합니다.
	var usageErr *usageError
	if errors.As(err, &usageErr) {
		_, _ = fmt.Fprintln(stderr, usageErr)
		return exitUsage
	}
	_, _ = fmt.Fprintf(stderr, "%s: %v\n", args[0], err)
	return exitError
}

var migrateDirections = []string{"up", "down", "status"}

// runMigrate는 DB에 migration을 적용하거나 되돌리거나 상태를 보여 줍니다.
func runMigrate(ctx context.Context, args []string, getenv func(string) string, stdout, stderr io.Writer) error {
	if len(args) != 1 || !slices.Contains(migrateDirections, args[0]) {
		return usageErrorf("usage: server migrate %s", strings.Join(migrateDirections, "|"))
	}
	direction := args[0]

	cfg, err := config.Load(getenv)
	if err != nil {
		return err
	}
	if err := cfg.RequireDatabase(); err != nil {
		return err
	}
	logger := logging.New(stderr, cfg.LogLevel, cfg.GCPProjectID)

	// 연결 문자열에는 비밀번호가 있을 수 있어 로그에는 오류만 남기고 주소는 남기지 않습니다.
	pool, closeDB, err := openDatabase(ctx, cfg)
	if err != nil {
		logger.ErrorContext(ctx, "DB 연결 실패", "error", err)
		return &loggedError{err: err}
	}
	defer closeDB()

	if direction == "status" {
		return printStatus(ctx, pool, stdout, logger)
	}
	if err := postgres.Migrate(ctx, pool, direction); err != nil {
		logger.ErrorContext(ctx, "migration 실패", "direction", direction, "error", err)
		return &loggedError{err: err}
	}
	logger.InfoContext(ctx, "migration 완료", "direction", direction)
	return nil
}

// printStatus는 migration 적용 상태를 표로 stdout에 씁니다.
func printStatus(ctx context.Context, pool *pgxpool.Pool, stdout io.Writer, logger *slog.Logger) error {
	statuses, err := postgres.Status(ctx, pool)
	if err != nil {
		logger.ErrorContext(ctx, "migration 상태 조회 실패", "error", err)
		return &loggedError{err: err}
	}
	for _, status := range statuses {
		state := "Pending"
		if status.Applied {
			state = "Applied"
		}
		_, _ = fmt.Fprintf(stdout, "%-8s %s\n", state, status.Source)
	}
	return nil
}

// runSeed는 내장 콘텐츠 시드를 DB에 적재하고 활성 시드로 바꿉니다. 같은 시드를 다시 돌려도 안전합니다.
func runSeed(ctx context.Context, args []string, getenv func(string) string, _, stderr io.Writer) error {
	if len(args) != 0 {
		return usageErrorf("usage: server seed")
	}

	cfg, err := config.Load(getenv)
	if err != nil {
		return err
	}
	if err := cfg.RequireDatabase(); err != nil {
		return err
	}
	logger := logging.New(stderr, cfg.LogLevel, cfg.GCPProjectID)

	s, err := seed.Load()
	if err != nil {
		logger.ErrorContext(ctx, "내장 시드 읽기 실패", "error", err)
		return &loggedError{err: err}
	}
	pool, closeDB, err := openDatabase(ctx, cfg)
	if err != nil {
		logger.ErrorContext(ctx, "DB 연결 실패", "error", err)
		return &loggedError{err: err}
	}
	defer closeDB()

	applied, err := content.Apply(ctx, pool, s)
	if err != nil {
		logger.ErrorContext(ctx, "시드 적재 실패", "version", s.Version, "error", err)
		return &loggedError{err: err}
	}
	logger.InfoContext(ctx, "시드 적용 완료", "version", s.Version, "newly_applied", applied, "templates", len(s.Templates))
	return nil
}

var jobNames = []string{"precompute", "notify", "retention"}

// runJob은 작업 이름을 검증하고 실행합니다. retention만 채워졌고, precompute·notify는 P8-3·P8-4에서 채웁니다.
func runJob(ctx context.Context, args []string, getenv func(string) string, _, stderr io.Writer) error {
	if len(args) != 1 || !slices.Contains(jobNames, args[0]) {
		return usageErrorf("usage: server job %s", strings.Join(jobNames, "|"))
	}
	if args[0] == "retention" {
		return runRetention(ctx, getenv, stderr)
	}
	return ErrNotImplemented
}

// openDatabase는 설정에 맞는 DB 연결 풀을 열고, 풀(과 Cloud SQL dialer)을 닫는 함수를 함께 돌려줍니다.
// CLOUD_SQL_INSTANCE가 있으면 Cloud SQL Go connector와 IAM 인증으로, 없으면 DATABASE_URL로 바로 붙습니다(S121).
func openDatabase(ctx context.Context, cfg config.Config) (*pgxpool.Pool, func(), error) {
	if cfg.CloudSQLInstance == "" {
		pool, err := postgres.Open(ctx, cfg.DatabaseURL)
		if err != nil {
			return nil, nil, err
		}
		return pool, pool.Close, nil
	}
	pool, closeDialer, err := postgres.OpenCloudSQL(ctx, cfg.DatabaseURL, cfg.CloudSQLInstance)
	if err != nil {
		return nil, nil, err
	}
	return pool, func() {
		pool.Close()
		_ = closeDialer()
	}, nil
}
