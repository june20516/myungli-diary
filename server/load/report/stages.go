package main

import (
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"
)

// 단계 집계(L1 plan §5 stages.csv)입니다. k6 --out csv 원자료에서 scenario(stage_<세션/초>)와 operation tag로 나눕니다.
// setup 요청(scenario 없음)과 operation tag가 없는 행은 셈에서 뺍니다.

const (
	stagePrefix = "stage_"
	// allOperations는 단계 전체 행의 operation 값입니다.
	allOperations = "all"
	// k6가 요청 시간 초과에 붙이는 error_code입니다(k6 문서 "Error codes").
	timeoutErrorCode = "1050"
)

type stageKey struct {
	Stage     string
	Operation string
}

type stageAgg struct {
	Durations []float64
	Requests  int
	Status2xx int
	Status304 int
	Status429 int
	Status5xx int
	Other     int
	Timeouts  int
	First     int64
	Last      int64
}

// StageRow는 stages.csv 한 줄입니다.
type StageRow struct {
	StageRate  int
	Stage      string
	Start, End time.Time
	Operation  string
	Requests   int
	ActualRPS  float64
	P50, P95   float64
	P99        float64
	Status2xx  int
	Status304  int
	Status429  int
	Status5xx  int
	Other      int
	Timeouts   int
	Blocked    bool
}

// rawColumns는 원자료에서 읽는 열입니다.
var rawColumns = []string{"metric_name", "timestamp", "metric_value", "error_code", "scenario", "status", "extra_tags"}

// AggregateStages는 원자료를 읽어 단계와 operation별 행을 돌려줍니다. blocked는 멈춤 조건에 닿은 단계 이름입니다.
func AggregateStages(raw io.Reader, blocked map[string]bool) ([]StageRow, error) {
	reader := csv.NewReader(raw)
	reader.ReuseRecord = true
	header, err := reader.Read()
	if err != nil {
		return nil, fmt.Errorf("원자료 머리줄: %w", err)
	}
	index, err := columnIndex(header, rawColumns)
	if err != nil {
		return nil, err
	}

	aggs := map[stageKey]*stageAgg{}
	for {
		record, err := reader.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("원자료: %w", err)
		}
		stage := record[index["scenario"]]
		metric := record[index["metric_name"]]
		if !strings.HasPrefix(stage, stagePrefix) || (metric != "http_reqs" && metric != "http_req_duration") {
			continue
		}
		operation := extraTag(record[index["extra_tags"]], "operation")
		if operation == "" {
			continue
		}
		timestamp, err := strconv.ParseInt(record[index["timestamp"]], 10, 64)
		if err != nil {
			return nil, fmt.Errorf("timestamp %q: %w", record[index["timestamp"]], err)
		}
		for _, op := range []string{operation, allOperations} {
			agg := aggs[stageKey{stage, op}]
			if agg == nil {
				agg = &stageAgg{First: timestamp, Last: timestamp}
				aggs[stageKey{stage, op}] = agg
			}
			agg.First = min(agg.First, timestamp)
			agg.Last = max(agg.Last, timestamp)
			switch metric {
			case "http_req_duration":
				value, err := strconv.ParseFloat(record[index["metric_value"]], 64)
				if err != nil {
					return nil, fmt.Errorf("metric_value %q: %w", record[index["metric_value"]], err)
				}
				agg.Durations = append(agg.Durations, value)
			case "http_reqs":
				agg.count(record[index["status"]], record[index["error_code"]])
			}
		}
	}
	return stageRows(aggs, blocked)
}

func (a *stageAgg) count(status, errorCode string) {
	a.Requests++
	code, _ := strconv.Atoi(status)
	switch {
	case errorCode == timeoutErrorCode:
		a.Timeouts++
	case code == 304:
		a.Status304++
	case code >= 200 && code < 300:
		a.Status2xx++
	case code == 429:
		a.Status429++
	case code >= 500 && code < 600:
		a.Status5xx++
	default:
		a.Other++
	}
}

func stageRows(aggs map[stageKey]*stageAgg, blocked map[string]bool) ([]StageRow, error) {
	// 단계의 시간 창은 operation과 상관없이 그 단계 전체(all)의 첫 요청과 마지막 요청입니다.
	rows := make([]StageRow, 0, len(aggs))
	for key, agg := range aggs {
		rate, err := strconv.Atoi(strings.TrimPrefix(key.Stage, stagePrefix))
		if err != nil {
			return nil, fmt.Errorf("단계 이름 %q는 stage_<정수>가 아닙니다", key.Stage)
		}
		window := aggs[stageKey{key.Stage, allOperations}]
		seconds := float64(window.Last - window.First + 1)
		sort.Float64s(agg.Durations)
		rows = append(rows, StageRow{
			StageRate: rate,
			Stage:     key.Stage,
			Start:     time.Unix(window.First, 0).UTC(),
			End:       time.Unix(window.Last+1, 0).UTC(),
			Operation: key.Operation,
			Requests:  agg.Requests,
			ActualRPS: float64(agg.Requests) / seconds,
			P50:       percentile(agg.Durations, 50),
			P95:       percentile(agg.Durations, 95),
			P99:       percentile(agg.Durations, 99),
			Status2xx: agg.Status2xx,
			Status304: agg.Status304,
			Status429: agg.Status429,
			Status5xx: agg.Status5xx,
			Other:     agg.Other,
			Timeouts:  agg.Timeouts,
			Blocked:   blocked[key.Stage],
		})
	}
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].StageRate != rows[j].StageRate {
			return rows[i].StageRate < rows[j].StageRate
		}
		// 단계마다 all을 맨 앞에 둡니다.
		if (rows[i].Operation == allOperations) != (rows[j].Operation == allOperations) {
			return rows[i].Operation == allOperations
		}
		return rows[i].Operation < rows[j].Operation
	})
	return rows, nil
}

