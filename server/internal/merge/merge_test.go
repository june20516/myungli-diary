package merge_test

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
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
	revoker *fakeRevoker
	// purchases는 결제 동기화가 읽는 RevenueCat 구매 목록 대역입니다. 비어 있으면 동기화가 아무것도 적지 않습니다.
	purchases *fakePurchaseSource
	service   *merge.Service
}

// fakePurchaseSource는 billing.PurchaseSource 대역입니다. 고객(계정 id)별 구매 목록 또는 오류를 돌려줍니다.
type fakePurchaseSource struct {
	mu        sync.Mutex
	purchases map[string][]billing.Purchase
	err       error
}

func (f *fakePurchaseSource) Purchases(_ context.Context, customerID string) ([]billing.Purchase, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return nil, f.err
	}
	return append([]billing.Purchase(nil), f.purchases[customerID]...), nil
}

func (f *fakePurchaseSource) add(accountID uuid.UUID, p billing.Purchase) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.purchases[accountID.String()] = append(f.purchases[accountID.String()], p)
}

func (f *fakePurchaseSource) fail(err error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.err = err
}

// fakeRevoker는 account.Revoker 대역입니다. 받은 허가 취소 대기 행 id를 호출마다 기록합니다.
type fakeRevoker struct {
	mu    sync.Mutex
	calls [][]int64
}

func (f *fakeRevoker) Attempt(_ context.Context, ids []int64) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, ids)
}

func (f *fakeRevoker) recorded() [][]int64 {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([][]int64(nil), f.calls...)
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
	revoker := &fakeRevoker{}
	purchases := &fakePurchaseSource{purchases: map[string][]billing.Purchase{}}
	syncer := billing.NewSyncer(pool, purchases, billing.SyncConfig{Catalog: billing.AdFreeCatalog([]string{"test.ad_free.month"})}, clk)
	return &fixture{
		ctx:       context.Background(),
		pool:      pool,
		clk:       clk,
		fake:      fake,
		auth:      authService,
		revoker:   revoker,
		purchases: purchases,
		service: merge.NewService(pool, merge.Deps{
			Proofs:    authService,
			Profiles:  profiles,
			Purchases: syncer,
			Revoker:   revoker,
			Clock:     clk,
		}),
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

func (f *fixture) googleProof(subject string) auth.LinkProof {
	claims := providertest.GoogleClaims(subject, testNonce, providertest.GoogleClientIDs[0], provider.GoogleIssuers[0], f.clk.Now())
	return auth.LinkProof{IDToken: f.fake.SignIDToken(claims), RawNonce: testNonce}
}

// Google 증명도 같은 두 갈래의 422입니다. A에 연결된 Google이면 같은 계정, 어디에도 없는 Google이면 연결 없음입니다.
func TestPreview_GoogleUnprocessable(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	_, err := f.auth.LinkIdentity(f.ctx, me, "google", f.googleProof("google-a"))
	require.NoError(t, err)

	_, _, _, err = f.service.Preview(f.ctx, me, "google", f.googleProof("google-a"))
	require.ErrorIs(t, err, merge.ErrSameAccount)

	_, _, _, err = f.service.Preview(f.ctx, me, "google", f.googleProof("google-free"))
	require.ErrorIs(t, err, merge.ErrNoAccount)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities WHERE provider = 'google'`), "연결로 넘어가지 않습니다")
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
		Diaries:     2, // 지운 일기는 옮기지만 세지 않습니다
		Schedules:   1,
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

// issueToken은 A(me)가 B의 LINE 증명으로 요약을 불러 합치기 토큰을 받습니다.
func (f *fixture) issueToken(t *testing.T, me uuid.UUID, lineSubject string) string {
	t.Helper()
	raw, _, _, err := f.service.Preview(f.ctx, me, "line", f.lineProof(lineSubject))
	require.NoError(t, err)
	return raw
}

// seedTaggedDay는 태그가 tag 하나인 날짜 기록을 넣습니다.
func (f *fixture) seedTaggedDay(t *testing.T, accountID uuid.UUID, date, tag string) {
	t.Helper()
	f.exec(t, `INSERT INTO diary_days (account_id, date, all_tags, featured_tags, guide_question, ruleset_version)
		VALUES ($1, $2, ARRAY[$3::text], '[]', jsonb_build_array(jsonb_build_object('text', $3::text)), 'r1')`, accountID, date, tag)
}

// seedSelectionWithReaction은 메시지 키가 messageKey인 문장 선택 기록과 살아 있는 반응 하나를 넣고 선택 id를 돌려줍니다.
// 출생 해시는 모든 계정이 같은 값이라 같은 (date, slot)이면 겹칩니다.
func (f *fixture) seedSelectionWithReaction(t *testing.T, accountID uuid.UUID, date, messageKey, reaction string) int64 {
	t.Helper()
	f.exec(t, `INSERT INTO content_seeds (version, slots) VALUES ('seed-v1', '{}') ON CONFLICT DO NOTHING`)
	var id int64
	require.NoError(t, f.pool.QueryRow(f.ctx, `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, $2, 'overall', $3, $4, 'v1', 'seed-v1') RETURNING id`, accountID, date, bytes.Repeat([]byte{1}, 32), messageKey).Scan(&id))
	f.exec(t, `INSERT INTO reactions (selection_id, reaction) VALUES ($1, $2)`, id, reaction)
	return id
}

func (f *fixture) accountStatus(t *testing.T, accountID uuid.UUID) string {
	t.Helper()
	var status string
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT status FROM accounts WHERE id = $1`, accountID).Scan(&status))
	return status
}

