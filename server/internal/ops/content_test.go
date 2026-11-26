package ops

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

var viewDate = profile.LocalDate{Year: 2026, Month: 11, Day: 20}

func insertDiaryDay(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID, date string, tags ...string) {
	t.Helper()
	_, err := pool.Exec(context.Background(), `INSERT INTO diary_days (account_id, date, all_tags, featured_tags, ruleset_version)
		VALUES ($1, $2, $3, '[]'::jsonb, 'v1')`, accountID, date, tags)
	require.NoError(t, err)
}

// insertDiary는 일기를 넣습니다. state는 "live", "deleted", "purged"입니다.
func insertDiary(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID, date, body, state string, createdAt time.Time) uuid.UUID {
	t.Helper()
	id := uuid.New()
	var deletedAt, purgedAt *time.Time
	switch state {
	case "deleted":
		deletedAt = &createdAt
	case "purged":
		deletedAt, purgedAt = &createdAt, &createdAt
	}
	_, err := pool.Exec(context.Background(), `INSERT INTO diaries (id, account_id, date, body, created_at, updated_at, deleted_at, content_purged_at)
		VALUES ($1, $2, $3, $4, $5, $5, $6, $7)`, id, accountID, date, body, createdAt, deletedAt, purgedAt)
	require.NoError(t, err)
	return id
}

func insertSchedule(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID, date, title string, memo *string, at *string, deleted bool) uuid.UUID {
	t.Helper()
	id := uuid.New()
	var deletedAt *time.Time
	if deleted {
		deletedAt = &testNow
	}
	_, err := pool.Exec(context.Background(), `INSERT INTO schedules (id, account_id, date, all_day, time, title, memo, deleted_at)
		VALUES ($1, $2, $3, $4::time IS NULL, $4::time, $5, $6, $7)`, id, accountID, date, at, title, memo, deletedAt)
	require.NoError(t, err)
	return id
}

func insertProfile(t *testing.T, pool *pgxpool.Pool, accountID uuid.UUID) {
	t.Helper()
	_, err := pool.Exec(context.Background(), `INSERT INTO profiles (account_id, honorific, language, current_timezone, calendar, is_leap_month,
		birth_year, birth_month, birth_day, birth_time_status, birth_time, gender, birth_timezone, birth_place_status, birth_city_id, longitude, notify_status, birth_hash)
		VALUES ($1, '비밀호칭', 'ko', 'Asia/Seoul', 'solar', false, 1990, 5, 17, 'known', '07:30', 'female', 'Asia/Seoul', 'city', 'seoul', 126.978, 'not_asked', decode(repeat('ab', 32), 'hex'))`, accountID)
	require.NoError(t, err)
}

type viewAuditRow struct {
	Action, Reason, Target string
	Purpose                *string
	AccountID              *uuid.UUID
}

func viewAuditRows(t *testing.T, pool *pgxpool.Pool) []viewAuditRow {
	t.Helper()
	rows, err := pool.Query(context.Background(), `SELECT action, reason, target::text, purpose, account_id FROM ops_audit ORDER BY at, id`)
	require.NoError(t, err)
	got, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (viewAuditRow, error) {
		var r viewAuditRow
		err := row.Scan(&r.Action, &r.Reason, &r.Target, &r.Purpose, &r.AccountID)
		return r, err
	})
	require.NoError(t, err)
	return got
}

func byDate(accountID uuid.UUID, date profile.LocalDate) ViewRequest {
	return ViewRequest{Target: ContentTarget{AccountID: accountID, Date: &date}, Purpose: PurposeInquiry, Reason: "문의 확인"}
}

func byID(accountID, id uuid.UUID) ViewRequest {
	return ViewRequest{Target: ContentTarget{AccountID: accountID, ID: &id}, Purpose: PurposeInquiry, Reason: "문의 확인"}
}

