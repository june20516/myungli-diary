package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"mime"
	"net/http"
	"strings"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	nethttpmiddleware "github.com/oapi-codegen/nethttp-middleware"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

const (
	codeRequestInvalid       = "request.invalid"
	codeRequestMalformed     = "request.malformed"
	codeUnsupportedMediaType = "request.unsupported_media_type"
	contentTypeJSON          = "application/json"
	contentTypeMergePatch    = "application/merge-patch+json"

	// validationOpenAPIVersion은 검증용 spec 사본의 버전입니다. ValidateRequests 주석을 보세요.
	validationOpenAPIVersion = "3.0.3"

	// kin-openapi가 본문 디코드 실패에 쓰는 RequestError.Reason입니다. 스키마 위반(같은 RequestError, 다른 Reason)과
	// 타입으로 구분되지 않아 문구로 가려냅니다(TestAPI_MalformedJSONReturns400Malformed가 문구의 변화를 잡습니다).
	reasonBodyDecodeFailed = "failed to decode request body"
)

// init의 등록은 kin-openapi 패키지 전역 상태라 httpapi를 import한 바이너리 전체(테스트 포함)에 적용됩니다.
func init() {
	// JSON 본문과 PATCH 본문(JSON Merge Patch)을 같은 규칙의 JSON으로 디코드합니다.
	openapi3filter.RegisterBodyDecoder(contentTypeJSON, decodeSingleJSONBody)
	openapi3filter.RegisterBodyDecoder(contentTypeMergePatch, decodeSingleJSONBody)
	// kin-openapi는 date·date-time만 기본으로 검사합니다. 계약의 id(format: uuid)도 검사합니다.
	openapi3.DefineStringFormatValidator("uuid", openapi3.NewRegexpFormatValidator(openapi3.FormatOfStringForUUIDOfRFC4122))
}

// decodeSingleJSONBody는 kin-openapi의 JSON body decoder와 같되, DecodeJSON처럼 JSON 값 하나만 허용합니다.
// 값 뒤에 데이터가 더 있으면 ParseError가 되어 400 request.malformed로 이어집니다.
func decodeSingleJSONBody(body io.Reader, _ http.Header, _ *openapi3.SchemaRef, _ openapi3filter.EncodingFn) (any, error) {
	decoder := json.NewDecoder(body)
	decoder.UseNumber()
	var value any
	if err := decoder.Decode(&value); err != nil {
		return nil, &openapi3filter.ParseError{Kind: openapi3filter.KindInvalidFormat, Cause: err}
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return nil, &openapi3filter.ParseError{Kind: openapi3filter.KindInvalidFormat, Cause: errTrailingData}
	}
	return value, nil
}

