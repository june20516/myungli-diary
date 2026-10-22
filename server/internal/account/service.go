// Package account는 계정의 접근 상태, 약관 동의, 계정 삭제를 맡습니다.
package account

import (
	"context"
	"errors"
	"fmt"
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
	// deletionGracePeriod는 옛 삭제 예약의 유예 기간입니다. 삭제 대기 계정이 남아 있는 동안 예정 시각 계산에만 씁니다.
	deletionGracePeriod = 30 * 24 * time.Hour

	// pgForeignKeyViolation은 PostgreSQL의 foreign_key_violation SQLSTATE입니다.
	pgForeignKeyViolation = "23503"
)

// ErrNotFound는 계정 행이 없을 때 돌려줍니다.
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
	// StatusPendingDeletion은 옛 삭제 예약으로 유예 기간 중인 계정입니다. 새로 만들지 않으며, 삭제 대기 경로를 없앨 때 함께 없앱니다.
	StatusPendingDeletion Status = "pending_deletion"
	// StatusDeleted는 개인 데이터를 지우고 껍데기만 남은 계정입니다.
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

// Service는 계정 접근 상태, 약관 동의, 계정 삭제를 처리합니다.
type Service struct {
	pool    *pgxpool.Pool
	queries *accountdb.Queries
	revoker Revoker
	clk     clock.Clock
}

// NewService는 Service를 만듭니다. revoker는 계정 삭제 뒤 허가 취소를 시도합니다.
func NewService(pool *pgxpool.Pool, revoker Revoker, clk clock.Clock) *Service {
	return &Service{pool: pool, queries: accountdb.New(pool), revoker: revoker, clk: clk}
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
