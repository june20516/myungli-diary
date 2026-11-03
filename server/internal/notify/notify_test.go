package notify_test

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/notify"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// memLedger는 메모리 Ledger입니다. Claim은 mutex로 (계정, 날짜)마다 한 번만 true입니다.
type memLedger struct {
	mu          sync.Mutex
	candidates  []notify.Candidate
	devices     map[uuid.UUID][]notify.Device
	claims      map[string]string // "계정|날짜" → result
	deactivated []uuid.UUID
	claimErr    error
	finishErr   error
}

func newLedger() *memLedger {
	return &memLedger{devices: map[uuid.UUID][]notify.Device{}, claims: map[string]string{}}
}

func claimKey(id uuid.UUID, d profile.LocalDate) string {
	return fmt.Sprintf("%s|%04d-%02d-%02d", id, d.Year, d.Month, d.Day)
}

func (l *memLedger) ListCandidates(_ context.Context, after uuid.UUID, limit int32) ([]notify.Candidate, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	var page []notify.Candidate
	for _, c := range l.candidates {
		if bytes.Compare(c.AccountID[:], after[:]) > 0 && len(page) < int(limit) {
			page = append(page, c)
		}
	}
	return page, nil
}

func (l *memLedger) Claim(_ context.Context, id uuid.UUID, d profile.LocalDate, _ time.Time) (bool, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.claimErr != nil {
		return false, l.claimErr
	}
	key := claimKey(id, d)
	if _, ok := l.claims[key]; ok {
		return false, nil
	}
	l.claims[key] = "pending"
	return true, nil
}

func (l *memLedger) Finish(_ context.Context, id uuid.UUID, d profile.LocalDate, result string, _ time.Time) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.finishErr != nil {
		return l.finishErr
	}
	l.claims[claimKey(id, d)] = result
	return nil
}

func (l *memLedger) Release(_ context.Context, id uuid.UUID, d profile.LocalDate) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	delete(l.claims, claimKey(id, d))
	return nil
}

func (l *memLedger) ActiveDevices(_ context.Context, id uuid.UUID) ([]notify.Device, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.devices[id], nil
}

func (l *memLedger) Deactivate(_ context.Context, deviceID uuid.UUID) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.deactivated = append(l.deactivated, deviceID)
	return nil
}

func (l *memLedger) result(id uuid.UUID, d profile.LocalDate) string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.claims[claimKey(id, d)]
}

// addUser는 서울 시간대, 알림 시각 notifyAt인 후보와 기기 n대를 더합니다. 계정 id 순서를 지키려고 정렬된 id를 씁니다.
func (l *memLedger) addUser(timezone string, notifyAt profile.LocalTime, devices int) uuid.UUID {
	id := uuid.Must(uuid.NewV7())
	time.Sleep(time.Millisecond) // UUIDv7 정렬을 보장합니다.
	l.candidates = append(l.candidates, notify.Candidate{AccountID: id, Profile: profile.Profile{
		CurrentTimezone: timezone,
		Notification:    profile.Notification{Status: profile.NotifyEnabled, Time: &notifyAt},
	}})
	for range devices {
		deviceID := uuid.New()
		l.devices[id] = append(l.devices[id], notify.Device{ID: deviceID, Token: "token-" + deviceID.String(), Platform: "android"})
	}
	return id
}

// recordSender는 받은 메시지를 기록하고, fail이 돌려주는 오류로 답합니다. 동시 실행 수 최대값을 잽니다.
type recordSender struct {
	mu         sync.Mutex
	messages   []notify.Message
	fail       func(token string) error
	hold       time.Duration
	running    int
	maxRunning int
}

func (s *recordSender) Send(_ context.Context, m notify.Message) error {
	s.mu.Lock()
	s.running++
	s.maxRunning = max(s.maxRunning, s.running)
	s.mu.Unlock()
	if s.hold > 0 {
		time.Sleep(s.hold)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.running--
	s.messages = append(s.messages, m)
	if s.fail != nil {
		return s.fail(m.Token)
	}
	return nil
}

func (s *recordSender) count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.messages)
}

// fixedComposer는 정해진 본문을 돌려주거나 err로 실패합니다.
type fixedComposer struct {
	body string
	err  error
}

