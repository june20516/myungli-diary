package cli

import (
	"context"
	"flag"
	"io"
	"slices"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/ops"
)

// 운영 명령(#1321)입니다. 운영자 컴퓨터에서 실행하고, IAP 뒤의 운영 API(server-ops)를 부릅니다. 결과는 stdout으로만 씁니다.
// 실행자와 시각은 서버가 정하므로 CLI는 보내지 않습니다.
// 구조화 로그를 쓰지 않습니다. Cloud Logging으로 갈 일이 없고, 열람 본문이 새는 경로를 줄이기 위해서입니다.
// stderr에는 사용법과 오류 한 줄만 나갑니다.

const opsUsageText = `usage: server ops <command>

commands:
  login --env staging|prod --api-url <https 주소>
  account show (--account <uuid> 또는 --store-transaction <id>) --reason <s> [--json]
  grant --account <uuid> --entitlement ad_free|insight (--days <1~366> 또는 --until <RFC3339>) --reason <s> [--json]
  revoke --account <uuid> --grant <id> --reason <s> [--json]
  content diary|schedule --account <uuid> (--date YYYY-MM-DD 또는 --id <uuid>) --purpose <p> --reason <s> [--json]
  content profile --account <uuid> --purpose <p> --reason <s> [--json]
  audit list (--account <uuid> 또는 --since YYYY-MM-DD, 둘 다 주면 AND) [--limit n] --reason <s> [--json]

login 외 명령은 모두 --env staging|prod가 필요하고, 먼저 그 환경으로 login해 두어야 합니다.`

// 감사 기록 조회 --limit의 범위입니다. ops.AuditFilter의 한도와 같습니다.
const (
	opsMaxLimit = 1000
	// opsMaxGrantDays는 --days의 상한입니다.
	opsMaxGrantDays = 366
)

// opsEnvironments는 운영 명령이 부를 수 있는 환경입니다.
var opsEnvironments = []string{"staging", "prod"}

// opsAction은 인자 해석을 마친 운영 명령 하나입니다. 운영 API를 부르고 결과를 출력합니다.
type opsAction func(ctx context.Context, api opsCaller, stdout io.Writer) error

// opsCommand는 해석한 명령과 그 명령이 부를 환경입니다.
type opsCommand struct {
	env    string
	action opsAction
}

// opsCaller는 운영 API 호출입니다. 시험에서는 httptest 서버를 부르는 같은 클라이언트를 씁니다.
type opsCaller interface {
	call(ctx context.Context, path string, request, response any) error
}

// opsRequest는 운영 API 하나를 부르고 결과를 표나 JSON으로 쓰는 동작을 만듭니다.
func opsRequest[T any](path string, request any, asJSON bool, print func(io.Writer, T) error) opsAction {
	return func(ctx context.Context, api opsCaller, stdout io.Writer) error {
		var result T
		if err := api.call(ctx, path, request, &result); err != nil {
			return err
		}
		if asJSON {
			return writeOpsJSON(stdout, result)
		}
		return print(stdout, result)
	}
}

// runOps는 `server ops` 하위 명령입니다. 실제 Google token endpoint와 기본 HTTP client를 씁니다.
func runOps(ctx context.Context, args []string, getenv func(string) string, stdout, stderr io.Writer) error {
	return newOpsCommand(defaultOpsDeps())(ctx, args, getenv, stdout, stderr)
}

// parseOps는 `ops` 뒤의 인자를 해석합니다. 네트워크에 붙지 않습니다.
func parseOps(args []string) (opsCommand, error) {
	if len(args) == 0 {
		return opsCommand{}, usageErrorf("%s", opsUsageText)
	}
	rest := args[1:]
	switch args[0] {
	case "account":
		return parseOpsAccount(rest)
	case "grant":
		return parseOpsGrant(rest)
	case "revoke":
		return parseOpsRevoke(rest)
	case "content":
		return parseOpsContent(rest)
	case "audit":
		return parseOpsAudit(rest)
	}
	return opsCommand{}, usageErrorf("ops: 알 수 없는 하위 명령 %q\n%s", args[0], opsUsageText)
}