func TestViewDiary_ByDate(t *testing.T) {
	svc, pool := newTestService(t)
	account := insertAccount(t, pool)
	insertDiaryDay(t, pool, account, "2026-11-20", "tag-a", "tag-b")
	second := insertDiary(t, pool, account, "2026-11-20", "둘째 본문", "live", testNow.Add(-2*time.Hour))
	first := insertDiary(t, pool, account, "2026-11-20", "첫째 본문", "live", testNow.Add(-3*time.Hour))
	insertDiaryDay(t, pool, account, "2026-11-21", "other-day")
	insertDiary(t, pool, account, "2026-11-21", "다른 날", "live", testNow.Add(-time.Hour))

	got, err := svc.ViewDiary(context.Background(), testActor, byDate(account, viewDate))
	require.NoError(t, err)

	require.Len(t, got.Entries, 2)
	assert.Equal(t, first, got.Entries[0].ID)
	assert.Equal(t, "첫째 본문", got.Entries[0].Body)
	assert.Equal(t, viewDate, got.Entries[0].Date)
	assert.True(t, testNow.Add(-3*time.Hour).Equal(got.Entries[0].CreatedAt))
	assert.True(t, testNow.Add(-3*time.Hour).Equal(got.Entries[0].UpdatedAt))
	assert.Equal(t, second, got.Entries[1].ID)
	assert.Equal(t, 0, got.DeletedCount)
	assert.Equal(t, []string{"tag-a", "tag-b"}, got.Tags)
}

func TestViewDiary_ByID(t *testing.T) {
	svc, pool := newTestService(t)
	account := insertAccount(t, pool)
	insertDiaryDay(t, pool, account, "2026-11-20", "tag-a")
	id := insertDiary(t, pool, account, "2026-11-20", "본문", "live", testNow.Add(-time.Hour))
	insertDiary(t, pool, account, "2026-11-20", "같은 날 다른 편", "live", testNow.Add(-2*time.Hour))

	got, err := svc.ViewDiary(context.Background(), testActor, byID(account, id))
	require.NoError(t, err)

	require.Len(t, got.Entries, 1)
	assert.Equal(t, id, got.Entries[0].ID)
	assert.Equal(t, "본문", got.Entries[0].Body)
	assert.Equal(t, []string{"tag-a"}, got.Tags)
}

func TestViewDiary_NoDayRecordGivesEmptyTags(t *testing.T) {
	svc, pool := newTestService(t)
	account := insertAccount(t, pool)

	got, err := svc.ViewDiary(context.Background(), testActor, byDate(account, viewDate))
	require.NoError(t, err)
	assert.Empty(t, got.Entries)
	assert.NotNil(t, got.Tags)
	assert.Empty(t, got.Tags)
}

func TestViewDiary_OtherAccountIDNotVisible(t *testing.T) {
	svc, pool := newTestService(t)
	owner, other := insertAccount(t, pool), insertAccount(t, pool)
	insertDiaryDay(t, pool, owner, "2026-11-20", "tag-a")
	id := insertDiary(t, pool, owner, "2026-11-20", "남의 본문", "live", testNow.Add(-time.Hour))

	got, err := svc.ViewDiary(context.Background(), testActor, byID(other, id))
	require.NoError(t, err)
	assert.Empty(t, got.Entries)
	assert.Equal(t, 0, got.DeletedCount)
	assert.Empty(t, got.Tags)

	rows := viewAuditRows(t, pool)
	require.Len(t, rows, 1)
	require.NotNil(t, rows[0].AccountID)
	assert.Equal(t, other, *rows[0].AccountID)
	assert.JSONEq(t, fmt.Sprintf(`{"kind":"diary","id":%q,"ids":[],"count":0}`, id), rows[0].Target)
}

func TestViewDiary_ExcludesDeletedAndPurged(t *testing.T) {
	svc, pool := newTestService(t)
	account := insertAccount(t, pool)
	insertDiaryDay(t, pool, account, "2026-11-20", "tag-a")
	live := insertDiary(t, pool, account, "2026-11-20", "살아 있는 본문", "live", testNow.Add(-4*time.Hour))
	insertDiary(t, pool, account, "2026-11-20", "지운 본문", "deleted", testNow.Add(-3*time.Hour))
	insertDiary(t, pool, account, "2026-11-20", "비운 본문", "purged", testNow.Add(-2*time.Hour))

	got, err := svc.ViewDiary(context.Background(), testActor, byDate(account, viewDate))
	require.NoError(t, err)

	require.Len(t, got.Entries, 1)
	assert.Equal(t, live, got.Entries[0].ID)
	assert.Equal(t, 2, got.DeletedCount)
	assert.NotContains(t, fmt.Sprintf("%+v", got), "지운 본문")
}

func TestViewDiary_ByIDOfDeletedCountsOnly(t *testing.T) {
	svc, pool := newTestService(t)
	account := insertAccount(t, pool)
	insertDiaryDay(t, pool, account, "2026-11-20", "tag-a")
	id := insertDiary(t, pool, account, "2026-11-20", "지운 본문", "deleted", testNow.Add(-time.Hour))

	got, err := svc.ViewDiary(context.Background(), testActor, byID(account, id))
	require.NoError(t, err)
	assert.Empty(t, got.Entries)
	assert.Equal(t, 1, got.DeletedCount)
}

