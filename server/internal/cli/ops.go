package cli

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/ops"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// 운영 명령(#1321)입니다. 운영자 컴퓨터에서 실행하고, 결과는 stdout으로만 씁니다.
// 구조화 로그를 쓰지 않습니다. Cloud Logging으로 갈 일이 없고, 열람 본문이 새는 경로를 줄이기 위해서입니다.
// stderr에는 사용법과 오류 한 줄만 나갑니다.

const opsUsageText = `usage: server ops <command>

commands:
  account show (--account <uuid> | --store-transaction <id>) --reason <s> [--json]
  grant --account <uuid> --entitlement ad_free|insight (--days <1~366> | --until <RFC3339>) --reason <s> [--json]
  revoke --account <uuid> --grant <id> --reason <s> [--json]
  content diary|schedule --account <uuid> (--date YYYY-MM-DD | --id <uuid>) --purpose <p> --reason <s> [--json]
  content profile --account <uuid> --purpose <p> --reason <s> [--json]
  audit list (--account <uuid> | --since YYYY-MM-DD) [--limit n] --reason <s> [--json]`

// 감사 기록 조회 --limit의 범위입니다. ops.AuditFilter의 한도와 같습니다.
const (
	opsMaxLimit = 1000
	// opsMaxGrantDays는 --days의 상한입니다.
	opsMaxGrantDays = 366
)

// opsAction은 인자 해석을 마친 운영 명령 하나입니다. DB에 붙은 뒤에 실행합니다.
type opsAction func(ctx context.Context, svc *ops.Service, actor ops.Actor, stdout io.Writer) error

// runOps는 `server ops` 하위 명령을 실행합니다. 인자 오류는 DB에 붙기 전에 사용법 오류로 끝납니다.
func runOps(ctx context.Context, args []string, getenv func(string) string, stdout, _ io.Writer) error {
	clk := clock.System{}
	action, err := parseOps(args, clk)
	if err != nil {
		return err
	}

	cfg, err := config.Load(getenv)
	if err != nil {
		return err
	}
	if err := cfg.RequireDatabase(); err != nil {
		return err
	}
	pool, closeDB, err := openDatabase(ctx, cfg)
	if err != nil {
		return fmt.Errorf("DB 연결 실패: %w", err)
	}
	defer closeDB()

	// 실행자는 인자가 아니라 DB가 인증한 세션 사용자입니다(IAM 인증이라 위조할 수 없습니다).
	var sessionUser string
	if err := pool.QueryRow(ctx, "SELECT session_user").Scan(&sessionUser); err != nil {
		return fmt.Errorf("DB 세션 사용자 확인 실패: %w", err)
	}
	actor := ops.Actor{ID: sessionUser, Channel: ops.ChannelCLI}

	return classifyOpsError(action(ctx, ops.NewService(pool, clk), actor, stdout), sessionUser)
}

// classifyOpsError는 Service 오류를 종료 코드에 맞는 오류로 바꿉니다.
// 입력 오류는 사용법 오류(종료 코드 2), 나머지는 일반 오류(종료 코드 1)입니다. 오류 문구에는 본문이 들어가지 않습니다.
func classifyOpsError(err error, sessionUser string) error {
	if err == nil {
		return nil
	}
	for _, usage := range []error{
		ops.ErrReason, ops.ErrPurpose, ops.ErrActor, ops.ErrAccountKey, ops.ErrAuditFilter,
		ops.ErrGrantPeriod, ops.ErrGrantKind, ops.ErrContentTarget,
	} {
		if errors.Is(err, usage) {
			return usageErrorf("ops: %v", err)
		}
	}

	var ambiguous ops.AmbiguousTransactionError
	if errors.As(err, &ambiguous) {
		ids := make([]string, 0, len(ambiguous.AccountIDs))
		for _, id := range ambiguous.AccountIDs {
			ids = append(ids, id.String())
		}
		return fmt.Errorf("%w: %s (--account로 다시 조회하세요)", err, strings.Join(ids, ", "))
	}

	// 권한 오류의 PostgreSQL 원문에는 표 이름이 들어가므로 싸지 않고 안내만 냅니다.
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "42501" {
		return fmt.Errorf("DB 사용자 %s에 운영자 역할이 없습니다. runbook '운영자 등록'을 보세요", sessionUser)
	}
	return err
}

// parseOps는 `ops` 뒤의 인자를 해석합니다. DB에 붙지 않습니다.
func parseOps(args []string, clk clock.Clock) (opsAction, error) {
	if len(args) == 0 {
		return nil, usageErrorf("%s", opsUsageText)
	}
	rest := args[1:]
	switch args[0] {
	case "account":
		return parseOpsAccount(rest)
	case "grant":
		return parseOpsGrant(rest, clk)
	case "revoke":
		return parseOpsRevoke(rest)
	case "content":
		return parseOpsContent(rest)
	case "audit":
		return parseOpsAudit(rest)
	}
	return nil, usageErrorf("ops: 알 수 없는 하위 명령 %q\n%s", args[0], opsUsageText)
}

