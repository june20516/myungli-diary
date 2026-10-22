package httpapi

import (
	"context"
	"errors"
	"log/slog"
	"net/url"

	"github.com/june20516/myungli-diary/server/internal/auth"
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
		ConsentRequired: me.ConsentRequired,
		IsNewAccount:    res.IsNewAccount,
		Tokens:          toGenTokenPair(res.Tokens),
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

// LoginLine은 LINE id_token을 검증하고 자체 토큰을 발급합니다.
func (a *API) LoginLine(ctx context.Context, req gen.LoginLineRequestObject) (gen.LoginLineResponseObject, error) {
	res, err := a.Auth.LoginLine(ctx, req.Body.IdToken, req.Body.Nonce)
	if err != nil {
		return nil, err
	}
	body, err := a.loginResponse(ctx, res)
	if err != nil {
		return nil, err
	}
	return gen.LoginLine200JSONResponse(body), nil
}

// LoginGoogle은 Google id_token을 검증하고 자체 토큰을 발급합니다.
func (a *API) LoginGoogle(ctx context.Context, req gen.LoginGoogleRequestObject) (gen.LoginGoogleResponseObject, error) {
	res, err := a.Auth.LoginGoogle(ctx, req.Body.IdToken, req.Body.Nonce)
	if err != nil {
		return nil, err
	}
	body, err := a.loginResponse(ctx, res)
	if err != nil {
		return nil, err
	}
	return gen.LoginGoogle200JSONResponse(body), nil
}

// LoginApple은 Apple id_token과 authorization code를 검증하고 자체 토큰을 발급합니다.
// 이 operation은 iOS 앱 전용이라 요청에 클라이언트 종류가 없고, 서비스의 LoginApple이 Apple client_id를
// 앱 BundleID로 고정합니다. Android의 Apple 웹 흐름은 appleCallback과 completeAppleWebLogin을 씁니다.
func (a *API) LoginApple(ctx context.Context, req gen.LoginAppleRequestObject) (gen.LoginAppleResponseObject, error) {
	res, err := a.Auth.LoginApple(ctx, req.Body.IdToken, req.Body.AuthorizationCode, req.Body.Nonce)
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

// appleCallback의 303 Location에 담는 error 값입니다(계약 appleCallback 303 설명).
const (
	// appLinkErrorCancelled는 사용자가 Apple 로그인을 취소했다는 뜻이며, Apple이 보내는 값을 그대로 씁니다.
	appLinkErrorCancelled = "user_cancelled_authorize"
	// appLinkErrorTokenInvalid는 Apple의 id_token이나 authorization code가 검증·교환되지 않았다는 뜻입니다.
	appLinkErrorTokenInvalid = "token_invalid"
	// appLinkErrorProviderUnavailable는 Apple 서버에 닿지 못했다는 뜻입니다. 잠시 뒤 다시 시도할 수 있습니다.
	appLinkErrorProviderUnavailable = "provider_unavailable"
	// appLinkErrorInvalidRequest는 Apple의 다른 오류이거나 code·id_token이 빠진 요청이라는 뜻입니다.
	appLinkErrorInvalidRequest = "invalid_request"
	// appLinkErrorServer는 server 내부 오류입니다. 원인은 로그에만 남깁니다.
	appLinkErrorServer = "server_error"
)

// AppleCallback은 Apple 웹 흐름(Android)의 form_post 콜백입니다.
// Apple의 id_token과 authorization code를 server가 직접 검증·교환해 저장하고, 앱에는 일회용 교환 코드만
// App Link(AppLink.Base + /auth/apple)로 303 redirect해 넘깁니다. 실패도 같은 주소에 error 값으로 알립니다.
// 그래서 App Link가 앱을 열지 못해 주소가 브라우저 기록에 남아도 Apple 토큰은 드러나지 않습니다.
//
// state가 없으면 계약 검증이 400을 내고 이 함수까지 오지 않습니다. Apple의 user(이름·이메일)는 쓰지 않으며
// 로그에도 남기지 않습니다.
func (a *API) AppleCallback(ctx context.Context, req gen.AppleCallbackRequestObject) (gen.AppleCallbackResponseObject, error) {
	form := req.Body
	query := a.appleCallbackQuery(ctx, form)
	query.Set("state", form.State)
	location := a.AppLink.location(query)
	return gen.AppleCallback303Response{Headers: gen.AppleCallback303ResponseHeaders{Location: &location}}, nil
}

// appleCallbackQuery는 콜백 결과를 Location query(state 제외)로 만듭니다. 성공이면 exchange, 실패면 error 하나입니다.
func (a *API) appleCallbackQuery(ctx context.Context, form *gen.AppleCallbackFormdataRequestBody) url.Values {
	if appleError := valueOf(form.Error); appleError != "" {
		// Apple의 오류 문구를 그대로 넘기지 않고 앱이 아는 값으로 줄입니다.
		if appleError == appLinkErrorCancelled {
			return appLinkError(appLinkErrorCancelled)
		}
		return appLinkError(appLinkErrorInvalidRequest)
	}
	idToken, authorizationCode := valueOf(form.IdToken), valueOf(form.Code)
	if idToken == "" || authorizationCode == "" {
		return appLinkError(appLinkErrorInvalidRequest)
	}

	exchangeCode, err := a.Auth.BeginAppleWebLogin(ctx, idToken, authorizationCode)
	switch {
	case err == nil:
		return url.Values{"exchange": {exchangeCode}}
	case errors.Is(err, auth.ErrProviderTokenInvalid):
		return appLinkError(appLinkErrorTokenInvalid)
	case errors.Is(err, auth.ErrProviderUnavailable):
		return appLinkError(appLinkErrorProviderUnavailable)
	default:
		// 응답이 problem이 아니라 redirect라서 writeHandlerError를 거치지 않으므로 같은 규칙으로 여기서 남깁니다.
		logHandlerError(ctx, a.logger(), err)
		return appLinkError(appLinkErrorServer)
	}
}

// appLinkError는 error 값 하나를 담은 Location query입니다.
func appLinkError(value string) url.Values {
	return url.Values{"error": {value}}
}

// valueOf는 선택 form 필드의 값을 돌려줍니다. 필드가 없으면 빈 문자열입니다.
func valueOf(field *string) string {
	if field == nil {
		return ""
	}
	return *field
}

// logger는 핸들러 로그를 남길 logger입니다. 조립에서 Logger를 넣지 않았으면 slog 기본 logger를 씁니다.
func (a *API) logger() *slog.Logger {
	if a.Logger != nil {
		return a.Logger
	}
	return slog.Default()
}

// CompleteAppleWebLogin은 Apple 웹 콜백이 넘긴 교환 코드와 nonce 원문으로 자체 토큰을 발급합니다.
// 교환 코드가 없거나 만료·소진됐거나 nonce가 맞지 않으면 서비스가 auth.ErrExchangeInvalid를 돌려주고 401이 됩니다.
func (a *API) CompleteAppleWebLogin(ctx context.Context, req gen.CompleteAppleWebLoginRequestObject) (gen.CompleteAppleWebLoginResponseObject, error) {
	res, err := a.Auth.CompleteAppleWebLogin(ctx, req.Body.ExchangeCode, req.Body.Nonce)
	if err != nil {
		return nil, err
	}
	body, err := a.loginResponse(ctx, res)
	if err != nil {
		return nil, err
	}
	return gen.CompleteAppleWebLogin200JSONResponse(body), nil
}
