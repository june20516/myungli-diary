package httpapi

import (
	"errors"
	"fmt"
	"net/http"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/getkin/kin-openapi/openapi3"

	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// Routes는 RegisterAPI가 계약 라우트를 감쌀 때 쓰는 계약과 middleware입니다.
type Routes struct {
	// Spec은 계약 문서입니다. 라우트의 operationId와 security 요구를 여기서 찾습니다.
	Spec *openapi3.T
	// Validate는 요청을 계약으로 검증하는 middleware입니다(ValidateRequests의 결과).
	Validate func(http.Handler) http.Handler
	// Authenticate는 security 요구에 bearerAuth가 있는 라우트만 감쌉니다(보통 BearerAuth의 결과).
	Authenticate func(op Operation, next http.Handler) http.Handler
}

// RegisterAPI는 계약의 모든 operation을 mux에 등록합니다.
// bearer 라우트는 Authenticate(op, Validate(handler)), 그 밖의 라우트는 Validate(handler)로 감쌉니다.
// 인증이 검증보다 바깥이라 토큰 없는 요청은 본문이 틀려도 400이 아니라 401을 받습니다.
// 라우트가 mux에 직접 등록되므로 접근 로그의 route와 404·405 problem은 다른 라우트와 같게 동작합니다.
//
// 생성 코드가 등록하는 pattern(예 "GET /v1/me")이 routes.Spec에 없거나 routes의 필드가 비어 있으면
// 시작 시점의 조립 버그이므로 panic합니다.
func RegisterAPI(mux *http.ServeMux, impl gen.StrictServerInterface, deps Deps, routes Routes) {
	if routes.Spec == nil || routes.Validate == nil || routes.Authenticate == nil {
		panic("httpapi.RegisterAPI: Routes의 Spec·Validate·Authenticate가 모두 있어야 합니다")
	}
	strict := gen.NewStrictHandlerWithOptions(impl, nil, gen.StrictHTTPServerOptions{
		// 검증을 통과한 본문이 생성 타입으로 디코드되지 않는 예외 경로입니다. 날짜·시각 형식은 검증 단계(validate.go의
		// format validator)가 먼저 잡으므로 정상 요청에서는 닿지 않습니다.
		RequestErrorHandlerFunc: func(w http.ResponseWriter, r *http.Request, _ error) {
			problem.Write(w, r, problem.RequestInvalid.Problem("Request does not match the contract"))
		},
		ResponseErrorHandlerFunc: func(w http.ResponseWriter, r *http.Request, err error) {
			writeHandlerError(deps, w, r, err)
		},
	})
	gen.HandlerWithOptions(strict, gen.StdHTTPServerOptions{
		BaseRouter:       contractMux{mux: mux, routes: routes},
		ErrorHandlerFunc: writeParameterError,
	})
}

// contractMux는 생성 코드가 등록하는 라우트마다 계약의 operation을 찾아 인증·검증 middleware를 감싸 mux에 등록합니다.
type contractMux struct {
	mux    *http.ServeMux
	routes Routes
}

func (c contractMux) HandleFunc(pattern string, handler func(http.ResponseWriter, *http.Request)) {
	op := operationFor(c.routes.Spec, pattern)
	wrapped := c.routes.Validate(http.HandlerFunc(handler))
	if op.Bearer {
		wrapped = c.routes.Authenticate(op, wrapped)
	}
	c.mux.Handle(pattern, wrapped)
}

func (c contractMux) ServeHTTP(w http.ResponseWriter, r *http.Request) { c.mux.ServeHTTP(w, r) }

// securitySchemeBearer는 계약의 bearer 인증 security scheme 이름입니다.
const securitySchemeBearer = "bearerAuth"

// operationFor는 생성 코드의 ServeMux pattern("METHOD /path")에 맞는 계약 operation을 찾습니다.
// 생성 코드의 path는 계약의 path 템플릿({date} 등)을 그대로 쓰므로 문자열로 맞춥니다. 없으면 panic합니다.
// operation에 security가 없으면 문서 전체의 security를 따릅니다(OpenAPI 규칙). security: []는 공개 라우트입니다.
func operationFor(spec *openapi3.T, pattern string) Operation {
	method, path, found := strings.Cut(pattern, " ")
	var operation *openapi3.Operation
	if found && spec.Paths != nil {
		if item := spec.Paths.Value(path); item != nil {
			operation = item.GetOperation(method)
		}
	}
	if operation == nil {
		panic(fmt.Sprintf("httpapi.RegisterAPI: 계약에 없는 라우트 %q", pattern))
	}

	requirements := spec.Security
	if operation.Security != nil {
		requirements = *operation.Security
	}
	bearer := false
	for _, requirement := range requirements {
		if _, ok := requirement[securitySchemeBearer]; ok {
			bearer = true
			break
		}
	}
	return Operation{ID: contractOperationID(operation.OperationID), Bearer: bearer}
}

// contractOperationID는 operationId를 계약의 표기(lowerCamelCase, 예 "getMe")로 맞춥니다.
// gen.GetSpec의 내장 spec은 oapi-codegen이 operationId를 Go 이름(예 "GetMe")으로 바꿔 둔 사본이라
// 첫 글자만 소문자로 되돌립니다. 계약의 operationId 목록은 api/contract_test.go가 고정합니다.
func contractOperationID(id string) string {
	first, size := utf8.DecodeRuneInString(id)
	if first == utf8.RuneError {
		return id
	}
	return string(unicode.ToLower(first)) + id[size:]
}

// writeParameterError는 생성 코드가 parameter를 Go 타입으로 바꾸지 못한 경우를 400 request.invalid로 씁니다.
// 날짜 형식은 검증 단계가 먼저 format 위반으로 잡으므로, 이 경로는 검증을 통과한 값이 생성 타입으로
// 바뀌지 않는 예외 상황에서만 닿습니다.
func writeParameterError(w http.ResponseWriter, r *http.Request, err error) {
	p := problem.RequestInvalid.Problem("Request does not match the contract")
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
