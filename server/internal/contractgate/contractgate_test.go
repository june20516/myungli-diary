package contractgate_test

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"

	"github.com/june20516/myungli-diary/server/internal/contractgate"
)

// specWith는 열린 enum 목록 문장과 스키마 몇 개만 둔 계약입니다. 줄 번호는 아래 상수와 맞습니다.
func specWith(openEnums string) []byte {
	return []byte(`openapi: 3.1.0
info:
  title: t
  version: 1.0.0
  description: |
    호환과 버전
    * 열린 enum: 값이 늘어날 수 있는 응답 enum입니다.
      ` + openEnums + `입니다. 그 밖의 enum은 닫힌 enum이라 값을 더하면 하위 호환을 깨는 변경으로 봅니다.
components:
  schemas:
    LuckLevel:
      type: string
      enum: [very_good, good]
    ConsentDocument:
      type: object
      properties:
        document:
          type: string
          enum: [terms, age_14]
    FocusSlot:
      type: object
      properties:
        reasons:
          type: array
          items:
            type: string
            enum:
              - a
              - b
`)
}

// 위치(1부터)는 specWith의 enum 값 자리입니다.
var (
	luckLevelVeryGood   = &contractgate.Source{Line: 13, Column: 14}
	consentDocumentAge  = &contractgate.Source{Line: 19, Column: 25}
	focusSlotReasonsB   = &contractgate.Source{Line: 29, Column: 17}
	luckLevelTypeString = &contractgate.Source{Line: 12, Column: 13}
)

func TestEnumNameAt_ComponentPropertyAndItems(t *testing.T) {
	var root yaml.Node
	require.NoError(t, yaml.Unmarshal(specWith("`LuckLevel`"), &root))

	tests := []struct {
		name   string
		source *contractgate.Source
		want   string
	}{
		{"스키마 자체 enum", luckLevelVeryGood, "LuckLevel"},
		{"속성 enum", consentDocumentAge, "ConsentDocument.document"},
		{"배열 속성 항목 enum", focusSlotReasonsB, "FocusSlot.reasons"},
		{"enum 값이 아님", luckLevelTypeString, ""},
		{"없는 위치", &contractgate.Source{Line: 999, Column: 1}, ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, contractgate.EnumNameAt(&root, tt.source.Line, tt.source.Column))
		})
	}
}

func TestEnumNameAt_InlineSchemaIsNotNamed(t *testing.T) {
	var root yaml.Node
	require.NoError(t, yaml.Unmarshal([]byte(`paths:
  /x:
    get:
      responses:
        '200':
          content:
            application/json:
              schema:
                type: string
                enum: [a, b]
`), &root))
	assert.Empty(t, contractgate.EnumNameAt(&root, 10, 24), "경로 안 인라인 enum은 이름이 없어 닫힌 enum으로 봅니다")
}

func TestOpenEnums_ReadsCurrentContract(t *testing.T) {
	spec, err := os.ReadFile("../../api/openapi.yaml")
	require.NoError(t, err)

	names, err := contractgate.OpenEnums(spec)
	require.NoError(t, err)
	// api.TestContract_FreezeOpenEnums와 같은 목록입니다(S93, S114, app A66).
	assert.ElementsMatch(t, []string{
		"NoticeCode", "ShinsalKind", "DayVirtueKind", "RelationKind", "PersonalReading.kind", "FocusSlot.reasons", "SlotText.variant", "Insight.source",
		"ConsentDocument.document", "Problem.code", "LoginProvider", "PurchaseStatus", "YongsinMethod", "SlotText.reaction", "Language",
	}, names)
}

func TestOpenEnums_MissingSentence_Error(t *testing.T) {
	_, err := contractgate.OpenEnums([]byte("info:\n  description: 열린 enum 문장 없음\n"))
	require.Error(t, err)
	_, err = contractgate.OpenEnums([]byte("info:\n  description: |\n    * 열린 enum: 없습니다. 그 밖의 enum은 닫힌 enum입니다.\n"))
	require.Error(t, err, "이름이 하나도 없으면 오류입니다")
}

func enumAdded(source *contractgate.Source) contractgate.Change {
	return contractgate.Change{ID: "response-property-enum-value-added", Level: 3, OperationID: "op", RevisionSource: source}
}

