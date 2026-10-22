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

// entryStore는 Create가 쓰는 저장소 동작입니다. *Store가 만족하고, 테스트는 대역으로 바꿉니다.
type entryStore interface {
	DayExists(ctx context.Context, accountID uuid.UUID, date profile.LocalDate) (bool, error)
	CreateEntry(ctx context.Context, accountID uuid.UUID, date profile.LocalDate, body string, record *fortune.DayRecord) (Entry, error)
}

// Service는 일기 저장 규칙(미래 날짜 거절, 그날 첫 편에만 그날 기록)을 얹은 일기 서비스입니다.
// 조회·본문 수정·삭제·복원·목록은 Store로 그대로 넘깁니다.
type Service struct {
	entries entryStore
	store   *Store
	days    Days
	clk     clock.Clock
}

// NewService는 저장소·그날 기록·시계로 서비스를 만듭니다.
func NewService(store *Store, days Days, clk clock.Clock) *Service {
	return newServiceWith(store, store, days, clk)
}

// newServiceWith는 Create가 쓰는 저장소(entries)를 따로 받는 생성자입니다. 테스트가 대역을 끼울 때 씁니다.
func newServiceWith(entries entryStore, store *Store, days Days, clk clock.Clock) *Service {
	return &Service{entries: entries, store: store, days: days, clk: clk}
}

// Create는 date에 일기를 한 편 만듭니다.
// date가 p.CurrentTimezone 기준 오늘보다 뒤면 ErrFutureDate입니다(D30).
// 그날 첫 편일 때만 엔진을 불러 날짜 기록을 만들어 함께 저장하고, 둘째 편부터는 부르지 않습니다(D83).
func (s *Service) Create(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (Entry, error) {
	today, err := s.today(p.CurrentTimezone)
	if err != nil {
		return Entry{}, err
	}
	if date.After(today) {
		return Entry{}, ErrFutureDate
	}

	exists, err := s.entries.DayExists(ctx, accountID, date)
	if err != nil {
		return Entry{}, err
	}
	if !exists {
		return s.createWithNewRecord(ctx, accountID, p, date, body)
	}
	entry, err := s.entries.CreateEntry(ctx, accountID, date, body, nil)
	if errors.Is(err, ErrDayRecordMissing) {
		// 확인과 저장 사이에 날짜 기록이 지워졌습니다(익명화·합치기). 기록을 만들어 한 번만 다시 부릅니다.
		return s.createWithNewRecord(ctx, accountID, p, date, body)
	}
	return entry, err
}

// createWithNewRecord는 엔진으로 그날 기록을 만들어 일기와 함께 저장합니다(트랜잭션 밖에서 엔진을 부름).
// 그 사이 다른 요청이 날짜 기록을 먼저 넣었으면 먼저 넣은 기록이 남아 같은 날짜의 기록은 하나로 모입니다.
func (s *Service) createWithNewRecord(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, body string) (Entry, error) {
	record, err := s.days.DayRecord(ctx, accountID, p, date)
	if err != nil {
		return Entry{}, err
	}
	return s.entries.CreateEntry(ctx, accountID, date, body, &record)
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

// Get은 살아 있는 일기를 돌려줍니다. 없거나 남의 것이면 ErrNotFound입니다.
func (s *Service) Get(ctx context.Context, accountID, id uuid.UUID) (Entry, error) {
	return s.store.Get(ctx, accountID, id)
}

// UpdateBody는 살아 있는 일기의 본문만 바꿉니다. 엔진을 부르지 않습니다.
func (s *Service) UpdateBody(ctx context.Context, accountID, id uuid.UUID, body string) (Entry, error) {
	return s.store.UpdateBody(ctx, accountID, id, body)
}

// Delete는 일기를 지웁니다(soft delete).
func (s *Service) Delete(ctx context.Context, accountID, id uuid.UUID) error {
	return s.store.Delete(ctx, accountID, id)
}

// Restore는 지운 일기를 되살립니다. 그날 살아 있는 일기가 이미 MaxEntriesPerDay편이면 ErrDayFull입니다.
func (s *Service) Restore(ctx context.Context, accountID, id uuid.UUID) (Entry, error) {
	return s.store.Restore(ctx, accountID, id)
}

// List는 조건에 맞는 일기를 날짜 내림차순(같은 날짜는 작성 순)으로 돌려줍니다.
func (s *Service) List(ctx context.Context, accountID uuid.UUID, q ListQuery) ([]Entry, error) {
	return s.store.List(ctx, accountID, q)
}
