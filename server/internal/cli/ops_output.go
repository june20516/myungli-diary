package cli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"text/tabwriter"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/ops"
)

// 운영 명령의 출력입니다. 모두 stdout에만 씁니다. 시각은 UTC RFC 3339, 값이 없으면 "-"입니다.

const opsEmpty = "-"

// writeOpsJSON은 결과를 들여쓴 JSON으로 씁니다. Go encoder는 C0 제어문자만 \uXXXX로 이스케이프하고
// DEL, C1 제어문자(U+0080~U+009F), 양방향(bidi) 제어문자는 그대로 내므로, escapeJSONTerminal로 그 글자를
// \uXXXX로 바꿔 터미널에 그대로 찍어도 안전하게 합니다. 바꾼 뒤에도 JSON 값은 같습니다.
func writeOpsJSON(w io.Writer, v any) error {
	var buf bytes.Buffer
	encoder := json.NewEncoder(&buf)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(v); err != nil {
		return err
	}
	_, err := w.Write(escapeJSONTerminal(buf.Bytes()))
	return err
}

// escapeJSONTerminal은 encoder가 낸 JSON에서 터미널 제어문자(isTerminalControl)와 bidi 제어문자를 \uXXXX로 바꿉니다.
// encoder가 문자열 안의 \n, \t와 C0 제어문자를 이미 이스케이프하므로 남은 \n은 들여쓰기 줄바꿈뿐이고 그대로 둡니다.
// 바꾸는 글자는 모두 ASCII 밖이거나 DEL이라 JSON 구조 글자가 아니므로 문자열 값 안에만 있고,
// 모두 BMP 글자라 \uXXXX 하나로 같은 값이 됩니다. encoder가 잘못된 UTF-8을 U+FFFD로 바꾸므로 입력은 올바른 UTF-8입니다.
func escapeJSONTerminal(encoded []byte) []byte {
	var out bytes.Buffer
	out.Grow(len(encoded))
	for _, r := range string(encoded) {
		if r != '\n' && r != '\t' && (isTerminalControl(r) || isBidiControl(r)) {
			fmt.Fprintf(&out, `\u%04x`, r)
			continue
		}
		out.WriteRune(r)
	}
	return out.Bytes()
}

// newOpsTable은 표 출력기를 만듭니다. 쓴 뒤 Flush를 불러야 합니다.
func newOpsTable(w io.Writer) *tabwriter.Writer {
	return tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
}

// cell은 표 칸에 넣을 글자에서 탭과 줄바꿈을 공백으로 바꿔 열이 깨지지 않게 하고, 터미널 제어문자를 지웁니다.
func cell(s string) string {
	return sanitizeTerminal(strings.NewReplacer("\t", " ", "\r", " ", "\n", " ").Replace(s))
}

// sanitizeTerminal은 사용자 입력 글에서 터미널 제어문자(\n, \t 외 C0 제어문자와 DEL, C1 U+0080~U+009F)와
// 양방향(bidi) 제어문자(U+061C, U+200E, U+200F, U+202A~U+202E, U+2066~U+2069)를 U+FFFD로 바꿉니다.
// 사람이 읽는 출력에서 ESC 시퀀스로 터미널을 조작하거나 글자 방향을 뒤집어 다른 내용처럼 보이게 하지 못하게 합니다.
// JSON 출력은 이 함수 대신 escapeJSONTerminal로 같은 글자를 \uXXXX로 이스케이프합니다(값은 그대로).
func sanitizeTerminal(s string) string {
	return strings.Map(func(r rune) rune {
		if isTerminalControl(r) || isBidiControl(r) {
			return '\uFFFD'
		}
		return r
	}, s)
}

// isTerminalControl은 \n, \t 외 C0 제어문자, DEL, C1 제어문자인지 알려 줍니다.
func isTerminalControl(r rune) bool {
	return r != '\n' && r != '\t' && (r < 0x20 || r == 0x7f || (r >= 0x80 && r <= 0x9f))
}

// isBidiControl은 글자 방향을 바꾸는 표시(ALM, LRM, RLM)와 embedding, override, isolate 제어문자인지 알려 줍니다.
func isBidiControl(r rune) bool {
	return r == '\u061C' || r == '\u200E' || r == '\u200F' || (r >= '\u202A' && r <= '\u202E') || (r >= '\u2066' && r <= '\u2069')
}

func formatTime(t time.Time) string { return t.UTC().Format(time.RFC3339) }

func formatTimePtr(t *time.Time) string {
	if t == nil {
		return opsEmpty
	}
	return formatTime(*t)
}

