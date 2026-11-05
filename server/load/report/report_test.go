package main

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/csv"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

const rawHeader = "metric_name,timestamp,metric_value,check,error,error_code,expected_response,group,method,name,proto,scenario,service,status,subproto,tls_version,url,extra_tags,metadata\n"

func rawLine(metric string, ts int64, value, errorCode, scenario, status, operation string) string {
	return rawPhaseLine(metric, ts, value, errorCode, scenario, status, operation, "")
}

// rawPhaseLine은 extra_tags에 phase도 담은 원자료 행입니다(scenarios/ramp.js의 VU tag).
func rawPhaseLine(metric string, ts int64, value, errorCode, scenario, status, operation, phase string) string {
	extra := ""
	if operation != "" {
		extra = "operation=" + operation
	}
	if phase != "" {
		extra += "&phase=" + phase
	}
	return strings.Join([]string{metric, strconv.FormatInt(ts, 10), value, "", "", errorCode, "true", "", "GET", operation, "HTTP/2.0", scenario, "", status, "", "", operation, extra, ""}, ",") + "\n"
}

func TestAggregateStages_SplitsByScenarioAndOperation(t *testing.T) {
	raw := rawHeader +
		// setup 요청은 scenario가 없어 빠집니다.
		rawLine("http_reqs", 100, "1", "", "", "200", "testLogin") +
		rawLine("http_reqs", 1000, "1", "", "stage_2", "200", "getDaily") +
		rawLine("http_req_duration", 1000, "100", "", "stage_2", "200", "getDaily") +
		rawLine("http_reqs", 1001, "1", "", "stage_2", "200", "getDaily") +
		rawLine("http_req_duration", 1001, "300", "", "stage_2", "200", "getDaily") +
		rawLine("http_reqs", 1003, "1", "", "stage_2", "304", "getGlossary") +
		rawLine("http_req_duration", 1003, "20", "", "stage_2", "304", "getGlossary") +
		rawLine("http_reqs", 2000, "1", "1050", "stage_5", "0", "getDaily") +
		rawLine("http_reqs", 2000, "1", "", "stage_5", "503", "getDaily") +
		rawLine("http_reqs", 2001, "1", "", "stage_5", "429", "getDaily") +
		rawLine("http_reqs", 2001, "1", "", "stage_5", "404", "getDaily") +
		// operation tag가 없는 행(k6 내부 요청)은 빠집니다.
		rawLine("http_reqs", 2001, "1", "", "stage_5", "200", "")

	rows, err := AggregateStages(strings.NewReader(raw), map[string]bool{"stage_5": true})
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]StageRow{}
	for _, row := range rows {
		if row.Phase != allPhases {
			t.Errorf("phase tag가 없는 원자료는 all 행만 나와야 함: %+v", row)
		}
		got[row.Stage+"/"+row.Operation] = row
	}
	if len(rows) != 5 {
		t.Fatalf("행 %d개, 5개여야 함: %+v", len(rows), rows)
	}

	all2 := got["stage_2/all"]
	if all2.Requests != 3 || all2.Status2xx != 2 || all2.Status304 != 1 {
		t.Errorf("stage_2/all = %+v", all2)
	}
	// 단계 창은 1000~1003초, 4초 동안 3건입니다.
	if all2.ActualRPS != 0.75 || !all2.Start.Equal(time.Unix(1000, 0)) || !all2.End.Equal(time.Unix(1004, 0)) {
		t.Errorf("stage_2/all 창 = %v~%v, rps %v", all2.Start, all2.End, all2.ActualRPS)
	}
	daily2 := got["stage_2/getDaily"]
	// getDaily 2건은 단계 창(4초)으로 나눕니다.
	if daily2.ActualRPS != 0.5 || daily2.P50 != 200 || daily2.P95 != 290 {
		t.Errorf("stage_2/getDaily = %+v", daily2)
	}
	if daily2.Blocked {
		t.Error("stage_2는 멈추지 않았습니다")
	}

	daily5 := got["stage_5/getDaily"]
	if daily5.Timeouts != 1 || daily5.Status5xx != 1 || daily5.Status429 != 1 || daily5.Other != 1 || !daily5.Blocked {
		t.Errorf("stage_5/getDaily = %+v", daily5)
	}
	if !math.IsNaN(daily5.P95) {
		t.Errorf("duration 행이 없으면 백분위는 NaN이어야 함: %v", daily5.P95)
	}
	if rows[0].Stage != "stage_2" || rows[0].Operation != allOperations {
		t.Errorf("첫 행은 stage_2/all이어야 함: %s/%s", rows[0].Stage, rows[0].Operation)
	}
}

