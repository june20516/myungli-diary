package content_test

import (
	"bytes"
	"context"
	"log/slog"
	"maps"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/seed"
)

// discardLog는 로그를 보지 않는 테스트의 logger입니다.
func discardLog() *slog.Logger { return slog.New(slog.DiscardHandler) }

// testSeed는 템플릿 body를 바꿔 서로 다른 Version을 얻는 작은 시드입니다. 슬롯 명세는 선택 테스트의 testSlots입니다.
func testSeed(t *testing.T, suffix string) seed.Seed {
	t.Helper()
	return testSeedWithSlots(t, testSlots, suffix)
}

// testSeedWithSlots는 슬롯 명세를 바꾼 testSeed입니다.
func testSeedWithSlots(t *testing.T, slots map[string]seed.Slot, suffix string) seed.Seed {
	t.Helper()
	s := seed.Seed{
		Slots: slots,
		Templates: []seed.Template{
			{Slot: "daily.guide", Key: "k", Variant: "1", Lang: "ko", Body: "한국어 1" + suffix},
			{Slot: "daily.guide", Key: "k", Variant: "1", Lang: "en", Body: "english 1" + suffix},
			{Slot: "glossary.value_name", Key: "element.wood", Variant: "single", Lang: "ko", Body: "나무"},
			{Slot: "glossary.value_name", Key: "element.wood", Variant: "single", Lang: "en", Body: "Wood"},
		},
	}
	require.NoError(t, s.Normalize())
	return s
}

func TestApply_InsertsAndActivates(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")

	applied, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	assert.True(t, applied)

	version, err := content.NewStore(pool, clock.System{}, discardLog()).Active(ctx)
	require.NoError(t, err)
	assert.Equal(t, s.Version, version)

	var n int
	require.NoError(t, pool.QueryRow(ctx, "SELECT count(*) FROM content_templates WHERE seed_version = $1", s.Version).Scan(&n))
	assert.Equal(t, len(s.Templates), n)
}

func TestApply_SameVersionIsNoop(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")

	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	applied, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	assert.False(t, applied, "같은 버전은 다시 넣지 않음")

	var n int
	require.NoError(t, pool.QueryRow(ctx, "SELECT count(*) FROM content_templates").Scan(&n))
	assert.Equal(t, len(s.Templates), n)
}

func TestApply_SameVersionReactivatesOldSeed(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	old, next := testSeed(t, ""), testSeed(t, "!")

	for _, s := range []seed.Seed{old, next, old} {
		_, err := content.Apply(ctx, pool, s)
		require.NoError(t, err)
	}
	version, err := content.NewStore(pool, clock.System{}, discardLog()).Active(ctx)
	require.NoError(t, err)
	assert.Equal(t, old.Version, version, "옛 버전으로 되돌리면 그 버전이 활성")
}

func TestApply_NewVersionKeepsOldRows(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	old, next := testSeed(t, ""), testSeed(t, "!")
	require.NotEqual(t, old.Version, next.Version)

	for _, s := range []seed.Seed{old, next} {
		applied, err := content.Apply(ctx, pool, s)
		require.NoError(t, err)
		assert.True(t, applied)
	}

	var templates, seeds, active int
	require.NoError(t, pool.QueryRow(ctx, "SELECT count(*) FROM content_templates WHERE seed_version = $1", old.Version).Scan(&templates))
	assert.Equal(t, len(old.Templates), templates, "옛 버전 행이 남음")
	require.NoError(t, pool.QueryRow(ctx, "SELECT count(*), count(*) FILTER (WHERE active) FROM content_seeds").Scan(&seeds, &active))
	assert.Equal(t, 2, seeds)
	assert.Equal(t, 1, active, "활성은 하나")

	version, err := content.NewStore(pool, clock.System{}, discardLog()).Active(ctx)
	require.NoError(t, err)
	assert.Equal(t, next.Version, version)
}