func formatStringPtr(s *string) string {
	if s == nil {
		return opsEmpty
	}
	return cell(*s)
}

func formatUUIDPtr(id *uuid.UUID) string {
	if id == nil {
		return opsEmpty
	}
	return id.String()
}

func formatBoolPtr(b *bool) string {
	if b == nil {
		return opsEmpty
	}
	return fmt.Sprint(*b)
}

func formatFloatPtr(f *float64) string {
	if f == nil {
		return opsEmpty
	}
	return fmt.Sprint(*f)
}

// printSection은 절 제목을 씁니다.
func printSection(w io.Writer, title string) {
	_, _ = fmt.Fprintf(w, "\n[%s]\n", title)
}

func printAccountSummary(w io.Writer, summary ops.AccountSummary) error {
	account := summary.Account
	_, _ = fmt.Fprint(w, "[계정]\n")
	table := newOpsTable(w)
	_, _ = fmt.Fprintf(table, "ID\t%s\n상태\t%s\n가입\t%s\n삭제\t%s\n최근 활동\t%s\n",
		account.ID, cell(account.Status), formatTime(account.CreatedAt), formatTimePtr(account.DeletedAt), formatTime(account.LastActiveAt))
	if err := table.Flush(); err != nil {
		return err
	}

	printSection(w, "로그인 수단")
	table = newOpsTable(w)
	_, _ = fmt.Fprint(table, "제공자\t연결\n")
	for _, identity := range summary.Identities {
		_, _ = fmt.Fprintf(table, "%s\t%s\n", cell(identity.Provider), formatTime(identity.LinkedAt))
	}
	if err := table.Flush(); err != nil {
		return err
	}

	printSection(w, "기기")
	table = newOpsTable(w)
	_, _ = fmt.Fprint(table, "플랫폼\t활성\t등록\t마지막 접속\n")
	for _, device := range summary.Devices {
		_, _ = fmt.Fprintf(table, "%s\t%t\t%s\t%s\n", cell(device.Platform), device.Active, formatTime(device.CreatedAt), formatTime(device.LastSeenAt))
	}
	if err := table.Flush(); err != nil {
		return err
	}

	printSection(w, "권한 상태")
	table = newOpsTable(w)
	_, _ = fmt.Fprint(table, "권한\t활성\t만료\t출처\n")
	for _, row := range []struct {
		name  string
		state billing.State
	}{{"ad_free", summary.Status.AdFree}, {"insight", summary.Status.Insight}} {
		source := cell(string(row.state.Source))
		if source == "" {
			source = opsEmpty
		}
		_, _ = fmt.Fprintf(table, "%s\t%t\t%s\t%s\n", row.name, row.state.Active, formatTimePtr(row.state.ExpiresAt), source)
	}
	if err := table.Flush(); err != nil {
		return err
	}

	printSection(w, "권한 행")
	if err := printGrantRows(w, summary.Grants); err != nil {
		return err
	}

	printSection(w, "구매")
	table = newOpsTable(w)
	_, _ = fmt.Fprint(table, "상품\t스토어\t스토어 거래 id\t구매\t환불\t환경\t옮겨 온 계정\n")
	for _, purchase := range summary.Purchases {
		environment := "sandbox"
		if purchase.Production {
			environment = "production"
		}
		_, _ = fmt.Fprintf(table, "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", cell(purchase.ProductID), cell(purchase.Store),
			formatStringPtr(purchase.StorePurchaseID), formatTime(purchase.PurchasedAt), formatTimePtr(purchase.RefundedAt),
			environment, formatUUIDPtr(purchase.MergedFrom))
	}
	return table.Flush()
}

// printGrantRows는 권한 행 표를 씁니다.
func printGrantRows(w io.Writer, rows []billing.GrantRow) error {
	table := newOpsTable(w)
	_, _ = fmt.Fprint(table, "행 id\t종류\t출처\t시작\t만료\t취소\n")
	for _, row := range rows {
		_, _ = fmt.Fprintf(table, "%d\t%s\t%s\t%s\t%s\t%s\n",
			row.ID, cell(string(row.Entitlement)), cell(string(row.Source)), formatTime(row.StartsAt), formatTime(row.ExpiresAt), formatTimePtr(row.RevokedAt))
	}
	return table.Flush()
}

func printGrantResult(w io.Writer, result ops.GrantResult) error {
	_, _ = fmt.Fprint(w, "[부여한 권한 행]\n")
	if err := printGrantRows(w, result.Grants); err != nil {
		return err
	}
	_, err := fmt.Fprintf(w, "감사 기록 %s\n", result.AuditID)
	return err
}

