// Package precompute는 job precompute(spec §8.1, P8-3)입니다. 현지 22:00~22:29인 최근 활동 사용자의
// 다음 날 데일리(다음 날이 1일이면 그 달 캘린더도)를 엔진에서 계산해 결과 캐시를 채웁니다.
package precompute

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
	"golang.org/x/sync/errgroup"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

const (
	// activeWindow는 대상으로 보는 마지막 활동 시각의 범위입니다.
	activeWindow = 14 * 24 * time.Hour
	// pageSize는 대상 후보를 한 번에 읽는 수입니다.
	pageSize int32 = 500
	// engineConcurrency는 엔진 동시 호출 상한입니다.
	engineConcurrency = 8
	// windowStartHour부터 windowMinutes 동안(22:00 이상 22:30 미만)이 현지 대상 시각입니다.
	windowStartHour = 22
	windowMinutes   = 30
)

// ErrAllFailed는 대상이 1명 이상인데 모두 실패했다는 뜻입니다(엔진 장애를 Job 실패로 드러냄, S128).
var ErrAllFailed = errors.New("precompute 대상이 모두 실패했습니다")

// Fortune은 캐시를 거쳐 엔진 결과를 받는 쪽입니다. *fortune.Service가 만족합니다.
type Fortune interface {
	Daily(ctx context.Context, b profile.Birth, date profile.LocalDate, currentTimezone string) (*enginev1.DailyResponse, error)
	Month(ctx context.Context, b profile.Birth, year, month int, currentTimezone string) (*enginev1.MonthResponse, error)
}

// ProfileLister는 활동 계정의 프로필을 계정 id 순으로 after 다음부터 limit개 줍니다(profile.ListActiveProfiles).
type ProfileLister func(ctx context.Context, activeSince time.Time, after uuid.UUID, limit int32) ([]profile.ActiveProfile, error)

// Deps는 Run이 쓰는 것입니다.
type Deps struct {
	Profiles ProfileLister
	Fortune  Fortune
	Clock    clock.Clock
	Logger   *slog.Logger
}

// Result는 한 번 실행의 수입니다.
type Result struct {
	Targets, Succeeded, Failed int
}

// Run은 대상 사용자의 다음 날 결과를 계산합니다. 실행 시각은 시작할 때 한 번 읽습니다.
// 사용자 하나의 실패는 건너뛰고 셉니다. 조회 실패와 대상 전원 실패만 오류입니다.
func Run(ctx context.Context, deps Deps) (Result, error) {
	now := deps.Clock.Now()
	var (
		mu     sync.Mutex
		result Result
	)
	// record는 대상 한 명의 결과를 셉니다. goroutine에서도 부르므로 mu로 지킵니다.
	record := func(ok bool) {
		mu.Lock()
		defer mu.Unlock()
		result.Targets++
		if ok {
			result.Succeeded++
		} else {
			result.Failed++
		}
	}

	var group errgroup.Group
	group.SetLimit(engineConcurrency)
	listErr := forEachActive(ctx, deps.Profiles, now.Add(-activeWindow), func(item profile.ActiveProfile) {
		nextDay, isTarget, err := targetDate(now, item.Profile.CurrentTimezone)
		if err != nil {
			// 시간대를 못 읽으면 대상인지 알 수 없으므로 대상이자 실패로 셉니다(S128).
			record(false)
			deps.Logger.WarnContext(ctx, "precompute 시간대를 읽지 못함", "error", err)
			return
		}
		if !isTarget {
			return
		}
		group.Go(func() error {
			record(compute(ctx, deps, item.Profile, nextDay))
			return nil
		})
	})
	_ = group.Wait() // goroutine은 오류를 돌려주지 않습니다.
	if listErr != nil {
		return result, listErr
	}

	deps.Logger.InfoContext(ctx, "precompute 완료",
		"targets", result.Targets, "succeeded", result.Succeeded, "failed", result.Failed)
	if result.Targets > 0 && result.Succeeded == 0 {
		return result, ErrAllFailed
	}
	return result, nil
}

// forEachActive는 활동 프로필을 페이지마다 읽어 visit에 넘깁니다.
func forEachActive(ctx context.Context, list ProfileLister, activeSince time.Time, visit func(profile.ActiveProfile)) error {
	after := uuid.Nil
	for {
		page, err := list(ctx, activeSince, after, pageSize)
		if err != nil {
			return fmt.Errorf("precompute 대상 조회: %w", err)
		}
		for _, item := range page {
			visit(item)
		}
		if len(page) < int(pageSize) {
			return nil
		}
		after = page[len(page)-1].AccountID
	}
}

// targetDate는 timezone의 현지 시각이 대상 창 안인지와, 그렇다면 현지 날짜의 다음 날을 돌려줍니다.
func targetDate(now time.Time, timezone string) (profile.LocalDate, bool, error) {
	location, err := time.LoadLocation(timezone)
	if err != nil {
		return profile.LocalDate{}, false, err
	}
	local := now.In(location)
	if local.Hour() != windowStartHour || local.Minute() >= windowMinutes {
		return profile.LocalDate{}, false, nil
	}
	next := time.Date(local.Year(), local.Month(), local.Day()+1, 0, 0, 0, 0, location)
	return profile.LocalDate{Year: next.Year(), Month: int(next.Month()), Day: next.Day()}, true, nil
}

// compute는 사용자 한 명의 다음 날 데일리와(1일이면) 그 달 캘린더를 계산합니다. 하나라도 실패하면 false입니다.
func compute(ctx context.Context, deps Deps, p profile.Profile, nextDay profile.LocalDate) bool {
	if _, err := deps.Fortune.Daily(ctx, p.Birth, nextDay, p.CurrentTimezone); err != nil {
		deps.Logger.WarnContext(ctx, "precompute 데일리 실패", "error", err)
		return false
	}
	if nextDay.Day != 1 {
		return true
	}
	if _, err := deps.Fortune.Month(ctx, p.Birth, nextDay.Year, nextDay.Month, p.CurrentTimezone); err != nil {
		deps.Logger.WarnContext(ctx, "precompute 캘린더 실패", "error", err)
		return false
	}
	return true
}
