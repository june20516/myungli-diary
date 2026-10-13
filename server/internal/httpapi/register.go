package httpapi

import (
	"errors"
	"net/http"

	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// RegisterAPI는 계약의 모든 operation을 mux에 등록합니다. 각 라우트는 validate(ValidateRequests의 결과)로 감쌉니다.
// 라우트가 mux에 직접 등록되므로 접근 로그의 route와 404·405 problem은 다른 라우트와 같게 동작합니다.
func RegisterAPI(mux *http.ServeMux, impl gen.StrictServerInterface, deps Deps, validate func(http.Handler) http.Handler) {
	strict := gen.NewStrictHandlerWithOptions(impl, nil, gen.StrictHTTPServerOptions{
		// 검증을 통과한 본문이 생성 타입으로 디코드되지 않는 경우입니다(예 형식은 맞지만 없는 날짜 2026-02-30).
		RequestErrorHandlerFunc: func(w http.ResponseWriter, r *http.Request, _ error) {
			problem.Write(w, r, problem.New(http.StatusBadRequest, codeRequestInvalid, "Request does not match the contract"))
		},
		ResponseErrorHandlerFunc: func(w http.ResponseWriter, r *http.Request, err error) {
			writeHandlerError(deps, w, r, err)
		},
	})
	gen.HandlerWithOptions(strict, gen.StdHTTPServerOptions{
		BaseRouter:       validatingMux{mux: mux, validate: validate},
		ErrorHandlerFunc: writeParameterError,
	})
}

// validatingMux는 생성 코드가 등록하는 라우트마다 validate를 감싸 mux에 등록합니다.
type validatingMux struct {
	mux      *http.ServeMux
	validate func(http.Handler) http.Handler
}

func (v validatingMux) HandleFunc(pattern string, handler func(http.ResponseWriter, *http.Request)) {
	v.mux.Handle(pattern, v.validate(http.HandlerFunc(handler)))
}

func (v validatingMux) ServeHTTP(w http.ResponseWriter, r *http.Request) { v.mux.ServeHTTP(w, r) }

// writeHandlerError는 핸들러가 돌려준 오류를 problem으로 씁니다.
// ErrNotImplemented는 501, 그 밖은 로그를 남기고 500입니다.
func writeHandlerError(deps Deps, w http.ResponseWriter, r *http.Request, err error) {
	if errors.Is(err, ErrNotImplemented) {
		problem.Write(w, r, problem.New(http.StatusNotImplemented, "not_implemented", "Not implemented"))
		return
	}
	deps.Logger.ErrorContext(r.Context(), "핸들러 오류", "error", err)
	problem.Write(w, r, problem.New(http.StatusInternalServerError, "internal", "Internal server error"))
}

// writeParameterError는 생성 코드가 parameter를 Go 타입으로 바꾸지 못한 경우를 400 request.invalid로 씁니다.
// 검증을 통과한 뒤에도 생길 수 있습니다(예 형식은 맞지만 없는 날짜 2026-02-30).
func writeParameterError(w http.ResponseWriter, r *http.Request, err error) {
	p := problem.New(http.StatusBadRequest, codeRequestInvalid, "Request does not match the contract")
	if fieldError, ok := parameterFieldError(err); ok {
		p.Errors = []problem.FieldError{fieldError}
	}
	problem.Write(w, r, p)
}

// parameterFieldError는 생성 코드의 parameter 오류에서 parameter 이름과 오류 코드를 꺼냅니다.
func parameterFieldError(err error) (problem.FieldError, bool) {
	var (
		requiredParam  *gen.RequiredParamError
		requiredHeader *gen.RequiredHeaderError
		invalidFormat  *gen.InvalidParamFormatError
		unmarshaling   *gen.UnmarshalingParamError
		tooManyValues  *gen.TooManyValuesForParamError
		cookie         *gen.UnescapedCookieParamError
	)
	switch {
	case errors.As(err, &requiredParam):
		return problem.FieldError{Field: requiredParam.ParamName, Code: "required"}, true
	case errors.As(err, &requiredHeader):
		return problem.FieldError{Field: requiredHeader.ParamName, Code: "required"}, true
	case errors.As(err, &invalidFormat):
		return problem.FieldError{Field: invalidFormat.ParamName, Code: "type"}, true
	case errors.As(err, &unmarshaling):
		return problem.FieldError{Field: unmarshaling.ParamName, Code: "type"}, true
	case errors.As(err, &tooManyValues):
		return problem.FieldError{Field: tooManyValues.ParamName, Code: "invalid"}, true
	case errors.As(err, &cookie):
		return problem.FieldError{Field: cookie.ParamName, Code: "invalid"}, true
	default:
		return problem.FieldError{}, false
	}
}
