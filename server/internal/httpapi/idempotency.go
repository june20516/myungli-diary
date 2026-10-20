package httpapi

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/httpapi/idempotencydb"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// IdempotencyTTL은 같은 Idempotency-Key로 같은 응답을 돌려주는 기간입니다. 만료는 키를 처음 선점한 시각 기준입니다.
const IdempotencyTTL = 24 * time.Hour

// idempotencyKeyHeader는 멱등 키를 싣는 요청 헤더입니다.
const idempotencyKeyHeader = "Idempotency-Key"

// replayedHeaders는 저장했다가 다시 보낼 응답 헤더입니다. 계약이 멱등 응답에 약속하는 것은 Location과 본문 형식입니다.
var replayedHeaders = []string{"Location", "Content-Type"}

// maxClaimAttempts는 선점 중 행이 사라지는 경쟁(다른 요청이 그 사이 행을 지움)에서 다시 시도하는 상한입니다.
const maxClaimAttempts = 3

// IdempotencyRecord는 이미 있는 멱등 키 행입니다.
type IdempotencyRecord struct {
	RequestHash []byte
	// Completed가 false이면 첫 요청이 아직 처리 중입니다(Response는 비어 있습니다).
	Completed bool
	Response  StoredResponse
}

// StoredResponse는 다시 보낼 응답입니다.
type StoredResponse struct {
	Status int
	Header map[string]string
	Body   []byte
}

// IdempotencyStore는 멱등 키 행을 저장합니다.
type IdempotencyStore interface {
	// Claim은 (accountID, key)를 now에 선점합니다. 행이 없거나 만료됐으면 claimed가 true입니다.
	// 살아 있는 행이 있으면 claimed는 false이고 existing에 그 행을 돌려줍니다.
	Claim(ctx context.Context, accountID uuid.UUID, key string, requestHash []byte, now time.Time) (claimed bool, existing IdempotencyRecord, err error)
	// Complete는 선점한 행에 응답을 채워 완료로 표시합니다.
	Complete(ctx context.Context, accountID uuid.UUID, key string, requestHash []byte, resp StoredResponse, now time.Time) error
	// Release는 완료되지 않은 선점을 지워 같은 키로 다시 시도할 수 있게 합니다.
	Release(ctx context.Context, accountID uuid.UUID, key string, requestHash []byte) error
}

// PgIdempotencyStore는 PostgreSQL 위의 IdempotencyStore입니다.
type PgIdempotencyStore struct {
	pool *pgxpool.Pool
}

// NewPgIdempotencyStore는 연결 풀 위에 저장소를 만듭니다.
func NewPgIdempotencyStore(pool *pgxpool.Pool) *PgIdempotencyStore {
	return &PgIdempotencyStore{pool: pool}
}

func (s *PgIdempotencyStore) Claim(ctx context.Context, accountID uuid.UUID, key string, requestHash []byte, now time.Time) (bool, IdempotencyRecord, error) {
	queries := idempotencydb.New(s.pool)
	for range maxClaimAttempts {
		_, err := queries.ClaimIdempotencyKey(ctx, idempotencydb.ClaimIdempotencyKeyParams{
			AccountID: accountID, Key: key, RequestHash: requestHash, CreatedAt: now, ExpiredBefore: now.Add(-IdempotencyTTL),
		})
		if err == nil {
			return true, IdempotencyRecord{}, nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return false, IdempotencyRecord{}, fmt.Errorf("멱등 키 선점: %w", err)
		}

		row, err := queries.GetIdempotencyKey(ctx, idempotencydb.GetIdempotencyKeyParams{AccountID: accountID, Key: key})
		if errors.Is(err, pgx.ErrNoRows) {
			continue // 선점과 조회 사이에 행이 지워졌습니다. 다시 선점합니다.
		}
		if err != nil {
			return false, IdempotencyRecord{}, fmt.Errorf("멱등 키 조회: %w", err)
		}
		record := IdempotencyRecord{RequestHash: row.RequestHash, Completed: row.CompletedAt != nil}
		if record.Completed {
			header := map[string]string{}
			if err := json.Unmarshal(row.Headers, &header); err != nil {
				return false, IdempotencyRecord{}, fmt.Errorf("멱등 키 헤더 해석: %w", err)
			}
			record.Response = StoredResponse{Status: int(row.Status.Int32), Header: header, Body: row.Body}
		}
		return false, record, nil
	}
	return false, IdempotencyRecord{}, errors.New("멱등 키 선점이 경쟁으로 끝나지 않습니다")
}