func TestViewDiary_AuditHasIDsNotBody(t *testing.T) {
	svc, pool := newTestService(t)
	account := insertAccount(t, pool)
	insertDiaryDay(t, pool, account, "2026-11-20", "tag-a")
	a := insertDiary(t, pool, account, "2026-11-20", "본문 하나", "live", testNow.Add(-3*time.Hour))
	b := insertDiary(t, pool, account, "2026-11-20", "본문 둘", "live", testNow.Add(-2*time.Hour))

	req := byDate(account, viewDate)
	req.Purpose, req.Reason = PurposeLegal, " 수사 협조 요청 "
	_, err := svc.ViewDiary(context.Background(), Actor{ID: "bran", Channel: ChannelAdminAPI}, req)
	require.NoError(t, err)

	rows := viewAuditRows(t, pool)
	require.Len(t, rows, 1)
	assert.Equal(t, "content_view", rows[0].Action)
	assert.Equal(t, "수사 협조 요청", rows[0].Reason)
	require.NotNil(t, rows[0].Purpose)
	assert.Equal(t, "legal", *rows[0].Purpose)
	require.NotNil(t, rows[0].AccountID)
	assert.Equal(t, account, *rows[0].AccountID)
	assert.JSONEq(t, fmt.Sprintf(`{"kind":"diary","date":"2026-11-20","ids":[%q,%q],"count":2}`, a, b), rows[0].Target)

	var leaked int
	require.NoError(t, pool.QueryRow(context.Background(), `SELECT count(*) FROM ops_audit
		WHERE target::text LIKE '%본문%' OR before::text LIKE '%본문%' OR after::text LIKE '%본문%' OR reason LIKE '%본문%'`).Scan(&leaked))
	assert.Zero(t, leaked)
}

func TestViewDiary_AccountNotFoundStillAudited(t *testing.T) {
	svc, pool := newTestService(t)

	got, err := svc.ViewDiary(context.Background(), testActor, byDate(uuid.New(), viewDate))
	require.ErrorIs(t, err, ErrAccountNotFound)
	assert.Equal(t, DiaryView{}, got)

	rows := viewAuditRows(t, pool)
	require.Len(t, rows, 1)
	assert.Equal(t, "content_view", rows[0].Action)
	assert.Nil(t, rows[0].AccountID)
}

func TestViewDiary_AuditFailureReturnsNothing(t *testing.T) {
	dbtest.LockCluster(t)
	_, pool := newTestService(t)
	account := insertAccount(t, pool)
	insertDiaryDay(t, pool, account, "2026-11-20", "tag-a")
	insertDiary(t, pool, account, "2026-11-20", "본문", "live", testNow.Add(-time.Hour))

	svc := newNoAuditService(t, pool)
	got, err := svc.ViewDiary(context.Background(), testActor, byDate(account, viewDate))
	require.Error(t, err)
	var pgErr *pgconn.PgError
	require.ErrorAs(t, err, &pgErr)
	assert.Equal(t, "42501", pgErr.Code)
	assert.Equal(t, DiaryView{}, got)
	assert.Empty(t, viewAuditRows(t, pool))
}

func TestView_RequiresExactlyOneOfDateOrID(t *testing.T) {
	svc, pool := newTestService(t)
	ctx := context.Background()
	account := insertAccount(t, pool)
	id := uuid.New()
	date := viewDate
	badDate := profile.LocalDate{Year: 2026, Month: 2, Day: 30}

	for name, target := range map[string]ContentTarget{
		"neither":     {AccountID: account},
		"both":        {AccountID: account, Date: &date, ID: &id},
		"invalidDate": {AccountID: account, Date: &badDate},
	} {
		req := ViewRequest{Target: target, Purpose: PurposeInquiry, Reason: "문의"}
		_, err := svc.ViewDiary(ctx, testActor, req)
		assert.ErrorIs(t, err, ErrContentTarget, name)
		_, err = svc.ViewSchedule(ctx, testActor, req)
		assert.ErrorIs(t, err, ErrContentTarget, name)
	}
	assert.Empty(t, viewAuditRows(t, pool))
}

