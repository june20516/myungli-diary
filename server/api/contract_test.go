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
	"getEntitlements", "restorePurchases", "revenuecatWebhook",
	"listCities", "getAppConfig", "getHealth",
}

// securityOverrides는 최상위 bearerAuth를 덮어쓰는 operation과 그 security scheme 이름입니다.
// 빈 목록은 인증 없음(security: [])입니다.
var securityOverrides = map[string][]string{
	"loginKakao":        {},
	"loginApple":        {},
	"appleCallback":     {},
	"refreshToken":      {},
	"revenuecatWebhook": {},
	"listCities":        {},
	"getAppConfig":      {},
	"getHealth":         {},
	"createPreview":     {"appCheck"},
	"getBirthHour":      {"appCheck"},
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
	raw, err := os.ReadFile(specPath)
	if err != nil {
		t.Fatalf("계약을 읽지 못함: %v", err)
	}
	var root yaml.Node
	if err := yaml.Unmarshal(raw, &root); err != nil {
		t.Fatalf("YAML 파싱 실패: %v", err)
	}
	walkNoNull(t, &root)
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
