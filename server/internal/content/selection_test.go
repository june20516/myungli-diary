package content_test

import (
	"context"
	"crypto/sha256"
	"maps"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/seed"
)

// 테스트에 쓰는 슬롯 이름입니다. extraTypeSlot은 하루 돌봄 상한(2개)을 넘겨 보려고 더한 세 번째 유형 슬롯입니다.
const (
	headSlot      = "daily.fortune.head"
	tagSlot       = "daily.fortune.tag"
	extraTypeSlot = "test.fortune.extra"
	guideSlot     = "daily.guide"
	colorSlot     = "daily.color"
)

// testSlots는 테스트 시드(testSeed)의 슬롯 명세입니다. Select는 활성 시드의 이 명세로 순환 방식을 정합니다.
var testSlots = map[string]seed.Slot{
	headSlot:      {ID: headSlot, Rotation: seed.RotationType},
	tagSlot:       {ID: tagSlot, Rotation: seed.RotationType},
	extraTypeSlot: {ID: extraTypeSlot, Rotation: seed.RotationType},
	guideSlot:     {ID: guideSlot, Rotation: seed.RotationVariant},
	colorSlot:     {ID: colorSlot, Rotation: seed.RotationNone},
}

// day0은 테스트의 기준 날짜(오늘)입니다.
var day0 = time.Date(2026, 10, 16, 0, 0, 0, 0, time.UTC)

func dayOffset(n int) time.Time { return day0.AddDate(0, 0, n) }

// selectFixture는 활성 시드, 계정 하나, 사주 지문 하나를 갖춘 테스트 환경입니다.
type selectFixture struct {
	pool    *pgxpool.Pool
	clock   *clocktest.Fake
	store   *content.Store
	version string
	account uuid.UUID
	hash    [32]byte
}

func newSelectFixture(t *testing.T) *selectFixture {
	t.Helper()
	return newSelectFixtureOn(t, dbtest.New(t))
}

// newSelectFixtureOn은 pool 위에 selectFixture를 만듭니다.
func newSelectFixtureOn(t *testing.T, pool *pgxpool.Pool) *selectFixture {
	t.Helper()
	ctx := context.Background()
	s := testSeed(t, "")
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)

	var account uuid.UUID
	require.NoError(t, pool.QueryRow(ctx,
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&account))
	clk := clocktest.New(time.Date(2026, 10, 16, 9, 0, 0, 0, time.UTC))
	return &selectFixture{pool: pool, clock: clk, store: content.NewStore(pool, clk, discardLog()), version: s.Version, account: account, hash: birthHash("h1")}
}

func birthHash(s string) [32]byte { return sha256.Sum256([]byte(s)) }

// pick은 슬롯 하나를 고르고 결과 하나를 돌려줍니다.
func (f *selectFixture) pick(t *testing.T, date time.Time, hash [32]byte, slot, key string) content.Selection {
	t.Helper()
	got, err := f.store.Select(context.Background(), f.account, date, hash, []content.SlotRequest{{Slot: slot, MessageKey: key}})
	require.NoError(t, err)
	require.Len(t, got, 1)
	return got[0]
}

// rotation은 rotation_state의 다음 차례를 돌려줍니다. 행이 없으면 ""입니다.
func (f *selectFixture) rotation(t *testing.T, key string) string {
	t.Helper()
	var next string
	err := f.pool.QueryRow(context.Background(),
		"SELECT coalesce((SELECT next_variant FROM rotation_state WHERE account_id = $1 AND message_key = $2), '')", f.account, key).Scan(&next)
	require.NoError(t, err)
	return next
}

// setRotation은 rotation_state의 다음 차례를 직접 정합니다.
func (f *selectFixture) setRotation(t *testing.T, key, next string) {
	t.Helper()
	_, err := f.pool.Exec(context.Background(), `INSERT INTO rotation_state (account_id, message_key, next_variant) VALUES ($1, $2, $3)
		ON CONFLICT (account_id, message_key) DO UPDATE SET next_variant = EXCLUDED.next_variant`, f.account, key, next)
	require.NoError(t, err)
}

// insertCare는 지난 선택 기록(variant care)을 직접 넣습니다.
func (f *selectFixture) insertCare(t *testing.T, date time.Time, slot string, hash [32]byte) {
	t.Helper()
	_, err := f.pool.Exec(context.Background(), `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, $2, $3, $4, 'past', 'care', $5)`, f.account, date.Format(time.DateOnly), slot, hash[:], f.version)
	require.NoError(t, err)
}

