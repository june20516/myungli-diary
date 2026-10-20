package httpapi

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"slices"
	"time"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// Limiter는 키별 요청 수를 세어 허용 여부를 알려 줍니다. *ratelimit.Limiter가 만족합니다.
type Limiter interface {
	// Allow는 key의 요청 수를 하나 올리고 window 안에서 limit 이내인지 돌려줍니다.
	// 거부되면 retryAfter는 다시 시도할 수 있을 때까지의 시간입니다.
	Allow(ctx context.Context, key string, limit int, window time.Duration) (allowed bool, retryAfter time.Duration, err error)
}

// RateLimit은 Routes.RateLimit에 넣을 함수를 만듭니다. op.ID가 operations에 있는 operation만 감싸고,
// 나머지는 next를 그대로 돌려줍니다. 키는 "<operation>:<클라이언트 IP의 SHA-256 hex>"라 IP 원문을 저장·로그하지 않습니다.
// 한도를 넘으면 429 rate_limited와 Retry-After(초, 올림)로 답합니다.
// App Check 바로 안쪽에 끼우므로 App Check를 통과하지 못한 요청은 한도를 쓰지 않습니다.
//
// 저장소 오류는 panic으로 올려 recoverPanic이 로그(본문 제외)와 500으로 처리하게 합니다.
func RateLimit(l Limiter, trustedHops int, limit int, window time.Duration, operations ...string) func(op Operation, next http.Handler) http.Handler {
	return func(op Operation, next http.Handler) http.Handler {
		if !slices.Contains(operations, op.ID) {
			return next
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			digest := sha256.Sum256([]byte(ClientIP(r, trustedHops)))
			key := op.ID + ":" + hex.EncodeToString(digest[:])
			allowed, retryAfter, err := l.Allow(r.Context(), key, limit, window)
			if err != nil {
				if errors.Is(err, context.Canceled) {
					// 클라이언트가 끊었습니다. 경보가 되지 않게 조용히 연결을 닫습니다.
					panic(http.ErrAbortHandler)
				}
				panic(fmt.Errorf("요청 한도 확인: %w", err))
			}
			if !allowed {
				writeProblem(w, r, problem.RateLimited.Problem("Too many requests"), false, ceilSeconds(retryAfter))
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// ceilSeconds는 d를 초 단위로 올리고 최소 1초로 맞춥니다(Retry-After가 0이면 헤더가 빠지므로).
func ceilSeconds(d time.Duration) time.Duration {
	return max(time.Second, (d+time.Second-1)/time.Second*time.Second)
}
