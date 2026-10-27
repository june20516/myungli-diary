package httpapi

import (
	"context"
	"time"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/merge"
)

// PreviewMerge는 다른 유저 계정(B)의 증명을 받아 합치기 토큰과 요약을 돌려줍니다(S110).
// 증명 오류는 linkIdentity와 같은 응답이고(400·401), 같은 계정·연결 없음은 422입니다. 합치기 서비스가 없으면 503입니다.
func (a *API) PreviewMerge(ctx context.Context, req gen.PreviewMergeRequestObject) (gen.PreviewMergeResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	if a.Merges == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	body := req.Body
	proof := auth.LinkProof{
		IDToken:           valueOf(body.IdToken),
		RawNonce:          body.Nonce,
		AuthorizationCode: valueOf(body.AuthorizationCode),
		ExchangeCode:      valueOf(body.ExchangeCode),
	}
	mergeToken, expiresAt, summary, err := a.Merges.Preview(ctx, id, string(body.Provider), proof)
	if err != nil {
		return nil, err
	}
	return gen.PreviewMerge200JSONResponse{
		MergeToken: mergeToken,
		ExpiresAt:  expiresAt.UTC(),
		Summary:    toGenMergeSummary(summary),
	}, nil
}

// mergeMeTimeout은 합친 뒤 Me를 읽는 마감입니다. 요청 ctx와 떼어 읽으므로 따로 둡니다.
const mergeMeTimeout = 5 * time.Second

// MergeAccounts는 합치기 토큰으로 다른 유저 계정(B)을 현재 계정(A)에 합치고 A의 Me를 돌려줍니다(S111).
// 토큰이 맞지 않으면 422 merge.token_invalid입니다. 같은 Idempotency-Key의 재전송은 멱등 미들웨어가 첫 응답으로 답하고,
// 키가 없거나 풀린 재전송도 이미 합친 토큰이면 서비스가 영수증을 보고 nil을 돌려주므로 200 Me입니다(S115).
// 합치기 서비스나 권한 판정(Me에 필요)이 없으면 합치기 전에 503입니다.
func (a *API) MergeAccounts(ctx context.Context, req gen.MergeAccountsRequestObject) (gen.MergeAccountsResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	if a.Merges == nil || a.Entitlements == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	if err := a.Merges.Execute(ctx, id, req.Body.MergeToken, merge.Profile(req.Body.Profile)); err != nil {
		return nil, err
	}
	// 합치기는 이미 commit됐으므로, 클라이언트가 끊어 요청 ctx가 취소돼도 Me를 읽어 200으로 끝냅니다.
	// 그래야 멱등 미들웨어가 응답을 저장해 같은 키 재전송이 저장 응답을 받습니다. 취소를 떼는 대신 짧은 마감을 둡니다.
	// Me 읽기가 잠깐 실패하면 한 번 다시 읽고, 그래도 실패하면 오류입니다(2xx가 아니라 키가 풀리지만,
	// 같은 토큰의 재전송은 합치기 영수증으로 200 Me를 받습니다. S115, 계약 mergeAccounts 설명 참고).
	meCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), mergeMeTimeout)
	defer cancel()
	body, err := a.me(meCtx, id)
	if err != nil {
		body, err = a.me(meCtx, id)
	}
	if err != nil {
		return nil, err
	}
	return gen.MergeAccounts200JSONResponse(body), nil
}

// toGenMergeSummary는 합치기 요약을 계약 MergeSummary로 바꿉니다. 계약에 없는 권한(insight)의 남은 날은 adFree와 같은 기간이라 싣지 않습니다.
func toGenMergeSummary(s merge.Summary) gen.MergeSummary {
	return gen.MergeSummary{
		Diaries:     s.Diaries,
		Schedules:   s.Schedules,
		DateRecords: s.DateRecords,
		Reactions:   s.Reactions,
		OverlapDays: s.OverlapDays,
		AddedDays:   gen.MergeAddedDays{AdFree: s.AddedDays[billing.AdFree]},
		Current:     toGenMergeProfile(s.Current),
		Other:       toGenMergeProfile(s.Other),
	}
}

// toGenMergeProfile은 프로필 요약을 계약 MergeProfileSummary로 바꿉니다. 저장된 프로필이 없으면 status만 있습니다.
func toGenMergeProfile(p merge.ProfileSummary) gen.MergeProfileSummary {
	if !p.Saved {
		return gen.MergeProfileSummary{Status: gen.None}
	}
	honorific := p.Honorific
	birth := toGenBirth(p.Birth)
	return gen.MergeProfileSummary{Status: gen.Saved, Honorific: &honorific, Birth: &birth}
}