func (c fixedComposer) Body(context.Context, uuid.UUID, profile.Profile, profile.LocalDate) (string, error) {
	return c.body, c.err
}

const testBody = "말과 글에 힘이 실리는 날이에요."

// 2026-11-04 07:05 KST
var notifyNow = time.Date(2026, 11, 3, 22, 5, 0, 0, time.UTC)

var notifyToday = profile.LocalDate{Year: 2026, Month: 11, Day: 4}

// syncBuffer는 여러 Run이 함께 쓰는 로그 버퍼입니다.
type syncBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *syncBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *syncBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}

type notifyRun struct {
	ledger   *memLedger
	sender   *recordSender
	composer notify.Composer
	prepare  func(context.Context) error
	logs     syncBuffer
}

func newNotifyRun() *notifyRun {
	return &notifyRun{ledger: newLedger(), sender: &recordSender{}, composer: fixedComposer{body: testBody}}
}

func (r *notifyRun) run(t *testing.T) (notify.Result, error) {
	t.Helper()
	return notify.Run(context.Background(), notify.Deps{
		Ledger:   r.ledger,
		Sender:   r.sender,
		Composer: r.composer,
		Prepare:  r.prepare,
		Clock:    clocktest.New(notifyNow),
		Logger:   slog.New(slog.NewTextHandler(&r.logs, nil)),
	})
}

var seven = profile.LocalTime{Hour: 7}

func TestRun_SendsToDueUsersDevices(t *testing.T) {
	r := newNotifyRun()
	due := r.ledger.addUser("Asia/Seoul", seven, 2)
	r.ledger.addUser("Asia/Seoul", profile.LocalTime{Hour: 7, Minute: 30}, 1)

	result, err := r.run(t)

	require.NoError(t, err)
	require.Len(t, r.sender.messages, 2)
	seoul := mustLocation(t, "Asia/Seoul")
	tokens := []string{r.sender.messages[0].Token, r.sender.messages[1].Token}
	assert.ElementsMatch(t, []string{r.ledger.devices[due][0].Token, r.ledger.devices[due][1].Token}, tokens)
	for _, m := range r.sender.messages {
		assert.Equal(t, testBody, m.Body)
		assert.Equal(t, notifyToday, m.Date)
		assert.True(t, m.Expire.Equal(time.Date(2026, 11, 5, 0, 0, 0, 0, seoul)))
	}
	assert.Equal(t, notify.ResultSent, r.ledger.result(due, notifyToday))
	assert.Equal(t, notify.Result{Candidates: 2, Targets: 1, Messages: 2, Sent: 2}, result)
}

func TestRun_SkipsAlreadyClaimed(t *testing.T) {
	r := newNotifyRun()
	id := r.ledger.addUser("Asia/Seoul", seven, 1)
	_, err := r.ledger.Claim(context.Background(), id, notifyToday, notifyNow)
	require.NoError(t, err)

	result, err := r.run(t)

	require.NoError(t, err)
	assert.Zero(t, r.sender.count())
	assert.Equal(t, notify.Result{Candidates: 1, Targets: 1, Skipped: 1}, result)
}

func TestRun_ConcurrentRunsSendOnce(t *testing.T) {
	r := newNotifyRun()
	for range 10 {
		r.ledger.addUser("Asia/Seoul", seven, 2)
	}
	var wg sync.WaitGroup
	for range 2 {
		wg.Go(func() {
			_, err := r.run(t)
			assert.NoError(t, err)
		})
	}
	wg.Wait()

	assert.Equal(t, 20, r.sender.count(), "기기 20대에 한 번씩만 보냅니다")
}

func TestRun_TokenInvalidDeactivatesAndNotFailure(t *testing.T) {
	r := newNotifyRun()
	id := r.ledger.addUser("Asia/Seoul", seven, 3)
	stale := r.ledger.devices[id][1]
	r.sender.fail = func(token string) error {
		if token == stale.Token {
			return fmt.Errorf("x: %w", notify.ErrTokenInvalid)
		}
		return nil
	}

	result, err := r.run(t)

	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{stale.ID}, r.ledger.deactivated)
	assert.Equal(t, notify.ResultSent, r.ledger.result(id, notifyToday))
	assert.Equal(t, notify.Result{Candidates: 1, Targets: 1, Messages: 3, Sent: 2, TokenInvalid: 1}, result)
}

