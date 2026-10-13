package httpapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgconn"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// 이 파일은 핸들러가 돌려준 오류를 problem 응답으로 바꾸는 단일 경로를 둡니다.
//
// 개인정보 규칙: 도메인 코드가 만드는 오류 문구(fmt.Errorf, errors.New)에는 출생 정보, 호칭,
// 이메일, 제공자 subject, 토큰 같은 값을 넣지 않습니다. 500·503 로그가 err.Error()를 그대로 남기기 때문입니다.
// DB 드라이버 오류는 Detail에 행 값이 들어갈 수 있어 logHandlerError가 따로 걸러 냅니다.

const (
	codeInternal           = "internal"
	codeServiceUnavailable = "service.unavailable"
)

// Error는 핸들러가 계약에 적힌 오류(상태, 코드, 필드 오류)를 그대로 지정할 때 돌려주는 오류입니다.
type Error struct {
	Status int
	Code   string
	Title  string
	Errors []problem.FieldError
	// BearerChallenge가 true이면 bearer 인증 실패 401로서 WWW-Authenticate 헤더를 붙입니다.
	BearerChallenge bool
}

// Error는 error 인터페이스를 만족시킵니다. 로그용 문구이므로 상태와 코드만 담습니다.
func (e *Error) Error() string {
	return fmt.Sprintf("http %d %s", e.Status, e.Code)
}

// domainError는 도메인 sentinel 오류 하나와 응답의 대응입니다.
type domainError struct {
	target          error
	status          int
	code, title     string
	bearerChallenge bool
}

// domainErrors는 도메인 sentinel을 응답으로 바꾸는 표입니다. errors.Is로 위에서부터 찾습니다.
// refresh token 오류는 bearer 인증(access token) 실패가 아니므로 WWW-Authenticate를 붙이지 않습니다.
var domainErrors = []domainError{
	{target: auth.ErrProviderTokenInvalid, status: http.StatusUnauthorized, code: "auth.provider_token_invalid", title: "Provider token invalid"},
	{target: auth.ErrProviderUnavailable, status: http.StatusServiceUnavailable, code: "auth.provider_unavailable", title: "Provider unavailable"},
	{target: auth.ErrRefreshInvalid, status: http.StatusUnauthorized, code: "auth.token_invalid", title: "Refresh token invalid"},
	{target: auth.ErrRefreshReused, status: http.StatusUnauthorized, code: "auth.refresh_reused", title: "Refresh token reused"},
}

// writeHandlerError는 핸들러가 돌려준 오류를 problem으로 씁니다.
// 순서: ErrNotImplemented(501), *Error(그대로), domainErrors 표, DB 연결 실패(503), 그 밖(500).
func writeHandlerError(deps Deps, w http.ResponseWriter, r *http.Request, err error) {
	if errors.Is(err, ErrNotImplemented) {
		problem.Write(w, r, problem.New(http.StatusNotImplemented, "not_implemented", "Not implemented"))
		return
	}

	var explicit *Error
	if errors.As(err, &explicit) {
		p := problem.New(explicit.Status, explicit.Code, explicit.Title)
		p.Errors = explicit.Errors
		writeProblem(w, r, p, explicit.BearerChallenge)
		return
	}

	for _, d := range domainErrors {
		if errors.Is(err, d.target) {
			writeProblem(w, r, problem.New(d.status, d.code, d.title), d.bearerChallenge)
			return
		}
	}

	// pgxpool은 연결을 새로 맺지 못하면 *pgconn.ConnectError를 돌려줍니다. 닫힌 pool의 오류는
	// 간접 의존인 puddle 패키지의 sentinel이라 여기서 판별하지 않고 500으로 둡니다.
	var connectErr *pgconn.ConnectError
	if errors.As(err, &connectErr) {
		logHandlerError(r.Context(), deps.Logger, err)
		problem.Write(w, r, problem.New(http.StatusServiceUnavailable, codeServiceUnavailable, "Service unavailable"))
		return
	}

	logHandlerError(r.Context(), deps.Logger, err)
	problem.Write(w, r, problem.New(http.StatusInternalServerError, codeInternal, "Internal server error"))
}

// writeProblem은 bearer 인증 실패 여부에 따라 헤더를 달리해 problem을 씁니다.
func writeProblem(w http.ResponseWriter, r *http.Request, p problem.Problem, bearerChallenge bool) {
	if bearerChallenge {
		problem.WriteBearerChallenge(w, r, p)
		return
	}
	problem.Write(w, r, p)
}

// logHandlerError는 500·503의 원인을 한 곳에서 남깁니다.
// *pgconn.PgError는 Message·Detail·Where에 행 값이 들어갈 수 있어 pgCode·constraint·table만 남깁니다.
// 그 밖의 오류는 타입과 문구를 남깁니다.
func logHandlerError(ctx context.Context, logger *slog.Logger, err error) {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		logger.ErrorContext(ctx, "핸들러 DB 오류",
			"pgCode", pgErr.Code,
			"constraint", pgErr.ConstraintName,
			"table", pgErr.TableName,
		)
		return
	}
	logger.ErrorContext(ctx, "핸들러 오류", "errorType", fmt.Sprintf("%T", err), "error", err.Error())
}
