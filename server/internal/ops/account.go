package ops

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/ops/opsdb"
)

// 계정 조회의 오류입니다.
var (
	// ErrAccountKey는 계정 id와 스토어 거래 id 중 정확히 하나만 주지 않았을 때입니다.
	ErrAccountKey = errors.New("계정 id와 스토어 거래 id 중 하나만 주어야 합니다")
	// ErrAccountNotFound는 찾는 계정이 없을 때입니다. 감사 행은 남습니다.
	ErrAccountNotFound = errors.New("계정을 찾을 수 없습니다")
)

// AmbiguousTransactionError는 같은 스토어 거래 id를 가진 구매가 둘 이상의 계정에 있을 때입니다.
// 계정 상세는 담지 않으므로 호출자는 계정 id로 다시 조회합니다. 감사 행은 남습니다.
type AmbiguousTransactionError struct {
	AccountIDs []uuid.UUID
}

func (e AmbiguousTransactionError) Error() string {
	return fmt.Sprintf("스토어 거래 id가 계정 %d개에 걸쳐 있습니다", len(e.AccountIDs))
}

// AccountKey는 조회할 계정을 찾는 열쇠입니다. 정확히 하나만 값이 있어야 합니다.
type AccountKey struct {
	AccountID        uuid.UUID
	StoreTransaction string
}

// AccountSummary는 문의 대응용 계정 상태입니다. 호칭, 출생 정보, 일기와 일정 본문, 제공자 subject, 알림 token은 담지 않습니다.
type AccountSummary struct {
	Account    AccountInfo        `json:"account"`
	Identities []IdentityInfo     `json:"identities"`
	Devices    []DeviceInfo       `json:"devices"`
	Status     billing.Status     `json:"status"`
	Grants     []billing.GrantRow `json:"grants"`
	Purchases  []PurchaseInfo     `json:"purchases"`
}

// AccountInfo는 계정 행의 지원용 칸입니다. 계정 상태는 active, deleted 둘뿐입니다.
type AccountInfo struct {
	ID           uuid.UUID  `json:"id"`
	Status       string     `json:"status"`
	CreatedAt    time.Time  `json:"createdAt"`
	DeletedAt    *time.Time `json:"deletedAt"`
	LastActiveAt time.Time  `json:"lastActiveAt"`
}

// IdentityInfo는 로그인 수단입니다. 연결을 떼면 행이 지워지므로 연결 해제 칸은 없습니다.
type IdentityInfo struct {
	Provider string    `json:"provider"`
	LinkedAt time.Time `json:"linkedAt"`
}

// DeviceInfo는 알림 기기입니다.
type DeviceInfo struct {
	Platform   string    `json:"platform"`
	Active     bool      `json:"active"`
	CreatedAt  time.Time `json:"createdAt"`
	LastSeenAt time.Time `json:"lastSeenAt"`
}

// PurchaseInfo는 구매 장부 한 건입니다. MergedFrom은 원래 구매한 계정이 조회 계정과 다를 때(계정 합치기로 옮겨 온 구매) 그 계정입니다.
type PurchaseInfo struct {
	ProductID       string     `json:"productId"`
	Store           string     `json:"store"`
	StorePurchaseID *string    `json:"storePurchaseId"`
	PurchasedAt     time.Time  `json:"purchasedAt"`
	RefundedAt      *time.Time `json:"refundedAt"`
	Production      bool       `json:"production"`
	MergedFrom      *uuid.UUID `json:"mergedFrom"`
}

// accountTarget은 계정 조회 감사 행의 target입니다. 조회에 쓴 열쇠와, 스토어 거래 id가 모호할 때 후보 계정 목록(candidates)을 남깁니다.
type accountTarget struct {
	AccountID        *uuid.UUID `json:"accountId,omitempty"`
	StoreTransaction string     `json:"storeTransaction,omitempty"`
	// Candidates는 스토어 거래 id가 모호할 때 후보 계정 id입니다.
	Candidates []uuid.UUID `json:"candidates,omitempty"`
}