func (s *PgIdempotencyStore) Complete(ctx context.Context, accountID uuid.UUID, key string, requestHash []byte, resp StoredResponse, now time.Time) error {
	headers, err := json.Marshal(resp.Header)
	if err != nil {
		return fmt.Errorf("멱등 키 헤더 직렬화: %w", err)
	}
	body := resp.Body
	if body == nil {
		body = []byte{}
	}
	affected, err := idempotencydb.New(s.pool).CompleteIdempotencyKey(ctx, idempotencydb.CompleteIdempotencyKeyParams{
		Status: pgtype.Int4{Int32: int32(resp.Status), Valid: true}, Headers: headers, Body: body, CompletedAt: &now, //nolint:gosec // HTTP 상태는 int32에 들어갑니다
		AccountID: accountID, Key: key, RequestHash: requestHash,
	})
	if err != nil {
		return fmt.Errorf("멱등 키 완료: %w", err)
	}
	if affected == 0 {
		return errors.New("멱등 키 완료: 선점한 행이 없습니다")
	}
	return nil
}

func (s *PgIdempotencyStore) Release(ctx context.Context, accountID uuid.UUID, key string, requestHash []byte) error {
	err := idempotencydb.New(s.pool).ReleaseIdempotencyKey(ctx, idempotencydb.ReleaseIdempotencyKeyParams{
		AccountID: accountID, Key: key, RequestHash: requestHash,
	})
	if err != nil {
		return fmt.Errorf("멱등 키 해제: %w", err)
	}
	return nil
}

// Idempotency는 Routes.Idempotency에 넣을 함수를 만듭니다. op.ID가 operations에 있는 operation만 감싸고,
// 나머지는 next를 그대로 돌려줍니다. 인증 뒤(계정을 알 때), 계약 검증 뒤에 끼우므로
// 검증에 실패한 요청은 표를 건드리지 않습니다.
//
// Idempotency-Key 헤더가 없는 요청은 멱등 처리 없이 그대로 처리합니다. 있으면:
//   - 처음 보는 키(또는 24시간 지난 키)면 행을 선점하고 처리합니다. 2xx면 상태·Location·Content-Type·본문을 저장하고,
//     2xx가 아니거나 panic·연결 끊김으로 끝나면 행을 지워 같은 키로 다시 시도할 수 있게 합니다.
//   - 요청 지문(메서드·경로·본문의 SHA-256)이 다르면 422 idempotency.mismatch입니다.
//   - 첫 요청이 처리 중이면 409 idempotency.in_progress, 끝났으면 저장한 응답을 그대로 다시 보냅니다.
//
// 저장소 오류는 응답 본문 없이 panic으로 올려 recoverPanic이 로그(본문 제외)와 500으로 처리하게 합니다.
func Idempotency(store IdempotencyStore, clk clock.Clock, log *slog.Logger, operations ...string) func(op Operation, next http.Handler) http.Handler {
	return func(op Operation, next http.Handler) http.Handler {
		if !slices.Contains(operations, op.ID) {
			return next
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := r.Header.Get(idempotencyKeyHeader)
			accountID, _, authenticated := AccountFrom(r.Context())
			if key == "" || !authenticated {
				next.ServeHTTP(w, r)
				return
			}
			serveIdempotent(store, clk, log, op.ID, key, accountID, next, w, r)
		})
	}
}