func TestAggregateStages_SplitsByPhase(t *testing.T) {
	raw := rawHeader +
		rawPhaseLine("http_reqs", 1000, "1", "", "stage_40", "200", "getDaily", "warmup") +
		rawPhaseLine("http_req_duration", 1000, "2500", "", "stage_40", "200", "getDaily", "warmup") +
		rawPhaseLine("http_reqs", 1001, "1", "", "stage_40", "200", "getAppConfig", "warmup") +
		rawPhaseLine("http_req_duration", 1001, "120", "", "stage_40", "200", "getAppConfig", "warmup") +
		rawPhaseLine("http_reqs", 1030, "1", "", "stage_40", "200", "getDaily", "steady") +
		rawPhaseLine("http_req_duration", 1030, "300", "", "stage_40", "200", "getDaily", "steady") +
		rawPhaseLine("http_reqs", 1031, "1", "", "stage_40", "503", "getDaily", "steady")

	rows, err := AggregateStages(strings.NewReader(raw), nil)
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]StageRow{}
	order := make([]string, 0, len(rows))
	for _, row := range rows {
		key := row.Phase + "/" + row.Operation
		got[key] = row
		order = append(order, key)
	}
	wantOrder := "all/all,all/getAppConfig,all/getDaily,warmup/all,warmup/getAppConfig,warmup/getDaily,steady/all,steady/getDaily"
	if strings.Join(order, ",") != wantOrder {
		t.Fatalf("행 순서 = %v, want %s", order, wantOrder)
	}

	if all := got["all/getDaily"]; all.Requests != 3 || all.Status5xx != 1 || all.P50 != 1400 {
		t.Errorf("all/getDaily = %+v", all)
	}
	warmup := got["warmup/getDaily"]
	// warmup 창은 1000~1001초(2초)입니다.
	if warmup.Requests != 1 || warmup.P95 != 2500 || warmup.ActualRPS != 0.5 || !warmup.End.Equal(time.Unix(1002, 0)) {
		t.Errorf("warmup/getDaily = %+v", warmup)
	}
	steady := got["steady/getDaily"]
	if steady.Requests != 2 || steady.Status5xx != 1 || steady.P95 != 300 || !steady.Start.Equal(time.Unix(1030, 0)) {
		t.Errorf("steady/getDaily = %+v", steady)
	}
}

func TestAggregateStages_MissingColumn(t *testing.T) {
	_, err := AggregateStages(strings.NewReader("metric_name,timestamp\n"), nil)
	if err == nil || !strings.Contains(err.Error(), "metric_value") {
		t.Fatalf("빠진 열 오류여야 함: %v", err)
	}
}

func TestPercentile(t *testing.T) {
	values := []float64{10, 20, 30, 40}
	cases := map[float64]float64{0: 10, 50: 25, 100: 40, 95: 38.5}
	for p, want := range cases {
		if got := percentile(values, p); math.Abs(got-want) > 1e-9 {
			t.Errorf("p%v = %v, want %v", p, got, want)
		}
	}
	if got := percentile([]float64{7}, 99); got != 7 {
		t.Errorf("값 하나의 p99 = %v", got)
	}
}

func TestBlockedStages(t *testing.T) {
	summary := `{"metrics":{
	  "http_req_failed{scenario:stage_40,phase:steady}":{"thresholds":{"rate<0.01":{"ok":false}}},
	  "http_req_duration{scenario:stage_20,operation:getDaily}":{"thresholds":{"p(95)<2000":{"ok":true}}},
	  "http_req_duration{phase:steady,operation:getDaily,scenario:stage_80}":{"thresholds":{"p(95)<2000":{"ok":false}}},
	  "checks":{"thresholds":{"rate==1":{"ok":false}}}
	}}`
	blocked, err := BlockedStages(strings.NewReader(summary))
	if err != nil {
		t.Fatal(err)
	}
	if !blocked["stage_40"] || !blocked["stage_80"] || blocked["stage_20"] || len(blocked) != 2 {
		t.Errorf("blocked = %v", blocked)
	}
}

func TestWriteStages_HeaderAndEmptyPercentile(t *testing.T) {
	var buf bytes.Buffer
	row := StageRow{StageRate: 5, Stage: "stage_5", Start: time.Unix(0, 0).UTC(), End: time.Unix(60, 0).UTC(), Phase: "steady", Operation: "getDaily",
		Requests: 1, ActualRPS: 1.0 / 60, P50: math.NaN(), P95: math.NaN(), P99: math.NaN(), Timeouts: 1, Blocked: true}
	if err := WriteStages(&buf, []StageRow{row}); err != nil {
		t.Fatal(err)
	}
	records, err := csv.NewReader(&buf).ReadAll()
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(records[0], ",") != strings.Join(stageHeader, ",") {
		t.Errorf("머리줄 = %v", records[0])
	}
	want := []string{"5", "1970-01-01T00:00:00Z", "1970-01-01T00:01:00Z", "steady", "getDaily", "1", "0.02", "", "", "", "0", "0", "0", "0", "0", "1", "true"}
	if strings.Join(records[1], ",") != strings.Join(want, ",") {
		t.Errorf("행 = %v, want %v", records[1], want)
	}
}