func TestEvaluate(t *testing.T) {
	open := specWith("`ConsentDocument.document`, `FocusSlot.reasons`의 항목")
	closed := specWith("`FocusSlot.reasons`의 항목")

	tests := []struct {
		name         string
		changes      []contractgate.Change
		base, head   []byte
		wantBreaking int
		wantOpen     []string
	}{
		{"닫힌 enum 값 추가(#833)", []contractgate.Change{enumAdded(luckLevelVeryGood)}, open, open, 1, nil},
		{"열린 enum 값 추가", []contractgate.Change{enumAdded(consentDocumentAge), enumAdded(focusSlotReasonsB)}, open, open, 0, []string{"ConsentDocument.document", "FocusSlot.reasons"}},
		{"같은 변경에서 enum을 열고 값 추가", []contractgate.Change{enumAdded(consentDocumentAge)}, closed, open, 1, nil},
		{"위치 없는 enum 값 추가", []contractgate.Change{enumAdded(nil)}, open, open, 1, nil},
		{"응답 mediatype enum 값 추가", []contractgate.Change{{ID: "response-mediatype-enum-value-added", Level: 3, RevisionSource: luckLevelVeryGood}}, open, open, 1, nil},
		{"ERR", []contractgate.Change{{ID: "response-required-property-removed", Level: 3}}, open, open, 1, nil},
		{"WARN", []contractgate.Change{{ID: "request-property-removed", Level: 2}}, open, open, 1, nil},
		{"S93이 막는 info", []contractgate.Change{{ID: "response-optional-property-removed", Level: 1}, {ID: "api-path-removed-with-deprecation", Level: 1}}, open, open, 2, nil},
		{"그 밖의 info", []contractgate.Change{{ID: "endpoint-added", Level: 1}, {ID: "response-optional-property-added", Level: 1}}, open, open, 0, nil},
		{"sunset 없는 deprecated 표시", []contractgate.Change{{ID: "api-deprecated-sunset-missing", Level: 3}}, open, open, 0, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := contractgate.Evaluate(tt.changes, tt.base, tt.head)
			require.NoError(t, err)
			assert.Len(t, result.Breaking, tt.wantBreaking)
			var gotOpen []string
			for _, finding := range result.OpenEnumAdditions {
				gotOpen = append(gotOpen, finding.Enum)
			}
			assert.Equal(t, tt.wantOpen, gotOpen)
		})
	}
}

func TestEvaluate_ClosedEnumFindingNamesEnum(t *testing.T) {
	spec := specWith("`ConsentDocument.document`")
	result, err := contractgate.Evaluate([]contractgate.Change{enumAdded(luckLevelVeryGood)}, spec, spec)
	require.NoError(t, err)
	require.Len(t, result.Breaking, 1)
	assert.Equal(t, "LuckLevel", result.Breaking[0].Enum)
}

func tfvars(ios, android string) []byte {
	return []byte(`server_settings = {
  APP_LINK_BASE           = "https://example.test"
  APP_MIN_VERSION_ANDROID = "` + android + `"
  APP_MIN_VERSION_IOS     = "` + ios + `"
}
`)
}

func TestMinVersions(t *testing.T) {
	versions, err := contractgate.MinVersions(tfvars("1.2.3", ""))
	require.NoError(t, err)
	assert.Equal(t, [3]int{1, 2, 3}, versions["APP_MIN_VERSION_IOS"])
	assert.Equal(t, [3]int{0, 0, 0}, versions["APP_MIN_VERSION_ANDROID"], "빈 값은 server와 같이 0.0.0")

	_, err = contractgate.MinVersions(tfvars("v1.2", "1.0.0"))
	require.Error(t, err)
	_, err = contractgate.MinVersions([]byte(`server_settings = {}`))
	require.Error(t, err, "설정 줄이 없으면 오류")
}

func TestMinVersionsRaised(t *testing.T) {
	parse := func(ios, android string) map[string][3]int {
		versions, err := contractgate.MinVersions(tfvars(ios, android))
		require.NoError(t, err)
		return versions
	}
	tests := []struct {
		name       string
		base, head map[string][3]int
		want       bool
	}{
		{"둘 다 올림", parse("", ""), parse("1.0.0", "1.0.0"), true},
		{"minor 비교는 숫자로", parse("1.9.0", "1.9.0"), parse("1.10.0", "1.10.0"), true},
		{"iOS만 올림", parse("1.0.0", "1.0.0"), parse("1.1.0", "1.0.0"), false},
		{"그대로", parse("1.0.0", "1.0.0"), parse("1.0.0", "1.0.0"), false},
		{"내림", parse("2.0.0", "2.0.0"), parse("1.0.0", "1.0.0"), false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, contractgate.MinVersionsRaised(tt.base, tt.head))
		})
	}
}
