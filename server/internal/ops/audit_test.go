package ops

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
)

func TestValidateReason(t *testing.T) {
	tests := []struct {
		name    string
		in      string
		want    string
		wantErr bool
	}{
		{"빈 값", "", "", true},
		{"공백만", "  ", "", true},
		{"개행 포함", "a\nb", "", true},
		{"캐리지 리턴 포함", "a\rb", "", true},
		{"501자", strings.Repeat("가", 501), "", true},
		{"NUL 포함", "a\x00b", "", true},
		{"잘못된 UTF-8", "a\xffb", "", true},
		{"U+0085 포함", "a\u0085b", "", true},
		{"U+2028 포함", "a\u2028b", "", true},
		{"U+2029 포함", "a\u2029b", "", true},
		{"@ 포함", "문의 a@b", "", true},
		{"7자리 연속 숫자", "회원번호 1234567", "", true},
		{"휴대전화 하이픈", "연락처 010-1234-5678 확인", "", true},
		{"전화번호 공백과 괄호", "(02) 123 4567", "", true},
		{"국제 전화번호", "+82 10 1234 5678", "", true},
		{"전각 숫자 7자리", "１２３４５６７", "", true},
		{"6자리 숫자는 허용", "문의 123456", "문의 123456", false},
		{"문의 번호 허용", "문의 #1234", "문의 #1234", false},
		{"Issue 번호 허용", "Issue #1321 환불 확인", "Issue #1321 환불 확인", false},
		{"# 뒤 숫자끼리는 이어지지 않음", "문의 #1234 #5678", "문의 #1234 #5678", false},
		{"점 날짜 허용", "2026.11.26 장애", "2026.11.26 장애", false},
		{"탭 허용", "a\tb", "a\tb", false},
		{"앞뒤 공백 제거", " 환불 확인 ", "환불 확인", false},
		{"500자", strings.Repeat("가", 500), strings.Repeat("가", 500), false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ValidateReason(tt.in)
			if tt.wantErr {
				assert.ErrorIs(t, err, ErrReason)
				return
			}
			require.NoError(t, err)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestParsePurpose(t *testing.T) {
	for _, s := range []string{"inquiry", "incident", "policy", "legal"} {
		got, err := ParsePurpose(s)
		require.NoError(t, err, s)
		assert.Equal(t, Purpose(s), got)
	}
	for _, s := range []string{"Inquiry", "", "other"} {
		_, err := ParsePurpose(s)
		assert.ErrorIs(t, err, ErrPurpose, s)
	}
}

func TestValidateActor(t *testing.T) {
	assert.NoError(t, validateActor(Actor{Email: "op@example.com", Subject: "sub-1"}))
	assert.ErrorIs(t, validateActor(Actor{Email: "  ", Subject: "sub-1"}), ErrActor)
	assert.ErrorIs(t, validateActor(Actor{Email: "", Subject: "sub-1"}), ErrActor)
	assert.ErrorIs(t, validateActor(Actor{Email: "op@example.com", Subject: " "}), ErrActor)
	assert.ErrorIs(t, validateActor(Actor{Email: "op@example.com"}), ErrActor)
	assert.ErrorIs(t, validateActor(Actor{}), ErrActor)
}

func TestValidateStoreTransaction(t *testing.T) {
	tests := []struct {
		name    string
		in      string
		want    string
		wantErr bool
	}{
		{"빈 값", "", "", true},
		{"공백만", "   ", "", true},
		{"129자", strings.Repeat("a", 129), "", true},
		{"가운데 공백", "GPA 1234", "", true},
		{"슬래시", "GPA/1234", "", true},
		{"한글", "거래1234", "", true},
		{"@ 포함", "a@b", "", true},
		{"128자", strings.Repeat("a", 128), strings.Repeat("a", 128), false},
		{"허용 문자", "GPA.1234-5678_9.0", "GPA.1234-5678_9.0", false},
		{"앞뒤 공백 제거", " tx-1 ", "tx-1", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ValidateStoreTransaction(tt.in)
			if tt.wantErr {
				assert.ErrorIs(t, err, ErrStoreTransaction)
				return
			}
			require.NoError(t, err)
			assert.Equal(t, tt.want, got)
		})
	}
}

func TestRecordTx_WritesRow(t *testing.T) {
	pool := dbtest.New(t)
	ctx := context.Background()
	id := uuid.New()
	var txNow time.Time

	// 넘긴 실행자 ID가 그대로 남고, channel은 ops_api, 시각은 트랜잭션의 now()입니다.
	err := pgx.BeginFunc(ctx, pool, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, "SELECT now()").Scan(&txNow); err != nil {
			return err
		}
		return recordTx(ctx, tx, id, Entry{
			Actor:  testActor,
			Action: ActionAccountShow,
			Reason: "문의 확인",
			Target: map[string]any{"date": "2026-11-01"},
		})
	})
	require.NoError(t, err)

	var (
		actor, actorSub, channel, action, reason string
		target                                   string
		beforeIsNull, afterIsNull                bool
		accountIsNull, purposeIsNull             bool
		gotAt                                    time.Time
	)
	require.NoError(t, pool.QueryRow(ctx, `SELECT actor, actor_sub, channel, action, reason, target::text,
		before IS NULL, after IS NULL, account_id IS NULL, purpose IS NULL, at FROM ops_audit WHERE id = $1`, id).
		Scan(&actor, &actorSub, &channel, &action, &reason, &target, &beforeIsNull, &afterIsNull, &accountIsNull, &purposeIsNull, &gotAt))
	assert.Equal(t, testActor.Email, actor)
	assert.Equal(t, testActor.Subject, actorSub)
	assert.Equal(t, ChannelOpsAPI, channel)
	assert.Equal(t, "account_show", action)
	assert.Equal(t, "문의 확인", reason)
	assert.JSONEq(t, `{"date":"2026-11-01"}`, target)
	assert.True(t, beforeIsNull)
	assert.True(t, afterIsNull)
	assert.True(t, accountIsNull)
	assert.True(t, purposeIsNull)
	assert.True(t, txNow.Equal(gotAt))
}