func TestStore_TemplatesByVersionAndLang(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	old, next := testSeed(t, ""), testSeed(t, "!")
	for _, s := range []seed.Seed{old, next} {
		_, err := content.Apply(ctx, pool, s)
		require.NoError(t, err)
	}
	store := content.NewStore(pool, clock.System{}, discardLog())

	ko, err := store.Templates(ctx, old.Version, "ko")
	require.NoError(t, err)
	body, ok := ko.Body("daily.guide", "k", "1")
	assert.True(t, ok)
	assert.Equal(t, "한국어 1", body)

	en, err := store.Templates(ctx, next.Version, "en")
	require.NoError(t, err)
	body, ok = en.Body("daily.guide", "k", "1")
	assert.True(t, ok)
	assert.Equal(t, "english 1!", body)

	_, ok = ko.Body("daily.guide", "k", "2")
	assert.False(t, ok, "없는 변주")
	_, ok = ko.Body("daily.guide", "nope", "1")
	assert.False(t, ok, "없는 키")

	name, ok := ko.ValueName("element", "wood")
	assert.True(t, ok)
	assert.Equal(t, "나무", name)
	name, ok = en.ValueName("element", "wood")
	assert.True(t, ok)
	assert.Equal(t, "Wood", name)
	_, ok = ko.ValueName("element", "fire")
	assert.False(t, ok, "사전에 없는 값")

	empty, err := store.Templates(ctx, old.Version, "ja")
	require.NoError(t, err)
	_, ok = empty.Body("daily.guide", "k", "1")
	assert.False(t, ok, "다른 언어로 폴백하지 않음")
}

func TestStore_TemplatesAreCachedAndConcurrentSafe(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	store := content.NewStore(pool, clock.System{}, discardLog())

	first, err := store.Templates(ctx, s.Version, "ko")
	require.NoError(t, err)
	// 캐시에 있으면 DB 내용이 바뀌어도(시드 버전은 불변이라 실제로는 없는 일) 같은 사본을 돌려줍니다.
	_, err = pool.Exec(ctx, "DELETE FROM content_templates WHERE lang = 'ko'")
	require.NoError(t, err)

	var wg sync.WaitGroup
	for range 8 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			got, err := store.Templates(ctx, s.Version, "ko")
			assert.NoError(t, err)
			body, ok := got.Body("daily.guide", "k", "1")
			assert.True(t, ok)
			assert.Equal(t, "한국어 1", body)
		}()
	}
	wg.Wait()
	assert.Same(t, first, mustTemplates(t, store, s.Version))
}

func mustTemplates(t *testing.T, store *content.Store, version string) content.Templates {
	t.Helper()
	got, err := store.Templates(context.Background(), version, "ko")
	require.NoError(t, err)
	return got
}

func TestStore_ActiveMissingIsErrNoActiveSeed(t *testing.T) {
	_, err := content.NewStore(dbtest.New(t), clock.System{}, discardLog()).Active(context.Background())
	assert.ErrorIs(t, err, content.ErrNoActiveSeed)
}

func TestApply_DuplicateTemplateInSeedFails(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")
	s.Templates = append(s.Templates, s.Templates[0])

	applied, err := content.Apply(ctx, pool, s)
	require.Error(t, err, "시드 안 중복은 삼키지 않고 오류")
	assert.False(t, applied)

	_, err = content.NewStore(pool, clock.System{}, discardLog()).Active(ctx)
	assert.ErrorIs(t, err, content.ErrNoActiveSeed, "실패한 적재는 롤백")
}

// lockTemplates는 다른 트랜잭션으로 content_templates를 잠가 조회가 끝나지 못하게 하고, 잠금을 푸는 함수를 돌려줍니다.
func lockTemplates(t *testing.T, pool *pgxpool.Pool) (release func()) {
	t.Helper()
	ctx := context.Background()
	tx, err := pool.Begin(ctx)
	require.NoError(t, err)
	_, err = tx.Exec(ctx, "LOCK TABLE content_templates IN ACCESS EXCLUSIVE MODE")
	require.NoError(t, err)
	return func() { require.NoError(t, tx.Rollback(ctx)) }
}

// waitForBlockedQuery는 잠금을 기다리는 쿼리가 생길 때까지 기다립니다(고정 sleep 대신 DB 상태를 봅니다).
func waitForBlockedQuery(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	require.Eventually(t, func() bool {
		var n int
		err := pool.QueryRow(context.Background(),
			"SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock' AND query LIKE '%content_templates%'").Scan(&n)
		return err == nil && n > 0
	}, 10*time.Second, 10*time.Millisecond)
}

