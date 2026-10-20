package fortune

import (
	"context"

	"github.com/google/uuid"
)

// Insight는 계정이 근거 열람 권한(D60 insight)을 가졌는지 판정합니다.
// 권한이 없으면 화면 묶음에서 evidence 깊이의 문장(판정 근거·원전, 용신 근거)을 뺍니다.
type Insight interface {
	Unlocked(ctx context.Context, accountID uuid.UUID) (bool, error)
}

// AlwaysLocked는 누구에게도 근거를 열지 않는 Insight입니다.
// 실제 조립은 billing.Store를 쓰고, 이 타입은 테스트·조립 대체용으로만 남깁니다.
type AlwaysLocked struct{}

// Unlocked는 늘 false입니다.
func (AlwaysLocked) Unlocked(context.Context, uuid.UUID) (bool, error) { return false, nil }
