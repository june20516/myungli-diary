package diary_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// fakeDays는 호출 횟수를 세고 정해 둔 기록(또는 오류)을 돌려주는 Days 대역입니다.
// guides는 (키, 변주) → 그날 후보 질문 문장이고, 없는 조합은 fortune.ErrGuideChoiceNotFound입니다.
type fakeDays struct {
	record fortune.DayRecord
	err    error
	calls  int
	guides map[diary.GuideChoice][]render.Segment
}

func (f *fakeDays) DayRecord(context.Context, uuid.UUID, profile.Profile, profile.LocalDate) (fortune.DayRecord, error) {
	f.calls++
	return f.record, f.err
}

func (f *fakeDays) GuideChoice(_ context.Context, _ uuid.UUID, _ profile.Profile, _ profile.LocalDate, messageKey, variant string) ([]render.Segment, error) {
	text, ok := f.guides[diary.GuideChoice{MessageKey: messageKey, Variant: variant}]
	if !ok {
		return nil, fortune.ErrGuideChoiceNotFound
	}
	return text, nil
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

func TestService_CreateRejectsFutureDate(t *testing.T) {
	ctx := context.Background()
	svc, _, acc := newService(t, &fakeDays{})

	_, err := svc.Create(ctx, acc, seoulProfile(), day(20), "오늘", diary.GuideRequest{})
	require.NoError(t, err, "서울 기준 오늘은 UTC로는 어제여도 씁니다")

	_, err = svc.Create(ctx, acc, seoulProfile(), day(21), "내일", diary.GuideRequest{})
	assert.ErrorIs(t, err, diary.ErrFutureDate)
}

func TestService_CreateFutureDateBoundaries(t *testing.T) {
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

			_, err := svc.Create(ctx, acc, seoulProfile(), tt.ok, "오늘", diary.GuideRequest{})
			require.NoError(t, err)
			_, err = svc.Create(ctx, acc, seoulProfile(), tt.tomorrow, "내일", diary.GuideRequest{})
			assert.ErrorIs(t, err, diary.ErrFutureDate)
		})
	}
}

func TestService_FirstEntryCallsEngineOnce(t *testing.T) {
	ctx := context.Background()
	days := &fakeDays{record: *record("dohwa", "a")}
	svc, store, acc := newService(t, days)

	got, err := svc.Create(ctx, acc, seoulProfile(), day(10), "본문", diary.GuideRequest{})
	require.NoError(t, err)
	assert.Equal(t, 1, days.calls)

	saved, err := store.Get(ctx, acc, got.ID)
	require.NoError(t, err)
	assert.Equal(t, got, saved)
	assert.Equal(t, "본문", saved.Body)
	assert.Equal(t, days.record.AllTags, saved.AllTags)
	assert.Equal(t, days.record.Featured, saved.Featured)
	assert.Equal(t, "r1", saved.RulesetVersion)
	assert.Equal(t, days.record.GuideQuestion, saved.GuideQuestion)
}

func TestService_SecondEntrySkipsEngine(t *testing.T) {
	ctx := context.Background()
	days := &fakeDays{record: fortune.DayRecord{AllTags: []string{"first"}, RulesetVersion: "r1"}}
	svc, _, acc := newService(t, days)

	_, err := svc.Create(ctx, acc, seoulProfile(), day(10), "첫째", diary.GuideRequest{})
	require.NoError(t, err)

	days.record = fortune.DayRecord{AllTags: []string{"second"}, RulesetVersion: "r2"}
	got, err := svc.Create(ctx, acc, seoulProfile(), day(10), "둘째", diary.GuideRequest{})
	require.NoError(t, err)
	assert.Equal(t, 1, days.calls, "날짜 기록이 있으면 Days를 부르지 않습니다")
	assert.Equal(t, []string{"first"}, got.AllTags)
	assert.Equal(t, "r1", got.RulesetVersion)
}

