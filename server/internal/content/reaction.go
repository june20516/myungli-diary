package content

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	"github.com/june20516/myungli-diary/server/internal/content/contentdb"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// PutReaction은 선택 기록 selectionID에 반응을 남깁니다. 멱등입니다.
//   - 같은 값의 활성 반응이 있으면 그대로 둡니다(처음 남긴 시각 유지).
//   - 다른 값의 활성 반응이 있으면 그 행을 soft delete하고 새 행을 넣습니다(바뀐 이력을 행으로 남깁니다).
//   - 활성 반응이 없으면 새 행을 넣습니다. soft delete된 행은 되살리지 않습니다.
//
// 같은 선택 기록의 동시 요청은 선택 기록 행 lock으로 차례로 처리합니다. 그래서 둘 다 성공하고, 나중에 처리한 값 하나만
// 활성으로 남으며 앞 값은 soft delete 이력이 됩니다(lock이 없으면 둘 다 "활성 없음"을 보고 넣어 한쪽 값이 조용히 빠집니다).
// 선택 기록이 없으면 ErrSelectionNotFound입니다.
//
// 선택 기록이 호출자 계정의 것인지는 호출자가 SelectionFor로 확인합니다. 트랜잭션이 다시 실행될 수 있어 fn은 멱등입니다.
func (s *Store) PutReaction(ctx context.Context, selectionID int64, reaction string) error {
	now := s.clock.Now()
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := contentdb.New(tx)
		locked, err := q.LockSelection(ctx, selectionID)
		if err != nil {
			return fmt.Errorf("선택 기록 잠금: %w", err)
		}
		if locked == 0 {
			return ErrSelectionNotFound
		}
		current, err := q.GetActiveReaction(ctx, selectionID)
		switch {
		case err == nil && current == reaction:
			return nil
		case err == nil:
			if err := q.SoftDeleteReactions(ctx, contentdb.SoftDeleteReactionsParams{SelectionID: selectionID, DeletedAt: &now}); err != nil {
				return fmt.Errorf("옛 반응 취소: %w", err)
			}
		case !errors.Is(err, pgx.ErrNoRows):
			return fmt.Errorf("반응 조회: %w", err)
		}
		if err := q.InsertReaction(ctx, contentdb.InsertReactionParams{SelectionID: selectionID, Reaction: reaction, CreatedAt: now}); err != nil {
			return fmt.Errorf("반응 기록: %w", err)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("반응 저장: %w", err)
	}
	return nil
}

// DeleteReaction은 선택 기록 selectionID의 활성 반응을 soft delete합니다. 활성 반응이 없어도 성공합니다(멱등).
func (s *Store) DeleteReaction(ctx context.Context, selectionID int64) error {
	now := s.clock.Now()
	if err := s.queries.SoftDeleteReactions(ctx, contentdb.SoftDeleteReactionsParams{SelectionID: selectionID, DeletedAt: &now}); err != nil {
		return fmt.Errorf("반응 취소: %w", err)
	}
	return nil
}

// ActiveReactions는 선택 기록 ID들의 활성 반응을 한 번에 읽어 선택 기록 ID -> 반응으로 돌려줍니다.
// 반응이 없는 기록은 키가 없습니다.
func (s *Store) ActiveReactions(ctx context.Context, selectionIDs []int64) (map[int64]string, error) {
	out := map[int64]string{}
	if len(selectionIDs) == 0 {
		return out, nil
	}
	rows, err := s.queries.ListActiveReactions(ctx, selectionIDs)
	if err != nil {
		return nil, fmt.Errorf("반응 조회: %w", err)
	}
	for _, r := range rows {
		out[r.SelectionID] = r.Reaction
	}
	return out, nil
}