func (f *selectFixture) countRows(t *testing.T, query string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, f.pool.QueryRow(context.Background(), query, args...).Scan(&n))
	return n
}

func TestSelect_NewUserStartsWithAdvice(t *testing.T) {
	f := newSelectFixture(t)
	// 시각과 시간대가 있어도 날짜 부분만 씁니다.
	seoul := time.FixedZone("KST", 9*60*60)
	date := time.Date(2026, 10, 16, 23, 30, 0, 0, seoul)

	got, err := f.store.Select(context.Background(), f.account, date, f.hash,
		[]content.SlotRequest{{Slot: headSlot, MessageKey: "k.head"}, {Slot: tagSlot, MessageKey: "k.tag"}})
	require.NoError(t, err)
	require.Len(t, got, 2)

	assert.Equal(t, headSlot, got[0].Slot, "결과는 요청 순서")
	assert.Equal(t, tagSlot, got[1].Slot)
	for _, sel := range got {
		assert.Equal(t, "advice", sel.Variant)
		assert.Equal(t, f.version, sel.SeedVersion)
		assert.NotZero(t, sel.ID)
	}
	assert.Equal(t, "k.head", got[0].MessageKey)
	assert.Equal(t, "state", f.rotation(t, "k.head"))
	assert.Equal(t, "state", f.rotation(t, "k.tag"))
	assert.Equal(t, 2, f.countRows(t, "SELECT count(*) FROM daily_selections WHERE date = '2026-10-16'"))
}

func TestSelect_SameKeyReusesRecord(t *testing.T) {
	f := newSelectFixture(t)
	first := f.pick(t, day0, f.hash, headSlot, "k")

	// 시드가 새 버전으로 바뀌어도 기록은 옛 버전을 그대로 씁니다.
	_, err := content.Apply(context.Background(), f.pool, testSeed(t, "!"))
	require.NoError(t, err)

	second := f.pick(t, day0, f.hash, headSlot, "k")
	assert.Equal(t, first, second, "같은 기록(ID·Variant·SeedVersion)")
	assert.Equal(t, f.version, second.SeedVersion)
	assert.Equal(t, "state", f.rotation(t, "k"), "다시 쓰면 순환은 그대로")
}

func TestSelect_ChangedKeySelectsAgain(t *testing.T) {
	f := newSelectFixture(t)
	// k2를 전날 한 번 써서 다음 차례를 state로 만들어 둡니다.
	f.pick(t, dayOffset(-1), f.hash, headSlot, "k2")
	first := f.pick(t, day0, f.hash, headSlot, "k1")
	require.Equal(t, "advice", first.Variant)

	second := f.pick(t, day0, f.hash, headSlot, "k2")
	assert.Equal(t, "k2", second.MessageKey)
	assert.Equal(t, "state", second.Variant, "새 키의 순환 차례로 새로 고름")
	assert.Equal(t, first.ID, second.ID, "(계정, 날짜, 슬롯, 지문)마다 기록은 하나")
	assert.Equal(t, "care", f.rotation(t, "k2"))
	assert.Equal(t, "state", f.rotation(t, "k1"), "옛 키의 순환은 건드리지 않음")

	again, err := f.store.SelectionFor(context.Background(), f.account, day0, headSlot, f.hash)
	require.NoError(t, err)
	assert.Equal(t, second, again)
}

func TestSelect_RotatesAdviceStateCare(t *testing.T) {
	f := newSelectFixture(t)
	want := []string{"advice", "state", "care", "advice"}
	for i, variant := range want {
		got := f.pick(t, dayOffset(i), f.hash, headSlot, "k")
		assert.Equal(t, variant, got.Variant, "%d번째 날", i)
	}
	assert.Equal(t, "state", f.rotation(t, "k"))
}

func TestSelect_GuideRotatesOneTwo(t *testing.T) {
	f := newSelectFixture(t)
	for i, variant := range []string{"1", "2", "1"} {
		got := f.pick(t, dayOffset(i), f.hash, guideSlot, "g")
		assert.Equal(t, variant, got.Variant, "%d번째 날", i)
	}
	assert.Equal(t, "2", f.rotation(t, "g"))
}

func TestSelect_InfoSlotIsSingle(t *testing.T) {
	f := newSelectFixture(t)
	for i := range 2 {
		got := f.pick(t, dayOffset(i), f.hash, colorSlot, "c")
		assert.Equal(t, seed.VariantSingle, got.Variant)
	}
	assert.Equal(t, 0, f.countRows(t, "SELECT count(*) FROM rotation_state"), "순환 없는 슬롯은 rotation_state를 쓰지 않음")
}

