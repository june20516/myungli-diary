package notify

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
	"golang.org/x/sync/errgroup"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

const (
	// pageSize는 후보를 한 번에 읽는 수입니다.
	pageSize int32 = 500
	// sendConcurrency는 동시에 처리하는 사용자 수입니다. 사용자 한 명의 기기는 차례로 보내므로 동시 발송도 이 수를 넘지 않습니다(spec §8.2).
	sendConcurrency = 50
	// maxFailureRate를 넘으면 Job을 실패로 끝내 경보를 받습니다(spec §8.2).
	maxFailureRate = 0.05
)

// ErrFailureRate는 한 실행의 발송 실패율이 5%를 넘었다는 뜻입니다.
var ErrFailureRate = errors.New("알림 발송 실패율이 5%를 넘었습니다")

// Ledger는 후보, 발송 기록, 기기 저장소입니다. *Store가 만족합니다.
type Ledger interface {
	ListCandidates(ctx context.Context, after uuid.UUID, limit int32) ([]Candidate, error)
	Claim(ctx context.Context, accountID uuid.UUID, localDate profile.LocalDate, now time.Time) (bool, error)
	Finish(ctx context.Context, accountID uuid.UUID, localDate profile.LocalDate, result string, now time.Time) error
	ActiveDevices(ctx context.Context, accountID uuid.UUID) ([]Device, error)
	Deactivate(ctx context.Context, deviceID uuid.UUID) error
}

// Sender는 메시지를 보냅니다. *FCM이 만족합니다.
type Sender interface {
	Send(ctx context.Context, m Message) error
}

