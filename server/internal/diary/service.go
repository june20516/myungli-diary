package diary

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// ErrFutureDate는 오늘(프로필 시간대 기준) 이후 날짜에 일기를 쓰려 할 때 돌려줍니다.
var ErrFutureDate = errors.New("오늘 이후 날짜에는 일기를 쓸 수 없습니다")

// Days는 일기를 처음 쓸 때 같이 적는 그날 엔진 결과의 기록을 만듭니다. *fortune.Views가 만족합니다.
type Days interface {
	DayRecord(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (fortune.DayRecord, error)
}

// Service는 일기 저장 규칙(미래 날짜 거절, 처음 쓸 때 그날 기록)을 얹은 일기 서비스입니다.
// 조회·삭제·복원·목록은 Store로 그대로 넘깁니다.
type Service struct {
	store *Store
	days  Days
	clk   clock.Clock
}

// NewService는 저장소·그날 기록·시계로 서비스를 만듭니다.
func NewService(store *Store, days Days, clk clock.Clock) *Service {
	return &Service{store: store, days: days, clk: clk}
}

// Put은 date의 일기 본문을 저장합니다. 새로 만들었으면 created가 true입니다.
// date가 p.CurrentTimezone 기준 오늘보다 뒤면 ErrFutureDate입니다(D30).
// 이미 있는 일기는 엔진을 부르지 않고 본문만 바꿉니다(P5-1). 없을 때만 그날 기록을 만들어 함께 저장합니다.
func (s *Service) Put(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (Entry, bool, error) {
	today, err := s.today(p.CurrentTimezone)
	if err != nil {
		return Entry{}, false, err
	}
	if isAfter(date, today) {
		return Entry{}, false, ErrFutureDate
	}

	_, err = s.store.Get(ctx, accountID, date)
	switch {
	case err == nil:
		return s.store.Upsert(ctx, accountID, Entry{Date: date, Body: body}) // 본문만 바뀝니다.
	case errors.Is(err, ErrNotFound):
		return s.createWithRecord(ctx, accountID, p, date, body)
	default:
		return Entry{}, false, err
	}
}

// createWithRecord는 그날 기록을 만들어 새 일기로 저장합니다.
// 그 사이 다른 기기가 먼저 만들었으면 Upsert가 본문만 고치므로 결과는 같습니다.
func (s *Service) createWithRecord(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (Entry, bool, error) {
	record, err := s.days.DayRecord(ctx, accountID, p, date)
	if err != nil {
		return Entry{}, false, err
	}
	return s.store.Upsert(ctx, accountID, Entry{
		Date:           date,
		Body:           body,
		AllTags:        record.AllTags,
		Featured:       record.Featured,
		GuideQuestion:  record.GuideQuestion,
		RulesetVersion: record.RulesetVersion,
	})
}

// today는 timezone 기준 오늘 날짜입니다.
func (s *Service) today(timezone string) (profile.LocalDate, error) {
	loc, err := time.LoadLocation(timezone) // 프로필 저장 때 검사를 통과한 이름입니다.
	if err != nil {
		return profile.LocalDate{}, errors.New("시간대 로드 실패") // 오류에 시간대 이름이 들어 있어 감싸지 않습니다.
	}
	now := s.clk.Now().In(loc)
	return profile.LocalDate{Year: now.Year(), Month: int(now.Month()), Day: now.Day()}, nil
}

// isAfter는 a가 b보다 뒤 날짜인지 봅니다.
func isAfter(a, b profile.LocalDate) bool {
	if a.Year != b.Year {
		return a.Year > b.Year
	}
	if a.Month != b.Month {
		return a.Month > b.Month
	}
	return a.Day > b.Day
}

// Get은 그 날짜의 살아 있는 일기를 돌려줍니다. 없으면 ErrNotFound입니다.
func (s *Service) Get(ctx context.Context, accountID uuid.UUID, date profile.LocalDate) (Entry, error) {
	return s.store.Get(ctx, accountID, date)
}

// Delete는 그 날짜의 일기를 지웁니다(soft delete).
func (s *Service) Delete(ctx context.Context, accountID uuid.UUID, date profile.LocalDate) error {
	return s.store.Delete(ctx, accountID, date)
}

// Restore는 그 날짜에 가장 늦게 지운 일기를 되살립니다.
func (s *Service) Restore(ctx context.Context, accountID uuid.UUID, date profile.LocalDate) (Entry, error) {
	return s.store.Restore(ctx, accountID, date)
}

// List는 조건에 맞는 일기를 날짜 내림차순으로 돌려줍니다.
func (s *Service) List(ctx context.Context, accountID uuid.UUID, q ListQuery) ([]Entry, error) {
	return s.store.List(ctx, accountID, q)
}
