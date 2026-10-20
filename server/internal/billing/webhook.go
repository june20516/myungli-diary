package billing

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/billing/billingdb"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// ErrWebhookInvalid는 webhook 본문에 문자열 event.id가 없다는 오류입니다(400 request.invalid, P7-8).
var ErrWebhookInvalid = errors.New("webhook 이벤트 형식 오류")

// testEventType은 RevenueCat 대시보드의 시험 전송 이벤트 type입니다. 기록만 하고 동기화하지 않습니다(P7-7).
const testEventType = "TEST"

// webhookIDFields는 계정 id 후보가 문자열 하나로 들어 있는 event 필드입니다.
var webhookIDFields = []string{"app_user_id", "original_app_user_id"}

// webhookIDListFields는 계정 id 후보가 문자열 배열로 들어 있는 event 필드입니다(aliases, TRANSFER의 양쪽).
var webhookIDListFields = []string{"aliases", "transferred_from", "transferred_to"}

// WebhookEvent는 webhook 본문에서 꺼낸 값입니다.
type WebhookEvent struct {
	ID   string
	Type string
	// AccountIDs는 계정 id 후보입니다. 처음 나온 순서이고 중복이 없습니다. accounts에 있는지는 확인하지 않았습니다.
	AccountIDs []uuid.UUID
}

// ParseWebhook은 webhook 본문에서 event.id·type과 계정 id 후보를 꺼냅니다(P7-7).
//
// event가 객체가 아니거나 event.id가 비어 있지 않은 문자열이 아니면 ErrWebhookInvalid입니다.
// 후보는 app_user_id, original_app_user_id, aliases, transferred_from, transferred_to 순으로 모읍니다.
// UUID 표준 소문자 표기(서버가 RevenueCat 고객 id로 쓰는 uuid.UUID.String())만 받습니다.
// 다른 표기는 다른 RevenueCat 고객이라 버리고, `$RCAnonymousID:…` 같은 익명 id도 버립니다.
func ParseWebhook(body map[string]any) (WebhookEvent, error) {
	event, ok := body["event"].(map[string]any)
	if !ok {
		return WebhookEvent{}, fmt.Errorf("%w: event 없음", ErrWebhookInvalid)
	}
	id, ok := event["id"].(string)
	if !ok || id == "" {
		return WebhookEvent{}, fmt.Errorf("%w: event.id 없음", ErrWebhookInvalid)
	}
	eventType, _ := event["type"].(string)

	var candidates []string
	for _, field := range webhookIDFields {
		if value, ok := event[field].(string); ok {
			candidates = append(candidates, value)
		}
	}
	for _, field := range webhookIDListFields {
		values, _ := event[field].([]any)
		for _, value := range values {
			if s, ok := value.(string); ok {
				candidates = append(candidates, s)
			}
		}
	}

	seen := map[uuid.UUID]bool{}
	var accountIDs []uuid.UUID
	for _, candidate := range candidates {
		parsed, err := uuid.Parse(candidate)
		if err != nil || parsed.String() != candidate || seen[parsed] {
			continue
		}
		seen[parsed] = true
		accountIDs = append(accountIDs, parsed)
	}
	return WebhookEvent{ID: id, Type: eventType, AccountIDs: accountIDs}, nil
}

// Webhooks는 RevenueCat webhook을 검증하고 처리합니다. webhook은 신호로만 쓰고 권한은 Syncer가 다시 계산합니다.
type Webhooks struct {
	pool   *pgxpool.Pool
	syncer *Syncer
	// authDigest는 설정한 Authorization 값의 SHA-256입니다. 설정이 비면 nil이고 어떤 요청도 통과하지 않습니다.
	authDigest []byte
	clk        clock.Clock
	log        *slog.Logger
}

// NewWebhooks는 Webhooks를 만듭니다. auth는 RevenueCat 대시보드에 적은 Authorization 값 전체입니다(P7-9).
func NewWebhooks(pool *pgxpool.Pool, syncer *Syncer, auth string, clk clock.Clock, log *slog.Logger) *Webhooks {
	w := &Webhooks{pool: pool, syncer: syncer, clk: clk, log: log}
	if auth != "" {
		digest := sha256.Sum256([]byte(auth))
		w.authDigest = digest[:]
	}
	return w
}

// Authorized는 header가 설정한 Authorization 값과 같은지 봅니다(P7-9).
// 길이가 드러나지 않게 두 값의 SHA-256을 상수 시간으로 비교합니다. 설정 값이 비면 늘 false입니다.
func (w *Webhooks) Authorized(header string) bool {
	if w.authDigest == nil {
		return false
	}
	digest := sha256.Sum256([]byte(header))
	return subtle.ConstantTimeCompare(digest[:], w.authDigest) == 1
}