// AccountSummary는 계정의 지원용 상태를 한 번에 돌려줍니다.
// 조회와 감사 행 쓰기가 한 트랜잭션이라, 감사 행이 커밋되지 않으면 결과를 돌려주지 않습니다.
// 계정을 못 찾거나 스토어 거래 id가 모호해도 감사 행은 커밋됩니다.
func (s *Service) AccountSummary(ctx context.Context, actor Actor, key AccountKey, reason string) (AccountSummary, error) {
	if err := validateActor(actor); err != nil {
		return AccountSummary{}, err
	}
	reason, err := ValidateReason(reason)
	if err != nil {
		return AccountSummary{}, err
	}
	target, err := newAccountTarget(key)
	if err != nil {
		return AccountSummary{}, err
	}

	auditID := uuid.New()
	var (
		summary   AccountSummary
		notFound  bool
		ambiguous []uuid.UUID
	)
	err = s.inTx(ctx, func(tx pgx.Tx) error {
		// 트랜잭션이 다시 실행될 수 있으므로 결과를 처음 상태로 돌립니다.
		summary, notFound, ambiguous = AccountSummary{}, false, nil
		auditTarget := target
		accountID := target.AccountID
		if accountID == nil {
			ids, err := opsdb.New(tx).ListOpsAccountsByStoreTransaction(ctx, pgtype.Text{String: target.StoreTransaction, Valid: true})
			if err != nil {
				return fmt.Errorf("스토어 거래 계정 조회: %w", err)
			}
			switch len(ids) {
			case 0:
			case 1:
				accountID = &ids[0]
			default:
				ambiguous = ids
				auditTarget.Candidates = ids
			}
		}

		if accountID != nil {
			found, err := s.loadSummary(ctx, tx, *accountID)
			if errors.Is(err, pgx.ErrNoRows) {
				accountID = nil
			} else if err != nil {
				return err
			} else {
				summary = found
			}
		}
		notFound = accountID == nil && ambiguous == nil

		return recordTx(ctx, tx, auditID, Entry{
			Actor: actor, Action: ActionAccountShow, AccountID: accountID, Reason: reason, Target: auditTarget,
		})
	})
	switch {
	case err != nil:
		return AccountSummary{}, err
	case ambiguous != nil:
		return AccountSummary{}, AmbiguousTransactionError{AccountIDs: ambiguous}
	case notFound:
		return AccountSummary{}, ErrAccountNotFound
	}
	return summary, nil
}

// newAccountTarget은 열쇠가 정확히 하나만 있는지 검사하고 감사 target으로 바꿉니다.
func newAccountTarget(key AccountKey) (accountTarget, error) {
	transaction := strings.TrimSpace(key.StoreTransaction)
	hasID := key.AccountID != uuid.Nil
	if hasID == (transaction != "") {
		return accountTarget{}, ErrAccountKey
	}
	if hasID {
		return accountTarget{AccountID: &key.AccountID}, nil
	}
	return accountTarget{StoreTransaction: transaction}, nil
}

// loadSummary는 계정 한 건의 지원용 상태를 tx 안에서 읽습니다. 계정이 없으면 pgx.ErrNoRows를 돌려줍니다.
// 권한 상태는 DB 시각 기준입니다.
func (s *Service) loadSummary(ctx context.Context, tx pgx.Tx, accountID uuid.UUID) (AccountSummary, error) {
	q := opsdb.New(tx)
	account, err := q.GetOpsAccount(ctx, accountID)
	if err != nil {
		return AccountSummary{}, err
	}
	now, err := s.now(ctx, tx)
	if err != nil {
		return AccountSummary{}, err
	}
	identities, err := q.ListOpsIdentities(ctx, accountID)
	if err != nil {
		return AccountSummary{}, fmt.Errorf("로그인 수단 조회: %w", err)
	}
	devices, err := q.ListOpsDevices(ctx, accountID)
	if err != nil {
		return AccountSummary{}, fmt.Errorf("기기 조회: %w", err)
	}
	purchases, err := q.ListOpsPurchases(ctx, accountID)
	if err != nil {
		return AccountSummary{}, fmt.Errorf("구매 장부 조회: %w", err)
	}
	grants, err := billing.ListGrantsTx(ctx, tx, accountID)
	if err != nil {
		return AccountSummary{}, err
	}

	if grants == nil {
		grants = []billing.GrantRow{}
	}
	summary := AccountSummary{
		Account: AccountInfo{
			ID: account.ID, Status: account.Status, CreatedAt: account.CreatedAt,
			DeletedAt: account.DeletedAt, LastActiveAt: account.LastActiveAt,
		},
		Identities: make([]IdentityInfo, 0, len(identities)),
		Devices:    make([]DeviceInfo, 0, len(devices)),
		Status:     billing.StatusAt(grants, now),
		Grants:     grants,
		Purchases:  make([]PurchaseInfo, 0, len(purchases)),
	}
	for _, identity := range identities {
		summary.Identities = append(summary.Identities, IdentityInfo{Provider: identity.Provider, LinkedAt: identity.CreatedAt})
	}
	for _, device := range devices {
		summary.Devices = append(summary.Devices, DeviceInfo{
			Platform: device.Platform, Active: device.Active, CreatedAt: device.CreatedAt, LastSeenAt: device.LastSeenAt,
		})
	}
	for _, purchase := range purchases {
		info := PurchaseInfo{
			ProductID: purchase.ProductID, Store: purchase.Store, PurchasedAt: purchase.PurchasedAt,
			RefundedAt: purchase.RefundedAt, Production: purchase.Production,
		}
		if purchase.StorePurchaseID.Valid {
			info.StorePurchaseID = &purchase.StorePurchaseID.String
		}
		if purchase.OriginalAccountID != accountID {
			original := purchase.OriginalAccountID
			info.MergedFrom = &original
		}
		summary.Purchases = append(summary.Purchases, info)
	}
	return summary, nil
}
