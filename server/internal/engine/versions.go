package engine

import (
	"context"
	"errors"
	"log/slog"
	"sync/atomic"
	"time"
)

// ErrVersionUnknown은 엔진 ruleset_version을 아직 한 번도 받지 못했을 때의 오류입니다.
var ErrVersionUnknown = errors.New("engine ruleset version unknown")

// Versions는 엔진의 현재 ruleset_version을 보관하고 주기적으로 갱신합니다.
// 결과 캐시 키에 이 값이 들어갑니다.
type Versions struct {
	engine  Engine
	logger  *slog.Logger
	current atomic.Pointer[string]

	initialBackoff time.Duration // 값을 모르는 동안의 첫 재시도 간격입니다. 테스트에서 줄입니다.
}

// defaultInitialBackoff는 ruleset_version을 아직 모를 때 첫 재시도까지의 간격입니다.
// 이후 두 배씩 늘어 갱신 주기를 넘지 않습니다.
const defaultInitialBackoff = 2 * time.Second

// NewVersions는 값이 비어 있는 Versions를 만듭니다. Refresh나 Run으로 채웁니다.
func NewVersions(e Engine, logger *slog.Logger) *Versions {
	return &Versions{engine: e, logger: logger, initialBackoff: defaultInitialBackoff}
}

// Refresh는 엔진 GetInfo를 한 번 불러 값을 갱신합니다.
// 실패하거나 ruleset_version이 비어 있으면 이전 값을 유지하고 오류만 돌려줍니다.
func (v *Versions) Refresh(ctx context.Context) error {
	info, err := v.engine.GetInfo(ctx)
	if err != nil {
		return err
	}
	rulesetVersion := info.GetRulesetVersion()
	if rulesetVersion == "" {
		return errors.New("엔진 GetInfo 응답의 ruleset_version이 비어 있습니다")
	}
	v.current.Store(&rulesetVersion)
	return nil
}

// Current는 마지막으로 받은 ruleset_version을 돌려줍니다. 받은 적이 없으면 ErrVersionUnknown입니다.
func (v *Versions) Current() (string, error) {
	rulesetVersion := v.current.Load()
	if rulesetVersion == nil {
		return "", ErrVersionUnknown
	}
	return *rulesetVersion, nil
}

// Run은 바로 한 번 Refresh한 뒤 interval마다 되풀이하고, ctx가 취소되면 반환합니다.
// 값을 아직 모르는 동안에는 initialBackoff부터 두 배씩 늘려(상한 interval) 다시 시도하고,
// 한 번 알게 되면 interval 주기로 돌아갑니다. 시작 때 엔진이 잠시 내려가 있어도 interval을 기다리지 않기 위해서입니다.
// interval이 0 이하면 시작 시 Warn 로그와 함께 한 번만 갱신하고 ctx 취소까지 기다립니다.
// 실패는 Warn 로그만 남기고 계속합니다(ctx 취소로 인한 오류는 종료 잡음이라 남기지 않습니다).
func (v *Versions) Run(ctx context.Context, interval time.Duration) {
	v.refreshAndLog(ctx)

	if interval <= 0 {
		v.logger.Warn("엔진 ruleset_version 갱신 주기가 0 이하라 시작 시 한 번만 갱신합니다")
		<-ctx.Done()
		return
	}

	backoff := min(v.initialBackoff, interval)
	timer := time.NewTimer(v.nextDelay(interval, &backoff))
	defer timer.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-timer.C:
			v.refreshAndLog(ctx)
			timer.Reset(v.nextDelay(interval, &backoff))
		}
	}
}

// nextDelay는 다음 Refresh까지의 간격을 돌려줍니다. 값을 알면 interval이고,
// 모르면 현재 backoff이며 호출할 때마다 backoff를 두 배로(상한 interval) 늘립니다.
func (v *Versions) nextDelay(interval time.Duration, backoff *time.Duration) time.Duration {
	if _, err := v.Current(); err == nil {
		return interval
	}
	delay := *backoff
	*backoff = min(*backoff*2, interval)
	return delay
}

func (v *Versions) refreshAndLog(ctx context.Context) {
	err := v.Refresh(ctx)
	if err == nil || errors.Is(err, context.Canceled) {
		return
	}
	v.logger.Warn("엔진 ruleset_version 갱신 실패", slog.Any("error", err))
}
