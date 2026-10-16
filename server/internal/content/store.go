// Package content는 콘텐츠 시드를 DB에 적재하고, 실행 중 문장 틀을 읽는 저장소를 둡니다.
package content

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/sync/singleflight"

	"github.com/june20516/myungli-diary/server/internal/content/contentdb"
	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/seed"
)

// ErrNoActiveSeed는 활성 시드가 하나도 없을 때(seed 명령이 아직 돌지 않았을 때) 돌려줍니다.
var ErrNoActiveSeed = errors.New("활성 콘텐츠 시드가 없습니다")

// valueNameSlot은 "<범주>.<값>" 키로 값의 표시 이름을 담은 슬롯입니다.
const valueNameSlot = "glossary.value_name"

// seedLockID는 동시에 뜬 인스턴스가 시드를 한 번에 하나씩만 적재하도록 거는 advisory lock의 번호입니다.
const seedLockID int64 = 0x636f6e74656e74 // "content"의 ASCII

// Apply는 시드를 DB에 적재하고 활성 시드로 바꿉니다. 모두 한 트랜잭션입니다.
// 같은 버전이 이미 있으면 문장 틀은 다시 넣지 않고 활성으로만 바꾸며 applied는 false입니다.
// 옛 버전의 행은 지우지 않습니다(옛 선택 기록이 가리키기 때문입니다).
// 트랜잭션이 다시 실행될 수 있으므로 fn은 멱등입니다.
func Apply(ctx context.Context, pool *pgxpool.Pool, s seed.Seed) (applied bool, err error) {
	err = postgres.InTx(ctx, pool, func(tx pgx.Tx) error {
		applied = false
		if _, err := tx.Exec(ctx, "SELECT pg_advisory_xact_lock($1)", seedLockID); err != nil {
			return fmt.Errorf("시드 잠금: %w", err)
		}
		q := contentdb.New(tx)
		inserted, err := q.InsertSeed(ctx, s.Version)
		if err != nil {
			return fmt.Errorf("시드 버전 기록: %w", err)
		}
		if inserted > 0 {
			// 한 번에 넣습니다. 시드 안에 (slot, key, variant, lang)이 겹치는 행이 있으면 PK 위반으로 오류가 됩니다.
			rows := make([][]any, len(s.Templates))
			for i, t := range s.Templates {
				rows[i] = []any{s.Version, t.Slot, t.Key, t.Variant, t.Lang, t.Body}
			}
			if _, err := tx.CopyFrom(ctx, pgx.Identifier{"content_templates"},
				[]string{"seed_version", "slot", "key", "variant", "lang", "body"}, pgx.CopyFromRows(rows)); err != nil {
				return fmt.Errorf("문장 틀 기록: %w", err)
			}
			hanja := make([][]any, 0, len(s.Hanja))
			for term, h := range s.Hanja {
				hanja = append(hanja, []any{s.Version, term, h})
			}
			if _, err := tx.CopyFrom(ctx, pgx.Identifier{"content_hanja"},
				[]string{"seed_version", "term", "hanja"}, pgx.CopyFromRows(hanja)); err != nil {
				return fmt.Errorf("한자 표기 기록: %w", err)
			}
			applied = true
		}
		// 부분 unique 인덱스(활성은 하나)를 지키려고 옛 활성을 먼저 끕니다.
		if err := q.DeactivateSeeds(ctx, s.Version); err != nil {
			return fmt.Errorf("옛 시드 비활성화: %w", err)
		}
		if err := q.ActivateSeed(ctx, s.Version); err != nil {
			return fmt.Errorf("시드 활성화: %w", err)
		}
		return nil
	})
	if err != nil {
		return false, err
	}
	return applied, nil
}

// Templates는 한 시드 버전·한 언어의 문장 틀 모음입니다. 만들어진 뒤 바뀌지 않아 동시에 읽어도 안전합니다.
type Templates interface {
	// Lang은 이 문장 틀 모음의 언어(ko, en, ja)입니다. 렌더 규칙(호칭 덩어리, 조사)이 언어마다 달라 렌더에 필요합니다.
	Lang() string
	// Body는 (slot, key, variant)의 원문을 돌려줍니다. 없으면 false입니다.
	Body(slot, key, variant string) (string, bool)
	// ValueName은 render.Names를 만족합니다.
	ValueName(category, value string) (string, bool)
}

var _ render.Names = Templates(nil)

type templateID struct{ slot, key, variant string }

// templates는 Templates의 메모리 구현입니다.
type templates struct {
	lang   string
	bodies map[templateID]string
}

func (t *templates) Lang() string { return t.lang }

func (t *templates) Body(slot, key, variant string) (string, bool) {
	body, ok := t.bodies[templateID{slot, key, variant}]
	return body, ok
}

