package auth

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// MergeTicketTTL은 합치기 토큰의 수명입니다(S101). 붙이기가 409로 끝난 뒤 사용자가 요약을 보고 합치기를 고를 시간입니다.
const MergeTicketTTL = 10 * time.Minute

// LinkedIdentity는 계정에 붙은 제공자 연결 하나입니다. subject는 내보내지 않습니다.
type LinkedIdentity struct {
	Provider string
	// LinkedAt은 연결을 만든 시각(auth_identities.created_at)입니다.
	LinkedAt time.Time
}

// LinkProof는 붙이기 증명입니다. 그 제공자의 로그인 증명과 같습니다(spec §3.1).
//
//   - 카카오·LINE·Google: IDToken, RawNonce
//   - Apple iOS: IDToken, AuthorizationCode, RawNonce
//   - Apple 웹 흐름(Android): ExchangeCode(appleCallback이 만든 교환 코드), RawNonce
type LinkProof struct {
	IDToken           string
	RawNonce          string
	AuthorizationCode string
	ExchangeCode      string
}

// LinkResult는 붙이기 결과입니다. Created는 연결을 새로 만들었는지(201)이고, false면 이미 현재 계정에 있던 연결입니다(200).
type LinkResult struct {
	Created bool
}

// 증명 필드의 JSON Pointer입니다. InvalidProofError.Field에 담습니다.
const (
	proofFieldIDToken           = "/idToken"
	proofFieldAuthorizationCode = "/authorizationCode"
	proofFieldExchangeCode      = "/exchangeCode"
	proofFieldNonce             = "/nonce"
)

// 제공자별 증명에 있어야 하는 필드입니다. 여기에 없는 필드가 오면 additionalProperties입니다.
var (
	idTokenProofFields     = []string{proofFieldIDToken, proofFieldNonce}
	appleNativeProofFields = []string{proofFieldIDToken, proofFieldAuthorizationCode, proofFieldNonce}
	appleWebProofFields    = []string{proofFieldExchangeCode, proofFieldNonce}
)

// ListIdentities는 계정의 제공자 연결을 붙인 순으로 돌려줍니다.
func (s *Service) ListIdentities(ctx context.Context, accountID uuid.UUID) ([]LinkedIdentity, error) {
	rows, err := authdb.New(s.pool).ListAccountIdentities(ctx, accountID)
	if err != nil {
		return nil, fmt.Errorf("연결 목록 조회: %w", err)
	}
	identities := make([]LinkedIdentity, 0, len(rows))
	for _, row := range rows {
		identities = append(identities, LinkedIdentity{Provider: row.Provider, LinkedAt: row.CreatedAt})
	}
	return identities, nil
}

