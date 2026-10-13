package postgres_test

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

const validNonceHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

// insertAppleWebLogin은 apple_web_logins 한 행을 넣습니다. 시각은 expires_at, consumed_at을 SQL 표현식으로 받습니다.
func insertAppleWebLogin(ctx context.Context, pool *pgxpool.Pool, id, exchangeHash, nonceHash, expiresAt, consumedAt string) error {
	_, err := pool.Exec(ctx, `INSERT INTO apple_web_logins
		(id, exchange_hash, subject, nonce_hash, apple_refresh_token, apple_token_key_id, apple_client_id, expires_at, consumed_at)
		VALUES ($1, decode($2, 'hex'), 'sub', $3, '\x01', 'key', 'client', `+expiresAt+`, `+consumedAt+`)`,
		id, exchangeHash, nonceHash)
	return err
}

func TestSchema_AppleWebLoginExchangeHashUnique(t *testing.T) {
	ctx := context.Background()
	pool := dbtest.New(t)
	const hash = "aa"
	if err := insertAppleWebLogin(ctx, pool, "00000000-0000-7000-8000-0000000000b1", hash, validNonceHash, "now()", "NULL"); err != nil {
		t.Fatal(err)
	}
	err := insertAppleWebLogin(ctx, pool, "00000000-0000-7000-8000-0000000000b2", hash, validNonceHash, "now()", "NULL")
	wantSQLState(t, err, uniqueViolation)
}

func TestSchema_AppleWebLoginNonceHashFormat(t *testing.T) {
	tests := []struct {
		name      string
		nonceHash string
		wantState string
	}{
		{"소문자 hex 64자", validNonceHash, ""},
		{"대문자", "0123456789ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef", checkViolation},
		{"63자", validNonceHash[:63], checkViolation},
		{"65자", validNonceHash + "0", checkViolation},
		{"hex가 아닌 문자", "g" + validNonceHash[1:], checkViolation},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := dbtest.New(t)
			err := insertAppleWebLogin(context.Background(), pool, "00000000-0000-7000-8000-0000000000b1", "aa", tt.nonceHash, "now()", "NULL")
			if tt.wantState == "" {
				if err != nil {
					t.Fatalf("성공해야 하는데 %v", err)
				}
				return
			}
			wantSQLState(t, err, tt.wantState)
		})
	}
}

func TestSchema_AppleWebLoginConsumedNotAfterExpiry(t *testing.T) {
	const expires = "timestamptz '2026-10-13 00:00:00+00'"
	tests := []struct {
		name       string
		consumedAt string // SQL 표현식입니다.
		wantState  string
	}{
		{"소진 전", "NULL", ""},
		{"만료 이전에 소진", "timestamptz '2026-10-12 23:59:00+00'", ""},
		{"만료 시각에 소진", expires, ""},
		{"만료 뒤에 소진", "timestamptz '2026-10-13 00:01:00+00'", checkViolation},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := dbtest.New(t)
			err := insertAppleWebLogin(context.Background(), pool, "00000000-0000-7000-8000-0000000000b1", "aa", validNonceHash, expires, tt.consumedAt)
			if tt.wantState == "" {
				if err != nil {
					t.Fatalf("성공해야 하는데 %v", err)
				}
				return
			}
			wantSQLState(t, err, tt.wantState)
		})
	}
}
