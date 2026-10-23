package auth

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/secretbox"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const (
	// revocationGiveUpAfter는 대기 행이 만들어진 뒤 이 시간이 지나면 시도를 포기하는 기한입니다(S106).
	revocationGiveUpAfter = 30 * 24 * time.Hour
	// revocationBaseDelay는 첫 실패 뒤 기다리는 시간이고, 실패마다 두 배가 되어 revocationMaxDelay에서 멈춥니다.
	revocationBaseDelay = time.Minute
	revocationMaxDelay  = 24 * time.Hour
	// revocationCallTimeout은 제공자 외부 호출 하나에 주는 최대 시간입니다.
	// Attempt가 받는 context에는 마감이 없으므로 여기서 직접 둡니다.
	revocationCallTimeout = 15 * time.Second
	// retryDueLimit은 RetryDue 한 번이 처리하는 대기 행의 최대 수입니다. 남은 행은 다음 실행이 처리합니다.
	retryDueLimit = 100
)

// AppleRevoker는 Apple refresh token을 revoke합니다. *provider.Apple이 만족합니다.
type AppleRevoker interface {
	Revoke(ctx context.Context, refreshToken, clientID string) error
}

// RevocationAttempter는 허가 취소 대기 행을 id로 한 번씩 시도합니다. account.Revoker와 같은 모양이며 *Revocations가 만족합니다.
type RevocationAttempter interface {
	Attempt(ctx context.Context, ids []int64)
}

// Revocations는 카카오·Apple 허가 취소 대기 행(provider_revocations)을 시도하고 재시도합니다(S106).
// LINE·Google은 app SDK가 허가를 취소하므로(S100) 대기 행이 없습니다. 여러 goroutine과 여러 프로세스에서 동시에 써도 안전합니다.
type Revocations struct {
	pool   *pgxpool.Pool
	kakao  KakaoUnlinker
	apple  AppleRevoker
	box    *secretbox.Box
	clock  clock.Clock
	logger *slog.Logger
}

// NewRevocations는 Revocations를 만듭니다. logger가 nil이면 아무것도 남기지 않습니다.
func NewRevocations(pool *pgxpool.Pool, kakao KakaoUnlinker, apple AppleRevoker, box *secretbox.Box, clk clock.Clock, logger *slog.Logger) *Revocations {
	if logger == nil {
		logger = slog.New(slog.DiscardHandler)
	}
	return &Revocations{pool: pool, kakao: kakao, apple: apple, box: box, clock: clk, logger: logger}
}

// QueueRevocationTx는 지우는 인증 계정 한 행의 허가 취소 대기 행을 같은 트랜잭션에 넣습니다.
// 카카오와, 저장한 token이 있는 Apple만 넣고, 그 밖(LINE·Google·테스트, token 없는 Apple)은 ok=false입니다.
// 계정 삭제의 QueueProviderRevocations와 같은 조건입니다. now는 대기 행의 created_at·next_attempt_at입니다.
func QueueRevocationTx(ctx context.Context, q *authdb.Queries, identity authdb.DeleteIdentityRow, now time.Time) (id int64, ok bool, err error) {
	params := authdb.QueueRevocationParams{
		Provider:   identity.Provider,
		IdentityID: identity.ID,
		Now:        now,
	}
	switch identity.Provider {
	case providerKakao:
		params.Subject = pgtype.Text{String: identity.Subject, Valid: true}
	case providerApple:
		if identity.AppleRefreshToken == nil {
			return 0, false, nil
		}
		params.AppleRefreshToken = identity.AppleRefreshToken
		params.AppleTokenKeyID = identity.AppleTokenKeyID
		params.AppleClientID = identity.AppleClientID
	default:
		return 0, false, nil
	}
	id, err = q.QueueRevocation(ctx, params)
	if err != nil {
		return 0, false, fmt.Errorf("허가 취소 대기 행 추가: %w", err)
	}
	return id, true, nil
}

// Attempt는 아직 시도하지 않은(attempts = 0) 대기 행을 id로 한 번씩 시도합니다(account.Revoker).
// 이미 실패 처리된 행은 건드리지 않고 RetryDue에 맡깁니다.
// 실패는 대기 행에 남겨 RetryDue가 다시 시도하므로 오류를 돌려주지 않습니다.
// 다른 곳이 이미 잡고 있거나 이미 없는 행은 건너뜁니다.
func (r *Revocations) Attempt(ctx context.Context, ids []int64) {
	for _, id := range ids {
		_, err := r.handleOne(ctx, func(q *authdb.Queries) (authdb.ProviderRevocation, error) {
			return q.LockRevocation(ctx, id)
		})
		if err != nil {
			r.logger.WarnContext(ctx, "허가 취소 대기 행 처리 실패", "id", id, "error", err)
		}
	}
}

