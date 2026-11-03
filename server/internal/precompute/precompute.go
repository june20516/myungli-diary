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
	// Prepare는 대상이 1명 이상일 때 첫 계산 전에 한 번 부릅니다(엔진 버전 조회). nil이면 건너뜁니다.
	// 대상이 없는 실행이 엔진을 부르지 않게 하려는 것입니다(cold start와 호출 비용).
	Prepare func(ctx context.Context) error
	Fortune Fortune
	Clock   clock.Clock
	Logger  *slog.Logger
}

// Result는 한 번 실행의 수입니다.
type Result struct {
	// Candidates는 읽은 활동 프로필 수(창 밖 포함)입니다.
	Candidates int
	// Targets는 현지 시각이 창 안인 수입니다. 준비 실패나 취소로 계산하지 못한 대상이 있으면 Succeeded + Failed보다 큽니다.
	Targets, Succeeded, Failed int
	// InvalidTimezone은 현재 시간대를 읽지 못한 프로필 수입니다. 대상인지 알 수 없어 Targets와 실패 판정에서 뺍니다(S128).
	InvalidTimezone int
}

// target은 계산할 사용자 한 명과 그 현지 다음 날입니다.
type target struct {
	profile profile.Profile
	nextDay profile.LocalDate
}

// Run은 대상 사용자의 다음 날 결과를 계산합니다. 실행 시각은 시작할 때 한 번 읽습니다.
// 대상을 모두 고른 뒤, 대상이 있으면 Prepare를 부르고 계산합니다.
// 사용자 하나의 실패는 건너뛰고 셉니다. 조회 실패, 준비 실패, ctx 취소, 대상 전원 실패만 오류이고,
// 어느 경우든 수와 단계별 시간을 로그에 남깁니다.
// 성공은 엔진 결과를 받았다는 뜻입니다. fortune.Service는 캐시 쓰기 실패를 Warn으로만 남기므로 캐시 저장까지는 보장하지 않습니다.
func Run(ctx context.Context, deps Deps) (Result, error) {
	now := deps.Clock.Now()
	var result Result
	var listTime, prepareTime, computeTime time.Duration
	defer func() {
		deps.Logger.InfoContext(context.WithoutCancel(ctx), "precompute 완료",
			"candidates", result.Candidates, "targets", result.Targets, "succeeded", result.Succeeded,
			"failed", result.Failed, "invalid_timezone", result.InvalidTimezone,
			"list_ms", listTime.Milliseconds(), "prepare_ms", prepareTime.Milliseconds(), "compute_ms", computeTime.Milliseconds())
	}()

	started := deps.Clock.Now()
	targets, err := selectTargets(ctx, deps.Profiles, now, &result)
	listTime = deps.Clock.Now().Sub(started)
	if err != nil {
		return result, err
	}
	result.Targets = len(targets)
	if len(targets) == 0 {
		return result, nil
	}

	if deps.Prepare != nil {
		started = deps.Clock.Now()
		err := deps.Prepare(ctx)
		prepareTime = deps.Clock.Now().Sub(started)
		if err != nil {
			return result, fmt.Errorf("precompute 준비: %w", err)
		}
	}

	started = deps.Clock.Now()
	computeAll(ctx, deps, targets, &result)
	computeTime = deps.Clock.Now().Sub(started)
	if err := ctx.Err(); err != nil {
		return result, fmt.Errorf("precompute 중단: %w", err)
	}
	if result.Succeeded == 0 {
		return result, ErrAllFailed
	}
	return result, nil
}

// selectTargets는 활동 프로필을 모두 읽어 현지 시각이 창 안인 사용자를 고르고, 후보와 시간대 실패 수를 셉니다.
// 한 실행의 대상은 한 시간대 창의 사용자뿐이라 메모리에 모아도 됩니다.
func selectTargets(ctx context.Context, list ProfileLister, now time.Time, result *Result) ([]target, error) {
	var targets []target
	err := forEachActive(ctx, list, now.Add(-activeWindow), func(item profile.ActiveProfile) {
		result.Candidates++
		nextDay, isTarget, err := targetDate(now, item.Profile.CurrentTimezone)
		if err != nil {
			result.InvalidTimezone++
			return
		}
		if isTarget {
			targets = append(targets, target{profile: item.Profile, nextDay: nextDay})
		}
	})
	return targets, err
}

// computeAll은 대상을 엔진 동시 호출 상한 안에서 계산하고 결과를 셉니다.
func computeAll(ctx context.Context, deps Deps, targets []target, result *Result) {
	var (
		mu    sync.Mutex
		group errgroup.Group
	)
	group.SetLimit(engineConcurrency)
	for _, t := range targets {
		if ctx.Err() != nil {
			break
		}
		group.Go(func() error {
			ok := compute(ctx, deps, t.profile, t.nextDay)
			mu.Lock()
			defer mu.Unlock()
			if ok {
				result.Succeeded++
			} else {
				result.Failed++
			}
			return nil
		})
	}
	_ = group.Wait() // goroutine은 오류를 돌려주지 않습니다.
}

// forEachActive는 활동 프로필을 페이지마다 읽어 visit에 넘깁니다. ctx가 끝나면 남은 페이지를 읽지 않습니다.
func forEachActive(ctx context.Context, list ProfileLister, activeSince time.Time, visit func(profile.ActiveProfile)) error {
	after := uuid.Nil
	for {
		if err := ctx.Err(); err != nil {
			return fmt.Errorf("precompute 중단: %w", err)
		}
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
	// 날짜는 시간대와 무관하게 더합니다. 현지 자정을 만들면 DST로 자정이 없는 날 전날로 정규화됩니다.
	today := profile.LocalDate{Year: local.Year(), Month: int(local.Month()), Day: local.Day()}
	return today.AddDays(1), true, nil
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