// 한 기기에도 보내지 못한 사용자는 기록을 지워(release) 창 안의 다음 실행이 다시 보냅니다.
func TestRun_AllDevicesFailReleasesForNextRun(t *testing.T) {
	r := newNotifyRun()
	for range 30 {
		r.ledger.addUser("Asia/Seoul", seven, 1)
	}
	failing := r.ledger.candidates[0].AccountID
	failToken := r.ledger.devices[failing][0].Token
	r.sender.fail = func(token string) error {
		if token == failToken {
			return errors.New("FCM 실패")
		}
		return nil
	}

	result, err := r.run(t)

	require.NoError(t, err, "30명 중 1명은 5% 이하입니다")
	assert.Empty(t, r.ledger.result(failing, notifyToday), "기록을 지웁니다")
	assert.Equal(t, notify.Result{Candidates: 30, Targets: 30, Messages: 30, Sent: 29, Failed: 1, Released: 1}, result)

	r.sender.fail = nil
	second, err := r.run(t)
	require.NoError(t, err)
	assert.Equal(t, 1, second.Sent, "다음 실행은 그 사용자만 다시 보냅니다")
	assert.Equal(t, notify.ResultSent, r.ledger.result(failing, notifyToday))
}

// 모든 기기의 토큰이 무효면 다시 보낼 곳이 없으므로 failed로 남깁니다.
func TestRun_AllTokensInvalidMarksFailed(t *testing.T) {
	r := newNotifyRun()
	id := r.ledger.addUser("Asia/Seoul", seven, 2)
	r.sender.fail = func(string) error { return fmt.Errorf("x: %w", notify.ErrTokenInvalid) }

	result, err := r.run(t)

	require.NoError(t, err, "토큰 무효는 실패율에 넣지 않습니다")
	assert.Equal(t, notify.ResultFailed, r.ledger.result(id, notifyToday))
	assert.Equal(t, notify.Result{Candidates: 1, Targets: 1, Messages: 2, TokenInvalid: 2}, result)
}

func TestRun_DeletedAccountClaimIsSkipped(t *testing.T) {
	r := newNotifyRun()
	r.ledger.addUser("Asia/Seoul", seven, 1)
	r.ledger.claimErr = fmt.Errorf("claim: %w", notify.ErrAccountDeleted)

	result, err := r.run(t)

	require.NoError(t, err)
	assert.Equal(t, notify.Result{Candidates: 1, Targets: 1, Skipped: 1}, result)
}

func TestRun_RecordErrorFailsJob(t *testing.T) {
	r := newNotifyRun()
	r.ledger.addUser("Asia/Seoul", seven, 1)
	r.ledger.finishErr = errors.New("DB 실패")

	result, err := r.run(t)

	require.ErrorIs(t, err, notify.ErrRecord)
	assert.Equal(t, 1, result.RecordErrors)
	assert.Equal(t, 1, result.Sent)
}

// 본문 만들기(엔진 호출)는 엔진 동시 호출 상한(8, spec §8.1과 같음) 안에서 합니다.
func TestRun_LimitsComposeConcurrency(t *testing.T) {
	r := newNotifyRun()
	for range 40 {
		r.ledger.addUser("Asia/Seoul", seven, 1)
	}
	composer := &slowComposer{hold: 10 * time.Millisecond}
	r.composer = composer

	_, err := r.run(t)

	require.NoError(t, err)
	assert.LessOrEqual(t, composer.maxRunning, 8)
	assert.Greater(t, composer.maxRunning, 1)
}

// slowComposer는 잠깐 막히며 동시 실행 수 최대값을 잽니다.
type slowComposer struct {
	mu         sync.Mutex
	hold       time.Duration
	running    int
	maxRunning int
}

func (c *slowComposer) Body(context.Context, uuid.UUID, profile.Profile, profile.LocalDate) (string, error) {
	c.mu.Lock()
	c.running++
	c.maxRunning = max(c.maxRunning, c.running)
	c.mu.Unlock()
	time.Sleep(c.hold)
	c.mu.Lock()
	c.running--
	c.mu.Unlock()
	return testBody, nil
}

