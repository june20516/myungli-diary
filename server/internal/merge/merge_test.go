package merge_test

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
	"github.com/june20516/myungli-diary/server/internal/auth/secretbox"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/merge"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

var testNow = time.Date(2026, 10, 23, 9, 0, 0, 0, time.UTC)

const testNonce = "raw-nonce-0123456789"

// fixture는 합치기 서비스와 그것이 쓰는 DB·제공자 대역·인증 서비스를 묶습니다.
type fixture struct {
	ctx     context.Context
	pool    *pgxpool.Pool
	clk     *clocktest.Fake
	fake    *providertest.Server
	auth    *auth.Service
	service *merge.Service
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	clk := clocktest.New(testNow)
	fake := providertest.New(t)
	pool := dbtest.New(t)

	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)
	access, err := token.NewAccessIssuer(token.SigningKey{ID: "k1", Private: priv}, nil, clk)
	require.NoError(t, err)
	box, err := secretbox.New(secretbox.Key{ID: "b1", Bytes: bytes.Repeat([]byte{7}, 32)}, nil)
	require.NoError(t, err)

	authService := auth.NewService(pool, auth.ServiceDeps{
		Kakao:  fake.NewKakao(t, clk),
		Line:   fake.NewLINE(t, clk),
		Google: fake.NewGoogle(t, clk),
		Apple:  fake.NewApple(t, clk),
		Access: access,
		Box:    box,
		Clock:  clk,
	})
	profiles := profile.NewService(pool, nil, clk)
	return &fixture{
		ctx:     context.Background(),
		pool:    pool,
		clk:     clk,
		fake:    fake,
		auth:    authService,
		service: merge.NewService(pool, authService, profiles, clk, nil),
	}
}

func (f *fixture) kakaoProof(subject string) auth.LinkProof {
	return auth.LinkProof{IDToken: f.fake.SignIDToken(providertest.KakaoClaims(subject, testNonce, f.clk.Now())), RawNonce: testNonce}
}

func (f *fixture) lineProof(subject string) auth.LinkProof {
	return auth.LinkProof{IDToken: f.fake.SignES256IDToken(providertest.LINEClaims(subject, testNonce, f.clk.Now())), RawNonce: testNonce}
}

// loginKakao·loginLine은 그 인증 계정으로 로그인해 유저 계정을 만들고 id를 돌려줍니다.
func (f *fixture) loginKakao(t *testing.T, subject string) uuid.UUID {
	t.Helper()
	proof := f.kakaoProof(subject)
	res, err := f.auth.LoginKakao(f.ctx, proof.IDToken, proof.RawNonce)
	require.NoError(t, err)
	return res.AccountID
}

func (f *fixture) loginLine(t *testing.T, subject string) uuid.UUID {
	t.Helper()
	proof := f.lineProof(subject)
	res, err := f.auth.LoginLine(f.ctx, proof.IDToken, proof.RawNonce)
	require.NoError(t, err)
	return res.AccountID
}

func (f *fixture) exec(t *testing.T, sql string, args ...any) {
	t.Helper()
	_, err := f.pool.Exec(f.ctx, sql, args...)
	require.NoError(t, err, sql)
}

func (f *fixture) count(t *testing.T, sql string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, f.pool.QueryRow(f.ctx, sql, args...).Scan(&n))
	return n
}

// seedDay는 날짜 기록 하나를 넣습니다.
func (f *fixture) seedDay(t *testing.T, accountID uuid.UUID, date string) {
	t.Helper()
	f.exec(t, `INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version) VALUES ($1, $2, '{}', '[]', 'r1')`, accountID, date)
}

// seedDiary는 일기 한 편을 넣습니다. deleted면 지운 일기입니다.
func (f *fixture) seedDiary(t *testing.T, accountID uuid.UUID, date string, deleted bool) {
	t.Helper()
	var deletedAt *time.Time
	if deleted {
		deletedAt = &testNow
	}
	f.exec(t, `INSERT INTO diaries (id, account_id, date, body, deleted_at) VALUES ($1, $2, $3, '일기', $4)`,
		uuid.Must(uuid.NewV7()), accountID, date, deletedAt)
}

// seedSchedule은 일정 하나를 넣습니다.
func (f *fixture) seedSchedule(t *testing.T, accountID uuid.UUID, deleted bool) {
	t.Helper()
	var deletedAt *time.Time
	if deleted {
		deletedAt = &testNow
	}
	f.exec(t, `INSERT INTO schedules (id, account_id, date, all_day, title, deleted_at) VALUES ($1, $2, '2026-10-21', true, '회의', $3)`,
		uuid.Must(uuid.NewV7()), accountID, deletedAt)
}

