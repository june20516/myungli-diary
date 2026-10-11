// Package postgres는 PostgreSQL 연결과 migration을 다룹니다.
package postgres

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// connectTimeout은 연결 확인(ping)까지 허용하는 시간입니다.
const connectTimeout = 5 * time.Second

// Open은 연결 풀을 만들고 ping으로 연결을 확인합니다. 5초 안에 확인하지 못하면 오류를 반환합니다.
//
// 연결 문자열에는 비밀번호가 들어 있을 수 있어, 오류에는 연결 문자열을 담지 않습니다.
func Open(ctx context.Context, url string) (*pgxpool.Pool, error) {
	ctx, cancel := context.WithTimeout(ctx, connectTimeout)
	defer cancel()

	config, err := pgxpool.ParseConfig(url)
	if err != nil {
		// pgx의 파싱 오류는 연결 문자열 일부를 포함할 수 있어 원인을 버립니다.
		return nil, errors.New("DATABASE_URL 형식이 올바르지 않습니다")
	}

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("연결 풀 생성: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("DB 연결 확인: %w", err)
	}
	return pool, nil
}