// 고른 오늘의 질문은 편마다 남고, 고르지 않은 편은 날짜 기록의 기본 질문입니다(S140). 목록과 조회도 같은 값입니다.
func TestService_GuideChoiceIsKeptPerEntry(t *testing.T) {
	ctx := context.Background()
	chosen := []render.Segment{{Text: "오늘 움직인 길을 적어 볼까요?"}}
	days := &fakeDays{
		record: *record("dohwa"),
		guides: map[diary.GuideChoice][]render.Segment{{MessageKey: "guide.yeokma", Variant: "1"}: chosen},
	}
	svc, store, acc := newService(t, days)

	first, err := svc.Create(ctx, acc, seoulProfile(), day(10), "첫째", diary.GuideRequest{Choice: &diary.GuideChoice{MessageKey: "guide.yeokma", Variant: "1"}})
	require.NoError(t, err)
	second, err := svc.Create(ctx, acc, seoulProfile(), day(10), "둘째", diary.GuideRequest{})
	require.NoError(t, err)

	assert.Equal(t, chosen, first.GuideQuestion, "고른 질문")
	assert.Equal(t, days.record.GuideQuestion, second.GuideQuestion, "고르지 않은 편은 기본 질문")

	saved, err := store.Get(ctx, acc, first.ID)
	require.NoError(t, err)
	assert.Equal(t, chosen, saved.GuideQuestion)
	list, err := store.List(ctx, acc, diary.ListQuery{Limit: 10})
	require.NoError(t, err)
	require.Len(t, list, 2)
	assert.Equal(t, chosen, list[0].GuideQuestion)
	assert.Equal(t, days.record.GuideQuestion, list[1].GuideQuestion)

	updated, err := store.UpdateBody(ctx, acc, first.ID, "고친 첫째")
	require.NoError(t, err)
	assert.Equal(t, chosen, updated.GuideQuestion, "본문을 고쳐도 고른 질문은 그대로")
}

// 그날 후보에 없는 질문을 고르면 엔진 기록도 일기도 만들지 않고 ErrGuideChoiceInvalid입니다.
func TestService_GuideChoiceNotCandidateIsRejected(t *testing.T) {
	ctx := context.Background()
	days := &fakeDays{record: *record("dohwa")}
	svc, store, acc := newService(t, days)

	_, err := svc.Create(ctx, acc, seoulProfile(), day(10), "본문", diary.GuideRequest{Choice: &diary.GuideChoice{MessageKey: "guide.unknown", Variant: "1"}})
	assert.ErrorIs(t, err, diary.ErrGuideChoiceInvalid)
	assert.Zero(t, days.calls)
	exists, err := store.DayExists(ctx, acc, day(10))
	require.NoError(t, err)
	assert.False(t, exists)
}

// 질문을 고르면서 떼면 엔진 기록도 일기도 만들지 않고 ErrGuideConflict입니다. (S149)
func TestService_GuideChoiceWithRemoveIsConflict(t *testing.T) {
	ctx := context.Background()
	days := &fakeDays{record: *record("dohwa")}
	svc, store, acc := newService(t, days)

	guide := diary.GuideRequest{Choice: &diary.GuideChoice{MessageKey: "guide.yeokma", Variant: "1"}, Without: true}
	_, err := svc.Create(ctx, acc, seoulProfile(), day(10), "본문", guide)
	assert.ErrorIs(t, err, diary.ErrGuideConflict)
	assert.Zero(t, days.calls)
	exists, err := store.DayExists(ctx, acc, day(10))
	require.NoError(t, err)
	assert.False(t, exists)
}

// 질문을 떼고 쓴 그날 첫 편도 날짜 기록(기본 질문 포함)은 남기고, 그 편에만 질문이 없습니다. (D116, S149)
func TestService_WithoutGuideKeepsDayRecord(t *testing.T) {
	ctx := context.Background()
	days := &fakeDays{record: *record("dohwa")}
	svc, _, acc := newService(t, days)

	removed, err := svc.Create(ctx, acc, seoulProfile(), day(10), "첫째", diary.GuideRequest{Without: true})
	require.NoError(t, err)
	assert.Empty(t, removed.GuideQuestion)
	assert.Equal(t, []string{"dohwa"}, removed.AllTags)

	second, err := svc.Create(ctx, acc, seoulProfile(), day(10), "둘째", diary.GuideRequest{})
	require.NoError(t, err)
	assert.Equal(t, record("dohwa").GuideQuestion, second.GuideQuestion)
}

func TestService_CreatePassesEngineErrors(t *testing.T) {
	ctx := context.Background()
	boom := errors.New("엔진 실패")
	svc, store, acc := newService(t, &fakeDays{err: boom})

	_, err := svc.Create(ctx, acc, seoulProfile(), day(10), "본문", diary.GuideRequest{})
	assert.ErrorIs(t, err, boom)

	exists, err := store.DayExists(ctx, acc, day(10))
	require.NoError(t, err)
	assert.False(t, exists, "오류면 날짜 기록도 없어야 합니다")
}

