package api_test

import (
	"context"
	"fmt"
	"iter"
	"os"
	"slices"
	"strconv"
	"strings"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"gopkg.in/yaml.v3"
)

const specPath = "openapi.yaml"

const problemRef = "#/components/schemas/Problem"

const identityInUseProblemRef = "#/components/schemas/IdentityInUseProblem"

// expectedOperationIDs는 계약의 operation 표 전체입니다.
var expectedOperationIDs = []string{
	"loginKakao", "loginApple", "appleCallback", "completeAppleWebLogin", "refreshToken", "logout",
	"getMe", "deleteMe", "agreeConsents", "createProfile", "updateProfile", "getProfile",
	"getDaily", "getChart", "getCalendar", "putReaction", "deleteReaction",
	"getGlossary", "createPreview", "getBirthHour", "convertLunarDate",
	"listDiaries", "createDiary", "getDiary", "updateDiary", "deleteDiary", "restoreDiary",
	"listSchedules", "createSchedule", "updateSchedule", "deleteSchedule", "restoreSchedule",
	"registerDevice", "deleteDevice",
	"getEntitlements", "restorePurchases", "revenuecatWebhook", "admobRewardCallback",
	"listCities", "getAppConfig", "getHealth",
	"loginLine", "loginGoogle", "listIdentities", "linkIdentity", "unlinkIdentity", "previewMerge", "mergeAccounts",
}

// securityOverrides는 최상위 bearerAuth를 덮어쓰는 operation과 그 security scheme 이름입니다.
// 빈 목록은 인증 없음(security: [])입니다.
var securityOverrides = map[string][]string{
	"loginKakao":            {},
	"loginApple":            {},
	"loginLine":             {},
	"loginGoogle":           {},
	"appleCallback":         {},
	"completeAppleWebLogin": {},
	"refreshToken":          {},
	"revenuecatWebhook":     {},
	"admobRewardCallback":   {},
	"listCities":            {},
	"getAppConfig":          {},
	"getHealth":             {},
	"createPreview":         {"appCheck"},
	"getBirthHour":          {"appCheck"},
	"convertLunarDate":      {"appCheck"},
}

func loadDoc(t *testing.T) *openapi3.T {
	t.Helper()
	loader := openapi3.NewLoader()
	doc, err := loader.LoadFromFile(specPath)
	if err != nil {
		t.Fatalf("계약을 읽지 못함: %v", err)
	}
	return doc
}

// forEachOperation은 모든 operation을 operationId와 함께 돌려줍니다.
func forEachOperation(doc *openapi3.T, visit func(operationID string, op *openapi3.Operation)) {
	for _, pathItem := range doc.Paths.Map() {
		for _, op := range pathItem.Operations() {
			visit(op.OperationID, op)
		}
	}
}

func TestContract_LoadsAndValidates(t *testing.T) {
	doc := loadDoc(t)

	if err := doc.Validate(context.Background()); err != nil {
		t.Fatalf("계약 검증 실패: %v", err)
	}
	if doc.OpenAPI != "3.1.0" {
		t.Fatalf("openapi = %q, want 3.1.0", doc.OpenAPI)
	}
}

func TestContract_OperationIDs(t *testing.T) {
	doc := loadDoc(t)

	var got []string
	forEachOperation(doc, func(operationID string, _ *openapi3.Operation) {
		got = append(got, operationID)
	})

	want := slices.Clone(expectedOperationIDs)
	slices.Sort(got)
	slices.Sort(want)
	if !slices.Equal(got, want) {
		t.Fatalf("operationId 집합이 다름\n got: %v\nwant: %v", got, want)
	}
}

func TestContract_ErrorsAreProblems(t *testing.T) {
	doc := loadDoc(t)

	forEachOperation(doc, func(operationID string, op *openapi3.Operation) {
		if op.Responses.Value("default") == nil {
			t.Errorf("%s: default 응답이 없음", operationID)
		}
		for status, ref := range op.Responses.Map() {
			isError := status == "default" || strings.HasPrefix(status, "4") || strings.HasPrefix(status, "5")
			if !isError {
				continue
			}
			content := ref.Value.Content
			if len(content) != 1 {
				t.Errorf("%s %s: content type이 하나가 아님: %v", operationID, status, mapKeys(content))
				continue
			}
			media := content.Get("application/problem+json")
			if media == nil {
				t.Errorf("%s %s: application/problem+json이 아님: %v", operationID, status, mapKeys(content))
				continue
			}
			wantRef := problemRef
			if operationID == "linkIdentity" && status == "409" {
				wantRef = identityInUseProblemRef // Problem에 mergeToken·expiresAt을 더한 확장
			}
			if media.Schema == nil || media.Schema.Ref != wantRef {
				t.Errorf("%s %s: schema가 %s 참조가 아님", operationID, status, wantRef)
			}
		}
	})
}

func TestContract_SecurityByDefault(t *testing.T) {
	doc := loadDoc(t)

	if len(doc.Security) != 1 || !hasOnlyScheme(doc.Security[0], "bearerAuth") {
		t.Fatalf("최상위 security가 bearerAuth 하나가 아님: %v", doc.Security)
	}

	forEachOperation(doc, func(operationID string, op *openapi3.Operation) {
		wantSchemes, overrides := securityOverrides[operationID]
		if !overrides {
			if op.Security != nil {
				t.Errorf("%s: bearer operation이 security를 덮어씀: %v", operationID, *op.Security)
			}
			return
		}
		if op.Security == nil {
			t.Errorf("%s: security를 덮어쓰지 않음", operationID)
			return
		}
		got := *op.Security
		if len(got) != len(wantSchemes) {
			t.Errorf("%s: security = %v, want %v", operationID, got, wantSchemes)
			return
		}
		for i, scheme := range wantSchemes {
			if !hasOnlyScheme(got[i], scheme) {
				t.Errorf("%s: security[%d] = %v, want %s", operationID, i, got[i], scheme)
			}
		}
	})
}

func TestContract_NoNullTypes(t *testing.T) {
	walkNoNull(t, loadYAML(t))
}

// loadYAML은 계약을 해석 없이 YAML node 트리로 읽습니다. 키워드 사용 여부처럼 kin-openapi가 지우는 정보를 볼 때 씁니다.
func loadYAML(t *testing.T) *yaml.Node {
	t.Helper()
	raw, err := os.ReadFile(specPath)
	if err != nil {
		t.Fatalf("계약을 읽지 못함: %v", err)
	}
	var root yaml.Node
	if err := yaml.Unmarshal(raw, &root); err != nil {
		t.Fatalf("YAML 파싱 실패: %v", err)
	}
	return &root
}

// walkNoNull은 nullable 키, null 타입, type 배열(3.1에서 null을 섞는 문법), null 값을 찾아 실패로 기록합니다.
func walkNoNull(t *testing.T, node *yaml.Node) {
	t.Helper()
	if node.Kind == yaml.ScalarNode && node.Tag == "!!null" {
		t.Errorf("line %d: null 값", node.Line)
	}
	if node.Kind == yaml.MappingNode {
		for i := 0; i+1 < len(node.Content); i += 2 {
			key, value := node.Content[i], node.Content[i+1]
			switch {
			case key.Value == "nullable":
				t.Errorf("line %d: nullable 사용", key.Line)
			case key.Value == "type" && value.Kind == yaml.ScalarNode && value.Value == "null":
				t.Errorf("line %d: null 타입", key.Line)
			case key.Value == "type" && value.Kind == yaml.SequenceNode:
				t.Errorf("line %d: type 배열", key.Line)
			}
		}
	}
	for _, child := range node.Content {
		walkNoNull(t, child)
	}
}

func TestContract_CreatePostsAcceptIdempotencyKey(t *testing.T) {
	doc := loadDoc(t)

	operations := map[string]*openapi3.Operation{}
	forEachOperation(doc, func(operationID string, op *openapi3.Operation) {
		operations[operationID] = op
	})

	for _, operationID := range []string{"createSchedule", "registerDevice", "createDiary"} {
		op := operations[operationID]
		if op == nil {
			t.Errorf("%s: operation이 없음", operationID)
			continue
		}
		param := op.Parameters.GetByInAndName(openapi3.ParameterInHeader, "Idempotency-Key")
		if param == nil {
			t.Errorf("%s: Idempotency-Key 헤더가 없음", operationID)
			continue
		}
		if param.Required {
			t.Errorf("%s: Idempotency-Key가 필수로 되어 있음", operationID)
		}
		schema := param.Schema.Value
		if schema.MinLength != 1 || schema.MaxLength == nil || *schema.MaxLength != 255 {
			t.Errorf("%s: Idempotency-Key 길이가 1~255가 아님", operationID)
		}
	}
}

func TestContract_ProblemRequiresCodeAndTraceID(t *testing.T) {
	doc := loadDoc(t)

	problem := doc.Components.Schemas["Problem"]
	if problem == nil {
		t.Fatal("Problem 스키마가 없음")
	}
	for _, field := range []string{"type", "title", "status", "code", "traceId"} {
		if !slices.Contains(problem.Value.Required, field) {
			t.Errorf("Problem.%s가 필수가 아님", field)
		}
	}
}

