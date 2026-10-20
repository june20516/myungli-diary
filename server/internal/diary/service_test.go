package diary_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// fakeDays는 호출 횟수를 세고 정해 둔 기록(또는 오류)을 돌려주는 Days 대역입니다.
type fakeDays struct {
	record fortune.DayRecord
	err    error
	calls  int
}

func (f *fakeDays) DayRecord(context.Context, uuid.UUID, profile.Profile, profile.LocalDate) (fortune.DayRecord, error) {
	f.calls++
	return f.record, f.err
}

func seoulProfile() profile.Profile {
	return profile.Profile{CurrentTimezone: "Asia/Seoul"}
}

// newService는 서울 2026-10-20 00:05(UTC 10-19 15:05)를 "지금"으로 하는 서비스를 만듭니다.
func newService(t *testing.T, days *fakeDays) (*diary.Service, *diary.Store, uuid.UUID) {
	t.Helper()
	store, acc, _ := setup(t)
	clk := clocktest.New(time.Date(2026, 10, 19, 15, 5, 0, 0, time.UTC))
	return diary.NewService(store, days, clk), store, acc
}

func TestService_PutFutureDateIsError(t *testing.T) {
	ctx := context.Background()
	svc, _, acc := newService(t, &fakeDays{})

	_, _, err := svc.Put(ctx, acc, seoulProfile(), day(20), "오늘")
	require.NoError(t, err, "서울 기준 오늘은 UTC로는 어제여도 씁니다")

	_, _, err = svc.Put(ctx, acc, seoulProfile(), day(21), "내일")
	assert.ErrorIs(t, err, diary.ErrFutureDate)
}

func TestService_PutFutureDateBoundaries(t *testing.T) {
	ctx := context.Background()
	tests := []struct {
		name         string
		now          time.Time // UTC
		ok, tomorrow profile.LocalDate
	}{
		{"서울 23:59", time.Date(2026, 10, 20, 14, 59, 0, 0, time.UTC), day(20), day(21)},
		{"연 경계", time.Date(2026, 12, 31, 14, 30, 0, 0, time.UTC), profile.LocalDate{Year: 2026, Month: 12, Day: 31}, profile.LocalDate{Year: 2027, Month: 1, Day: 1}},
		{"월 경계", time.Date(2026, 10, 31, 14, 30, 0, 0, time.UTC), day(31), profile.LocalDate{Year: 2026, Month: 11, Day: 1}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store, acc, _ := setup(t)
			svc := diary.NewService(store, &fakeDays{}, clocktest.New(tt.now))

			_, _, err := svc.Put(ctx, acc, seoulProfile(), tt.ok, "오늘")
			require.NoError(t, err)
			_, _, err = svc.Put(ctx, acc, seoulProfile(), tt.tomorrow, "내일")
			assert.ErrorIs(t, err, diary.ErrFutureDate)
		})
	}
}

func TestService_PutAfterDeleteRecordsDayAgain(t *testing.T) {
	ctx := context.Background()
	days := &fakeDays{record: fortune.DayRecord{AllTags: []string{"first"}, RulesetVersion: "r1"}}
	svc, _, acc := newService(t, days)

	_, _, err := svc.Put(ctx, acc, seoulProfile(), day(10), "처음")
	require.NoError(t, err)
	require.NoError(t, svc.Delete(ctx, acc, day(10)))

	days.record = fortune.DayRecord{AllTags: []string{"second"}, RulesetVersion: "r2"}
	got, created, err := svc.Put(ctx, acc, seoulProfile(), day(10), "다시")
	require.NoError(t, err)
	assert.True(t, created)
	assert.Equal(t, 2, days.calls)
	assert.Equal(t, []string{"second"}, got.AllTags)
	assert.Equal(t, "r2", got.RulesetVersion)
}

func TestService_PutNewRecordsDay(t *testing.T) {
	ctx := context.Background()
	days := &fakeDays{record: fortune.DayRecord{
		AllTags:        []string{"dohwa", "a"},
		Featured:       entry(10, "").Featured,
		RulesetVersion: "r1",
		GuideQuestion:  entry(10, "").GuideQuestion,
	}}
	svc, store, acc := newService(t, days)

	got, created, err := svc.Put(ctx, acc, seoulProfile(), day(10), "본문")
	require.NoError(t, err)
	assert.True(t, created)
	assert.Equal(t, 1, days.calls)

	saved, err := store.Get(ctx, acc, day(10))
	require.NoError(t, err)
	assert.Equal(t, got, saved)
	assert.Equal(t, "본문", saved.Body)
	assert.Equal(t, days.record.AllTags, saved.AllTags)
	assert.Equal(t, days.record.Featured, saved.Featured)
	assert.Equal(t, "r1", saved.RulesetVersion)
	assert.Equal(t, days.record.GuideQuestion, saved.GuideQuestion)
}

func TestService_PutExistingSkipsDays(t *testing.T) {
	ctx := context.Background()
	days := &fakeDays{record: fortune.DayRecord{AllTags: []string{"first"}, RulesetVersion: "r1"}}
	svc, _, acc := newService(t, days)

	_, _, err := svc.Put(ctx, acc, seoulProfile(), day(10), "처음")
	require.NoError(t, err)

	days.record = fortune.DayRecord{AllTags: []string{"second"}, RulesetVersion: "r2"}
	got, created, err := svc.Put(ctx, acc, seoulProfile(), day(10), "고침")
	require.NoError(t, err)
	assert.False(t, created)
	assert.Equal(t, 1, days.calls, "이미 있으면 Days를 부르지 않습니다")
	assert.Equal(t, "고침", got.Body)
	assert.Equal(t, []string{"first"}, got.AllTags)
	assert.Equal(t, "r1", got.RulesetVersion)
}

func TestService_PutPassesEngineErrors(t *testing.T) {
	ctx := context.Background()
	boom := errors.New("엔진 실패")
	svc, store, acc := newService(t, &fakeDays{err: boom})

	_, _, err := svc.Put(ctx, acc, seoulProfile(), day(10), "본문")
	assert.ErrorIs(t, err, boom)

	_, err = store.Get(ctx, acc, day(10))
	assert.ErrorIs(t, err, diary.ErrNotFound, "오류면 행이 없어야 합니다")
}