func TestView_ValidatesInputBeforeDB(t *testing.T) {
	svc, pool := newTestService(t)
	ctx := context.Background()
	account := insertAccount(t, pool)

	req := byDate(account, viewDate)
	_, err := svc.ViewDiary(ctx, Actor{}, req)
	assert.ErrorIs(t, err, ErrActor)

	bad := req
	bad.Reason = ""
	_, err = svc.ViewDiary(ctx, testActor, bad)
	assert.ErrorIs(t, err, ErrReason)

	bad = req
	bad.Purpose = "curiosity"
	_, err = svc.ViewSchedule(ctx, testActor, bad)
	assert.ErrorIs(t, err, ErrPurpose)
	_, err = svc.ViewProfile(ctx, testActor, account, "", "문의")
	assert.ErrorIs(t, err, ErrPurpose)
	_, err = svc.ViewProfile(ctx, testActor, account, PurposeInquiry, "줄\n바꿈")
	assert.ErrorIs(t, err, ErrReason)
	assert.Empty(t, viewAuditRows(t, pool))
}

func TestViewSchedule_ByDate(t *testing.T) {
	svc, pool := newTestService(t)
	account := insertAccount(t, pool)
	memo := "비밀 메모"
	at := "14:30"
	timed := insertSchedule(t, pool, account, "2026-11-20", "회의", &memo, &at, false)
	allDay := insertSchedule(t, pool, account, "2026-11-20", "휴가", nil, nil, false)
	insertSchedule(t, pool, account, "2026-11-20", "지운 일정", nil, nil, true)
	insertSchedule(t, pool, account, "2026-11-21", "다른 날", nil, nil, false)

	got, err := svc.ViewSchedule(context.Background(), testActor, byDate(account, viewDate))
	require.NoError(t, err)

	require.Len(t, got.Entries, 2)
	assert.Equal(t, 1, got.DeletedCount)
	assert.Equal(t, ScheduleEntry{ID: allDay, Date: viewDate, AllDay: true, Title: "휴가"}, got.Entries[0])
	assert.Equal(t, timed, got.Entries[1].ID)
	assert.False(t, got.Entries[1].AllDay)
	require.NotNil(t, got.Entries[1].Time)
	assert.Equal(t, "14:30", *got.Entries[1].Time)
	require.NotNil(t, got.Entries[1].Memo)
	assert.Equal(t, memo, *got.Entries[1].Memo)

	rows := viewAuditRows(t, pool)
	require.Len(t, rows, 1)
	assert.JSONEq(t, fmt.Sprintf(`{"kind":"schedule","date":"2026-11-20","ids":[%q,%q],"count":2}`, allDay, timed), rows[0].Target)
	assert.NotContains(t, rows[0].Target, "회의")
	assert.NotContains(t, rows[0].Target, "비밀 메모")
}

func TestViewSchedule_ByIDOtherAccountNotVisible(t *testing.T) {
	svc, pool := newTestService(t)
	owner, other := insertAccount(t, pool), insertAccount(t, pool)
	id := insertSchedule(t, pool, owner, "2026-11-20", "회의", nil, nil, false)

	got, err := svc.ViewSchedule(context.Background(), testActor, byID(other, id))
	require.NoError(t, err)
	assert.Empty(t, got.Entries)

	got, err = svc.ViewSchedule(context.Background(), testActor, byID(owner, id))
	require.NoError(t, err)
	require.Len(t, got.Entries, 1)
	assert.Equal(t, "회의", got.Entries[0].Title)
	assert.Len(t, viewAuditRows(t, pool), 2)
}

func TestViewProfile_Audited(t *testing.T) {
	svc, pool := newTestService(t)
	account := insertAccount(t, pool)
	insertProfile(t, pool, account)

	got, err := svc.ViewProfile(context.Background(), testActor, account, PurposeInquiry, "계산 오류 문의")
	require.NoError(t, err)

	require.NotNil(t, got.Honorific)
	assert.Equal(t, "비밀호칭", *got.Honorific)
	assert.Equal(t, "ko", got.Language)
	assert.Equal(t, "Asia/Seoul", got.CurrentTimezone)
	require.NotNil(t, got.Calendar)
	assert.Equal(t, "solar", *got.Calendar)
	require.NotNil(t, got.IsLeapMonth)
	assert.False(t, *got.IsLeapMonth)
	require.NotNil(t, got.BirthDate)
	assert.Equal(t, profile.LocalDate{Year: 1990, Month: 5, Day: 17}, *got.BirthDate)
	require.NotNil(t, got.BirthTimeStatus)
	assert.Equal(t, "known", *got.BirthTimeStatus)
	require.NotNil(t, got.BirthTime)
	assert.Equal(t, "07:30", *got.BirthTime)
	require.NotNil(t, got.Gender)
	assert.Equal(t, "female", *got.Gender)
	require.NotNil(t, got.BirthTimezone)
	assert.Equal(t, "Asia/Seoul", *got.BirthTimezone)
	require.NotNil(t, got.BirthPlaceStatus)
	assert.Equal(t, "city", *got.BirthPlaceStatus)
	require.NotNil(t, got.BirthCityID)
	assert.Equal(t, "seoul", *got.BirthCityID)
	require.NotNil(t, got.Longitude)
	assert.InDelta(t, 126.978, *got.Longitude, 1e-9)

	rows := viewAuditRows(t, pool)
	require.Len(t, rows, 1)
	assert.Equal(t, "content_view", rows[0].Action)
	require.NotNil(t, rows[0].Purpose)
	assert.Equal(t, "inquiry", *rows[0].Purpose)
	require.NotNil(t, rows[0].AccountID)
	assert.Equal(t, account, *rows[0].AccountID)
	assert.JSONEq(t, `{"kind":"profile","count":1}`, rows[0].Target)
	for _, secret := range []string{"비밀호칭", "1990", "seoul", "126.978"} {
		assert.NotContains(t, rows[0].Target, secret)
	}
}