func TestExecute_MovesRecordsAndDeletesB(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	// B는 카카오도 붙여 둡니다. B를 지울 때 카카오 허가 취소 대기 행 하나가 생깁니다(LINE은 server가 취소하지 않음).
	_, err := f.auth.LinkIdentity(f.ctx, other, "kakao", f.kakaoProof("kakao-b"))
	require.NoError(t, err)

	f.seedDay(t, other, "2026-10-14")
	f.seedDiary(t, other, "2026-10-14", false)
	f.seedDiary(t, other, "2026-10-14", true)
	f.seedSchedule(t, other, false)
	f.seedSchedule(t, other, true)
	selectionID := f.seedSelectionWithReaction(t, other, "2026-10-14", "msg.b", "like")
	f.exec(t, `INSERT INTO rotation_state (account_id, message_key, next_variant) VALUES ($1, 'msg.b', 'v2')`, other)
	token := f.issueToken(t, me, "U-b")

	require.NoError(t, f.service.Execute(f.ctx, me, token, merge.ProfileCurrent))

	assert.Equal(t, 2, f.count(t, `SELECT count(*) FROM diaries WHERE account_id = $1`, me), "지운 일기도 옮깁니다")
	assert.Equal(t, 2, f.count(t, `SELECT count(*) FROM schedules WHERE account_id = $1`, me), "지운 일정도 옮깁니다")
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM diary_days WHERE account_id = $1 AND date = '2026-10-14'`, me))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM daily_selections WHERE id = $1 AND account_id = $2`, selectionID, me))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM reactions WHERE selection_id = $1 AND deleted_at IS NULL`, selectionID), "반응은 선택 기록을 따라갑니다")
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM reaction_tallies`), "옮긴 반응은 집계에 더하지 않습니다")
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM rotation_state WHERE account_id = $1`, me), "순환 상태는 A 것을 씁니다")

	assert.Equal(t, "deleted", f.accountStatus(t, other))
	assert.Equal(t, "active", f.accountStatus(t, me))
	for _, table := range []string{"auth_identities", "refresh_tokens", "diaries", "diary_days", "schedules", "daily_selections", "rotation_state", "consents"} {
		assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM `+table+` WHERE account_id = $1`, other), "%s에 B 행이 없습니다", table)
	}
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities WHERE account_id = $1`, me), "인증 계정은 옮기지 않습니다")
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM account_merge_tickets`), "B를 지우며 토큰도 지웁니다")

	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM provider_revocations WHERE provider = 'kakao' AND subject = 'kakao-b'`))
	calls := f.revoker.recorded()
	require.Len(t, calls, 1, "commit 뒤 허가 취소를 한 번 시도합니다")
	assert.Len(t, calls[0], 1)
}

// B의 알림 기기는 옮기지 않고 B와 함께 지웁니다(S119). 같은 단말은 app이 다음 실행 때 A로 다시 등록합니다.
func TestExecute_DeletesOtherDevices(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	seedDevice := func(accountID uuid.UUID, token string) {
		f.exec(t, `INSERT INTO devices (id, account_id, fcm_token, token_hash, platform, active, last_seen_at)
			VALUES ($1, $2, $3, sha256(convert_to($3, 'UTF8')), 'ios', true, now())`, uuid.Must(uuid.NewV7()), accountID, token)
	}
	seedDevice(me, "fcm-a")
	seedDevice(other, "fcm-b")
	token := f.issueToken(t, me, "U-b")

	require.NoError(t, f.service.Execute(f.ctx, me, token, merge.ProfileCurrent))

	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM devices WHERE account_id = $1`, other), "B의 기기는 지웁니다")
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM devices WHERE account_id = $1 AND fcm_token = 'fcm-a'`, me), "A의 기기는 그대로입니다")
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM devices WHERE fcm_token = 'fcm-b'`), "B의 기기를 A로 옮기지 않습니다")
}

