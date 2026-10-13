package httpapi_test

import (
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

const (
	// contractPath는 계약 원본입니다(이 패키지 디렉터리 기준).
	contractPath = "../../api/openapi.yaml"
	// registryFile은 problem code 상수를 정의하는 유일한 파일입니다(internal 기준 상대 경로).
	registryFile = "httpapi/problem/codes.go"
	// internalDir은 리터럴 검사를 돌릴 소스 루트입니다.
	internalDir = ".."
)

// codeShape는 problem code처럼 생긴 문자열입니다(예 "internal", "request.invalid").
var codeShape = regexp.MustCompile(`^[a-z_]+(\.[a-z_]+)?$`)

// contractCodes는 계약 원본의 `x-problem-codes`를 code -> status로 읽습니다.
func contractCodes(t *testing.T) map[string]int {
	t.Helper()
	raw, err := os.ReadFile(contractPath)
	require.NoError(t, err)
	var spec struct {
		Components struct {
			Schemas struct {
				Problem struct {
					Properties struct {
						Code struct {
							Codes map[string]struct {
								Status int `yaml:"status"`
							} `yaml:"x-problem-codes"`
						} `yaml:"code"`
					} `yaml:"properties"`
				} `yaml:"Problem"`
			} `yaml:"schemas"`
		} `yaml:"components"`
	}
	require.NoError(t, yaml.Unmarshal(raw, &spec))
	result := make(map[string]int)
	for code, entry := range spec.Components.Schemas.Problem.Properties.Code.Codes {
		result[code] = entry.Status
	}
	return result
}

// TestProblemCodes_EmittedCodesAreInContract는 server가 내보내는 모든 code가 계약의 목록에
// 같은 상태로 있는지 확인합니다. 반대로 계약에만 있는 code(아직 구현하지 않은 operation의 것)는 허용합니다.
func TestProblemCodes_EmittedCodesAreInContract(t *testing.T) {
	contract := contractCodes(t)
	require.NotEmpty(t, contract)

	seen := make(map[string]bool)
	for _, c := range problem.AllCodes() {
		t.Run(c.Value, func(t *testing.T) {
			assert.False(t, seen[c.Value], "code가 두 번 등록됨")
			seen[c.Value] = true

			status, ok := contract[c.Value]
			if assert.True(t, ok, "계약 x-problem-codes에 없음") {
				assert.Equal(t, status, c.Status, "계약과 상태가 다름")
			}
		})
	}
}

// TestProblemCodes_AllCodesListsEveryDeclaredCode는 codes.go가 선언한 Code 값이 모두
// AllCodes에 들어 있는지 확인합니다. 선언만 하고 목록에 빠뜨리면 위 대조를 피해 가기 때문입니다.
func TestProblemCodes_AllCodesListsEveryDeclaredCode(t *testing.T) {
	file, err := parser.ParseFile(token.NewFileSet(), filepath.Join(internalDir, registryFile), nil, 0)
	require.NoError(t, err)

	declared := make(map[string]bool)
	ast.Inspect(file, func(n ast.Node) bool {
		lit, ok := n.(*ast.CompositeLit)
		if !ok || len(lit.Elts) == 0 {
			return true
		}
		if ident, ok := lit.Type.(*ast.Ident); !ok || ident.Name != "Code" {
			return true
		}
		if first, ok := lit.Elts[0].(*ast.BasicLit); ok && first.Kind == token.STRING {
			value, err := strconv.Unquote(first.Value)
			require.NoError(t, err)
			declared[value] = true
		}
		return true
	})
	require.NotEmpty(t, declared)

	listed := make(map[string]bool)
	for _, c := range problem.AllCodes() {
		listed[c.Value] = true
	}
	assert.Equal(t, declared, listed)
}

// TestProblemCodes_NoLiteralCodesOutsideRegistry는 registry 밖에서 problem code를 문자열 리터럴로
// 쓰지 않는지 확인합니다. 다음 둘을 찾습니다.
//   - code 자리의 리터럴: problem.New의 두 번째 인자, 키가 code인 필드, Error{Code: ...}
//   - 어디에 있든 registry에 등록된 code와 같은 리터럴
//
// 테스트 파일과 생성 코드(gen)는 보지 않습니다. FieldError.Code의 keyword("required" 등)는
// 등록된 code가 아니고 code 자리 규칙에도 걸리지 않으므로 허용됩니다.
func TestProblemCodes_NoLiteralCodesOutsideRegistry(t *testing.T) {
	registered := make(map[string]bool)
	for _, c := range problem.AllCodes() {
		registered[c.Value] = true
	}

	var violations []string
	err := filepath.WalkDir(internalDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, relErr := filepath.Rel(internalDir, path)
		if relErr != nil {
			return relErr
		}
		rel = filepath.ToSlash(rel)
		if d.IsDir() {
			if rel == "httpapi/gen" {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(rel, ".go") || strings.HasSuffix(rel, "_test.go") || rel == registryFile {
			return nil
		}
		violations = append(violations, literalCodeViolations(t, path, rel, registered)...)
		return nil
	})
	require.NoError(t, err)
	assert.Empty(t, violations, "problem code는 problem/codes.go의 상수를 씁니다")
}

// literalCodeViolations는 한 파일에서 problem code 리터럴 사용 위치를 "파일:줄 리터럴" 꼴로 돌려줍니다.
func literalCodeViolations(t *testing.T, path, rel string, registered map[string]bool) []string {
	t.Helper()
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, path, nil, 0)
	require.NoError(t, err)

	var found []string
	report := func(lit *ast.BasicLit) {
		found = append(found, rel+":"+strconv.Itoa(fset.Position(lit.Pos()).Line)+" "+lit.Value)
	}
	// stringLit는 expr이 문자열 리터럴이면 그 값을 돌려줍니다.
	stringLit := func(expr ast.Expr) (*ast.BasicLit, string, bool) {
		lit, ok := expr.(*ast.BasicLit)
		if !ok || lit.Kind != token.STRING {
			return nil, "", false
		}
		value, err := strconv.Unquote(lit.Value)
		return lit, value, err == nil
	}
	reported := make(map[*ast.BasicLit]bool)
	flag := func(expr ast.Expr, needShape bool) {
		lit, value, ok := stringLit(expr)
		if !ok || reported[lit] || (needShape && !codeShape.MatchString(value)) {
			return
		}
		reported[lit] = true
		report(lit)
	}

	ast.Inspect(file, func(n ast.Node) bool {
		switch node := n.(type) {
		case *ast.CallExpr:
			// problem.New(status, code, title)
			if sel, ok := node.Fun.(*ast.SelectorExpr); ok && sel.Sel.Name == "New" && len(node.Args) == 3 {
				if pkg, ok := sel.X.(*ast.Ident); ok && pkg.Name == "problem" {
					flag(node.Args[1], true)
				}
			}
		case *ast.KeyValueExpr:
			// domainError{code: ...} 같은 소문자 code 필드
			if key, ok := node.Key.(*ast.Ident); ok && key.Name == "code" {
				flag(node.Value, true)
			}
		case *ast.CompositeLit:
			// Error{Code: ...}. FieldError{Code: ...}는 keyword라서 대상이 아닙니다.
			if ident, ok := node.Type.(*ast.Ident); ok && ident.Name == "Error" {
				for _, elt := range node.Elts {
					if kv, ok := elt.(*ast.KeyValueExpr); ok {
						if key, ok := kv.Key.(*ast.Ident); ok && key.Name == "Code" {
							flag(kv.Value, true)
						}
					}
				}
			}
		case *ast.BasicLit:
			if _, value, ok := stringLit(node); ok && registered[value] {
				flag(node, false)
			}
		}
		return true
	})
	return found
}
