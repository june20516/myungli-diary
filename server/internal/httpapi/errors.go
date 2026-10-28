package httpapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5/pgconn"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/device"
	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/merge"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/internal/profile/honorific"
	"github.com/june20516/myungli-diary/server/internal/schedule"
)

// 이 파일은 핸들러가 돌려준 오류를 problem 응답으로 바꾸는 단일 경로를 둡니다.
//
// 개인정보 규칙: 도메인 코드가 만드는 오류 문구(fmt.Errorf, errors.New)에는 출생 정보, 호칭,
// 이메일, 제공자 subject, 토큰 같은 값을 넣지 않습니다. 500·503 로그가 err.Error()를 그대로 남기기 때문입니다.
// DB 드라이버 오류는 Detail에 행 값이 들어갈 수 있어 logHandlerError가 따로 걸러 냅니다.

// Error는 핸들러가 계약에 적힌 오류(상태, 코드, 필드 오류)를 그대로 지정할 때 돌려주는 오류입니다.
// Status가 0이거나 HTTP 상태 범위(100~599) 밖이면 프로그램 오류로 보고 500 internal로 답합니다.
type Error struct {
	Status int
	Code   string
	Title  string
	Errors []problem.FieldError
	// BearerChallenge가 true이면 bearer 인증 실패 401로서 WWW-Authenticate 헤더를 붙입니다.
	BearerChallenge bool
	// RetryAfter가 0보다 크면 Retry-After 헤더(초)를 붙입니다.
	RetryAfter time.Duration
}

// newError는 registry의 code로 *Error를 만듭니다. 상태는 code가 정하므로 호출자가 따로 적지 않습니다.
func newError(c problem.Code, title string) *Error {
	return &Error{Status: c.Status, Code: c.Value, Title: title}
}

// Error는 error 인터페이스를 만족시킵니다. 로그용 문구이므로 상태와 코드만 담습니다.
func (e *Error) Error() string {
	return fmt.Sprintf("http %d %s", e.Status, e.Code)
}

// domainError는 도메인 sentinel 오류 하나와 응답의 대응입니다.
type domainError struct {
	target          error
	code            problem.Code
	title           string
	bearerChallenge bool
	retryAfter      time.Duration
	// field가 비어 있지 않으면 errors[]에 code와 같은 코드로 그 필드를 가리킵니다.
	field string
	// logged가 true이면 운영자가 알아야 하는 상태라 Error 로그를 남깁니다.
	logged bool
}

// engineRetryAfter는 엔진에 닿지 못했을 때 클라이언트에 권하는 재시도 간격입니다.
const engineRetryAfter = 5 * time.Second

