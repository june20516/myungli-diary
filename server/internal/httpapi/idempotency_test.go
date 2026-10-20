package httpapi_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/schedule"
)

const (
	schedulesTarget = "/v1/schedules"
	createBody      = `{"date":"2026-10-21","allDay":true,"title":"회의"}`
	otherBody       = `{"date":"2026-10-22","allDay":true,"title":"다른 회의"}`
	// allDay가 false인데 time이 없어 서비스가 422 request.inconsistent로 거절하는 본문입니다.
	inconsistentBody = `{"date":"2026-10-21","allDay":false,"title":"회의"}`
)

// gatedSchedules는 Create를 가로채는 ScheduleService입니다. 나머지는 실제 서비스에 맡깁니다.
type gatedSchedules struct {
	*schedule.Service
	mu      sync.Mutex
	entered chan struct{} // Create가 들어오면 닫힙니다(한 번만).
	release chan struct{} // 닫히기 전까지 Create가 기다립니다. nil이면 기다리지 않습니다.
	panics  bool          // true이면 Create가 panic합니다.
	once    sync.Once
}

func (g *gatedSchedules) Create(ctx context.Context, accountID uuid.UUID, in schedule.Input) (schedule.Schedule, error) {
	g.mu.Lock()
	entered, release, panics := g.entered, g.release, g.panics
	g.mu.Unlock()
	if entered != nil {
		g.once.Do(func() { close(entered) })
	}
	if release != nil {
		<-release
	}
	if panics {
		panic("핸들러 실패")
	}
	return g.Service.Create(ctx, accountID, in)
}

type idempotencyEnv struct {
	handler  http.Handler
	pool     *pgxpool.Pool
	clk      *clocktest.Fake
	service  *gatedSchedules
	accounts map[string]uuid.UUID
}

// authenticateByHeader는 X-Test-Account(a·b)에 해당하는 계정을 ctx에 넣습니다. 헤더가 없으면 a입니다.
func (e *idempotencyEnv) authenticate(_ httpapi.Operation, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		name := r.Header.Get("X-Test-Account")
		if name == "" {
			name = "a"
		}
		ctx := httpapi.WithAccount(r.Context(), e.accounts[name], account.Access{Status: account.StatusActive})
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func newIdempotencyEnv(t *testing.T) *idempotencyEnv {
	t.Helper()
	pool := dbtest.New(t)
	env := &idempotencyEnv{
		pool:     pool,
		clk:      clocktest.New(time.Date(2026, 10, 20, 0, 0, 0, 0, time.UTC)),
		service:  &gatedSchedules{Service: schedule.NewService(schedule.NewStore(pool))},
		accounts: map[string]uuid.UUID{},
	}
	for _, name := range []string{"a", "b"} {
		var id uuid.UUID
		require.NoError(t, pool.QueryRow(t.Context(),
			"INSERT INTO accounts (id, status, last_active_at) VALUES (gen_random_uuid(), 'active', now()) RETURNING id").Scan(&id))
		env.accounts[name] = id
	}

	spec, err := gen.GetSpec()
	require.NoError(t, err)
	deps, _ := newTestDeps()
	api := &httpapi.API{Schedules: env.service, Logger: deps.Logger, AppLink: testAppLink(t)}
	routes := httpapi.Routes{
		Spec:         spec,
		Validate:     httpapi.ValidateRequests(spec, deps.Logger),
		Authenticate: env.authenticate,
		Idempotency:  httpapi.Idempotency(httpapi.NewPgIdempotencyStore(pool), env.clk, "createSchedule"),
	}
	env.handler = httpapi.NewHandler(deps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, api, deps, routes)
	})
	return env
}

// post는 POST /v1/schedules를 보냅니다. key나 account가 빈 문자열이면 그 헤더를 보내지 않습니다.
func (e *idempotencyEnv) post(t *testing.T, key, accountName, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := newBodyRequest(t, http.MethodPost, schedulesTarget, contentTypeJSON, body)
	if key != "" {
		req.Header.Set("Idempotency-Key", key)
	}
	if accountName != "" {
		req.Header.Set("X-Test-Account", accountName)
	}
	return serve(e.handler, req)
}

func (e *idempotencyEnv) count(t *testing.T, table string) int {
	t.Helper()
	var n int
	require.NoError(t, e.pool.QueryRow(t.Context(), "SELECT count(*) FROM "+table).Scan(&n))
	return n
}

func TestIdempotency_ReplaysSameResponse(t *testing.T) {
	env := newIdempotencyEnv(t)

	first := env.post(t, "key-1", "", createBody)
	second := env.post(t, "key-1", "", createBody)

	require.Equal(t, http.StatusCreated, first.Code, first.Body.String())
	assert.Equal(t, first.Code, second.Code)
	assert.Equal(t, first.Body.String(), second.Body.String())
	assert.NotEmpty(t, first.Header().Get("Location"))
	assert.Equal(t, first.Header().Get("Location"), second.Header().Get("Location"))
	assert.Equal(t, first.Header().Get("Content-Type"), second.Header().Get("Content-Type"))
	assert.Equal(t, 1, env.count(t, "schedules"))
}

