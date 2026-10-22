// Package merge는 계정 합치기(D85, S110·S111)를 맡습니다. A는 지금 로그인한 유저 계정, B는 합쳐져 지워지는 유저 계정입니다.
//
// 요약(Preview)은 B의 인증 증명을 검증하고, 옮겨질 기록·구매와 두 프로필을 요약해 합치기 토큰을 발급합니다.
// 토큰은 원문을 응답에만 주고 DB(account_merge_tickets)에는 SHA-256만 저장합니다.
// 실행(Execute)은 그 토큰으로 B의 기록·구매를 A로 옮기고 B를 지웁니다.
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

	"github.com/june20516/myungli-diary/server/internal/account"
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

// Profile은 합친 뒤 쓸 프로필입니다(계약 MergeProfile).
type Profile string

const (
	// ProfileCurrent는 A의 프로필을 그대로 둡니다.
	ProfileCurrent Profile = "current"
	// ProfileOther는 B의 프로필로 A의 프로필을 바꿉니다. B에 프로필이 없으면 합친 뒤 A는 프로필이 없습니다.
	ProfileOther Profile = "other"
)

// Service는 계정 합치기 서비스입니다. 여러 goroutine에서 동시에 써도 안전합니다.
type Service struct {
	pool     *pgxpool.Pool
	proofs   ProofVerifier
	profiles ProfileReader
	revoker  account.Revoker
	clock    clock.Clock
	logger   *slog.Logger
}

// NewService는 Service를 만듭니다. revoker는 B를 지운 뒤 허가 취소를 시도합니다. logger가 nil이면 아무것도 남기지 않습니다.
func NewService(pool *pgxpool.Pool, proofs ProofVerifier, profiles ProfileReader, revoker account.Revoker, clk clock.Clock, logger *slog.Logger) *Service {
	if logger == nil {
		logger = slog.New(slog.DiscardHandler)
	}
	return &Service{pool: pool, proofs: proofs, profiles: profiles, revoker: revoker, clock: clk, logger: logger}
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

// Execute는 합치기 토큰으로 B를 A(accountID)에 합칩니다(mergeAccounts, S111, spec §6.3).
//
// 한 트랜잭션에서 잠금 → 토큰 확인·소진 → 기록 → 프로필 → 구매 → B 삭제 순으로 처리하고, commit 뒤 B의 허가 취소를 시도합니다.
// 토큰이 없거나, 썼거나, 지났거나, A의 것이 아니거나, A·B가 active가 아니거나, 증명한 인증 계정이 B에서 떨어졌으면
// ErrTokenInvalid이고 아무것도 바꾸지 않습니다. A와 B가 서로를 동시에 합치면 잠금 순서 때문에 하나만 성공하고,
// 다른 쪽은 상대가 지워져(토큰 행도 함께 지워짐) ErrTokenInvalid입니다.
func (s *Service) Execute(ctx context.Context, accountID uuid.UUID, mergeToken string, chosen Profile) error {
	if chosen != ProfileCurrent && chosen != ProfileOther {
		return fmt.Errorf("합치기 프로필 선택 %q: 알 수 없는 값", chosen)
	}
	hash := token.HashRefreshToken(mergeToken)

	var (
		otherID       uuid.UUID
		revocationIDs []int64
	)
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		now := s.clock.Now()
		q := mergedb.New(tx)

		var err error
		otherID, err = s.lockAndConsume(ctx, tx, q, accountID, hash, now)
		if err != nil {
			return err
		}
		if err := moveRecords(ctx, q, accountID, otherID, chosen); err != nil {
			return err
		}
		if chosen == ProfileOther {
			if err := replaceProfile(ctx, q, accountID, otherID, now); err != nil {
				return err
			}
		}
		if err := billing.MovePurchasesTx(ctx, tx, otherID, accountID, now); err != nil {
			return fmt.Errorf("합치기 구매 옮기기: %w", err)
		}
		// B의 인증 계정·세션·rotation_state·consents·합치기 토큰(이번 토큰 포함) 등을 계정 삭제와 같이 지웁니다(D85 ④).
		// 이번 토큰은 이미 쓴 것으로 표시했고 응답에 쓰지 않으므로 지워져도 됩니다. 같은 요청의 재전송은 멱등 기록이 답합니다.
		revocationIDs, err = account.DeleteAccountTx(ctx, tx, otherID, now)
		if err != nil {
			return fmt.Errorf("합친 계정 삭제: %w", err)
		}
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrTokenInvalid) {
			return ErrTokenInvalid
		}
		return fmt.Errorf("계정 합치기: %w", err)
	}
	s.logger.InfoContext(ctx, "계정 합치기", "accountId", accountID, "otherAccountId", otherID, "revocations", len(revocationIDs))

	if len(revocationIDs) > 0 {
		// 이미 commit된 합치기의 뒷정리이므로, 클라이언트가 응답 전에 연결을 끊어 ctx가 취소돼도 끝까지 수행합니다.
		s.revoker.Attempt(context.WithoutCancel(ctx), revocationIDs)
	}
	return nil
}