func TestSelect_StoredRotationOutsideCycleRestarts(t *testing.T) {
	f := newSelectFixture(t)
	f.setRotation(t, "k", "2") // 유형 슬롯에 맞지 않는 값
	got := f.pick(t, day0, f.hash, headSlot, "k")
	assert.Equal(t, "advice", got.Variant, "모르는 차례면 처음부터")
	assert.Equal(t, "state", f.rotation(t, "k"))
}

func TestSelect_CareSkippedAtDailyCap(t *testing.T) {
	f := newSelectFixture(t)
	for _, key := range []string{"k.head", "k.tag", "k.extra"} {
		f.setRotation(t, key, "care")
	}

	// 한 호출 안에서 앞 두 슬롯이 이번에 고른 care도 셉니다.
	got, err := f.store.Select(context.Background(), f.account, day0, f.hash, []content.SlotRequest{
		{Slot: headSlot, MessageKey: "k.head"},
		{Slot: tagSlot, MessageKey: "k.tag"},
		{Slot: extraTypeSlot, MessageKey: "k.extra"},
	})
	require.NoError(t, err)
	require.Len(t, got, 3)
	assert.Equal(t, "care", got[0].Variant)
	assert.Equal(t, "care", got[1].Variant)
	assert.Equal(t, "advice", got[2].Variant, "하루 2개를 넘으므로 care를 건너뛰고 다음 차례")
	assert.Equal(t, "state", f.rotation(t, "k.extra"), "실제로 고른 advice의 다음")
	assert.Equal(t, "advice", f.rotation(t, "k.head"))
}

func TestSelect_CareSkippedAtWeeklyCap(t *testing.T) {
	tests := []struct {
		name string
		// past는 오늘 전 care 기록의 (날짜 오프셋, 슬롯)입니다.
		past []struct {
			offset int
			slot   string
		}
		want string
	}{
		{
			name: "최근 7일 7개면 건너뜀",
			past: []struct {
				offset int
				slot   string
			}{{-6, headSlot}, {-5, headSlot}, {-4, headSlot}, {-3, headSlot}, {-2, headSlot}, {-1, headSlot}, {-1, tagSlot}},
			want: "advice",
		},
		{
			name: "7일 전 기록은 세지 않음",
			past: []struct {
				offset int
				slot   string
			}{{-7, headSlot}, {-5, headSlot}, {-4, headSlot}, {-3, headSlot}, {-2, headSlot}, {-1, headSlot}, {-1, tagSlot}},
			want: "care",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newSelectFixture(t)
			for _, p := range tt.past {
				f.insertCare(t, dayOffset(p.offset), p.slot, f.hash)
			}
			f.setRotation(t, "k", "care")
			got := f.pick(t, day0, f.hash, headSlot, "k")
			assert.Equal(t, tt.want, got.Variant)
		})
	}
}

func TestSelect_CareCountsOncePerDateSlot(t *testing.T) {
	f := newSelectFixture(t)
	// 오늘 head에 지문만 다른 care 두 줄 → 하나로 세어 1개라 extra는 care를 고를 수 있습니다.
	f.insertCare(t, day0, headSlot, birthHash("old1"))
	f.insertCare(t, day0, headSlot, birthHash("old2"))
	f.setRotation(t, "k", "care")
	got := f.pick(t, day0, f.hash, extraTypeSlot, "k")
	assert.Equal(t, "care", got.Variant)
}

func TestSelect_CareCapExcludesSlotBeingSelected(t *testing.T) {
	f := newSelectFixture(t)
	// 오늘 head(같은 지문, 옛 키)와 tag에 care가 있습니다. head의 키가 바뀌어 그 기록을 새로 고르면
	// 바뀔 기록 자신은 세지 않으므로 오늘 care는 tag 하나이고, care를 고를 수 있습니다.
	f.insertCare(t, day0, headSlot, f.hash)
	f.insertCare(t, day0, tagSlot, f.hash)
	f.setRotation(t, "k", "care")
	got := f.pick(t, day0, f.hash, headSlot, "k")
	assert.Equal(t, "care", got.Variant)
	assert.Equal(t, 2, f.countRows(t, "SELECT count(*) FROM daily_selections"), "같은 행을 바꿈")
}

