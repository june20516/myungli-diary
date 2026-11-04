package main

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"time"
)

// Cloud Monitoring 시계열(L1 plan §5 monitoring.csv, usage.csv)입니다. Monitoring API v3 projects.timeSeries.list를
// 1분 간격으로 정렬해 부릅니다. 지표 이름과 종류는 2026-11-04 부하 프로젝트의 metricDescriptors로 확인했습니다.

const monitoringAPI = "https://monitoring.googleapis.com/v3"

// seriesQuery는 monitoring.csv의 지표 하나입니다. Resource가 비면 Cloud Run 서비스 이름(server, engine)으로 나눕니다.
type seriesQuery struct {
	Name     string // monitoring.csv의 metric 값
	Unit     string
	Filter   string
	Aligner  string
	Reducer  string
	Resource string // 고정 resource 값(Cloud SQL은 "sql")
}

var seriesQueries = []seriesQuery{
	{"instance_count", "count", runFilter("run.googleapis.com/container/instance_count"), "ALIGN_MAX", "REDUCE_SUM", ""},
	{"request_count", "requests_per_min", runFilter("run.googleapis.com/request_count"), "ALIGN_DELTA", "REDUCE_SUM", ""},
	{"request_latency_p95", "ms", runFilter("run.googleapis.com/request_latencies"), "ALIGN_DELTA", "REDUCE_PERCENTILE_95", ""},
	{"cpu_utilization_mean", "ratio", runFilter("run.googleapis.com/container/cpu/utilizations"), "ALIGN_DELTA", "REDUCE_MEAN", ""},
	{"billable_instance_time", "seconds_per_min", runFilter("run.googleapis.com/container/billable_instance_time"), "ALIGN_DELTA", "REDUCE_SUM", ""},
	{"sql_connections", "count", sqlFilter("cloudsql.googleapis.com/database/postgresql/num_backends"), "ALIGN_MAX", "REDUCE_SUM", "sql"},
	{"sql_cpu_utilization", "ratio", sqlFilter("cloudsql.googleapis.com/database/cpu/utilization"), "ALIGN_MEAN", "REDUCE_MEAN", "sql"},
}

func runFilter(metric string) string {
	return fmt.Sprintf(`metric.type = %q AND resource.type = "cloud_run_revision"`, metric)
}

func sqlFilter(metric string) string {
	return fmt.Sprintf(`metric.type = %q AND resource.type = "cloudsql_database"`, metric)
}

// MonitoringRow는 monitoring.csv 한 줄입니다.
type MonitoringRow struct {
	Time     time.Time
	Metric   string
	Resource string
	Value    float64
	Unit     string
}

// Monitoring은 Monitoring API를 부릅니다. Client는 인증된 HTTP client(ADC)이고 Base는 API 주소입니다(시험에서 바꿈).
type Monitoring struct {
	Client  *http.Client
	Base    string
	Project string
}

// Fetch는 [start, end) 창의 지표를 모두 받아 시각, 지표, resource 순으로 돌려줍니다.
func (m Monitoring) Fetch(ctx context.Context, start, end time.Time) ([]MonitoringRow, error) {
	var rows []MonitoringRow
	for _, query := range seriesQueries {
		got, err := m.fetchSeries(ctx, query, start, end)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", query.Name, err)
		}
		rows = append(rows, got...)
	}
	sort.Slice(rows, func(i, j int) bool {
		if !rows[i].Time.Equal(rows[j].Time) {
			return rows[i].Time.Before(rows[j].Time)
		}
		if rows[i].Metric != rows[j].Metric {
			return rows[i].Metric < rows[j].Metric
		}
		return rows[i].Resource < rows[j].Resource
	})
	return rows, nil
}

type timeSeriesPage struct {
	TimeSeries []struct {
		Resource struct {
			Labels map[string]string `json:"labels"`
		} `json:"resource"`
		Points []struct {
			Interval struct {
				EndTime time.Time `json:"endTime"`
			} `json:"interval"`
			Value pointValue `json:"value"`
		} `json:"points"`
	} `json:"timeSeries"`
	NextPageToken string `json:"nextPageToken"`
}

// pointValue는 정렬, 축약 뒤의 값입니다. INT64는 JSON에서 문자열로 옵니다.
type pointValue struct {
	Int64Value  *string  `json:"int64Value"`
	DoubleValue *float64 `json:"doubleValue"`
}

func (v pointValue) float() (float64, error) {
	switch {
	case v.DoubleValue != nil:
		return *v.DoubleValue, nil
	case v.Int64Value != nil:
		return strconv.ParseFloat(*v.Int64Value, 64)
	default:
		return 0, fmt.Errorf("값이 int64Value나 doubleValue가 아닙니다")
	}
}