// lockAndConsume은 A·B를 잠그고 토큰을 확인한 뒤 쓴 것으로 표시하고 B의 id를 돌려줍니다. 맞지 않으면 ErrTokenInvalid입니다.
//
// 잠금 순서: 결제 advisory lock(A·B)을 먼저 잡고, 그다음 A·B accounts 행을 id 순으로 FOR UPDATE로 잡습니다.
// 결제 동기화는 advisory lock을 쥔 채 구매 장부 INSERT의 FK 검사(accounts 행 KEY SHARE)로 계정 행을 기다리므로,
// 계정 행을 먼저 잡고 advisory lock을 기다리면 동기화와 서로를 기다리는 deadlock이 됩니다.
// 두 합치기(A→B, B→A)도 같은 순서로 잡으므로 뒤에 온 쪽은 앞 쪽이 끝난 뒤 지워진 상대와 토큰을 봅니다.
func (s *Service) lockAndConsume(ctx context.Context, tx pgx.Tx, q *mergedb.Queries, accountID uuid.UUID, hash []byte, now time.Time) (uuid.UUID, error) {
	// 잠글 계정을 정하려고 먼저 잠그지 않고 읽습니다. 토큰 행의 A·B는 바뀌지 않으므로 잠근 뒤 같은 A·B로 다시 확인합니다.
	ticket, err := q.MergeTicketAccounts(ctx, hash)
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, ErrTokenInvalid
	}
	if err != nil {
		return uuid.Nil, fmt.Errorf("합치기 토큰 조회: %w", err)
	}
	if ticket.AccountID != accountID {
		return uuid.Nil, ErrTokenInvalid
	}
	otherID := ticket.OtherAccountID

	if err := billing.LockAccountsTx(ctx, tx, accountID, otherID); err != nil {
		return uuid.Nil, fmt.Errorf("합치기 결제 잠금: %w", err)
	}
	accounts, err := q.LockMergeAccounts(ctx, []uuid.UUID{accountID, otherID})
	if err != nil {
		return uuid.Nil, fmt.Errorf("합치기 계정 잠금: %w", err)
	}
	if len(accounts) != 2 {
		return uuid.Nil, ErrTokenInvalid
	}
	for _, a := range accounts {
		if account.Status(a.Status) != account.StatusActive {
			return uuid.Nil, ErrTokenInvalid
		}
	}

	locked, err := q.LockMergeTicket(ctx, mergedb.LockMergeTicketParams{TokenHash: hash, AccountID: accountID, OtherAccountID: otherID})
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, ErrTokenInvalid
	}
	if err != nil {
		return uuid.Nil, fmt.Errorf("합치기 토큰 잠금: %w", err)
	}
	if locked.ConsumedAt != nil || !locked.ExpiresAt.After(now) {
		return uuid.Nil, ErrTokenInvalid
	}
	linked, err := q.IdentityLinkedTo(ctx, mergedb.IdentityLinkedToParams{IdentityID: locked.IdentityID, AccountID: otherID})
	if err != nil {
		return uuid.Nil, fmt.Errorf("합치기 인증 계정 확인: %w", err)
	}
	if !linked {
		return uuid.Nil, ErrTokenInvalid
	}
	if err := q.ConsumeMergeTicket(ctx, mergedb.ConsumeMergeTicketParams{Now: now, ID: locked.ID}); err != nil {
		return uuid.Nil, fmt.Errorf("합치기 토큰 소진: %w", err)
	}
	return otherID, nil
}

