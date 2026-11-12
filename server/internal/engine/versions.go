package engine

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync/atomic"
	"time"

	"golang.org/x/sync/singleflight"
)

// SupportedRulesetVersion은 이 server 빌드가 값과 메시지 키를 모두 다루는 엔진 ruleset_version의 가장 높은 값입니다(D110 ③).
// 엔진 계약을 따라잡는 PR에서 함께 올립니다. 실행 중인 server는 GET /version(getServerVersion) 응답으로 이 값을 내놓고,
// deploy-engine workflow는 배포할 엔진의 RULESET_VERSION이 이 값보다 높으면 배포하지 않습니다(D110 ④).
const SupportedRulesetVersion = "2026.11.8"

// ErrVersionUnknown은 엔진 ruleset_version을 아직 한 번도 받지 못했을 때의 오류입니다.
var ErrVersionUnknown = errors.New("engine ruleset version unknown")

// Versions는 엔진의 현재 ruleset_version을 보관하고 주기적으로 갱신합니다.
// 결과 캐시 키에 이 값이 들어갑니다.
type Versions struct {
	engine  Engine
	logger  *slog.Logger
	current atomic.Pointer[string]
	// ensure는 값을 모를 때 동시에 온 Ensure가 Refresh 하나를 함께 기다리게 합니다.
	ensure singleflight.Group

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

// Ensure는 값을 알면 그 값을, 모르면 Refresh를 한 번 불러(동시에 온 호출은 하나를 함께 기다림) 받은 값을 돌려줍니다.
// 엔진과 server가 함께 cold start한 직후에도 첫 요청이 503이 되지 않고 엔진이 뜰 때까지 기다리게 하려는 것입니다(S132).
// Refresh는 첫 호출자의 ctx와 떨어져 돌므로 한 요청이 취소돼도 다른 요청의 기다림이 끊기지 않습니다.
// 기다림은 호출자 ctx가 끝나면 멈추고, Refresh가 실패하면 그 오류를 ErrVersionUnknown과 함께 돌려줍니다.
func (v *Versions) Ensure(ctx context.Context) (string, error) {
	if rulesetVersion, err := v.Current(); err == nil {
		return rulesetVersion, nil
	}
	result := v.ensure.DoChan("refresh", func() (any, error) {
		return nil, v.Refresh(context.WithoutCancel(ctx))
	})
	select {
	case <-ctx.Done():
		return "", ctx.Err()
	case r := <-result:
		if r.Err != nil {
			return "", fmt.Errorf("%w: %w", ErrVersionUnknown, r.Err)
		}
		return v.Current()
	}
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
