// Package contractgate는 REST 계약(api/openapi.yaml)의 변경이 이미 나간 앱 빌드를 깨는지 판정합니다(D138, S165).
//
// 깨는 변경 후보는 oasdiff breaking이 찾고, 이 패키지는 그 결과를 계약의 규칙(S93)으로 거릅니다.
//   - oasdiff의 WARN 이상과 breakingInfoIDs(선택 응답 필드 삭제 등 S93이 허용하지 않는 info)는 깨는 변경입니다.
//   - 응답 enum 값 추가는 그 enum이 기준과 새 계약 양쪽의 "열린 enum" 목록(info.description, app A66이 읽는 것)에 있을 때만 통과합니다.
//     같은 변경에서 enum을 열고 값을 더하면 기준 쪽 목록에 없어 막힙니다.
//   - 깨는 변경이 남아도 staging과 prod의 최소 앱 버전(iOS, Android)을 모두 올렸으면 통과합니다(D138 ②의 최소 버전 길).
//     `/v2`는 새 operation 추가라 처음부터 깨는 변경으로 잡히지 않습니다.
package contractgate

import (
	"errors"
	"fmt"
	"regexp"
	"slices"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

// Change는 oasdiff breaking --format json이 내는 변경 하나입니다. 쓰는 칸만 받습니다.
type Change struct {
	ID          string `json:"id"`
	Text        string `json:"text"`
	Level       int    `json:"level"`
	Operation   string `json:"operation"`
	OperationID string `json:"operationId"`
	Path        string `json:"path"`
	// RevisionSource는 새 계약에서 바뀐 곳입니다. enum 값 추가면 더한 값의 위치입니다.
	RevisionSource *Source `json:"revisionSource"`
}

// Source는 계약 파일 안의 위치입니다(1부터 셈).
type Source struct {
	Line   int `json:"line"`
	Column int `json:"column"`
}

// oasdiff 변경 수준입니다.
const (
	levelInfo = 1
	levelWarn = 2
)

// enumValueAddedIDs는 응답 enum에 값을 더한 변경입니다. 열린 enum이면 통과합니다.
var enumValueAddedIDs = []string{"response-property-enum-value-added", "response-mediatype-enum-value-added"}

// breakingInfoIDs는 oasdiff가 info로 보지만 S93(freeze 뒤 추가만)에서 깨는 변경으로 보는 것입니다.
// 선택 응답 필드와 선택 응답 헤더 삭제, deprecated 표시 뒤의 operation과 필드 삭제입니다(v1에서는 지우지 않음, S127).
var breakingInfoIDs = []string{
	"response-optional-property-removed",
	"optional-response-header-removed",
	"api-path-removed-with-deprecation",
	"api-removed-with-deprecation",
	"response-required-property-removed-with-deprecation",
}

// allowedIDs는 oasdiff가 ERR로 보지만 앱을 깨지 않는 변경입니다. deprecated 표시에 sunset 날짜가 없는 것은 표시일 뿐입니다(S127).
var allowedIDs = []string{"api-deprecated-sunset-missing", "api-deprecated-sunset-parse"}

// Result는 판정 결과입니다.
type Result struct {
	// Breaking은 깨는 변경입니다.
	Breaking []Finding
	// OpenEnumAdditions는 열린 enum 값 추가라 통과한 변경입니다.
	OpenEnumAdditions []Finding
}

// Finding은 판정한 변경과 그 enum 이름(enum 값 추가일 때)입니다.
type Finding struct {
	Change Change
	// Enum은 값을 더한 enum의 계약 이름(`LuckLevel`, `ConsentDocument.document`)입니다. 찾지 못하면 빈 문자열입니다.
	Enum string
}

// Evaluate는 oasdiff 변경을 계약 규칙으로 거릅니다. baseSpec과 headSpec은 기준과 새 계약 YAML 원문입니다.
func Evaluate(changes []Change, baseSpec, headSpec []byte) (Result, error) {
	baseOpen, err := OpenEnums(baseSpec)
	if err != nil {
		return Result{}, fmt.Errorf("기준 계약: %w", err)
	}
	headOpen, err := OpenEnums(headSpec)
	if err != nil {
		return Result{}, fmt.Errorf("새 계약: %w", err)
	}
	var headRoot yaml.Node
	if err := yaml.Unmarshal(headSpec, &headRoot); err != nil {
		return Result{}, fmt.Errorf("새 계약 YAML: %w", err)
	}

	var result Result
	for _, change := range changes {
		switch {
		case slices.Contains(allowedIDs, change.ID):
			continue
		case slices.Contains(enumValueAddedIDs, change.ID):
			finding := Finding{Change: change}
			if change.RevisionSource != nil {
				finding.Enum = EnumNameAt(&headRoot, change.RevisionSource.Line, change.RevisionSource.Column)
			}
			if finding.Enum != "" && slices.Contains(baseOpen, finding.Enum) && slices.Contains(headOpen, finding.Enum) {
				result.OpenEnumAdditions = append(result.OpenEnumAdditions, finding)
			} else {
				result.Breaking = append(result.Breaking, finding)
			}
		case change.Level >= levelWarn, change.Level == levelInfo && slices.Contains(breakingInfoIDs, change.ID):
			result.Breaking = append(result.Breaking, Finding{Change: change})
		}
	}
	return result, nil
}

// openEnumSection은 info.description의 "열린 enum:" 항목에서 "그 밖의 enum"까지입니다.
var openEnumSection = regexp.MustCompile(`(?s)\* 열린 enum:(.*?)그 밖의 enum`)

// codeSpan은 `이름` 표기입니다.
var codeSpan = regexp.MustCompile("`([A-Za-z][A-Za-z0-9]*(?:\\.[A-Za-z][A-Za-z0-9]*)?)`")

// OpenEnums는 계약 info.description "호환과 버전" 절의 열린 enum 이름 목록입니다(app A66이 읽는 것과 같은 문장).
// 목록 문장을 찾지 못하거나 비어 있으면 오류입니다(문장이 바뀌어 관문이 모든 enum을 닫힌 것으로 보는 일을 막음).
func OpenEnums(spec []byte) ([]string, error) {
	var doc struct {
		Info struct {
			Description string `yaml:"description"`
		} `yaml:"info"`
	}
	if err := yaml.Unmarshal(spec, &doc); err != nil {
		return nil, fmt.Errorf("YAML: %w", err)
	}
	section := openEnumSection.FindStringSubmatch(doc.Info.Description)
	if section == nil {
		return nil, errors.New(`info.description에 "* 열린 enum: … 그 밖의 enum" 문장이 없습니다`)
	}
	var names []string
	for _, match := range codeSpan.FindAllStringSubmatch(section[1], -1) {
		if !slices.Contains(names, match[1]) {
			names = append(names, match[1])
		}
	}
	if len(names) == 0 {
		return nil, errors.New("열린 enum 목록이 비어 있습니다")
	}
	return names, nil
}

// EnumNameAt은 계약 YAML에서 line, column에 있는 enum 값이 속한 enum의 계약 이름입니다.
// components/schemas의 스키마 자체 enum은 `X`, 그 속성의 enum(배열이면 항목의 enum)은 `X.y`입니다.
// 그 밖의 자리(경로 안 인라인 스키마, 더 깊은 중첩, allOf 등)나 enum 값이 아니면 빈 문자열이라 닫힌 enum으로 봅니다.
func EnumNameAt(root *yaml.Node, line, column int) string {
	path := pathTo(root, line, column, nil)
	if len(path) < 2 || path[len(path)-2] != "enum" {
		return ""
	}
	keys := path[:len(path)-2]
	if len(keys) < 3 || keys[0] != "components" || keys[1] != "schemas" {
		return ""
	}
	schema, rest := keys[2], keys[3:]
	switch {
	case len(rest) == 0:
		return schema
	case len(rest) == 2 && rest[0] == "properties":
		return schema + "." + rest[1]
	case len(rest) == 3 && rest[0] == "properties" && rest[2] == "items":
		return schema + "." + rest[1]
	}
	return ""
}

// pathTo는 node 아래에서 line, column에 있는 scalar까지의 키 경로입니다. 배열 항목은 순번 문자열입니다. 없으면 nil입니다.
func pathTo(node *yaml.Node, line, column int, prefix []string) []string {
	switch node.Kind {
	case yaml.DocumentNode:
		for _, child := range node.Content {
			if found := pathTo(child, line, column, prefix); found != nil {
				return found
			}
		}
	case yaml.MappingNode:
		for i := 0; i+1 < len(node.Content); i += 2 {
			key := node.Content[i].Value
			if found := pathTo(node.Content[i+1], line, column, append(slices.Clone(prefix), key)); found != nil {
				return found
			}
		}
	case yaml.SequenceNode:
		for i, child := range node.Content {
			if found := pathTo(child, line, column, append(slices.Clone(prefix), strconv.Itoa(i))); found != nil {
				return found
			}
		}
	case yaml.ScalarNode:
		if node.Line == line && node.Column == column {
			return prefix
		}
	}
	return nil
}

// minVersionNames는 최소 앱 버전 설정 이름입니다(getAppConfig, P6-10).
var minVersionNames = []string{"APP_MIN_VERSION_IOS", "APP_MIN_VERSION_ANDROID"}

// MinVersions는 tfvars 원문의 최소 앱 버전입니다. 비어 있으면 server와 같이 0.0.0입니다(config.LoadAppVersions).
// 설정 줄이 없거나 MAJOR.MINOR.PATCH 숫자 형식이 아니면 오류입니다.
func MinVersions(tfvars []byte) (map[string][3]int, error) {
	versions := map[string][3]int{}
	for _, name := range minVersionNames {
		line := regexp.MustCompile(`(?m)^\s*` + name + `\s*=\s*"([^"]*)"`).FindSubmatch(tfvars)
		if line == nil {
			return nil, fmt.Errorf("%s 설정 줄이 없습니다", name)
		}
		version, err := parseVersion(string(line[1]))
		if err != nil {
			return nil, fmt.Errorf("%s: %w", name, err)
		}
		versions[name] = version
	}
	return versions, nil
}

// semver는 server 설정과 같은 MAJOR.MINOR.PATCH 숫자 형식입니다(config.semverPattern).
var semver = regexp.MustCompile(`^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$`)

func parseVersion(raw string) ([3]int, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return [3]int{}, nil
	}
	match := semver.FindStringSubmatch(raw)
	if match == nil {
		return [3]int{}, fmt.Errorf("%q는 MAJOR.MINOR.PATCH 숫자 형식이 아닙니다", raw)
	}
	var version [3]int
	for i := range version {
		n, err := strconv.Atoi(match[i+1])
		if err != nil {
			return [3]int{}, fmt.Errorf("%q: %w", raw, err)
		}
		version[i] = n
	}
	return version, nil
}

// MinVersionsRaised는 head의 최소 앱 버전이 iOS, Android 모두 base보다 높은지 봅니다.
func MinVersionsRaised(base, head map[string][3]int) bool {
	for _, name := range minVersionNames {
		headVersion, baseVersion := head[name], base[name]
		if slices.Compare(headVersion[:], baseVersion[:]) <= 0 {
			return false
		}
	}
	return true
}
