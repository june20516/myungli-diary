package httpapi

import (
	"context"
	"errors"
	"fmt"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// GetMe는 계정 상태와 동의 필요 여부를 돌려줍니다.
// hasProfile, adFree, insight는 프로필(P3)과 수익(P7)이 생길 때까지 고정값입니다.
func (a *API) GetMe(ctx context.Context, _ gen.GetMeRequestObject) (gen.GetMeResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	me, err := a.Accounts.Me(ctx, id)
	if err != nil {
		return nil, err
	}

	// 계약상 requiredConsents는 빈 배열이어도 항상 있어야 하므로 nil을 피합니다.
	required := make([]gen.ConsentDocument, 0, len(me.RequiredConsents))
	for _, doc := range me.RequiredConsents {
		required = append(required, gen.ConsentDocument{Document: gen.ConsentDocumentDocument(doc.Document), Version: doc.Version})
	}
	body := gen.Me{
		AccountId:        id,
		AdFree:           gen.AdFree{Active: false},
		ConsentRequired:  me.ConsentRequired,
		HasProfile:       false,
		Insight:          gen.Insight{Active: false},
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
			return nil, &Error{
				Status: 422, Code: "consent.version_mismatch", Title: "Consent version mismatch",
				Errors: []problem.FieldError{{
					Field: fmt.Sprintf("/documents/%d/version", mismatch.Index),
					Code:  "consent.version_mismatch",
				}},
			}
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