func TestRecordTx_ContentViewWithPurposeAndNilTarget(t *testing.T) {
	pool := dbtest.New(t)
	ctx := context.Background()
	id := uuid.New()
	accountID := uuid.New()
	purpose := PurposeInquiry

	err := pgx.BeginFunc(ctx, pool, func(tx pgx.Tx) error {
		return recordTx(ctx, tx, id, Entry{
			Actor:     testActor,
			Action:    ActionContentView,
			AccountID: &accountID,
			Purpose:   &purpose,
			Reason:    "문의",
			After:     map[string]any{"n": 1},
		})
	})
	require.NoError(t, err)

	var target, after, gotPurpose string
	var gotAccount uuid.UUID
	require.NoError(t, pool.QueryRow(ctx, `SELECT target::text, after::text, purpose, account_id FROM ops_audit WHERE id = $1`, id).
		Scan(&target, &after, &gotPurpose, &gotAccount))
	assert.JSONEq(t, `{}`, target)
	assert.JSONEq(t, `{"n":1}`, after)
	assert.Equal(t, "inquiry", gotPurpose)
	assert.Equal(t, accountID, gotAccount)
}

func TestRecordTx_TypedNilIsNullOrEmpty(t *testing.T) {
	pool := dbtest.New(t)
	ctx := context.Background()
	id := uuid.New()

	err := pgx.BeginFunc(ctx, pool, func(tx pgx.Tx) error {
		return recordTx(ctx, tx, id, Entry{
			Actor:  testActor,
			Action: ActionAccountShow,
			Reason: "문의",
			Target: (*struct{})(nil),
			Before: (*struct{})(nil),
			After:  map[string]any(nil),
		})
	})
	require.NoError(t, err)

	var target string
	var beforeIsNull, afterIsNull bool
	require.NoError(t, pool.QueryRow(ctx, `SELECT target::text, before IS NULL, after IS NULL FROM ops_audit WHERE id = $1`, id).
		Scan(&target, &beforeIsNull, &afterIsNull))
	assert.JSONEq(t, `{}`, target)
	assert.True(t, beforeIsNull)
	assert.True(t, afterIsNull)
}
