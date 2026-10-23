package auth

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

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
//   - 다른 유저 계정에 있음: ErrIdentityInUse(409). 합치기 토큰은 만들지 않습니다(S110). 합치기는 previewMerge가 따로 증명을 받습니다.
//
// 같은 연결을 두 계정이 동시에 붙이면 한쪽이 (provider, subject) unique 위반을 받습니다. 그쪽은 트랜잭션을 한 번 다시
// 실행해 ErrIdentityInUse가 됩니다(로그인의 동시 첫 로그인 처리와 같은 방식).
//
// Apple 웹 흐름은 교환 코드를 CompleteAppleWebLogin과 같은 규칙(appleWebTarget)으로 트랜잭션 안에서 소진합니다.
// 코드가 틀리거나 nonce가 맞지 않으면 ErrExchangeInvalid이며 코드는 소진되지 않습니다.
// 연결을 만들지 못하면(in-use·provider_taken) rollback되므로 교환 코드도 소진되지 않고 남습니다.
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
	switch {
	case err == nil:
		return result, nil
	case errors.Is(err, ErrIdentityInUse):
		s.logger.InfoContext(ctx, "다른 계정의 연결이어서 붙이기 거절", "accountId", accountID, "provider", providerName)
		return LinkResult{}, ErrIdentityInUse
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

// errProofIdentityNotFound는 Apple 웹 흐름 합치기 증명에서 연결을 찾지 못해 교환 코드 소진을 되돌릴 때 씁니다.
// VerifyProof 밖으로 나가지 않습니다.
var errProofIdentityNotFound = errors.New("auth: proof identity not found")

// VerifyProof는 합치기 요약(previewMerge, S110)이 받은 다른 유저 계정(B)의 증명을 검증하고, 그 인증 계정과
// 연결된 유저 계정을 찾습니다. 연결을 만들거나 바꾸지 않습니다. 증명 조합 검사와 오류 sentinel은 LinkIdentity와 같습니다.
//
//   - 연결이 없거나 그 유저 계정이 지워졌으면 found=false입니다.
//   - iOS Apple은 소유 확인에 id_token만 씁니다. code는 교환하지 않으므로 저장하거나 revoke할 grant가 없습니다(spec §6.2).
//   - Apple 웹 흐름은 교환 코드를 LinkIdentity와 같은 규칙으로 트랜잭션 안에서 확인하고, 연결을 찾았을 때만 소진합니다.
//     못 찾으면 rollback해 코드가 남으므로 app은 그 코드로 linkIdentity를 부를 수 있습니다. 교환 결과의 Apple token은
//     저장하지 않고 revoke하지도 않습니다. 같은 Apple 허가는 B를 지울 때 B에 저장한 token으로 취소됩니다(§4).
func (s *Service) VerifyProof(ctx context.Context, providerName string, proof LinkProof) (identityID, accountID uuid.UUID, found bool, err error) {
	if err := checkLinkProof(providerName, proof); err != nil {
		return uuid.Nil, uuid.Nil, false, err
	}
	if providerName == providerApple && proof.ExchangeCode != "" {
		return s.verifyAppleWebProof(ctx, proof)
	}

	subject, err := s.verifyProofSubject(ctx, providerName, proof)
	if err != nil {
		return uuid.Nil, uuid.Nil, false, err
	}
	row, err := authdb.New(s.pool).FindActiveIdentity(ctx, authdb.FindActiveIdentityParams{Provider: providerName, Subject: subject})
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, uuid.Nil, false, nil
	}
	if err != nil {
		return uuid.Nil, uuid.Nil, false, fmt.Errorf("합치기 증명 연결 조회: %w", err)
	}
	return row.ID, row.AccountID, true, nil
}

// verifyProofSubject는 id_token 증명(카카오·LINE·Google·iOS Apple)을 제공자에게 검증하고 subject를 돌려줍니다.
func (s *Service) verifyProofSubject(ctx context.Context, providerName string, proof LinkProof) (string, error) {
	if providerName == providerApple {
		identity, err := s.apple.Verify(ctx, proof.IDToken, proof.RawNonce, provider.AppleNative)
		if err != nil {
			return "", s.providerError(ctx, err, providerApple, "verify")
		}
		return identity.Subject, nil
	}
	verifier, err := s.idTokenVerifier(providerName)
	if err != nil {
		return "", err
	}
	identity, err := verifier.Verify(ctx, proof.IDToken, proof.RawNonce)
	if err != nil {
		return "", s.providerError(ctx, err, providerName, "verify")
	}
	return identity.Subject, nil
}