func TestRun_ComposeFailureCountsOneFailedMessage(t *testing.T) {
	r := newNotifyRun()
	id := r.ledger.addUser("Asia/Seoul", seven, 2)
	r.composer = fixedComposer{err: errors.New("엔진 실패")}

	result, err := r.run(t)

	require.ErrorIs(t, err, notify.ErrFailureRate)
	assert.Zero(t, r.sender.count())
	assert.Empty(t, r.ledger.result(id, notifyToday), "보내지 못했으므로 기록을 지워 다음 실행이 다시 시도합니다")
	assert.Equal(t, notify.Result{Candidates: 1, Targets: 1, Messages: 1, Failed: 1, Released: 1}, result)
}

func TestRun_FailureRateAboveFivePercentIsError(t *testing.T) {
	for name, c := range map[string]struct {
		failures int
		wantErr  bool
	}{"10%": {2, true}, "5%": {1, false}} {
		t.Run(name, func(t *testing.T) {
			r := newNotifyRun()
			for range 20 {
				r.ledger.addUser("Asia/Seoul", seven, 1)
			}
			failTokens := map[string]bool{}
			for _, cand := range r.ledger.candidates[:c.failures] {
				failTokens[r.ledger.devices[cand.AccountID][0].Token] = true
			}
			r.sender.fail = func(token string) error {
				if failTokens[token] {
					return errors.New("FCM 실패")
				}
				return nil
			}

			_, err := r.run(t)

			if c.wantErr {
				require.ErrorIs(t, err, notify.ErrFailureRate)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func TestRun_PrepareOnlyWithTargets(t *testing.T) {
	calls := 0
	r := newNotifyRun()
	r.prepare = func(context.Context) error { calls++; return nil }
	r.ledger.addUser("Asia/Seoul", profile.LocalTime{Hour: 12}, 1)
	_, err := r.run(t)
	require.NoError(t, err)
	assert.Zero(t, calls, "대상이 없으면 엔진을 준비하지 않습니다")

	r.ledger.addUser("Asia/Seoul", seven, 1)
	_, err = r.run(t)
	require.NoError(t, err)
	assert.Equal(t, 1, calls)
}

func TestRun_PrepareErrorStopsBeforeClaim(t *testing.T) {
	r := newNotifyRun()
	id := r.ledger.addUser("Asia/Seoul", seven, 1)
	prepareErr := errors.New("엔진 버전 없음")
	r.prepare = func(context.Context) error { return prepareErr }

	_, err := r.run(t)

	require.ErrorIs(t, err, prepareErr)
	assert.Empty(t, r.ledger.result(id, notifyToday), "준비가 실패하면 claim하지 않아 다음 실행이 보냅니다")
	assert.Zero(t, r.sender.count())
}

func TestRun_InvalidTimezoneCountedSeparately(t *testing.T) {
	r := newNotifyRun()
	r.ledger.addUser("Nowhere/Invalid", seven, 1)

	result, err := r.run(t)

	require.NoError(t, err)
	assert.Equal(t, notify.Result{Candidates: 1, InvalidTimezone: 1}, result)
}

func TestRun_LimitsConcurrency(t *testing.T) {
	r := newNotifyRun()
	for range 200 {
		r.ledger.addUser("Asia/Seoul", seven, 1)
	}
	r.sender.hold = 5 * time.Millisecond

	_, err := r.run(t)

	require.NoError(t, err)
	assert.Equal(t, 200, r.sender.count())
	assert.LessOrEqual(t, r.sender.maxRunning, 50)
	assert.Greater(t, r.sender.maxRunning, 1)
}

func TestRun_LogsCountsWithoutIdentifiers(t *testing.T) {
	r := newNotifyRun()
	id := r.ledger.addUser("Asia/Seoul", seven, 1)

	_, err := r.run(t)

	require.NoError(t, err)
	logs := r.logs.String()
	for _, key := range []string{"candidates=", "targets=", "sent=", "failed=", "list_ms=", "send_ms="} {
		assert.Contains(t, logs, key)
	}
	assert.NotContains(t, logs, id.String())
	assert.NotContains(t, logs, r.ledger.devices[id][0].Token)
	assert.NotContains(t, logs, testBody)
}