// 같은 날짜의 날짜 기록과 같은 (date, slot, birth_hash)의 문장 선택 기록은 고른 프로필 쪽을 남깁니다(spec §6.3).
// 다른 쪽 일기는 모두 남긴 날짜 기록 아래로 옮기고, 다른 쪽 선택에 붙은 반응은 집계에 더한 뒤 지웁니다.
func TestExecute_OverlapKeepsChosenProfileSide(t *testing.T) {
	cases := []struct {
		name         string
		profile      merge.Profile
		keptTag      string
		keptMessage  string
		tallyMessage string
		tallyAction  string
	}{
		{name: "other", profile: merge.ProfileOther, keptTag: "tag.b", keptMessage: "msg.b", tallyMessage: "msg.a", tallyAction: "like"},
		{name: "current", profile: merge.ProfileCurrent, keptTag: "tag.a", keptMessage: "msg.a", tallyMessage: "msg.b", tallyAction: "dislike"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFixture(t)
			me := f.loginKakao(t, "kakao-a")
			other := f.loginLine(t, "U-b")
			f.seedProfile(t, me, "민지")
			f.seedProfile(t, other, "벗")
			f.seedTaggedDay(t, me, "2026-10-12", "tag.a")
			f.seedDiary(t, me, "2026-10-12", false)
			f.seedTaggedDay(t, other, "2026-10-12", "tag.b")
			f.seedDiary(t, other, "2026-10-12", false)
			f.seedDiary(t, other, "2026-10-12", true)
			mine := f.seedSelectionWithReaction(t, me, "2026-10-12", "msg.a", "like")
			theirs := f.seedSelectionWithReaction(t, other, "2026-10-12", "msg.b", "dislike")
			token := f.issueToken(t, me, "U-b")

			require.NoError(t, f.service.Execute(f.ctx, me, token, tc.profile))

			var tags []string
			var question string
			require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT all_tags, guide_question->0->>'text' FROM diary_days WHERE account_id = $1 AND date = '2026-10-12'`, me).
				Scan(&tags, &question))
			assert.Equal(t, []string{tc.keptTag}, tags)
			assert.Equal(t, tc.keptTag, question, "가이드 질문도 남긴 쪽 것입니다")
			assert.Equal(t, 3, f.count(t, `SELECT count(*) FROM diaries WHERE account_id = $1 AND date = '2026-10-12'`, me), "일기는 하나도 지우지 않습니다")

			assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM daily_selections WHERE account_id = $1 AND date = '2026-10-12'`, me))
			assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM daily_selections WHERE account_id = $1 AND message_key = $2`, me, tc.keptMessage))
			assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM reactions WHERE selection_id IN ($1, $2)`, mine, theirs), "남긴 선택의 반응만 남습니다")
			var tallied int
			require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT count FROM reaction_tallies WHERE message_key = $1 AND variant = 'v1' AND reaction = $2`,
				tc.tallyMessage, tc.tallyAction).Scan(&tallied))
			assert.Equal(t, 1, tallied, "지운 쪽 반응은 집계에 더합니다")
			assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM reaction_tallies`))
		})
	}
}

func TestExecute_ProfileOtherReplacesProfile(t *testing.T) {
	t.Run("other는 B 프로필로 A를 바꿉니다", func(t *testing.T) {
		f := newFixture(t)
		me := f.loginKakao(t, "kakao-a")
		other := f.loginLine(t, "U-b")
		f.seedProfile(t, me, "민지")
		f.seedProfile(t, other, "벗")
		f.exec(t, `UPDATE profiles SET birth_year = 1985, language = 'ja', birth_hash = $2 WHERE account_id = $1`, other, bytes.Repeat([]byte{3}, 32))

		require.NoError(t, f.service.Execute(f.ctx, me, f.issueToken(t, me, "U-b"), merge.ProfileOther))

		var honorific, language string
		var year int
		var hash []byte
		require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT honorific, birth_year, language, birth_hash FROM profiles WHERE account_id = $1`, me).
			Scan(&honorific, &year, &language, &hash))
		assert.Equal(t, "벗", honorific)
		assert.Equal(t, 1985, year)
		assert.Equal(t, "ja", language, "설정도 B 것입니다")
		assert.Equal(t, bytes.Repeat([]byte{3}, 32), hash)
	})
	t.Run("A에 프로필이 없어도 other면 B 프로필이 생깁니다", func(t *testing.T) {
		f := newFixture(t)
		me := f.loginKakao(t, "kakao-a")
		other := f.loginLine(t, "U-b")
		f.seedProfile(t, other, "벗")

		require.NoError(t, f.service.Execute(f.ctx, me, f.issueToken(t, me, "U-b"), merge.ProfileOther))

		assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM profiles WHERE account_id = $1 AND honorific = '벗'`, me))
	})
	t.Run("B에 프로필이 없으면 other는 A를 프로필 없음으로 둡니다", func(t *testing.T) {
		f := newFixture(t)
		me := f.loginKakao(t, "kakao-a")
		f.loginLine(t, "U-b")
		f.seedProfile(t, me, "민지")

		require.NoError(t, f.service.Execute(f.ctx, me, f.issueToken(t, me, "U-b"), merge.ProfileOther))

		assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM profiles WHERE account_id = $1`, me))
	})
	t.Run("current는 A 프로필을 그대로 둡니다", func(t *testing.T) {
		f := newFixture(t)
		me := f.loginKakao(t, "kakao-a")
		other := f.loginLine(t, "U-b")
		f.seedProfile(t, me, "민지")
		f.seedProfile(t, other, "벗")

		require.NoError(t, f.service.Execute(f.ctx, me, f.issueToken(t, me, "U-b"), merge.ProfileCurrent))

		assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM profiles WHERE account_id = $1 AND honorific = '민지'`, me))
	})
}

