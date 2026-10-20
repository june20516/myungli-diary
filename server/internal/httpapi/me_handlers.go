package httpapi

import (
	"context"
	"errors"
	"fmt"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// GetMe는 계정 상태, 동의 필요 여부, 권한(adFree, insight)을 돌려줍니다.
// 권한 판정(Entitlements)이 없으면 503 service.unavailable입니다.
func (a *API) GetMe(ctx context.Context, _ gen.GetMeRequestObject) (gen.GetMeResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	if a.Entitlements == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	me, err := a.Accounts.Me(ctx, id)
	if err != nil {
		return nil, err
	}

	hasProfile, err := a.Profiles.Exists(ctx, id)
	if err != nil {
		return nil, err
	}

	status, err := a.Entitlements.Status(ctx, id)
	if err != nil {
		return nil, err
	}
	entitlements := toEntitlements(status)

	// 계약상 requiredConsents는 빈 배열이어도 항상 있어야 하므로 nil을 피합니다.
	required := make([]gen.ConsentDocument, 0, len(me.RequiredConsents))
	for _, doc := range me.RequiredConsents {
		required = append(required, gen.ConsentDocument{Document: gen.ConsentDocumentDocument(doc.Document), Version: doc.Version})
	}
	body := gen.Me{
		AccountId:        id,
		AdFree:           entitlements.AdFree,
		ConsentRequired:  me.ConsentRequired,
		HasProfile:       hasProfile,
		Insight:          entitlements.Insight,
		RequiredConsents: required,
		Status:           gen.MeStatus(me.Status),
	}
	if me.Status == account.StatusPendingDeletion {
		body.DeletionScheduledAt = me.DeletionScheduledAt
	}
	return gen.GetMe200JSONResponse(body), nil
}

// AgreeConsents는 약관 동의를 기록합니다. 현재 버전이 아닌 문서가 있으면 422이고 아무것도 저장하지 않습니다.
func (a *API) AgreeConsents(ctx context.Context, req gen.AgreeConsentsRequestObject) (gen.AgreeConsentsResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	docs := make([]account.ConsentDocument, 0, len(req.Body.Documents))
	for _, doc := range req.Body.Documents {
		docs = append(docs, account.ConsentDocument{Document: account.Document(doc.Document), Version: doc.Version})
	}
	if err := a.Accounts.AgreeConsents(ctx, id, docs); err != nil {
		var mismatch *account.ConsentVersionMismatchError
		if errors.As(err, &mismatch) {
			e := newError(problem.ConsentVersionMismatch, "Consent version mismatch")
			e.Errors = []problem.FieldError{{
				Field: fmt.Sprintf("/documents/%d/version", mismatch.Index),
				Code:  problem.ConsentVersionMismatch.Value,
			}}
			return nil, e
		}
		return nil, err
	}
	return gen.AgreeConsents204Response{}, nil
}

// DeleteMe는 계정 삭제를 예약하고 익명화 예정 시각을 202로 돌려줍니다.
func (a *API) DeleteMe(ctx context.Context, _ gen.DeleteMeRequestObject) (gen.DeleteMeResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	scheduledAt, err := a.Accounts.RequestDeletion(ctx, id)
	if err != nil {
		return nil, err
	}
	return gen.DeleteMe202JSONResponse{DeletionScheduledAt: scheduledAt}, nil
}