func TestViewProfile_MissingProfileOrAccount(t *testing.T) {
	svc, pool := newTestService(t)
	noProfile := insertAccount(t, pool)

	_, err := svc.ViewProfile(context.Background(), testActor, noProfile, PurposeInquiry, "문의")
	require.ErrorIs(t, err, ErrAccountNotFound)
	_, err = svc.ViewProfile(context.Background(), testActor, uuid.New(), PurposeInquiry, "문의")
	require.ErrorIs(t, err, ErrAccountNotFound)

	rows := viewAuditRows(t, pool)
	require.Len(t, rows, 2)
	assert.JSONEq(t, `{"kind":"profile","count":0}`, rows[0].Target)
}

// TestService_AllCommandsWorkAsOpsRole은 모든 명령이 myungli_ops 역할의 권한만으로 동작함을 확인합니다.
// 테스트 DB의 기본 사용자는 superuser라 이렇게 하지 않으면 migration의 권한 누락을 잡지 못합니다.
func TestService_AllCommandsWorkAsOpsRole(t *testing.T) {
	dbtest.LockCluster(t)
	_, admin := newTestService(t)
	ctx := context.Background()
	account := insertAccount(t, admin)
	insertProfile(t, admin, account)
	insertDiaryDay(t, admin, account, "2026-11-20", "tag-a")
	insertDiary(t, admin, account, "2026-11-20", "본문", "live", testNow.Add(-time.Hour))
	insertSchedule(t, admin, account, "2026-11-20", "회의", nil, nil, false)

	cfg := admin.Config().Copy()
	cfg.AfterConnect = func(ctx context.Context, conn *pgx.Conn) error {
		_, err := conn.Exec(ctx, "SET ROLE myungli_ops")
		return err
	}
	opsPool, err := pgxpool.NewWithConfig(ctx, cfg)
	require.NoError(t, err)
	t.Cleanup(opsPool.Close)
	svc := NewService(opsPool, clocktest.New(testNow))

	_, err = svc.AccountSummary(ctx, testActor, AccountKey{AccountID: account}, "문의")
	require.NoError(t, err, "AccountSummary")

	granted, err := svc.Grant(ctx, testActor, GrantRequest{
		AccountID: account, Kind: billing.OperatorAdFree, ExpiresAt: testNow.Add(24 * time.Hour), Reason: "보상",
	})
	require.NoError(t, err, "Grant")
	require.NotEmpty(t, granted.Grants)
	_, err = svc.Revoke(ctx, testActor, RevokeRequest{AccountID: account, GrantID: granted.Grants[0].ID, Reason: "회수"})
	require.NoError(t, err, "Revoke")

	diary, err := svc.ViewDiary(ctx, testActor, byDate(account, viewDate))
	require.NoError(t, err, "ViewDiary")
	assert.Len(t, diary.Entries, 1)
	schedule, err := svc.ViewSchedule(ctx, testActor, byDate(account, viewDate))
	require.NoError(t, err, "ViewSchedule")
	assert.Len(t, schedule.Entries, 1)
	_, err = svc.ViewProfile(ctx, testActor, account, PurposeInquiry, "문의")
	require.NoError(t, err, "ViewProfile")

	records, err := svc.AuditList(ctx, testActor, AuditFilter{AccountID: &account}, "점검")
	require.NoError(t, err, "AuditList")
	assert.Len(t, records, 6)
}
