package schedule

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/profile"
)

// Service는 일정 규칙(조회 범위 상한, AllDay·Time 짝)을 얹은 일정 서비스입니다.
type Service struct {
	store *Store
}

// NewService는 저장소 위에 서비스를 만듭니다.
func NewService(store *Store) *Service {
	return &Service{store: store}
}

// List는 from부터 to까지(포함) 일정을 날짜 → 종일 먼저 → 시각 → 만든 순으로 돌려줍니다.
// from이 to보다 늦으면 ErrRangeReversed, 범위가 MaxRangeDays를 넘으면 ErrRangeTooLong입니다.
func (s *Service) List(ctx context.Context, accountID uuid.UUID, from, to profile.LocalDate) ([]Schedule, error) {
	if from.After(to) {
		return nil, ErrRangeReversed
	}
	if rangeDays(from, to) > MaxRangeDays {
		return nil, ErrRangeTooLong
	}
	return s.store.List(ctx, accountID, from, to)
}

// Create는 일정을 만듭니다. AllDay와 Time의 짝이 어긋나면 *profile.ValidationError입니다.
func (s *Service) Create(ctx context.Context, accountID uuid.UUID, in Input) (Schedule, error) {
	if err := checkPair(in.AllDay, in.Time); err != nil {
		return Schedule{}, err
	}
	in.Memo = emptyToNil(in.Memo)
	return s.store.Create(ctx, accountID, in)
}

// Update는 p를 적용한 결과로 일정을 고칩니다. 없는(남의 것·지운 것 포함) 일정은 ErrNotFound,
// 적용한 결과의 짝이 어긋나면 *profile.ValidationError입니다.
func (s *Service) Update(ctx context.Context, accountID, id uuid.UUID, p Patch) (Schedule, error) {
	return s.store.Update(ctx, accountID, id, p.apply)
}

// Delete는 일정을 지운 것으로 표시합니다(soft delete). 살아 있는 일정이 없으면 ErrNotFound입니다.
func (s *Service) Delete(ctx context.Context, accountID, id uuid.UUID) error {
	return s.store.Delete(ctx, accountID, id)
}

// Restore는 지운 일정을 되살립니다. 이미 살아 있는 일정이면 그대로 돌려주고(P5-5), 없으면 ErrNotFound입니다.
func (s *Service) Restore(ctx context.Context, accountID, id uuid.UUID) (Schedule, error) {
	return s.store.Restore(ctx, accountID, id)
}

// rangeDays는 from과 to를 모두 센 날짜 수입니다. 달력 날짜 차이라 UTC 자정끼리 뺍니다.
func rangeDays(from, to profile.LocalDate) int {
	start := time.Date(from.Year, time.Month(from.Month), from.Day, 0, 0, 0, 0, time.UTC)
	end := time.Date(to.Year, time.Month(to.Month), to.Day, 0, 0, 0, 0, time.UTC)
	return int(end.Sub(start)/(24*time.Hour)) + 1
}