func (t *templates) ValueName(category, value string) (string, bool) {
	return t.Body(valueNameSlot, category+"."+value, seed.VariantSingle)
}

// loadTimeout은 문장 틀 한 묶음을 DB에서 읽는 데 주는 최대 시간입니다.
// 로드는 호출자 ctx와 분리돼 있어 호출자가 취소해도 이어지므로, DB가 멈춰도 고루틴이 영원히 남지 않게 상한을 둡니다.
const loadTimeout = 30 * time.Second

type cacheKey struct{ version, lang string }

// Store는 DB의 콘텐츠 시드를 읽고 문장 선택을 기록합니다. 문장 틀은 (버전, 언어)별로 메모리에 한 번만 불러 둡니다.
type Store struct {
	// pool은 선택 기록처럼 트랜잭션이 필요한 작업에 씁니다.
	pool    *pgxpool.Pool
	queries *contentdb.Queries
	// clock은 반응 soft delete 시각처럼 DB에 남기는 시각을 정합니다.
	clock clock.Clock

	// mu는 cache 맵만 지킵니다. DB 조회 동안에는 잡지 않아서, 한 키의 느린 로드가 다른 키를 막지 않습니다.
	mu    sync.Mutex
	cache map[cacheKey]*templates
	// loads는 같은 키를 동시에 요청한 호출을 DB 조회 한 번으로 합칩니다.
	loads singleflight.Group

	// glossaryMu는 glossaries 맵만 지킵니다.
	glossaryMu sync.Mutex
	// glossaries는 (버전, 언어)별로 만든 용어 사전입니다. 문장 틀과 같은 이유로 무효화할 일이 없습니다.
	glossaries map[cacheKey]Glossary
}

// NewStore는 pool과 clk를 쓰는 Store를 만듭니다.
func NewStore(pool *pgxpool.Pool, clk clock.Clock) *Store {
	return &Store{pool: pool, queries: contentdb.New(pool), clock: clk, cache: map[cacheKey]*templates{}, glossaries: map[cacheKey]Glossary{}}
}

// Active는 활성 시드 버전을 돌려줍니다. 없으면 ErrNoActiveSeed입니다.
func (s *Store) Active(ctx context.Context) (string, error) {
	version, err := s.queries.GetActiveSeed(ctx)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNoActiveSeed
	}
	if err != nil {
		return "", fmt.Errorf("활성 시드 조회: %w", err)
	}
	return version, nil
}

// Templates는 version·lang의 문장 틀을 돌려줍니다. 한 번 읽은 것은 메모리에 두고 다시 DB를 읽지 않습니다.
// 시드 버전은 내용 지문이라 같은 (version, lang)의 내용은 바뀌지 않으므로 캐시를 무효화할 일이 없습니다.
// 조회 오류는 캐시하지 않아 다음 호출이 다시 시도합니다. 기다리는 중에 ctx가 끝나면 바로 돌아옵니다.
func (s *Store) Templates(ctx context.Context, version, lang string) (Templates, error) {
	key := cacheKey{version, lang}
	if t, ok := s.cached(key); ok {
		return t, nil
	}
	// 로드는 이 호출자의 ctx와 분리합니다. 같은 flight에 합류한 다른 호출자가 있어서,
	// 첫 호출자가 취소해도 로드가 끝까지 가서 캐시를 채워야 하기 때문입니다.
	loadCtx := context.WithoutCancel(ctx)
	ch := s.loads.DoChan(version+"\x00"+lang, func() (any, error) {
		loadCtx, cancel := context.WithTimeout(loadCtx, loadTimeout)
		defer cancel()
		t, err := s.load(loadCtx, key)
		if err != nil {
			return nil, err
		}
		return t, nil
	})
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case res := <-ch:
		if res.Err != nil {
			return nil, res.Err
		}
		t, ok := res.Val.(*templates)
		if !ok {
			return nil, fmt.Errorf("문장 틀 로드 결과 형식이 잘못됐습니다: %T", res.Val)
		}
		return t, nil
	}
}

func (s *Store) cached(key cacheKey) (*templates, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	t, ok := s.cache[key]
	return t, ok
}

// load는 DB에서 문장 틀을 읽어 캐시에 넣습니다. 성공했을 때만 캐시합니다.
func (s *Store) load(ctx context.Context, key cacheKey) (*templates, error) {
	rows, err := s.queries.ListTemplates(ctx, contentdb.ListTemplatesParams{SeedVersion: key.version, Lang: key.lang})
	if err != nil {
		return nil, fmt.Errorf("문장 틀 조회: %w", err)
	}
	t := &templates{lang: key.lang, bodies: make(map[templateID]string, len(rows))}
	for _, r := range rows {
		t.bodies[templateID{r.Slot, r.Key, r.Variant}] = r.Body
	}
	s.mu.Lock()
	s.cache[key] = t
	s.mu.Unlock()
	return t, nil
}