func TestStore_TemplatesCallerCancelDoesNotFailOtherWaiters(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	store := content.NewStore(pool, clock.System{}, discardLog())
	// 슬롯 명세를 먼저 캐시해 두어, 아래 두 호출의 flight는 문장 틀 로드 하나뿐입니다.
	_, err = store.Slots(ctx, s.Version)
	require.NoError(t, err)
	// 호출이 문장 틀 flight에 들어갈 때마다 알립니다. 두 번째 호출이 합류한 것을 본 뒤에 첫 호출자를 취소합니다.
	joined := make(chan string, 2)
	content.SetFlightHookForTest(store, func(key string) {
		if strings.HasPrefix(key, "templates") {
			joined <- key
		}
	})
	release := lockTemplates(t, pool)

	firstCtx, cancelFirst := context.WithCancel(ctx)
	defer cancelFirst()
	firstErr := make(chan error, 1)
	go func() {
		_, err := store.Templates(firstCtx, s.Version, "ko")
		firstErr <- err
	}()
	waitForBlockedQuery(t, pool)
	first := <-joined

	type result struct {
		tpl content.Templates
		err error
	}
	second := make(chan result, 1)
	go func() {
		tpl, err := store.Templates(ctx, s.Version, "ko")
		second <- result{tpl, err}
	}()
	// 로드는 잠금에 막혀 끝나지 않았으므로, 같은 키로 들어온 두 번째 호출은 첫 호출의 flight에 합류한 것입니다.
	require.Equal(t, first, <-joined, "두 번째 호출이 같은 flight에 합류")

	cancelFirst()
	require.ErrorIs(t, <-firstErr, context.Canceled, "취소한 호출자는 ctx 오류")
	release()

	res := <-second
	require.NoError(t, res.err, "다른 호출자는 첫 호출자의 취소에 영향받지 않음")
	_, ok := res.tpl.Body("daily.guide", "k", "1")
	assert.True(t, ok)

	// 로드가 캐시를 채웠으므로 DB 없이도 같은 사본이 나옵니다.
	_, err = pool.Exec(ctx, "DELETE FROM content_templates")
	require.NoError(t, err)
	again, err := store.Templates(ctx, s.Version, "ko")
	require.NoError(t, err)
	assert.Same(t, res.tpl, again)
}

func TestStore_TemplatesCanceledCallerReturnsWithoutWaitingForLoad(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	store := content.NewStore(pool, clock.System{}, discardLog())
	release := lockTemplates(t, pool)
	defer release()

	callCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	done := make(chan error, 1)
	go func() {
		_, err := store.Templates(callCtx, s.Version, "ko")
		done <- err
	}()
	waitForBlockedQuery(t, pool)
	cancel()
	require.ErrorIs(t, <-done, context.Canceled, "로드가 끝나지 않아도 취소하면 바로 돌아옴")
}

func TestStore_TemplatesLoadErrorIsNotCached(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	store := content.NewStore(pool, clock.System{}, discardLog())

	// 테이블 이름을 잠시 바꿔 조회가 실패하게 합니다.
	_, err = pool.Exec(ctx, "ALTER TABLE content_templates RENAME TO content_templates_moved")
	require.NoError(t, err)
	_, err = store.Templates(ctx, s.Version, "ko")
	require.Error(t, err)
	_, err = pool.Exec(ctx, "ALTER TABLE content_templates_moved RENAME TO content_templates")
	require.NoError(t, err)

	got, err := store.Templates(ctx, s.Version, "ko")
	require.NoError(t, err, "오류는 캐시하지 않아 다음 호출이 다시 시도")
	_, ok := got.Body("daily.guide", "k", "1")
	assert.True(t, ok)
}

func TestReactions_SelectionDeleteIsRestricted(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)

	var accountID string
	require.NoError(t, pool.QueryRow(ctx, "INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&accountID))
	var selectionID int64
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, '2026-10-16', 'daily.guide', decode(repeat('ab', 32), 'hex'), 'k', '1', $2) RETURNING id`, accountID, s.Version).Scan(&selectionID))
	_, err = pool.Exec(ctx, "INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'like')", selectionID)
	require.NoError(t, err)

	_, err = pool.Exec(ctx, "DELETE FROM daily_selections WHERE id = $1", selectionID)
	assert.Error(t, err, "반응이 있는 선택 기록은 지울 수 없음")
}

func TestReactions_OneActivePerSelection(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)

	var accountID string
	require.NoError(t, pool.QueryRow(ctx, "INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&accountID))
	var selectionID int64
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, '2026-10-16', 'daily.guide', decode(repeat('ab', 32), 'hex'), 'k', '1', $2) RETURNING id`, accountID, s.Version).Scan(&selectionID))

	_, err = pool.Exec(ctx, "INSERT INTO reactions (selection_id, reaction, deleted_at) VALUES ($1, 'like', now())", selectionID)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, "INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'dislike')", selectionID)
	require.NoError(t, err, "soft delete된 행과 활성 행 하나는 함께 있을 수 있음")

	_, err = pool.Exec(ctx, "INSERT INTO reactions (selection_id, reaction) VALUES ($1, 'like')", selectionID)
	var pgErr *pgconn.PgError
	require.ErrorAs(t, err, &pgErr, "활성 행 두 개는 unique 위반")
	assert.Equal(t, "23505", pgErr.Code)
}

