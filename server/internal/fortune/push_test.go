package fortune_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

var pushDate = profile.LocalDate{Year: 2026, Month: 10, Day: 16}

// 알림 본문은 그날 총운 머리 문장에서 호칭 덩어리만 뺀 평문이고, 같은 선택 기록을 오늘 화면과 나눕니다(D62, S13).
func TestViews_PushBodyIsHeadWithoutHonorific(t *testing.T) {
	f := newViewsFixture(t, dailyFake(false), viewSeed(t, ""), fakeInsight{})
	ctx := context.Background()

	body, err := f.views.PushBody(ctx, f.account, viewProfile("ko"), pushDate)
	require.NoError(t, err)
	assert.Equal(t, "천천히 해 보세요.", body)

	view, err := f.views.Daily(ctx, f.account, viewProfile("ko"), pushDate)
	require.NoError(t, err)
	assert.Equal(t, "민지님, 천천히 해 보세요.", plain(view.Texts[fortune.SlotFortuneHead].Text))
}

func TestViews_PushBodyMissingHeadIsError(t *testing.T) {
	f := newViewsFixture(t, dailyFake(false), viewSeed(t, "", fortune.SlotFortuneHead), fakeInsight{})

	_, err := f.views.PushBody(context.Background(), f.account, viewProfile("ko"), pushDate)

	require.ErrorIs(t, err, fortune.ErrEmptyPushBody)
}
