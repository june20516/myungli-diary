package httpapi

import (
	"context"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// toGenIdentityList는 연결 목록을 계약 응답으로 바꿉니다. 제공자 사용자 id(subject)는 내보내지 않습니다.
func toGenIdentityList(identities []auth.LinkedIdentity) gen.IdentityList {
	items := make([]gen.Identity, 0, len(identities))
	for _, identity := range identities {
		items = append(items, gen.Identity{
			Provider: gen.LoginProvider(identity.Provider),
			LinkedAt: identity.LinkedAt.UTC(),
		})
	}
	return gen.IdentityList{Items: items}
}

// ListIdentities는 현재 계정에 붙은 로그인 제공자를 붙인 순서로 돌려줍니다.
func (a *API) ListIdentities(ctx context.Context, _ gen.ListIdentitiesRequestObject) (gen.ListIdentitiesResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	identities, err := a.Auth.ListIdentities(ctx, id)
	if err != nil {
		return nil, err
	}
	return gen.ListIdentities200JSONResponse(toGenIdentityList(identities)), nil
}

// LinkIdentity는 현재 계정에 제공자 연결을 붙이고, 붙인 뒤의 연결 목록을 돌려줍니다.
// 새로 만들었으면 201, 이미 있었으면 200입니다. 제공자별 증명 필드 조합 검사는 서비스가 합니다.
func (a *API) LinkIdentity(ctx context.Context, req gen.LinkIdentityRequestObject) (gen.LinkIdentityResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	body := req.Body
	proof := auth.LinkProof{
		IDToken:           valueOf(body.IdToken),
		RawNonce:          body.Nonce,
		AuthorizationCode: valueOf(body.AuthorizationCode),
		ExchangeCode:      valueOf(body.ExchangeCode),
	}
	result, err := a.Auth.LinkIdentity(ctx, id, string(req.Provider), proof)
	if err != nil {
		return nil, err
	}
	identities, err := a.Auth.ListIdentities(ctx, id)
	if err != nil {
		return nil, err
	}
	list := toGenIdentityList(identities)
	if result.Created {
		return gen.LinkIdentity201JSONResponse(list), nil
	}
	return gen.LinkIdentity200JSONResponse(list), nil
}

// UnlinkIdentity는 현재 계정에서 제공자 연결을 뗍니다.
func (a *API) UnlinkIdentity(ctx context.Context, req gen.UnlinkIdentityRequestObject) (gen.UnlinkIdentityResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	if err := a.Auth.UnlinkIdentity(ctx, id, string(req.Provider)); err != nil {
		return nil, err
	}
	return gen.UnlinkIdentity204Response{}, nil
}
