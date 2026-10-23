package account

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/june20516/myungli-diary/server/internal/account/accountdb"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// SQLStateAccountDeleted는 지운 계정에 개인 데이터 행을 쓰려 할 때 DB trigger가 내는 SQLSTATE입니다(migration 00015).
// 삭제 트랜잭션이 계정 행을 잡은 동안 시작한 쓰기는 잠금을 기다렸다가 이 오류로 실패합니다.
const SQLStateAccountDeleted = "MD001"

// IsAccountDeletedError는 err가 지운 계정에 쓰려다 trigger에 막힌 DB 오류인지 알려 줍니다.
func IsAccountDeletedError(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == SQLStateAccountDeleted
}

// Revoker는 계정 삭제가 commit된 뒤 허가 취소 대기 행을 한 번씩 시도합니다(S106).
// 실패는 대기 행에 남아 재시도 job이 다시 시도하므로 오류를 돌려주지 않습니다.
// 받는 ctx는 취소·마감이 없으므로(commit 뒤 뒷정리) 구현이 외부 호출마다 자기 timeout을 둬야 합니다.
type Revoker interface {
	Attempt(ctx context.Context, ids []int64)
}

// deleteStep은 계정 삭제에서 표 하나를 지우는 단계입니다.
type deleteStep struct {
	what string
	run  func(ctx context.Context, accountID uuid.UUID) error
}

// deleteSteps는 지우는 순서입니다. FK가 모두 ON DELETE RESTRICT라 자식부터 지우고,
// 캐시는 프로필과 문장 선택 기록의 출생 해시로 찾으므로 맨 먼저, Apple 웹 로그인 기록은 인증 계정의 subject로
// 찾으므로 인증 계정보다 먼저 지웁니다.
func deleteSteps(q *accountdb.Queries) []deleteStep {
	return []deleteStep{
		{"차트 캐시", q.DeleteChartCacheByAccount},
		{"데일리 캐시", q.DeleteDailyCacheByAccount},
		{"월 캐시", q.DeleteMonthCacheByAccount},
		{"반응", q.DeleteReactionsByAccount},
		{"문장 선택 기록", q.DeleteDailySelectionsByAccount},
		{"순환 상태", q.DeleteRotationStateByAccount},
		{"일기", q.DeleteDiariesByAccount},
		{"날짜 기록", q.DeleteDiaryDaysByAccount},
		{"일정", q.DeleteSchedulesByAccount},
		{"멱등 키", q.DeleteIdempotencyKeysByAccount},
		{"합치기 토큰", q.DeleteMergeTicketsByAccount},
		{"refresh token", q.DeleteRefreshTokensByAccount},
		{"약관 동의", q.DeleteConsentsByAccount},
		{"Apple 웹 로그인 기록", q.DeleteAppleWebLoginsByAccount},
		{"인증 계정", q.DeleteIdentitiesByAccount},
		{"프로필", q.DeleteProfileByAccount},
	}
}

// DeleteAccountTx는 tx 안에서 계정의 개인 데이터를 지우고 계정을 deleted 껍데기로 남깁니다(S105).
// 지우기 전에 카카오·Apple 허가 취소 대기 행을 넣고(S106) 반응을 문장별 집계에 더합니다(D57).
// 돌려주는 id는 넣은 대기 행이며, 호출자가 commit한 뒤 Revoker.Attempt에 넘깁니다.
// 이미 deleted면 아무것도 하지 않고 (nil, nil)이고, 계정이 없으면 ErrNotFound입니다.
// 계정 합치기는 B를 지울 때 같은 트랜잭션 안에서 이 함수를 그대로 부릅니다(D85 ④).
func DeleteAccountTx(ctx context.Context, tx pgx.Tx, accountID uuid.UUID, now time.Time) ([]int64, error) {
	revocationIDs, _, err := deleteAccountTx(ctx, tx, accountID, now)
	return revocationIDs, err
}

// deleteAccountTx는 DeleteAccountTx이며, 이번 호출이 실제로 지웠는지(이미 deleted면 false)도 돌려줍니다.
func deleteAccountTx(ctx context.Context, tx pgx.Tx, accountID uuid.UUID, now time.Time) (revocationIDs []int64, deleted bool, err error) {
	q := accountdb.New(tx)

	status, err := q.LockAccountForDelete(ctx, accountID)
	if err != nil {
		return nil, false, notFoundOr(err, "삭제할 계정 잠금")
	}
	if Status(status) == StatusDeleted {
		return nil, false, nil
	}

	revocationIDs, err = q.QueueProviderRevocations(ctx, accountdb.QueueProviderRevocationsParams{
		Now: now, AccountID: accountID,
	})
	if err != nil {
		return nil, false, fmt.Errorf("허가 취소 대기 행 저장: %w", err)
	}
	if err := q.TallyReactions(ctx, accountID); err != nil {
		return nil, false, fmt.Errorf("반응 집계: %w", err)
	}
	for _, step := range deleteSteps(q) {
		if err := step.run(ctx, accountID); err != nil {
			return nil, false, fmt.Errorf("%s 삭제: %w", step.what, err)
		}
	}
	if err := q.MarkAccountDeleted(ctx, accountdb.MarkAccountDeletedParams{DeletedAt: now, ID: accountID}); err != nil {
		return nil, false, fmt.Errorf("계정 상태 변경: %w", err)
	}
	return revocationIDs, true, nil
}

// Delete는 계정을 바로 지웁니다(deleteMe). commit 뒤 허가 취소 대기 행을 한 번씩 시도하며, 그 결과와 상관없이 성공입니다.
// 이미 지운 계정이면 아무것도 하지 않고 nil이고, 계정이 없으면 ErrNotFound입니다.
func (s *Service) Delete(ctx context.Context, id uuid.UUID) error {
	var (
		revocationIDs []int64
		deleted       bool
	)
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		var err error
		revocationIDs, deleted, err = deleteAccountTx(ctx, tx, id, s.clk.Now())
		return err
	})
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return err
		}
		return fmt.Errorf("계정 삭제: %w", err)
	}
	if deleted {
		s.logger.InfoContext(ctx, "계정 삭제", "accountId", id, "revocations", len(revocationIDs))
	}

	if len(revocationIDs) > 0 {
		// 이미 commit된 삭제의 뒷정리이므로, 클라이언트가 응답 전에 연결을 끊어 ctx가 취소돼도 끝까지 수행합니다.
		s.revoker.Attempt(context.WithoutCancel(ctx), revocationIDs)
	}
	return nil
}
