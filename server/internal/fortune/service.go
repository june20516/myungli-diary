// Package fortune은 엔진 결과 캐시와 "캐시 → singleflight → 엔진 → 저장" 조회 흐름을 담습니다.
package fortune

import (
	"context"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"strconv"
	"time"

	"golang.org/x/sync/singleflight"
	"google.golang.org/protobuf/proto"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// cacheWriteTimeout은 캐시 쓰기 한 번의 상한입니다. DB가 멈춰도 엔진이 성공한 요청이 거기 묶이지 않게 합니다.
const cacheWriteTimeout = time.Second

// VersionSource는 엔진의 현재 ruleset_version을 줍니다. *engine.Versions가 만족합니다.
type VersionSource interface{ Current() (string, error) }

// Service는 엔진 결과를 캐시와 함께 조회합니다.
// 돌려주는 응답은 같은 키로 동시에 기다린 호출자끼리 공유될 수 있으므로 바꾸지 않습니다.
type Service struct {
	engine   engine.Engine
	versions VersionSource
	cache    ResultCache
	flight   singleflight.Group
	logger   *slog.Logger
}

// NewService는 Service를 만듭니다.
func NewService(e engine.Engine, v VersionSource, c ResultCache, logger *slog.Logger) *Service {
	return &Service{engine: e, versions: v, cache: c, logger: logger}
}

// Chart는 원국을 조회합니다. 캐시 키는 asOf의 연도입니다.
func (s *Service) Chart(ctx context.Context, b profile.Birth, asOf profile.LocalDate) (*enginev1.ChartResponse, error) {
	ruleset, err := s.currentRuleset()
	if err != nil {
		return nil, err
	}
	info, err := toBirthInfo(b)
	if err != nil {
		return nil, err
	}
	key := ChartKey{BirthHash: profile.BirthHash(b), Ruleset: ruleset, AsOfYear: asOf.Year}
	return fetch(ctx, s, fetchSpec[*enginev1.ChartResponse]{
		kind:      "chart",
		flightKey: flightKey("chart", key.BirthHash, ruleset, strconv.Itoa(asOf.Year)),
		newMsg:    func() *enginev1.ChartResponse { return &enginev1.ChartResponse{} },
		get:       func(ctx context.Context) ([]byte, bool, error) { return s.cache.GetChart(ctx, key) },
		put: func(ctx context.Context, rs string, data []byte) error {
			stored := key
			stored.Ruleset = rs
			return s.cache.PutChart(ctx, stored, data)
		},
		call: func(ctx context.Context) (*enginev1.ChartResponse, error) {
			return s.engine.GetChart(ctx, &enginev1.ChartRequest{Birth: info, AsOf: toLocalDate(asOf)})
		},
		ruleset: func(r *enginev1.ChartResponse) string { return r.GetMeta().GetRulesetVersion() },
	})
}

// Daily는 사용자 현재 시간대의 날짜 하나의 운세를 조회합니다.
func (s *Service) Daily(ctx context.Context, b profile.Birth, date profile.LocalDate, currentTimezone string) (*enginev1.DailyResponse, error) {
	ruleset, err := s.currentRuleset()
	if err != nil {
		return nil, err
	}
	info, err := toBirthInfo(b)
	if err != nil {
		return nil, err
	}
	key := DailyKey{BirthHash: profile.BirthHash(b), Ruleset: ruleset, Date: date, CurrentTimezone: currentTimezone}
	return fetch(ctx, s, fetchSpec[*enginev1.DailyResponse]{
		kind: "daily",
		flightKey: flightKey("daily", key.BirthHash, ruleset,
			fmt.Sprintf("%04d-%02d-%02d", date.Year, date.Month, date.Day), currentTimezone),
		newMsg: func() *enginev1.DailyResponse { return &enginev1.DailyResponse{} },
		get:    func(ctx context.Context) ([]byte, bool, error) { return s.cache.GetDaily(ctx, key) },
		put: func(ctx context.Context, rs string, data []byte) error {
			stored := key
			stored.Ruleset = rs
			return s.cache.PutDaily(ctx, stored, data)
		},
		call: func(ctx context.Context) (*enginev1.DailyResponse, error) {
			return s.engine.GetDaily(ctx, &enginev1.DailyRequest{
				Birth: info, Date: toLocalDate(date), CurrentTimezone: currentTimezone,
			})
		},
		ruleset: func(r *enginev1.DailyResponse) string { return r.GetMeta().GetRulesetVersion() },
	})
}

// DailyUncached는 Daily와 같은 요청을 캐시와 singleflight 없이 엔진에 바로 보냅니다.
// 계정 없는 요청(미리보기)처럼 출생 정보에서 되찾을 수 있는 값(birth_hash)을 저장하면 안 될 때 씁니다(D50).
func (s *Service) DailyUncached(ctx context.Context, b profile.Birth, date profile.LocalDate, currentTimezone string) (*enginev1.DailyResponse, error) {
	if _, err := s.currentRuleset(); err != nil {
		return nil, err
	}
	info, err := toBirthInfo(b)
	if err != nil {
		return nil, err
	}
	return s.engine.GetDaily(ctx, &enginev1.DailyRequest{Birth: info, Date: toLocalDate(date), CurrentTimezone: currentTimezone})
}

// Month는 한 달 달력을 조회합니다.
func (s *Service) Month(ctx context.Context, b profile.Birth, year, month int, currentTimezone string) (*enginev1.MonthResponse, error) {
	ruleset, err := s.currentRuleset()
	if err != nil {
		return nil, err
	}
	info, err := toBirthInfo(b)
	if err != nil {
		return nil, err
	}
	key := MonthKey{BirthHash: profile.BirthHash(b), Ruleset: ruleset, Year: year, Month: month, CurrentTimezone: currentTimezone}
	return fetch(ctx, s, fetchSpec[*enginev1.MonthResponse]{
		kind: "month",
		flightKey: flightKey("month", key.BirthHash, ruleset,
			strconv.Itoa(year), strconv.Itoa(month), currentTimezone),
		newMsg: func() *enginev1.MonthResponse { return &enginev1.MonthResponse{} },
		get:    func(ctx context.Context) ([]byte, bool, error) { return s.cache.GetMonth(ctx, key) },
		put: func(ctx context.Context, rs string, data []byte) error {
			stored := key
			stored.Ruleset = rs
			return s.cache.PutMonth(ctx, stored, data)
		},
		call: func(ctx context.Context) (*enginev1.MonthResponse, error) {
			return s.engine.GetMonthCalendar(ctx, &enginev1.MonthRequest{
				Birth: info, Year: toInt32(year), Month: toInt32(month), CurrentTimezone: currentTimezone,
			})
		},
		ruleset: func(r *enginev1.MonthResponse) string { return r.GetMeta().GetRulesetVersion() },
	})
}

// currentRuleset은 캐시 조회 키에 쓸 ruleset_version을 줍니다. 아직 모르면 엔진을 쓸 수 없는 것으로 봅니다.
func (s *Service) currentRuleset() (string, error) {
	ruleset, err := s.versions.Current()
	if err != nil {
		if errors.Is(err, engine.ErrVersionUnknown) {
			return "", fmt.Errorf("%w: %w", engine.ErrUnavailable, err)
		}
		return "", err
	}
	return ruleset, nil
}

// fetchSpec은 조회 종류마다 다른 부분입니다.
type fetchSpec[T proto.Message] struct {
	kind      string // 로그용 종류
	flightKey string
	newMsg    func() T
	get       func(ctx context.Context) ([]byte, bool, error)
	put       func(ctx context.Context, ruleset string, data []byte) error
	call      func(ctx context.Context) (T, error)
	ruleset   func(T) string // 응답의 meta.ruleset_version
}

// fetch는 캐시 → singleflight → 엔진 → 저장 흐름입니다. 캐시 오류는 Warn만 남기고 엔진 결과로 계속합니다.
func fetch[T proto.Message](ctx context.Context, s *Service, spec fetchSpec[T]) (T, error) {
	var zero T

	if cached, ok := readCache(ctx, s, spec); ok {
		return cached, nil
	}

	// 엔진 호출은 첫 호출자의 취소가 다른 호출자에게 번지지 않게 WithoutCancel로 부릅니다.
	// 시도마다 deadline은 engine.Client가 이미 겁니다.
	engineCtx := context.WithoutCancel(ctx)
	resultCh := s.flight.DoChan(spec.flightKey, func() (any, error) {
		response, err := spec.call(engineCtx)
		if err != nil {
			return nil, err
		}
		writeCtx, cancel := context.WithTimeout(engineCtx, cacheWriteTimeout)
		defer cancel()
		writeCache(writeCtx, s, spec, response)
		return response, nil
	})

	select {
	case <-ctx.Done():
		return zero, ctx.Err()
	case result := <-resultCh:
		if result.Err != nil {
			return zero, result.Err
		}
		response := result.Val.(T)
		if result.Shared {
			// 같은 호출을 나눠 받은 호출자끼리 객체를 공유하지 않게 복제합니다.
			return proto.Clone(response).(T), nil
		}
		return response, nil
	}
}

// readCache는 캐시에서 응답을 읽습니다. 읽기 오류나 깨진 행은 Warn만 남기고 없는 것으로 다룹니다.
func readCache[T proto.Message](ctx context.Context, s *Service, spec fetchSpec[T]) (T, bool) {
	var zero T
	data, ok, err := spec.get(ctx)
	if err != nil {
		s.logger.Warn("엔진 결과 캐시 읽기 실패", slog.String("kind", spec.kind), slog.String("error_type", fmt.Sprintf("%T", err)))
		return zero, false
	}
	if !ok {
		return zero, false
	}
	message := spec.newMsg()
	if err := proto.Unmarshal(data, message); err != nil {
		s.logger.Warn("엔진 결과 캐시 행을 해석하지 못했습니다", slog.String("kind", spec.kind))
		return zero, false
	}
	return message, true
}

// writeCache는 응답의 meta.ruleset_version을 키로 저장합니다. 실패해도 Warn만 남깁니다.
func writeCache[T proto.Message](ctx context.Context, s *Service, spec fetchSpec[T], response T) {
	ruleset := spec.ruleset(response)
	if ruleset == "" {
		s.logger.Warn("엔진 응답에 ruleset_version이 없어 캐시에 저장하지 않습니다", slog.String("kind", spec.kind))
		return
	}
	data, err := proto.MarshalOptions{Deterministic: true}.Marshal(response)
	if err != nil {
		s.logger.Warn("엔진 응답 직렬화 실패", slog.String("kind", spec.kind))
		return
	}
	if err := spec.put(ctx, ruleset, data); err != nil {
		s.logger.Warn("엔진 결과 캐시 쓰기 실패", slog.String("kind", spec.kind), slog.String("error_type", fmt.Sprintf("%T", err)))
	}
}

// flightKey는 종류, 해시, 나머지 키 값을 각각 strconv.Quote로 감싸 이어 붙입니다.
// 값 안의 구분자는 따옴표 이스케이프되므로 서로 다른 키가 같은 문자열이 될 수 없습니다.
// 해시는 키에만 쓰고 로그에 남기지 않습니다.
func flightKey(kind string, birthHash [32]byte, parts ...string) string {
	key := strconv.Quote(kind) + "|" + hex.EncodeToString(birthHash[:])
	for _, part := range parts {
		key += "|" + strconv.Quote(part)
	}
	return key
}