// ValidateRequests는 요청을 계약(spec)으로 검증하는 middleware를 만듭니다. 라우트마다 감싸 씁니다.
//
// 실패는 problem으로 바꿉니다.
//   - 스키마·parameter 위반: 400 request.invalid. errors[].field는 본문 위치면 JSON Pointer(RFC 6901,
//     예 "/birth/date/day", 본문 전체는 ""), 경로·쿼리·헤더 parameter면 계약의 parameter 이름(예 "date")입니다.
//     JSON Pointer는 항상 "/"로 시작하거나 비어 있으므로 parameter 이름과 겹치지 않습니다.
//   - JSON 문법 오류: 400 request.malformed
//   - Content-Type 불일치: 415 request.unsupported_media_type
//   - 본문 상한 초과: 413 request.too_large
//
// 검증은 쿼리 문자열과 본문을 바꾸지 않습니다(default 채우기 끔). admobRewardCallback이 원본 쿼리 문자열로
// 서명을 검증하기 때문입니다. 그래서 parameter default(예 limit 30)는 핸들러가 적용합니다.
//
// 검증은 spec 사본의 버전을 3.0.3으로 낮춰 kin-openapi의 built-in validator로 합니다. kin-openapi(v0.142)는 3.1 문서를
// JSON Schema 2020-12 validator로 검사하는데, 이 경로는 format(date 등)을 검사하지 않고 오류의 위치·keyword를
// 구조화해 주지 않습니다(errors[].field를 만들 수 없음). 계약은 3.0과 겹치는 keyword만 쓰므로 3.0 의미로 검사해도
// 계약의 뜻이 바뀌지 않습니다. 이 전제는 api/contract_test.go의 TestContract_NoOpenAPI31OnlySyntax와
// TestContract_NoNullTypes(const·webhooks·숫자형 exclusiveMinimum/Maximum·type 배열·null 금지)가 지킵니다.
//
// HEAD 요청은 GET으로 바꾼 사본으로 검증하고 그 사본을 핸들러에 넘깁니다. ServeMux는 GET 라우트로 HEAD도 받는데
// 계약에는 HEAD operation이 없으므로, GET과 같은 규칙을 적용해 검증 우회를 막습니다(RFC 9110 §9.3.2).
// 응답 본문은 net/http가 원래 요청이 HEAD임을 보고 버립니다.
//
// logger에는 계약 router가 라우트를 찾지 못하거나 분류되지 않는 오류가 생겼을 때만 오류 타입과 route 패턴을 남깁니다.
// 요청 값은 남기지 않습니다.
func ValidateRequests(spec *openapi3.T, logger *slog.Logger) func(http.Handler) http.Handler {
	// 호출자의 spec은 바꾸지 않습니다. 검증기가 Host를 servers와 대조하지 않게 servers도 비웁니다.
	validationSpec := *spec
	validationSpec.OpenAPI = validationOpenAPIVersion
	validationSpec.Servers = nil

	options := &nethttpmiddleware.Options{
		Options: openapi3filter.Options{
			// 위반을 한 번에 모두 돌려줘 app이 필드 오류를 함께 보여 줄 수 있게 합니다.
			MultiError:          true,
			SkipSettingDefaults: true,
			// 인증 검사는 P2에서 넣습니다. 그때까지 모든 security 요구를 통과시킵니다.
			AuthenticationFunc: func(context.Context, *openapi3filter.AuthenticationInput) error { return nil },
		},
		SilenceServersWarning: true,
		ErrorHandlerWithOpts: func(ctx context.Context, err error, w http.ResponseWriter, r *http.Request, opts nethttpmiddleware.ErrorHandlerOpts) {
			writeValidationProblem(ctx, logger, err, w, r, opts)
		},
	}
	// 계약 router(gorillamux)는 여기서 한 번만 만들고 모든 라우트가 함께 씁니다.
	validate := nethttpmiddleware.OapiRequestValidatorWithOptions(&validationSpec, options)

	return func(next http.Handler) http.Handler {
		validator := validate(next)
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method == http.MethodHead {
				r = r.Clone(r.Context())
				r.Method = http.MethodGet
			}
			validator.ServeHTTP(w, r)
		})
	}
}

// writeValidationProblem은 nethttp-middleware의 검증 실패를 problem 응답으로 씁니다.
func writeValidationProblem(ctx context.Context, logger *slog.Logger, err error, w http.ResponseWriter, r *http.Request, opts nethttpmiddleware.ErrorHandlerOpts) {
	if opts.MatchedRoute == nil {
		// ServeMux가 고른 라우트를 계약 router가 찾지 못한 경우입니다(경로 정규화 차이 등). 검증 없이 넘기지 않습니다.
		logger.ErrorContext(ctx, "계약 router가 라우트를 찾지 못함", "route", r.Pattern, "errorType", fmt.Sprintf("%T", err))
		problem.Write(w, r, problem.New(http.StatusNotFound, "route.not_found", "Route not found"))
		return
	}
	p, classified := validationProblem(err, unsupportedMediaType(r, opts.MatchedRoute.Route.Operation))
	if !classified {
		logger.ErrorContext(ctx, "분류되지 않는 검증 오류", "route", r.Pattern, "errorType", fmt.Sprintf("%T", err))
	}
	problem.Write(w, r, p)
}

// unsupportedMediaType은 operation이 본문을 받는데 요청 Content-Type(파라미터 제외)이 계약의 content에 없는지 봅니다.
func unsupportedMediaType(r *http.Request, operation *openapi3.Operation) bool {
	if operation == nil || operation.RequestBody == nil || operation.RequestBody.Value == nil {
		return false
	}
	mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil {
		mediaType = ""
	}
	return operation.RequestBody.Value.Content.Get(mediaType) == nil
}

