package api_test

import (
	"context"
	"fmt"
	"iter"
	"os"
	"slices"
	"strings"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"gopkg.in/yaml.v3"
)

const specPath = "openapi.yaml"

const problemRef = "#/components/schemas/Problem"

// expectedOperationIDs는 계약의 operation 표 전체입니다.
var expectedOperationIDs = []string{
	"loginKakao", "loginApple", "appleCallback", "refreshToken", "logout",
	"getMe", "deleteMe", "agreeConsents", "createProfile", "updateProfile",
	"getDaily", "getChart", "getCalendar", "putReaction", "deleteReaction",
	"getGlossary", "createPreview", "getBirthHour",
	"listDiaries", "getDiary", "putDiary", "deleteDiary", "restoreDiary",
	"listSchedules", "createSchedule", "updateSchedule", "deleteSchedule", "restoreSchedule",
	"registerDevice", "deleteDevice",
	"getEntitlements", "restorePurchases", "revenuecatWebhook", "admobRewardCallback",
	"listCities", "getAppConfig", "getHealth",
}

// securityOverrides는 최상위 bearerAuth를 덮어쓰는 operation과 그 security scheme 이름입니다.
// 빈 목록은 인증 없음(security: [])입니다.
var securityOverrides = map[string][]string{
	"loginKakao":          {},
	"loginApple":          {},
	"appleCallback":       {},
	"refreshToken":        {},
	"revenuecatWebhook":   {},
	"admobRewardCallback": {},
	"listCities":          {},
	"getAppConfig":        {},
	"getHealth":           {},
	"createPreview":       {"appCheck"},
	"getBirthHour":        {"appCheck"},
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
			if media.Schema == nil || media.Schema.Ref != problemRef {
				t.Errorf("%s %s: schema가 Problem 참조가 아님", operationID, status)
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

	for _, operationID := range []string{"createSchedule", "registerDevice"} {
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