// opsFlags는 모든 하위 명령이 쓰는 공통 인자입니다.
type opsFlags struct {
	fs     *flag.FlagSet
	env    *string
	reason *string
	json   *bool
}

// newOpsFlags는 하위 명령 이름으로 FlagSet을 만들고 --env, --reason, --json을 등록합니다.
// FlagSet의 출력은 버립니다. 오류는 usageError로 한 번만 내보냅니다.
func newOpsFlags(name string) *opsFlags {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	return &opsFlags{
		fs:     fs,
		env:    fs.String("env", "", "환경 staging|prod(필수)"),
		reason: fs.String("reason", "", "사유(필수, 1~500자, 줄바꿈 금지)"),
		json:   fs.Bool("json", false, "JSON으로 출력"),
	}
}

// parse는 인자를 읽고 --env와 --reason을 검사합니다. 남는 위치 인자가 있으면 사용법 오류입니다.
func (f *opsFlags) parse(args []string) (reason string, err error) {
	if err := f.fs.Parse(args); err != nil {
		return "", usageErrorf("ops %s: %v\n%s", f.fs.Name(), err, opsUsageText)
	}
	if f.fs.NArg() != 0 {
		return "", usageErrorf("ops %s: 알 수 없는 인자 %q\n%s", f.fs.Name(), f.fs.Arg(0), opsUsageText)
	}
	if !slices.Contains(opsEnvironments, *f.env) {
		return "", usageErrorf("ops %s: --env는 staging 또는 prod여야 합니다", f.fs.Name())
	}
	reason, err = ops.ValidateReason(*f.reason)
	if err != nil {
		return "", usageErrorf("ops %s: --reason: %v", f.fs.Name(), err)
	}
	return reason, nil
}

// isSet은 인자가 명령줄에 주어졌는지 알려 줍니다.
func (f *opsFlags) isSet(name string) bool {
	set := false
	f.fs.Visit(func(fl *flag.Flag) { set = set || fl.Name == name })
	return set
}

// accountFlag는 필수 --account를 uuid로 읽습니다.
func (f *opsFlags) accountFlag(value string) (uuid.UUID, error) {
	id, err := uuid.Parse(value)
	if err != nil {
		return uuid.Nil, usageErrorf("ops %s: --account는 uuid여야 합니다", f.fs.Name())
	}
	return id, nil
}

// 운영 API 요청 본문입니다. 칸 이름은 internal/opsapi/handlers.go와 같고, 빈 값은 보내지 않습니다.

type opsShowAccountRequest struct {
	AccountID        string `json:"accountId,omitempty"`
	StoreTransaction string `json:"storeTransaction,omitempty"`
	Reason           string `json:"reason"`
}

type opsGrantRequest struct {
	AccountID   string `json:"accountId"`
	Entitlement string `json:"entitlement"`
	Days        int    `json:"days,omitempty"`
	Until       string `json:"until,omitempty"`
	Reason      string `json:"reason"`
}

type opsRevokeRequest struct {
	AccountID string `json:"accountId"`
	GrantID   int64  `json:"grantId"`
	Reason    string `json:"reason"`
}

type opsViewRequest struct {
	AccountID string `json:"accountId"`
	Date      string `json:"date,omitempty"`
	ID        string `json:"id,omitempty"`
	Purpose   string `json:"purpose"`
	Reason    string `json:"reason"`
}

type opsListAuditRequest struct {
	AccountID string `json:"accountId,omitempty"`
	Since     string `json:"since,omitempty"`
	Limit     int    `json:"limit,omitempty"`
	Reason    string `json:"reason"`
}