// domainErrors는 도메인 sentinel을 응답으로 바꾸는 표입니다. errors.Is로 위에서부터 찾습니다.
// refresh token·교환 코드 오류는 bearer 인증(access token) 실패가 아니므로 WWW-Authenticate를 붙이지 않습니다.
var domainErrors = []domainError{
	{target: auth.ErrProviderTokenInvalid, code: problem.AuthProviderTokenInvalid, title: "Provider token invalid"},
	{target: auth.ErrProviderUnavailable, code: problem.AuthProviderUnavailable, title: "Provider unavailable"},
	{target: auth.ErrRefreshInvalid, code: problem.AuthTokenInvalid, title: "Refresh token invalid"},
	{target: auth.ErrRefreshReused, code: problem.AuthRefreshReused, title: "Refresh token reused"},
	{target: auth.ErrExchangeInvalid, code: problem.AuthExchangeInvalid, title: "Exchange code invalid"},
	{target: auth.ErrProviderTaken, code: problem.AuthProviderTaken, title: "Provider already linked"},
	// 붙이기·떼기 도중 현재 계정이 지워졌습니다. 미들웨어가 지운 계정에 주는 응답과 같은 bearer 실패입니다.
	{target: auth.ErrAccountDeleted, code: problem.AuthTokenInvalid, title: "Token invalid", bearerChallenge: true},
	{target: auth.ErrIdentityInUse, code: problem.AuthIdentityInUse, title: "Identity in use"},
	{target: auth.ErrLastIdentity, code: problem.AuthLastIdentity, title: "Last identity"},
	{target: auth.ErrIdentityNotFound, code: problem.AuthIdentityNotFound, title: "Identity not found"},
	{target: merge.ErrSameAccount, code: problem.MergeSameAccount, title: "Same account"},
	{target: merge.ErrNoAccount, code: problem.MergeNoAccount, title: "No account"},
	{target: merge.ErrTokenInvalid, code: problem.MergeTokenInvalid, title: "Merge token invalid"},
	{target: profile.ErrNotFound, code: problem.ProfileRequired, title: "Profile required"},
	{target: engine.ErrUnavailable, code: problem.EngineUnavailable, title: "Engine unavailable", retryAfter: engineRetryAfter},
	{target: engine.ErrTimeout, code: problem.EngineTimeout, title: "Engine timeout"},
	{target: engine.ErrInternal, code: problem.EngineError, title: "Engine error"},
	// 활성 콘텐츠 시드가 없으면 seed 명령을 돌리지 않은 배포입니다(P4-7). 사용자 탓이 아니라 503이고 로그를 남깁니다.
	{target: content.ErrNoActiveSeed, code: problem.ServiceUnavailable, title: "Service unavailable", logged: true},
	{target: diary.ErrNotFound, code: problem.DiaryNotFound, title: "Diary not found"},
	{target: diary.ErrFutureDate, code: problem.DiaryFutureDate, title: "Diary date in the future"},
	{target: diary.ErrDayFull, code: problem.DiaryDayFull, title: "Diary day full"},
	{target: schedule.ErrNotFound, code: problem.ScheduleNotFound, title: "Schedule not found"},
	{target: device.ErrNotFound, code: problem.DeviceNotFound, title: "Device not found"},
	// 경로·쿼리 매개변수 위반의 errors[].field는 이름 그대로입니다.
	{target: schedule.ErrRangeTooLong, code: problem.RangeTooLong, title: "Range too long", field: "to"},
	{target: schedule.ErrRangeReversed, code: problem.RequestInvalid, title: "Range reversed", field: "from"},
	// 인증은 통과했는데 계정이 없는 경우입니다. access token이 가리키는 계정이 없으므로 bearer 실패입니다.
	{target: account.ErrNotFound, code: problem.AuthTokenInvalid, title: "Token invalid", bearerChallenge: true},
}

// writeHandlerError는 핸들러가 돌려준 오류를 problem으로 씁니다.
// 순서: ErrNotImplemented(501), *Error(그대로, 상태가 범위 밖이면 500), *profile.ValidationError(422),
// 지운 계정 쓰기(401 auth.token_invalid), domainErrors 표, DB 연결 실패(503), 그 밖(500).
// 프로필 저장, 음력 변환, 데일리·달력(핸들러가 직접 422로 바꿈) 밖에서 온 engine.ErrInvalidArgument·ErrOutOfRange는 server 쪽 입력 구성 오류라 표에 없고 500입니다.
func writeHandlerError(deps Deps, w http.ResponseWriter, r *http.Request, err error) {
	if errors.Is(err, ErrNotImplemented) {
		problem.Write(w, r, problem.NotImplemented.Problem("Not implemented"))
		return
	}

	// 호출자가 지정한 오류와 프로필 의미 검사 위반(422)은 같은 *Error 경로로 답합니다.
	var explicit *Error
	var violation *profile.ValidationError
	var invalidProof *auth.InvalidProofError
	switch {
	case errors.As(err, &explicit):
	case errors.As(err, &violation):
		explicit = validationError(violation)
	case errors.As(err, &invalidProof):
		explicit = invalidProofError(invalidProof)
	}
	if explicit != nil && !validHTTPStatus(explicit.Status) {
		logHandlerError(r.Context(), deps.Logger, err)
		problem.Write(w, r, problem.Internal.Problem("Internal server error"))
		return
	}
	if explicit != nil {
		p := problem.New(explicit.Status, explicit.Code, explicit.Title)
		p.Errors = explicit.Errors
		writeProblem(w, r, p, explicit.BearerChallenge, explicit.RetryAfter)
		return
	}

	// 삭제 중이던 계정에 쓰려다 DB trigger에 막혔습니다. 미들웨어가 deleted 계정에 주는 응답과 같습니다.
	if account.IsAccountDeletedError(err) {
		writeTokenInvalid(w, r)
		return
	}

	for _, d := range domainErrors {
		if errors.Is(err, d.target) {
			if d.logged {
				logHandlerError(r.Context(), deps.Logger, err)
			}
			p := d.code.Problem(d.title)
			if d.field != "" {
				p.Errors = []problem.FieldError{{Field: d.field, Code: d.code.Value}}
			}
			writeProblem(w, r, p, d.bearerChallenge, d.retryAfter)
			return
		}
	}

	// pgxpool은 연결을 새로 맺지 못하면 *pgconn.ConnectError를 돌려줍니다. 닫힌 pool의 오류는
	// 간접 의존인 puddle 패키지의 sentinel이라 여기서 판별하지 않고 500으로 둡니다.
	var connectErr *pgconn.ConnectError
	if errors.As(err, &connectErr) {
		logHandlerError(r.Context(), deps.Logger, err)
		problem.Write(w, r, problem.ServiceUnavailable.Problem("Service unavailable"))
		return
	}

	logHandlerError(r.Context(), deps.Logger, err)
	problem.Write(w, r, problem.Internal.Problem("Internal server error"))
}