// LinkIdentity는 현재 계정에 제공자 연결을 붙입니다(S100). providerName은 kakao·apple·line·google입니다.
//
// 증명 필드 조합을 먼저 검사하고(맞지 않으면 *InvalidProofError, errors.Is(err, ErrInvalidProof)), 트랜잭션 밖에서
// 제공자 검증을 마칩니다(iOS Apple은 code 교환까지). 그 뒤 한 트랜잭션에서 현재 계정 행을 잠그고 연결을 찾습니다.
//
//   - 어디에도 없음: 현재 계정에 같은 제공자 연결이 있으면 ErrProviderTaken, 없으면 연결을 만들고 Created=true
//   - 현재 계정에 있음: 바꾸지 않고 Created=false(Apple이면 refresh token만 새 값으로)
//   - 다른 active 계정에 있음: 합치기 토큰을 저장해 commit한 뒤 *IdentityInUseError
//   - 삭제 대기 계정에 있음: ErrIdentityPendingDeletion
//
// 같은 연결을 두 계정이 동시에 붙이면 한쪽이 (provider, subject) unique 위반을 받습니다. 그쪽은 트랜잭션을 한 번 다시
// 실행해 *IdentityInUseError가 됩니다(로그인의 동시 첫 로그인 처리와 같은 방식).
//
// Apple 웹 흐름은 교환 코드를 CompleteAppleWebLogin과 같은 규칙(appleWebTarget)으로 트랜잭션 안에서 소진합니다.
// 코드가 틀리거나 nonce가 맞지 않으면 ErrExchangeInvalid이며 코드는 소진되지 않습니다.
// 교환 코드는 in-use면 commit되므로 토큰 행과 함께 소진되고, provider_taken·삭제 대기면 rollback으로 남습니다.
//
// iOS Apple에서 교환한 refresh token을 저장하지 못하면 LoginApple과 같이 revokeUnsavedAppleGrant 규칙을 따릅니다
// (그 subject의 연결 행이 없을 때만 revoke). 다른 계정에 연결이 있는 경우(in-use)는 연결 행이 있으므로 revoke하지 않고 버립니다.
func (s *Service) LinkIdentity(ctx context.Context, accountID uuid.UUID, providerName string, proof LinkProof) (LinkResult, error) {
	if err := checkLinkProof(providerName, proof); err != nil {
		return LinkResult{}, err
	}
	verified, err := s.verifyLinkProof(ctx, providerName, proof)
	if err != nil {
		return LinkResult{}, err
	}

	result, err := s.link(ctx, accountID, providerName, verified.prepare)
	var inUse *IdentityInUseError
	switch {
	case err == nil:
		return result, nil
	case errors.As(err, &inUse):
		s.logger.InfoContext(ctx, "다른 계정의 연결이어서 합치기 토큰 발급", "accountId", accountID, "provider", providerName)
		return LinkResult{}, inUse
	case errors.Is(err, ErrExchangeInvalid):
		s.logger.InfoContext(ctx, "Apple 웹 흐름 붙이기 교환 코드 거절", "provider", providerApple, "step", "link_web")
		return LinkResult{}, ErrExchangeInvalid
	default:
		if verified.appleGrant != nil {
			s.revokeUnsavedAppleGrant(ctx, verified.appleSubject, verified.appleGrant)
		}
		return LinkResult{}, fmt.Errorf("%s 붙이기: %w", providerName, err)
	}
}

// checkLinkProof는 제공자에 맞는 증명 필드 조합인지 검사합니다. 제공자를 부르기 전에 합니다.
// 빠진 필드를 먼저 보고, 그 다음 그 제공자가 쓰지 않는 필드를 봅니다. 문제가 된 첫 필드 하나를 돌려줍니다.
// Apple은 IDToken·AuthorizationCode 중 하나라도 있거나 ExchangeCode가 없으면 iOS 흐름으로, 그 밖에는 웹 흐름으로 봅니다.
func checkLinkProof(providerName string, proof LinkProof) error {
	var want []string
	switch providerName {
	case providerKakao, providerLine, providerGoogle:
		want = idTokenProofFields
	case providerApple:
		if proof.IDToken == "" && proof.AuthorizationCode == "" && proof.ExchangeCode != "" {
			want = appleWebProofFields
		} else {
			want = appleNativeProofFields
		}
	default:
		return fmt.Errorf("붙일 수 없는 제공자 %q", providerName)
	}

	given := []struct {
		field string
		set   bool
	}{
		{proofFieldIDToken, proof.IDToken != ""},
		{proofFieldAuthorizationCode, proof.AuthorizationCode != ""},
		{proofFieldExchangeCode, proof.ExchangeCode != ""},
		{proofFieldNonce, proof.RawNonce != ""},
	}
	for _, g := range given {
		if slices.Contains(want, g.field) && !g.set {
			return &InvalidProofError{Field: g.field, Code: proofCodeRequired}
		}
	}
	for _, g := range given {
		if !slices.Contains(want, g.field) && g.set {
			return &InvalidProofError{Field: g.field, Code: proofCodeAdditionalProperties}
		}
	}
	return nil
}

// verifiedLink는 트랜잭션 전에 검증을 마친 붙이기 증명입니다.
type verifiedLink struct {
	// prepare는 붙이기 트랜잭션 안에서 붙일 연결을 정합니다.
	prepare prepareLogin
	// appleSubject·appleGrant는 iOS Apple의 code 교환 결과입니다. 저장하지 못했을 때 정리(revokeUnsavedAppleGrant)에 씁니다.
	appleSubject string
	appleGrant   *appleGrant
}

