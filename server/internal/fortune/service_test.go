package fortune_test

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

func discardLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

func testBirth() profile.Birth {
	return profile.Birth{
		Calendar: profile.CalendarSolar, Date: profile.LocalDate{Year: 1990, Month: 5, Day: 17},
		TimeStatus: profile.TimeUnknown, Gender: "female", Timezone: "Asia/Seoul", PlaceStatus: profile.PlaceNotAsked,
	}
}

func rulesetMeta(ruleset string) *enginev1.ResponseMeta {
	return &enginev1.ResponseMeta{RulesetVersion: ruleset}
}

// newVersions는 Fake가 알려 주는 ruleset으로 Refresh까지 마친 Versions를 줍니다.
func newVersions(t *testing.T, fake *enginetest.Fake) *engine.Versions {
	t.Helper()
	versions := engine.NewVersions(fake, discardLogger())
	require.NoError(t, versions.Refresh(context.Background()))
	return versions
}

// failingCache는 읽기·쓰기가 모두 실패하는 ResultCache 대역입니다.
type failingCache struct{ fortune.ResultCache }

var errCacheDown = errors.New("cache down")

func (failingCache) GetChart(context.Context, fortune.ChartKey) ([]byte, bool, error) {
	return nil, false, errCacheDown
}
func (failingCache) PutChart(context.Context, fortune.ChartKey, []byte) error { return errCacheDown }
func (failingCache) GetDaily(context.Context, fortune.DailyKey) ([]byte, bool, error) {
	return nil, false, errCacheDown
}
func (failingCache) PutDaily(context.Context, fortune.DailyKey, []byte) error { return errCacheDown }
func (failingCache) GetMonth(context.Context, fortune.MonthKey) ([]byte, bool, error) {
	return nil, false, errCacheDown
}
func (failingCache) PutMonth(context.Context, fortune.MonthKey, []byte) error { return errCacheDown }

// garbageCache는 읽으면 깨진 bytes를 돌려주는 ResultCache 대역입니다.
type garbageCache struct{ failingCache }

func (garbageCache) GetDaily(context.Context, fortune.DailyKey) ([]byte, bool, error) {
	return []byte{0xff, 0xff, 0xff}, true, nil
}
func (garbageCache) PutDaily(context.Context, fortune.DailyKey, []byte) error { return nil }

func TestService_ChartMissCallsEngineThenCaches(t *testing.T) {
	fake := &enginetest.Fake{Chart: func(*enginev1.ChartRequest) (*enginev1.ChartResponse, error) {
		return &enginev1.ChartResponse{Meta: rulesetMeta("rs-1"), Gongmang: []enginev1.Branch{1, 2}}, nil
	}}
	service := fortune.NewService(fake, newVersions(t, fake), fortune.NewPostgresCache(dbtest.New(t)), discardLogger())
	asOf := profile.LocalDate{Year: 2026, Month: 10, Day: 15}

	first, err := service.Chart(context.Background(), testBirth(), asOf)
	require.NoError(t, err)
	second, err := service.Chart(context.Background(), testBirth(), asOf)
	require.NoError(t, err)

	assert.EqualValues(t, 1, fake.ChartCalls.Load())
	assert.True(t, proto.Equal(first, second))
}

func TestService_RulesetChangeMissesOldCache(t *testing.T) {
	ruleset := "rs-1"
	fake := &enginetest.Fake{
		Info: func() (*enginev1.InfoResponse, error) {
			return &enginev1.InfoResponse{EngineVersion: "test", RulesetVersion: ruleset}, nil
		},
		Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
			return &enginev1.DailyResponse{Meta: rulesetMeta(ruleset)}, nil
		},
	}
	versions := newVersions(t, fake)
	service := fortune.NewService(fake, versions, fortune.NewPostgresCache(dbtest.New(t)), discardLogger())
	date := profile.LocalDate{Year: 2026, Month: 10, Day: 15}

	_, err := service.Daily(context.Background(), testBirth(), date, "Asia/Seoul")
	require.NoError(t, err)
	_, err = service.Daily(context.Background(), testBirth(), date, "Asia/Seoul")
	require.NoError(t, err)
	require.EqualValues(t, 1, fake.DailyCalls.Load())

	ruleset = "rs-2"
	require.NoError(t, versions.Refresh(context.Background()))
	response, err := service.Daily(context.Background(), testBirth(), date, "Asia/Seoul")
	require.NoError(t, err)

	assert.EqualValues(t, 2, fake.DailyCalls.Load())
	assert.Equal(t, "rs-2", response.GetMeta().GetRulesetVersion())
}

