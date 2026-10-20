package httpapi

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// 이 파일은 비로그인 요청(createPreview·getBirthHour·convertLunarDate)의 App Check 관문을 둡니다.
// RegisterAPI가 appCheck 라우트를 AppCheck(op, Validate(handler)) 순서로 감싸므로,
// 토큰이 없거나 틀린 요청은 본문 검증(400)보다 먼저 401을 받습니다.

// appCheckHeader는 App Check 토큰을 싣는 요청 헤더입니다(계약의 securitySchemes.appCheck).
const appCheckHeader = "X-Firebase-AppCheck"

// AppCheckVerifier는 App Check 토큰을 검증합니다. *provider.AppCheck가 만족합니다.
// 토큰 오류는 provider.ErrTokenInvalid, JWKS 장애는 provider.ErrUnavailable로 판별됩니다.
type AppCheckVerifier interface {
	Verify(ctx context.Context, token string) error
}

// RequireAppCheck은 appCheck 라우트를 감싸는 함수를 만듭니다(Routes.AppCheck에 넣습니다).
//
//  1. X-Firebase-AppCheck 헤더가 없거나 비어 있거나 둘 이상이면 401 app_check.invalid
//  2. 검증 실패: JWKS 장애(provider.ErrUnavailable)는 503 service.unavailable(운영자가 알아야 해 Error 로그), 그 밖의 실패는 401 app_check.invalid(로그 없음)
//
// 토큰 값은 로그에 남기지 않습니다.
func RequireAppCheck(verifier AppCheckVerifier, logger *slog.Logger) func(op Operation, next http.Handler) http.Handler {
	return func(op Operation, next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			values := r.Header.Values(appCheckHeader)
			if len(values) != 1 || strings.TrimSpace(values[0]) == "" {
				writeAppCheckInvalid(w, r)
				return
			}
			if err := verifier.Verify(r.Context(), strings.TrimSpace(values[0])); err != nil {
				if errors.Is(err, provider.ErrUnavailable) {
					logger.ErrorContext(r.Context(), "App Check 검증 불가(JWKS 장애)", "operation", op.ID, "error", err.Error())
					writeServiceUnavailable(w, r)
					return
				}
				writeAppCheckInvalid(w, r)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// appCheckUnconfigured는 Routes.AppCheck이 없을 때 appCheck 라우트를 막는 관문입니다(로컬에서 프로젝트 번호를 안 둔 경우).
// 검증할 수 없는 요청을 통과시키지 않고 503으로 답합니다.
func appCheckUnconfigured(logger *slog.Logger) func(op Operation, next http.Handler) http.Handler {
	return func(op Operation, _ http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			logger.ErrorContext(r.Context(), "App Check 검증기가 설정되지 않았습니다", "operation", op.ID)
			writeServiceUnavailable(w, r)
		})
	}
}

func writeAppCheckInvalid(w http.ResponseWriter, r *http.Request) {
	problem.Write(w, r, problem.AppCheckInvalid.Problem("App Check token invalid"))
}

func writeServiceUnavailable(w http.ResponseWriter, r *http.Request) {
	problem.Write(w, r, problem.ServiceUnavailable.Problem("Service unavailable"))
}
