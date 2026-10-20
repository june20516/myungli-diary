package fortune_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/seed"
)

// 오늘은 currentTimezone 기준입니다(고정 시각 2026-10-16 00:30 UTC).
func TestViews_PreviewDateIsTodayInCurrentTimezone(t *testing.T) {
	var got *enginev1.DailyRequest
	fake := &enginetest.Fake{Daily: func(req *enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		got = req
		return dailyResponse(true), nil
	}}
	f := newViewsFixture(t, fake, viewSeed(t, ""), fortune.AlwaysLocked{})
	ctx := context.Background()

	seoul, err := f.views.Preview(ctx, testBirth(), "Asia/Seoul", "ko")
	require.NoError(t, err)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 16}, seoul.Date)
	assert.EqualValues(t, 16, got.GetDate().GetDay())
	assert.Equal(t, "Asia/Seoul", got.GetCurrentTimezone())

	honolulu, err := f.views.Preview(ctx, testBirth(), "Pacific/Honolulu", "ko")
	require.NoError(t, err)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 10, Day: 15}, honolulu.Date)
	assert.EqualValues(t, 15, got.GetDate().GetDay())
}

// 총운은 advice 유형이고 호칭 덩어리가 빠지며, 선택 기록은 남지 않습니다(P6-5).
func TestViews_PreviewRendersAdviceWithoutHonorificAndRecordsNoSelection(t *testing.T) {
	f := newViewsFixture(t, dailyFake(true), viewSeed(t, ""), fortune.AlwaysLocked{})

	view, err := f.views.Preview(context.Background(), testBirth(), "Asia/Seoul", "ko")
	require.NoError(t, err)

	assert.Equal(t, content.VariantAdvice, view.Head.Variant)
	assert.Equal(t, "천천히 해 보세요.", plain(view.Head.Text), "호칭 덩어리 삭제")
	assert.Nil(t, view.Head.Evidence)
	require.NotNil(t, view.Tag)
	assert.Equal(t, content.VariantAdvice, view.Tag.Variant)
	assert.Equal(t, "사람을 만나 보세요.", plain(view.Tag.Text))

	var selections int
	require.NoError(t, f.pool.QueryRow(context.Background(), "SELECT count(*) FROM daily_selections").Scan(&selections))
	assert.Zero(t, selections, "선택 기록 없음")
	assert.Empty(t, f.logs.String())
}

func TestViews_PreviewWithoutTagLeavesTagNil(t *testing.T) {
	f := newViewsFixture(t, dailyFake(false), viewSeed(t, ""), fortune.AlwaysLocked{})

	view, err := f.views.Preview(context.Background(), testBirth(), "Asia/Seoul", "ko")
	require.NoError(t, err)
	assert.Nil(t, view.Tag)
}

func TestViews_PreviewDayKindNameFromGlossaryInRequestedLanguage(t *testing.T) {
	f := newViewsFixture(t, dailyFake(true), viewSeed(t, ""), fortune.AlwaysLocked{})
	ctx := context.Background()

	ko, err := f.views.Preview(ctx, testBirth(), "Asia/Seoul", "ko")
	require.NoError(t, err)
	assert.Equal(t, "귀인의 날", ko.DayKindName)

	en, err := f.views.Preview(ctx, testBirth(), "Asia/Seoul", "en")
	require.NoError(t, err)
	assert.Equal(t, "Day of Help", en.DayKindName)
	assert.Equal(t, "Take it slow.", plain(en.Head.Text))
}

// 이름이 없으면 enum 값으로 대신하지 않고 오류입니다(P6-6).
func TestViews_PreviewMissingDayKindNameIsError(t *testing.T) {
	f := newViewsFixture(t, dailyFake(true), viewSeed(t, ""), fortune.AlwaysLocked{})

	// 테스트 시드에 일본어 문장 틀이 없어 용어 사전이 비어 있습니다.
	_, err := f.views.Preview(context.Background(), testBirth(), "Asia/Seoul", "ja")
	assert.ErrorContains(t, err, "day_kind.gwiin_day")
}

func TestViews_PreviewRendersNotices(t *testing.T) {
	fake := dailyFake(true, enginev1.NoticeCode_NOTICE_CODE_TIME_UNKNOWN)
	f := newViewsFixture(t, fake, viewSeed(t, ""), fortune.AlwaysLocked{})

	view, err := f.views.Preview(context.Background(), testBirth(), "Asia/Seoul", "ko")
	require.NoError(t, err)
	require.Len(t, view.Notices, 1)
	assert.Equal(t, "time_unknown", view.Notices[0].Code)
	assert.Equal(t, "태어난 시간을 몰라 낮 12시로 계산했어요.", plain(view.Notices[0].Text))
}

func TestViews_PreviewNoActiveSeedIsErrNoActiveSeed(t *testing.T) {
	f := newViewsFixture(t, dailyFake(true), seed.Seed{}, fortune.AlwaysLocked{})

	_, err := f.views.Preview(context.Background(), testBirth(), "Asia/Seoul", "ko")
	assert.ErrorIs(t, err, content.ErrNoActiveSeed)
}

// 미리보기는 daily_cache를 읽지도 쓰지도 않습니다(birth_hash는 출생 정보를 되찾을 수 있는 값이라 D50 위반).
func TestViews_PreviewDoesNotTouchDailyCache(t *testing.T) {
	calls := 0
	fake := &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		calls++
		return dailyResponse(true), nil
	}}
	f := newViewsFixture(t, fake, viewSeed(t, ""), fortune.AlwaysLocked{})
	ctx := context.Background()

	for range 2 {
		_, err := f.views.Preview(ctx, testBirth(), "Asia/Seoul", "ko")
		require.NoError(t, err)
	}

	var cached int
	require.NoError(t, f.pool.QueryRow(ctx, "SELECT count(*) FROM daily_cache").Scan(&cached))
	assert.Zero(t, cached, "캐시에 행이 없음")
	assert.Equal(t, 2, calls, "캐시를 읽지 않아 매번 엔진 호출")
}