// RetryDue는 next_attempt_at이 된 대기 행을 한 행씩 한 트랜잭션에서 잡아(FOR UPDATE SKIP LOCKED) 시도합니다.
// 겹쳐 도는 job은 같은 행을 부르지 않습니다. 한 번에 최대 retryDueLimit행을 처리하고,
// 시도했거나(성공·실패) 포기해 지운 행의 수를 돌려줍니다. 외부 호출이 실패해도 오류가 아니며 행에 남깁니다.
func (r *Revocations) RetryDue(ctx context.Context) (attempted int, err error) {
	for attempted < retryDueLimit {
		now := r.clock.Now()
		handled, err := r.handleOne(ctx, func(q *authdb.Queries) (authdb.ProviderRevocation, error) {
			return q.LockDueRevocation(ctx, now)
		})
		if err != nil {
			return attempted, err
		}
		if !handled {
			return attempted, nil
		}
		attempted++
	}
	return attempted, nil
}

// handleOne은 lock이 돌려준 대기 행 하나를 한 트랜잭션에서 처리합니다.
// 외부 호출(최대 revocationCallTimeout) 동안 행 잠금과 DB 연결 하나를 쥡니다. 겹쳐 도는 Attempt·RetryDue가 많으면
// 그만큼 연결이 묶이는데 pgxpool 기본 MaxConns는 작으므로, 운영에서 필요하면 DATABASE_URL의 pool_max_conns를 올립니다.
// 잠글 행이 없으면 handled=false입니다.
func (r *Revocations) handleOne(ctx context.Context, lock func(q *authdb.Queries) (authdb.ProviderRevocation, error)) (handled bool, err error) {
	err = postgres.InTx(ctx, r.pool, func(tx pgx.Tx) error {
		handled = false
		q := authdb.New(tx)
		row, err := lock(q)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("대기 행 잠금: %w", err)
		}
		handled = true
		return r.process(ctx, q, row)
	})
	if err != nil {
		return false, fmt.Errorf("허가 취소 처리: %w", err)
	}
	return handled, nil
}

// process는 잠근 대기 행을 처리합니다. 30일(기한)이 지났으면 부르지 않고 지우고, 아니면 제공자를 불러
// 성공하면 지우고 실패하면 다음 시각을 정합니다. 다음 시각은 기한을 넘지 않으며, 기한 시각의 시도가 실패하면
// 마지막 시도로 보고 지웁니다. 로그에는 id·provider·결과만 남깁니다.
func (r *Revocations) process(ctx context.Context, q *authdb.Queries, row authdb.ProviderRevocation) error {
	now := r.clock.Now()
	deadline := row.CreatedAt.Add(revocationGiveUpAfter)
	if now.After(deadline) {
		r.logger.ErrorContext(ctx, "허가 취소를 포기함", "id", row.ID, "provider", row.Provider)
		return r.deleteRow(ctx, q, row.ID)
	}
	relinked, err := r.kakaoRelinked(ctx, q, row)
	if err != nil {
		return err
	}
	if relinked {
		// 같은 카카오 사용자가 다시 가입했습니다. unlink는 사용자 단위라 새 계정의 연결까지 끊으므로 부르지 않습니다.
		r.logger.InfoContext(ctx, "다시 가입한 카카오 사용자라 허가 취소 생략", "id", row.ID, "provider", row.Provider)
		return r.deleteRow(ctx, q, row.ID)
	}

	callCtx, cancel := context.WithTimeout(ctx, revocationCallTimeout)
	defer cancel()
	if err := r.revoke(callCtx, row); err != nil {
		if ctx.Err() != nil {
			// 호출한 쪽이 멈춘 것이라 실패로 세지 않고 그대로 둡니다.
			return ctx.Err()
		}
		attempts := row.Attempts + 1
		r.logger.WarnContext(ctx, "허가 취소 실패", "id", row.ID, "provider", row.Provider,
			"attempts", attempts, "reason", revocationFailureReason(err))
		if !now.Before(deadline) {
			r.logger.ErrorContext(ctx, "허가 취소를 포기함", "id", row.ID, "provider", row.Provider)
			return r.deleteRow(ctx, q, row.ID)
		}
		next := now.Add(revocationBackoff(attempts))
		if next.After(deadline) {
			next = deadline
		}
		if err := q.ScheduleRevocationRetry(ctx, authdb.ScheduleRevocationRetryParams{
			Attempts:      attempts,
			NextAttemptAt: next,
			ID:            row.ID,
		}); err != nil {
			return fmt.Errorf("다음 시도 시각 기록: %w", err)
		}
		return nil
	}
	r.logger.InfoContext(ctx, "허가 취소 완료", "id", row.ID, "provider", row.Provider)
	return r.deleteRow(ctx, q, row.ID)
}

