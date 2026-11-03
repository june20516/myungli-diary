package cli

import (
	"context"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/engine/enginetest"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/notify"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/seed"
)

// capturingSender는 받은 메시지를 기록하는 notify.Sender입니다.
type capturingSender struct {
	mu       sync.Mutex
	messages []notify.Message
}

func (s *capturingSender) Send(_ context.Context, m notify.Message) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.messages = append(s.messages, m)
	return nil
}

// notifyDaily는 내장 시드에 원고가 있는 키로 채운 데일리 응답 대역입니다.
func notifyDaily() *enginetest.Fake {
	j := func(key string) *enginev1.Judgment { return &enginev1.Judgment{MessageKey: key} }
	return &enginetest.Fake{Daily: func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
		return &enginev1.DailyResponse{
			Kind:      enginev1.DayKind_DAY_KIND_GWIIN_DAY,
			Fortune:   []*enginev1.Judgment{j("fortune.gwiin_day.inseong")},
			Guide:     j("guide.dohwa"),
			Color:     &enginev1.ColorCard{Judgment: j("color.gwiin_day")},
			Direction: &enginev1.DirectionCard{Judgment: j("direction.gwiin_day")},
			Number:    &enginev1.NumberCard{Judgment: j("number.gwiin_day")},
			FocusTime: &enginev1.FocusTimeCard{Judgment: j("focus_time.pick")},
			Meta:      &enginev1.ResponseMeta{RulesetVersion: "rs-1"},
		}, nil
	}}
}

// createNotifyTarget은 내장 시드를 적용하고, 호칭 "민지", 서울 07:00 알림, 활성 기기 1대인 계정을 만듭니다.
func createNotifyTarget(t *testing.T, pool *pgxpool.Pool, now time.Time) uuid.UUID {
	t.Helper()
	ctx := t.Context()
	embedded, err := seed.Load()
	require.NoError(t, err)
	_, err = content.Apply(ctx, pool, embedded)
	require.NoError(t, err)

	id := uuid.New()
	require.NoError(t, authdb.New(pool).CreateAccount(ctx, authdb.CreateAccountParams{ID: id, LastActiveAt: now}))
	_, err = profile.NewService(pool, noopCharts{}, clocktest.New(now)).Put(ctx, id, profile.Profile{
		Honorific:       "민지",
		Language:        "ko",
		CurrentTimezone: "Asia/Seoul",
		Birth: profile.Birth{
			Calendar: profile.CalendarSolar, Date: profile.LocalDate{Year: 1990, Month: 5, Day: 17},
			TimeStatus: profile.TimeUnknown, Gender: "female", Timezone: "Asia/Seoul", PlaceStatus: profile.PlaceSkipped,
		},
		Notification: profile.Notification{Status: profile.NotifyEnabled, Time: &profile.LocalTime{Hour: 7}},
	})
	require.NoError(t, err)
	_, err = pool.Exec(ctx, `INSERT INTO devices (id, account_id, fcm_token, token_hash, platform, active, last_seen_at)
		VALUES ($1, $2, 'device-1', sha256('device-1'), 'android', true, now())`, uuid.New(), id)
	require.NoError(t, err)
	return id
}

// 2026-11-04 07:05 KST
var notifyJobNow = time.Date(2026, 11, 3, 22, 5, 0, 0, time.UTC)

// 알림이 그날 총운 머리 문장을 호칭 없이 평문으로 보내고 기록을 sent로 남긴다.
func TestNotifyJob_SendsHeadWithoutHonorific(t *testing.T) {
	pool := dbtest.New(t)
	account := createNotifyTarget(t, pool, notifyJobNow)
	sender := &capturingSender{}

	err := notifyJob(t.Context(), notifyDeps{Pool: pool, Engine: notifyDaily(), Sender: sender, Clock: clocktest.New(notifyJobNow), Logger: slog.New(slog.DiscardHandler)})

	require.NoError(t, err)
	require.Len(t, sender.messages, 1)
	body := sender.messages[0].Body
	assert.NotEmpty(t, body)
	for _, leaked := range []string{"민지", "[[", "{"} {
		assert.False(t, strings.Contains(body, leaked), "본문 %q에 %q가 있습니다", body, leaked)
	}
	assert.Equal(t, "device-1", sender.messages[0].Token)
	assert.Equal(t, profile.LocalDate{Year: 2026, Month: 11, Day: 4}, sender.messages[0].Date)
	var result string
	require.NoError(t, pool.QueryRow(t.Context(), `SELECT result FROM notification_log WHERE account_id = $1 AND local_date = '2026-11-04'`, account).Scan(&result))
	assert.Equal(t, "sent", result)
}

// 같은 날 두 번째 실행은 보내지 않는다.
func TestNotifyJob_SecondRunSkips(t *testing.T) {
	pool := dbtest.New(t)
	createNotifyTarget(t, pool, notifyJobNow)
	sender := &capturingSender{}
	deps := notifyDeps{Pool: pool, Engine: notifyDaily(), Sender: sender, Clock: clocktest.New(notifyJobNow), Logger: slog.New(slog.DiscardHandler)}

	require.NoError(t, notifyJob(t.Context(), deps))
	require.NoError(t, notifyJob(t.Context(), deps))

	assert.Len(t, sender.messages, 1)
}

// 대상이 없으면 엔진을 부르지 않는다.
func TestNotifyJob_NoTargetsSkipsEngine(t *testing.T) {
	pool := dbtest.New(t)
	createNotifyTarget(t, pool, notifyJobNow)
	fake := notifyDaily()
	noon := time.Date(2026, 11, 4, 3, 0, 0, 0, time.UTC) // 서울 12:00

	require.NoError(t, notifyJob(t.Context(), notifyDeps{Pool: pool, Engine: fake, Sender: &capturingSender{}, Clock: clocktest.New(noon), Logger: slog.New(slog.DiscardHandler)}))

	assert.Zero(t, fake.InfoCalls.Load())
}

func TestRun_NotifyWithoutDatabaseURL_Exits1WithConfigError(t *testing.T) {
	code, stderr := runCLI(t, "job", "notify")

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "DATABASE_URL")
	assert.NotContains(t, stderr, "not implemented")
}

func TestRun_NotifyWithoutProjectID_Exits1(t *testing.T) {
	env := map[string]string{"DATABASE_URL": dbtest.NewURL(t), "ENGINE_ADDR": "127.0.0.1:1"}

	code, _, stderr := runCLIWithEnv(t, env, "job", "notify")

	assert.Equal(t, 1, code)
	assert.Contains(t, stderr, "GOOGLE_CLOUD_PROJECT")
}
