package httpapi

import (
	"context"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// healthPingTimeout은 헬스 체크가 DB 응답을 기다리는 최대 시간입니다.
const healthPingTimeout = time.Second

// AuthService는 핸들러가 쓰는 인증 서비스입니다. *auth.Service가 만족합니다.
type AuthService interface {
	LoginKakao(ctx context.Context, idToken, rawNonce string) (auth.LoginResult, error)
	LoginApple(ctx context.Context, idToken, authorizationCode, rawNonce string, client provider.AppleClient) (auth.LoginResult, error)
	Refresh(ctx context.Context, rawRefresh string) (auth.TokenPair, error)
	Logout(ctx context.Context, accountID uuid.UUID, rawRefresh string) error
}

// AccountService는 핸들러가 쓰는 계정 서비스입니다. *account.Service가 만족합니다.
type AccountService interface {
	Me(ctx context.Context, id uuid.UUID) (account.Me, error)
	AgreeConsents(ctx context.Context, id uuid.UUID, docs []account.ConsentDocument) error
	RequestDeletion(ctx context.Context, id uuid.UUID) (time.Time, error)
}

// API는 gen.StrictServerInterface 구현입니다. 아직 구현하지 않은 operation은 Unimplemented가 501로 답합니다.
type API struct {
	Unimplemented

	Auth     AuthService
	Accounts AccountService
	// DB는 헬스 체크의 ping에 씁니다.
	DB *pgxpool.Pool
	// AppleCallbackDeepLink는 Apple 웹 흐름 콜백이 앱으로 돌려보낼 deep link입니다.
	AppleCallbackDeepLink string
}

var _ gen.StrictServerInterface = (*API)(nil)

// GetHealth는 DB ping이 1초 안에 성공하면 200, 아니면 503 service.unavailable입니다.
// DB가 설정되지 않은 것도 조립 실수이므로 503으로 드러냅니다.
func (a *API) GetHealth(ctx context.Context, _ gen.GetHealthRequestObject) (gen.GetHealthResponseObject, error) {
	if a.DB == nil {
		return nil, &Error{Status: http.StatusServiceUnavailable, Code: codeServiceUnavailable, Title: "Service unavailable"}
	}
	pingCtx, cancel := context.WithTimeout(ctx, healthPingTimeout)
	defer cancel()
	if err := a.DB.Ping(pingCtx); err != nil {
		return nil, &Error{Status: http.StatusServiceUnavailable, Code: codeServiceUnavailable, Title: "Service unavailable"}
	}
	return gen.GetHealth200JSONResponse{Status: gen.Ok}, nil
}
