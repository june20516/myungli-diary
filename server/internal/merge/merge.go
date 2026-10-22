// Package merge는 계정 합치기(D85, S110·S111)를 맡습니다. A는 지금 로그인한 유저 계정, B는 합쳐져 지워지는 유저 계정입니다.
//
// 요약(Preview)은 B의 인증 증명을 검증하고, 옮겨질 기록·구매와 두 프로필을 요약해 합치기 토큰을 발급합니다.
// 토큰은 원문을 응답에만 주고 DB(account_merge_tickets)에는 SHA-256만 저장합니다.
//
// 로그에는 계정 id와 제공자 이름만 남깁니다. id_token·nonce·subject·합치기 토큰 원문·호칭·출생 정보는 남기지 않습니다.
package merge

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/merge/mergedb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// MergeTicketTTL은 합치기 토큰의 유효 시간입니다(spec §6.2).
const MergeTicketTTL = 10 * time.Minute

// day는 남은 날을 셀 때의 하루 길이입니다.
const day = 24 * time.Hour

var (
	// ErrSameAccount는 증명한 인증 계정이 현재 유저 계정(A)에 이미 연결된 경우입니다(422 merge.same_account).
	ErrSameAccount = errors.New("merge: same account")
	// ErrNoAccount는 증명한 인증 계정이 어느 유저 계정에도 연결되지 않은 경우입니다(422 merge.no_account). 연결로 넘어가지 않습니다.
	ErrNoAccount = errors.New("merge: no account")
	// ErrTokenInvalid는 합치기 토큰이 없거나, 썼거나, 지났거나, 다른 bearer의 것이거나, B가 지워진 경우입니다(422 merge.token_invalid).
	ErrTokenInvalid = errors.New("merge: token invalid")
)

// ProofVerifier는 B의 인증 증명을 검증하고 그 인증 계정과 유저 계정을 찾습니다. *auth.Service가 만족합니다.
type ProofVerifier interface {
	VerifyProof(ctx context.Context, providerName string, proof auth.LinkProof) (identityID, accountID uuid.UUID, found bool, err error)
}

var _ ProofVerifier = (*auth.Service)(nil)

// ProfileReader는 프로필을 읽습니다. 없으면 profile.ErrNotFound입니다. *profile.Service가 만족합니다.
type ProfileReader interface {
	Get(ctx context.Context, accountID uuid.UUID) (profile.Profile, error)
}

var _ ProfileReader = (*profile.Service)(nil)

// ProfileSummary는 합칠 때 고를 수 있는 프로필 요약입니다. Saved가 false면 프로필이 없고 Honorific·Birth는 비어 있습니다.
type ProfileSummary struct {
	Saved     bool
	Honorific string
	Birth     profile.Birth
}

// Summary는 합치면 B에서 A로 옮겨지거나 더해지는 것의 요약입니다(계약 MergeSummary).
type Summary struct {
	// Diaries·Schedules는 지운 것을 포함한 B의 일기·일정 수입니다.
	Diaries, Schedules int
	// DateRecords는 A와 날짜가 겹치지 않는 B의 날짜 기록 수이고, OverlapDays는 두 계정 모두 날짜 기록이 있는 날 수입니다.
	DateRecords int
	// Reactions는 B의 살아 있는 문장 반응 수입니다.
	Reactions   int
	OverlapDays int
	// AddedDays는 권한마다 B의 기간 상품 남은 날(일 단위 올림)입니다. 남은 구간이 없는 권한은 키가 없습니다.
	AddedDays map[billing.Entitlement]int
	// Current는 A, Other는 B의 프로필 요약입니다.
	Current, Other ProfileSummary
}

// Service는 계정 합치기 서비스입니다. 여러 goroutine에서 동시에 써도 안전합니다.
type Service struct {
	pool     *pgxpool.Pool
	proofs   ProofVerifier
	profiles ProfileReader
	clock    clock.Clock
	logger   *slog.Logger
}

// NewService는 Service를 만듭니다. logger가 nil이면 아무것도 남기지 않습니다.
func NewService(pool *pgxpool.Pool, proofs ProofVerifier, profiles ProfileReader, clk clock.Clock, logger *slog.Logger) *Service {
	if logger == nil {
		logger = slog.New(slog.DiscardHandler)
	}
	return &Service{pool: pool, proofs: proofs, profiles: profiles, clock: clk, logger: logger}
}