// seedSelection은 문장 선택 기록 하나를 넣고 id를 돌려줍니다.
func (f *fixture) seedSelection(t *testing.T, accountID uuid.UUID, date string) int64 {
	t.Helper()
	f.exec(t, `INSERT INTO content_seeds (version, slots) VALUES ('seed-v1', '{}') ON CONFLICT DO NOTHING`)
	var id int64
	require.NoError(t, f.pool.QueryRow(f.ctx, `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, $2, 'overall', $3, 'msg.a', 'v1', 'seed-v1') RETURNING id`, accountID, date, bytes.Repeat([]byte{1}, 32)).Scan(&id))
	return id
}

// seedProfile은 호칭이 honorific인 프로필을 넣습니다.
func (f *fixture) seedProfile(t *testing.T, accountID uuid.UUID, honorific string) {
	t.Helper()
	f.exec(t, `INSERT INTO profiles (account_id, honorific, language, current_timezone, calendar, is_leap_month,
			birth_year, birth_month, birth_day, birth_time_status, birth_time, gender, birth_timezone, birth_place_status,
			notify_status, birth_hash)
		VALUES ($1, $2, 'ko', 'Asia/Seoul', 'lunar', true, 1990, 3, 14, 'known', '07:30', 'female', 'Asia/Seoul',
			'skipped', 'not_asked', $3)`, accountID, honorific, bytes.Repeat([]byte{2}, 32))
}

// seedPassGrant는 광고 제거권 구매 하나의 사용 구간(ad_free·insight)을 넣습니다.
func (f *fixture) seedPassGrant(t *testing.T, accountID uuid.UUID, purchaseID string, startsAt, expiresAt time.Time) {
	t.Helper()
	for _, entitlement := range []string{"ad_free", "insight"} {
		f.exec(t, `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
			VALUES ($1, $2, 'ad_free_pass', $3, $4, $5)`, accountID, entitlement, purchaseID, startsAt, expiresAt)
	}
}

func TestPreview_SameAccount(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")

	_, _, _, err := f.service.Preview(f.ctx, me, "kakao", f.kakaoProof("kakao-a"))

	require.ErrorIs(t, err, merge.ErrSameAccount)
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM account_merge_tickets`))
}

func TestPreview_NoAccount(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")

	_, _, _, err := f.service.Preview(f.ctx, me, "line", f.lineProof("U-free"))

	require.ErrorIs(t, err, merge.ErrNoAccount)
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM auth_identities WHERE provider = 'line'`), "연결로 넘어가지 않습니다")
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM account_merge_tickets`))
}

// 증명 오류는 연결과 같은 sentinel을 그대로 돌려줍니다.
func TestPreview_ProofErrorIsAuthSentinel(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")

	_, _, _, err := f.service.Preview(f.ctx, me, "line", auth.LinkProof{IDToken: "not-a-jwt", RawNonce: testNonce})

	require.ErrorIs(t, err, auth.ErrProviderTokenInvalid)
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM account_merge_tickets`))
}