// kakaoRelinked는 카카오 대기 행의 subject로 지금 인증 계정이 있는지(같은 사용자가 다시 가입했는지) 알려 줍니다.
// Apple 대기 행은 subject가 없고 token 단위로 취소하므로 해당하지 않습니다.
func (r *Revocations) kakaoRelinked(ctx context.Context, q *authdb.Queries, row authdb.ProviderRevocation) (bool, error) {
	if row.Provider != providerKakao {
		return false, nil
	}
	exists, err := q.IdentityExists(ctx, authdb.IdentityExistsParams{Provider: providerKakao, Subject: row.Subject.String})
	if err != nil {
		return false, fmt.Errorf("카카오 인증 계정 확인: %w", err)
	}
	return exists, nil
}

func (r *Revocations) deleteRow(ctx context.Context, q *authdb.Queries, id int64) error {
	if err := q.DeleteRevocation(ctx, id); err != nil {
		return fmt.Errorf("대기 행 삭제: %w", err)
	}
	return nil
}

// revocationBackoff는 attempts번째 실패 뒤 기다리는 시간입니다: 1분 x 2^(attempts-1), 최대 1일.
func revocationBackoff(attempts int32) time.Duration {
	delay := revocationBaseDelay
	for i := int32(1); i < attempts; i++ {
		delay *= 2
		if delay >= revocationMaxDelay {
			return revocationMaxDelay
		}
	}
	return delay
}

// revoke는 대기 행 하나의 제공자 허가를 취소하는 외부 호출을 합니다. 이미 끊긴 경우는 성공입니다.
//
//   - 카카오: 앱과의 연결을 끊습니다(unlink). 이미 앱과 연결되지 않은 사용자(ErrKakaoNotLinked)는 성공입니다.
//   - Apple: 저장한 refresh token을 복호화해 revoke합니다. 저장한 token이 없거나 invalid_grant(ErrTokenInvalid)면 성공입니다.
func (r *Revocations) revoke(ctx context.Context, row authdb.ProviderRevocation) error {
	switch row.Provider {
	case providerKakao:
		err := r.kakao.Unlink(ctx, row.Subject.String)
		if err == nil || errors.Is(err, provider.ErrKakaoNotLinked) {
			return nil
		}
		return fmt.Errorf("카카오 unlink: %w", err)
	case providerApple:
		if row.AppleRefreshToken == nil {
			return nil
		}
		plain, err := r.box.Open(row.AppleRefreshToken, row.AppleTokenKeyID.String, row.IdentityID[:])
		if err != nil {
			return fmt.Errorf("%w: apple refresh token 복호화: %w", errDecrypt, err)
		}
		err = r.apple.Revoke(ctx, string(plain), row.AppleClientID.String)
		if err == nil || errors.Is(err, provider.ErrTokenInvalid) {
			return nil
		}
		return fmt.Errorf("apple revoke: %w", err)
	default:
		return fmt.Errorf("대기 행 %d: 알 수 없는 제공자 %q", row.ID, row.Provider)
	}
}

// errDecrypt는 저장한 Apple refresh token을 복호화하지 못했음을 나타냅니다. 실패 사유 분류에 씁니다.
var errDecrypt = errors.New("decrypt failed")

// revocationFailureReason은 허가 취소 실패를 로그용 사유로 분류합니다. 원인 문구는 담지 않습니다.
func revocationFailureReason(err error) string {
	switch {
	case errors.Is(err, provider.ErrUnavailable):
		return "unavailable"
	case errors.Is(err, errDecrypt):
		return "decrypt"
	default:
		return "other"
	}
}
