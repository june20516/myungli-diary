//go:build enginecontract

package engine_test

import (
	"context"
	"fmt"
	"io"
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
	// passed는 모든 테스트가 통과했을 때만 true입니다. 아니면 정리 전에 엔진 로그를 출력합니다.
	passed := false
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
			// 기동 실패·health 타임아웃 원인을 CI에서 볼 수 있게 정리 전에 엔진 로그를 남깁니다(엔진 출력만 있고 출생 정보는 없음).
			if !passed {
				dumpLogs(termCtx, container)
			}
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
	passed = m.Run() == 0
	if passed {
		return 0
	}
	return 1
}

// dumpLogs는 컨테이너 로그를 stderr로 복사합니다.
func dumpLogs(ctx context.Context, container testcontainers.Container) {
	logs, err := container.Logs(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "엔진 로그 읽기 실패: %v\n", err)
		return
	}
	defer func() { _ = logs.Close() }()
	fmt.Fprintln(os.Stderr, "--- 엔진 컨테이너 로그 ---")
	_, _ = io.Copy(os.Stderr, logs)
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
	var lastErr error
	for {
		lastErr = checkServing(ctx, health, "", engineService)
		if lastErr == nil {
			return nil
		}
		select {
		case <-ctx.Done():
			return fmt.Errorf("%w (마지막 health 결과: %w)", ctx.Err(), lastErr)
		case <-ticker.C:
		}
	}
}

// checkServing은 모든 서비스가 SERVING이면 nil, 아니면 처음 만난 이유를 돌려줍니다.
func checkServing(ctx context.Context, health grpc_health_v1.HealthClient, services ...string) error {
	for _, service := range services {
		callCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
		resp, err := health.Check(callCtx, &grpc_health_v1.HealthCheckRequest{Service: service})
		cancel()
		if err != nil {
			return fmt.Errorf("서비스 %q health 호출: %w", service, err)
		}
		if resp.GetStatus() != grpc_health_v1.HealthCheckResponse_SERVING {
			return fmt.Errorf("서비스 %q 상태 %s", service, resp.GetStatus())
		}
	}
	return nil
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
	// 1990-05-15의 일주는 庚辰입니다(2000-01-01 戊午 기준 60갑자 일수 계산과 엔진 응답이 일치).
	day := chart.GetPillars().GetDay()
	require.NotNil(t, day)
	assert.Equal(t, enginev1.Stem_STEM_GYEONG, day.GetStem())
	assert.Equal(t, enginev1.Branch_BRANCH_JIN, day.GetBranch())
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

func TestRealEngine_LunarUpperBoundIsOutOfRange(t *testing.T) {
	// 지원 범위는 양력 2099-12-31까지라, 음력 2099년 12월은 양력 2100년에 걸쳐 범위를 벗어납니다.
	_, err := newRealClient(t).GetChart(t.Context(), &enginev1.ChartRequest{
		Birth: seoulBirth(enginev1.CalendarType_CALENDAR_TYPE_LUNAR, false, &enginev1.LocalDate{Year: 2099, Month: 12, Day: 29}),
		AsOf:  &enginev1.LocalDate{Year: 2026, Month: 10, Day: 15},
	})
	require.ErrorIs(t, err, engine.ErrOutOfRange)
}