// Composer는 알림 본문을 만듭니다(그날 총운 머리 문장, 호칭 없음).
type Composer interface {
	Body(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (string, error)
}

// Deps는 Run이 쓰는 것입니다.
type Deps struct {
	Ledger   Ledger
	Sender   Sender
	Composer Composer
	// Prepare는 대상이 1명 이상일 때 claim 전에 한 번 부릅니다(엔진 버전 조회). nil이면 건너뜁니다.
	Prepare func(ctx context.Context) error
	Clock   clock.Clock
	Logger  *slog.Logger
}

// Result는 한 번 실행의 수입니다.
type Result struct {
	// Candidates는 읽은 후보 수, InvalidTimezone은 현재 시간대를 읽지 못한 수입니다(Targets와 실패율에서 뺌).
	Candidates, InvalidTimezone int
	// Targets는 지금 보낼 시각인 사용자 수, Skipped는 그중 이미 그날 기록이 있던 수입니다.
	Targets, Skipped int
	// Messages는 시도한 메시지 수(본문을 못 만든 사용자는 1로 셈)이고 Sent + Failed + TokenInvalid와 같습니다.
	Messages, Sent, Failed, TokenInvalid int
}

// target은 지금 보낼 사용자 한 명입니다.
type target struct {
	candidate Candidate
	due       Due
}

// Run은 지금 알림 시각인 사용자에게 하루 한 번 알림을 보냅니다. 실행 시각은 시작할 때 한 번 읽습니다.
// 후보를 모두 읽어 대상을 고른 뒤, 대상이 있으면 Prepare를 부르고, 사용자마다 claim → 본문 → 기기별 발송 → 결과 기록 순으로 처리합니다.
// 조회 실패, 준비 실패, ctx 취소, 실패율 5% 초과가 오류이고, 어느 경우든 수와 단계별 시간을 로그에 남깁니다.
func Run(ctx context.Context, deps Deps) (Result, error) {
	now := deps.Clock.Now()
	var result Result
	var listTime, prepareTime, sendTime time.Duration
	defer func() {
		deps.Logger.InfoContext(context.WithoutCancel(ctx), "notify 완료",
			"candidates", result.Candidates, "invalid_timezone", result.InvalidTimezone,
			"targets", result.Targets, "skipped", result.Skipped,
			"messages", result.Messages, "sent", result.Sent, "failed", result.Failed, "token_invalid", result.TokenInvalid,
			"list_ms", listTime.Milliseconds(), "prepare_ms", prepareTime.Milliseconds(), "send_ms", sendTime.Milliseconds())
	}()

	started := deps.Clock.Now()
	targets, err := selectTargets(ctx, deps.Ledger, now, &result)
	listTime = deps.Clock.Now().Sub(started)
	if err != nil {
		return result, err
	}
	result.Targets = len(targets)
	if len(targets) == 0 {
		return result, nil
	}

	if deps.Prepare != nil {
		started = deps.Clock.Now()
		err := deps.Prepare(ctx)
		prepareTime = deps.Clock.Now().Sub(started)
		if err != nil {
			return result, fmt.Errorf("notify 준비: %w", err)
		}
	}

	started = deps.Clock.Now()
	sendAll(ctx, deps, now, targets, &result)
	sendTime = deps.Clock.Now().Sub(started)
	if err := ctx.Err(); err != nil {
		return result, fmt.Errorf("notify 중단: %w", err)
	}
	if result.Messages > 0 && float64(result.Failed)/float64(result.Messages) > maxFailureRate {
		return result, ErrFailureRate
	}
	return result, nil
}

// selectTargets는 후보를 모두 읽어 지금 알림 시각인 사용자를 고르고, 후보와 시간대 실패 수를 셉니다.
func selectTargets(ctx context.Context, ledger Ledger, now time.Time, result *Result) ([]target, error) {
	var targets []target
	after := uuid.Nil
	for {
		if err := ctx.Err(); err != nil {
			return nil, fmt.Errorf("notify 중단: %w", err)
		}
		page, err := ledger.ListCandidates(ctx, after, pageSize)
		if err != nil {
			return nil, fmt.Errorf("notify 대상 조회: %w", err)
		}
		for _, c := range page {
			result.Candidates++
			notifyAt := c.Profile.Notification.Time
			if notifyAt == nil {
				// enabled인데 시각이 없는 행은 DB 제약상 없습니다. 생기면 대상이 아닌 것으로 봅니다.
				continue
			}
			due, isDue, err := DueAt(now, c.Profile.CurrentTimezone, *notifyAt)
			if err != nil {
				result.InvalidTimezone++
				continue
			}
			if isDue {
				targets = append(targets, target{candidate: c, due: due})
			}
		}
		if len(page) < int(pageSize) {
			return targets, nil
		}
		after = page[len(page)-1].AccountID
	}
}

// sendAll은 대상을 동시 sendConcurrency명까지 처리하고 결과를 셉니다.
func sendAll(ctx context.Context, deps Deps, now time.Time, targets []target, result *Result) {
	var (
		mu    sync.Mutex
		group errgroup.Group
	)
	group.SetLimit(sendConcurrency)
	for _, t := range targets {
		if ctx.Err() != nil {
			break
		}
		group.Go(func() error {
			outcome := deliver(ctx, deps, now, t)
			mu.Lock()
			defer mu.Unlock()
			result.Skipped += outcome.skipped
			result.Messages += outcome.messages
			result.Sent += outcome.sent
			result.Failed += outcome.failed
			result.TokenInvalid += outcome.tokenInvalid
			return nil
		})
	}
	_ = group.Wait() // goroutine은 오류를 돌려주지 않습니다.
}

// outcome은 사용자 한 명의 처리 결과입니다.
type outcome struct {
	skipped, messages, sent, failed, tokenInvalid int
}

// deliver는 사용자 한 명에게 claim, 본문 만들기, 기기별 발송, 결과 기록을 합니다.
// 오류는 수로만 남기고 로그에는 계정 id, 토큰, 본문을 담지 않습니다.
func deliver(ctx context.Context, deps Deps, now time.Time, t target) outcome {
	accountID, date := t.candidate.AccountID, t.due.LocalDate
	claimed, err := deps.Ledger.Claim(ctx, accountID, date, now)
	if err != nil {
		deps.Logger.WarnContext(ctx, "notify claim 실패", "error", err)
		return outcome{messages: 1, failed: 1}
	}
	if !claimed {
		return outcome{skipped: 1}
	}

	var out outcome
	body, err := deps.Composer.Body(ctx, accountID, t.candidate.Profile, date)
	if err != nil || body == "" {
		deps.Logger.WarnContext(ctx, "notify 본문 실패", "error", err)
		out = outcome{messages: 1, failed: 1}
	} else {
		out = sendDevices(ctx, deps, accountID, Message{Body: body, Date: date, Expire: t.due.Expire})
	}

	result := ResultFailed
	if out.sent > 0 {
		result = ResultSent
	}
	if err := deps.Ledger.Finish(context.WithoutCancel(ctx), accountID, date, result, deps.Clock.Now()); err != nil {
		deps.Logger.WarnContext(ctx, "notify 결과 기록 실패", "error", err)
	}
	return out
}

// sendDevices는 사용자의 활성 기기마다 차례로 보냅니다. 토큰이 무효인 기기는 비활성으로 바꾸고 실패로 세지 않습니다.
func sendDevices(ctx context.Context, deps Deps, accountID uuid.UUID, base Message) outcome {
	devices, err := deps.Ledger.ActiveDevices(ctx, accountID)
	if err != nil {
		deps.Logger.WarnContext(ctx, "notify 기기 조회 실패", "error", err)
		return outcome{messages: 1, failed: 1}
	}
	var out outcome
	for _, d := range devices {
		message := base
		message.Token = d.Token
		out.messages++
		err := deps.Sender.Send(ctx, message)
		switch {
		case err == nil:
			out.sent++
		case errors.Is(err, ErrTokenInvalid):
			out.tokenInvalid++
			if err := deps.Ledger.Deactivate(context.WithoutCancel(ctx), d.ID); err != nil {
				deps.Logger.WarnContext(ctx, "notify 기기 비활성 실패", "error", err)
			}
		default:
			out.failed++
			deps.Logger.WarnContext(ctx, "notify 발송 실패", "error", err)
		}
	}
	return out
}