func TestMonitoringFetch_ParsesPagesAndValues(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.URL.Path != "/projects/p1/timeSeries" {
			t.Errorf("경로 = %s", r.URL.Path)
		}
		q := r.URL.Query()
		if q.Get("aggregation.alignmentPeriod") != "60s" || q.Get("interval.startTime") != "2026-11-04T08:00:00Z" {
			t.Errorf("query = %v", q)
		}
		filter := q.Get("filter")
		switch {
		case strings.Contains(filter, "instance_count") && q.Get("pageToken") == "":
			if q.Get("aggregation.groupByFields") != "resource.labels.service_name" {
				t.Errorf("Cloud Run 지표는 서비스별로 묶어야 함: %v", q)
			}
			_, _ = w.Write([]byte(`{"timeSeries":[{"resource":{"labels":{"service_name":"server"}},"points":[{"interval":{"endTime":"2026-11-04T08:01:00Z"},"value":{"int64Value":"3"}}]}],"nextPageToken":"next"}`))
		case strings.Contains(filter, "instance_count"):
			_, _ = w.Write([]byte(`{"timeSeries":[{"resource":{"labels":{"service_name":"engine"}},"points":[{"interval":{"endTime":"2026-11-04T08:01:00Z"},"value":{"int64Value":"1"}}]}]}`))
		case strings.Contains(filter, "billable_instance_time"):
			_, _ = w.Write([]byte(`{"timeSeries":[{"resource":{"labels":{"service_name":"server"}},"points":[{"interval":{"endTime":"2026-11-04T08:01:00Z"},"value":{"doubleValue":120}},{"interval":{"endTime":"2026-11-04T08:02:00Z"},"value":{"doubleValue":60}}]}]}`))
		case strings.Contains(filter, "num_backends"):
			if q.Get("aggregation.groupByFields") != "" {
				t.Errorf("Cloud SQL은 서비스로 묶지 않음: %v", q)
			}
			_, _ = w.Write([]byte(`{"timeSeries":[{"resource":{"labels":{"database_id":"x"}},"points":[{"interval":{"endTime":"2026-11-04T08:01:00Z"},"value":{"int64Value":"12"}}]}]}`))
		default:
			_, _ = w.Write([]byte(`{}`))
		}
	}))
	defer server.Close()

	start := time.Date(2026, 11, 4, 8, 0, 0, 0, time.UTC)
	end := start.Add(10 * time.Minute)
	rows, err := Monitoring{Client: server.Client(), Base: server.URL, Project: "p1"}.Fetch(context.Background(), start, end)
	if err != nil {
		t.Fatal(err)
	}
	if calls != len(seriesQueries)+1 {
		t.Errorf("API 호출 %d번, 지표 %d개 + 다음 쪽 1번이어야 함", calls, len(seriesQueries))
	}
	var lines []string
	for _, row := range rows {
		lines = append(lines, row.Time.Format("15:04")+" "+row.Metric+" "+row.Resource+" "+strconv.FormatFloat(row.Value, 'f', -1, 64))
	}
	want := []string{
		"08:01 billable_instance_time server 120",
		"08:01 instance_count engine 1",
		"08:01 instance_count server 3",
		"08:01 sql_connections sql 12",
		"08:02 billable_instance_time server 60",
	}
	if strings.Join(lines, "\n") != strings.Join(want, "\n") {
		t.Errorf("rows =\n%s\nwant\n%s", strings.Join(lines, "\n"), strings.Join(want, "\n"))
	}

	usage := Usage(rows, Sizes{VCPU: 1, MemoryGiB: 0.5}, start, end)
	if len(usage) != 2 || usage[0].Resource != "server" || usage[0].InstanceSeconds != 180 || usage[0].MemoryGiBSeconds != 90 {
		t.Errorf("usage = %+v", usage)
	}
	if usage[1].Resource != "sql" || math.Abs(usage[1].SQLHours-10.0/60) > 1e-9 {
		t.Errorf("sql usage = %+v", usage[1])
	}
}

func TestMonitoringFetch_APIError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, `{"error":{"message":"denied"}}`, http.StatusForbidden)
	}))
	defer server.Close()
	_, err := Monitoring{Client: server.Client(), Base: server.URL, Project: "p1"}.Fetch(context.Background(), time.Now(), time.Now())
	if err == nil || !strings.Contains(err.Error(), "403") {
		t.Fatalf("403 오류여야 함: %v", err)
	}
}

func TestReadStages_Gzip(t *testing.T) {
	raw := rawHeader + rawLine("http_reqs", 1000, "1", "", "stage_2", "200", "getDaily")
	dir := t.TempDir()
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	if _, err := gz.Write([]byte(raw)); err != nil {
		t.Fatal(err)
	}
	if err := gz.Close(); err != nil {
		t.Fatal(err)
	}
	for name, content := range map[string][]byte{"raw.csv.gz": buf.Bytes(), "raw.csv": []byte(raw)} {
		path := filepath.Join(dir, name)
		if err := os.WriteFile(path, content, 0o600); err != nil {
			t.Fatal(err)
		}
		rows, err := readStages(path, nil)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if len(rows) != 2 || rows[0].Requests != 1 {
			t.Errorf("%s: rows = %+v", name, rows)
		}
	}
}