// seedPurchase는 구매 장부 행 하나를 넣습니다.
func (f *fixture) seedPurchase(t *testing.T, accountID uuid.UUID, purchaseID string, purchasedAt time.Time) {
	t.Helper()
	f.exec(t, `INSERT INTO purchases (id, account_id, original_account_id, product_id, store, purchased_at, production)
		VALUES ($1, $2, $2, 'test.ad_free.month', 'app_store', $3, true)`, purchaseID, accountID, purchasedAt)
}

// grantPeriod는 계정의 구매 ad_free 구간입니다.
func (f *fixture) grantPeriod(t *testing.T, accountID uuid.UUID, purchaseID string) (startsAt, expiresAt time.Time, revokedAt *time.Time) {
	t.Helper()
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT starts_at, expires_at, revoked_at FROM entitlement_grants
		WHERE account_id = $1 AND source_ref = $2 AND entitlement = 'ad_free'`, accountID, purchaseID).Scan(&startsAt, &expiresAt, &revokedAt))
	return startsAt, expiresAt, revokedAt
}

// D88 ① 예: 10/20에 합치면 A는 11/5 만료, B는 11/1 만료(12일 남음)라 A 끝이 11/17입니다.
func TestExecute_PurchasesAppendRemaining(t *testing.T) {
	f := newFixture(t)
	now := time.Date(2026, 10, 20, 0, 0, 0, 0, time.UTC)
	f.clk.Set(now)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	f.seedPurchase(t, me, "p-a", time.Date(2026, 10, 5, 0, 0, 0, 0, time.UTC))
	f.seedPassGrant(t, me, "p-a", time.Date(2026, 10, 5, 0, 0, 0, 0, time.UTC), time.Date(2026, 11, 5, 0, 0, 0, 0, time.UTC))
	f.seedPurchase(t, other, "p-b", time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC))
	f.seedPassGrant(t, other, "p-b", time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC))
	// 합치기 전에 끝난 B 구매는 A 구간을 받지 않습니다.
	f.seedPurchase(t, other, "p-b-old", time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC))
	f.seedPassGrant(t, other, "p-b-old", time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC))

	require.NoError(t, f.service.Execute(f.ctx, me, f.issueToken(t, me, "U-b"), merge.ProfileCurrent))

	// A의 구매 목록: 옮긴 구매는 A 구간으로 대기, 합치기 전에 끝난 B 구매는 구간 없이 expired입니다(owned가 아님).
	listed, err := billing.NewStore(f.pool, f.clk, billing.AdFreeCatalog([]string{"test.ad_free.month"})).Purchases(f.ctx, me)
	require.NoError(t, err)
	statusOf := map[time.Time]string{}
	for _, item := range listed {
		statusOf[item.PurchasedAt.UTC()] = item.Status
		if item.PurchasedAt.Equal(time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC)) {
			assert.Nil(t, item.Period, "끝난 B 구매는 A 구간이 없습니다")
		}
	}
	assert.Equal(t, map[time.Time]string{
		time.Date(2026, 10, 5, 0, 0, 0, 0, time.UTC): billing.PurchaseActive,
		time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC): billing.PurchasePending,
		time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC):  billing.PurchaseExpired,
	}, statusOf)

	startsAt, expiresAt, revokedAt := f.grantPeriod(t, me, "p-b")
	assert.True(t, startsAt.Equal(time.Date(2026, 11, 5, 0, 0, 0, 0, time.UTC)), "A 구간 시작 %s", startsAt.UTC())
	assert.True(t, expiresAt.Equal(time.Date(2026, 11, 17, 0, 0, 0, 0, time.UTC)), "A 구간 끝 %s", expiresAt.UTC())
	assert.Nil(t, revokedAt)
	_, cutAt, cutRevoked := f.grantPeriod(t, other, "p-b")
	assert.True(t, cutAt.Equal(now), "B 쪽 행은 지금에서 끊깁니다: %s", cutAt.UTC())
	assert.Nil(t, cutRevoked)

	var owner, original uuid.UUID
	var mergedAt *time.Time
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT account_id, original_account_id, merged_at FROM purchases WHERE id = 'p-b'`).
		Scan(&owner, &original, &mergedAt))
	assert.Equal(t, me, owner)
	assert.Equal(t, other, original)
	require.NotNil(t, mergedAt)
	assert.True(t, mergedAt.Equal(now))
}