// invalidProofError는 제공자별 증명 필드 조합 위반을 400과 errors[] 한 항목으로 바꿉니다.
func invalidProofError(e *auth.InvalidProofError) *Error {
	out := newError(problem.RequestInvalid, "Invalid proof")
	out.Errors = []problem.FieldError{{Field: e.Field, Code: e.Code}}
	return out
}

// validHTTPStatus는 status가 응답에 쓸 수 있는 HTTP 상태 코드(100~599)인지 알려 줍니다.
func validHTTPStatus(status int) bool {
	return status >= 100 && status <= 599
}

// writeProblem은 bearer 인증 실패 여부와 재시도 간격에 따라 헤더를 달리해 problem을 씁니다.
func writeProblem(w http.ResponseWriter, r *http.Request, p problem.Problem, bearerChallenge bool, retryAfter time.Duration) {
	if retryAfter > 0 {
		w.Header().Set("Retry-After", strconv.Itoa(int(retryAfter.Seconds())))
	}
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

// 422 errors[].code에 쓰는 상태 규칙 이름입니다. 계약 FieldError.code가 request.inconsistent에서 이 둘을 정합니다.
const (
	ruleRequiredByStatus  = "required_by_status"
	ruleForbiddenByStatus = "forbidden_by_status"
)

// violationCodes는 프로필 의미 검사 위반을 problem code로 바꾸는 표입니다. 호칭 거부는 honorificCodes로 갈립니다.
var violationCodes = map[profile.Violation]problem.Code{
	profile.DateInvalid:     problem.DateInvalid,
	profile.BirthOutOfRange: problem.BirthOutOfRange,
	profile.Inconsistent:    problem.RequestInconsistent,
	profile.TimezoneInvalid: problem.TimezoneInvalid,
	profile.CityNotFound:    problem.CityNotFound,
	profile.BirthInvalid:    problem.BirthInvalid,
}

// honorificCodes는 호칭 거부 사유를 problem code로 바꾸는 표입니다.
var honorificCodes = map[honorific.Code]problem.Code{
	honorific.Empty:       problem.NameEmpty,
	honorific.TooLong:     problem.NameTooLong,
	honorific.Emoji:       problem.NameEmoji,
	honorific.Control:     problem.NameControl,
	honorific.InvalidChar: problem.NameInvalidChar,
}

// validationError는 프로필 의미 검사 위반을 422 *Error로 바꿉니다.
// errors[]는 위반한 필드마다 하나이고, code는 상태 규칙이 있으면 그 이름, 없으면 problem code입니다.
// 표에 없는 위반은 프로그램 오류이므로 상태 0의 *Error가 되어 500으로 답합니다.
func validationError(v *profile.ValidationError) *Error {
	var code problem.Code
	var ok bool
	if v.Violation == profile.HonorificRejected {
		code, ok = honorificCodes[v.Honorific]
	} else {
		code, ok = violationCodes[v.Violation]
	}
	if !ok {
		return &Error{}
	}

	e := newError(code, "Validation failed")
	e.Errors = make([]problem.FieldError, 0, len(v.Fields))
	for _, f := range v.Fields {
		fieldCode := code.Value
		switch f.Rule {
		case profile.RequiredByStatus:
			fieldCode = ruleRequiredByStatus
		case profile.ForbiddenByStatus:
			fieldCode = ruleForbiddenByStatus
		case profile.NoStatusRule:
		}
		e.Errors = append(e.Errors, problem.FieldError{Field: f.Field, Code: fieldCode})
	}
	return e
}