// opsFlags는 모든 하위 명령이 쓰는 공통 인자입니다.
type opsFlags struct {
	fs     *flag.FlagSet
	reason *string
	json   *bool
}

// newOpsFlags는 하위 명령 이름으로 FlagSet을 만들고 --reason, --json을 등록합니다.
// FlagSet의 출력은 버립니다. 오류는 usageError로 한 번만 내보냅니다.
func newOpsFlags(name string) *opsFlags {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	return &opsFlags{
		fs:     fs,
		reason: fs.String("reason", "", "사유(필수, 1~500자, 줄바꿈 금지)"),
		json:   fs.Bool("json", false, "JSON으로 출력"),
	}
}

// parse는 인자를 읽고 --reason을 검사합니다. 남는 위치 인자가 있으면 사용법 오류입니다.
func (f *opsFlags) parse(args []string) (reason string, err error) {
	if err := f.fs.Parse(args); err != nil {
		return "", usageErrorf("ops %s: %v\n%s", f.fs.Name(), err, opsUsageText)
	}
	if f.fs.NArg() != 0 {
		return "", usageErrorf("ops %s: 알 수 없는 인자 %q\n%s", f.fs.Name(), f.fs.Arg(0), opsUsageText)
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

func parseOpsAccount(args []string) (opsAction, error) {
	if len(args) == 0 || args[0] != "show" {
		return nil, usageErrorf("ops account: show 하위 명령이 필요합니다\n%s", opsUsageText)
	}
	f := newOpsFlags("account show")
	account := f.fs.String("account", "", "계정 id")
	transaction := f.fs.String("store-transaction", "", "스토어 거래 id")
	reason, err := f.parse(args[1:])
	if err != nil {
		return nil, err
	}

	key := ops.AccountKey{StoreTransaction: strings.TrimSpace(*transaction)}
	if f.isSet("account") == f.isSet("store-transaction") {
		return nil, usageErrorf("ops account show: --account와 --store-transaction 중 하나만 주세요")
	}
	if f.isSet("account") {
		if key.AccountID, err = f.accountFlag(*account); err != nil {
			return nil, err
		}
	} else if key.StoreTransaction == "" {
		return nil, usageErrorf("ops account show: --store-transaction이 비어 있습니다")
	}
	asJSON := *f.json

	return func(ctx context.Context, svc *ops.Service, actor ops.Actor, stdout io.Writer) error {
		summary, err := svc.AccountSummary(ctx, actor, key, reason)
		if err != nil {
			return err
		}
		if asJSON {
			return writeOpsJSON(stdout, summary)
		}
		return printAccountSummary(stdout, summary)
	}, nil
}

func parseOpsGrant(args []string, clk clock.Clock) (opsAction, error) {
	f := newOpsFlags("grant")
	account := f.fs.String("account", "", "계정 id")
	entitlement := f.fs.String("entitlement", "", "부여 종류 ad_free|insight")
	days := f.fs.Int("days", 0, "부여 기간(일, 1~366)")
	until := f.fs.String("until", "", "만료 시각(RFC 3339)")
	reason, err := f.parse(args)
	if err != nil {
		return nil, err
	}

	accountID, err := f.accountFlag(*account)
	if err != nil {
		return nil, err
	}
	kind := billing.OperatorKind(*entitlement)
	if kind != billing.OperatorAdFree && kind != billing.OperatorInsight {
		return nil, usageErrorf("ops grant: --entitlement는 ad_free 또는 insight여야 합니다")
	}
	if f.isSet("days") == f.isSet("until") {
		return nil, usageErrorf("ops grant: --days와 --until 중 하나만 주세요")
	}
	var untilTime time.Time
	if f.isSet("days") {
		if *days < 1 || *days > opsMaxGrantDays {
			return nil, usageErrorf("ops grant: --days는 1~%d여야 합니다", opsMaxGrantDays)
		}
	} else if untilTime, err = time.Parse(time.RFC3339, *until); err != nil {
		return nil, usageErrorf("ops grant: --until은 RFC 3339 시각이어야 합니다")
	}
	asJSON, daysValue := *f.json, *days

	return func(ctx context.Context, svc *ops.Service, actor ops.Actor, stdout io.Writer) error {
		expiresAt := untilTime
		if daysValue > 0 {
			expiresAt = clk.Now().Add(time.Duration(daysValue) * 24 * time.Hour)
		}
		result, err := svc.Grant(ctx, actor, ops.GrantRequest{AccountID: accountID, Kind: kind, ExpiresAt: expiresAt, Reason: reason})
		if err != nil {
			return err
		}
		if asJSON {
			return writeOpsJSON(stdout, result)
		}
		return printGrantResult(stdout, result)
	}, nil
}

func parseOpsRevoke(args []string) (opsAction, error) {
	f := newOpsFlags("revoke")
	account := f.fs.String("account", "", "계정 id")
	grant := f.fs.Int64("grant", 0, "권한 행 id")
	reason, err := f.parse(args)
	if err != nil {
		return nil, err
	}

	accountID, err := f.accountFlag(*account)
	if err != nil {
		return nil, err
	}
	if *grant <= 0 {
		return nil, usageErrorf("ops revoke: --grant는 권한 행 id(양수)여야 합니다")
	}
	grantID, asJSON := *grant, *f.json

	return func(ctx context.Context, svc *ops.Service, actor ops.Actor, stdout io.Writer) error {
		result, err := svc.Revoke(ctx, actor, ops.RevokeRequest{AccountID: accountID, GrantID: grantID, Reason: reason})
		if err != nil {
			return err
		}
		if asJSON {
			return writeOpsJSON(stdout, result)
		}
		return printRevokeResult(stdout, result)
	}, nil
}

// opsContentKinds는 content 하위 명령입니다.
const (
	contentDiary    = "diary"
	contentSchedule = "schedule"
	contentProfile  = "profile"
)

func parseOpsContent(args []string) (opsAction, error) {
	if len(args) == 0 || (args[0] != contentDiary && args[0] != contentSchedule && args[0] != contentProfile) {
		return nil, usageErrorf("ops content: diary, schedule, profile 중 하나가 필요합니다\n%s", opsUsageText)
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
		return nil, err
	}

	accountID, err := f.accountFlag(*account)
	if err != nil {
		return nil, err
	}
	parsedPurpose, err := ops.ParsePurpose(*purpose)
	if err != nil {
		return nil, usageErrorf("ops content %s: --purpose: %v", kind, err)
	}
	target := ops.ContentTarget{AccountID: accountID}
	if kind != contentProfile {
		if f.isSet("date") == f.isSet("id") {
			return nil, usageErrorf("ops content %s: --date와 --id 중 하나만 주세요", kind)
		}
		if f.isSet("date") {
			parsed, err := time.Parse(time.DateOnly, *date)
			if err != nil {
				return nil, usageErrorf("ops content %s: --date는 YYYY-MM-DD여야 합니다", kind)
			}
			target.Date = &profile.LocalDate{Year: parsed.Year(), Month: int(parsed.Month()), Day: parsed.Day()}
		} else {
			parsed, err := uuid.Parse(*id)
			if err != nil {
				return nil, usageErrorf("ops content %s: --id는 uuid여야 합니다", kind)
			}
			target.ID = &parsed
		}
	}
	req := ops.ViewRequest{Target: target, Purpose: parsedPurpose, Reason: reason}
	asJSON := *f.json

	return func(ctx context.Context, svc *ops.Service, actor ops.Actor, stdout io.Writer) error {
		switch kind {
		case contentDiary:
			view, err := svc.ViewDiary(ctx, actor, req)
			if err != nil {
				return err
			}
			if asJSON {
				return writeOpsJSON(stdout, view)
			}
			return printDiaryView(stdout, view)
		case contentSchedule:
			view, err := svc.ViewSchedule(ctx, actor, req)
			if err != nil {
				return err
			}
			if asJSON {
				return writeOpsJSON(stdout, view)
			}
			return printScheduleView(stdout, view)
		default:
			view, err := svc.ViewProfile(ctx, actor, accountID, parsedPurpose, reason)
			if err != nil {
				return err
			}
			if asJSON {
				return writeOpsJSON(stdout, view)
			}
			return printProfileView(stdout, view)
		}
	}, nil
}

func parseOpsAudit(args []string) (opsAction, error) {
	if len(args) == 0 || args[0] != "list" {
		return nil, usageErrorf("ops audit: list 하위 명령이 필요합니다\n%s", opsUsageText)
	}
	f := newOpsFlags("audit list")
	account := f.fs.String("account", "", "계정 id")
	since := f.fs.String("since", "", "시작 날짜 YYYY-MM-DD(UTC)")
	limit := f.fs.Int("limit", 0, "최대 건수(1~1000, 기본 100)")
	reason, err := f.parse(args[1:])
	if err != nil {
		return nil, err
	}

	filter := ops.AuditFilter{}
	if !f.isSet("account") && !f.isSet("since") {
		return nil, usageErrorf("ops audit list: --account 또는 --since가 필요합니다")
	}
	if f.isSet("account") {
		accountID, err := f.accountFlag(*account)
		if err != nil {
			return nil, err
		}
		filter.AccountID = &accountID
	}
	if f.isSet("since") {
		parsed, err := time.Parse(time.DateOnly, *since)
		if err != nil {
			return nil, usageErrorf("ops audit list: --since는 YYYY-MM-DD여야 합니다")
		}
		filter.Since = &parsed
	}
	if f.isSet("limit") {
		if *limit < 1 || *limit > opsMaxLimit {
			return nil, usageErrorf("ops audit list: --limit은 1~%d여야 합니다", opsMaxLimit)
		}
		filter.Limit = *limit
	}
	asJSON := *f.json

	return func(ctx context.Context, svc *ops.Service, actor ops.Actor, stdout io.Writer) error {
		records, err := svc.AuditList(ctx, actor, filter, reason)
		if err != nil {
			return err
		}
		if asJSON {
			return writeOpsJSON(stdout, records)
		}
		return printAuditRecords(stdout, records)
	}, nil
}
