// report는 부하 측정 1회차의 결과 파일(L1 plan §5, D104 ②)을 만듭니다.
//
//	go run ./load/report -raw .local/load/<회차>/raw.csv -summary docs/load/<회차>/k6-summary.json -out docs/load/<회차>
//
// stages.csv는 k6 원자료에서, monitoring.csv와 usage.csv는 Cloud Monitoring(ADC, monitoring.read)에서 만듭니다.
// Monitoring 지표는 몇 분 늦게 들어오므로 측정이 끝나고 5분쯤 뒤에 돌립니다. 열 이름과 단위는 server/load/README.md입니다.
package main

import (
	"compress/gzip"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"golang.org/x/oauth2/google"
)

type options struct {
	raw, summary, out, project string
	sizes                      Sizes
	skipMonitoring             bool
}

func main() {
	var opts options
	flag.StringVar(&opts.raw, "raw", "", "k6 --out csv 원자료 경로(필수, .gz면 압축을 풀며 읽음)")
	flag.StringVar(&opts.summary, "summary", "", "k6 handleSummary JSON 경로(필수, 멈춤 조건 판정)")
	flag.StringVar(&opts.out, "out", "", "결과 폴더(필수, server/docs/load/<날짜>-<회차>)")
	flag.StringVar(&opts.project, "project", "myungli-diary-load", "Cloud Monitoring을 읽을 GCP 프로젝트")
	flag.Float64Var(&opts.sizes.VCPU, "vcpu", 1, "Cloud Run 인스턴스 하나의 vCPU(run.tf)")
	flag.Float64Var(&opts.sizes.MemoryGiB, "memory-gib", 0.5, "Cloud Run 인스턴스 하나의 메모리 GiB(run.tf 512Mi)")
	flag.BoolVar(&opts.skipMonitoring, "skip-monitoring", false, "stages.csv만 만듭니다(로컬 확인)")
	flag.Parse()

	if err := run(context.Background(), opts); err != nil {
		fmt.Fprintln(os.Stderr, "report:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, opts options) error {
	if opts.raw == "" || opts.summary == "" || opts.out == "" {
		return errors.New("-raw, -summary, -out은 필수입니다")
	}
	blocked, err := readBlocked(opts.summary)
	if err != nil {
		return err
	}
	rows, err := readStages(opts.raw, blocked)
	if err != nil {
		return err
	}
	if len(rows) == 0 {
		return errors.New("원자료에 단계(stage_) 요청이 없습니다")
	}
	if err := os.MkdirAll(opts.out, 0o750); err != nil {
		return err
	}
	if err := writeFile(filepath.Join(opts.out, "stages.csv"), func(f *os.File) error { return WriteStages(f, rows) }); err != nil {
		return err
	}
	if opts.skipMonitoring {
		return nil
	}

	start, end := window(rows)
	client, err := google.DefaultClient(ctx, "https://www.googleapis.com/auth/monitoring.read")
	if err != nil {
		return fmt.Errorf("ADC(gcloud auth application-default login): %w", err)
	}
	series, err := Monitoring{Client: client, Base: monitoringAPI, Project: opts.project}.Fetch(ctx, start, end)
	if err != nil {
		return err
	}
	if err := writeFile(filepath.Join(opts.out, "monitoring.csv"), func(f *os.File) error { return WriteMonitoring(f, series) }); err != nil {
		return err
	}
	return writeFile(filepath.Join(opts.out, "usage.csv"), func(f *os.File) error {
		return WriteUsage(f, Usage(series, opts.sizes, start, end))
	})
}

// window는 Monitoring을 읽을 창입니다. 첫 단계 시작 1분 전부터 마지막 단계 끝 2분 뒤까지, 분 단위로 맞춥니다.
func window(rows []StageRow) (time.Time, time.Time) {
	start, end := rows[0].Start, rows[0].End
	for _, row := range rows {
		start = minTime(start, row.Start)
		end = maxTime(end, row.End)
	}
	return start.Add(-time.Minute).Truncate(time.Minute), end.Add(2 * time.Minute).Truncate(time.Minute)
}

func minTime(a, b time.Time) time.Time {
	if b.Before(a) {
		return b
	}
	return a
}

func maxTime(a, b time.Time) time.Time {
	if b.After(a) {
		return b
	}
	return a
}

func readBlocked(path string) (map[string]bool, error) {
	f, err := os.Open(path) //nolint:gosec // 경로는 이 도구를 돌리는 사람이 flag로 준 값입니다
	if err != nil {
		return nil, err
	}
	defer func() { _ = f.Close() }() // 읽기만 한 파일이라 닫기 오류는 결과에 영향이 없습니다
	return BlockedStages(f)
}

func readStages(path string, blocked map[string]bool) ([]StageRow, error) {
	f, err := os.Open(path) //nolint:gosec // 경로는 이 도구를 돌리는 사람이 flag로 준 값입니다
	if err != nil {
		return nil, err
	}
	defer func() { _ = f.Close() }() // 읽기만 한 파일이라 닫기 오류는 결과에 영향이 없습니다
	raw, err := rawReader(path, f)
	if err != nil {
		return nil, err
	}
	return AggregateStages(raw, blocked)
}

// rawReader는 원자료를 읽는 reader입니다. k6는 파일 이름이 .gz로 끝나면 gzip으로 쓰므로(생성기 Job 기본) 그때 압축을 풉니다.
func rawReader(path string, f io.Reader) (io.Reader, error) {
	if !strings.HasSuffix(path, ".gz") {
		return f, nil
	}
	gz, err := gzip.NewReader(f)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return gz, nil
}

func writeFile(path string, write func(*os.File) error) error {
	f, err := os.Create(path) //nolint:gosec // 경로는 flag -out 아래의 고정 파일 이름입니다
	if err != nil {
		return err
	}
	if err := write(f); err != nil {
		_ = f.Close()
		return fmt.Errorf("%s: %w", path, err)
	}
	return f.Close()
}
