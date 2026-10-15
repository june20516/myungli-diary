package engine

import (
	"context"
	"errors"
	"fmt"
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
}

// NewVersions는 값이 비어 있는 Versions를 만듭니다. Refresh나 Run으로 채웁니다.
func NewVersions(e Engine, logger *slog.Logger) *Versions {
	return &Versions{engine: e, logger: logger}
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
// 실패는 Warn 로그만 남기고 계속합니다(ctx 취소로 인한 오류는 종료 잡음이라 남기지 않습니다).
func (v *Versions) Run(ctx context.Context, interval time.Duration) {
	v.refreshAndLog(ctx)

	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			v.refreshAndLog(ctx)
		}
	}
}

func (v *Versions) refreshAndLog(ctx context.Context) {
	err := v.Refresh(ctx)
	if err == nil || errors.Is(err, context.Canceled) {
		return
	}
	v.logger.Warn("엔진 ruleset_version 갱신 실패", slog.String("error", fmt.Sprint(err)))
}