func parseOpsAccount(args []string) (opsCommand, error) {
	if len(args) == 0 || args[0] != "show" {
		return opsCommand{}, usageErrorf("ops account: show 하위 명령이 필요합니다\n%s", opsUsageText)
	}
	f := newOpsFlags("account show")
	account := f.fs.String("account", "", "계정 id")
	transaction := f.fs.String("store-transaction", "", "스토어 거래 id")
	reason, err := f.parse(args[1:])
	if err != nil {
		return opsCommand{}, err
	}

	request := opsShowAccountRequest{StoreTransaction: strings.TrimSpace(*transaction), Reason: reason}
	if f.isSet("account") == f.isSet("store-transaction") {
		return opsCommand{}, usageErrorf("ops account show: --account와 --store-transaction 중 하나만 주세요")
	}
	if f.isSet("account") {
		accountID, err := f.accountFlag(*account)
		if err != nil {
			return opsCommand{}, err
		}
		request.AccountID = accountID.String()
	} else if request.StoreTransaction == "" {
		return opsCommand{}, usageErrorf("ops account show: --store-transaction이 비어 있습니다")
	}
	return opsCommand{env: *f.env, action: opsRequest("/ops/v1/accounts:show", request, *f.json, printAccountSummary)}, nil
}

func parseOpsGrant(args []string) (opsCommand, error) {
	f := newOpsFlags("grant")
	account := f.fs.String("account", "", "계정 id")
	entitlement := f.fs.String("entitlement", "", "부여 종류 ad_free|insight")
	days := f.fs.Int("days", 0, "부여 기간(일, 1~366)")
	until := f.fs.String("until", "", "만료 시각(RFC 3339)")
	reason, err := f.parse(args)
	if err != nil {
		return opsCommand{}, err
	}

	accountID, err := f.accountFlag(*account)
	if err != nil {
		return opsCommand{}, err
	}
	kind := billing.OperatorKind(*entitlement)
	if kind != billing.OperatorAdFree && kind != billing.OperatorInsight {
		return opsCommand{}, usageErrorf("ops grant: --entitlement는 ad_free 또는 insight여야 합니다")
	}
	if f.isSet("days") == f.isSet("until") {
		return opsCommand{}, usageErrorf("ops grant: --days와 --until 중 하나만 주세요")
	}
	request := opsGrantRequest{AccountID: accountID.String(), Entitlement: string(kind), Reason: reason}
	// --days의 만료는 서버가 DB 시각 기준으로 셉니다. 운영자 컴퓨터 시계를 쓰지 않습니다.
	if f.isSet("days") {
		if *days < 1 || *days > opsMaxGrantDays {
			return opsCommand{}, usageErrorf("ops grant: --days는 1~%d여야 합니다", opsMaxGrantDays)
		}
		request.Days = *days
	} else {
		untilTime, err := time.Parse(time.RFC3339, *until)
		if err != nil {
			return opsCommand{}, usageErrorf("ops grant: --until은 RFC 3339 시각이어야 합니다")
		}
		request.Until = untilTime.Format(time.RFC3339)
	}
	return opsCommand{env: *f.env, action: opsRequest("/ops/v1/grants", request, *f.json, printGrantResult)}, nil
}

func parseOpsRevoke(args []string) (opsCommand, error) {
	f := newOpsFlags("revoke")
	account := f.fs.String("account", "", "계정 id")
	grant := f.fs.Int64("grant", 0, "권한 행 id")
	reason, err := f.parse(args)
	if err != nil {
		return opsCommand{}, err
	}

	accountID, err := f.accountFlag(*account)
	if err != nil {
		return opsCommand{}, err
	}
	if *grant <= 0 {
		return opsCommand{}, usageErrorf("ops revoke: --grant는 권한 행 id(양수)여야 합니다")
	}
	request := opsRevokeRequest{AccountID: accountID.String(), GrantID: *grant, Reason: reason}
	return opsCommand{env: *f.env, action: opsRequest("/ops/v1/grants:revoke", request, *f.json, printRevokeResult)}, nil
}

// opsContentKinds는 content 하위 명령입니다.
const (
	contentDiary    = "diary"
	contentSchedule = "schedule"
	contentProfile  = "profile"
)

