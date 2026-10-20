package httpapi

import (
	"context"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// GetEntitlements는 광고 제거권과 근거 열람 권한의 현재 상태를 돌려줍니다.
// 권한 판정(Entitlements)이 없으면 503 service.unavailable입니다.
func (a *API) GetEntitlements(ctx context.Context, _ gen.GetEntitlementsRequestObject) (gen.GetEntitlementsResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	if a.Entitlements == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	status, err := a.Entitlements.Status(ctx, id)
	if err != nil {
		return nil, err
	}
	return gen.GetEntitlements200JSONResponse(toEntitlements(status)), nil
}

// toEntitlements는 판정 결과를 계약 Entitlements로 바꿉니다.
// 유효하지 않은 권한은 expiresAt·source 없이 active false만 담습니다(Status가 그런 상태를 돌려줍니다).
func toEntitlements(s billing.Status) gen.Entitlements {
	out := gen.Entitlements{AdFree: gen.AdFree{Active: s.AdFree.Active}, Insight: gen.Insight{Active: s.Insight.Active}}
	if s.AdFree.Active {
		out.AdFree.ExpiresAt = s.AdFree.ExpiresAt
	}
	if s.Insight.Active {
		out.Insight.ExpiresAt = s.Insight.ExpiresAt
		source := gen.InsightSource(s.Insight.Source)
		out.Insight.Source = &source
	}
	return out
}
