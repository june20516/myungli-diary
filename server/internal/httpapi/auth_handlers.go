package httpapi

import (
	"context"
	"net/url"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// toGenTokenPair는 서비스의 토큰 한 쌍을 계약 응답 타입으로 바꿉니다.
func toGenTokenPair(p auth.TokenPair) gen.TokenPair {
	return gen.TokenPair{
		AccessToken:           p.AccessToken,
		AccessTokenExpiresAt:  p.AccessExpiresAt,
		RefreshToken:          p.RefreshToken,
		RefreshTokenExpiresAt: p.RefreshExpiresAt,
	}
}

// loginResponse는 로그인 결과에 동의 필요 여부를 붙여 계약 응답으로 만듭니다.
func (a *API) loginResponse(ctx context.Context, res auth.LoginResult) (gen.LoginResponse, error) {
	me, err := a.Accounts.Me(ctx, res.AccountID)
	if err != nil {
		// 토큰은 이미 발급·저장됐지만 응답하지 못하므로 버려집니다. 클라이언트가 로그인을 다시 시도하면 복구됩니다.
		return gen.LoginResponse{}, err
	}
	return gen.LoginResponse{
		ConsentRequired:      me.ConsentRequired,
		IsNewAccount:         res.IsNewAccount,
		RestoredFromDeletion: res.RestoredFromDeletion,
		Tokens:               toGenTokenPair(res.Tokens),
	}, nil
}

// LoginKakao는 카카오 id_token을 검증하고 자체 토큰을 발급합니다.
func (a *API) LoginKakao(ctx context.Context, req gen.LoginKakaoRequestObject) (gen.LoginKakaoResponseObject, error) {
	res, err := a.Auth.LoginKakao(ctx, req.Body.IdToken, req.Body.Nonce)
	if err != nil {
		return nil, err
	}
	body, err := a.loginResponse(ctx, res)
	if err != nil {
		return nil, err
	}
	return gen.LoginKakao200JSONResponse(body), nil
}

// LoginApple은 Apple id_token과 authorization code를 검증하고 자체 토큰을 발급합니다.
// clientType이 Apple client_id(앱 BundleID 또는 웹 ServicesID)를 정합니다.
func (a *API) LoginApple(ctx context.Context, req gen.LoginAppleRequestObject) (gen.LoginAppleResponseObject, error) {
	client := provider.AppleNative
	if req.Body.ClientType == gen.Web {
		client = provider.AppleWeb
	}
	res, err := a.Auth.LoginApple(ctx, req.Body.IdToken, req.Body.AuthorizationCode, req.Body.Nonce, client)
	if err != nil {
		return nil, err
	}
	body, err := a.loginResponse(ctx, res)
	if err != nil {
		return nil, err
	}
	return gen.LoginApple200JSONResponse(body), nil
}

// RefreshToken은 refresh token을 회전해 새 토큰 한 쌍을 돌려줍니다.
func (a *API) RefreshToken(ctx context.Context, req gen.RefreshTokenRequestObject) (gen.RefreshTokenResponseObject, error) {
	pair, err := a.Auth.Refresh(ctx, req.Body.RefreshToken)
	if err != nil {
		return nil, err
	}
	return gen.RefreshToken200JSONResponse(toGenTokenPair(pair)), nil
}

// Logout은 보낸 refresh token의 family를 폐기합니다.
func (a *API) Logout(ctx context.Context, req gen.LogoutRequestObject) (gen.LogoutResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	if err := a.Auth.Logout(ctx, id, req.Body.RefreshToken); err != nil {
		return nil, err
	}
	return gen.Logout204Response{}, nil
}

// errNoAccount는 인증 middleware를 거치지 않아 ctx에 계정이 없을 때의 오류입니다(조립 실수 방어).
var errNoAccount = func() *Error {
	e := newError(problem.AuthTokenInvalid, "Token invalid")
	e.BearerChallenge = true
	return e
}()

// AppleCallback은 Apple 웹 흐름의 form_post 콜백을 앱 deep link로 303 redirect합니다.
// 받은 값(code, id_token, user)은 deep link 쿼리로만 넘기고 로그에 남기지 않습니다.
func (a *API) AppleCallback(_ context.Context, req gen.AppleCallbackRequestObject) (gen.AppleCallbackResponseObject, error) {
	form := req.Body
	query := url.Values{"state": {form.State}}

	switch {
	case form.Error != nil && *form.Error != "":
		query.Set("error", *form.Error)
	default:
		var missing []problem.FieldError
		if form.Code == nil || *form.Code == "" {
			missing = append(missing, problem.FieldError{Field: "/code", Code: "required"})
		}
		if form.IdToken == nil || *form.IdToken == "" {
			missing = append(missing, problem.FieldError{Field: "/id_token", Code: "required"})
		}
		if len(missing) > 0 {
			e := newError(problem.RequestInvalid, "Request does not match the contract")
			e.Errors = missing
			return nil, e
		}
		query.Set("code", *form.Code)
		query.Set("id_token", *form.IdToken)
		if form.User != nil && *form.User != "" {
			query.Set("user", *form.User)
		}
	}

	location, err := deepLinkWithQuery(a.AppleCallbackDeepLink, query)
	if err != nil {
		return nil, err
	}
	return gen.AppleCallback303Response{Headers: gen.AppleCallback303ResponseHeaders{Location: &location}}, nil
}

// deepLinkWithQuery는 deep link에 이미 있는 쿼리를 보존하며 query를 덧붙입니다.
func deepLinkWithQuery(deepLink string, query url.Values) (string, error) {
	u, err := url.Parse(deepLink)
	if err != nil {
		return "", err
	}
	merged := u.Query()
	for key, values := range query {
		merged[key] = values
	}
	u.RawQuery = merged.Encode()
	return u.String(), nil
}