func (m Monitoring) fetchSeries(ctx context.Context, query seriesQuery, start, end time.Time) ([]MonitoringRow, error) {
	params := url.Values{}
	params.Set("filter", query.Filter)
	params.Set("interval.startTime", start.UTC().Format(time.RFC3339))
	params.Set("interval.endTime", end.UTC().Format(time.RFC3339))
	params.Set("aggregation.alignmentPeriod", "60s")
	params.Set("aggregation.perSeriesAligner", query.Aligner)
	params.Set("aggregation.crossSeriesReducer", query.Reducer)
	if query.Resource == "" {
		params.Set("aggregation.groupByFields", "resource.labels.service_name")
	}

	var rows []MonitoringRow
	for {
		page, err := m.page(ctx, params)
		if err != nil {
			return nil, err
		}
		for _, series := range page.TimeSeries {
			resource := query.Resource
			if resource == "" {
				resource = series.Resource.Labels["service_name"]
			}
			for _, point := range series.Points {
				value, err := point.Value.float()
				if err != nil {
					return nil, err
				}
				rows = append(rows, MonitoringRow{Time: point.Interval.EndTime.UTC(), Metric: query.Name, Resource: resource, Value: value, Unit: query.Unit})
			}
		}
		if page.NextPageToken == "" {
			return rows, nil
		}
		params.Set("pageToken", page.NextPageToken)
	}
}

func (m Monitoring) page(ctx context.Context, params url.Values) (timeSeriesPage, error) {
	endpoint := fmt.Sprintf("%s/projects/%s/timeSeries?%s", m.Base, url.PathEscape(m.Project), params.Encode())
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return timeSeriesPage{}, err
	}
	res, err := m.Client.Do(req)
	if err != nil {
		return timeSeriesPage{}, err
	}
	defer func() { _ = res.Body.Close() }() // 응답 본문을 다 읽은 뒤라 닫기 오류는 결과에 영향이 없습니다
	if res.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(res.Body, 2048))
		return timeSeriesPage{}, fmt.Errorf("Monitoring API %d: %s", res.StatusCode, body)
	}
	var page timeSeriesPage
	if err := json.NewDecoder(res.Body).Decode(&page); err != nil {
		return timeSeriesPage{}, fmt.Errorf("Monitoring API 응답: %w", err)
	}
	return page, nil
}

// WriteMonitoring은 monitoring.csv를 씁니다.
func WriteMonitoring(w io.Writer, rows []MonitoringRow) error {
	out := csv.NewWriter(w)
	if err := out.Write([]string{"time_utc", "metric", "resource", "value", "unit"}); err != nil {
		return err
	}
	for _, row := range rows {
		if err := out.Write([]string{row.Time.Format(time.RFC3339), row.Metric, row.Resource, strconv.FormatFloat(row.Value, 'f', -1, 64), row.Unit}); err != nil {
			return err
		}
	}
	out.Flush()
	return out.Error()
}

// UsageRow는 usage.csv 한 줄입니다. 금액은 넣지 않습니다(D74).
type UsageRow struct {
	Resource         string
	InstanceSeconds  float64
	VCPUSeconds      float64
	MemoryGiBSeconds float64
	SQLHours         float64
}

// Sizes는 서비스 인스턴스 하나의 크기입니다(deploy/terraform/env/run.tf, server와 엔진이 같음).
type Sizes struct {
	VCPU      float64
	MemoryGiB float64
}

// Usage는 billable_instance_time 합으로 서비스별 사용량을 내고, Cloud SQL은 측정 창 길이(시간)를 씁니다.
// SQL 인스턴스는 창 내내 켜져 있으므로 창 길이가 그대로 사용 시간입니다.
func Usage(rows []MonitoringRow, sizes Sizes, start, end time.Time) []UsageRow {
	seconds := map[string]float64{}
	for _, row := range rows {
		if row.Metric == "billable_instance_time" {
			seconds[row.Resource] += row.Value
		}
	}
	names := make([]string, 0, len(seconds))
	for name := range seconds {
		names = append(names, name)
	}
	sort.Strings(names)
	usage := make([]UsageRow, 0, len(names)+1)
	for _, name := range names {
		usage = append(usage, UsageRow{
			Resource:         name,
			InstanceSeconds:  seconds[name],
			VCPUSeconds:      seconds[name] * sizes.VCPU,
			MemoryGiBSeconds: seconds[name] * sizes.MemoryGiB,
		})
	}
	return append(usage, UsageRow{Resource: "sql", SQLHours: end.Sub(start).Hours()})
}

// WriteUsage는 usage.csv를 씁니다.
func WriteUsage(w io.Writer, rows []UsageRow) error {
	out := csv.NewWriter(w)
	if err := out.Write([]string{"resource", "instance_seconds", "vcpu_seconds", "memory_gib_seconds", "sql_hours"}); err != nil {
		return err
	}
	for _, row := range rows {
		record := []string{
			row.Resource, formatFloat(row.InstanceSeconds), formatFloat(row.VCPUSeconds),
			formatFloat(row.MemoryGiBSeconds), formatFloat(row.SQLHours),
		}
		if err := out.Write(record); err != nil {
			return err
		}
	}
	out.Flush()
	return out.Error()
}