func printRevokeResult(w io.Writer, result ops.RevokeResult) error {
	_, _ = fmt.Fprint(w, "[회수 전]\n")
	if err := printGrantRows(w, result.Before); err != nil {
		return err
	}
	printSection(w, "회수 뒤")
	if err := printGrantRows(w, result.After); err != nil {
		return err
	}
	_, err := fmt.Fprintf(w, "감사 기록 %s\n", result.AuditID)
	return err
}

// 열람 출력은 본문에 줄바꿈이 있어 표 대신 항목별 블록으로 씁니다.

func printDiaryView(w io.Writer, view ops.DiaryView) error {
	for _, entry := range view.Entries {
		if _, err := fmt.Fprintf(w, "[일기] %s  %04d-%02d-%02d  작성 %s  수정 %s\n%s\n\n",
			entry.ID, entry.Date.Year, entry.Date.Month, entry.Date.Day, formatTime(entry.CreatedAt), formatTime(entry.UpdatedAt), sanitizeTerminal(entry.Body)); err != nil {
			return err
		}
	}
	tags := opsEmpty
	if len(view.Tags) > 0 {
		tags = sanitizeTerminal(strings.Join(view.Tags, ", "))
	}
	_, err := fmt.Fprintf(w, "일기 %d편, 지운 일기 %d편\n그날 태그: %s\n", len(view.Entries), view.DeletedCount, tags)
	return err
}

func printScheduleView(w io.Writer, view ops.ScheduleView) error {
	for _, entry := range view.Entries {
		clock := "종일"
		if !entry.AllDay {
			clock = formatStringPtr(entry.Time)
		}
		if _, err := fmt.Fprintf(w, "[일정] %s  %04d-%02d-%02d  %s\n제목: %s\n메모: %s\n\n",
			entry.ID, entry.Date.Year, entry.Date.Month, entry.Date.Day, clock, sanitizeTerminal(entry.Title), opsMemo(entry.Memo)); err != nil {
			return err
		}
	}
	_, err := fmt.Fprintf(w, "일정 %d건, 지운 일정 %d건\n", len(view.Entries), view.DeletedCount)
	return err
}

// opsMemo는 메모가 없으면 "-"를 돌려줍니다. 메모는 줄바꿈을 그대로 둡니다.
func opsMemo(memo *string) string {
	if memo == nil {
		return opsEmpty
	}
	return sanitizeTerminal(*memo)
}

func printProfileView(w io.Writer, view ops.ProfileView) error {
	birthDate := opsEmpty
	if view.BirthDate != nil {
		birthDate = fmt.Sprintf("%04d-%02d-%02d", view.BirthDate.Year, view.BirthDate.Month, view.BirthDate.Day)
	}
	table := newOpsTable(w)
	_, _ = fmt.Fprintf(table, "호칭\t%s\n언어\t%s\n현재 시간대\t%s\n달력\t%s\n윤달\t%s\n생년월일\t%s\n태어난 시각 상태\t%s\n태어난 시각\t%s\n성별\t%s\n출생 시간대\t%s\n출생지 상태\t%s\n출생 도시\t%s\n경도\t%s\n",
		formatStringPtr(view.Honorific), cell(view.Language), cell(view.CurrentTimezone), formatStringPtr(view.Calendar),
		formatBoolPtr(view.IsLeapMonth), birthDate, formatStringPtr(view.BirthTimeStatus), formatStringPtr(view.BirthTime),
		formatStringPtr(view.Gender), formatStringPtr(view.BirthTimezone), formatStringPtr(view.BirthPlaceStatus),
		formatStringPtr(view.BirthCityID), formatFloatPtr(view.Longitude))
	return table.Flush()
}

func printAuditRecords(w io.Writer, records []ops.AuditRecord) error {
	table := newOpsTable(w)
	_, _ = fmt.Fprint(table, "시각\t실행자\t실행자 sub\t경로\t동작\t계정\t목적\t사유\t대상\tID\n")
	for _, record := range records {
		// 대상(target JSON)은 길어도 자르지 않고 한 칸에 그대로 둡니다. 전후 값(before, after)은 --json으로 봅니다.
		_, _ = fmt.Fprintf(table, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", formatTime(record.At), cell(record.Actor), cell(record.ActorSub), cell(record.Channel),
			cell(record.Action), formatUUIDPtr(record.AccountID), formatStringPtr(record.Purpose), cell(record.Reason), cell(string(record.Target)), record.ID)
	}
	return table.Flush()
}