// moveRecords는 B의 기록(날짜 기록·일기·일정·문장 선택 기록과 반응)을 A로 옮깁니다(spec §6.3 2).
// 순서는 diaries_day_fk (account_id, date) 때문에 날짜 기록 → 일기입니다. B에 남는 날짜 기록은 B 삭제가 지웁니다.
func moveRecords(ctx context.Context, q *mergedb.Queries, accountID, otherID uuid.UUID, chosen Profile) error {
	if chosen == ProfileOther {
		if err := q.KeepOtherDiaryDays(ctx, mergedb.KeepOtherDiaryDaysParams{AccountID: accountID, OtherAccountID: otherID}); err != nil {
			return fmt.Errorf("겹친 날짜 기록 남기기: %w", err)
		}
	}
	if err := q.CopyOtherOnlyDiaryDays(ctx, mergedb.CopyOtherOnlyDiaryDaysParams{AccountID: accountID, OtherAccountID: otherID}); err != nil {
		return fmt.Errorf("날짜 기록 옮기기: %w", err)
	}
	if err := q.MoveDiaries(ctx, mergedb.MoveDiariesParams{AccountID: accountID, OtherAccountID: otherID}); err != nil {
		return fmt.Errorf("일기 옮기기: %w", err)
	}
	if err := q.MoveSchedules(ctx, mergedb.MoveSchedulesParams{AccountID: accountID, OtherAccountID: otherID}); err != nil {
		return fmt.Errorf("일정 옮기기: %w", err)
	}

	// 겹친 문장 선택 기록은 고른 프로필 쪽을 남기고, 다른 쪽 반응은 집계에 더한 뒤 그 선택과 함께 지웁니다.
	winner, loser := accountID, otherID
	if chosen == ProfileOther {
		winner, loser = otherID, accountID
	}
	if err := q.TallyOverlappingReactions(ctx, mergedb.TallyOverlappingReactionsParams{LoserAccountID: loser, WinnerAccountID: winner}); err != nil {
		return fmt.Errorf("겹친 반응 집계: %w", err)
	}
	if err := q.DeleteOverlappingReactions(ctx, mergedb.DeleteOverlappingReactionsParams{LoserAccountID: loser, WinnerAccountID: winner}); err != nil {
		return fmt.Errorf("겹친 반응 삭제: %w", err)
	}
	if err := q.DeleteOverlappingSelections(ctx, mergedb.DeleteOverlappingSelectionsParams{LoserAccountID: loser, WinnerAccountID: winner}); err != nil {
		return fmt.Errorf("겹친 문장 선택 기록 삭제: %w", err)
	}
	if err := q.MoveSelections(ctx, mergedb.MoveSelectionsParams{AccountID: accountID, OtherAccountID: otherID}); err != nil {
		return fmt.Errorf("문장 선택 기록 옮기기: %w", err)
	}
	return nil
}

// replaceProfile은 B의 프로필로 A의 프로필을 바꿉니다. B에 프로필이 없으면 A의 프로필을 지워 프로필 없음으로 둡니다.
func replaceProfile(ctx context.Context, q *mergedb.Queries, accountID, otherID uuid.UUID, now time.Time) error {
	copied, err := q.ReplaceProfileWithOther(ctx, mergedb.ReplaceProfileWithOtherParams{AccountID: accountID, Now: now, OtherAccountID: otherID})
	if err != nil {
		return fmt.Errorf("프로필 바꾸기: %w", err)
	}
	if copied > 0 {
		return nil
	}
	if err := q.DeleteProfile(ctx, accountID); err != nil {
		return fmt.Errorf("프로필 지우기: %w", err)
	}
	return nil
}