func TestContract_EvidenceAccessRequired(t *testing.T) {
	doc := loadDoc(t)

	// Preview는 항상 locked이지만 근거 부재와 잠금을 구분하려고 같은 필드를 둡니다.
	for _, name := range []string{"Daily", "Chart", "Calendar", "Preview"} {
		schema := doc.Components.Schemas[name]
		if schema == nil {
			t.Errorf("%s 스키마가 없음", name)
			continue
		}
		if !slices.Contains(schema.Value.Required, "evidenceAccess") {
			t.Errorf("%s.evidenceAccess가 필수가 아님", name)
		}
		property := schema.Value.Properties["evidenceAccess"]
		if property == nil || property.Ref != "#/components/schemas/EvidenceAccess" {
			t.Errorf("%s.evidenceAccess가 EvidenceAccess 참조가 아님", name)
		}
	}
}

func TestContract_NoOpenAPI31OnlySyntax(t *testing.T) {
	for _, violation := range openAPI30Violations(loadYAML(t)) {
		t.Error(violation)
	}
}

// 위반 검출기 자체를 확인합니다. properties 아래 필드 이름은 키워드가 아니므로 통과하고,
// 스키마 위치의 3.1 전용 키워드·숫자형 exclusiveMinimum·$ref 형제 키·3.1 최상위 키는 실패해야 합니다.
func TestOpenAPI30Violations_DetectsKeywordsButNotPropertyNames(t *testing.T) {
	const allowed = `
openapi: 3.1.0
components:
  schemas:
    Ok:
      type: object
      x-internal: true
      properties:
        const: {type: string}
        if: {$ref: '#/components/schemas/Other'}
      example: {const: 1, prefixItems: []}
paths:
  /x:
    get:
      parameters:
        - name: q
          in: query
          schema: {type: integer, minimum: 0, exclusiveMinimum: true}
`
	if got := openAPI30Violations(parseYAML(t, allowed)); len(got) != 0 {
		t.Errorf("오탐: %v", got)
	}

	const violating = `
openapi: 3.1.0
webhooks: {}
components:
  pathItems: {}
  schemas:
    Bad:
      type: object
      properties:
        a: {const: x}
        b: {type: integer, exclusiveMinimum: 0}
        c: {$ref: '#/components/schemas/Other', description: sibling}
      unevaluatedProperties: false
paths:
  /x:
    get:
      responses:
        '200':
          content:
            application/json:
              schema: {type: array, prefixItems: [{type: string}]}
`
	got := openAPI30Violations(parseYAML(t, violating))
	if len(got) != 7 {
		t.Errorf("위반 %d개, want 7: %v", len(got), got)
	}
}

func parseYAML(t *testing.T, source string) *yaml.Node {
	t.Helper()
	var root yaml.Node
	if err := yaml.Unmarshal([]byte(source), &root); err != nil {
		t.Fatalf("YAML 파싱 실패: %v", err)
	}
	return &root
}

// schemaKeywords는 OpenAPI 3.0.3 Schema Object가 허용하는 키워드입니다. x- 확장은 따로 허용합니다.
// nullable은 3.0 키워드라 여기서는 허용하고, 사용 금지는 TestContract_NoNullTypes가 맡습니다.
var schemaKeywords = map[string]bool{
	"$ref": true, "title": true, "description": true, "type": true, "format": true,
	"multipleOf": true, "maximum": true, "exclusiveMaximum": true, "minimum": true, "exclusiveMinimum": true,
	"maxLength": true, "minLength": true, "pattern": true,
	"maxItems": true, "minItems": true, "uniqueItems": true, "items": true,
	"maxProperties": true, "minProperties": true, "required": true, "properties": true, "additionalProperties": true,
	"enum": true, "allOf": true, "oneOf": true, "anyOf": true, "not": true,
	"default": true, "nullable": true, "discriminator": true, "readOnly": true, "writeOnly": true,
	"xml": true, "externalDocs": true, "example": true, "deprecated": true,
}

// documentKeys와 componentKeys는 3.0.3 최상위·components 객체의 키입니다(3.1의 webhooks·pathItems를 막습니다).
var (
	documentKeys = map[string]bool{
		"openapi": true, "info": true, "servers": true, "paths": true, "components": true,
		"security": true, "tags": true, "externalDocs": true,
	}
	componentKeys = map[string]bool{
		"schemas": true, "responses": true, "parameters": true, "examples": true, "requestBodies": true,
		"headers": true, "securitySchemes": true, "links": true, "callbacks": true,
	}
)

// openAPI30Violations는 계약이 OpenAPI 3.0.3으로 읽혀도 같은 뜻인지 검사해 위반을 돌려줍니다.
// server의 요청 검증은 계약 사본을 3.0.3으로 읽으므로(internal/httpapi/validate.go) 이 검사가 그 전제를 지킵니다.
// 스키마 위치(components.schemas와 모든 schema 키)에서는 schemaKeywords allowlist 밖 키워드,
// 숫자형 exclusiveMinimum·exclusiveMaximum(3.0에서는 bool), $ref 형제 키를 위반으로 봅니다.
// properties 아래 키는 필드 이름이고 example 아래는 데이터이므로 키워드로 보지 않습니다.
func openAPI30Violations(root *yaml.Node) []string {
	var violations []string
	report := func(node *yaml.Node, format string, args ...any) {
		violations = append(violations, fmt.Sprintf("line %d: ", node.Line)+fmt.Sprintf(format, args...))
	}

	var walkSchema func(node *yaml.Node)
	walkSchema = func(node *yaml.Node) {
		if node.Kind != yaml.MappingNode {
			report(node, "스키마가 객체가 아님")
			return
		}
		hasRef := false
		for key, value := range mappingPairs(node) {
			name := key.Value
			if strings.HasPrefix(name, "x-") {
				continue
			}
			if !schemaKeywords[name] {
				report(key, "OpenAPI 3.0 Schema Object에 없는 키워드 %s", name)
				continue
			}
			switch name {
			case "$ref":
				hasRef = true
			case "exclusiveMinimum", "exclusiveMaximum":
				if value.Tag != "!!bool" {
					report(key, "3.1 전용 숫자형 %s", name)
				}
			case "properties":
				for _, propertySchema := range mappingPairs(value) {
					walkSchema(propertySchema)
				}
			case "items", "not":
				walkSchema(value)
			case "additionalProperties":
				if value.Kind == yaml.MappingNode {
					walkSchema(value)
				}
			case "allOf", "oneOf", "anyOf":
				for _, item := range value.Content {
					walkSchema(item)
				}
			}
		}
		if hasRef && len(node.Content) > 2 {
			report(node, "$ref에 형제 키가 있음")
		}
	}

	// walkDocument는 스키마가 아닌 위치를 돌며 schema 키를 찾아 walkSchema로 넘깁니다.
	var walkDocument func(node *yaml.Node)
	walkDocument = func(node *yaml.Node) {
		if node.Kind == yaml.MappingNode {
			for key, value := range mappingPairs(node) {
				switch key.Value {
				case "schema":
					walkSchema(value)
				case "example", "examples":
					// 예시 값은 데이터입니다.
				default:
					walkDocument(value)
				}
			}
			return
		}
		for _, child := range node.Content {
			walkDocument(child)
		}
	}

	document := root
	if document.Kind == yaml.DocumentNode && len(document.Content) == 1 {
		document = document.Content[0]
	}
	for key, value := range mappingPairs(document) {
		if !documentKeys[key.Value] && !strings.HasPrefix(key.Value, "x-") {
			report(key, "OpenAPI 3.0 최상위에 없는 키 %s", key.Value)
			continue
		}
		if key.Value != "components" {
			walkDocument(value)
			continue
		}
		for componentKey, components := range mappingPairs(value) {
			switch {
			case strings.HasPrefix(componentKey.Value, "x-"):
			case !componentKeys[componentKey.Value]:
				report(componentKey, "OpenAPI 3.0 components에 없는 키 %s", componentKey.Value)
			case componentKey.Value == "schemas":
				for _, schema := range mappingPairs(components) {
					walkSchema(schema)
				}
			default:
				walkDocument(components)
			}
		}
	}
	return violations
}

// mappingPairs는 mapping node의 키·값 쌍을 순서대로 돌려줍니다. mapping이 아니면 아무것도 돌려주지 않습니다.
func mappingPairs(node *yaml.Node) iter.Seq2[*yaml.Node, *yaml.Node] {
	return func(yield func(*yaml.Node, *yaml.Node) bool) {
		if node.Kind != yaml.MappingNode {
			return
		}
		for i := 0; i+1 < len(node.Content); i += 2 {
			if !yield(node.Content[i], node.Content[i+1]) {
				return
			}
		}
	}
}

func hasOnlyScheme(requirement openapi3.SecurityRequirement, scheme string) bool {
	_, ok := requirement[scheme]
	return ok && len(requirement) == 1
}