func TestService_DelegatesToStore(t *testing.T) {
	ctx := context.Background()
	svc, _, acc := newService(t, &fakeDays{record: *record("a")})
	e, err := svc.Create(ctx, acc, seoulProfile(), day(10), "처음", diary.GuideRequest{})
	require.NoError(t, err)

	updated, err := svc.UpdateBody(ctx, acc, e.ID, "고침")
	require.NoError(t, err)
	assert.Equal(t, "고침", updated.Body)
	got, err := svc.Get(ctx, acc, e.ID)
	require.NoError(t, err)
	assert.Equal(t, updated, got)

	require.NoError(t, svc.Delete(ctx, acc, e.ID))
	restored, err := svc.Restore(ctx, acc, e.ID)
	require.NoError(t, err)
	assert.Equal(t, e.ID, restored.ID)
	list, err := svc.List(ctx, acc, diary.ListQuery{Limit: 10})
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{e.ID}, ids(list))
}

// fakeEntries는 DayExists·CreateEntry 호출을 기록하고 정해 둔 응답을 돌려주는 entryStore 대역입니다.
type fakeEntries struct {
	exists    bool
	createErr func(call int, record *fortune.DayRecord) error // call은 1부터입니다.
	records   []*fortune.DayRecord                            // CreateEntry에 넘어온 record 기록
}

func (f *fakeEntries) DayExists(context.Context, uuid.UUID, profile.LocalDate) (bool, error) {
	return f.exists, nil
}

func (f *fakeEntries) CreateEntry(_ context.Context, _ uuid.UUID, date profile.LocalDate, body string, _ diary.Guide, rec *fortune.DayRecord) (diary.Entry, error) {
	f.records = append(f.records, rec)
	if err := f.createErr(len(f.records), rec); err != nil {
		return diary.Entry{}, err
	}
	return diary.Entry{ID: uuid.New(), Date: date, Body: body}, nil
}

func newServiceWithFakes(entries *fakeEntries, days *fakeDays) *diary.Service {
	clk := clocktest.New(time.Date(2026, 10, 19, 15, 5, 0, 0, time.UTC))
	return diary.NewServiceWith(entries, nil, days, clk)
}

func TestService_RetriesOnceWhenDayRecordVanishes(t *testing.T) {
	days := &fakeDays{record: fortune.DayRecord{RulesetVersion: "r1"}}
	entries := &fakeEntries{exists: true, createErr: func(call int, rec *fortune.DayRecord) error {
		if call == 1 {
			return diary.ErrDayRecordMissing
		}
		return nil
	}}
	svc := newServiceWithFakes(entries, days)

	_, err := svc.Create(context.Background(), uuid.New(), seoulProfile(), day(10), "본문", diary.GuideRequest{})
	require.NoError(t, err)
	assert.Equal(t, 1, days.calls)
	require.Len(t, entries.records, 2)
	assert.Nil(t, entries.records[0], "DayExists가 true면 처음엔 record 없이 부름")
	assert.NotNil(t, entries.records[1])
}

func TestService_RetryFailsTwiceReturnsError(t *testing.T) {
	days := &fakeDays{}
	entries := &fakeEntries{exists: true, createErr: func(int, *fortune.DayRecord) error { return diary.ErrDayRecordMissing }}
	svc := newServiceWithFakes(entries, days)

	_, err := svc.Create(context.Background(), uuid.New(), seoulProfile(), day(10), "본문", diary.GuideRequest{})
	assert.ErrorIs(t, err, diary.ErrDayRecordMissing)
	assert.Len(t, entries.records, 2, "한 번만 다시 부름")
	assert.Equal(t, 1, days.calls)
}

func TestService_DayFullIsNotRetried(t *testing.T) {
	entries := &fakeEntries{exists: true, createErr: func(int, *fortune.DayRecord) error { return diary.ErrDayFull }}
	svc := newServiceWithFakes(entries, &fakeDays{})

	_, err := svc.Create(context.Background(), uuid.New(), seoulProfile(), day(10), "본문", diary.GuideRequest{})
	assert.ErrorIs(t, err, diary.ErrDayFull)
	assert.Len(t, entries.records, 1)
}