// verifyLinkProof는 증명을 제공자에게 검증합니다. 오류는 로그인과 같은 sentinel(providerError)입니다.
// Apple 웹 흐름은 검증이 이미 콜백에서 끝났으므로 여기서는 제공자를 부르지 않습니다.
func (s *Service) verifyLinkProof(ctx context.Context, providerName string, proof LinkProof) (verifiedLink, error) {
	switch providerName {
	case providerApple:
		if proof.ExchangeCode != "" {
			return verifiedLink{prepare: s.appleWebTarget(proof.ExchangeCode, proof.RawNonce)}, nil
		}
		subject, grant, err := s.verifyAppleNative(ctx, proof.IDToken, proof.AuthorizationCode, proof.RawNonce)
		if err != nil {
			return verifiedLink{}, err
		}
		return verifiedLink{prepare: fixedTarget(subject, grant), appleSubject: subject, appleGrant: grant}, nil
	default:
		verifier, err := s.idTokenVerifier(providerName)
		if err != nil {
			return verifiedLink{}, err
		}
		identity, err := verifier.Verify(ctx, proof.IDToken, proof.RawNonce)
		if err != nil {
			return verifiedLink{}, s.providerError(ctx, err, providerName, "verify")
		}
		return verifiedLink{prepare: fixedTarget(identity.Subject, nil)}, nil
	}
}

// idTokenVerifier는 id_token만으로 검증하는 제공자(카카오·LINE·Google)의 검증기를 돌려줍니다.
func (s *Service) idTokenVerifier(providerName string) (IDTokenVerifier, error) {
	switch providerName {
	case providerKakao:
		return s.kakao, nil
	case providerLine:
		return s.line, nil
	case providerGoogle:
		return s.google, nil
	default:
		return nil, fmt.Errorf("id_token 검증기가 없는 제공자 %q", providerName)
	}
}

// link는 붙이기 트랜잭션을 실행합니다. 아래 두 경합이면 한 번 다시 실행합니다.
//
//   - (provider, subject) unique 위반: 같은 연결을 동시에 붙인 쪽이 먼저 commit했습니다. 다시 실행하면 그 연결을 찾아
//     in-use(같은 계정이면 Created=false)가 됩니다.
//   - 합치기 토큰의 identity_id FK 위반: 다른 계정이 그 연결을 떼는 중이었습니다. GetIdentityForLink가 계정 행 잠금을
//     기다린 뒤 다시 확인하는 것은 계정 행뿐이라, 이미 지워진 연결 행을 돌려줄 수 있습니다. 다시 실행하면 연결이 없으므로 Created가 됩니다.
func (s *Service) link(ctx context.Context, accountID uuid.UUID, providerName string, prepare prepareLogin) (LinkResult, error) {
	result, err := s.linkOnce(ctx, accountID, providerName, prepare)
	if isIdentityConflict(err) || isMergeTicketIdentityGone(err) {
		result, err = s.linkOnce(ctx, accountID, providerName, prepare)
	}
	return result, err
}

// linkOnce는 붙이기 트랜잭션 한 번입니다. in-use면 합치기 토큰을 남겨야 하므로 오류를 돌려주지 않고 commit한 뒤
// *IdentityInUseError를 돌려줍니다(Refresh의 재사용 처리와 같은 방식).
func (s *Service) linkOnce(ctx context.Context, accountID uuid.UUID, providerName string, prepare prepareLogin) (LinkResult, error) {
	var (
		result LinkResult
		inUse  *IdentityInUseError
	)
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		// InTx가 다시 실행할 수 있으므로 결과를 매번 새로 채웁니다.
		result, inUse = LinkResult{}, nil
		q := authdb.New(tx)
		now := s.clock.Now()

		// 현재 계정 행을 먼저 잠가, 같은 계정의 붙이기·떼기가 한 줄로 처리되게 합니다.
		if err := lockActiveAccount(ctx, q, accountID); err != nil {
			return err
		}
		target, err := prepare(ctx, q, now)
		if err != nil {
			return err
		}
		existing, err := q.GetIdentityForLink(ctx, authdb.GetIdentityForLinkParams{Provider: providerName, Subject: target.subject})
		if errors.Is(err, pgx.ErrNoRows) {
			if err := s.createLinkedIdentity(ctx, q, accountID, providerName, target); err != nil {
				return err
			}
			result = LinkResult{Created: true}
			return nil
		}
		if err != nil {
			return fmt.Errorf("identity 조회: %w", err)
		}

		switch {
		case existing.AccountID == accountID:
			if target.apple != nil {
				return s.saveAppleGrant(ctx, q, existing.ID, target.apple)
			}
			return nil
		case existing.AccountStatus == statusPendingDeletion:
			return ErrIdentityPendingDeletion
		case existing.AccountStatus == statusActive:
			inUse, err = s.issueMergeTicket(ctx, q, now, accountID, existing)
			return err
		default:
			// 익명화는 subject를 바꾸므로 정상이라면 여기에 오지 않습니다. 데이터가 어긋난 것이라 서버 오류로 둡니다.
			return fmt.Errorf("계정 %s: 익명화된 계정에 연결된 identity입니다", existing.AccountID)
		}
	})
	if err != nil {
		return LinkResult{}, err
	}
	if inUse != nil {
		return LinkResult{}, inUse
	}
	return result, nil
}

