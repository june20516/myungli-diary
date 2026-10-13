package httpapi

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
)

// errTestSentinel은 domainErrors 표 동작을 확인하는 테스트 전용 sentinel입니다.
var errTestSentinel = errors.New("테스트 sentinel")

// serveHandlerError는 writeHandlerError의 응답과 로그를 돌려줍니다.
func serveHandlerError(t *testing.T, err error) (*httptest.ResponseRecorder, problem.Problem, string) {
	t.Helper()
	logs := &bytes.Buffer{}
	deps := Deps{Logger: slog.New(slog.NewTextHandler(logs, nil))}
	rec := httptest.NewRecorder()
	writeHandlerError(deps, rec, httptest.NewRequest(http.MethodGet, "/x", nil), err)
	var p problem.Problem
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &p))
	return rec, p, logs.String()
}

func TestWriteHandlerError_ExplicitErrorKeepsStatusCodeAndFields(t *testing.T) {
	fields := []problem.FieldError{{Field: "/documents/0/version", Code: "consent.version_mismatch"}}
	rec, p, _ := serveHandlerError(t, fmt.Errorf("wrap: %w", &Error{
		Status: http.StatusUnprocessableEntity, Code: "consent.version_mismatch", Title: "Consent version mismatch", Errors: fields,
	}))

	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	assert.Equal(t, "consent.version_mismatch", p.Code)
	assert.Equal(t, "Consent version mismatch", p.Title)
	assert.Equal(t, fields, p.Errors)
	assert.Empty(t, rec.Header().Get("WWW-Authenticate"))
}

func TestWriteHandlerError_BearerChallengeAddsHeader(t *testing.T) {
	rec, p, _ := serveHandlerError(t, &Error{
		Status: http.StatusUnauthorized, Code: "auth.token_invalid", Title: "Token invalid", BearerChallenge: true,
	})

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
	assert.Equal(t, "auth.token_invalid", p.Code)
	assert.Equal(t, `Bearer error="invalid_token"`, rec.Header().Get("WWW-Authenticate"))
}

func TestWriteHandlerError_DomainSentinelIsMapped(t *testing.T) {
	original := domainErrors
	domainErrors = append([]domainError{{target: errTestSentinel, status: http.StatusUnauthorized, code: "auth.test", title: "Test"}}, original...)
	t.Cleanup(func() { domainErrors = original })

	rec, p, _ := serveHandlerError(t, fmt.Errorf("x: %w", errTestSentinel))

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
	assert.Equal(t, "auth.test", p.Code)
	assert.Empty(t, rec.Header().Get("WWW-Authenticate"))
}

func TestWriteHandlerError_ConnectErrorIs503(t *testing.T) {
	rec, p, logs := serveHandlerError(t, fmt.Errorf("acquire: %w", &pgconn.ConnectError{}))

	assert.Equal(t, http.StatusServiceUnavailable, rec.Code)
	assert.Equal(t, "service.unavailable", p.Code)
	assert.NotEmpty(t, logs)
}

func TestWriteHandlerError_UnknownErrorIs500AndLogsType(t *testing.T) {
	rec, p, logs := serveHandlerError(t, errors.New("boom"))

	assert.Equal(t, http.StatusInternalServerError, rec.Code)
	assert.Equal(t, "internal", p.Code)
	assert.Contains(t, logs, "boom")
	assert.Contains(t, logs, "*errors.errorString")
}

func TestWriteHandlerError_PgErrorLogOmitsDetail(t *testing.T) {
	pgErr := &pgconn.PgError{
		Code: "23505", ConstraintName: "c", TableName: "t",
		Message: "msg-secret", Detail: "Key (subject)=(12345)", Where: "where-secret",
	}
	rec, p, logs := serveHandlerError(t, fmt.Errorf("insert: %w", pgErr))

	assert.Equal(t, http.StatusInternalServerError, rec.Code)
	assert.Equal(t, "internal", p.Code)
	assert.Contains(t, logs, "23505")
	assert.Contains(t, logs, "constraint=c")
	assert.Contains(t, logs, "table=t")
	for _, secret := range []string{"12345", "msg-secret", "where-secret"} {
		assert.False(t, strings.Contains(logs, secret), "로그에 %q 가 있으면 안 됩니다", secret)
	}
}