// 토큰이 안 맞는 경우는 모두 ErrTokenInvalid이고 A·B 모두 바뀌지 않습니다(Review Focus 4).
func TestExecute_TokenInvalidCases(t *testing.T) {
	cases := []struct {
		name string
		// otherGone이면 prepare가 B를 지우거나 deleted로 바꾸므로 B의 상태·기록은 보지 않습니다.
		otherGone bool
		// prepare는 토큰을 받은 뒤 상황을 만들고, Execute를 부를 bearer 계정을 돌려줍니다.
		prepare func(t *testing.T, f *fixture, me, other uuid.UUID) uuid.UUID
	}{
		{name: "없는 토큰", prepare: func(_ *testing.T, _ *fixture, me, _ uuid.UUID) uuid.UUID { return me }},
		{name: "만료", prepare: func(_ *testing.T, f *fixture, me, _ uuid.UUID) uuid.UUID {
			f.clk.Advance(merge.MergeTicketTTL)
			return me
		}},
		{name: "다른 bearer", prepare: func(t *testing.T, f *fixture, _, _ uuid.UUID) uuid.UUID {
			return f.loginKakao(t, "kakao-c")
		}},
		{name: "B가 삭제됨", otherGone: true, prepare: func(t *testing.T, f *fixture, me, other uuid.UUID) uuid.UUID {
			// B를 지우면 B에 묶인 토큰 행도 지워집니다.
			tx, err := f.pool.Begin(f.ctx)
			require.NoError(t, err)
			_, err = account.DeleteAccountTx(f.ctx, tx, other, f.clk.Now())
			require.NoError(t, err)
			require.NoError(t, tx.Commit(f.ctx))
			return me
		}},
		{name: "B만 deleted 표시", otherGone: true, prepare: func(t *testing.T, f *fixture, me, other uuid.UUID) uuid.UUID {
			// 토큰 행이 남은 채 B가 deleted인 상태(방어)입니다.
			f.exec(t, `UPDATE accounts SET status = 'deleted', deleted_at = now() WHERE id = $1`, other)
			return me
		}},
		{name: "인증 계정이 B에서 떼짐", prepare: func(t *testing.T, f *fixture, me, other uuid.UUID) uuid.UUID {
			f.exec(t, `DELETE FROM auth_identities WHERE account_id = $1 AND provider = 'line'`, other)
			return me
		}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFixture(t)
			me := f.loginKakao(t, "kakao-a")
			other := f.loginLine(t, "U-b")
			// B는 카카오도 있어 LINE을 떼도 남습니다.
			_, err := f.auth.LinkIdentity(f.ctx, other, "kakao", f.kakaoProof("kakao-b"))
			require.NoError(t, err)
			// 단언이 비지 않도록 A·B 모두 기록·프로필·구매를 둡니다.
			f.seedProfile(t, me, "민지")
			f.seedPurchase(t, me, "p-a", testNow.AddDate(0, 0, -5))
			f.seedPassGrant(t, me, "p-a", testNow.AddDate(0, 0, -5), testNow.AddDate(0, 0, 25))
			f.seedProfile(t, other, "벗")
			f.seedDay(t, other, "2026-10-14")
			f.seedDiary(t, other, "2026-10-14", false)
			f.seedPurchase(t, other, "p-b", testNow.AddDate(0, 0, -1))
			f.seedPassGrant(t, other, "p-b", testNow.AddDate(0, 0, -1), testNow.AddDate(0, 0, 29))
			token := f.issueToken(t, me, "U-b")
			if tc.name == "없는 토큰" {
				token = "not-issued-token-0123456789012345678901234"
			}
			bearer := tc.prepare(t, f, me, other)

			err = f.service.Execute(f.ctx, bearer, token, merge.ProfileCurrent)

			require.ErrorIs(t, err, merge.ErrTokenInvalid)
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM account_merge_tickets WHERE consumed_at IS NOT NULL`), "토큰을 쓰지 않았습니다")
			assert.Equal(t, "active", f.accountStatus(t, me))
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM diaries WHERE account_id = $1`, me), "A 기록은 그대로입니다")
			assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM profiles WHERE account_id = $1 AND honorific = '민지'`, me), "A 프로필은 그대로입니다")
			startsAt, expiresAt, revokedAt := f.grantPeriod(t, me, "p-a")
			assert.True(t, startsAt.Equal(testNow.AddDate(0, 0, -5)) && expiresAt.Equal(testNow.AddDate(0, 0, 25)) && revokedAt == nil,
				"A 구매 구간은 그대로입니다: %s~%s", startsAt.UTC(), expiresAt.UTC())
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM entitlement_grants WHERE account_id = $1 AND source_ref = 'p-b'`, me))
			assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM purchases WHERE account_id = $1 AND id = 'p-b'`, me))
			if !tc.otherGone {
				assert.Equal(t, "active", f.accountStatus(t, other))
				assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM diaries WHERE account_id = $1`, other), "B 일기는 그대로입니다")
				_, bExpires, bRevoked := f.grantPeriod(t, other, "p-b")
				assert.True(t, bExpires.Equal(testNow.AddDate(0, 0, 29)) && bRevoked == nil, "B 구간은 끊기지 않았습니다")
			}
			assert.Empty(t, f.revoker.recorded())
		})
	}

	// 합친 뒤 같은 토큰의 재사용은 영수증 규칙을 따릅니다(TestExecute_ResendAfterMerge, TestExecute_ResendAfterReceiptTTLIsInvalid).
	t.Run("쓴 토큰(consumed_at)", func(t *testing.T) {
		f := newFixture(t)
		me := f.loginKakao(t, "kakao-a")
		other := f.loginLine(t, "U-b")
		token := f.issueToken(t, me, "U-b")
		f.exec(t, `UPDATE account_merge_tickets SET consumed_at = now()`)

		require.ErrorIs(t, f.service.Execute(f.ctx, me, token, merge.ProfileCurrent), merge.ErrTokenInvalid)
		assert.Equal(t, "active", f.accountStatus(t, other))
	})
}