func TestService_ConcurrentSameKeyCallsEngineOnce(t *testing.T) {
	fake := &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		time.Sleep(200 * time.Millisecond)
		return &enginev1.DailyResponse{Meta: rulesetMeta("rs-1")}, nil
	}}
	service := fortune.NewService(fake, newVersions(t, fake), fortune.NewPostgresCache(dbtest.New(t)), discardLogger())
	date := profile.LocalDate{Year: 2026, Month: 10, Day: 15}

	var wg sync.WaitGroup
	errs := make(chan error, 10)
	for range 10 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := service.Daily(context.Background(), testBirth(), date, "Asia/Seoul")
			errs <- err
		}()
	}
	wg.Wait()
	close(errs)

	for err := range errs {
		require.NoError(t, err)
	}
	assert.EqualValues(t, 1, fake.DailyCalls.Load())
}

func TestService_UnknownVersionIsUnavailable(t *testing.T) {
	fake := &enginetest.Fake{}
	versions := engine.NewVersions(fake, discardLogger()) // Refresh 전
	service := fortune.NewService(fake, versions, fortune.NewPostgresCache(dbtest.New(t)), discardLogger())

	_, err := service.Chart(context.Background(), testBirth(), profile.LocalDate{Year: 2026, Month: 1, Day: 1})

	require.Error(t, err)
	assert.ErrorIs(t, err, engine.ErrUnavailable)
	assert.EqualValues(t, 0, fake.ChartCalls.Load())
}

func TestService_CacheFailureFallsBackToEngine(t *testing.T) {
	fake := &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		return &enginev1.DailyResponse{Meta: rulesetMeta("rs-1")}, nil
	}}
	service := fortune.NewService(fake, newVersions(t, fake), failingCache{}, discardLogger())

	response, err := service.Daily(context.Background(), testBirth(), profile.LocalDate{Year: 2026, Month: 10, Day: 15}, "Asia/Seoul")

	require.NoError(t, err)
	assert.Equal(t, "rs-1", response.GetMeta().GetRulesetVersion())
	assert.EqualValues(t, 1, fake.DailyCalls.Load())
}

func TestService_CorruptCacheRowFallsBackToEngine(t *testing.T) {
	fake := &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		return &enginev1.DailyResponse{Meta: rulesetMeta("rs-1")}, nil
	}}
	service := fortune.NewService(fake, newVersions(t, fake), garbageCache{}, discardLogger())

	_, err := service.Daily(context.Background(), testBirth(), profile.LocalDate{Year: 2026, Month: 10, Day: 15}, "Asia/Seoul")

	require.NoError(t, err)
	assert.EqualValues(t, 1, fake.DailyCalls.Load())
}

func TestService_MissingResponseRulesetIsNotCached(t *testing.T) {
	fake := &enginetest.Fake{} // 빈 응답: meta 없음
	service := fortune.NewService(fake, newVersions(t, fake), fortune.NewPostgresCache(dbtest.New(t)), discardLogger())
	date := profile.LocalDate{Year: 2026, Month: 10, Day: 15}

	for range 2 {
		_, err := service.Daily(context.Background(), testBirth(), date, "Asia/Seoul")
		require.NoError(t, err)
	}

	assert.EqualValues(t, 2, fake.DailyCalls.Load())
}

func TestService_DailyKeyIncludesTimezone(t *testing.T) {
	fake := &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		return &enginev1.DailyResponse{Meta: rulesetMeta("rs-1")}, nil
	}}
	service := fortune.NewService(fake, newVersions(t, fake), fortune.NewPostgresCache(dbtest.New(t)), discardLogger())
	date := profile.LocalDate{Year: 2026, Month: 10, Day: 15}

	for _, timezone := range []string{"Asia/Seoul", "America/New_York"} {
		_, err := service.Daily(context.Background(), testBirth(), date, timezone)
		require.NoError(t, err)
	}

	assert.EqualValues(t, 2, fake.DailyCalls.Load())
}

func TestService_MonthMissCallsEngineThenCaches(t *testing.T) {
	fake := &enginetest.Fake{MonthCalendar: func(*enginev1.MonthRequest) (*enginev1.MonthResponse, error) {
		return &enginev1.MonthResponse{Meta: rulesetMeta("rs-1")}, nil
	}}
	service := fortune.NewService(fake, newVersions(t, fake), fortune.NewPostgresCache(dbtest.New(t)), discardLogger())

	for range 2 {
		_, err := service.Month(context.Background(), testBirth(), 2026, 10, "Asia/Seoul")
		require.NoError(t, err)
	}
	_, err := service.Month(context.Background(), testBirth(), 2026, 11, "Asia/Seoul")
	require.NoError(t, err)

	assert.EqualValues(t, 2, fake.MonthCalendarCalls.Load())
}

