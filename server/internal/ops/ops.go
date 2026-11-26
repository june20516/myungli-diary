// Package ops는 운영 명령(#1321)의 Service입니다.
// 모든 공개 함수는 Actor와 사유를 먼저 검사하고, 감사 행과 데이터 접근을 한 트랜잭션에서 합니다.
// 운영 API(IAP 뒤)가 이 Service를 씁니다.
package ops

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

// 호출자가 errors.Is로 구분하는 사용법 오류입니다.
var (
	// ErrReason은 사유가 비었거나 500자를 넘거나 개행, @, 7자리 이상 숫자열(전화번호 형태 포함)을 포함할 때입니다.
	ErrReason = errors.New("사유는 앞뒤 공백을 뗀 뒤 1~500자이고 줄바꿈, @, 7자리 이상 숫자열(전화번호 형태 포함)을 포함할 수 없습니다. " +
		"개인정보 대신 문의 번호나 Issue 번호를 적으세요(예: 문의 #1234, Issue #1321)")
	// ErrPurpose는 목적이 inquiry, incident, policy, legal이 아닐 때입니다.
	ErrPurpose = errors.New("목적은 inquiry, incident, policy, legal 중 하나여야 합니다")
	// ErrActor는 실행자 메일이나 sub가 비었을 때입니다.
	ErrActor = errors.New("실행자 메일과 sub가 있어야 합니다")
	// ErrStoreTransaction은 스토어 거래 id가 1~128자의 영문, 숫자, 점, 밑줄, 하이픈이 아닐 때입니다.
	ErrStoreTransaction = errors.New("스토어 거래 id는 1~128자의 영문, 숫자, 점, 밑줄, 하이픈이어야 합니다")
)

// ChannelOpsAPI는 감사 행의 channel 값입니다. 운영 명령은 운영 API(IAP 뒤)로만 들어옵니다.
// 감사 INSERT 쿼리(db/queries/ops.sql)의 리터럴과 DB CHECK가 같은 값입니다.
const ChannelOpsAPI = "ops_api"

// Actor는 IAP가 검증한 운영자 Google 계정입니다.
// Email은 사람이 읽는 표시, Subject는 바뀌지 않는 구분자(IAP sub)이며 감사 행에 둘 다 남습니다.
type Actor struct {
	Email   string
	Subject string
}

// validateActor는 Email과 Subject가 공백뿐이 아닌지 검사합니다.
func validateActor(a Actor) error {
	if strings.TrimSpace(a.Email) == "" || strings.TrimSpace(a.Subject) == "" {
		return ErrActor
	}
	return nil
}

// auditIdentity는 감사 행에 남길 정규화한 실행자 값입니다. Email은 앞뒤 공백을 떼고 소문자로 바꿉니다.
func (a Actor) auditIdentity() (email, subject string) {
	return strings.ToLower(strings.TrimSpace(a.Email)), strings.TrimSpace(a.Subject)
}

// Service는 운영 명령을 실행합니다.
type Service struct {
	pool *pgxpool.Pool
	// now는 트랜잭션 안에서 지금 시각을 돌려줍니다. 기본은 DB의 now()입니다.
	// 운영자 노트북 시계로 부여 시작, 회수 시각, 기간 검사가 어긋나지 않게 하려는 것이고, 테스트만 고정 시각으로 바꿉니다.
	now func(ctx context.Context, tx pgx.Tx) (time.Time, error)
}

// NewService는 Service를 만듭니다. 시각은 DB의 now()를 씁니다.
func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool, now: dbNow}
}

// dbNow는 트랜잭션 시작 시각(now())을 UTC로 돌려줍니다. 같은 트랜잭션의 감사 행 at(trigger)과 같은 값입니다.
func dbNow(ctx context.Context, tx pgx.Tx) (time.Time, error) {
	var now time.Time
	if err := tx.QueryRow(ctx, "SELECT now()").Scan(&now); err != nil {
		return time.Time{}, fmt.Errorf("DB 시각 조회: %w", err)
	}
	return now.UTC(), nil
}

// inTx는 fn을 트랜잭션 하나 안에서 실행합니다. 감사 행과 데이터 접근이 함께 커밋되거나 함께 취소됩니다.
func (s *Service) inTx(ctx context.Context, fn func(pgx.Tx) error) error {
	return postgres.InTx(ctx, s.pool, fn)
}
