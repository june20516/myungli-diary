package postgres

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// maxTxRetries는 serialization 실패·deadlock으로 트랜잭션을 다시 실행하는 최대 횟수입니다(spec §11.3).
// 처음 실행까지 합쳐 최대 maxTxRetries+1번 실행합니다.
const maxTxRetries = 3

// 다시 실행하면 성공할 수 있는 SQLSTATE입니다.
const (
	sqlStateSerializationFailure = "40001"
	sqlStateDeadlockDetected     = "40P01"
)

// TxBeginner는 트랜잭션을 시작할 수 있는 연결입니다. *pgxpool.Pool과 *pgx.Conn이 만족합니다.
type TxBeginner interface {
	BeginTx(ctx context.Context, txOptions pgx.TxOptions) (pgx.Tx, error)
}

// InTx는 fn을 트랜잭션 하나 안에서 실행합니다.
// fn이 nil을 돌려주면 commit하고, 오류를 돌려주면 rollback한 뒤 그 오류를 그대로 돌려줍니다.
//
// serialization 실패(40001)나 deadlock(40P01)이면 트랜잭션 전체를 처음부터 최대 3번 다시 실행합니다.
// 그래서 fn은 여러 번 불려도 결과가 같아야 합니다. fn 밖의 변수에 결과를 담는다면 fn 첫머리에서 초기화하세요.
// ctx가 끝나면 더 다시 실행하지 않습니다.
func InTx(ctx context.Context, db TxBeginner, fn func(tx pgx.Tx) error) error {
	var err error
	for attempt := 0; attempt <= maxTxRetries; attempt++ {
		err = pgx.BeginTxFunc(ctx, db, pgx.TxOptions{}, fn)
		if !isRetryable(err) || ctx.Err() != nil {
			return err
		}
	}
	return err
}

// isRetryable은 err가 트랜잭션을 다시 실행하면 성공할 수 있는 DB 오류인지 알려 줍니다.
func isRetryable(err error) bool {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		return false
	}
	return pgErr.Code == sqlStateSerializationFailure || pgErr.Code == sqlStateDeadlockDetected
}