// Handle은 webhook 이벤트 하나를 처리합니다(P7-7·P7-8).
//
//  1. body를 해석합니다. 형식 오류는 ErrWebhookInvalid입니다.
//  2. 후보 id 중 accounts에 있는 계정을 후보 순서대로 찾습니다.
//  3. billing_events에 기록합니다. 같은 event.id가 이미 있으면 새로 쓰지 않고, 이미 처리됐으면 바로 끝납니다.
//  4. TEST 이벤트와 계정을 찾지 못한 이벤트는 동기화하지 않습니다(계정 없음은 Warn 로그).
//  5. 찾은 계정마다 동기화하고, 모두 끝나면 processed_at을 찍습니다.
//
// 동기화가 실패하면 processed_at을 찍지 않고 오류를 돌려줍니다. RevenueCat이 재전송하면 다시 처리합니다.
// 같은 이벤트가 동시에 오면 둘 다 동기화할 수 있지만 동기화가 멱등이라 결과가 같습니다.
// 로그에는 event.id·type·계정 id만 남기고 본문은 남기지 않습니다.
func (w *Webhooks) Handle(ctx context.Context, body map[string]any) error {
	event, err := ParseWebhook(body)
	if err != nil {
		return err
	}
	queries := billingdb.New(w.pool)

	accountIDs, err := w.existingAccounts(ctx, queries, event.AccountIDs)
	if err != nil {
		return fmt.Errorf("webhook 계정 조회(event %s): %w", event.ID, err)
	}

	processed, err := w.record(ctx, queries, event, accountIDs, body)
	if err != nil {
		return err
	}
	if processed {
		w.log.InfoContext(ctx, "RevenueCat webhook 이미 처리함", "eventId", event.ID, "eventType", event.Type)
		return nil
	}

	switch {
	case event.Type == testEventType:
		w.log.InfoContext(ctx, "RevenueCat webhook 시험 이벤트", "eventId", event.ID)
	case len(accountIDs) == 0:
		// 재전송해도 계정이 생기지 않으므로 기록만 하고 성공으로 답합니다.
		w.log.WarnContext(ctx, "RevenueCat webhook 계정 없음", "eventId", event.ID, "eventType", event.Type)
	default:
		for _, accountID := range accountIDs {
			if err := w.syncer.Sync(ctx, accountID); err != nil {
				return fmt.Errorf("webhook 동기화(event %s): %w", event.ID, err)
			}
		}
		w.log.InfoContext(ctx, "RevenueCat webhook 처리", "eventId", event.ID, "eventType", event.Type, "accountIds", accountIDs)
	}

	if err := queries.MarkBillingEventProcessed(ctx, billingdb.MarkBillingEventProcessedParams{Now: w.clk.Now(), EventID: event.ID}); err != nil {
		return fmt.Errorf("webhook 처리 완료 기록(event %s): %w", event.ID, err)
	}
	return nil
}

// existingAccounts는 candidates 중 accounts에 있는 id를 candidates 순서대로 돌려줍니다.
func (w *Webhooks) existingAccounts(ctx context.Context, queries *billingdb.Queries, candidates []uuid.UUID) ([]uuid.UUID, error) {
	if len(candidates) == 0 {
		return nil, nil
	}
	found, err := queries.ExistingAccountIDs(ctx, candidates)
	if err != nil {
		return nil, err
	}
	exists := make(map[uuid.UUID]bool, len(found))
	for _, id := range found {
		exists[id] = true
	}
	var out []uuid.UUID
	for _, id := range candidates {
		if exists[id] {
			out = append(out, id)
		}
	}
	return out, nil
}

// record는 이벤트를 billing_events에 기록하고, 이미 처리를 마친 이벤트인지 알려 줍니다.
// account_id는 찾은 첫 계정(없으면 NULL)입니다. 이미 있던 행은 그대로 둡니다.
func (w *Webhooks) record(ctx context.Context, queries *billingdb.Queries, event WebhookEvent, accountIDs []uuid.UUID, body map[string]any) (processed bool, err error) {
	payload, err := json.Marshal(body)
	if err != nil {
		return false, fmt.Errorf("webhook 본문 직렬화(event %s): %w", event.ID, err)
	}
	var first uuid.NullUUID
	if len(accountIDs) > 0 {
		first = uuid.NullUUID{UUID: accountIDs[0], Valid: true}
	}
	err = queries.InsertBillingEvent(ctx, billingdb.InsertBillingEventParams{
		EventID:    event.ID,
		AccountID:  first,
		Payload:    payload,
		ReceivedAt: w.clk.Now(),
	})
	if err != nil {
		return false, fmt.Errorf("webhook 기록(event %s): %w", event.ID, err)
	}
	processedAt, err := queries.BillingEventProcessedAt(ctx, event.ID)
	if err != nil {
		return false, fmt.Errorf("webhook 처리 상태 조회(event %s): %w", event.ID, err)
	}
	return processedAt != nil, nil
}
