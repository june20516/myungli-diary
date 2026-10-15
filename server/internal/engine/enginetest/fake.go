// Package enginetest는 engine.Engine의 테스트 대역을 담습니다.
package enginetest

import (
	"context"
	"sync/atomic"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
)

// Fake는 메서드마다 응답·오류를 함수로 넣는 engine.Engine 대역입니다. 함수가 nil이면 빈 응답을 돌려줍니다
// (GetInfo는 기본값 engine_version "test", ruleset_version "rs-1"). 호출 횟수는 *Calls에 쌓입니다.
type Fake struct {
	Chart         func(*enginev1.ChartRequest) (*enginev1.ChartResponse, error)
	Daily         func(*enginev1.DailyRequest) (*enginev1.DailyResponse, error)
	MonthCalendar func(*enginev1.MonthRequest) (*enginev1.MonthResponse, error)
	BirthHour     func(*enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error)
	Info          func() (*enginev1.InfoResponse, error)

	ChartCalls, DailyCalls, MonthCalendarCalls, BirthHourCalls, InfoCalls atomic.Int64
}

var _ engine.Engine = (*Fake)(nil)

func (f *Fake) GetChart(_ context.Context, req *enginev1.ChartRequest) (*enginev1.ChartResponse, error) {
	f.ChartCalls.Add(1)
	if f.Chart == nil {
		return &enginev1.ChartResponse{}, nil
	}
	return f.Chart(req)
}

func (f *Fake) GetDaily(_ context.Context, req *enginev1.DailyRequest) (*enginev1.DailyResponse, error) {
	f.DailyCalls.Add(1)
	if f.Daily == nil {
		return &enginev1.DailyResponse{}, nil
	}
	return f.Daily(req)
}

func (f *Fake) GetMonthCalendar(_ context.Context, req *enginev1.MonthRequest) (*enginev1.MonthResponse, error) {
	f.MonthCalendarCalls.Add(1)
	if f.MonthCalendar == nil {
		return &enginev1.MonthResponse{}, nil
	}
	return f.MonthCalendar(req)
}

func (f *Fake) GetBirthHour(_ context.Context, req *enginev1.BirthHourRequest) (*enginev1.BirthHourResponse, error) {
	f.BirthHourCalls.Add(1)
	if f.BirthHour == nil {
		return &enginev1.BirthHourResponse{}, nil
	}
	return f.BirthHour(req)
}

func (f *Fake) GetInfo(context.Context) (*enginev1.InfoResponse, error) {
	f.InfoCalls.Add(1)
	if f.Info == nil {
		return &enginev1.InfoResponse{EngineVersion: "test", RulesetVersion: "rs-1"}, nil
	}
	return f.Info()
}
