package notify

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
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
	// composeConcurrency는 본문 만들기(캐시가 없으면 엔진 호출)의 동시 상한입니다. precompute의 엔진 상한(spec §8.1)과 같습니다.
	composeConcurrency = 8
	// maxFailureRate를 넘으면 Job을 실패로 끝내 경보를 받습니다(spec §8.2).
	maxFailureRate = 0.05
	// lookahead는 이번 실행이 기다렸다 보내는 앞쪽 폭이고 Scheduler 주기(notify-every-5m)와 같습니다(D109).
	// 보낼 시각이 [지금, 지금 + lookahead)인 사용자는 다음 실행을 기다리지 않고 이번 실행이 그 시각에 보냅니다.
	lookahead = 5 * time.Minute
)

var (
	// ErrFailureRate는 한 실행의 발송 실패율이 5%를 넘었다는 뜻입니다.
	ErrFailureRate = errors.New("알림 발송 실패율이 5%를 넘었습니다")
	// ErrRecord는 발송 기록이나 기기 상태를 DB에 쓰지 못한 일이 있었다는 뜻입니다.
	ErrRecord = errors.New("알림 기록을 쓰지 못했습니다")
)

// Ledger는 후보, 발송 기록, 기기 저장소입니다. *Store가 만족합니다.
type Ledger interface {
	ListCandidates(ctx context.Context, after uuid.UUID, limit int32) ([]Candidate, error)
	Claim(ctx context.Context, accountID uuid.UUID, localDate profile.LocalDate, now time.Time) (bool, error)
	Finish(ctx context.Context, accountID uuid.UUID, localDate profile.LocalDate, result string, now time.Time) error
	Release(ctx context.Context, accountID uuid.UUID, localDate profile.LocalDate) error
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
	// Offset은 계정의 알림을 고른 시각보다 늦추는 몫입니다. nil이면 SpreadOffset입니다(D109).
	Offset func(accountID uuid.UUID) time.Duration
	// Wait는 until까지 기다립니다. ctx가 끝나면 그 오류를 돌려줍니다. nil이면 실제 timer로 기다립니다.
	Wait func(ctx context.Context, until time.Time) error
}

// offset은 Offset이 없으면 SpreadOffset을 씁니다.
func (d Deps) offset(accountID uuid.UUID) time.Duration {
	if d.Offset == nil {
		return SpreadOffset(accountID)
	}
	return d.Offset(accountID)
}

// wait는 Wait가 없으면 Clock 기준으로 until까지 timer로 기다립니다.
func (d Deps) wait(ctx context.Context, until time.Time) error {
	if d.Wait != nil {
		return d.Wait(ctx, until)
	}
	delay := until.Sub(d.Clock.Now())
	if delay <= 0 {
		return ctx.Err()
	}
	timer := time.NewTimer(delay)
	defer timer.Stop()
	select {
	case <-timer.C:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// Result는 한 번 실행의 수입니다.
type Result struct {
	// Candidates는 읽은 후보 수, InvalidTimezone은 현재 시간대를 읽지 못한 수입니다(Targets와 실패율에서 뺌).
	Candidates, InvalidTimezone int
	// Targets는 지금 보낼 시각인 사용자 수, Skipped는 그중 이미 그날 기록이 있거나 그 사이 지워진 계정 수입니다.
	Targets, Skipped int
	// Messages는 시도한 메시지 수(본문을 못 만든 사용자는 1로 셈)이고 Sent + Failed + TokenInvalid와 같습니다.
	// 실패율은 Failed / (Sent + Failed)입니다. 토큰 무효는 정상 흐름이라 분자와 분모 모두에서 뺍니다.
	Messages, Sent, Failed, TokenInvalid int
	// Released는 한 기기에도 보내지 못해 기록을 지운 사용자 수입니다(다음 실행이 다시 보냄).
	Released int
	// RecordErrors는 기록이나 기기 상태를 쓰지 못한 수입니다. 1 이상이면 Job이 실패합니다.
	RecordErrors int
}

// target은 지금 보낼 사용자 한 명입니다.
type target struct {
	candidate Candidate
	due       Due
}

// Run은 보낼 시각(고른 시각 + 계정 오프셋, D109)이 된 사용자에게 하루 한 번 알림을 보냅니다. 대상을 고르는 시각은 시작할 때 한 번 읽습니다.
// 후보를 모두 읽어 대상을 고른 뒤(보낼 시각이 lookahead 안에 오는 사용자 포함), 대상이 있으면 Prepare를 부르고,
// 보낼 시각 순으로 그 시각까지 기다렸다가 사용자마다 claim → 본문 → 기기별 발송 → 결과 기록 순으로 처리합니다.
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
			"released", result.Released, "record_errors", result.RecordErrors,
			"list_ms", listTime.Milliseconds(), "prepare_ms", prepareTime.Milliseconds(), "send_ms", sendTime.Milliseconds())
	}()

	started := deps.Clock.Now()
	targets, err := selectTargets(ctx, deps, now, &result)
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
	sendAll(ctx, deps, targets, &result)
	sendTime = deps.Clock.Now().Sub(started)
	if err := ctx.Err(); err != nil {
		return result, fmt.Errorf("notify 중단: %w", err)
	}
	var errs []error
	if attempted := result.Sent + result.Failed; attempted > 0 && float64(result.Failed)/float64(attempted) > maxFailureRate {
		errs = append(errs, ErrFailureRate)
	}
	if result.RecordErrors > 0 {
		errs = append(errs, ErrRecord)
	}
	return result, errors.Join(errs...)
}