func TestIdempotency_DifferentBodyIsMismatch(t *testing.T) {
	env := newIdempotencyEnv(t)
	require.Equal(t, http.StatusCreated, env.post(t, "key-1", "", createBody).Code)

	rec := env.post(t, "key-1", "", otherBody)

	require.Equal(t, http.StatusUnprocessableEntity, rec.Code, rec.Body.String())
	assert.Equal(t, "idempotency.mismatch", decodeProblem(t, rec).Code)
	assert.Equal(t, 1, env.count(t, "schedules"))
}

func TestIdempotency_InProgress(t *testing.T) {
	env := newIdempotencyEnv(t)
	env.service.entered = make(chan struct{})
	env.service.release = make(chan struct{})

	firstDone := make(chan *httptest.ResponseRecorder, 1)
	go func() { firstDone <- env.post(t, "key-1", "", createBody) }()
	<-env.service.entered

	rec := env.post(t, "key-1", "", createBody)
	require.Equal(t, http.StatusConflict, rec.Code, rec.Body.String())
	assert.Equal(t, "idempotency.in_progress", decodeProblem(t, rec).Code)

	close(env.service.release)
	first := <-firstDone
	require.Equal(t, http.StatusCreated, first.Code, first.Body.String())

	// 첫 요청이 끝나면 같은 키는 저장한 응답을 돌려줍니다.
	replay := env.post(t, "key-1", "", createBody)
	assert.Equal(t, http.StatusCreated, replay.Code)
	assert.Equal(t, first.Body.String(), replay.Body.String())
	assert.Equal(t, 1, env.count(t, "schedules"))
}

func TestIdempotency_FailureReleasesKey(t *testing.T) {
	env := newIdempotencyEnv(t)

	failed := env.post(t, "key-1", "", inconsistentBody)
	require.Equal(t, http.StatusUnprocessableEntity, failed.Code, failed.Body.String())
	assert.Equal(t, 0, env.count(t, "idempotency_keys"))

	// 같은 키로 고친 본문을 다시 보내면 새 요청으로 처리합니다.
	retried := env.post(t, "key-1", "", createBody)
	require.Equal(t, http.StatusCreated, retried.Code, retried.Body.String())
	assert.Equal(t, 1, env.count(t, "schedules"))
}

func TestIdempotency_PanicReleasesKey(t *testing.T) {
	env := newIdempotencyEnv(t)
	env.service.panics = true

	rec := env.post(t, "key-1", "", createBody)
	require.Equal(t, http.StatusInternalServerError, rec.Code)
	assert.Equal(t, 0, env.count(t, "idempotency_keys"))

	env.service.panics = false
	require.Equal(t, http.StatusCreated, env.post(t, "key-1", "", createBody).Code)
}

func TestIdempotency_ExpiresAfterTTL(t *testing.T) {
	env := newIdempotencyEnv(t)
	first := env.post(t, "key-1", "", createBody)
	require.Equal(t, http.StatusCreated, first.Code)

	env.clk.Advance(httpapi.IdempotencyTTL - time.Second)
	assert.Equal(t, first.Body.String(), env.post(t, "key-1", "", createBody).Body.String(), "24시간 안에는 같은 응답")
	assert.Equal(t, 1, env.count(t, "schedules"))

	env.clk.Advance(time.Second)
	again := env.post(t, "key-1", "", createBody)
	require.Equal(t, http.StatusCreated, again.Code)
	assert.NotEqual(t, first.Body.String(), again.Body.String(), "24시간이 지나면 새 요청")
	assert.Equal(t, 2, env.count(t, "schedules"))
	assert.Equal(t, 1, env.count(t, "idempotency_keys"))

	// 덮어쓴 행은 새 응답을 재생합니다.
	assert.Equal(t, again.Body.String(), env.post(t, "key-1", "", createBody).Body.String())
}

func TestIdempotency_KeysAreScopedPerAccount(t *testing.T) {
	env := newIdempotencyEnv(t)

	a := env.post(t, "key-1", "a", createBody)
	b := env.post(t, "key-1", "b", otherBody)

	require.Equal(t, http.StatusCreated, a.Code, a.Body.String())
	require.Equal(t, http.StatusCreated, b.Code, b.Body.String())
	assert.NotEqual(t, a.Body.String(), b.Body.String())
	assert.Equal(t, 2, env.count(t, "schedules"))
}

func TestIdempotency_WithoutKeyTouchesNothing(t *testing.T) {
	env := newIdempotencyEnv(t)

	first := env.post(t, "", "", createBody)
	second := env.post(t, "", "", createBody)

	require.Equal(t, http.StatusCreated, first.Code)
	require.Equal(t, http.StatusCreated, second.Code)
	assert.Equal(t, 2, env.count(t, "schedules"))
	assert.Equal(t, 0, env.count(t, "idempotency_keys"))
}

func TestIdempotency_SkipsOtherOperations(t *testing.T) {
	env := newIdempotencyEnv(t)
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, schedulesTarget+"?from=2026-10-01&to=2026-10-31", nil)
	req.Header.Set("Idempotency-Key", "key-1")

	rec := serve(env.handler, req)

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, 0, env.count(t, "idempotency_keys"))
}

func TestIdempotency_InvalidRequestTouchesNothing(t *testing.T) {
	env := newIdempotencyEnv(t)

	rec := env.post(t, "key-1", "", `{"title":`)

	require.Equal(t, http.StatusBadRequest, rec.Code, rec.Body.String())
	assert.Equal(t, 0, env.count(t, "idempotency_keys"))
}
