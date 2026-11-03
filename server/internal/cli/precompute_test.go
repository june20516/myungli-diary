package cli

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// noopCharts는 프로필 저장 때 원국 확인을 통과시키는 대역입니다.
type noopCharts struct{}

func (noopCharts) Chart(context.Context, profile.Birth, profile.LocalDate) (*enginev1.ChartResponse, error) {
	return &enginev1.ChartResponse{}, nil
}

// createPrecomputeTarget은 now에 활동한 서울 시간대 계정과 프로필을 만듭니다.
func createPrecomputeTarget(t *testing.T, pool *pgxpool.Pool, now time.Time) {
	t.Helper()
	id := uuid.New()
	require.NoError(t, authdb.New(pool).CreateAccount(t.Context(), authdb.CreateAccountParams{ID: id, LastActiveAt: now}))
	_, err := profile.NewService(pool, noopCharts{}, clocktest.New(now)).Put(t.Context(), id, profile.Profile{
		Honorific:       "민지",
		Language:        "ko",
		CurrentTimezone: "Asia/Seoul",
		Birth: profile.Birth{
			Calendar: profile.CalendarSolar, Date: profile.LocalDate{Year: 1990, Month: 5, Day: 17},
			TimeStatus: profile.TimeUnknown, Gender: "female", Timezone: "Asia/Seoul", PlaceStatus: profile.PlaceSkipped,
		},
		Notification: profile.Notification{Status: profile.NotifyDisabled},
	})
	require.NoError(t, err)
}

// rulesetEngine은 응답에 ruleset_version을 넣어 캐시에 저장되게 하는 엔진 대역입니다.
func rulesetEngine() *enginetest.Fake {
	meta := &enginev1.ResponseMeta{RulesetVersion: "rs-1"}
	return &enginetest.Fake{
		Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
			return &enginev1.DailyResponse{Meta: meta}, nil
		},
	}
}

// precompute가 서울 22:10에 다음 날 데일리를 캐시에 채우고, 다시 돌면 캐시를 써 엔진을 부르지 않는다.
func TestJobPrecompute_FillsDailyCache(t *testing.T) {
	pool := dbtest.New(t)
	now := time.Date(2026, 11, 3, 13, 10, 0, 0, time.UTC) // 서울 22:10
	createPrecomputeTarget(t, pool, now)
	fake := rulesetEngine()
	deps := precomputeDeps{Pool: pool, Engine: fake, Clock: clocktest.New(now), Logger: slog.New(slog.DiscardHandler)}

	require.NoError(t, precomputeJob(t.Context(), deps))

	var rows int
	require.NoError(t, pool.QueryRow(t.Context(),
		`SELECT count(*) FROM daily_cache WHERE date = '2026-11-04' AND current_timezone = 'Asia/Seoul'`).Scan(&rows))
	assert.Equal(t, 1, rows)
	assert.Equal(t, int64(1), fake.DailyCalls.Load())

	require.NoError(t, precomputeJob(t.Context(), deps))
	assert.Equal(t, int64(1), fake.DailyCalls.Load(), "두 번째 실행은 캐시를 씁니다")
}

// 엔진 버전을 받지 못하면 job이 실패하고 데일리를 부르지 않는다.
func TestJobPrecompute_EngineInfoFailureIsError(t *testing.T) {
	pool := dbtest.New(t)
	now := time.Date(2026, 11, 3, 13, 10, 0, 0, time.UTC)
	createPrecomputeTarget(t, pool, now)
	fake := rulesetEngine()
	fake.Info = func() (*enginev1.InfoResponse, error) { return nil, errors.New("엔진 없음") }

	err := precomputeJob(t.Context(), precomputeDeps{Pool: pool, Engine: fake, Clock: clocktest.New(now), Logger: slog.New(slog.DiscardHandler)})

	require.Error(t, err)
	assert.Zero(t, fake.DailyCalls.Load())
}

// job precompute는 설정을 읽는 단계부터 실행한다.
func TestRun_PrecomputeWithoutDatabaseURL_Exits1WithConfigError(t *testing.T) {
	code, stderr := runCLI(t, "job", "precompute")

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "DATABASE_URL")
	assert.NotContains(t, stderr, "not implemented")
}

// 엔진 주소가 없으면 job이 실패한다.
func TestRun_PrecomputeMissingEngineAddr_Exits1(t *testing.T) {
	code, _, stderr := runCLIWithEnv(t, map[string]string{"DATABASE_URL": dbtest.NewURL(t)}, "job", "precompute")

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "ENGINE_ADDR")
}