// validationProblem은 검증 오류를 상태와 코드로 분류합니다. 우선순위는 413, 415, 400 malformed, 400 invalid입니다.
// mediaTypeUnsupported는 요청 Content-Type이 계약에 없는지입니다. 분류하지 못하면 500과 false를 돌려줍니다.
func validationProblem(err error, mediaTypeUnsupported bool) (problem.Problem, bool) {
	var tooLarge *http.MaxBytesError
	if errors.As(err, &tooLarge) {
		return problem.New(http.StatusRequestEntityTooLarge, "request.too_large", "Request body is too large"), true
	}

	requestErrors, ok := collectRequestErrors(err)
	if !ok {
		// 인증 통과 함수를 쓰므로 RequestError가 아닌 오류는 생기지 않아야 합니다.
		return problem.New(http.StatusInternalServerError, "internal", "Internal server error"), false
	}

	var fieldErrors []problem.FieldError
	unsupported, malformed := false, false
	for _, requestError := range requestErrors {
		switch {
		// 본문이 비어 있으면 Content-Type과 관계없이 필수 본문 누락(400)입니다.
		case requestError.RequestBody != nil && mediaTypeUnsupported && !errors.Is(requestError.Err, openapi3filter.ErrInvalidRequired):
			unsupported = true
		case requestError.RequestBody != nil && requestError.Reason == reasonBodyDecodeFailed:
			malformed = true
		case requestError.Parameter != nil:
			fieldErrors = append(fieldErrors, fieldErrorsOf(requestError.Err, requestError.Parameter.Name, false)...)
		default:
			fieldErrors = append(fieldErrors, fieldErrorsOf(requestError.Err, "", true)...)
		}
	}

	switch {
	case unsupported:
		return problem.New(http.StatusUnsupportedMediaType, codeUnsupportedMediaType, "Unsupported request content type"), true
	case malformed:
		return problem.New(http.StatusBadRequest, codeRequestMalformed, "Request body is malformed"), true
	}
	p := problem.New(http.StatusBadRequest, codeRequestInvalid, "Request does not match the contract")
	p.Errors = fieldErrors
	return p, true
}

// collectRequestErrors는 MultiError를 펼쳐 RequestError 목록을 돌려줍니다. 다른 종류가 섞이면 false입니다.
// RequestError 안쪽에도 MultiError가 있으므로 errors.As가 아니라 바깥 타입으로 가립니다.
func collectRequestErrors(err error) ([]*openapi3filter.RequestError, bool) {
	switch typed := err.(type) { //nolint:errorlint // 바깥 타입으로만 가르려는 의도입니다(위 주석 참고)
	case *openapi3filter.RequestError:
		return []*openapi3filter.RequestError{typed}, true
	case openapi3.MultiError:
		var all []*openapi3filter.RequestError
		for _, inner := range typed {
			collected, ok := collectRequestErrors(inner)
			if !ok {
				return nil, false
			}
			all = append(all, collected...)
		}
		return all, true
	default:
		return nil, false
	}
}

// fieldErrorsOf는 RequestError.Err 하나를 FieldError로 바꿉니다.
// inBody면 위치를 JSON Pointer로, 아니면 parameter 이름(base)을 그대로 씁니다.
// errors[].code는 위반한 JSON Schema keyword(required, pattern, minimum, format 등)이고,
// parameter를 타입으로 읽지 못하면 type입니다.
func fieldErrorsOf(err error, base string, inBody bool) []problem.FieldError {
	switch typed := err.(type) { //nolint:errorlint // 바깥 타입으로만 가르려는 의도입니다(위 주석 참고)
	case openapi3.MultiError:
		var all []problem.FieldError
		for _, inner := range typed {
			all = append(all, fieldErrorsOf(inner, base, inBody)...)
		}
		return all
	case *openapi3.SchemaError:
		field := base
		if inBody {
			field = jsonPointer(typed.JSONPointer())
		}
		code := typed.SchemaField
		if code == "" {
			code = "invalid"
		}
		return []problem.FieldError{{Field: field, Code: code}}
	}

	var parseError *openapi3filter.ParseError
	switch {
	case errors.Is(err, openapi3filter.ErrInvalidRequired), errors.Is(err, openapi3filter.ErrInvalidEmptyValue):
		return []problem.FieldError{{Field: base, Code: "required"}}
	case errors.As(err, &parseError):
		return []problem.FieldError{{Field: base, Code: "type"}}
	default:
		return []problem.FieldError{{Field: base, Code: "invalid"}}
	}
}

// jsonPointer는 경로 조각을 RFC 6901 JSON Pointer로 만듭니다. 빈 경로는 문서 전체("")입니다.
func jsonPointer(segments []string) string {
	var builder strings.Builder
	escaper := strings.NewReplacer("~", "~0", "/", "~1")
	for _, segment := range segments {
		builder.WriteString("/")
		builder.WriteString(escaper.Replace(segment))
	}
	return builder.String()
}
