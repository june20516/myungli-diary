package opsapi

import (
	"sync"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// 콘텐츠 열람 상한입니다. 운영자(IAP sub)마다 콘텐츠 열람 세 경로를 합쳐 1분에 30건까지입니다.
// 인스턴스 메모리 기준이라 server-ops 인스턴스가 둘(Terraform max_instance_count)이면 실제 상한은 많아야 그 두 배입니다.
// 대량 열람을 늦추고 감사 기록에 몰린 흔적을 남기려는 것이며, 로그 기반 알림은 아닙니다.
const (
	contentViewLimit  = 30
	contentViewWindow = time.Minute
)

// contentPaths는 상한을 함께 세는 콘텐츠 열람 경로입니다.
var contentPaths = map[string]bool{
	"/ops/v1/content:diary":    true,
	"/ops/v1/content:schedule": true,
	"/ops/v1/content:profile":  true,
}

// rateLimiter는 키(운영자 sub)마다 지난 window 동안 허용한 시각을 기억해 limit건을 넘으면 거절합니다(sliding window).
// 거절한 요청은 세지 않습니다. 운영자는 몇 명이라 키마다 시각 목록을 두어도 메모리가 작고,
// 창이 빈 키는 지웁니다.
type rateLimiter struct {
	clock  clock.Clock
	limit  int
	window time.Duration

	mu   sync.Mutex
	hits map[string][]time.Time
}

func newRateLimiter(clk clock.Clock, limit int, window time.Duration) *rateLimiter {
	return &rateLimiter{clock: clk, limit: limit, window: window, hits: make(map[string][]time.Time)}
}

// allow는 key의 요청 하나를 받아도 되는지 알려 주고, 받으면 셉니다.
func (l *rateLimiter) allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.clock.Now()
	cutoff := now.Add(-l.window)
	kept := l.hits[key][:0]
	for _, at := range l.hits[key] {
		if at.After(cutoff) {
			kept = append(kept, at)
		}
	}
	if len(kept) >= l.limit {
		l.hits[key] = kept
		return false
	}
	l.hits[key] = append(kept, now)
	return true
}
