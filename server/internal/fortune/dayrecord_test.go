package fortune_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
)

// taggedFake는 대표 태그와 전체 태그를 채운 데일리 응답을 돌려주는 대역입니다.
func taggedFake(all, featured []string) *enginetest.Fake {
	return &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		r := dailyResponse(true)
		r.AllTags = all
		r.FeaturedTags = featured
		return r, nil
	}}
}

func TestViews_DayRecord(t *testing.T) {
	fx := newViewsFixture(t, taggedFake([]string{"tag.dohwa", "tag.yeokma"}, []string{"tag.dohwa"}),
		viewSeed(t, ""), fakeInsight{})

	got, err := fx.views.DayRecord(context.Background(), fx.account, viewProfile("ko"), viewDate)
	require.NoError(t, err)

	assert.Equal(t, []string{"dohwa", "yeokma"}, got.AllTags)
	assert.Equal(t, []fortune.FeaturedTag{{Key: "dohwa", Polarity: fortune.PolarityGood}}, got.Featured)
	assert.Equal(t, "rs-1", got.RulesetVersion)
	assert.Equal(t, "눈길이 간 사람을 적어 볼까요?", plain(got.GuideQuestion))
}

func TestViews_DayRecordNoTags(t *testing.T) {
	fx := newViewsFixture(t, taggedFake(nil, nil), viewSeed(t, ""), fakeInsight{})

	got, err := fx.views.DayRecord(context.Background(), fx.account, viewProfile("ko"), viewDate)
	require.NoError(t, err)

	assert.NotNil(t, got.AllTags)
	assert.Empty(t, got.AllTags)
	assert.NotNil(t, got.Featured)
	assert.Empty(t, got.Featured)
}

func TestViews_DayRecordWithoutGuideManuscript(t *testing.T) {
	fx := newViewsFixture(t, taggedFake(nil, nil), viewSeed(t, "", fortune.SlotGuide), fakeInsight{})

	got, err := fx.views.DayRecord(context.Background(), fx.account, viewProfile("ko"), viewDate)
	require.NoError(t, err)

	assert.Nil(t, got.GuideQuestion)
}

func TestViews_DayRecordUnknownFeaturedTagIsError(t *testing.T) {
	fx := newViewsFixture(t, taggedFake([]string{"tag.unknown"}, []string{"tag.unknown"}), viewSeed(t, ""), fakeInsight{})

	_, err := fx.views.DayRecord(context.Background(), fx.account, viewProfile("ko"), viewDate)
	assert.Error(t, err)
}

func TestViews_DayRecordUnknownAllTagIsError(t *testing.T) {
	fx := newViewsFixture(t, taggedFake([]string{"tag.dohwa", "tag.unknown"}, []string{"tag.dohwa"}), viewSeed(t, ""), fakeInsight{})

	_, err := fx.views.DayRecord(context.Background(), fx.account, viewProfile("ko"), viewDate)
	assert.Error(t, err)
}