// A→B와 B→A를 동시에 실행하면 잠금 순서 때문에 하나만 성공하고, 다른 쪽은 상대가 deleted라 ErrTokenInvalid입니다(spec §6.3).
// 두 실행이 모두 잠금을 기다리는 것을 확인한 뒤 풀어 결정적으로 겹치게 하고, deadlock이면 마감으로 실패합니다.
func TestExecute_MutualMergeOnlyOneWins(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	tokenAB := f.issueToken(t, me, "U-b")
	tokenBA, _, _, err := f.service.Preview(f.ctx, other, "kakao", f.kakaoProof("kakao-a"))
	require.NoError(t, err)

	// 두 계정 행을 잡아 두 실행을 잠금 앞에 세웁니다.
	blocker, err := f.pool.Begin(f.ctx)
	require.NoError(t, err)
	t.Cleanup(func() { _ = blocker.Rollback(context.Background()) })
	_, err = blocker.Exec(f.ctx, `SELECT id FROM accounts WHERE id = ANY($1) ORDER BY id FOR UPDATE`, []uuid.UUID{me, other})
	require.NoError(t, err)

	ctx, cancel := context.WithTimeout(f.ctx, 15*time.Second)
	defer cancel()
	results := make(chan error, 2)
	go func() { results <- f.service.Execute(ctx, me, tokenAB, merge.ProfileCurrent) }()
	go func() { results <- f.service.Execute(ctx, other, tokenBA, merge.ProfileCurrent) }()

	require.Eventually(t, func() bool {
		return f.count(t, `SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock'`) == 2
	}, 10*time.Second, 20*time.Millisecond, "두 실행이 모두 잠금을 기다립니다")
	require.NoError(t, blocker.Rollback(f.ctx))

	var succeeded, invalid int
	for range 2 {
		err := <-results
		switch {
		case err == nil:
			succeeded++
		case errors.Is(err, merge.ErrTokenInvalid):
			invalid++
		default:
			t.Fatalf("예상하지 못한 오류: %v", err)
		}
	}
	assert.Equal(t, 1, succeeded)
	assert.Equal(t, 1, invalid)
	statuses := []string{f.accountStatus(t, me), f.accountStatus(t, other)}
	assert.ElementsMatch(t, []string{"active", "deleted"}, statuses)
}

// 하루 10편 상한은 합치기에서 검사하지 않습니다(D83 ④).
func TestExecute_DiaryCapIgnored(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	f.seedDay(t, me, "2026-10-12")
	f.seedDay(t, other, "2026-10-12")
	for range 6 {
		f.seedDiary(t, me, "2026-10-12", false)
		f.seedDiary(t, other, "2026-10-12", false)
	}

	require.NoError(t, f.service.Execute(f.ctx, me, f.issueToken(t, me, "U-b"), merge.ProfileCurrent))

	assert.Equal(t, 12, f.count(t, `SELECT count(*) FROM diaries WHERE account_id = $1 AND date = '2026-10-12' AND deleted_at IS NULL`, me))
}

