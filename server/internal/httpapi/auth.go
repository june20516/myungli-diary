package httpapi

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// 이 파일은 bearer 라우트의 인증과 계정 상태 관문을 둡니다. RegisterAPI가 bearer 라우트를
// Authenticate(op, Validate(handler)) 순서로 감싸므로, 토큰이 없거나 틀린 요청은 본문 검증(400)보다
// 먼저 401을 받습니다.

const (
	// bearerScheme은 Authorization 헤더의 인증 scheme입니다. 비교는 대소문자를 가리지 않습니다(RFC 9110 §11.1).
	bearerScheme = "Bearer"
)

// allowedWhilePendingDeletion은 삭제 대기 계정이 부를 수 있는 operation입니다.
// 상태 확인(getMe), 삭제 재요청(deleteMe), 로그아웃만 열어 둡니다. 복구는 다시 로그인해서 합니다.
var allowedWhilePendingDeletion = map[string]bool{
	"getMe":    true,
	"deleteMe": true,
	"logout":   true,
}

// allowedWhileConsentRequired는 현재 버전 약관에 아직 동의하지 않은 계정이 부를 수 있는 operation입니다.
// 계약의 agreeConsents 설명과 같습니다.
var allowedWhileConsentRequired = map[string]bool{
	"getMe":         true,
	"agreeConsents": true,
	"logout":        true,
	"deleteMe":      true,
}

// Operation은 RegisterAPI가 라우트마다 Authenticate에 넘기는 계약 operation 정보입니다.
type Operation struct {
	// ID는 계약의 operationId입니다(예 "getMe").
	ID string
	// Bearer는 operation의 security 요구에 bearerAuth가 있는지입니다.
	Bearer bool
}

// AccessTokenVerifier는 access token을 검증해 계정 id를 돌려줍니다. *token.AccessIssuer가 만족합니다.
// 만료는 token.ErrAccessExpired, 그 밖의 실패는 token.ErrAccessInvalid로 판별됩니다.
type AccessTokenVerifier interface {
	Verify(token string) (uuid.UUID, error)
}

// AccountGate는 요청마다 계정의 접근 상태를 돌려줍니다. *account.Service가 만족합니다.
// 계정이 없으면 account.ErrNotFound를 돌려줍니다.
type AccountGate interface {
	Access(ctx context.Context, id uuid.UUID) (account.Access, error)
}

// BearerAuth는 bearer 라우트를 감싸는 Authenticate 함수를 만듭니다(Routes.Authenticate에 넣습니다).
//
// 순서와 응답은 다음과 같습니다.
//  1. Authorization 헤더가 없거나 "Bearer <token>" 형식이 아니면 401 auth.token_invalid
//  2. 토큰 검증: 만료면 401 auth.token_expired, 그 밖의 실패면 401 auth.token_invalid
//  3. 계정 상태 조회: 계정이 없으면 401 auth.token_invalid, DB 연결 실패는 503, 그 밖의 오류는 500
//     (핸들러 오류와 같은 writeHandlerError 규칙)
//  4. 상태 관문: deleted면 401 auth.token_invalid. pending_deletion이면 getMe·deleteMe·logout 말고는
//     401 auth.token_invalid. 동의가 필요하면 getMe·agreeConsents·logout·deleteMe 말고는 403 consent.required.
//     두 조건이 함께면 삭제 대기 규칙이 먼저입니다.
//
// 401에는 모두 WWW-Authenticate 헤더를 붙입니다. 통과하면 계정 id와 접근 상태를 ctx에 넣으며,
// 핸들러는 AccountFrom으로 꺼냅니다. 토큰 값은 로그에 남기지 않습니다.
func BearerAuth(tokens AccessTokenVerifier, gate AccountGate, logger *slog.Logger) func(op Operation, next http.Handler) http.Handler {
	deps := Deps{Logger: logger}
	return func(op Operation, next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			accessToken, ok := bearerToken(r.Header.Get("Authorization"))
			if !ok {
				writeTokenInvalid(w, r)
				return
			}
			accountID, err := tokens.Verify(accessToken)
			if errors.Is(err, token.ErrAccessExpired) {
				problem.WriteBearerChallenge(w, r, problem.AuthTokenExpired.Problem("Token expired"))
				return
			}
			if err != nil {
				writeTokenInvalid(w, r)
				return
			}

			access, err := gate.Access(r.Context(), accountID)
			if err != nil {
				// account.ErrNotFound는 domainErrors 표가 401 auth.token_invalid(WWW-Authenticate 포함)로 바꿉니다.
				writeHandlerError(deps, w, r, err)
				return
			}

			switch access.Status {
			case account.StatusActive:
			case account.StatusPendingDeletion:
				if !allowedWhilePendingDeletion[op.ID] {
					writeTokenInvalid(w, r)
					return
				}
			default:
				// deleted(익명화 완료)와 모르는 상태는 토큰이 가리키는 계정이 더는 없는 것으로 봅니다.
				writeTokenInvalid(w, r)
				return
			}
			if access.ConsentRequired && !allowedWhileConsentRequired[op.ID] {
				problem.Write(w, r, problem.ConsentRequired.Problem("Consent required"))
				return
			}

			next.ServeHTTP(w, r.WithContext(withAccount(r.Context(), accountID, access)))
		})
	}
}

// bearerToken은 Authorization 헤더 값에서 bearer token을 꺼냅니다.
// scheme은 대소문자를 가리지 않고, scheme과 토큰 사이는 공백 한 칸이며, 토큰은 비어 있으면 안 됩니다.
func bearerToken(header string) (string, bool) {
	scheme, value, found := strings.Cut(header, " ")
	if !found || !strings.EqualFold(scheme, bearerScheme) || value == "" {
		return "", false
	}
	return value, true
}

// writeTokenInvalid는 401 auth.token_invalid를 WWW-Authenticate와 함께 씁니다.
func writeTokenInvalid(w http.ResponseWriter, r *http.Request) {
	problem.WriteBearerChallenge(w, r, problem.AuthTokenInvalid.Problem("Token invalid"))
}

// accountContextKey는 ctx에 인증된 계정을 담는 키 타입입니다. 패키지 밖에서 같은 키를 만들 수 없게 unexported입니다.
type accountContextKey struct{}

// authenticatedAccount는 ctx에 담는 인증 결과입니다.
type authenticatedAccount struct {
	id     uuid.UUID
	access account.Access
}

// withAccount는 인증된 계정 id와 접근 상태를 담은 ctx를 돌려줍니다.
func withAccount(ctx context.Context, id uuid.UUID, access account.Access) context.Context {
	return context.WithValue(ctx, accountContextKey{}, authenticatedAccount{id: id, access: access})
}

// AccountFrom은 BearerAuth가 ctx에 넣은 계정 id와 접근 상태를 돌려줍니다.
// bearer 라우트가 아니거나 인증을 거치지 않은 ctx면 ok가 false입니다.
func AccountFrom(ctx context.Context) (id uuid.UUID, access account.Access, ok bool) {
	authenticated, ok := ctx.Value(accountContextKey{}).(authenticatedAccount)
	if !ok {
		return uuid.Nil, account.Access{}, false
	}
	return authenticated.id, authenticated.access, true
}
