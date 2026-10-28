// Package postgres는 PostgreSQL 연결과 migration을 다룹니다.
package postgres

import (
	"context"
	"errors"
	"fmt"
	"net"
	"time"

	"cloud.google.com/go/cloudsqlconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// connectTimeout은 연결 확인(ping)까지 허용하는 시간입니다.
const connectTimeout = 5 * time.Second

// Open은 연결 풀을 만들고 ping으로 연결을 확인합니다. 5초 안에 확인하지 못하면 오류를 반환합니다.
//
// 연결 문자열에는 비밀번호가 들어 있을 수 있어, 오류에는 연결 문자열을 담지 않습니다.
func Open(ctx context.Context, url string) (*pgxpool.Pool, error) {
	config, err := parseConfig(url)
	if err != nil {
		return nil, err
	}
	return openConfig(ctx, config)
}

// DialFunc는 Cloud SQL instance(연결 이름 project:region:instance)로 연결을 엽니다.
type DialFunc func(ctx context.Context, instance string) (net.Conn, error)

// OpenWithDialer는 url의 사용자·DB 설정으로, host 대신 dial이 instance로 연 연결을 쓰는 풀을 만듭니다.
func OpenWithDialer(ctx context.Context, url, instance string, dial DialFunc) (*pgxpool.Pool, error) {
	config, err := parseConfig(url)
	if err != nil {
		return nil, err
	}
	config.ConnConfig.DialFunc = func(ctx context.Context, _, _ string) (net.Conn, error) {
		return dial(ctx, instance)
	}
	return openConfig(ctx, config)
}

// OpenCloudSQL은 Cloud SQL Go connector와 IAM DB 인증으로 instance에 붙는 풀을 만듭니다(S121).
// url에는 IAM DB 사용자와 DB 이름만 있으면 되고 비밀번호는 없습니다. 자격 증명은 실행 서비스 계정(ADC)입니다.
// dialer는 풀이 살아 있는 동안 쓰이므로, 풀을 닫을 때 함께 닫도록 호출한 쪽이 돌려받은 close를 부릅니다.
func OpenCloudSQL(ctx context.Context, url, instance string) (pool *pgxpool.Pool, closeDialer func() error, err error) {
	dialer, err := cloudsqlconn.NewDialer(ctx, cloudsqlconn.WithIAMAuthN())
	if err != nil {
		return nil, nil, fmt.Errorf("cloudsqlconn dialer 생성: %w", err)
	}
	dial := func(ctx context.Context, instance string) (net.Conn, error) { return dialer.Dial(ctx, instance) }
	pool, err = OpenWithDialer(ctx, url, instance, dial)
	if err != nil {
		_ = dialer.Close()
		return nil, nil, err
	}
	return pool, dialer.Close, nil
}

// parseConfig는 연결 문자열을 풀 설정으로 바꿉니다.
func parseConfig(url string) (*pgxpool.Config, error) {
	config, err := pgxpool.ParseConfig(url)
	if err != nil {
		// pgx의 파싱 오류는 연결 문자열 일부를 포함할 수 있어 원인을 버립니다.
		return nil, errors.New("DATABASE_URL 형식이 올바르지 않습니다")
	}
	return config, nil
}

// openConfig는 설정으로 풀을 만들고 connectTimeout 안에 ping으로 연결을 확인합니다.
func openConfig(ctx context.Context, config *pgxpool.Config) (*pgxpool.Pool, error) {
	ctx, cancel := context.WithTimeout(ctx, connectTimeout)
	defer cancel()

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