func TestService_EngineErrorIsReturned(t *testing.T) {
	fake := &enginetest.Fake{Chart: func(*enginev1.ChartRequest) (*enginev1.ChartResponse, error) {
		return nil, engine.ErrTimeout
	}}
	service := fortune.NewService(fake, newVersions(t, fake), failingCache{}, discardLogger())

	_, err := service.Chart(context.Background(), testBirth(), profile.LocalDate{Year: 2026, Month: 1, Day: 1})

	assert.ErrorIs(t, err, engine.ErrTimeout)
}

func TestService_CanceledCallerReturnsImmediately(t *testing.T) {
	release := make(chan struct{})
	fake := &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		<-release
		return &enginev1.DailyResponse{Meta: rulesetMeta("rs-1")}, nil
	}}
	service := fortune.NewService(fake, newVersions(t, fake), failingCache{}, discardLogger())
	ctx, cancel := context.WithCancel(context.Background())

	done := make(chan error, 1)
	go func() {
		_, err := service.Daily(ctx, testBirth(), profile.LocalDate{Year: 2026, Month: 10, Day: 15}, "Asia/Seoul")
		done <- err
	}()
	require.Eventually(t, func() bool { return fake.DailyCalls.Load() == 1 }, 2*time.Second, 5*time.Millisecond)
	cancel()

	select {
	case err := <-done:
		assert.ErrorIs(t, err, context.Canceled)
	case <-time.After(2 * time.Second):
		t.Fatal("호출자 ctx가 취소됐는데 엔진 응답을 기다리며 돌아오지 않았습니다")
	}
	close(release)
}

func TestService_InvalidBirthIsProgramError(t *testing.T) {
	fake := &enginetest.Fake{}
	service := fortune.NewService(fake, newVersions(t, fake), failingCache{}, discardLogger())
	birth := testBirth()
	birth.Gender = "other"

	_, err := service.Chart(context.Background(), birth, profile.LocalDate{Year: 2026, Month: 1, Day: 1})

	require.Error(t, err)
	assert.NotContains(t, err.Error(), "other")
	assert.EqualValues(t, 0, fake.ChartCalls.Load())
}

// blockingPutCache는 Get은 없음, Put은 ctx가 끝날 때까지 막히는 ResultCache 대역입니다(멈춘 DB).
type blockingPutCache struct{ failingCache }

func (blockingPutCache) GetDaily(context.Context, fortune.DailyKey) ([]byte, bool, error) {
	return nil, false, nil
}
func (blockingPutCache) PutDaily(ctx context.Context, _ fortune.DailyKey, _ []byte) error {
	<-ctx.Done()
	return ctx.Err()
}

func TestService_StalledCacheWriteDoesNotHoldCallers(t *testing.T) {
	fake := &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		return &enginev1.DailyResponse{Meta: rulesetMeta("rs-1")}, nil
	}}
	service := fortune.NewService(fake, newVersions(t, fake), blockingPutCache{}, discardLogger())
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	started := time.Now()
	response, err := service.Daily(ctx, testBirth(), profile.LocalDate{Year: 2026, Month: 10, Day: 15}, "Asia/Seoul")

	require.NoError(t, err)
	assert.Equal(t, "rs-1", response.GetMeta().GetRulesetVersion())
	assert.Less(t, time.Since(started), 3*time.Second, "캐시 쓰기 timeout(1초) 근처에서 끝나야 합니다")
}

func TestService_SharedFlightResultsAreSeparateObjects(t *testing.T) {
	fake := &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		time.Sleep(200 * time.Millisecond)
		return &enginev1.DailyResponse{Meta: rulesetMeta("rs-1")}, nil
	}}
	service := fortune.NewService(fake, newVersions(t, fake), failingCache{}, discardLogger())
	date := profile.LocalDate{Year: 2026, Month: 10, Day: 15}

	responses := make(chan *enginev1.DailyResponse, 2)
	for range 2 {
		go func() {
			response, err := service.Daily(context.Background(), testBirth(), date, "Asia/Seoul")
			assert.NoError(t, err)
			responses <- response
		}()
	}
	first, second := <-responses, <-responses

	require.EqualValues(t, 1, fake.DailyCalls.Load())
	assert.NotSame(t, first, second)
	assert.True(t, proto.Equal(first, second))
}
