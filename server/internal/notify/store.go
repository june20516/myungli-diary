// Package notify는 job notify(spec §8.2, P8-4)입니다. 알림을 켠 사용자에게 현지 알림 시각 뒤 60분 안에
// 하루 한 번 그날 총운 머리 문장(호칭 없음)을 FCM HTTP v1로 보냅니다.
package notify

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/notify/notifydb"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// 발송 기록의 결과 값입니다(notification_log.result).
const (
	ResultSent   = "sent"
	ResultFailed = "failed"
)

// Candidate는 알림 대상 후보 한 명입니다.
type Candidate struct {
	AccountID uuid.UUID
	Profile   profile.Profile
}

// Device는 알림을 받을 활성 기기 하나입니다.
type Device struct {
	ID       uuid.UUID
	Token    string
	Platform string
}

// Store는 알림 후보, 발송 기록, 기기를 다룹니다.
type Store struct {
	pool *pgxpool.Pool
	q    *notifydb.Queries
}

// NewStore는 Store를 만듭니다.
func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool, q: notifydb.New(pool)}
}

// ListCandidates는 알림을 켰고 활성 기기가 있는 활동 계정을 계정 id 순으로 after 다음부터 limit명 줍니다.
func (s *Store) ListCandidates(ctx context.Context, after uuid.UUID, limit int32) ([]Candidate, error) {
	profiles, err := profile.ListNotifyProfiles(ctx, s.pool, after, limit)
	if err != nil {
		return nil, err
	}
	candidates := make([]Candidate, 0, len(profiles))
	for _, p := range profiles {
		candidates = append(candidates, Candidate{AccountID: p.AccountID, Profile: p.Profile})
	}
	return candidates, nil
}

// Claim은 (계정, 현지 날짜)의 발송 기록을 pending으로 넣습니다. 새로 넣었으면 true이고, 이미 있으면 false입니다.
func (s *Store) Claim(ctx context.Context, accountID uuid.UUID, localDate profile.LocalDate, now time.Time) (bool, error) {
	rows, err := s.q.ClaimNotification(ctx, notifydb.ClaimNotificationParams{
		AccountID: accountID, LocalDate: profile.PgDate(localDate), ClaimedAt: now,
	})
	if err != nil {
		return false, fmt.Errorf("알림 기록 claim: %w", err)
	}
	return rows == 1, nil
}

// Finish는 발송 기록의 결과를 result(ResultSent·ResultFailed)로 바꿉니다. sent면 sent_at에 now를 넣습니다.
func (s *Store) Finish(ctx context.Context, accountID uuid.UUID, localDate profile.LocalDate, result string, now time.Time) error {
	if err := s.q.FinishNotification(ctx, notifydb.FinishNotificationParams{
		Result: result, FinishedAt: now, AccountID: accountID, LocalDate: profile.PgDate(localDate),
	}); err != nil {
		return fmt.Errorf("알림 기록 결과: %w", err)
	}
	return nil
}

// ActiveDevices는 계정의 활성 기기를 최근에 본 순서로 줍니다.
func (s *Store) ActiveDevices(ctx context.Context, accountID uuid.UUID) ([]Device, error) {
	rows, err := s.q.ListActiveDevices(ctx, accountID)
	if err != nil {
		return nil, fmt.Errorf("활성 기기 조회: %w", err)
	}
	devices := make([]Device, 0, len(rows))
	for _, row := range rows {
		devices = append(devices, Device{ID: row.ID, Token: row.FcmToken, Platform: row.Platform})
	}
	return devices, nil
}

// Deactivate는 기기를 비활성으로 바꿉니다(FCM이 토큰을 무효라고 답했을 때, S92).
func (s *Store) Deactivate(ctx context.Context, deviceID uuid.UUID) error {
	if err := s.q.DeactivateDeviceByID(ctx, deviceID); err != nil {
		return fmt.Errorf("기기 비활성: %w", err)
	}
	return nil
}
