// Package account는 계정의 접근 상태, 약관 동의, 삭제 예약을 맡습니다.
package account

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/account/accountdb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const (
	// lastActiveInterval은 last_active_at을 다시 갱신하기까지의 최소 간격입니다(하루 1번까지).
	lastActiveInterval = 24 * time.Hour
	// deletionGracePeriod는 삭제 요청부터 익명화까지의 유예 기간입니다.
	deletionGracePeriod = 30 * 24 * time.Hour

	// pgForeignKeyViolation은 PostgreSQL의 foreign_key_violation SQLSTATE입니다.
	pgForeignKeyViolation = "23503"
)

// ErrNotFound는 계정이 없거나 이미 삭제(익명화)됐을 때 돌려줍니다.
var ErrNotFound = errors.New("account: not found")

// ConsentVersionMismatchError는 동의 요청 항목의 버전이 현재 버전과 다를 때의 오류입니다.
type ConsentVersionMismatchError struct {
	// Index는 요청 목록에서 처음 어긋난 항목의 위치입니다.
	Index int
}

// Error는 error 인터페이스를 만족시킵니다.
func (e *ConsentVersionMismatchError) Error() string {
	return fmt.Sprintf("account: consent version mismatch at index %d", e.Index)
}

// Status는 계정의 상태입니다.
type Status string

const (
	// StatusActive는 정상 계정입니다.
	StatusActive Status = "active"
	// StatusPendingDeletion은 삭제를 요청하고 유예 기간 중인 계정입니다.
	StatusPendingDeletion Status = "pending_deletion"
	// StatusDeleted는 익명화가 끝난 계정입니다.
	StatusDeleted Status = "deleted"
)

// Access는 요청마다 확인하는 계정 접근 상태입니다.
type Access struct {
	Status Status
	// DeletionScheduledAt은 삭제 대기 계정의 익명화 예정 시각입니다. 그 밖에는 nil입니다.
	DeletionScheduledAt *time.Time
	// ConsentRequired는 현재 버전 문서 중 아직 동의하지 않은 것이 있으면 true입니다.
	ConsentRequired bool
}

// ConsentDocument는 문서와 그 버전의 짝입니다.
type ConsentDocument struct {
	Document Document
	Version  string
}

// Me는 /v1/me 응답의 계정 부분입니다. 프로필 유무와 권한은 이후 단계가 채웁니다.
type Me struct {
	AccountID uuid.UUID
	Access
	// RequiredConsents는 아직 동의하지 않은 현재 버전 문서이며 문서 이름 순입니다.
	RequiredConsents []ConsentDocument
}

// SessionEnder는 계정 삭제 예약 뒤에 세션과 제공자 연결을 정리하는 의존성입니다. *auth.Service가 만족합니다.
type SessionEnder interface {
	RevokeAllSessions(ctx context.Context, accountID uuid.UUID) error
	// DisconnectProviders는 계정이 pending_deletion일 때만 기록하므로 상태 변경을 commit한 뒤에 불러야 합니다.
	DisconnectProviders(ctx context.Context, accountID uuid.UUID) error
}

// Service는 계정 접근 상태, 약관 동의, 삭제 예약을 처리합니다.
type Service struct {
	pool     *pgxpool.Pool
	queries  *accountdb.Queries
	sessions SessionEnder
	clk      clock.Clock
	logger   *slog.Logger
}

// NewService는 Service를 만듭니다.
func NewService(pool *pgxpool.Pool, sessions SessionEnder, clk clock.Clock, logger *slog.Logger) *Service {
	return &Service{pool: pool, queries: accountdb.New(pool), sessions: sessions, clk: clk, logger: logger}
}

// Access는 계정의 접근 상태를 돌려줍니다. 요청마다 불립니다.
// last_active_at이 now-24h보다 이전일 때만 갱신하므로 하루에 한 번까지만 쓰기가 일어납니다.
func (s *Service) Access(ctx context.Context, id uuid.UUID) (Access, error) {
	row, err := s.queries.GetAccountAccess(ctx, id)
	if err != nil {
		return Access{}, notFoundOr(err, "계정 조회")
	}
	now := s.clk.Now()
	if row.LastActiveAt.Before(now.Add(-lastActiveInterval)) {
		if _, err := s.queries.TouchLastActive(ctx, accountdb.TouchLastActiveParams{LastActiveAt: now, ID: id}); err != nil {
			return Access{}, fmt.Errorf("last_active_at 갱신: %w", err)
		}
	}
	missing, err := s.missingConsents(ctx, s.queries, id)
	if err != nil {
		return Access{}, err
	}
	return buildAccess(row, len(missing) > 0), nil
}

// Me는 /v1/me에 담을 계정 정보를 돌려줍니다.
func (s *Service) Me(ctx context.Context, id uuid.UUID) (Me, error) {
	row, err := s.queries.GetAccountAccess(ctx, id)
	if err != nil {
		return Me{}, notFoundOr(err, "계정 조회")
	}
	missing, err := s.missingConsents(ctx, s.queries, id)
	if err != nil {
		return Me{}, err
	}
	return Me{AccountID: id, Access: buildAccess(row, len(missing) > 0), RequiredConsents: missing}, nil
}

