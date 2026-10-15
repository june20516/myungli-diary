package httpapi_test

import (
	"context"
	"net/http"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth/authdb"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// switchableCharts는 실패를 켜고 끌 수 있는 ChartChecker 대역입니다.
type switchableCharts struct {
	mu    sync.Mutex
	err   error
	calls int
}

func (c *switchableCharts) Chart(context.Context, profile.Birth, profile.LocalDate) (*enginev1.ChartResponse, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.calls++
	if c.err != nil {
		return nil, c.err
	}
	return &enginev1.ChartResponse{}, nil
}

func (c *switchableCharts) set(err error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.err, c.calls = err, 0
}

func (c *switchableCharts) callCount() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.calls
}

// 엔진이 죽어도 출생 정보를 안 바꾸는 PATCH는 200이고, 바꾸는 PATCH만 503입니다(실제 profile.Service + DB).
func TestUpdateProfile_EngineDownOnlyBlocksBirthChange(t *testing.T) {
	pool := dbtest.New(t)
	clk := clocktest.New(handlerNow)
	require.NoError(t, authdb.New(pool).CreateAccount(t.Context(), authdb.CreateAccountParams{ID: fixedAccountID, LastActiveAt: handlerNow}))
	charts := &switchableCharts{}
	handler, spec := newHandlerAPI(t, &httpapi.API{Profiles: profile.NewService(pool, charts, clk)})

	create := newBodyRequest(t, http.MethodPut, "/v1/me/profile", contentTypeJSON, profileWithNotificationTime("07:05"))
	rec := serve(handler, create)
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, create, rec)

	charts.set(engine.ErrUnavailable)

	tz := newBodyRequest(t, http.MethodPatch, "/v1/me/profile", contentTypeMergePatch, `{"currentTimezone":"Asia/Tokyo"}`)
	rec = serve(handler, tz)
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectContractResponse(t, spec, tz, rec)
	assert.Zero(t, charts.callCount(), "출생 정보가 안 바뀌면 엔진을 부르지 않습니다")

	otherBirth := `{"birth":{"calendar":"solar","date":{"year":1991,"month":5,"day":17},"isLeapMonth":false,` +
		`"time":{"status":"known","value":"07:30"},"gender":"female","timezone":"Asia/Seoul","place":{"status":"not_asked"}}}`
	birth := newBodyRequest(t, http.MethodPatch, "/v1/me/profile", contentTypeMergePatch, otherBirth)
	rec = serve(handler, birth)
	require.Equal(t, http.StatusServiceUnavailable, rec.Code, rec.Body.String())
	assert.Equal(t, "5", rec.Header().Get("Retry-After"))
	assert.Equal(t, "engine.unavailable", decodeProblem(t, rec).Code)
	expectContractResponse(t, spec, birth, rec)
}