// selectTargets는 후보를 모두 읽어 보낼 시각이 지났거나 lookahead 안에 오는 사용자를 고르고, 후보와 시간대 실패 수를 셉니다.
func selectTargets(ctx context.Context, deps Deps, now time.Time, result *Result) ([]target, error) {
	var targets []target
	after := uuid.Nil
	for {
		if err := ctx.Err(); err != nil {
			return nil, fmt.Errorf("notify 중단: %w", err)
		}
		page, err := deps.Ledger.ListCandidates(ctx, after, pageSize)
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
			due, isDue, err := DueAt(now, c.Profile.CurrentTimezone, *notifyAt, deps.offset(c.AccountID), lookahead)
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

// sendAll은 대상을 보낼 시각 순으로, 그 시각이 되면 처리를 시작합니다. 동시에 sendConcurrency명까지 처리하고 결과를 셉니다.
// 본문 만들기는 composeConcurrency로 더 좁힙니다. 기다리는 중 ctx가 끝나면 남은 대상은 시작하지 않습니다(다음 실행이 보냄).
func sendAll(ctx context.Context, deps Deps, targets []target, result *Result) {
	var (
		mu    sync.Mutex
		group errgroup.Group
	)
	composeSlots := make(chan struct{}, composeConcurrency)
	group.SetLimit(sendConcurrency)
	slices.SortStableFunc(targets, func(a, b target) int { return a.due.SendAt.Compare(b.due.SendAt) })
	for _, t := range targets {
		if deps.wait(ctx, t.due.SendAt) != nil {
			break
		}
		group.Go(func() error {
			out := deliver(ctx, deps, deps.Clock.Now(), t, composeSlots)
			mu.Lock()
			defer mu.Unlock()
			result.Skipped += out.skipped
			result.Messages += out.messages
			result.Sent += out.sent
			result.Failed += out.failed
			result.TokenInvalid += out.tokenInvalid
			result.Released += out.released
			result.RecordErrors += out.recordErrors
			return nil
		})
	}
	_ = group.Wait() // goroutine은 오류를 돌려주지 않습니다.
}

// outcome은 사용자 한 명의 처리 결과입니다.
type outcome struct {
	skipped, messages, sent, failed, tokenInvalid, released, recordErrors int
}

// deliver는 사용자 한 명에게 claim, 본문 만들기, 기기별 발송, 결과 기록을 합니다.
// 한 기기라도 받으면 sent, 모든 기기의 토큰이 무효면(또는 기기가 없으면) failed로 남깁니다.
// 그 밖에 보내지 못했으면 기록을 지워(release) 창 안의 다음 실행이 다시 보냅니다. 같은 날 알림은 교체 키(tag,
// apns-collapse-id)로 바뀌므로, 전달됐는지 모르는 요청을 다시 보내도 기기에는 하나로 보입니다(S129).
// 오류는 수로만 남기고 로그에는 계정 id, 토큰, 본문을 담지 않습니다.
func deliver(ctx context.Context, deps Deps, now time.Time, t target, composeSlots chan struct{}) outcome {
	accountID, date := t.candidate.AccountID, t.due.LocalDate
	claimed, err := deps.Ledger.Claim(ctx, accountID, date, now)
	switch {
	case errors.Is(err, ErrAccountDeleted):
		return outcome{skipped: 1}
	case err != nil:
		deps.Logger.WarnContext(ctx, "notify claim 실패", "error", err)
		return outcome{messages: 1, failed: 1, recordErrors: 1}
	case !claimed:
		return outcome{skipped: 1}
	}

	var out outcome
	body, err := compose(ctx, deps, t, composeSlots)
	if err != nil {
		deps.Logger.WarnContext(ctx, "notify 본문 실패", "error", err)
		out = outcome{messages: 1, failed: 1}
	} else {
		out = sendDevices(ctx, deps, accountID, Message{Body: body, Date: date, Expire: t.due.Expire})
	}

	// 기록은 Job ctx가 끝나도 남깁니다.
	recordCtx := context.WithoutCancel(ctx)
	switch {
	case out.sent > 0:
		out.recordErrors += finish(recordCtx, deps, accountID, date, ResultSent)
	case out.failed == 0:
		out.recordErrors += finish(recordCtx, deps, accountID, date, ResultFailed)
	default:
		if err := deps.Ledger.Release(recordCtx, accountID, date); err != nil {
			deps.Logger.WarnContext(ctx, "notify 기록 release 실패", "error", err)
			out.recordErrors++
		} else {
			out.released++
		}
	}
	return out
}

// compose는 본문을 만듭니다. 동시에 composeConcurrency개까지만 만듭니다.
func compose(ctx context.Context, deps Deps, t target, slots chan struct{}) (string, error) {
	select {
	case slots <- struct{}{}:
	case <-ctx.Done():
		return "", ctx.Err()
	}
	defer func() { <-slots }()
	body, err := deps.Composer.Body(ctx, t.candidate.AccountID, t.candidate.Profile, t.due.LocalDate)
	if err == nil && body == "" {
		err = errors.New("빈 본문")
	}
	return body, err
}

// finish는 기록의 결과를 바꾸고, 실패하면 1을 돌려줍니다.
func finish(ctx context.Context, deps Deps, accountID uuid.UUID, date profile.LocalDate, result string) int {
	if err := deps.Ledger.Finish(ctx, accountID, date, result, deps.Clock.Now()); err != nil {
		deps.Logger.WarnContext(ctx, "notify 결과 기록 실패", "error", err)
		return 1
	}
	return 0
}

// sendDevices는 사용자의 활성 기기마다 차례로 보냅니다. 토큰이 무효인 기기는 비활성으로 바꾸고 실패로 세지 않습니다.
// Job ctx가 끝나면 남은 기기는 보내지 않고 실패로 셉니다(기록을 지워 다음 실행이 보냄).
func sendDevices(ctx context.Context, deps Deps, accountID uuid.UUID, base Message) outcome {
	devices, err := deps.Ledger.ActiveDevices(ctx, accountID)
	if err != nil {
		deps.Logger.WarnContext(ctx, "notify 기기 조회 실패", "error", err)
		return outcome{messages: 1, failed: 1}
	}
	var out outcome
	for _, d := range devices {
		out.messages++
		if ctx.Err() != nil {
			out.failed++
			continue
		}
		message := base
		message.Token = d.Token
		err := deps.Sender.Send(ctx, message)
		switch {
		case err == nil:
			out.sent++
		case errors.Is(err, ErrTokenInvalid):
			out.tokenInvalid++
			if err := deps.Ledger.Deactivate(context.WithoutCancel(ctx), d.ID); err != nil {
				deps.Logger.WarnContext(ctx, "notify 기기 비활성 실패", "error", err)
				out.recordErrors++
			}
		default:
			out.failed++
			deps.Logger.WarnContext(ctx, "notify 발송 실패", "error", err)
		}
	}
	return out
}
