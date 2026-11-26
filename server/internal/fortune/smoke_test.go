package fortune_test

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/seed"
)

// smokeTemplates는 총운 슬롯의 세 문장 유형을 모두 갖춘 ko 문장 틀입니다. 조합 확인은 순환 변주를 모두 렌더합니다.
func smokeTemplates() []seed.Template {
	return append(viewTemplates(""),
		tpl(fortune.SlotFortuneHead, "fortune.gwiin_day.inseong", content.VariantState, "ko", "{name}님, 마음이 차분한 날이에요."),
		tpl(fortune.SlotFortuneHead, "fortune.gwiin_day.inseong", content.VariantCare, "ko", "{name}님, 쉬어 가도 괜찮아요."),
	)
}

func smokeSeed(t *testing.T, templates []seed.Template) seed.Seed {
	t.Helper()
	s := seed.Seed{Slots: viewSlots, Templates: templates}
	require.NoError(t, s.Normalize())
	return s
}

// smokeFake는 데일리, 달력, 원국 응답을 모두 내는 엔진 대역입니다.
func smokeFake() *enginetest.Fake {
	return &enginetest.Fake{
		Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) { return dailyResponse(false), nil },
		MonthCalendar: func(*enginev1.MonthRequest) (*enginev1.MonthResponse, error) {
			return &enginev1.MonthResponse{
				Days: []*enginev1.MonthDay{{
					Kind:     enginev1.DayKind_DAY_KIND_GWIIN_DAY,
					Judgment: judgment("calendar.good", map[string]*enginev1.Param{"score": intParam(80)}),
				}},
				Meta: &enginev1.ResponseMeta{RulesetVersion: "rs-1"},
			}, nil
		},
		Chart: func(*enginev1.ChartRequest) (*enginev1.ChartResponse, error) {
			return &enginev1.ChartResponse{
				Yongsin: &enginev1.YongsinInfo{Judgment: judgment("yongsin.method.eokbu", nil)},
				Meta:    &enginev1.ResponseMeta{RulesetVersion: "rs-1"},
			}, nil
		},
	}
}

// runSmoke는 s를 적용한 DB와 fake로 ko 조합 확인을 돌립니다.
func runSmoke(t *testing.T, fake *enginetest.Fake, s seed.Seed) (fortune.SmokeReport, *pgxpool.Pool, error) {
	t.Helper()
	ctx := context.Background()
	pool := dbtest.New(t)
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	clk := clocktest.New(time.Date(2026, 10, 16, 0, 30, 0, 0, time.UTC))
	report, err := fortune.RunSmoke(ctx, fortune.SmokeConfig{
		Engine:    fake,
		Store:     content.NewStore(pool, clk, discardLogger()),
		Clock:     clk,
		Logger:    slog.New(slog.DiscardHandler),
		Languages: []string{"ko"},
	})
	return report, pool, err
}

func TestRunSmoke_PassesWhenEveryTextRenders(t *testing.T) {
	fake := smokeFake()

	report, _, err := runSmoke(t, fake, smokeSeed(t, smokeTemplates()))

	require.NoError(t, err)
	assert.Empty(t, report.Failures)
	assert.Positive(t, report.Checks)
	assert.Positive(t, fake.DailyCalls.Load(), "오늘 화면")
	assert.Positive(t, fake.MonthCalendarCalls.Load(), "달력")
	assert.Positive(t, fake.ChartCalls.Load(), "나의 사주")
}

// 원고가 없어 문장을 만들지 못한 슬롯은 실패로 보고합니다. 렌더 실패 로그의 칸(slot 등)을 함께 담습니다.
func TestRunSmoke_ReportsMissingTemplate(t *testing.T) {
	var templates []seed.Template
	for _, tp := range smokeTemplates() {
		if tp.Slot != fortune.SlotNumber {
			templates = append(templates, tp)
		}
	}

	report, _, err := runSmoke(t, smokeFake(), smokeSeed(t, templates))

	require.NoError(t, err)
	require.NotEmpty(t, report.Failures)
	assert.Contains(t, failureSlots(report), fortune.SlotNumber)
}

// 순환 변주(총운의 state, care)는 실제 사용자에게 날마다 돌아 나오므로 모두 렌더해 봅니다.
func TestRunSmoke_ReportsMissingRotationVariant(t *testing.T) {
	report, _, err := runSmoke(t, smokeFake(), smokeSeed(t, viewTemplates("")))

	require.NoError(t, err)
	var variants []string
	for _, f := range report.Failures {
		if f.Attrs["slot"] == fortune.SlotFortuneHead {
			variants = append(variants, f.Attrs["variant"])
		}
	}
	assert.Contains(t, variants, content.VariantState)
	assert.Contains(t, variants, content.VariantCare)
}

// 조합 확인은 계정, 선택 기록, 결과 캐시를 만들지 않습니다. 캐시를 거치지 않으므로 매번 엔진을 부릅니다.
func TestRunSmoke_WritesNothing(t *testing.T) {
	_, pool, err := runSmoke(t, smokeFake(), smokeSeed(t, smokeTemplates()))
	require.NoError(t, err)

	for _, table := range []string{"accounts", "daily_selections", "daily_cache", "chart_cache", "month_cache"} {
		var n int
		require.NoError(t, pool.QueryRow(context.Background(), "SELECT count(*) FROM "+table).Scan(&n))
		assert.Zero(t, n, table)
	}
}

// 엔진 호출이 실패하면 조합 확인 자체가 실패합니다(판 불일치로 엔진이 오류를 내는 경우).
func TestRunSmoke_EngineErrorFails(t *testing.T) {
	fake := smokeFake()
	fake.Daily = func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) { return nil, errors.New("engine down") }

	_, _, err := runSmoke(t, fake, smokeSeed(t, smokeTemplates()))

	require.Error(t, err)
}

func failureSlots(r fortune.SmokeReport) []string {
	slots := make([]string, 0, len(r.Failures))
	for _, f := range r.Failures {
		slots = append(slots, f.Attrs["slot"])
	}
	return slots
}