// percentile은 정렬된 값의 p 백분위입니다. 두 순위 사이는 선형 보간합니다(k6 요약과 같은 방식).
func percentile(sorted []float64, p float64) float64 {
	if len(sorted) == 0 {
		return math.NaN()
	}
	rank := p / 100 * float64(len(sorted)-1)
	lower := int(math.Floor(rank))
	upper := int(math.Ceil(rank))
	weight := rank - float64(lower)
	return sorted[lower]*(1-weight) + sorted[upper]*weight
}

// extraTag는 k6 csv의 extra_tags 열(k=v&k=v)에서 값 하나를 꺼냅니다.
func extraTag(extra, name string) string {
	values, err := url.ParseQuery(extra)
	if err != nil {
		return ""
	}
	return values.Get(name)
}

func columnIndex(header, wanted []string) (map[string]int, error) {
	index := map[string]int{}
	for i, name := range header {
		index[name] = i
	}
	for _, name := range wanted {
		if _, ok := index[name]; !ok {
			return nil, fmt.Errorf("원자료에 %s 열이 없습니다", name)
		}
	}
	return index, nil
}

// BlockedStages는 k6 요약(handleSummary JSON)에서 멈춤 조건이 실패한 단계 이름을 찾습니다.
// threshold 지표 이름은 http_req_failed{scenario:stage_40}처럼 scenario를 담습니다(scenarios/ramp.js).
func BlockedStages(summary io.Reader) (map[string]bool, error) {
	var parsed struct {
		Metrics map[string]struct {
			Thresholds map[string]struct {
				OK bool `json:"ok"`
			} `json:"thresholds"`
		} `json:"metrics"`
	}
	if err := json.NewDecoder(summary).Decode(&parsed); err != nil {
		return nil, fmt.Errorf("k6 요약: %w", err)
	}
	blocked := map[string]bool{}
	for name, metric := range parsed.Metrics {
		stage := scenarioTag(name)
		if stage == "" {
			continue
		}
		for _, threshold := range metric.Thresholds {
			if !threshold.OK {
				blocked[stage] = true
			}
		}
	}
	return blocked, nil
}

// scenarioTag는 "metric{scenario:stage_40,operation:getDaily}"에서 stage_40을 꺼냅니다.
func scenarioTag(metricName string) string {
	open := strings.Index(metricName, "{")
	if open < 0 || !strings.HasSuffix(metricName, "}") {
		return ""
	}
	for _, part := range strings.Split(metricName[open+1:len(metricName)-1], ",") {
		if value, ok := strings.CutPrefix(part, "scenario:"); ok {
			return value
		}
	}
	return ""
}

var stageHeader = []string{
	"stage_rate", "stage_start_utc", "stage_end_utc", "operation", "requests", "actual_rps",
	"p50_ms", "p95_ms", "p99_ms", "status_2xx", "status_304", "status_429", "status_5xx", "status_other", "timeouts", "blocked",
}

// WriteStages는 stages.csv를 씁니다. 열 이름과 단위는 server/load/README.md에 있습니다.
func WriteStages(w io.Writer, rows []StageRow) error {
	out := csv.NewWriter(w)
	if err := out.Write(stageHeader); err != nil {
		return err
	}
	for _, row := range rows {
		record := []string{
			strconv.Itoa(row.StageRate), row.Start.Format(time.RFC3339), row.End.Format(time.RFC3339), row.Operation,
			strconv.Itoa(row.Requests), formatFloat(row.ActualRPS), formatFloat(row.P50), formatFloat(row.P95), formatFloat(row.P99),
			strconv.Itoa(row.Status2xx), strconv.Itoa(row.Status304), strconv.Itoa(row.Status429), strconv.Itoa(row.Status5xx),
			strconv.Itoa(row.Other), strconv.Itoa(row.Timeouts), strconv.FormatBool(row.Blocked),
		}
		if err := out.Write(record); err != nil {
			return err
		}
	}
	out.Flush()
	return out.Error()
}

// formatFloat는 소수 둘째 자리까지 씁니다. 값이 없으면(요청 없는 operation의 백분위) 빈 칸입니다.
func formatFloat(value float64) string {
	if math.IsNaN(value) {
		return ""
	}
	return strconv.FormatFloat(value, 'f', 2, 64)
}
