// Package content는 콘텐츠 시드를 DB에 적재하고, 실행 중 문장 틀을 읽는 저장소를 둡니다.
package content

import (
	"context"
	"errors"
	"fmt"
	"sync"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/content/contentdb"
	"github.com/june20516/myungli-diary/server/internal/content/render"
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
			for _, t := range s.Templates {
				if err := q.InsertTemplate(ctx, contentdb.InsertTemplateParams{
					SeedVersion: s.Version, Slot: t.Slot, Key: t.Key, Variant: t.Variant, Lang: t.Lang, Body: t.Body,
				}); err != nil {
					return fmt.Errorf("문장 틀 기록: %w", err)
				}
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
	// Body는 (slot, key, variant)의 원문을 돌려줍니다. 없으면 false입니다.
	Body(slot, key, variant string) (string, bool)
	// ValueName은 render.Names를 만족합니다.
	ValueName(category, value string) (string, bool)
}

var _ render.Names = Templates(nil)

type templateID struct{ slot, key, variant string }

// templates는 Templates의 메모리 구현입니다.
type templates struct {
	bodies map[templateID]string
}

func (t *templates) Body(slot, key, variant string) (string, bool) {
	body, ok := t.bodies[templateID{slot, key, variant}]
	return body, ok
}

func (t *templates) ValueName(category, value string) (string, bool) {
	return t.Body(valueNameSlot, category+"."+value, seed.VariantSingle)
}

type cacheKey struct{ version, lang string }

// Store는 DB의 콘텐츠 시드를 읽습니다. 문장 틀은 (버전, 언어)별로 메모리에 한 번만 불러 둡니다.
type Store struct {
	queries *contentdb.Queries

	mu    sync.Mutex
	cache map[cacheKey]*templates
}

// NewStore는 pool을 쓰는 Store를 만듭니다.
func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{queries: contentdb.New(pool), cache: map[cacheKey]*templates{}}
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
func (s *Store) Templates(ctx context.Context, version, lang string) (Templates, error) {
	key := cacheKey{version, lang}
	s.mu.Lock()
	defer s.mu.Unlock()
	if t, ok := s.cache[key]; ok {
		return t, nil
	}
	rows, err := s.queries.ListTemplates(ctx, contentdb.ListTemplatesParams{SeedVersion: version, Lang: lang})
	if err != nil {
		return nil, fmt.Errorf("문장 틀 조회: %w", err)
	}
	t := &templates{bodies: make(map[templateID]string, len(rows))}
	for _, r := range rows {
		t.bodies[templateID{r.Slot, r.Key, r.Variant}] = r.Body
	}
	s.cache[key] = t
	return t, nil
}
