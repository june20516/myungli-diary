//go:build enginecontract

package engine_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/health/grpc_health_v1"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
)

// 이 파일은 core가 만든 실제 엔진 이미지(core/Dockerfile)를 띄워 server의 클라이언트로 RPC를 부릅니다(#79).
// 기본 `go test ./...`에는 포함되지 않고 `-tags enginecontract`로만 돕니다. Docker가 필요합니다.

const (
	enginePort    = "50051/tcp"
	engineService = "myungli.engine.v1.MyungliEngine"
	// 이미지 빌드와 근거 데이터 검증·캐시 예열 시간을 합친 상한입니다.
	engineStartTimeout = 5 * time.Minute
	healthPollInterval = 500 * time.Millisecond
)

// engineAddr는 TestMain이 띄운 엔진 컨테이너의 host:port입니다. 패키지의 모든 테스트가 공유합니다.
var engineAddr string

func TestMain(m *testing.M) {
	os.Exit(run(m))
}

// run은 엔진 컨테이너를 한 번 띄우고 테스트를 돌린 뒤 컨테이너를 정리합니다.
func run(m *testing.M) int {
	ctx, cancel := context.WithTimeout(context.Background(), engineStartTimeout)
	defer cancel()

	container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: testcontainers.ContainerRequest{
			FromDockerfile: testcontainers.FromDockerfile{
				// core/만 빌드 맥락입니다(D33). 상대 경로는 이 패키지 디렉터리 기준입니다.
				Context:       "../../../core",
				Dockerfile:    "Dockerfile",
				PrintBuildLog: false,
			},
			Env:          map[string]string{"PORT": "50051"},
			ExposedPorts: []string{enginePort},
			WaitingFor:   wait.ForListeningPort(enginePort).WithStartupTimeout(engineStartTimeout),
		},
		Started: true,
	})
	if container != nil {
		defer func() {
			termCtx, termCancel := context.WithTimeout(context.Background(), time.Minute)
			defer termCancel()
			_ = container.Terminate(termCtx)
		}()
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "엔진 컨테이너 기동 실패: %v\n", err)
		return 1
	}

	host, err := container.Host(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "엔진 호스트 확인 실패: %v\n", err)
		return 1
	}
	port, err := container.MappedPort(ctx, enginePort)
	if err != nil {
		fmt.Fprintf(os.Stderr, "엔진 포트 확인 실패: %v\n", err)
		return 1
	}
	engineAddr = fmt.Sprintf("%s:%s", host, port.Port())

	if err := waitServing(ctx, engineAddr); err != nil {
		fmt.Fprintf(os.Stderr, "엔진이 SERVING이 되지 않음: %v\n", err)
		return 1
	}
	return m.Run()
}

// waitServing은 전체("")와 엔진 서비스의 health가 모두 SERVING이 될 때까지 폴링합니다.
func waitServing(ctx context.Context, addr string) error {
	conn, err := grpc.NewClient(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return fmt.Errorf("health 연결 생성: %w", err)
	}
	defer func() { _ = conn.Close() }()
	health := grpc_health_v1.NewHealthClient(conn)

	ticker := time.NewTicker(healthPollInterval)
	defer ticker.Stop()
	for {
		if allServing(ctx, health, "", engineService) {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}

func allServing(ctx context.Context, health grpc_health_v1.HealthClient, services ...string) bool {
	for _, service := range services {
		callCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
		resp, err := health.Check(callCtx, &grpc_health_v1.HealthCheckRequest{Service: service})
		cancel()
		if err != nil || resp.GetStatus() != grpc_health_v1.HealthCheckResponse_SERVING {
			return false
		}
	}
	return true
}

func newRealClient(t *testing.T) *engine.Client {
	t.Helper()
	client, err := engine.NewClient(engine.ClientConfig{Addr: engineAddr})
	require.NoError(t, err)
	t.Cleanup(func() { _ = client.Close() })
	return client
}

func seoulBirth(calendar enginev1.CalendarType, isLeap bool, date *enginev1.LocalDate) *enginev1.BirthInfo {
	return &enginev1.BirthInfo{
		Calendar:    calendar,
		IsLeapMonth: isLeap,
		Date:        date,
		Time:        &enginev1.LocalTime{Hour: 10, Minute: 30},
		Gender:      enginev1.Gender_GENDER_MALE,
		Timezone:    "Asia/Seoul",
	}
}

func TestRealEngine_GetInfo(t *testing.T) {
	info, err := newRealClient(t).GetInfo(t.Context())
	require.NoError(t, err)
	assert.NotEmpty(t, info.GetEngineVersion())
	assert.NotEmpty(t, info.GetRulesetVersion())
}

func TestRealEngine_GetChartSolar(t *testing.T) {
	client := newRealClient(t)
	info, err := client.GetInfo(t.Context())
	require.NoError(t, err)

	chart, err := client.GetChart(t.Context(), &enginev1.ChartRequest{
		Birth: seoulBirth(enginev1.CalendarType_CALENDAR_TYPE_SOLAR, false, &enginev1.LocalDate{Year: 1990, Month: 5, Day: 15}),
		AsOf:  &enginev1.LocalDate{Year: 2026, Month: 10, Day: 15},
	})
	require.NoError(t, err)
	assert.NotNil(t, chart.GetPillars().GetDay())
	assert.Equal(t, info.GetRulesetVersion(), chart.GetMeta().GetRulesetVersion())
}

func TestRealEngine_LunarLeapMissingIsInvalid(t *testing.T) {
	// 2026년 음력 1월에는 윤달이 없습니다.
	_, err := newRealClient(t).GetChart(t.Context(), &enginev1.ChartRequest{
		Birth: seoulBirth(enginev1.CalendarType_CALENDAR_TYPE_LUNAR, true, &enginev1.LocalDate{Year: 2026, Month: 1, Day: 1}),
		AsOf:  &enginev1.LocalDate{Year: 2026, Month: 10, Day: 15},
	})
	require.ErrorIs(t, err, engine.ErrInvalidArgument)
}

func TestRealEngine_PartialRangeMonthIsOutOfRange(t *testing.T) {
	// 지원 범위는 양력 1900-01-31부터라 1900년 1월은 일부만 걸친 달이고, 엔진은 OUT_OF_RANGE를 냅니다.
	// 음력 1900-01-01은 양력 1900-01-31이라 범위 안입니다(엔진이 차트를 계산함).
	_, err := newRealClient(t).GetMonthCalendar(t.Context(), &enginev1.MonthRequest{
		Birth:           seoulBirth(enginev1.CalendarType_CALENDAR_TYPE_SOLAR, false, &enginev1.LocalDate{Year: 1990, Month: 5, Day: 15}),
		Year:            1900,
		Month:           1,
		CurrentTimezone: "Asia/Seoul",
	})
	require.ErrorIs(t, err, engine.ErrOutOfRange)
}