// verifyAppleWebProof는 Apple 웹 흐름의 합치기 증명을 확인합니다. 교환 코드 확인·소진과 연결 조회를 한 트랜잭션에서 하고,
// 연결이 없으면 rollback해 코드를 소진하지 않습니다.
func (s *Service) verifyAppleWebProof(ctx context.Context, proof LinkProof) (identityID, accountID uuid.UUID, found bool, err error) {
	prepare := s.appleWebTarget(proof.ExchangeCode, proof.RawNonce)
	err = postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := authdb.New(tx)
		target, err := prepare(ctx, q, s.clock.Now())
		if err != nil {
			return err
		}
		row, err := q.FindActiveIdentity(ctx, authdb.FindActiveIdentityParams{Provider: providerApple, Subject: target.subject})
		if errors.Is(err, pgx.ErrNoRows) {
			return errProofIdentityNotFound
		}
		if err != nil {
			return fmt.Errorf("합치기 증명 연결 조회: %w", err)
		}
		identityID, accountID = row.ID, row.AccountID
		return nil
	})
	switch {
	case err == nil:
		return identityID, accountID, true, nil
	case errors.Is(err, errProofIdentityNotFound):
		return uuid.Nil, uuid.Nil, false, nil
	case errors.Is(err, ErrExchangeInvalid):
		s.logger.InfoContext(ctx, "Apple 웹 흐름 합치기 증명 교환 코드 거절", "provider", providerApple, "step", "merge_web")
		return uuid.Nil, uuid.Nil, false, ErrExchangeInvalid
	default:
		return uuid.Nil, uuid.Nil, false, fmt.Errorf("apple 합치기 증명: %w", err)
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

// link는 붙이기 트랜잭션을 실행합니다. 아래 경합이면 한 번 다시 실행합니다(retryableTxError).
//
//   - (provider, subject) unique 위반: 같은 연결을 동시에 붙인 쪽이 먼저 commit했습니다. 다시 실행하면 그 연결을 찾아
//     in-use(같은 계정이면 Created=false)가 됩니다.
//   - errDeletedAccountIdentity: 다른 계정 삭제를 기다린 사이 같은 연결로 새 계정이 생겼습니다. 다시 실행하면 그 새 연결을 찾습니다.
func (s *Service) link(ctx context.Context, accountID uuid.UUID, providerName string, prepare prepareLogin) (LinkResult, error) {
	result, err := s.linkOnce(ctx, accountID, providerName, prepare)
	if retryableTxError(err) {
		result, err = s.linkOnce(ctx, accountID, providerName, prepare)
	}
	return result, err
}

// linkOnce는 붙이기 트랜잭션 한 번입니다.
//
// 다른 계정이 그 연결을 떼거나 계정을 지우는 중이면 GetIdentityForLink가 그 계정 행 잠금을 기다린 뒤 계정 행만 다시
// 확인하므로, 이미 지워진 연결 행을 돌려줄 수 있습니다. 그래서 다른 계정의 연결이면 새 statement로 연결 행이 남아 있는지
// 다시 확인하고, 없으면 어디에도 없는 연결로 보고 만듭니다.
func (s *Service) linkOnce(ctx context.Context, accountID uuid.UUID, providerName string, prepare prepareLogin) (LinkResult, error) {
	var result LinkResult
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		// InTx가 다시 실행할 수 있으므로 결과를 매번 새로 채웁니다.
		result = LinkResult{}
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
		create := func() error {
			if err := s.createLinkedIdentity(ctx, q, accountID, providerName, target); err != nil {
				return err
			}
			result = LinkResult{Created: true}
			return nil
		}
		existing, err := q.GetIdentityForLink(ctx, authdb.GetIdentityForLinkParams{Provider: providerName, Subject: target.subject})
		if errors.Is(err, pgx.ErrNoRows) {
			return create()
		}
		if err != nil {
			return fmt.Errorf("identity 조회: %w", err)
		}
		if existing.AccountID == accountID {
			if target.apple != nil {
				return s.saveAppleGrant(ctx, q, existing.ID, target.apple)
			}
			return nil
		}

		stillLinked, err := q.IdentityExists(ctx, authdb.IdentityExistsParams{Provider: providerName, Subject: target.subject})
		if err != nil {
			return fmt.Errorf("identity 다시 확인: %w", err)
		}
		switch {
		case !stillLinked:
			return create()
		case existing.AccountStatus == statusActive:
			// 오류를 돌려주면 rollback되므로 Apple 웹 흐름의 교환 코드도 소진되지 않습니다.
			return ErrIdentityInUse
		default:
			return deletedAccountIdentityError(existing.AccountID)
		}
	})
	if err != nil {
		return LinkResult{}, err
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
// httpapi의 상태 관문이 active가 아닌 계정을 먼저 막으므로, 여기서 걸리는 것은 그 사이 계정 삭제가 끼어든 경우입니다.
// 지운 계정이면 ErrAccountDeleted(401, 미들웨어가 지운 계정에 주는 응답과 같음)이고, 모르는 상태는 서버 오류입니다.
func lockActiveAccount(ctx context.Context, q *authdb.Queries, accountID uuid.UUID) error {
	status, err := q.LockAccountStatus(ctx, accountID)
	if err != nil {
		return fmt.Errorf("계정 잠금: %w", err)
	}
	if status == statusDeleted {
		return ErrAccountDeleted
	}
	if status != statusActive {
		return fmt.Errorf("계정 %s: active가 아닙니다(%s)", accountID, status)
	}
	return nil
}
