package auth

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
)

// DisconnectProviders는 계정에 붙은 제공자 연결 중 아직 해제하지 않은 것을 모두 해제합니다.
//
//   - Apple: 저장한 refresh token을 복호화해 revoke합니다.
//   - 카카오: 앱과의 연결을 끊습니다(unlink).
//
// 성공한 연결은 Apple 토큰 열을 비우고 해제 시각을 기록합니다. 하나가 실패해도 나머지를 시도하고,
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
		if err := s.disconnect(ctx, identity); err != nil {
			s.logger.WarnContext(ctx, "제공자 연결 해제 실패", "accountId", accountID, "provider", identity.Provider)
			errs = append(errs, err)
			continue
		}
		if err := q.MarkProviderDisconnected(ctx, authdb.MarkProviderDisconnectedParams{
			DisconnectedAt: s.clock.Now(),
			ID:             identity.ID,
		}); err != nil {
			errs = append(errs, fmt.Errorf("%s 연결 해제 기록: %w", identity.Provider, err))
		}
	}
	return errors.Join(errs...)
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
		return fmt.Errorf("apple refresh token 복호화: %w", err)
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
