package ops

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"
	"strings"
	"time"
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

// ValidateReason은 사유의 앞뒤 공백을 떼고 1~500자(rune)인지 검사해 정리한 사유를 돌려줍니다.
// 줄을 깨는 문자(\n, \r, U+0085, U+2028, U+2029)와 NUL, 잘못된 UTF-8이 있으면 ErrReason입니다. 탭은 허용합니다.
func ValidateReason(s string) (string, error) {
	reason := strings.TrimSpace(s)
	if reason == "" || !utf8.ValidString(reason) || utf8.RuneCountInString(reason) > maxReasonRunes ||
		strings.ContainsAny(reason, "\r\n\x00\u0085\u2028\u2029") {
		return "", ErrReason
	}
	return reason, nil
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
func recordTx(ctx context.Context, tx pgx.Tx, id uuid.UUID, at time.Time, e Entry) error {
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

	params := opsdb.InsertOpsAuditParams{
		ID:      id,
		At:      at,
		Actor:   e.Actor.ID,
		Channel: string(e.Actor.Channel),
		Action:  string(e.Action),
		Reason:  e.Reason,
		Target:  targetJSON,
		Before:  beforeJSON,
		After:   afterJSON,
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