func parseOpsContent(args []string) (opsCommand, error) {
	if len(args) == 0 || (args[0] != contentDiary && args[0] != contentSchedule && args[0] != contentProfile) {
		return opsCommand{}, usageErrorf("ops content: diary, schedule, profile 중 하나가 필요합니다\n%s", opsUsageText)
	}
	kind := args[0]
	f := newOpsFlags("content " + kind)
	account := f.fs.String("account", "", "계정 id")
	purpose := f.fs.String("purpose", "", "목적 inquiry|incident|policy|legal")
	var date, id *string
	if kind != contentProfile {
		date = f.fs.String("date", "", "날짜 YYYY-MM-DD")
		id = f.fs.String("id", "", "항목 id")
	}
	reason, err := f.parse(args[1:])
	if err != nil {
		return opsCommand{}, err
	}

	accountID, err := f.accountFlag(*account)
	if err != nil {
		return opsCommand{}, err
	}
	parsedPurpose, err := ops.ParsePurpose(*purpose)
	if err != nil {
		return opsCommand{}, usageErrorf("ops content %s: --purpose: %v", kind, err)
	}
	request := opsViewRequest{AccountID: accountID.String(), Purpose: string(parsedPurpose), Reason: reason}
	if kind != contentProfile {
		if f.isSet("date") == f.isSet("id") {
			return opsCommand{}, usageErrorf("ops content %s: --date와 --id 중 하나만 주세요", kind)
		}
		if f.isSet("date") {
			parsed, err := time.Parse(time.DateOnly, *date)
			if err != nil {
				return opsCommand{}, usageErrorf("ops content %s: --date는 YYYY-MM-DD여야 합니다", kind)
			}
			request.Date = parsed.Format(time.DateOnly)
		} else {
			parsed, err := uuid.Parse(*id)
			if err != nil {
				return opsCommand{}, usageErrorf("ops content %s: --id는 uuid여야 합니다", kind)
			}
			request.ID = parsed.String()
		}
	}

	asJSON := *f.json
	var action opsAction
	switch kind {
	case contentDiary:
		action = opsRequest("/ops/v1/content:diary", request, asJSON, printDiaryView)
	case contentSchedule:
		action = opsRequest("/ops/v1/content:schedule", request, asJSON, printScheduleView)
	default:
		action = opsRequest("/ops/v1/content:profile", request, asJSON, printProfileView)
	}
	return opsCommand{env: *f.env, action: action}, nil
}

func parseOpsAudit(args []string) (opsCommand, error) {
	if len(args) == 0 || args[0] != "list" {
		return opsCommand{}, usageErrorf("ops audit: list 하위 명령이 필요합니다\n%s", opsUsageText)
	}
	f := newOpsFlags("audit list")
	account := f.fs.String("account", "", "계정 id")
	since := f.fs.String("since", "", "시작 날짜 YYYY-MM-DD(UTC)")
	limit := f.fs.Int("limit", 0, "최대 건수(1~1000, 기본 100)")
	reason, err := f.parse(args[1:])
	if err != nil {
		return opsCommand{}, err
	}

	request := opsListAuditRequest{Reason: reason}
	if !f.isSet("account") && !f.isSet("since") {
		return opsCommand{}, usageErrorf("ops audit list: --account 또는 --since가 필요합니다")
	}
	if f.isSet("account") {
		accountID, err := f.accountFlag(*account)
		if err != nil {
			return opsCommand{}, err
		}
		request.AccountID = accountID.String()
	}
	if f.isSet("since") {
		parsed, err := time.Parse(time.DateOnly, *since)
		if err != nil {
			return opsCommand{}, usageErrorf("ops audit list: --since는 YYYY-MM-DD여야 합니다")
		}
		request.Since = parsed.Format(time.DateOnly)
	}
	if f.isSet("limit") {
		if *limit < 1 || *limit > opsMaxLimit {
			return opsCommand{}, usageErrorf("ops audit list: --limit은 1~%d여야 합니다", opsMaxLimit)
		}
		request.Limit = *limit
	}
	return opsCommand{env: *f.env, action: opsRequest("/ops/v1/audit:list", request, *f.json, printAuditRecords)}, nil
}