func TestStore_SlotsByVersion(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	changed := maps.Clone(testSlots)
	changed[guideSlot] = seed.Slot{ID: guideSlot, Rotation: seed.RotationNone, Vocative: true}
	old, next := testSeed(t, ""), testSeedWithSlots(t, changed, "")
	require.NotEqual(t, old.Version, next.Version, "슬롯 명세가 다르면 버전이 다름")
	for _, s := range []seed.Seed{old, next} {
		_, err := content.Apply(ctx, pool, s)
		require.NoError(t, err)
	}
	store := content.NewStore(pool, clock.System{}, discardLog())

	got, err := store.Slots(ctx, old.Version)
	require.NoError(t, err)
	assert.Equal(t, old.Slots, got, "Apply가 넣은 옛 버전 명세")
	got, err = store.Slots(ctx, next.Version)
	require.NoError(t, err)
	assert.Equal(t, next.Slots, got)

	// 문장 틀은 같은 버전의 명세를 함께 돌려줍니다.
	tpl, err := store.Templates(ctx, old.Version, "ko")
	require.NoError(t, err)
	guide, ok := tpl.Slot(guideSlot)
	require.True(t, ok)
	assert.Equal(t, seed.RotationVariant, guide.Rotation)
	tpl, err = store.Templates(ctx, next.Version, "ko")
	require.NoError(t, err)
	guide, ok = tpl.Slot(guideSlot)
	require.True(t, ok)
	assert.True(t, guide.Vocative)
	_, ok = tpl.Slot("nope")
	assert.False(t, ok)

	_, err = store.Slots(ctx, "missing")
	assert.ErrorContains(t, err, "missing", "없는 버전은 오류")
}

// 근거 문장 슬롯이 명세에 없으면 그 버전 명세를 처음 읽을 때 한 번만 Error 로그를 남깁니다.
func TestStore_SlotsLogsMissingEvidenceSlotsOncePerVersion(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	withBasis := maps.Clone(testSlots)
	withBasis["evidence.basis"] = seed.Slot{ID: "evidence.basis"}
	complete := maps.Clone(withBasis)
	complete["explain.today_reason"] = seed.Slot{ID: "explain.today_reason"}
	complete["evidence.source"] = seed.Slot{ID: "evidence.source"}
	partial, full := testSeedWithSlots(t, withBasis, ""), testSeedWithSlots(t, complete, "")
	for _, s := range []seed.Seed{partial, full} {
		_, err := content.Apply(ctx, pool, s)
		require.NoError(t, err)
	}
	var logs bytes.Buffer
	store := content.NewStore(pool, clock.System{}, slog.New(slog.NewTextHandler(&logs, nil)))

	for range 2 {
		_, err := store.Templates(ctx, partial.Version, "ko")
		require.NoError(t, err)
		_, err = store.Templates(ctx, partial.Version, "en")
		require.NoError(t, err)
	}
	out := logs.String()
	assert.Equal(t, 2, strings.Count(out, "level=ERROR"), out)
	assert.Contains(t, out, "slot=explain.today_reason")
	assert.Contains(t, out, "slot=evidence.source")
	assert.NotContains(t, out, "slot=evidence.basis")

	logs.Reset()
	_, err := store.Slots(ctx, full.Version)
	require.NoError(t, err)
	assert.Empty(t, logs.String(), "근거 슬롯이 모두 있으면 로그 없음")
}

// daily_selections.birth_hash는 익명화 때 비우므로 NULL을 받고, 값이 있으면 32바이트여야 합니다.
func TestSelections_BirthHashNullableButSized(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	var accountID string
	require.NoError(t, pool.QueryRow(ctx, "INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&accountID))
	insert := `INSERT INTO daily_selections (account_id, date, slot, birth_hash, message_key, variant, seed_version)
		VALUES ($1, '2026-10-16', 'daily.guide', $2, 'k', '1', $3)`

	_, err = pool.Exec(ctx, insert, accountID, nil, s.Version)
	require.NoError(t, err, "NULL은 허용")
	_, err = pool.Exec(ctx, insert, accountID, nil, s.Version)
	require.NoError(t, err, "NULL끼리는 unique에 걸리지 않음(익명화한 행)")

	_, err = pool.Exec(ctx, insert, accountID, make([]byte, 31), s.Version)
	var pgErr *pgconn.PgError
	require.ErrorAs(t, err, &pgErr, "31바이트는 거부")
	assert.Equal(t, "daily_selections_birth_hash_len", pgErr.ConstraintName)

	_, err = pool.Exec(ctx, insert, accountID, make([]byte, 32), s.Version)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, insert, accountID, make([]byte, 32), s.Version)
	require.ErrorAs(t, err, &pgErr, "값이 있으면 unique 유지")
	assert.Equal(t, "23505", pgErr.Code)
}
