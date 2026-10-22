package httpapi

import (
	"context"

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