// 합치기로 옮긴 일기·일정은 수정 시각(updated_at)을 바꾸지 않고, 그 뒤 보통 수정은 여전히 수정 시각을 바꿉니다(migration 00017).
func TestExecute_KeepsUpdatedAtOfMovedRecords(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	editedAt := time.Date(2026, 9, 1, 12, 0, 0, 0, time.UTC)
	diaryID, scheduleID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	f.seedDay(t, other, "2026-09-01")
	f.exec(t, `INSERT INTO diaries (id, account_id, date, body, created_at, updated_at) VALUES ($1, $2, '2026-09-01', '일기', $3, $3)`, diaryID, other, editedAt)
	f.exec(t, `INSERT INTO schedules (id, account_id, date, all_day, title, created_at, updated_at) VALUES ($1, $2, '2026-09-01', true, '회의', $3, $3)`,
		scheduleID, other, editedAt)

	require.NoError(t, f.service.Execute(f.ctx, me, f.issueToken(t, me, "U-b"), merge.ProfileCurrent))

	updatedAt := func(table string, id uuid.UUID) time.Time {
		t.Helper()
		var at time.Time
		require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT updated_at FROM `+table+` WHERE id = $1 AND account_id = $2`, id, me).Scan(&at))
		return at
	}
	assert.True(t, updatedAt("diaries", diaryID).Equal(editedAt), "옮긴 일기 수정 시각 %s", updatedAt("diaries", diaryID).UTC())
	assert.True(t, updatedAt("schedules", scheduleID).Equal(editedAt), "옮긴 일정 수정 시각 %s", updatedAt("schedules", scheduleID).UTC())

	f.exec(t, `UPDATE diaries SET body = '고친 일기' WHERE id = $1`, diaryID)
	f.exec(t, `UPDATE schedules SET title = '고친 회의' WHERE id = $1`, scheduleID)
	assert.True(t, updatedAt("diaries", diaryID).After(editedAt), "보통 수정은 수정 시각을 바꿉니다")
	assert.True(t, updatedAt("schedules", scheduleID).After(editedAt), "보통 수정은 수정 시각을 바꿉니다")
}

// 합치기 전에 B를 결제 동기화하므로, 장부에 아직 적지 않은 B 구매도 A로 옮겨지고 A 구간이 생깁니다(spec §6.3).
func TestExecute_SyncsOtherPurchasesFirst(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	boughtAt := testNow.AddDate(0, 0, -1)
	f.purchases.add(other, billing.Purchase{ID: "p-unsynced", ProductID: "test.ad_free.month", Store: "app_store", PurchasedAt: boughtAt, Production: true})
	token := f.issueToken(t, me, "U-b")

	require.NoError(t, f.service.Execute(f.ctx, me, token, merge.ProfileCurrent))

	var owner, original uuid.UUID
	require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT account_id, original_account_id FROM purchases WHERE id = 'p-unsynced'`).Scan(&owner, &original))
	assert.Equal(t, me, owner)
	assert.Equal(t, other, original)
	startsAt, expiresAt, revokedAt := f.grantPeriod(t, me, "p-unsynced")
	assert.True(t, startsAt.Equal(testNow), "A 구간은 지금부터: %s", startsAt.UTC())
	assert.True(t, expiresAt.Equal(boughtAt.AddDate(0, 1, 0)), "남은 길이만큼: %s", expiresAt.UTC())
	assert.Nil(t, revokedAt)
}