// createLinkedIdentity는 어디에도 없는 연결을 현재 계정에 만듭니다.
// 현재 계정에 같은 제공자의 다른 사용자 연결이 있으면 ErrProviderTaken입니다(한 계정에 제공자마다 연결 하나).
func (s *Service) createLinkedIdentity(ctx context.Context, q *authdb.Queries, accountID uuid.UUID, providerName string, target loginTarget) error {
	taken, err := q.AccountHasProvider(ctx, authdb.AccountHasProviderParams{AccountID: accountID, Provider: providerName})
	if err != nil {
		return fmt.Errorf("제공자 연결 확인: %w", err)
	}
	if taken {
		return ErrProviderTaken
	}
	params, err := s.newIdentityParams(accountID, providerName, target.subject, target.apple)
	if err != nil {
		return err
	}
	if err := q.CreateIdentity(ctx, params); err != nil {
		return fmt.Errorf("identity 생성: %w", err)
	}
	s.logger.InfoContext(ctx, "연결 붙이기", "accountId", accountID, "provider", providerName)
	return nil
}

// issueMergeTicket은 다른 계정에 있는 연결로 합치기 토큰을 만들어 해시를 저장하고, 원문을 담은 오류를 돌려줍니다.
// 토큰은 refresh token과 같은 방식(256비트 난수 base64url, SHA-256 저장)으로 만듭니다.
func (s *Service) issueMergeTicket(ctx context.Context, q *authdb.Queries, now time.Time, accountID uuid.UUID, other authdb.GetIdentityForLinkRow) (*IdentityInUseError, error) {
	id, err := uuid.NewV7()
	if err != nil {
		return nil, fmt.Errorf("합치기 토큰 id 생성: %w", err)
	}
	raw, hash, err := token.NewRefreshToken()
	if err != nil {
		return nil, fmt.Errorf("합치기 토큰 생성: %w", err)
	}
	// DB(timestamptz)는 마이크로초 정밀도로 저장하므로, 응답 값도 같은 정밀도로 맞춰 DB 값과 일치시킵니다.
	expiresAt := now.Add(MergeTicketTTL).Truncate(time.Microsecond)
	if err := q.InsertMergeTicket(ctx, authdb.InsertMergeTicketParams{
		ID:             id,
		TokenHash:      hash,
		AccountID:      accountID,
		OtherAccountID: other.AccountID,
		IdentityID:     other.ID,
		ExpiresAt:      expiresAt,
	}); err != nil {
		return nil, fmt.Errorf("합치기 토큰 저장: %w", err)
	}
	return &IdentityInUseError{MergeToken: raw, ExpiresAt: expiresAt}, nil
}