func TestSelect_NewBirthHashSelectsAgainAndAdvances(t *testing.T) {
	tests := []struct {
		start      string // 첫 선택 때의 차례
		first      string
		second     string
		afterTwice string
	}{
		{start: "advice", first: "advice", second: "state", afterTwice: "care"},
		{start: "state", first: "state", second: "care", afterTwice: "advice"},
		{start: "care", first: "care", second: "advice", afterTwice: "state"},
	}
	for _, tt := range tests {
		t.Run(tt.start, func(t *testing.T) {
			f := newSelectFixture(t)
			f.setRotation(t, "k", tt.start)
			old := f.pick(t, day0, birthHash("old"), headSlot, "k")
			require.Equal(t, tt.first, old.Variant)

			got := f.pick(t, day0, birthHash("new"), headSlot, "k")
			assert.Equal(t, tt.second, got.Variant)
			assert.NotEqual(t, old.Variant, got.Variant, "같은 날 다시 고른 문장은 앞 문장과 유형이 다름")
			assert.NotEqual(t, old.ID, got.ID, "새 지문은 새 기록")
			assert.Equal(t, tt.afterTwice, f.rotation(t, "k"), "두 번 모두 한 칸씩 넘김")

			kept, err := f.store.SelectionFor(context.Background(), f.account, day0, headSlot, birthHash("old"))
			require.NoError(t, err, "옛 지문 기록은 남음")
			assert.Equal(t, old, kept)
		})
	}
}

// poolWithMaxConns는 연결 수 상한을 정한 테스트 DB pool입니다. 동시성 테스트가 기본 상한(CPU 수에 따라 다름)에 막히지 않게 합니다.
func poolWithMaxConns(t *testing.T, maxConns int32) *pgxpool.Pool {
	t.Helper()
	cfg, err := pgxpool.ParseConfig(dbtest.NewURL(t))
	require.NoError(t, err)
	cfg.MaxConns = maxConns
	pool, err := pgxpool.NewWithConfig(context.Background(), cfg)
	require.NoError(t, err)
	t.Cleanup(pool.Close)
	return pool
}

func TestSelect_ConcurrentFirstOpenAgrees(t *testing.T) {
	ctx := context.Background()
	// lock을 쥔 연결 1 + Select 트랜잭션 2 + lock 대기 조회 1보다 여유 있게 둡니다.
	f := newSelectFixtureOn(t, poolWithMaxConns(t, 8))
	reqs := []content.SlotRequest{{Slot: headSlot, MessageKey: "k.head"}, {Slot: guideSlot, MessageKey: "k.guide"}}

	// 별도 연결로 같은 계정 lock을 먼저 쥡니다. 두 Select가 모두 이 lock을 기다리는 것을 확인한 뒤 풀어,
	// 두 요청이 실제로 경합하게 합니다. Select가 lock을 걸지 않으면 기다리는 lock이 생기지 않아 이 테스트가 실패합니다.
	holder, err := f.pool.Begin(ctx)
	require.NoError(t, err)
	lockSQL, lockArgs := content.SelectionLockForTest(f.account)
	_, err = holder.Exec(ctx, lockSQL, lockArgs...)
	require.NoError(t, err)

	const callers = 2
	results := make([][]content.Selection, callers)
	errs := make([]error, callers)
	var wg sync.WaitGroup
	for i := range callers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results[i], errs[i] = f.store.Select(ctx, f.account, day0, f.hash, reqs)
		}()
	}

	waiting := func() int {
		var n int
		err := f.pool.QueryRow(ctx, `SELECT count(*) FROM pg_locks
			WHERE locktype = 'advisory' AND NOT granted AND objsubid = 2 AND classid::bigint = $1`,
			content.SelectionLockClassForTest).Scan(&n)
		if err != nil {
			return -1
		}
		return n
	}
	lockedOut := assert.Eventually(t, func() bool { return waiting() == callers }, 10*time.Second, 10*time.Millisecond,
		"두 Select가 모두 계정 lock을 기다려야 함")
	require.NoError(t, holder.Rollback(ctx))
	wg.Wait()
	require.True(t, lockedOut)

	for i := range callers {
		require.NoError(t, errs[i])
	}
	assert.Equal(t, results[0], results[1], "두 요청이 같은 결과")
	assert.Equal(t, "advice", results[0][0].Variant)
	assert.Equal(t, "1", results[0][1].Variant)
	assert.Equal(t, "state", f.rotation(t, "k.head"), "순환은 한 번만 넘어감")
	assert.Equal(t, "2", f.rotation(t, "k.guide"))
	assert.Equal(t, 2, f.countRows(t, "SELECT count(*) FROM daily_selections"))
}

