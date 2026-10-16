package content_test

import (
	"context"
	"sync"
	"time"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/seed"
)

// testSeed는 템플릿 body를 바꿔 서로 다른 Version을 얻는 작은 시드입니다.
func testSeed(t *testing.T, suffix string) seed.Seed {
	t.Helper()
	s := seed.Seed{
		Slots: map[string]seed.Slot{"daily.guide": {ID: "daily.guide", Rotation: seed.RotationVariant}},
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

	version, err := content.NewStore(pool).Active(ctx)
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
	version, err := content.NewStore(pool).Active(ctx)
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

	version, err := content.NewStore(pool).Active(ctx)
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
	store := content.NewStore(pool)

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
	store := content.NewStore(pool)

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
	_, err := content.NewStore(dbtest.New(t)).Active(context.Background())
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

	_, err = content.NewStore(pool).Active(ctx)
	assert.ErrorIs(t, err, content.ErrNoActiveSeed, "실패한 적재는 롤백")
}

func TestStore_TemplatesCanceledWhileLoadingIsNotCached(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	s := testSeed(t, "")
	_, err := content.Apply(ctx, pool, s)
	require.NoError(t, err)
	store := content.NewStore(pool)

	// 다른 트랜잭션이 테이블을 잠가 조회가 끝나지 못하게 합니다.
	tx, err := pool.Begin(ctx)
	require.NoError(t, err)
	_, err = tx.Exec(ctx, "LOCK TABLE content_templates IN ACCESS EXCLUSIVE MODE")
	require.NoError(t, err)

	short, cancel := context.WithTimeout(ctx, 100*time.Millisecond)
	defer cancel()
	_, err = store.Templates(short, s.Version, "ko")
	require.ErrorIs(t, err, context.DeadlineExceeded, "ctx가 끝나면 로드를 기다리지 않고 돌아옴")
	require.NoError(t, tx.Rollback(ctx))

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