// Preview는 B의 증명을 검증하고, A(accountID)와 B를 합칠 때의 요약과 합치기 토큰을 돌려줍니다(previewMerge, S110).
//
// 증명 오류는 연결(linkIdentity)과 같은 auth sentinel입니다. 증명한 인증 계정이 A에 연결돼 있으면 ErrSameAccount,
// 어디에도 없으면 ErrNoAccount이고, 둘 다 토큰을 만들지 않습니다. 옮길 기록이 없어도 요약과 토큰을 줍니다.
//
// 토큰은 부를 때마다 새로 발급합니다. 한 트랜잭션에서 그 인증 계정과 B를 공유 잠금으로 확인한 뒤 토큰을 넣고 기록을 셉니다.
// 검증과 이 트랜잭션 사이에 B가 그 인증 계정을 떼거나 지워졌으면 ErrNoAccount입니다.
func (s *Service) Preview(ctx context.Context, accountID uuid.UUID, providerName string, proof auth.LinkProof) (string, time.Time, Summary, error) {
	identityID, otherID, found, err := s.proofs.VerifyProof(ctx, providerName, proof)
	if err != nil {
		return "", time.Time{}, Summary{}, err
	}
	if !found {
		return "", time.Time{}, Summary{}, ErrNoAccount
	}
	if otherID == accountID {
		return "", time.Time{}, Summary{}, ErrSameAccount
	}

	// 합치기 토큰은 refresh token과 같은 방식(32바이트 난수 base64url, SHA-256 저장)입니다.
	raw, hash, err := token.NewRefreshToken()
	if err != nil {
		return "", time.Time{}, Summary{}, fmt.Errorf("합치기 토큰 생성: %w", err)
	}
	now := s.clock.Now()
	// DB 정밀도(마이크로초)로 맞춰 응답과 저장 값이 같게 합니다.
	expiresAt := now.Add(MergeTicketTTL).Truncate(time.Microsecond)

	var summary Summary
	err = postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		summary = Summary{}
		q := mergedb.New(tx)
		owner, err := q.LockActiveIdentityAccount(ctx, identityID)
		if errors.Is(err, pgx.ErrNoRows) || (err == nil && owner != otherID) {
			return ErrNoAccount
		}
		if err != nil {
			return fmt.Errorf("합치기 인증 계정 확인: %w", err)
		}
		if err := q.InsertMergeTicket(ctx, mergedb.InsertMergeTicketParams{
			ID:             uuid.Must(uuid.NewV7()),
			TokenHash:      hash,
			AccountID:      accountID,
			OtherAccountID: otherID,
			IdentityID:     identityID,
			ExpiresAt:      expiresAt,
		}); err != nil {
			return fmt.Errorf("합치기 토큰 저장: %w", err)
		}
		summary, err = countSummary(ctx, q, accountID, otherID, now)
		return err
	})
	if err != nil {
		if errors.Is(err, ErrNoAccount) {
			return "", time.Time{}, Summary{}, ErrNoAccount
		}
		return "", time.Time{}, Summary{}, err
	}

	if summary.Current, err = s.profileSummary(ctx, accountID); err != nil {
		return "", time.Time{}, Summary{}, err
	}
	if summary.Other, err = s.profileSummary(ctx, otherID); err != nil {
		return "", time.Time{}, Summary{}, err
	}
	s.logger.InfoContext(ctx, "합치기 토큰 발급", "accountId", accountID, "otherAccountId", otherID, "provider", providerName)
	return raw, expiresAt, summary, nil
}

// countSummary는 B에서 A로 옮길 기록 수와 더해질 남은 날을 셉니다. 프로필은 채우지 않습니다.
func countSummary(ctx context.Context, q *mergedb.Queries, accountID, otherID uuid.UUID, now time.Time) (Summary, error) {
	counts, err := q.CountMovableRecords(ctx, mergedb.CountMovableRecordsParams{AccountID: accountID, OtherAccountID: otherID})
	if err != nil {
		return Summary{}, fmt.Errorf("옮길 기록 세기: %w", err)
	}
	grants, err := q.ListRemainingPassGrants(ctx, mergedb.ListRemainingPassGrantsParams{AccountID: otherID, Now: now})
	if err != nil {
		return Summary{}, fmt.Errorf("남은 사용 구간 조회: %w", err)
	}
	return Summary{
		Diaries:     int(counts.Diaries),
		Schedules:   int(counts.Schedules),
		DateRecords: int(counts.DateRecords),
		Reactions:   int(counts.Reactions),
		OverlapDays: int(counts.OverlapDays),
		AddedDays:   remainingDays(grants, now),
	}, nil
}

// remainingDays는 권한마다 아직 끝나지 않은 구간의 남은 길이(expires_at - max(starts_at, now)) 합을 일 단위로 올려 돌려줍니다.
// 합치기가 B 구간을 now에서 끊고 그 남은 길이로 A 구간을 붙이는 계산(spec §5.3)과 같은 길이입니다.
func remainingDays(grants []mergedb.ListRemainingPassGrantsRow, now time.Time) map[billing.Entitlement]int {
	remaining := make(map[billing.Entitlement]time.Duration)
	for _, g := range grants {
		start := g.StartsAt
		if start.Before(now) {
			start = now
		}
		remaining[billing.Entitlement(g.Entitlement)] += g.ExpiresAt.Sub(start)
	}
	days := make(map[billing.Entitlement]int, len(remaining))
	for entitlement, d := range remaining {
		whole := int(d / day)
		if d%day != 0 {
			whole++
		}
		days[entitlement] = whole
	}
	return days
}

// profileSummary는 계정의 프로필 요약입니다. 프로필이 없으면 Saved가 false입니다.
func (s *Service) profileSummary(ctx context.Context, accountID uuid.UUID) (ProfileSummary, error) {
	p, err := s.profiles.Get(ctx, accountID)
	if errors.Is(err, profile.ErrNotFound) {
		return ProfileSummary{}, nil
	}
	if err != nil {
		return ProfileSummary{}, fmt.Errorf("합치기 프로필 조회: %w", err)
	}
	return ProfileSummary{Saved: true, Honorific: p.Honorific, Birth: p.Birth}, nil
}