// 합치기 전 결제 동기화가 실패해도 합치기는 진행합니다(장부에 있는 것만 옮김).
func TestExecute_SyncFailureStillMerges(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	f.purchases.fail(billing.ErrProviderUnavailable)
	token := f.issueToken(t, me, "U-b")

	require.NoError(t, f.service.Execute(f.ctx, me, token, merge.ProfileCurrent))

	assert.Equal(t, "deleted", f.accountStatus(t, other))
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM purchases`))
}

// 그날 성격도 날짜 기록 값이라 겹친 날은 고른 프로필 쪽, B에만 있는 날은 B 값을 남깁니다(D90 ①, S116).
func TestExecute_DayKindFollowsDayRecord(t *testing.T) {
	cases := []struct {
		name       string
		profile    merge.Profile
		overlapped string
	}{
		{name: "other", profile: merge.ProfileOther, overlapped: "yongsin_day"},
		{name: "current", profile: merge.ProfileCurrent, overlapped: "gwiin_day"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFixture(t)
			me := f.loginKakao(t, "kakao-a")
			other := f.loginLine(t, "U-b")
			f.seedTaggedDay(t, me, "2026-10-12", "tag.a")
			f.seedTaggedDay(t, other, "2026-10-12", "tag.b")
			f.seedTaggedDay(t, other, "2026-10-13", "tag.b")
			f.exec(t, `UPDATE diary_days SET day_kind = 'gwiin_day' WHERE account_id = $1`, me)
			f.exec(t, `UPDATE diary_days SET day_kind = CASE date WHEN '2026-10-12' THEN 'yongsin_day' ELSE 'gisin_day' END WHERE account_id = $1`, other)
			token := f.issueToken(t, me, "U-b")

			require.NoError(t, f.service.Execute(f.ctx, me, token, tc.profile))

			kindOf := func(date string) string {
				var kind string
				require.NoError(t, f.pool.QueryRow(f.ctx, `SELECT day_kind FROM diary_days WHERE account_id = $1 AND date = $2`, me, date).Scan(&kind))
				return kind
			}
			assert.Equal(t, tc.overlapped, kindOf("2026-10-12"))
			assert.Equal(t, "gisin_day", kindOf("2026-10-13"), "B에만 있던 날은 B 값을 옮깁니다")
		})
	}
}

// 합치기가 끝난 토큰을 같은 A가 다시 보내면 다시 합치지 않고 성공입니다(#552, S115).
func TestExecute_ResendAfterMerge(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	f.seedDay(t, other, "2026-10-14")
	f.seedDiary(t, other, "2026-10-14", false)
	token := f.issueToken(t, me, "U-b")
	require.NoError(t, f.service.Execute(f.ctx, me, token, merge.ProfileCurrent))

	f.clk.Advance(merge.ReceiptTTL - time.Second)
	require.NoError(t, f.service.Execute(f.ctx, me, token, merge.ProfileOther), "고른 프로필이 달라도 이미 합친 결과를 그대로 둡니다")

	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM diaries WHERE account_id = $1`, me))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM account_merge_receipts WHERE account_id = $1`, me))
}

// 영수증은 합친 A에게만 유효합니다. 다른 계정이 같은 토큰을 보내면 422입니다.
func TestExecute_ResendFromOtherAccountIsInvalid(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	f.loginLine(t, "U-b")
	token := f.issueToken(t, me, "U-b")
	require.NoError(t, f.service.Execute(f.ctx, me, token, merge.ProfileCurrent))

	stranger := f.loginKakao(t, "kakao-c")
	assert.ErrorIs(t, f.service.Execute(f.ctx, stranger, token, merge.ProfileCurrent), merge.ErrTokenInvalid)
}

// 영수증 유효 시간(24시간)이 지나면 같은 A라도 422입니다.
func TestExecute_ResendAfterReceiptTTLIsInvalid(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	f.loginLine(t, "U-b")
	token := f.issueToken(t, me, "U-b")
	require.NoError(t, f.service.Execute(f.ctx, me, token, merge.ProfileCurrent))

	f.clk.Advance(merge.ReceiptTTL)
	assert.ErrorIs(t, f.service.Execute(f.ctx, me, token, merge.ProfileCurrent), merge.ErrTokenInvalid)
}

// 같은 토큰의 두 요청이 동시에 오면 하나가 합치고 다른 하나는 영수증을 보고 성공합니다.
func TestExecute_ConcurrentSameTokenBothSucceed(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-a")
	other := f.loginLine(t, "U-b")
	f.seedDay(t, other, "2026-10-14")
	f.seedDiary(t, other, "2026-10-14", false)
	token := f.issueToken(t, me, "U-b")

	// 두 계정 행을 잡아 두 실행을 잠금 앞에 세웁니다.
	blocker, err := f.pool.Begin(f.ctx)
	require.NoError(t, err)
	t.Cleanup(func() { _ = blocker.Rollback(context.Background()) })
	_, err = blocker.Exec(f.ctx, `SELECT id FROM accounts WHERE id = ANY($1) ORDER BY id FOR UPDATE`, []uuid.UUID{me, other})
	require.NoError(t, err)

	ctx, cancel := context.WithTimeout(f.ctx, 15*time.Second)
	defer cancel()
	results := make(chan error, 2)
	for range 2 {
		go func() { results <- f.service.Execute(ctx, me, token, merge.ProfileCurrent) }()
	}
	require.Eventually(t, func() bool {
		return f.count(t, `SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock'`) >= 2
	}, 10*time.Second, 20*time.Millisecond, "두 실행이 모두 잠금을 기다립니다")
	require.NoError(t, blocker.Rollback(f.ctx))

	for range 2 {
		assert.NoError(t, <-results)
	}
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM diaries WHERE account_id = $1`, me))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM account_merge_receipts`))
}