// UnlinkIdentity는 현재 계정에서 제공자 연결을 뗍니다(S100). providerName은 kakao·apple·line·google입니다.
//
// 트랜잭션에서 계정 행을 잠그고 연결 행을 물리적으로 지운 뒤 남은 연결 수를 봅니다. 그 제공자 연결이 없으면
// ErrIdentityNotFound, 지우고 남은 연결이 없으면 rollback하고 ErrLastIdentity입니다. 계정 행을 잠그므로 연결 둘을
// 동시에 떼도 하나는 남습니다. 표시만 남기지 않고 지우는 것은 그 제공자 사용자가 나중에 새 계정을 만들 때
// (provider, subject) unique에 걸리지 않게 하려는 것입니다.
//
// 카카오와 저장한 token이 있는 Apple이면 같은 트랜잭션에서 허가 취소 대기 행을 넣고(QueueRevocationTx),
// commit한 뒤 한 번 시도합니다(S106). 실패해도 대기 행에 남아 job retention이 다시 시도하므로 떼기는 성공입니다.
// 요청이 취소돼도 끝까지 하도록 context의 취소를 떼어 냅니다.
func (s *Service) UnlinkIdentity(ctx context.Context, accountID uuid.UUID, providerName string) error {
	if !isLinkableProvider(providerName) {
		return fmt.Errorf("뗄 수 없는 제공자 %q", providerName)
	}
	var revocationID int64
	var queued bool
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		queued = false
		q := authdb.New(tx)
		if err := lockActiveAccount(ctx, q, accountID); err != nil {
			return err
		}
		row, err := q.DeleteIdentity(ctx, authdb.DeleteIdentityParams{AccountID: accountID, Provider: providerName})
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrIdentityNotFound
		}
		if err != nil {
			return fmt.Errorf("identity 삭제: %w", err)
		}
		remaining, err := q.CountIdentities(ctx, accountID)
		if err != nil {
			return fmt.Errorf("연결 수 확인: %w", err)
		}
		if remaining == 0 {
			// 오류를 돌려주면 rollback되어 지운 행이 되돌아갑니다.
			return ErrLastIdentity
		}
		id, ok, err := QueueRevocationTx(ctx, q, row, s.clock.Now())
		if err != nil {
			return err
		}
		revocationID, queued = id, ok
		return nil
	})
	if err != nil {
		if errors.Is(err, ErrIdentityNotFound) || errors.Is(err, ErrLastIdentity) {
			return err
		}
		return fmt.Errorf("%s 떼기: %w", providerName, err)
	}
	s.logger.InfoContext(ctx, "연결 떼기", "accountId", accountID, "provider", providerName)

	if queued && s.revoker != nil {
		s.revoker.Attempt(context.WithoutCancel(ctx), []int64{revocationID})
	}
	return nil
}

// mergeTicketIdentityConstraint는 account_merge_tickets.identity_id의 FK 제약 이름입니다.
const mergeTicketIdentityConstraint = "account_merge_tickets_identity_id_fkey"

// sqlStateForeignKeyViolation은 FK 위반 SQLSTATE입니다.
const sqlStateForeignKeyViolation = "23503"

// isMergeTicketIdentityGone은 err가 합치기 토큰의 identity_id FK 위반(붙이려던 연결이 그 사이 지워짐)인지 알려 줍니다.
func isMergeTicketIdentityGone(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == sqlStateForeignKeyViolation && pgErr.ConstraintName == mergeTicketIdentityConstraint
}

// isLinkableProvider는 계약의 붙이기·떼기 대상 제공자(kakao·apple·line·google)인지 알려 줍니다. test는 계약에 없습니다.
func isLinkableProvider(providerName string) bool {
	switch providerName {
	case providerKakao, providerApple, providerLine, providerGoogle:
		return true
	default:
		return false
	}
}

// lockActiveAccount는 계정 행을 잠그고 active인지 확인합니다.
// httpapi의 상태 관문이 active가 아닌 계정을 먼저 막으므로, 여기서 걸리는 것은 그 사이 삭제 요청이 끼어든 경우뿐입니다.
// 삭제 대기 계정에 연결을 더하거나 빼면 허가 취소 대기 행과 어긋나므로 서버 오류로 멈춥니다.
func lockActiveAccount(ctx context.Context, q *authdb.Queries, accountID uuid.UUID) error {
	status, err := q.LockAccountStatus(ctx, accountID)
	if err != nil {
		return fmt.Errorf("계정 잠금: %w", err)
	}
	if status != statusActive {
		return fmt.Errorf("계정 %s: active가 아닙니다(%s)", accountID, status)
	}
	return nil
}
