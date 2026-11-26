package ops

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/june20516/myungli-diary/server/internal/ops/opsdb"
)

// maxReasonRunes는 사유의 최대 길이(글자 수)입니다.
const maxReasonRunes = 500

// Purpose는 콘텐츠 열람의 목적입니다.
type Purpose string

// 콘텐츠 열람 목적입니다.
const (
	PurposeInquiry  Purpose = "inquiry"
	PurposeIncident Purpose = "incident"
	PurposePolicy   Purpose = "policy"
	PurposeLegal    Purpose = "legal"
)

// ParsePurpose는 문자열을 목적으로 바꿉니다. 정확히 일치하는 네 값만 받습니다.
func ParsePurpose(s string) (Purpose, error) {
	switch p := Purpose(s); p {
	case PurposeInquiry, PurposeIncident, PurposePolicy, PurposeLegal:
		return p, nil
	default:
		return "", ErrPurpose
	}
}

// maxStoreTransactionLen은 스토어 거래 id의 최대 길이입니다.
const maxStoreTransactionLen = 128

// ValidateStoreTransaction은 스토어 거래 id의 앞뒤 공백을 떼고 1~128자의 [A-Za-z0-9._-]인지 검사해 돌려줍니다.
func ValidateStoreTransaction(s string) (string, error) {
	id := strings.TrimSpace(s)
	if id == "" || len(id) > maxStoreTransactionLen {
		return "", ErrStoreTransaction
	}
	for _, c := range id {
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', c == '.', c == '_', c == '-':
		default:
			return "", ErrStoreTransaction
		}
	}
	return id, nil
}

// ValidateReason은 사유의 앞뒤 공백을 떼고 1~500자(rune)인지 검사해 정리한 사유를 돌려줍니다.
// 줄을 깨는 문자(\n, \r, U+0085, U+2028, U+2029)와 NUL, 잘못된 UTF-8, 메일 주소가 새기 쉬운 @,
// 전화번호나 회원번호처럼 보이는 숫자열(hasLongDigitRun)이 있으면 ErrReason입니다. 탭은 허용합니다.
func ValidateReason(s string) (string, error) {
	reason := strings.TrimSpace(s)
	if reason == "" || !utf8.ValidString(reason) || utf8.RuneCountInString(reason) > maxReasonRunes ||
		strings.ContainsAny(reason, "\r\n\x00\u0085\u2028\u2029@") || hasLongDigitRun(reason) {
		return "", ErrReason
	}
	return reason, nil
}

// maxReasonDigitRun은 사유에 이어 쓸 수 있는 숫자 개수의 상한입니다. 이보다 많으면(7자리 이상) 전화번호 형태로 봅니다.
const maxReasonDigitRun = 6

// dotDatePattern은 사유에서 숫자열로 세지 않는 점 날짜(2026.11.26, 2026.1.5)입니다.
var dotDatePattern = regexp.MustCompile(`[0-9]{4}\.[0-9]{1,2}\.[0-9]{1,2}`)

// hasLongDigitRun은 숫자와 그 사이를 잇는 문자(공백류 전부, -, ., /, _, 괄호, +)로만 이어진 구간에 숫자가 7개 이상 있는지
// 알려 줍니다(010-1234-5678, 010.1234.5678, (02) 123 4567, +82 10 ...). 숫자는 전각 숫자도 셉니다.
// #과 글자는 구간을 끊으므로 "문의 #1234 #5678"은 통과합니다. 앞뒤에 숫자가 붙지 않은 점 날짜(2026.11.26)만 예외로
// 구간을 끊고, 하이픈으로 이은 날짜(2026-11-26)는 8자리 숫자열이라 거절합니다.
func hasLongDigitRun(s string) bool {
	s = maskDotDates(s)
	digits := 0
	for _, r := range s {
		switch {
		case unicode.IsDigit(r):
			digits++
			if digits > maxReasonDigitRun {
				return true
			}
		case isDigitJoiner(r):
		default:
			digits = 0
		}
	}
	return false
}

// isDigitJoiner는 숫자 사이에 있어도 숫자열을 끊지 않는 문자입니다.
func isDigitJoiner(r rune) bool {
	return unicode.IsSpace(r) || strings.ContainsRune("-./_()+", r)
}

// maskDotDates는 앞뒤가 숫자가 아닌 점 날짜를 #으로 바꿔 숫자열을 끊습니다. 앞뒤에 숫자가 붙은 경우(12026.11.26)는 날짜로 보지 않습니다.
func maskDotDates(s string) string {
	matches := dotDatePattern.FindAllStringIndex(s, -1)
	if len(matches) == 0 {
		return s
	}
	var b strings.Builder
	last := 0
	for _, m := range matches {
		before, _ := utf8.DecodeLastRuneInString(s[:m[0]])
		after, _ := utf8.DecodeRuneInString(s[m[1]:])
		if unicode.IsDigit(before) || unicode.IsDigit(after) {
			continue
		}
		b.WriteString(s[last:m[0]])
		b.WriteByte('#')
		last = m[1]
	}
	b.WriteString(s[last:])
	return b.String()
}

// Action은 감사 표에 남기는 운영 행위입니다.
type Action string

