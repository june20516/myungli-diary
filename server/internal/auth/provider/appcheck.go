package provider

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"slices"

	"github.com/coreos/go-oidc/v3/oidc"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// App Check 설정의 기본 값과 claim 접두사입니다.
const (
	DefaultAppCheckJWKSURL = "https://firebaseappcheck.googleapis.com/v1/jwks"

	appCheckIssuerPrefix   = "https://firebaseappcheck.googleapis.com/"
	appCheckAudiencePrefix = "projects/"
)

// AppCheckConfig는 Firebase App Check 토큰 검증 설정입니다.
type AppCheckConfig struct {
	// ProjectNumber는 Firebase 프로젝트 번호(숫자)입니다. iss와 aud를 이 값으로 확인합니다.
	ProjectNumber string
	// HTTPClient는 JWKS 조회에 쓰는 client입니다. nil이면 새 기본 client를 씁니다.
	HTTPClient *http.Client
	// JWKSURL이 비면 운영 URL(DefaultAppCheckJWKSURL)을 씁니다.
	JWKSURL string
	// Clock은 exp 판정에 쓰는 시계입니다. nil이면 clock.System을 씁니다.
	Clock clock.Clock
}

// AppCheck은 Firebase App Check 토큰을 검증합니다. 여러 고루틴에서 함께 써도 안전합니다.
// 카카오·Apple과 같은 JWKS 조회·장애 분류(oidc.go)를 씁니다.
type AppCheck struct {
	verifier *oidc.IDTokenVerifier
	audience string
}

// NewAppCheck는 cfg로 AppCheck을 만듭니다. ProjectNumber가 비었거나 숫자만이 아니면 오류입니다.
func NewAppCheck(cfg AppCheckConfig) (*AppCheck, error) {
	if !isDigits(cfg.ProjectNumber) {
		return nil, errors.New("AppCheck 설정: ProjectNumber는 숫자만으로 된 프로젝트 번호여야 합니다")
	}
	clk := orDefaultClock(cfg.Clock)
	keySet := newKeySet(orDefaultClient(cfg.HTTPClient), orDefault(cfg.JWKSURL, DefaultAppCheckJWKSURL))
	// App Check 토큰의 aud는 배열이고 client id가 없어 go-oidc의 aud 검사는 끄고 Verify에서 직접 확인합니다.
	verifier := oidc.NewVerifier(appCheckIssuerPrefix+cfg.ProjectNumber, keySet, &oidc.Config{
		SkipClientIDCheck:    true,
		SupportedSigningAlgs: []string{oidc.RS256},
		Now:                  clk.Now,
	})
	return &AppCheck{verifier: verifier, audience: appCheckAudiencePrefix + cfg.ProjectNumber}, nil
}

// Verify는 App Check 토큰의 RS256 서명, iss, exp, aud(projects/<프로젝트 번호> 포함)를 확인합니다.
// 토큰이 올바르지 않으면 ErrTokenInvalid, JWKS를 받아 오지 못하면 ErrUnavailable로 감쌉니다.
func (a *AppCheck) Verify(ctx context.Context, token string) error {
	idToken, err := verifyIDTokenClaims(ctx, a.verifier, "App Check 토큰", token)
	if err != nil {
		return err
	}
	if !slices.Contains(idToken.Audience, a.audience) {
		return fmt.Errorf("%w: App Check 토큰: aud에 프로젝트 번호가 없습니다", ErrTokenInvalid)
	}
	return nil
}

// isDigits는 value가 비어 있지 않은 ASCII 숫자열인지 검사합니다.
// platform/config의 LoadAppCheck도 같은 기준(ASCII 숫자만)으로 FIREBASE_PROJECT_NUMBER를 검사합니다.
// config는 도메인 패키지를 import하지 않는 관례라 코드를 공유하지 않으니, 기준을 바꾸면 양쪽을 함께 고칩니다.
func isDigits(value string) bool {
	if value == "" {
		return false
	}
	for _, r := range value {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}
