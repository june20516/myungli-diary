package api_test

import (
	"context"
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

	for _, name := range []string{"Daily", "Chart", "Calendar"} {
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
	walkNoOpenAPI31OnlySyntax(t, loadYAML(t))
}

// walkNoOpenAPI31OnlySyntax는 3.1에서만 뜻이 있는 const·webhooks 키, 숫자형 exclusiveMinimum·exclusiveMaximum
// (3.0에서는 bool), $ref 형제 키를 찾아 실패로 기록합니다.
// server의 요청 검증은 계약 사본을 3.0.3으로 읽으므로(internal/httpapi/validate.go) 이 검사가 그 전제를 지킵니다.
func walkNoOpenAPI31OnlySyntax(t *testing.T, node *yaml.Node) {
	t.Helper()
	if node.Kind == yaml.MappingNode {
		hasRef := false
		for i := 0; i+1 < len(node.Content); i += 2 {
			key, value := node.Content[i], node.Content[i+1]
			switch key.Value {
			case "const", "webhooks":
				t.Errorf("line %d: 3.1 전용 키워드 %s", key.Line, key.Value)
			case "exclusiveMinimum", "exclusiveMaximum":
				if value.Tag != "!!bool" {
					t.Errorf("line %d: 3.1 전용 숫자형 %s", key.Line, key.Value)
				}
			case "$ref":
				hasRef = true
			}
		}
		if hasRef && len(node.Content) > 2 {
			t.Errorf("line %d: $ref에 형제 키가 있음", node.Line)
		}
	}
	for _, child := range node.Content {
		walkNoOpenAPI31OnlySyntax(t, child)
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
