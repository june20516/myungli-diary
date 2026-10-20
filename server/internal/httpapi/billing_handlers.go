package httpapi

import (
	"context"
	"errors"

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

// RestorePurchases는 RevenueCat 구매 목록으로 광고 제거권을 다시 계산하고 권한 상태를 돌려줍니다.
// 결제 설정이 없거나(Purchases가 비어 있음, P7-16) RevenueCat 장애면 503 billing.provider_unavailable입니다. 그 밖의 오류는 500입니다.
func (a *API) RestorePurchases(ctx context.Context, _ gen.RestorePurchasesRequestObject) (gen.RestorePurchasesResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	if a.Purchases == nil {
		return nil, newError(problem.BillingUnavailable, "Billing provider unavailable")
	}
	status, err := a.Purchases.Restore(ctx, id)
	if errors.Is(err, billing.ErrProviderUnavailable) {
		a.Logger.WarnContext(ctx, "구매 복원: RevenueCat 장애", "accountId", id, "error", err.Error())
		return nil, newError(problem.BillingUnavailable, "Billing provider unavailable")
	}
	if err != nil {
		return nil, err
	}
	return gen.RestorePurchases200JSONResponse(toEntitlements(status)), nil
}

// RevenuecatWebhook은 RevenueCat webhook을 받습니다(P7-7·P7-8·P7-9).
//
// 응답: 처리됨(기록만 한 경우 포함) 200 본문 없음, Authorization 불일치 401 auth.token_invalid(challenge 없음),
// event.id 형식 오류 400 request.invalid, 저장·동기화 실패 500(RevenueCat이 재전송).
// 동기화 중 RevenueCat 장애도 503이 아니라 500입니다. RevenueCat은 200 밖의 응답을 모두 실패로 보고 재전송합니다.
// 결제 설정이 없으면(Webhooks가 비어 있음, P7-16) 500이고 Error 로그를 남깁니다.
// 로그에 Authorization 값과 본문을 남기지 않습니다.
func (a *API) RevenuecatWebhook(ctx context.Context, request gen.RevenuecatWebhookRequestObject) (gen.RevenuecatWebhookResponseObject, error) {
	if a.Webhooks == nil {
		a.Logger.ErrorContext(ctx, "RevenueCat webhook을 받았지만 결제 설정이 없습니다")
		return nil, newError(problem.Internal, "Internal server error")
	}
	if !a.Webhooks.Authorized(RawRequestFrom(ctx).Authorization) {
		return nil, newError(problem.AuthTokenInvalid, "Webhook authorization invalid")
	}
	var body map[string]any
	if request.Body != nil {
		body = *request.Body
	}
	err := a.Webhooks.Handle(ctx, body)
	if errors.Is(err, billing.ErrWebhookInvalid) {
		return nil, newError(problem.RequestInvalid, "Webhook event invalid")
	}
	if err != nil {
		// 오류에 billing.ErrProviderUnavailable이 감싸여 있어도 계약대로 500으로 답하도록 *Error로 바꿉니다.
		logHandlerError(ctx, a.Logger, err)
		return nil, newError(problem.Internal, "Internal server error")
	}
	return gen.RevenuecatWebhook200Response{}, nil
}