func mapKeys(content openapi3.Content) []string {
	keys := make([]string, 0, len(content))
	for key := range content {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	return keys
}

// TestContract_LoginNonceDocumentsHashRule은 두 로그인 요청의 nonce가
// "원문 + SHA-256 hex 규칙"과 길이 범위를 문서화하는지 확인합니다.
func TestContract_LoginNonceDocumentsHashRule(t *testing.T) {
	doc := loadDoc(t)

	for _, name := range []string{"KakaoLoginRequest", "AppleLoginRequest", "LineLoginRequest", "GoogleLoginRequest", "LinkIdentityRequest"} {
		ref := doc.Components.Schemas[name]
		if ref == nil || ref.Value.Properties["nonce"] == nil {
			t.Errorf("%s: nonce 속성이 없음", name)
			continue
		}
		nonce := ref.Value.Properties["nonce"].Value
		if !strings.Contains(nonce.Description, "SHA-256") {
			t.Errorf("%s: nonce 설명에 SHA-256 규칙이 없음", name)
		}
		if nonce.MinLength != 16 {
			t.Errorf("%s: nonce minLength = %d, want 16", name, nonce.MinLength)
		}
		if nonce.MaxLength == nil || *nonce.MaxLength != 256 {
			t.Errorf("%s: nonce maxLength가 256이 아님", name)
		}
	}

	// nonce를 받는 operation은 설명 또는 요청 스키마의 nonce 설명에 해시 규칙이 있어야 합니다.
	for _, id := range []string{"loginKakao", "loginApple", "loginLine", "loginGoogle", "linkIdentity"} {
		op := operationByID(t, doc, id)
		documented := strings.Contains(op.Description, "SHA-256")
		if body := op.RequestBody; body != nil && body.Value != nil && body.Value.Content["application/json"] != nil {
			if nonce := body.Value.Content["application/json"].Schema.Value.Properties["nonce"]; nonce != nil {
				documented = documented || strings.Contains(nonce.Value.Description, "SHA-256")
			}
		}
		if !documented {
			t.Errorf("%s: 설명과 요청 스키마 nonce 설명 어디에도 SHA-256 규칙이 없음", id)
		}
	}
	for _, text := range []string{"일회용으로 기록하지 않습니다", "Google"} {
		if !strings.Contains(doc.Info.Description, text) {
			t.Errorf("info.description에 %q가 없음", text)
		}
	}
}

// TestContract_AppleCallbackAcceptsCancellation은 사용자가 Apple 로그인을 취소했을 때
// code·id_token 없이 error·state만 오는 form을 계약이 허용하는지 확인합니다.
func TestContract_AppleCallbackAcceptsCancellation(t *testing.T) {
	doc := loadDoc(t)

	var form *openapi3.Schema
	forEachOperation(doc, func(operationID string, op *openapi3.Operation) {
		if operationID != "appleCallback" {
			return
		}
		form = op.RequestBody.Value.Content["application/x-www-form-urlencoded"].Schema.Value
	})
	if form == nil {
		t.Fatal("appleCallback form 스키마가 없음")
	}
	if len(form.Required) != 1 || form.Required[0] != "state" {
		t.Errorf("required = %v, want [state]", form.Required)
	}
	if form.Properties["error"] == nil {
		t.Error("properties에 error가 없음")
	}
}

// TestContract_AgreeConsentsDeclares422는 동의 문서 버전 불일치(422)를 계약이 선언하는지 확인합니다.
func TestContract_AgreeConsentsDeclares422(t *testing.T) {
	doc := loadDoc(t)

	found := false
	forEachOperation(doc, func(operationID string, op *openapi3.Operation) {
		if operationID != "agreeConsents" {
			return
		}
		found = true
		resp := op.Responses.Value("422")
		if resp == nil {
			t.Error("agreeConsents.responses에 422가 없음")
			return
		}
		if resp.Ref != "#/components/responses/UnprocessableEntity" {
			t.Errorf("agreeConsents 422 = %q, want UnprocessableEntity 참조", resp.Ref)
		}
	})
	if !found {
		t.Fatal("agreeConsents operation이 없음")
	}

	unprocessable := doc.Components.Responses["UnprocessableEntity"]
	if unprocessable == nil || unprocessable.Value == nil || unprocessable.Value.Description == nil {
		t.Fatal("components.responses.UnprocessableEntity 설명이 없음")
	}
	if !strings.Contains(*unprocessable.Value.Description, "consent.version_mismatch") {
		t.Error("UnprocessableEntity 설명에 consent.version_mismatch가 없음")
	}
}

// TestContract_AppleCallbackDescribes400은 appleCallback 설명이 400이 되는 조건을 적는지 확인합니다.
func TestContract_AppleCallbackDescribes400(t *testing.T) {
	doc := loadDoc(t)

	found := false
	forEachOperation(doc, func(operationID string, op *openapi3.Operation) {
		if operationID != "appleCallback" {
			return
		}
		found = true
		const want = "`state`가 없거나 비어 있으면 400입니다."
		if !strings.Contains(op.Description, want) {
			t.Errorf("appleCallback 설명에 %q가 없음", want)
		}
		// 빈 state도 계약 검증이 거부하도록 스키마에 최소 길이를 둡니다.
		form := op.RequestBody.Value.Content.Get("application/x-www-form-urlencoded")
		if form == nil || form.Schema.Value.Properties["state"] == nil || form.Schema.Value.Properties["state"].Value.MinLength != 1 {
			t.Error("appleCallback form의 state에 minLength: 1이 없음")
		}
		if op.Responses.Value("400") == nil {
			t.Error("appleCallback.responses에 400이 없음")
		}
	})
	if !found {
		t.Fatal("appleCallback operation이 없음")
	}
}

// problemCodeEntry는 Problem.code의 `x-problem-codes` 항목 하나입니다.
type problemCodeEntry struct {
	Status      int    `yaml:"status"`
	Description string `yaml:"description"`
}

// loadProblemCodes는 계약 원본에서 `x-problem-codes`를 읽습니다.
func loadProblemCodes(t *testing.T) map[string]problemCodeEntry {
	t.Helper()
	raw, err := os.ReadFile(specPath)
	if err != nil {
		t.Fatalf("계약을 읽지 못함: %v", err)
	}
	var spec struct {
		Components struct {
			Schemas struct {
				Problem struct {
					Properties struct {
						Code struct {
							Codes map[string]problemCodeEntry `yaml:"x-problem-codes"`
						} `yaml:"code"`
					} `yaml:"properties"`
				} `yaml:"Problem"`
			} `yaml:"schemas"`
		} `yaml:"components"`
	}
	if err := yaml.Unmarshal(raw, &spec); err != nil {
		t.Fatalf("YAML 파싱 실패: %v", err)
	}
	return spec.Components.Schemas.Problem.Properties.Code.Codes
}

// TestContract_ProblemCodesAreWellFormed는 `x-problem-codes`의 모든 항목이 HTTP 오류 상태(400~599)와
// 비어 있지 않은 설명을 갖는지 확인합니다.
func TestContract_ProblemCodesAreWellFormed(t *testing.T) {
	codes := loadProblemCodes(t)
	if len(codes) == 0 {
		t.Fatal("Problem.code에 x-problem-codes가 없음")
	}
	for code, entry := range codes {
		if entry.Status < 400 || entry.Status > 599 {
			t.Errorf("%s: status %d가 400~599 밖임", code, entry.Status)
		}
		if strings.TrimSpace(entry.Description) == "" {
			t.Errorf("%s: description이 비어 있음", code)
		}
	}
}

// TestContract_ProblemCodesSurviveLoad는 kin-openapi가 읽은 뒤에도 확장 필드가 남는지 확인합니다.
// 검증용 3.0 사본은 같은 loader 결과를 변환하므로, 여기서 남으면 사본에도 남습니다.
func TestContract_ProblemCodesSurviveLoad(t *testing.T) {
	doc := loadDoc(t)
	problem := doc.Components.Schemas["Problem"]
	if problem == nil || problem.Value == nil || problem.Value.Properties["code"] == nil || problem.Value.Properties["code"].Value == nil {
		t.Fatal("Problem.code 스키마를 읽지 못함")
	}
	code := problem.Value.Properties["code"].Value
	if _, ok := code.Extensions["x-problem-codes"]; !ok {
		t.Error("kin-openapi가 읽은 Problem.code에 x-problem-codes가 없음")
	}
}

func TestContract_VersionIsDraft14(t *testing.T) {
	doc := loadDoc(t)
	if doc.Info.Version != "1.0.0-draft.14" {
		t.Errorf("info.version = %q, want 1.0.0-draft.14", doc.Info.Version)
	}
}

// TestContract_Draft12DaeunStartYear는 대운 시작 양력 연도 DaeunPeriod.startYear(필수 정수)를 고정합니다. (S94, app 요청 #351)
func TestContract_Draft12DaeunStartYear(t *testing.T) {
	doc := loadDoc(t)
	period := doc.Components.Schemas["DaeunPeriod"].Value
	startYear := period.Properties["startYear"]
	if startYear == nil {
		t.Fatal("DaeunPeriod.startYear가 없음")
	}
	if !slices.Contains(period.Required, "startYear") {
		t.Error("DaeunPeriod.startYear가 required에 없음")
	}
	if !startYear.Value.Type.Is("integer") {
		t.Errorf("DaeunPeriod.startYear type = %v, want integer", startYear.Value.Type)
	}
	for _, text := range []string{"양력 연도", "`startAgeKorean` = `startYear` - 출생 양력 연도 + 1"} {
		if !strings.Contains(startYear.Value.Description, text) {
			t.Errorf("DaeunPeriod.startYear 설명에 %q가 없음", text)
		}
	}
}

// TestContract_DeviceOperations는 알림 기기 계약(S92)을 확인합니다. 이미 등록된 토큰은 같은 Device로 200,
// 새 토큰은 201이고, 해제의 404는 device.not_found입니다.
func TestContract_DeviceOperations(t *testing.T) {
	doc := loadDoc(t)
	register := operationByID(t, doc, "registerDevice")
	for _, status := range []int{200, 201} {
		resp := register.Responses.Status(status)
		if resp == nil || resp.Value == nil || resp.Value.Content.Get("application/json") == nil {
			t.Errorf("registerDevice %d 응답(application/json)이 없음", status)
		}
	}
	if operationByID(t, doc, "deleteDevice").Responses.Status(404) == nil {
		t.Error("deleteDevice 404 응답이 없음")
	}
	entry, ok := loadProblemCodes(t)["device.not_found"]
	if !ok {
		t.Fatal("x-problem-codes에 device.not_found가 없음")
	}
	if entry.Status != 404 {
		t.Errorf("device.not_found status = %d, want 404", entry.Status)
	}
}

// TestContract_ResponsesMatchImplementation은 S3 점검에서 맞춘 응답 목록을 확인합니다(S93).
// completeAppleWebLogin에는 요청 한도가 없고, admobRewardCallback은 query 검증 400과 저장 실패 500을 냅니다.
func TestContract_ResponsesMatchImplementation(t *testing.T) {
	doc := loadDoc(t)
	if operationByID(t, doc, "completeAppleWebLogin").Responses.Status(429) != nil {
		t.Error("completeAppleWebLogin에 나지 않는 429 응답이 있음")
	}
	admob := operationByID(t, doc, "admobRewardCallback")
	for _, status := range []int{400, 500} {
		if admob.Responses.Status(status) == nil {
			t.Errorf("admobRewardCallback %d 응답이 없음", status)
		}
	}
}

// operationByID는 operationId로 operation을 찾습니다. 없으면 테스트를 멈춥니다.
func operationByID(t *testing.T, doc *openapi3.T, id string) *openapi3.Operation {
	t.Helper()
	var found *openapi3.Operation
	forEachOperation(doc, func(operationID string, op *openapi3.Operation) {
		if operationID == id {
			found = op
		}
	})
	if found == nil {
		t.Fatalf("%s operation이 없음", id)
	}
	return found
}

// okSchemaRef는 200 JSON 응답 스키마의 $ref입니다.
func okSchemaRef(t *testing.T, op *openapi3.Operation) string {
	t.Helper()
	ok := op.Responses.Value("200")
	if ok == nil {
		t.Fatal("200 응답이 없음")
	}
	return ok.Value.Content["application/json"].Schema.Ref
}

func TestContract_GetProfileExists(t *testing.T) {
	doc := loadDoc(t)
	op := operationByID(t, doc, "getProfile")

	if got := doc.Paths.Find("/v1/me/profile").Get; got != op {
		t.Error("getProfile이 GET /v1/me/profile이 아님")
	}
	if op.Security != nil {
		t.Errorf("getProfile이 bearer 기본 security를 덮어씀: %v", *op.Security)
	}
	if got := okSchemaRef(t, op); got != "#/components/schemas/Profile" {
		t.Errorf("200 schema = %q, want Profile", got)
	}
	if op.Responses.Value("409") == nil {
		t.Error("409 응답이 없음")
	}
}

func TestContract_ConvertLunarDateIsAppCheck(t *testing.T) {
	doc := loadDoc(t)
	op := operationByID(t, doc, "convertLunarDate")

	if got := doc.Paths.Find("/v1/lunar-date").Post; got != op {
		t.Error("convertLunarDate가 POST /v1/lunar-date가 아님")
	}
	if op.Security == nil || len(*op.Security) != 1 || !hasOnlyScheme((*op.Security)[0], "appCheck") {
		t.Errorf("security = %v, want [{appCheck: []}]", op.Security)
	}
	if got := okSchemaRef(t, op); got != "#/components/schemas/LunarConversion" {
		t.Errorf("200 schema = %q, want LunarConversion", got)
	}
	resultRef := doc.Components.Schemas["LunarConversion"]
	if resultRef == nil || resultRef.Value == nil {
		t.Fatal("LunarConversion 스키마를 읽지 못함")
	}
	result := resultRef.Value
	if !slices.Equal(slices.Sorted(slices.Values(result.Required)), []string{"monthHasLeap", "solarDate"}) {
		t.Errorf("LunarConversion.required = %v, want [monthHasLeap solarDate]", result.Required)
	}
	for _, status := range []string{"422", "429"} {
		if op.Responses.Value(status) == nil {
			t.Errorf("%s 응답이 없음", status)
		}
	}
}

func TestContract_DisplayFieldsRequired(t *testing.T) {
	doc := loadDoc(t)
	want := map[string]string{
		"City":        "countryName",
		"Preview":     "dayKindName",
		"Daily":       "characterReason",
		"CalendarDay": "characterReason",
		"Glossary":    "meanings",
	}
	for schema, field := range want {
		ref := doc.Components.Schemas[schema]
		if ref == nil || ref.Value == nil {
			t.Errorf("%s 스키마가 없음", schema)
			continue
		}
		if !slices.Contains(ref.Value.Required, field) {
			t.Errorf("%s.required에 %s가 없음: %v", schema, field, ref.Value.Required)
		}
		if ref.Value.Properties[field] == nil {
			t.Errorf("%s.properties에 %s가 없음", schema, field)
		}
	}
	cityRef := doc.Components.Schemas["City"]
	if cityRef == nil || cityRef.Value == nil {
		t.Fatal("City 스키마를 읽지 못함")
	}
	city := cityRef.Value
	if city.Properties["regionName"] == nil {
		t.Error("City.regionName이 없음")
	}
	if slices.Contains(city.Required, "regionName") {
		t.Error("City.regionName은 선택 필드인데 required에 있음")
	}
}

func TestContract_ProfileProblemCodes(t *testing.T) {
	codes := loadProblemCodes(t)
	for _, code := range []string{"timezone.invalid", "city.not_found"} {
		entry, ok := codes[code]
		if !ok {
			t.Errorf("x-problem-codes에 %s가 없음", code)
			continue
		}
		if entry.Status != 422 {
			t.Errorf("%s status = %d, want 422", code, entry.Status)
		}
	}
}

// TestContract_CompleteAppleWebLoginIsPublic은 교환 코드 완료 operation이 인증 없이 열려 있고
// 요청·401 응답이 계약대로인지 확인합니다.
func TestContract_CompleteAppleWebLoginIsPublic(t *testing.T) {
	doc := loadDoc(t)

	found := false
	forEachOperation(doc, func(operationID string, op *openapi3.Operation) {
		if operationID != "completeAppleWebLogin" {
			return
		}
		found = true
		if op.Security == nil || len(*op.Security) != 0 {
			t.Errorf("security = %v, want 빈 배열", op.Security)
		}
		body := op.RequestBody.Value.Content["application/json"].Schema.Value
		if !slices.Equal(slices.Sorted(slices.Values(body.Required)), []string{"exchangeCode", "nonce"}) {
			t.Errorf("required = %v, want [exchangeCode nonce]", body.Required)
		}
		code := body.Properties["exchangeCode"].Value
		if code.MinLength != 43 || code.MaxLength == nil || *code.MaxLength != 43 {
			t.Errorf("exchangeCode 길이가 43으로 고정되어 있지 않음")
		}
		if code.Pattern != "^[A-Za-z0-9_-]{43}$" {
			t.Errorf("exchangeCode pattern = %q, want ^[A-Za-z0-9_-]{43}$", code.Pattern)
		}
		if op.Responses.Value("401") == nil {
			t.Error("401 응답이 없음")
		}
	})
	if !found {
		t.Fatal("completeAppleWebLogin operation이 없음")
	}
}

func TestContract_AppleLoginRequestHasNoClientType(t *testing.T) {
	doc := loadDoc(t)
	schema := doc.Components.Schemas["AppleLoginRequest"]
	if schema == nil {
		t.Fatal("AppleLoginRequest 스키마가 없음")
	}
	if schema.Value.Properties["clientType"] != nil {
		t.Error("AppleLoginRequest에 clientType이 남아 있음")
	}
	if slices.Contains(schema.Value.Required, "clientType") {
		t.Error("required에 clientType이 남아 있음")
	}
}

func TestContract_AppleCallbackLocationDescribesExchange(t *testing.T) {
	doc := loadDoc(t)

	found := false
	forEachOperation(doc, func(operationID string, op *openapi3.Operation) {
		if operationID != "appleCallback" {
			return
		}
		found = true
		desc := *op.Responses.Value("303").Value.Description
		for _, want := range []string{"exchange", "server_error"} {
			if !strings.Contains(desc, want) {
				t.Errorf("303 설명에 %q가 없음", want)
			}
		}
		if strings.Contains(desc, "id_token") {
			t.Error("303 설명에 id_token이 있음(Location으로 넘기지 않습니다)")
		}
	})
	if !found {
		t.Fatal("appleCallback operation이 없음")
	}
}

// TestContract_Draft4Fields는 draft.4에서 더한 필드를 고정합니다. 근거 문장(#167)과 출생 도시 경도(#199)입니다.
func TestContract_Draft4Fields(t *testing.T) {
	doc := loadDoc(t)
	tests := []struct {
		schema, field, ref string
		required           bool
	}{
		{"SlotText", "todayReason", "#/components/schemas/RenderedText", false},
		{"Evidence", "basis", "#/components/schemas/RenderedText", false},
		{"Evidence", "source", "#/components/schemas/RenderedText", false},
		{"Glossary", "hanja", "", true},
		{"City", "longitude", "", true},
		{"Profile", "birthCity", "#/components/schemas/City", false},
	}
	for _, tt := range tests {
		t.Run(tt.schema+"."+tt.field, func(t *testing.T) {
			ref := doc.Components.Schemas[tt.schema]
			if ref == nil || ref.Value == nil {
				t.Fatalf("%s 스키마가 없음", tt.schema)
			}
			prop := ref.Value.Properties[tt.field]
			if prop == nil {
				t.Fatalf("%s.properties에 %s가 없음", tt.schema, tt.field)
			}
			if tt.ref != "" && prop.Ref != tt.ref {
				t.Errorf("%s.%s $ref = %q, want %q", tt.schema, tt.field, prop.Ref, tt.ref)
			}
			if got := slices.Contains(ref.Value.Required, tt.field); got != tt.required {
				t.Errorf("%s.%s required = %v, want %v", tt.schema, tt.field, got, tt.required)
			}
		})
	}

	longitude := doc.Components.Schemas["City"].Value.Properties["longitude"].Value
	if longitude.Min == nil || *longitude.Min != -180 || longitude.Max == nil || *longitude.Max != 180 {
		t.Errorf("City.longitude 범위 = [%v, %v], want [-180, 180]", longitude.Min, longitude.Max)
	}
}

// problemCodeStatus는 Problem.code의 x-problem-codes에서 code의 status를 읽습니다. 없으면 0입니다.
func problemCodeStatus(t *testing.T, doc *openapi3.T, code string) int {
	t.Helper()
	raw, ok := doc.Components.Schemas["Problem"].Value.Properties["code"].Value.Extensions["x-problem-codes"].(map[string]any)
	if !ok {
		t.Fatal("x-problem-codes를 읽지 못함")
	}
	entry, ok := raw[code].(map[string]any)
	if !ok {
		return 0
	}
	status, _ := entry["status"].(float64)
	return int(status)
}

// TestContract_Draft5Additions는 draft.5에서 더한 problem code와 설명을 고정합니다. (P4, #219)
func TestContract_Draft5Additions(t *testing.T) {
	doc := loadDoc(t)

	codes := []struct {
		code      string
		status    int
		operation []string // 설명에 이 code가 있어야 하는 operation
	}{
		{"reaction.not_found", 404, []string{"putReaction", "deleteReaction"}},
		{"schedule.not_found", 404, []string{"updateSchedule", "deleteSchedule"}},
		{"range.too_long", 422, []string{"listSchedules"}},
	}
	for _, tt := range codes {
		t.Run(tt.code, func(t *testing.T) {
			if got := problemCodeStatus(t, doc, tt.code); got != tt.status {
				t.Errorf("x-problem-codes[%s].status = %d, want %d", tt.code, got, tt.status)
			}
			for _, id := range tt.operation {
				op := operationByID(t, doc, id)
				if !strings.Contains(op.Description, tt.code) {
					t.Errorf("%s 설명에 %s가 없음", id, tt.code)
				}
				if op.Responses.Value(strconv.Itoa(tt.status)) == nil {
					t.Errorf("%s에 %d 응답이 없음", id, tt.status)
				}
			}
		})
	}

	descriptions := []struct {
		name, text string
		got        func() string
	}{
		{"SlotText 빈 문장 규칙", "빈 `segments`", func() string { return doc.Components.Schemas["SlotText"].Value.Description }},
		{"SlotText reactable", "daily.fortune.head", func() string { return doc.Components.Schemas["SlotText"].Value.Description }},
		{"SlotText 선택 문장 생략", "선택 문장 필드(`todayReason`·`Evidence.basis`·`Evidence.source`)는 생략합니다", func() string { return doc.Components.Schemas["SlotText"].Value.Description }},
		{"SlotText variant 유형", "`advice`·`state`·`care`", func() string { return doc.Components.Schemas["SlotText"].Value.Description }},
		{"SlotText variant 가이드", "`1`·`2`", func() string { return doc.Components.Schemas["SlotText"].Value.Description }},
		{"SlotText variant single", "`single`", func() string { return doc.Components.Schemas["SlotText"].Value.Description }},
		{"Notice 빈 segments", "빈 `segments`", func() string { return doc.Components.Schemas["Notice"].Value.Description }},
		{"Schedule.time 시간대", "currentTimezone", func() string { return doc.Components.Schemas["Schedule"].Value.Properties["time"].Value.Description }},
		{"Schedule.time 끝 시각 없음", "끝 시각(길이) 필드는 없습니다", func() string { return doc.Components.Schemas["Schedule"].Value.Properties["time"].Value.Description }},
		{"getCalendar 캐시", "rulesetVersion", func() string { return operationByID(t, doc, "getCalendar").Description }},
		{"getCalendar ETag 없음", "`ETag`는 없습니다", func() string { return operationByID(t, doc, "getCalendar").Description }},
	}
	for _, tt := range descriptions {
		t.Run(tt.name, func(t *testing.T) {
			if !strings.Contains(tt.got(), tt.text) {
				t.Errorf("설명에 %q가 없음: %q", tt.text, tt.got())
			}
		})
	}
}

// TestContract_Draft6Additions는 draft.6에서 더한 409 응답과 설명을 고정합니다. (#248, P4 남은 일)
func TestContract_Draft6Additions(t *testing.T) {
	doc := loadDoc(t)

	for _, id := range []string{"getGlossary", "putReaction", "deleteReaction"} {
		t.Run(id, func(t *testing.T) {
			op := operationByID(t, doc, id)
			if !strings.Contains(op.Description, "409 `profile.required`") {
				t.Errorf("%s 설명에 409 profile.required가 없음", id)
			}
			if op.Responses.Value("409") == nil {
				t.Errorf("%s에 409 응답이 없음", id)
			}
		})
	}

	t.Run("Profile.birthCity 생략 조건", func(t *testing.T) {
		description := doc.Components.Schemas["Profile"].Value.Description
		for _, text := range []string{"계산에 쓴 저장된 경도", "찾지 못하면 `city`여도 `birthCity`를 뺍니다"} {
			if !strings.Contains(description, text) {
				t.Errorf("Profile 설명에 %q가 없음", text)
			}
		}
	})

	t.Run("getCalendar 첫 달", func(t *testing.T) {
		description := operationByID(t, doc, "getCalendar").Description
		for _, text := range []string{"첫 달은 1900-02", "마지막 달은 2099-12"} {
			if !strings.Contains(description, text) {
				t.Errorf("getCalendar 설명에 %q가 없음", text)
			}
		}
	})
}

// TestContract_Draft7Additions는 draft.7에서 더한 일기·일정 동작 설명을 고정합니다. (P5, 응답 형태는 그대로)
func TestContract_Draft7Additions(t *testing.T) {
	doc := loadDoc(t)

	descriptions := map[string][]string{
		"restoreDiary":    {"이미 살아 있는 일기", "404 `diary.not_found`", "422 `diary.day_full`"},
		"listDiaries":     {"`from`이 `to`보다 늦으면 빈 목록"},
		"listSchedules":   {"`from`이 `to`보다 늦으면 400 `request.invalid`"},
		"restoreSchedule": {"이미 살아 있는 일정이면 그대로"},
	}
	for id, texts := range descriptions {
		t.Run(id, func(t *testing.T) {
			description := operationByID(t, doc, id).Description
			for _, text := range texts {
				if !strings.Contains(description, text) {
					t.Errorf("%s 설명에 %q가 없음", id, text)
				}
			}
		})
	}

	for _, id := range []string{"updateSchedule", "deleteSchedule", "restoreSchedule"} {
		t.Run(id+" 404", func(t *testing.T) {
			op := operationByID(t, doc, id)
			if !strings.Contains(op.Description, "404 `schedule.not_found`") {
				t.Errorf("%s 설명에 404 schedule.not_found가 없음", id)
			}
			if op.Responses.Value("404") == nil {
				t.Errorf("%s에 404 응답이 없음", id)
			}
		})
	}
}

// TestContract_Draft9Additions는 draft.9에서 더한 결제 webhook·복원 동작 설명을 고정합니다. (P7, 응답 형태는 그대로)
func TestContract_Draft9Additions(t *testing.T) {
	doc := loadDoc(t)

	descriptions := map[string][]string{
		"admobRewardCallback": {"`user_id`가 없거나 없는 계정이면 기록만 하고 200", "현재와 1시간 넘게 어긋난(오래됐거나 미래) `timestamp`"},
		"revenuecatWebhook":   {"모르는 계정이면 기록만 하고 200", "`type`이 `TEST`인 이벤트도 기록만 하고 200", "같은 `event.id`는 한 번만 처리"},
		"restorePurchases":    {"환불된 구매", "`Purchases.logIn`에 `Me.accountId` 문자열(소문자 표준 UUID 표기)을 그대로 넘깁니다"},
	}
	for id, texts := range descriptions {
		t.Run(id, func(t *testing.T) {
			description := operationByID(t, doc, id).Description
			for _, text := range texts {
				if !strings.Contains(description, text) {
					t.Errorf("%s 설명에 %q가 없음", id, text)
				}
			}
		})
	}
}

// TestContract_Draft9Removals는 draft.9에서 뺀, app이 쓰지 않는 필드 다섯 개가 없음을 고정합니다. (S77, app 확인 #309)
func TestContract_Draft9Removals(t *testing.T) {
	doc := loadDoc(t)

	removed := map[string][]string{
		"FocusSlot":   {"score", "pillar"},
		"CalendarDay": {"scoreItems", "featuredTag"},
		"Calendar":    {"notices"},
	}
	for name, properties := range removed {
		schema := doc.Components.Schemas[name].Value
		for _, property := range properties {
			t.Run(name+"."+property, func(t *testing.T) {
				if _, ok := schema.Properties[property]; ok {
					t.Errorf("%s.%s가 properties에 남아 있음", name, property)
				}
				if slices.Contains(schema.Required, property) {
					t.Errorf("%s.%s가 required에 남아 있음", name, property)
				}
			})
		}
	}

	// 다른 스키마의 notices·featuredTags와 CalendarDay.score·pillar는 그대로입니다.
	kept := map[string][]string{
		"Daily":       {"notices"},
		"Chart":       {"notices"},
		"CalendarDay": {"score", "pillar"},
	}
	for name, properties := range kept {
		for _, property := range properties {
			if _, ok := doc.Components.Schemas[name].Value.Properties[property]; !ok {
				t.Errorf("%s.%s가 없음", name, property)
			}
		}
	}

	if _, ok := doc.Components.Schemas["ScoreItem"]; ok {
		t.Error("참조되지 않는 ScoreItem 스키마가 남아 있음")
	}
}

// TestContract_Draft8Additions는 draft.8에서 더한 비로그인·참조 동작 설명을 고정합니다. (P6, 응답 형태는 그대로)
func TestContract_Draft8Additions(t *testing.T) {
	doc := loadDoc(t)

	if !strings.Contains(doc.Components.SecuritySchemes["appCheck"].Value.Description, "convertLunarDate") {
		t.Error("appCheck 설명에 convertLunarDate가 없음")
	}
	for _, text := range []string{"지원 언어는 `ko`·`en`·`ja`", "q값 순서", "기본 언어는 `en`"} {
		if !strings.Contains(doc.Info.Description, text) {
			t.Errorf("info.description에 %q가 없음", text)
		}
	}

	descriptions := map[string][]string{
		"getBirthHour":     {"`Asia/Seoul`", "시간대별 대표 경도(한국 127.5°, D29)", "IP별 요청 한도(분당 30회)"},
		"convertLunarDate": {"IP별 요청 한도(분당 30회)"},
		"listCities":       {"앞부분", "`If-None-Match`가 현재 `ETag`와 같으면 304"},
		"createPreview":    {"`advice`", "IP별 요청 한도(분당 30회)"},
	}
	for id, texts := range descriptions {
		t.Run(id, func(t *testing.T) {
			description := operationByID(t, doc, id).Description
			for _, text := range texts {
				if !strings.Contains(description, text) {
					t.Errorf("%s 설명에 %q가 없음", id, text)
				}
			}
		})
	}

	for _, text := range []string{"엔진 RPC가 생기기 전까지는 501", "기기·IP별"} {
		for _, id := range []string{"getBirthHour", "convertLunarDate"} {
			if strings.Contains(operationByID(t, doc, id).Description, text) {
				t.Errorf("%s 설명에 %q가 남아 있음", id, text)
			}
		}
	}

	for _, id := range []string{"createPreview", "getBirthHour", "convertLunarDate"} {
		if operationByID(t, doc, id).Responses.Value("429") == nil {
			t.Errorf("%s에 429 응답이 없음", id)
		}
	}
	for _, id := range []string{"getBirthHour", "convertLunarDate"} {
		if operationByID(t, doc, id).Responses.Value("501") != nil {
			t.Errorf("%s에 501 응답이 남아 있음", id)
		}
	}
	if _, ok := doc.Components.Responses["NotImplemented"]; ok {
		t.Error("쓰지 않는 NotImplemented 응답 component가 남아 있음")
	}

	testDraft8PersonalReadings(t, doc)
}

// testDraft8PersonalReadings는 원국 개인 해석 필드와 Notice.text 설명을 고정합니다. (P6-13·P6-14)
func testDraft8PersonalReadings(t *testing.T, doc *openapi3.T) {
	t.Helper()

	chart := doc.Components.Schemas["Chart"].Value
	readings := chart.Properties["personalReadings"]
	if readings == nil {
		t.Fatal("Chart.personalReadings가 없음")
	}
	if slices.Contains(chart.Required, "personalReadings") {
		t.Error("Chart.personalReadings가 required에 있음(선택 필드여야 함)")
	}
	if readings.Value.Items == nil || readings.Value.Items.Ref != "#/components/schemas/PersonalReading" {
		t.Error("Chart.personalReadings 항목이 PersonalReading이 아님")
	}
	if !strings.Contains(readings.Value.Description, "근거 열람 권한") {
		t.Error("Chart.personalReadings 설명에 근거 열람 권한 잠금(D60)이 없음")
	}

	reading := doc.Components.Schemas["PersonalReading"].Value
	if !slices.Equal(reading.Required, []string{"kind", "text"}) {
		t.Errorf("PersonalReading.required = %v, want [kind text]", reading.Required)
	}
	wantKinds := []any{
		"day_master", "ten_god", "hidden_ten_god", "twelve_stage", "shinsal",
		"daeun_stem_ten_god", "daeun_branch_ten_god", "daeun_twelve_stage", "seun_ten_god",
	}
	if got := reading.Properties["kind"].Value.Enum; !slices.Equal(got, wantKinds) {
		t.Errorf("PersonalReading.kind enum = %v, want %v", got, wantKinds)
	}
	if names, _ := reading.Properties["kind"].Value.Extensions["x-enum-varnames"].([]any); len(names) != len(wantKinds) {
		t.Errorf("PersonalReading.kind x-enum-varnames 길이 = %d, want %d", len(names), len(wantKinds))
	}
	for field, ref := range map[string]string{
		"position": "#/components/schemas/Position",
		"shinsal":  "#/components/schemas/ShinsalKind",
		"text":     "#/components/schemas/RenderedText",
	} {
		if got := reading.Properties[field].Ref; got != ref {
			t.Errorf("PersonalReading.%s = %q, want %q", field, got, ref)
		}
	}
	index := reading.Properties["index"].Value
	if !index.Type.Is("integer") || index.Min == nil || *index.Min != 0 {
		t.Error("PersonalReading.index가 0 이상 integer가 아님")
	}

	notice := doc.Components.Schemas["Notice"].Value.Description
	if !strings.Contains(notice, "배너를 그리지 않습니다") || strings.Contains(notice, "자기 문구를 씁니다") {
		t.Errorf("Notice 설명이 P6-14와 다름: %q", notice)
	}
	if strings.Contains(doc.Info.Description, "원국 개인 해석은 writing 슬롯이 아직 없어") {
		t.Error("info.description에 원국 개인 해석 설계 메모가 남아 있음")
	}
}

// TestContract_Draft13DiaryEntries는 draft.13의 일기 하루 여러 편 계약을 고정합니다. (D83, #407)
func TestContract_Draft13DiaryEntries(t *testing.T) {
	doc := loadDoc(t)

	paths := map[string][]string{
		"/v1/diaries":              {"GET listDiaries", "POST createDiary"},
		"/v1/diaries/{id}":         {"GET getDiary", "PUT updateDiary", "DELETE deleteDiary"},
		"/v1/diaries/{id}/restore": {"POST restoreDiary"},
	}
	for path, methods := range paths {
		item := doc.Paths.Find(path)
		if item == nil {
			t.Errorf("%s 경로가 없음", path)
			continue
		}
		for _, entry := range methods {
			method, operationID, _ := strings.Cut(entry, " ")
			op := item.GetOperation(method)
			if op == nil || op.OperationID != operationID {
				t.Errorf("%s %s의 operationId가 %s가 아님", method, path, operationID)
			}
		}
	}
	for _, removed := range []string{"/v1/diaries/{date}", "/v1/diaries/{date}/restore"} {
		if doc.Paths.Value(removed) != nil {
			t.Errorf("옛 경로 %s가 남아 있음", removed)
		}
	}

	t.Run("id 경로 매개변수", func(t *testing.T) {
		for _, path := range []string{"/v1/diaries/{id}", "/v1/diaries/{id}/restore"} {
			item := doc.Paths.Find(path)
			if item == nil {
				continue
			}
			var found bool
			for _, param := range item.Parameters {
				if param.Value == nil || param.Value.Name != "id" || param.Value.In != openapi3.ParameterInPath {
					continue
				}
				found = true
				schema := param.Value.Schema.Value
				if !schema.Type.Is("string") || schema.Format != "uuid" {
					t.Errorf("%s의 id schema가 string/uuid가 아님", path)
				}
			}
			if !found {
				t.Errorf("%s에 id 경로 매개변수가 없음", path)
			}
		}
	})

	requiredOf := func(name string) []string {
		ref := doc.Components.Schemas[name]
		if ref == nil || ref.Value == nil {
			t.Fatalf("%s 스키마가 없음", name)
		}
		return ref.Value.Required
	}
	t.Run("스키마 required", func(t *testing.T) {
		for _, want := range []string{"id", "date", "body", "tags", "rulesetVersion", "createdAt", "updatedAt"} {
			if !slices.Contains(requiredOf("Diary"), want) {
				t.Errorf("Diary.required에 %s가 없음", want)
			}
		}
		if id := doc.Components.Schemas["Diary"].Value.Properties["id"]; id == nil || id.Value.Format != "uuid" {
			t.Error("Diary.id가 format uuid가 아님")
		}
		sameSet := func(name string, want []string) {
			got := slices.Clone(requiredOf(name))
			slices.Sort(got)
			slices.Sort(want)
			if !slices.Equal(got, want) {
				t.Errorf("%s.required = %v, want %v", name, got, want)
			}
		}
		sameSet("DiarySummary", []string{"id", "date", "createdAt", "excerpt", "featuredTags"})
		sameSet("DiaryInput", []string{"date", "body"})
		sameSet("DiaryBodyInput", []string{"body"})
	})
	t.Run("본문 길이", func(t *testing.T) {
		for _, name := range []string{"DiaryInput", "DiaryBodyInput"} {
			body := doc.Components.Schemas[name].Value.Properties["body"].Value
			if body.MinLength != 1 || body.MaxLength == nil || *body.MaxLength != 10000 {
				t.Errorf("%s.body 길이가 1~10000이 아님", name)
			}
		}
	})

	t.Run("createDiary 응답", func(t *testing.T) {
		op := operationByID(t, doc, "createDiary")
		created := op.Responses.Value("201")
		if created == nil || created.Value.Headers["Location"] == nil {
			t.Error("createDiary 201에 Location 헤더가 없음")
		}
		for _, status := range []string{"409", "422"} {
			if op.Responses.Value(status) == nil {
				t.Errorf("createDiary에 %s 응답이 없음", status)
			}
		}
		if op.Responses.Value("200") != nil {
			t.Error("createDiary에 200 응답이 있음")
		}
	})
	t.Run("updateDiary는 엔진을 부르지 않음", func(t *testing.T) {
		op := operationByID(t, doc, "updateDiary")
		for _, status := range []string{"502", "504"} {
			if op.Responses.Value(status) != nil {
				t.Errorf("updateDiary에 %s 응답이 있음", status)
			}
		}
	})
	t.Run("listDiaries 설명", func(t *testing.T) {
		description := operationByID(t, doc, "listDiaries").Description
		for _, text := range []string{"같은 날짜 안에서는 작성 순", "한 날짜의 일기가 두 쪽에 나뉠 수"} {
			if !strings.Contains(description, text) {
				t.Errorf("listDiaries 설명에 %q가 없음", text)
			}
		}
	})
}

// TestContract_Draft13ProblemCodes는 draft.13에서 더하고 뺀 problem code를 고정합니다. (D83, #407)
func TestContract_Draft13ProblemCodes(t *testing.T) {
	codes := loadProblemCodes(t)
	if entry, ok := codes["diary.day_full"]; !ok || entry.Status != 422 {
		t.Errorf("diary.day_full = %+v (있음 %v), want status 422", entry, ok)
	}
	if _, ok := codes["diary.date_taken"]; ok {
		t.Error("diary.date_taken이 남아 있음")
	}
}

// enumStrings는 문자열 enum 스키마의 값을 []string으로 바꿉니다.
func enumStrings(schema *openapi3.Schema) []string {
	values := make([]string, 0, len(schema.Enum))
	for _, value := range schema.Enum {
		values = append(values, value.(string))
	}
	return values
}

// sameElements는 got과 want가 순서와 상관없이 같은 원소 집합인지 확인합니다.
func sameElements(t *testing.T, label string, got, want []string) {
	t.Helper()
	got, want = slices.Clone(got), slices.Clone(want)
	slices.Sort(got)
	slices.Sort(want)
	if !slices.Equal(got, want) {
		t.Errorf("%s = %v, want %v", label, got, want)
	}
}

// schemaOf는 components/schemas의 스키마를 돌려줍니다. 없으면 테스트를 멈춥니다.
func schemaOf(t *testing.T, doc *openapi3.T, name string) *openapi3.Schema {
	t.Helper()
	ref := doc.Components.Schemas[name]
	if ref == nil || ref.Value == nil {
		t.Fatalf("%s 스키마가 없음", name)
	}
	return ref.Value
}

// requireResponses는 operation에 status 응답이 모두 있는지 확인합니다.
func requireResponses(t *testing.T, operationID string, op *openapi3.Operation, statuses ...string) {
	t.Helper()
	for _, status := range statuses {
		if op.Responses.Value(status) == nil {
			t.Errorf("%s에 %s 응답이 없음", operationID, status)
		}
	}
}

// jsonBodyRef는 operation의 JSON 요청 본문 스키마 $ref입니다.
func jsonBodyRef(t *testing.T, op *openapi3.Operation) string {
	t.Helper()
	if op.RequestBody == nil || op.RequestBody.Value == nil || op.RequestBody.Value.Content["application/json"] == nil {
		t.Fatal("JSON 요청 본문이 없음")
	}
	return op.RequestBody.Value.Content["application/json"].Schema.Ref
}

// TestContract_Draft14Identities는 draft.14에서 더한 로그인 제공자·연결 관리·합치기 계약을 고정합니다. (D82, #386)
func TestContract_Draft14Identities(t *testing.T) {
	doc := loadDoc(t)

	t.Run("LINE·Google 로그인", func(t *testing.T) {
		for id, schema := range map[string]string{"loginLine": "LineLoginRequest", "loginGoogle": "GoogleLoginRequest"} {
			op := operationByID(t, doc, id)
			if op.Security == nil || len(*op.Security) != 0 {
				t.Errorf("%s: security가 빈 배열이 아님", id)
			}
			if got := jsonBodyRef(t, op); got != "#/components/schemas/"+schema {
				t.Errorf("%s 본문 = %s, want %s", id, got, schema)
			}
			sameElements(t, schema+".required", schemaOf(t, doc, schema).Required, []string{"idToken", "nonce"})
			if got := okSchemaRef(t, op); got != "#/components/schemas/LoginResponse" {
				t.Errorf("%s 200 = %s, want LoginResponse", id, got)
			}
			requireResponses(t, id, op, "401", "503")
		}
	})

	t.Run("LoginProvider", func(t *testing.T) {
		sameElements(t, "LoginProvider.enum", enumStrings(schemaOf(t, doc, "LoginProvider")), []string{"kakao", "apple", "line", "google"})
	})

	t.Run("열린 enum", func(t *testing.T) {
		for _, text := range []string{"`LoginProvider`"} {
			if !strings.Contains(doc.Info.Description, text) {
				t.Errorf("info.description의 열린 enum 목록에 %s가 없음", text)
			}
		}
	})

	t.Run("새 bearer operation의 공통 응답", func(t *testing.T) {
		for _, id := range []string{"listIdentities", "linkIdentity", "unlinkIdentity", "previewMerge", "mergeAccounts"} {
			op := operationByID(t, doc, id)
			requireResponses(t, id, op, "401", "403")
			if id == "linkIdentity" || id == "previewMerge" || id == "mergeAccounts" {
				requireResponses(t, id, op, "400", "413", "415")
			}
		}
	})

	t.Run("listIdentities", func(t *testing.T) {
		op := operationByID(t, doc, "listIdentities")
		if got := okSchemaRef(t, op); got != "#/components/schemas/IdentityList" {
			t.Errorf("listIdentities 200 = %s, want IdentityList", got)
		}
		list := schemaOf(t, doc, "IdentityList")
		items := list.Properties["items"]
		if items == nil || !items.Value.Type.Is("array") || items.Value.Items.Ref != "#/components/schemas/Identity" {
			t.Error("IdentityList.items가 Identity 배열이 아님")
		}
		sameElements(t, "IdentityList.required", list.Required, []string{"items"})
		identity := schemaOf(t, doc, "Identity")
		sameElements(t, "Identity.required", identity.Required, []string{"provider", "linkedAt"})
		if identity.Properties["subject"] != nil {
			t.Error("Identity에 subject가 있음")
		}
		if identity.Properties["provider"].Ref != "#/components/schemas/LoginProvider" {
			t.Error("Identity.provider가 LoginProvider 참조가 아님")
		}
		if linkedAt := identity.Properties["linkedAt"].Value; linkedAt.Format != "date-time" {
			t.Errorf("Identity.linkedAt format = %q, want date-time", linkedAt.Format)
		}
		requireResponses(t, "listIdentities", op, "401", "403")
	})

	providerParam := func(t *testing.T, operationID string) {
		t.Helper()
		item := doc.Paths.Find("/v1/me/identities/{provider}")
		if item == nil {
			t.Fatal("/v1/me/identities/{provider} 경로가 없음")
		}
		for _, param := range item.Parameters {
			if param.Value != nil && param.Value.Name == "provider" && param.Value.In == openapi3.ParameterInPath {
				if !param.Value.Required || param.Value.Schema.Ref != "#/components/schemas/LoginProvider" {
					t.Errorf("%s: provider parameter가 필수 LoginProvider 참조가 아님", operationID)
				}
				return
			}
		}
		t.Errorf("%s: provider 경로 매개변수가 없음", operationID)
	}

	t.Run("linkIdentity", func(t *testing.T) {
		op := operationByID(t, doc, "linkIdentity")
		providerParam(t, "linkIdentity")
		requireResponses(t, "linkIdentity", op, "200", "201", "400", "401", "409", "503")
		for _, status := range []string{"200", "201"} {
			media := op.Responses.Value(status).Value.Content["application/json"]
			if media == nil || media.Schema.Ref != "#/components/schemas/IdentityList" {
				t.Errorf("linkIdentity %s JSON 스키마가 IdentityList가 아님", status)
			}
		}
		if got := jsonBodyRef(t, op); got != "#/components/schemas/LinkIdentityRequest" {
			t.Errorf("linkIdentity 본문 = %s, want LinkIdentityRequest", got)
		}
		conflict := op.Responses.Value("409").Value.Content["application/problem+json"]
		if conflict == nil || conflict.Schema.Ref != identityInUseProblemRef {
			t.Error("linkIdentity 409 content가 IdentityInUseProblem 참조가 아님")
		}
		for _, text := range []string{"auth.provider_taken", "auth.identity_in_use", "auth.identity_pending_deletion", "auth.provider_token_invalid", "auth.exchange_invalid", "exchangeCode", "저장하지 않"} {
			if !strings.Contains(op.Description, text) {
				t.Errorf("linkIdentity 설명에 %q가 없음", text)
			}
		}

		problem := schemaOf(t, doc, "IdentityInUseProblem")
		if len(problem.AllOf) == 0 || problem.AllOf[0].Ref != problemRef {
			t.Error("IdentityInUseProblem.allOf에 Problem이 없음")
		}
		var properties openapi3.Schemas
		for _, part := range problem.AllOf {
			if part.Ref == "" && part.Value != nil && part.Value.Properties != nil {
				properties = part.Value.Properties
			}
			if part.Ref == "" && part.Value != nil && len(part.Value.Required) > 0 {
				t.Errorf("IdentityInUseProblem에 required %v가 있음(auth.identity_in_use일 때만 있는 필드)", part.Value.Required)
			}
		}
		if len(problem.Properties) > 0 {
			properties = problem.Properties
		}
		if properties["mergeToken"] == nil || !properties["mergeToken"].Value.Type.Is("string") {
			t.Error("IdentityInUseProblem.mergeToken이 string이 아님")
		}
		if properties["expiresAt"] == nil || properties["expiresAt"].Value.Format != "date-time" {
			t.Error("IdentityInUseProblem.expiresAt이 date-time이 아님")
		}

		request := schemaOf(t, doc, "LinkIdentityRequest")
		sameElements(t, "LinkIdentityRequest.required", request.Required, []string{"nonce"})
		var names []string
		for name := range request.Properties {
			names = append(names, name)
		}
		sameElements(t, "LinkIdentityRequest.properties", names, []string{"idToken", "authorizationCode", "exchangeCode", "nonce"})
		if len(request.OneOf) > 0 || len(request.AnyOf) > 0 {
			t.Error("LinkIdentityRequest가 oneOf/anyOf를 씀(additionalProperties가 없어 Apple iOS 증명이 두 갈래에 다 맞음)")
		}
		for _, text := range []string{"kakao", "idToken", "authorizationCode", "exchangeCode", "request.invalid"} {
			if !strings.Contains(request.Description, text) {
				t.Errorf("LinkIdentityRequest 설명에 %q가 없음", text)
			}
		}
	})

	t.Run("unlinkIdentity", func(t *testing.T) {
		op := operationByID(t, doc, "unlinkIdentity")
		providerParam(t, "unlinkIdentity")
		requireResponses(t, "unlinkIdentity", op, "204", "400", "404", "409")
		if op.RequestBody != nil {
			t.Error("unlinkIdentity에 요청 본문이 있음")
		}
		if !strings.Contains(op.Description, "LINE·Google의 제공자 허가는 server가 취소하지 않습니다") {
			t.Error("unlinkIdentity 설명에 LINE·Google 허가 취소 규칙이 없음")
		}
	})

	t.Run("previewMerge", func(t *testing.T) {
		op := operationByID(t, doc, "previewMerge")
		if got := jsonBodyRef(t, op); got != "#/components/schemas/MergePreviewRequest" {
			t.Errorf("previewMerge 본문 = %s, want MergePreviewRequest", got)
		}
		sameElements(t, "MergePreviewRequest.required", schemaOf(t, doc, "MergePreviewRequest").Required, []string{"mergeToken"})
		if got := okSchemaRef(t, op); got != "#/components/schemas/MergePreview" {
			t.Errorf("previewMerge 200 = %s, want MergePreview", got)
		}
		requireResponses(t, "previewMerge", op, "422")
		sameElements(t, "MergePreview.required", schemaOf(t, doc, "MergePreview").Required, []string{"current", "other", "overlapDayCount"})
		summary := schemaOf(t, doc, "MergeAccountSummary")
		sameElements(t, "MergeAccountSummary.required", summary.Required, []string{"saju", "diaryCount", "providers"})
		if summary.Properties["honorific"] == nil {
			t.Error("MergeAccountSummary.honorific이 없음")
		}
		if providers := summary.Properties["providers"]; providers == nil || providers.Value.Items.Ref != "#/components/schemas/LoginProvider" {
			t.Error("MergeAccountSummary.providers.items가 LoginProvider 참조가 아님")
		}
		for name, count := range map[string]*openapi3.SchemaRef{
			"MergeAccountSummary.diaryCount": summary.Properties["diaryCount"],
			"MergePreview.overlapDayCount":   schemaOf(t, doc, "MergePreview").Properties["overlapDayCount"],
		} {
			if count == nil || !count.Value.Type.Is("integer") || count.Value.Min == nil || *count.Value.Min != 0 {
				t.Errorf("%s가 minimum 0인 integer가 아님", name)
			}
		}
		saju := schemaOf(t, doc, "MergeSaju")
		if saju.Properties["calendar"].Ref != "#/components/schemas/CalendarType" {
			t.Error("MergeSaju.calendar가 CalendarType 참조가 아님")
		}
		if saju.Properties["date"].Ref != "#/components/schemas/LunarOrSolarDate" {
			t.Error("MergeSaju.date가 LunarOrSolarDate 참조가 아님")
		}
		if isLeap := saju.Properties["isLeapMonth"]; isLeap == nil || !isLeap.Value.Type.Is("boolean") {
			t.Error("MergeSaju.isLeapMonth가 boolean이 아님")
		}
		sameElements(t, "MergeSaju.status", enumStrings(schemaOf(t, doc, "MergeSaju").Properties["status"].Value), []string{"saved", "none"})
		if birthTime := schemaOf(t, doc, "MergeSaju").Properties["birthTime"]; birthTime == nil || birthTime.Ref != "#/components/schemas/BirthTime" {
			t.Error("MergeSaju.birthTime이 BirthTime 참조가 아님")
		}
	})

	t.Run("mergeAccounts", func(t *testing.T) {
		op := operationByID(t, doc, "mergeAccounts")
		if got := jsonBodyRef(t, op); got != "#/components/schemas/MergeRequest" {
			t.Errorf("mergeAccounts 본문 = %s, want MergeRequest", got)
		}
		request := schemaOf(t, doc, "MergeRequest")
		sameElements(t, "MergeRequest.required", request.Required, []string{"mergeToken", "keep"})
		sameElements(t, "MergeRequest.keep", enumStrings(request.Properties["keep"].Value), []string{"current", "other"})
		if got := okSchemaRef(t, op); got != "#/components/schemas/MergeResult" {
			t.Errorf("mergeAccounts 200 = %s, want MergeResult", got)
		}
		result := schemaOf(t, doc, "MergeResult")
		sameElements(t, "MergeResult.required", result.Required, []string{"accountId", "tokens"})
		if result.Properties["tokens"].Ref != "#/components/schemas/TokenPair" {
			t.Error("MergeResult.tokens가 TokenPair 참조가 아님")
		}
		if result.Properties["accountId"].Value.Format != "uuid" {
			t.Error("MergeResult.accountId가 format uuid가 아님")
		}
		requireResponses(t, "mergeAccounts", op, "422", "503")
		if op.Parameters.GetByInAndName(openapi3.ParameterInHeader, "Idempotency-Key") != nil {
			t.Error("mergeAccounts가 Idempotency-Key를 받음")
		}
		for _, text := range []string{"Idempotency-Key", "merge.token_invalid", "billing.provider_unavailable"} {
			if !strings.Contains(op.Description, text) {
				t.Errorf("mergeAccounts 설명에 %q가 없음", text)
			}
		}
	})
}

// TestContract_Draft14ProblemCodes는 draft.14에서 더한 problem code를 고정합니다. (D82, S104)
func TestContract_Draft14ProblemCodes(t *testing.T) {
	codes := loadProblemCodes(t)
	for code, status := range map[string]int{
		"auth.provider_taken":            409,
		"auth.identity_in_use":           409,
		"auth.identity_pending_deletion": 409,
		"auth.last_identity":             409,
		"auth.identity_not_found":        404,
		"merge.token_invalid":            422,
	} {
		if entry, ok := codes[code]; !ok || entry.Status != status {
			t.Errorf("%s = %+v (있음 %v), want status %d", code, entry, ok, status)
		}
	}
}
