package auth

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// DisconnectProviders는 계정에 붙은 제공자 연결 중 아직 해제하지 않은 것을 모두 해제합니다.
//
//   - Apple: 저장한 refresh token을 복호화해 revoke합니다.
//   - 카카오: 앱과의 연결을 끊습니다(unlink).
//
// 각 연결의 외부 호출 직전에 계정이 아직 삭제 대기인지 확인하고(stillPendingDeletion), 아니면(복구 로그인으로
// active가 됐거나 계정이 없으면) 그 연결은 건너뜁니다. 확인과 외부 호출 사이에 끼어드는 복구 로그인은 막지 못하며,
// 그 경합은 markDisconnected가 기록을 생략하는 것으로만 줄입니다.
//
// 성공한 연결은 계정이 아직 삭제 대기일 때만 Apple 토큰 열을 비우고 해제 시각을 기록합니다(markDisconnected). 하나가 실패해도 나머지를 시도하고,
// 실패들을 errors.Join으로 묶어 돌려줍니다. 실패한 연결은 그대로 남으므로 같은 함수를 다시 부르면
// 남은 것만 처리합니다(계정 삭제 직후와 job retention 재시도가 같은 함수를 씀).
func (s *Service) DisconnectProviders(ctx context.Context, accountID uuid.UUID) error {
	q := authdb.New(s.pool)
	identities, err := q.ListIdentities(ctx, accountID)
	if err != nil {
		return fmt.Errorf("identity 목록 조회: %w", err)
	}

	var errs []error
	for _, identity := range identities {
		if identity.ProviderDisconnectedAt != nil {
			continue
		}
		pending, err := s.stillPendingDeletion(ctx, accountID)
		if err != nil {
			errs = append(errs, fmt.Errorf("%s 연결 해제 전 계정 확인: %w", identity.Provider, err))
			continue
		}
		if !pending {
			s.logger.InfoContext(ctx, "계정이 삭제 대기가 아니어서 연결 해제를 건너뜀",
				"accountId", accountID, "provider", identity.Provider)
			continue
		}
		if err := s.disconnect(ctx, identity); err != nil {
			s.logger.WarnContext(ctx, "제공자 연결 해제 실패",
				"accountId", accountID, "provider", identity.Provider, "reason", disconnectFailureReason(err))
			errs = append(errs, err)
			continue
		}
		if err := s.markDisconnected(ctx, identity); err != nil {
			errs = append(errs, fmt.Errorf("%s 연결 해제 기록: %w", identity.Provider, err))
		}
	}
	return errors.Join(errs...)
}

// stillPendingDeletion은 계정 행을 잠깐 잠가 status를 읽고, 삭제 대기인지 알려 줍니다.
// 트랜잭션은 확인만 하고 바로 끝내므로, 외부 호출 동안 계정 행을 잠그고 있지 않습니다.
// 계정 행이 없으면 해제할 대상이 아니므로 false입니다.
func (s *Service) stillPendingDeletion(ctx context.Context, accountID uuid.UUID) (bool, error) {
	var pending bool
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		status, err := authdb.New(tx).LockAccountStatus(ctx, accountID)
		if errors.Is(err, pgx.ErrNoRows) {
			pending = false
			return nil
		}
		if err != nil {
			return fmt.Errorf("계정 잠금: %w", err)
		}
		pending = status == statusPendingDeletion
		return nil
	})
	return pending, err
}

// markDisconnected는 계정 행을 잠근 뒤, 계정이 아직 삭제 대기일 때만 연결 해제를 기록합니다.
//
// 제공자 호출과 기록 사이에 복구 로그인이 끼어들면 계정은 active가 되고, 그 identity에는 복구 로그인이
// 새로 받은 Apple 토큰이 저장돼 있습니다. 그때 기록하면 살아 있는 연결을 '해제됨'으로 덮으므로 기록하지 않습니다.
// 복구 로그인도 같은 계정 행을 잠그므로(GetIdentity) 두 쪽이 한 줄로 처리됩니다.
func (s *Service) markDisconnected(ctx context.Context, identity authdb.ListIdentitiesRow) error {
	return postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := authdb.New(tx)
		status, err := q.LockAccountStatus(ctx, identity.AccountID)
		if err != nil {
			return fmt.Errorf("계정 잠금: %w", err)
		}
		if status != statusPendingDeletion {
			s.logger.InfoContext(ctx, "계정이 삭제 대기가 아니어서 연결 해제를 기록하지 않음",
				"accountId", identity.AccountID, "provider", identity.Provider)
			return nil
		}
		return q.MarkProviderDisconnected(ctx, authdb.MarkProviderDisconnectedParams{
			DisconnectedAt: s.clock.Now(),
			ID:             identity.ID,
		})
	})
}

// errDecrypt는 저장한 Apple refresh token을 복호화하지 못했음을 나타냅니다. 실패 사유 분류에 씁니다.
var errDecrypt = errors.New("decrypt failed")

// disconnectFailureReason은 연결 해제 실패를 로그용 사유로 분류합니다. 원인 문구는 담지 않습니다.
func disconnectFailureReason(err error) string {
	switch {
	case errors.Is(err, provider.ErrUnavailable):
		return "unavailable"
	case errors.Is(err, provider.ErrTokenInvalid):
		return "token_invalid"
	case errors.Is(err, errDecrypt):
		return "decrypt"
	default:
		return "other"
	}
}

// disconnect는 제공자 연결 하나를 해제하는 외부 호출을 합니다.
func (s *Service) disconnect(ctx context.Context, identity authdb.ListIdentitiesRow) error {
	switch identity.Provider {
	case providerKakao:
		if err := s.kakaoUnlink.Unlink(ctx, identity.Subject); err != nil {
			return fmt.Errorf("카카오 unlink: %w", err)
		}
		return nil
	case providerApple:
		return s.revokeApple(ctx, identity)
	default:
		return fmt.Errorf("identity %s: 알 수 없는 제공자 %q", identity.ID, identity.Provider)
	}
}

// revokeApple은 저장한 Apple refresh token을 복호화해 revoke합니다.
// 저장한 토큰이 없으면 revoke할 것이 없으므로 처리된 것으로 봅니다.
// Apple이 invalid_grant(이미 무효인 토큰)로 거절하면 다시 시도해도 같으므로 역시 처리된 것으로 봅니다.
func (s *Service) revokeApple(ctx context.Context, identity authdb.ListIdentitiesRow) error {
	if identity.AppleRefreshToken == nil {
		return nil
	}
	plain, err := s.box.Open(identity.AppleRefreshToken, identity.AppleTokenKeyID.String, identity.ID[:])
	if err != nil {
		return fmt.Errorf("%w: apple refresh token 복호화: %w", errDecrypt, err)
	}
	err = s.apple.Revoke(ctx, string(plain), identity.AppleClientID.String)
	if errors.Is(err, provider.ErrTokenInvalid) {
		s.logger.InfoContext(ctx, "Apple refresh token이 이미 무효여서 revoke를 건너뜀", "accountId", identity.AccountID)
		return nil
	}
	if err != nil {
		return fmt.Errorf("apple revoke: %w", err)
	}
	return nil
}