func TestPreview_OtherAccount(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")

	// A: 날짜 기록 2026-10-12(B와 겹침), 일기 1, 프로필 없음
	f.seedDay(t, me, "2026-10-12")
	f.seedDiary(t, me, "2026-10-12", false)
	// B: 날짜 기록 2(하나는 A와 겹침), 일기 3(지운 것 1), 일정 2(지운 것 1), 반응 1(살아 있는 것만, 취소한 이력 1)
	f.seedDay(t, other, "2026-10-12")
	f.seedDay(t, other, "2026-10-14")
	f.seedDiary(t, other, "2026-10-12", false)
	f.seedDiary(t, other, "2026-10-14", false)
	f.seedDiary(t, other, "2026-10-14", true)
	f.seedSchedule(t, other, false)
	f.seedSchedule(t, other, true)
	selectionID := f.seedSelection(t, other, "2026-10-14")
	f.exec(t, `INSERT INTO reactions (selection_id, reaction, deleted_at) VALUES ($1, 'like', $2)`, selectionID, testNow.Add(-time.Hour))
	f.exec(t, `INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'like')`, selectionID)
	f.seedProfile(t, other, "벗")
	// B의 광고 제거권: 쓰는 구간 남은 5일 + 대기 구간 6일 23시간(올림해 합 12일), 끝난 구간·끊긴 구간·보상 구간은 세지 않음
	f.seedPassGrant(t, other, "p-active", testNow.AddDate(0, 0, -25), testNow.AddDate(0, 0, 5))
	f.seedPassGrant(t, other, "p-pending", testNow.AddDate(0, 0, 5), testNow.AddDate(0, 0, 12).Add(-time.Hour))
	f.seedPassGrant(t, other, "p-expired", testNow.AddDate(0, 0, -60), testNow.AddDate(0, 0, -30))
	f.seedPassGrant(t, other, "p-revoked", testNow.AddDate(0, 0, 12), testNow.AddDate(0, 0, 40))
	f.exec(t, `UPDATE entitlement_grants SET revoked_at = $1 WHERE source_ref = 'p-revoked'`, testNow)
	f.exec(t, `INSERT INTO entitlement_grants (account_id, entitlement, source, source_ref, starts_at, expires_at)
		VALUES ($1, 'insight', 'rewarded_ad', 'reward-1', $2, $3)`, other, testNow.Add(-time.Hour), testNow.Add(10*time.Hour))
	// A 쪽 구간은 B 남은 날에 섞이지 않습니다.
	f.seedPassGrant(t, me, "p-a", testNow, testNow.AddDate(0, 0, 30))

	raw, expiresAt, summary, err := f.service.Preview(f.ctx, me, "line", f.lineProof("U-b"))

	require.NoError(t, err)
	assert.Equal(t, merge.Summary{
		Diaries:     3,
		Schedules:   2,
		DateRecords: 1,
		Reactions:   1,
		OverlapDays: 1,
		AddedDays:   map[billing.Entitlement]int{billing.AdFree: 12, billing.Insight: 12},
		Current:     merge.ProfileSummary{},
		Other: merge.ProfileSummary{Saved: true, Honorific: "벗", Birth: profile.Birth{
			Calendar: profile.CalendarLunar, IsLeapMonth: true, Date: profile.LocalDate{Year: 1990, Month: 3, Day: 14},
			TimeStatus: profile.TimeKnown, Time: &profile.LocalTime{Hour: 7, Minute: 30}, Gender: "female",
			Timezone: "Asia/Seoul", PlaceStatus: profile.PlaceSkipped,
		}},
	}, summary)

	assert.Len(t, raw, 43)
	assert.Regexp(t, `^[A-Za-z0-9_-]{43}$`, raw)
	assert.True(t, expiresAt.Equal(testNow.Add(merge.MergeTicketTTL)), "expiresAt = %s", expiresAt)

	hash := sha256.Sum256([]byte(raw))
	var (
		gotAccount, gotOther, gotIdentity uuid.UUID
		gotExpires                        time.Time
		consumedAt                        *time.Time
	)
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT account_id, other_account_id, identity_id, expires_at, consumed_at
		FROM account_merge_tickets WHERE token_hash = $1`, hash[:]).Scan(&gotAccount, &gotOther, &gotIdentity, &gotExpires, &consumedAt))
	assert.Equal(t, me, gotAccount)
	assert.Equal(t, other, gotOther)
	var lineIdentity uuid.UUID
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT id FROM auth_identities WHERE provider = 'line' AND subject = 'U-b'`).Scan(&lineIdentity))
	assert.Equal(t, lineIdentity, gotIdentity)
	assert.True(t, gotExpires.Equal(expiresAt))
	assert.Nil(t, consumedAt)
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM account_merge_tickets WHERE token_hash = $1`, []byte(raw)), "원문은 저장하지 않습니다")
}

// 옮길 기록이 하나도 없어도 요약과 토큰을 줍니다.
func TestPreview_EmptyOtherStillSummarizes(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	f.seedProfile(t, me, "민지")
	f.loginLine(t, "U-b")

	raw, _, summary, err := f.service.Preview(f.ctx, me, "line", f.lineProof("U-b"))

	require.NoError(t, err)
	assert.Len(t, raw, 43)
	assert.Zero(t, summary.Diaries)
	assert.Zero(t, summary.Schedules)
	assert.Zero(t, summary.DateRecords)
	assert.Zero(t, summary.Reactions)
	assert.Zero(t, summary.OverlapDays)
	assert.Zero(t, summary.AddedDays[billing.AdFree])
	assert.True(t, summary.Current.Saved)
	assert.Equal(t, "민지", summary.Current.Honorific)
	assert.False(t, summary.Other.Saved)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM account_merge_tickets`))
}

// 요약을 다시 부르면 새 토큰을 하나 더 발급합니다. 앞 토큰은 쓰지 않으면 10분 뒤 만료됩니다.
func TestPreview_EachCallIssuesNewToken(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	f.loginLine(t, "U-b")

	first, _, _, err := f.service.Preview(f.ctx, me, "line", f.lineProof("U-b"))
	require.NoError(t, err)
	second, _, _, err := f.service.Preview(f.ctx, me, "line", f.lineProof("U-b"))
	require.NoError(t, err)

	assert.NotEqual(t, first, second)
	assert.Equal(t, 2, f.count(t, `SELECT count(*) FROM account_merge_tickets`))
}