func TestSelect_Errors(t *testing.T) {
	tests := []struct {
		name string
		reqs []content.SlotRequest
	}{
		{name: "모르는 슬롯", reqs: []content.SlotRequest{{Slot: "nope", MessageKey: "k"}}},
		{name: "같은 슬롯 두 번", reqs: []content.SlotRequest{{Slot: headSlot, MessageKey: "a"}, {Slot: headSlot, MessageKey: "b"}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newSelectFixture(t)
			_, err := f.store.Select(context.Background(), f.account, day0, f.hash, tt.reqs)
			require.Error(t, err)
			assert.Equal(t, 0, f.countRows(t, "SELECT count(*) FROM daily_selections"), "아무것도 기록하지 않음")
		})
	}
}

func TestSelect_NoActiveSeed(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	var account uuid.UUID
	require.NoError(t, pool.QueryRow(ctx,
		"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&account))

	_, err := content.NewStore(pool, clocktest.New(day0), discardLog()).Select(ctx, account, day0, birthHash("h"),
		[]content.SlotRequest{{Slot: headSlot, MessageKey: "k"}})
	assert.ErrorIs(t, err, content.ErrNoActiveSeed)
}

func TestSelectionFor_NotFound(t *testing.T) {
	f := newSelectFixture(t)
	f.pick(t, day0, f.hash, headSlot, "k")

	_, err := f.store.SelectionFor(context.Background(), f.account, day0, tagSlot, f.hash)
	assert.ErrorIs(t, err, content.ErrSelectionNotFound, "다른 슬롯")
	_, err = f.store.SelectionFor(context.Background(), f.account, dayOffset(1), headSlot, f.hash)
	assert.ErrorIs(t, err, content.ErrSelectionNotFound, "다른 날")
	_, err = f.store.SelectionFor(context.Background(), f.account, day0, headSlot, birthHash("other"))
	assert.ErrorIs(t, err, content.ErrSelectionNotFound, "다른 지문")
}

func TestSelect_ChangedKeySoftDeletesReaction(t *testing.T) {
	ctx := context.Background()
	f := newSelectFixture(t)
	first := f.pick(t, day0, f.hash, headSlot, "k1")
	_, err := f.pool.Exec(ctx, "INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'like')", first.ID)
	require.NoError(t, err)

	same := f.pick(t, day0, f.hash, headSlot, "k1")
	require.Equal(t, first, same)
	assert.Equal(t, 1, f.countRows(t, "SELECT count(*) FROM reactions WHERE deleted_at IS NULL"), "키가 같으면 반응을 건드리지 않음")

	second := f.pick(t, day0, f.hash, headSlot, "k2")
	assert.Equal(t, first.ID, second.ID, "행 id는 그대로")
	var deletedAt *time.Time
	require.NoError(t, f.pool.QueryRow(ctx, "SELECT deleted_at FROM reactions WHERE selection_id = $1", first.ID).Scan(&deletedAt))
	require.NotNil(t, deletedAt, "새 문장에 옛 반응이 붙지 않게 soft delete")
	assert.True(t, f.clock.Now().Equal(*deletedAt), "clock 기준 시각")
}

func TestSelect_SameDayOtherHashTypeIsSkipped(t *testing.T) {
	tests := []struct {
		name string
		run  func(t *testing.T, f *selectFixture) (old []content.Selection, got content.Selection)
		want string
		next string
	}{
		{
			name: "키와 지문이 함께 바뀜",
			run: func(t *testing.T, f *selectFixture) ([]content.Selection, content.Selection) {
				old := f.pick(t, day0, birthHash("h1"), headSlot, "k1")
				return []content.Selection{old}, f.pick(t, day0, birthHash("h2"), headSlot, "k2")
			},
			want: "state", next: "care",
		},
		{
			name: "지난 날짜를 나중에 다시 고름",
			run: func(t *testing.T, f *selectFixture) ([]content.Selection, content.Selection) {
				old := f.pick(t, day0, birthHash("h1"), headSlot, "k")  // advice
				f.pick(t, dayOffset(1), birthHash("h1"), headSlot, "k") // state
				f.pick(t, dayOffset(2), birthHash("h1"), headSlot, "k") // care → 다음 차례 advice
				return []content.Selection{old}, f.pick(t, day0, birthHash("h2"), headSlot, "k")
			},
			want: "state", next: "care",
		},
		{
			name: "돌봄 상한과 함께 건너뜀",
			run: func(t *testing.T, f *selectFixture) ([]content.Selection, content.Selection) {
				old := f.pick(t, day0, birthHash("h1"), headSlot, "k") // advice
				f.insertCare(t, day0, tagSlot, birthHash("h1"))
				f.insertCare(t, day0, extraTypeSlot, birthHash("h1"))
				f.setRotation(t, "k", "care")
				// care는 상한, advice는 같은 날 앞 지문의 유형이라 둘 다 건너뜁니다.
				return []content.Selection{old}, f.pick(t, day0, birthHash("h2"), headSlot, "k")
			},
			want: "state", next: "care",
		},
		{
			// 같은 날 앞 지문이 advice·state를 썼고 care는 상한입니다. 상한이 우선이라 회피만 풀고,
			// 차례(care) 다음부터 보아 상한에 걸리지 않는 첫 후보 advice를 고릅니다.
			name: "회피 후보가 모두 막히면 상한만 지킴",
			run: func(t *testing.T, f *selectFixture) ([]content.Selection, content.Selection) {
				a := f.pick(t, day0, birthHash("h1"), headSlot, "k") // advice
				b := f.pick(t, day0, birthHash("h2"), headSlot, "k") // state
				require.Equal(t, "state", b.Variant)
				require.Equal(t, "care", f.rotation(t, "k"))
				f.insertCare(t, day0, tagSlot, birthHash("h1"))
				f.insertCare(t, day0, extraTypeSlot, birthHash("h1"))
				return []content.Selection{a, b}, f.pick(t, day0, birthHash("h3"), headSlot, "k")
			},
			want: "advice", next: "state",
		},
		{
			name: "회피 후보가 모두 막히면 차례부터 첫 후보",
			run: func(t *testing.T, f *selectFixture) ([]content.Selection, content.Selection) {
				a := f.pick(t, day0, birthHash("h1"), guideSlot, "g") // 1
				b := f.pick(t, day0, birthHash("h2"), guideSlot, "g") // 1이 막혀 2
				require.Equal(t, "2", b.Variant)
				return []content.Selection{a, b}, f.pick(t, day0, birthHash("h3"), guideSlot, "g")
			},
			want: "1", next: "2",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newSelectFixture(t)
			old, got := tt.run(t, f)
			assert.Equal(t, tt.want, got.Variant)
			if len(old) == 1 {
				assert.NotEqual(t, old[0].Variant, got.Variant, "같은 날 같은 슬롯의 앞 유형과 다름")
			}
			assert.Equal(t, tt.next, f.rotation(t, got.MessageKey), "실제로 고른 것의 다음")
		})
	}
}

// 순환 방식은 Select 트랜잭션이 읽은 활성 시드 버전의 슬롯 명세를 따릅니다.
func TestSelect_UsesActiveSeedSlotSpec(t *testing.T) {
	ctx := context.Background()
	f := newSelectFixture(t)
	assert.Equal(t, "1", f.pick(t, day0, f.hash, guideSlot, "k.a").Variant, "변주 슬롯")

	// 새 시드에서 가이드 슬롯이 순환하지 않게 바뀌면, 새로 고르는 기록은 single입니다.
	changed := maps.Clone(testSlots)
	changed[guideSlot] = seed.Slot{ID: guideSlot, Rotation: seed.RotationNone}
	next := testSeedWithSlots(t, changed, "")
	_, err := content.Apply(ctx, f.pool, next)
	require.NoError(t, err)

	got := f.pick(t, dayOffset(1), f.hash, guideSlot, "k.b")
	assert.Equal(t, seed.VariantSingle, got.Variant)
	assert.Equal(t, next.Version, got.SeedVersion)
	// 옛 기록은 옛 버전 그대로입니다.
	old := f.pick(t, day0, f.hash, guideSlot, "k.a")
	assert.Equal(t, "1", old.Variant)
	assert.Equal(t, f.version, old.SeedVersion)

	// 활성 명세에서 빠진 슬롯은 오류이고 아무것도 기록하지 않습니다.
	delete(changed, colorSlot)
	_, err = content.Apply(ctx, f.pool, testSeedWithSlots(t, changed, ""))
	require.NoError(t, err)
	_, err = f.store.Select(ctx, f.account, dayOffset(2), f.hash, []content.SlotRequest{{Slot: colorSlot, MessageKey: "k"}})
	assert.ErrorContains(t, err, colorSlot)
	assert.Zero(t, f.countRows(t, "SELECT count(*) FROM daily_selections WHERE date = $1", dayOffset(2)))
}