// 감사 표에 남기는 운영 행위입니다.
const (
	ActionAccountShow Action = "account_show"
	ActionGrant       Action = "grant"
	ActionRevoke      Action = "revoke"
	ActionContentView Action = "content_view"
	ActionAuditList   Action = "audit_list"
	// ActionDenied는 IAP 검증은 통과했지만 허용 목록 밖이라 거절한 요청입니다. 실행자와 경로만 남깁니다.
	ActionDenied Action = "denied"
)

// Entry는 감사 행 한 건의 내용입니다.
// Target, Before, After는 JSON으로 직렬화해 남기므로 일기와 일정 본문, 호칭, 출생 정보, 제공자 subject, 토큰을 담지 않습니다.
type Entry struct {
	Actor     Actor
	Action    Action
	AccountID *uuid.UUID
	Purpose   *Purpose
	Reason    string
	Target    any
	Before    any
	After     any
}

// recordTx는 감사 행을 tx 안에서 씁니다. Before, After가 nil이면 NULL, Target이 nil이면 {}로 남깁니다.
// 시각(at)은 넘기지 않습니다. trigger(00029 ops_audit_stamp)가 DB의 now()로 정하고,
// channel은 ChannelOpsAPI 하나입니다(쿼리가 정함). actor는 DB가 덮지 않고 넘긴 값(정규화한 메일)을 남기고, actor_sub에는 IAP sub를 남깁니다.
func recordTx(ctx context.Context, tx pgx.Tx, id uuid.UUID, e Entry) error {
	target := e.Target
	if isNil(target) {
		target = struct{}{}
	}
	targetJSON, err := json.Marshal(target)
	if err != nil {
		return fmt.Errorf("감사 target 직렬화: %w", err)
	}
	beforeJSON, err := marshalOptional(e.Before)
	if err != nil {
		return fmt.Errorf("감사 before 직렬화: %w", err)
	}
	afterJSON, err := marshalOptional(e.After)
	if err != nil {
		return fmt.Errorf("감사 after 직렬화: %w", err)
	}

	email, subject := e.Actor.auditIdentity()
	params := opsdb.InsertOpsAuditParams{
		ID:       id,
		Actor:    email,
		ActorSub: subject,
		Action:   string(e.Action),
		Reason:   e.Reason,
		Target:   targetJSON,
		Before:   beforeJSON,
		After:    afterJSON,
	}
	if e.AccountID != nil {
		params.AccountID = uuid.NullUUID{UUID: *e.AccountID, Valid: true}
	}
	if e.Purpose != nil {
		params.Purpose = pgtype.Text{String: string(*e.Purpose), Valid: true}
	}
	if err := opsdb.New(tx).InsertOpsAudit(ctx, params); err != nil {
		return fmt.Errorf("감사 행 쓰기: %w", err)
	}
	return nil
}

// marshalOptional은 v가 nil이면 nil(DB의 NULL)을, 아니면 JSON을 돌려줍니다.
func marshalOptional(v any) ([]byte, error) {
	if isNil(v) {
		return nil, nil
	}
	return json.Marshal(v)
}

// isNil은 v가 untyped nil이거나 nil 포인터, map, slice, interface인지 알려 줍니다.
// typed nil이 JSON null로 남지 않게 untyped nil과 같게 다룹니다.
func isNil(v any) bool {
	if v == nil {
		return true
	}
	rv := reflect.ValueOf(v)
	switch rv.Kind() {
	case reflect.Pointer, reflect.Map, reflect.Slice, reflect.Interface:
		return rv.IsNil()
	default:
		return false
	}
}

// deniedReason은 거절 행의 사유입니다. 거절한 요청은 본문을 읽지 않으므로 운영자가 쓴 사유 대신 고정 문구를 남깁니다.
const deniedReason = "허용 목록 밖 운영자의 요청(자동 기록)"

// maxDeniedRouteLen은 거절 행에 남기는 경로의 최대 길이입니다. 호출자는 등록된 경로 패턴만 넘깁니다.
const maxDeniedRouteLen = 100

// deniedTarget은 거절 행의 target입니다.
type deniedTarget struct {
	Route string `json:"route"`
}

// RecordDenied는 IAP 검증을 통과했지만 허용 목록 밖이라 거절한 요청을 감사 행(action denied)으로 남깁니다.
// 실행자 메일, sub, 경로만 남기고 계정, 목적, 전후 값은 비웁니다(DB 제약 ops_audit_denied_shape).
// route는 요청 값이 아니라 등록된 경로 패턴이어야 합니다.
func (s *Service) RecordDenied(ctx context.Context, actor Actor, route string) error {
	if err := validateActor(actor); err != nil {
		return err
	}
	if route == "" || len(route) > maxDeniedRouteLen {
		return fmt.Errorf("거절 기록의 경로는 1~%d자여야 합니다", maxDeniedRouteLen)
	}
	auditID := uuid.New()
	return s.inTx(ctx, func(tx pgx.Tx) error {
		return recordTx(ctx, tx, auditID, Entry{
			Actor: actor, Action: ActionDenied, Reason: deniedReason, Target: deniedTarget{Route: route},
		})
	})
}