func serveIdempotent(store IdempotencyStore, clk clock.Clock, log *slog.Logger, operationID, key string, accountID uuid.UUID, next http.Handler, w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			writeTooLarge(w, r)
			return
		}
		panic(fmt.Errorf("멱등 키 요청 본문 읽기: %w", err))
	}
	r.Body = io.NopCloser(bytes.NewReader(body))
	hash := requestHash(r, body)

	claimed, existing, err := store.Claim(r.Context(), accountID, key, hash, clk.Now())
	if err != nil {
		if errors.Is(err, context.Canceled) {
			// Claim 전에 클라이언트가 끊었습니다. 경보가 되지 않게 조용히 연결을 닫습니다.
			panic(http.ErrAbortHandler)
		}
		panic(err)
	}
	if !claimed {
		replayOrReject(w, r, hash, existing)
		return
	}

	// 정상 종료가 아니면(2xx 아님, panic, 연결 끊김) 선점을 풀어 같은 키로 다시 시도할 수 있게 합니다.
	// 연결이 끊겨 ctx가 취소돼도 풀 수 있게 취소를 떼어 냅니다.
	// 2xx로 끝난 요청은 일정이 이미 생겼으므로 지우지 않습니다(keep).
	keep := false
	detached := context.WithoutCancel(r.Context())
	defer func() {
		if keep {
			return
		}
		if err := store.Release(detached, accountID, key, hash); err != nil {
			log.ErrorContext(detached, "멱등 키 해제 실패", "operation", operationID, "accountId", accountID, "error", err)
		}
	}()

	buffered := newBufferedResponse(w)
	next.ServeHTTP(buffered, r)

	if buffered.status/100 == 2 {
		stored := StoredResponse{Status: buffered.status, Header: pickHeaders(buffered.header), Body: buffered.body.Bytes()}
		// 클라이언트가 성공 응답을 받기 전에 행을 완료로 만들어, 응답을 받은 뒤 보낸 재시도가 처리 중으로 보이지 않게 합니다.
		// 클라이언트가 끊겨도 이미 커밋된 처리의 기록은 남아야 하므로 취소를 떼어 냅니다.
		// 완료 기록이 실패해도 행을 지우지 않습니다. 재시도가 중복 생성되는 것보다 409 in_progress가 낫습니다.
		keep = true
		if err := store.Complete(detached, accountID, key, hash, stored, clk.Now()); err != nil {
			log.ErrorContext(detached, "멱등 키 완료 기록 실패", "operation", operationID, "accountId", accountID, "error", err)
		}
	}
	buffered.flush()
}

// replayOrReject는 이미 있는 행에 대한 응답을 씁니다: 지문이 다르면 422, 처리 중이면 409, 완료면 저장한 응답입니다.
func replayOrReject(w http.ResponseWriter, r *http.Request, hash []byte, existing IdempotencyRecord) {
	switch {
	case !bytes.Equal(existing.RequestHash, hash):
		problem.Write(w, r, problem.IdempotencyMismatch.Problem("Idempotency-Key was used with a different request"))
	case !existing.Completed:
		problem.Write(w, r, problem.IdempotencyInProgress.Problem("The request with this Idempotency-Key is still being processed"))
	default:
		for name, value := range existing.Response.Header {
			w.Header().Set(name, value)
		}
		w.WriteHeader(existing.Response.Status)
		_, _ = w.Write(existing.Response.Body)
	}
}

// requestHash는 메서드·경로·본문의 SHA-256입니다. 구분자(0 바이트)로 필드 경계를 고정합니다.
func requestHash(r *http.Request, body []byte) []byte {
	h := sha256.New()
	h.Write([]byte(r.Method))
	h.Write([]byte{0})
	h.Write([]byte(r.URL.Path))
	h.Write([]byte{0})
	h.Write(body)
	return h.Sum(nil)
}

func pickHeaders(header http.Header) map[string]string {
	picked := map[string]string{}
	for _, name := range replayedHeaders {
		if value := header.Get(name); value != "" {
			picked[name] = value
		}
	}
	return picked
}

// bufferedResponse는 핸들러의 응답을 모았다가 flush로 실제 writer에 한 번에 씁니다.
// 응답을 저장한 뒤에 보내기 위해서입니다. 일정 생성처럼 작은 JSON 응답을 위한 것입니다.
type bufferedResponse struct {
	target http.ResponseWriter
	header http.Header
	status int
	body   bytes.Buffer
}

func newBufferedResponse(target http.ResponseWriter) *bufferedResponse {
	// 바깥 middleware가 이미 넣은 헤더(예 X-Trace-Id)는 보존해야 하므로 복사해 시작합니다.
	return &bufferedResponse{target: target, header: target.Header().Clone()}
}

func (b *bufferedResponse) Header() http.Header { return b.header }

func (b *bufferedResponse) WriteHeader(status int) {
	if b.status == 0 && status >= http.StatusOK {
		b.status = status
	}
}

func (b *bufferedResponse) Write(p []byte) (int, error) {
	if b.status == 0 {
		b.status = http.StatusOK
	}
	return b.body.Write(p)
}

func (b *bufferedResponse) flush() {
	status := b.status
	if status == 0 {
		status = http.StatusOK
	}
	target := b.target.Header()
	for name := range target {
		delete(target, name)
	}
	for name, values := range b.header {
		target[name] = values
	}
	b.target.WriteHeader(status)
	_, _ = b.target.Write(b.body.Bytes())
}