// AgreeConsents는 문서 동의를 저장합니다.
// 버전이 CurrentDocuments와 다른 항목이 있으면 아무것도 저장하지 않고 첫 항목의 *ConsentVersionMismatchError를 돌려줍니다.
// 이미 동의한 문서를 다시 동의해도 성공합니다.
func (s *Service) AgreeConsents(ctx context.Context, id uuid.UUID, docs []ConsentDocument) error {
	for i, d := range docs {
		if current, ok := CurrentDocuments[d.Document]; !ok || current != d.Version {
			return &ConsentVersionMismatchError{Index: i}
		}
	}
	now := s.clk.Now()
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := s.queries.WithTx(tx)
		for _, d := range docs {
			consentID, err := uuid.NewV7()
			if err != nil {
				return fmt.Errorf("동의 id 생성: %w", err)
			}
			if err := q.InsertConsent(ctx, accountdb.InsertConsentParams{
				ID: consentID, AccountID: id, Document: string(d.Document), Version: d.Version, AgreedAt: now,
			}); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == pgForeignKeyViolation {
			return ErrNotFound
		}
		return fmt.Errorf("동의 저장: %w", err)
	}
	return nil
}

// RequestDeletion은 active 계정을 pending_deletion으로 바꾸고 익명화 예정 시각(요청 시각 + 30일)을 돌려줍니다.
// 상태를 commit한 뒤 세션과 제공자 연결을 정리하며, 그 실패는 경고 로그만 남기고 성공으로 취급합니다.
// 이미 pending_deletion이면 아무것도 바꾸지 않고 기존 예정 시각을 돌려줍니다.
// 동시에 두 번 불려도 UPDATE가 갱신한 행 수가 1인 호출만 정리를 수행합니다.
func (s *Service) RequestDeletion(ctx context.Context, id uuid.UUID) (time.Time, error) {
	var (
		scheduled time.Time
		changed   bool
	)
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		// InTx가 fn을 다시 실행할 수 있으므로 결과를 먼저 초기화합니다.
		scheduled, changed = time.Time{}, false
		q := s.queries.WithTx(tx)

		now := s.clk.Now()
		rows, err := q.RequestDeletion(ctx, accountdb.RequestDeletionParams{DeletionRequestedAt: now, ID: id})
		if err != nil {
			return err
		}
		if rows == 1 {
			scheduled, changed = now.Add(deletionGracePeriod), true
			return nil
		}

		// 0행이면 계정이 없거나 이미 active가 아닙니다. 상태를 읽어 구분합니다.
		row, err := q.GetAccountAccess(ctx, id)
		if err != nil {
			return notFoundOr(err, "계정 조회")
		}
		if Status(row.Status) != StatusPendingDeletion || row.DeletionRequestedAt == nil {
			return ErrNotFound
		}
		scheduled = row.DeletionRequestedAt.Add(deletionGracePeriod)
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return time.Time{}, err
		}
		return time.Time{}, fmt.Errorf("삭제 예약: %w", err)
	}

	if changed {
		s.endSessions(ctx, id)
	}
	return scheduled, nil
}

// endSessions는 commit된 삭제 예약 뒤에 세션 폐기와 제공자 연결 해제를 시도합니다.
// 둘은 서로 독립이라 하나가 실패해도 다른 하나를 부르고, 실패는 계정 id와 오류 타입만 경고로 남깁니다.
func (s *Service) endSessions(ctx context.Context, id uuid.UUID) {
	if err := s.sessions.RevokeAllSessions(ctx, id); err != nil {
		s.logger.WarnContext(ctx, "삭제 예약 뒤 세션 폐기 실패", "accountId", id, "errorType", fmt.Sprintf("%T", err))
	}
	if err := s.sessions.DisconnectProviders(ctx, id); err != nil {
		s.logger.WarnContext(ctx, "삭제 예약 뒤 제공자 연결 해제 실패", "accountId", id, "errorType", fmt.Sprintf("%T", err))
	}
}

// missingConsents는 현재 버전 문서 중 동의 기록이 없는 것을 문서 이름 순으로 돌려줍니다.
func (s *Service) missingConsents(ctx context.Context, q *accountdb.Queries, id uuid.UUID) ([]ConsentDocument, error) {
	rows, err := q.ListConsents(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("동의 목록 조회: %w", err)
	}
	agreed := make(map[ConsentDocument]bool, len(rows))
	for _, r := range rows {
		agreed[ConsentDocument{Document: Document(r.Document), Version: r.Version}] = true
	}
	var missing []ConsentDocument
	for doc, version := range CurrentDocuments {
		if d := (ConsentDocument{Document: doc, Version: version}); !agreed[d] {
			missing = append(missing, d)
		}
	}
	sort.Slice(missing, func(i, j int) bool { return missing[i].Document < missing[j].Document })
	return missing, nil
}

// buildAccess는 조회 행을 Access로 바꿉니다.
func buildAccess(row accountdb.GetAccountAccessRow, consentRequired bool) Access {
	a := Access{Status: Status(row.Status), ConsentRequired: consentRequired}
	if row.DeletionRequestedAt != nil {
		t := row.DeletionRequestedAt.Add(deletionGracePeriod)
		a.DeletionScheduledAt = &t
	}
	return a
}

// notFoundOr는 행 없음을 ErrNotFound로, 그 밖의 오류를 맥락을 붙여 돌려줍니다.
func notFoundOr(err error, what string) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	return fmt.Errorf("%s: %w", what, err)
}
