package cli

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/account"
	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/secretbox"
	"github.com/june20516/myungli-diary/server/internal/auth/token"
	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/merge"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/platform/config"
	"github.com/june20516/myungli-diary/server/internal/platform/logging"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/internal/preview"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/internal/ratelimit"
	"github.com/june20516/myungli-diary/server/internal/schedule"
	"github.com/june20516/myungli-diary/server/legal"
)

const (
	// versionRefreshInterval은 엔진 ruleset_version을 다시 읽는 주기입니다.
	versionRefreshInterval = 10 * time.Minute

	readHeaderTimeout = 10 * time.Second
	// readTimeout은 본문까지 읽는 상한입니다. 본문 상한(1 MiB)을 느리게 보내는 연결이 오래 붙어 있지 않게 합니다.
	readTimeout = 30 * time.Second
	// idleTimeout은 keep-alive 연결을 다음 요청 없이 유지하는 상한입니다.
	idleTimeout = 120 * time.Second
	// shutdownTimeout은 plan의 "최대 10초"보다 짧게 잡습니다. Cloud Run은 SIGTERM 뒤 10초에
	// SIGKILL을 보내므로, 남은 연결 강제 종료와 종료 로그를 남길 여유 2초를 둡니다.
	shutdownTimeout = 8 * time.Second
	// providerHTTPTimeout은 외부 제공자(카카오·Apple) 호출 한 번의 상한입니다. provider도 호출마다 같은 deadline을 둡니다.
	providerHTTPTimeout = 5 * time.Second
	// publicRateLimit은 비로그인 계산 operation의 클라이언트 IP별 분당 허용 횟수입니다.
	publicRateLimit = 30
)

// runServe는 HTTP 서버를 시작하고 ctx가 취소되면 처리 중인 요청을 마친 뒤 종료합니다.
// 시작할 때 DB·인증·엔진 설정을 검사하고 DB에 연결하며, 하나라도 실패하면 서버를 열지 않고 끝납니다.
// 엔진 연결은 lazy이고 시작 때 GetInfo가 실패해도 시작은 계속합니다(ruleset_version은 감시 goroutine이 채웁니다).
func runServe(ctx context.Context, args []string, getenv func(string) string, _, stderr io.Writer) error {
	if len(args) != 0 {
		return usageErrorf("usage: server serve")
	}
	cfg, err := config.Load(getenv)
	if err != nil {
		return err
	}
	if err := cfg.RequireDatabase(); err != nil {
		return err
	}
	authCfg, err := config.LoadAuth(getenv)
	if err != nil {
		return err
	}
	// 키 형식 오류는 DB에 연결하기 전에 드러냅니다. 오류에는 변수 이름만 담고 값은 담지 않습니다.
	settings, err := parseAuthSettings(authCfg)
	if err != nil {
		return err
	}
	engineCfg, err := config.LoadEngine(getenv)
	if err != nil {
		return err
	}
	// staging 빌드에서만 TEST_LOGIN_SECRET을 읽고 검사합니다(prod 빌드는 아무것도 읽지 않음, S24).
	testLogin, err := loadTestLogin(getenv)
	if err != nil {
		return err
	}
	appCheckCfg, err := config.LoadAppCheck(getenv)
	if err != nil {
		return err
	}
	proxyHops, err := config.LoadTrustedProxyHops(getenv)
	if err != nil {
		return err
	}
	appVersions, err := config.LoadAppVersions(getenv)
	if err != nil {
		return err
	}
	billingCfg, err := config.LoadBilling(getenv)
	if err != nil {
		return err
	}
	logger := logging.New(stderr, cfg.LogLevel, cfg.GCPProjectID)

	// 연결 문자열에는 비밀번호가 있을 수 있어 로그에는 오류만 남기고 주소는 남기지 않습니다.
	pool, err := postgres.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.ErrorContext(ctx, "DB 연결 실패", "error", err)
		return &loggedError{err: err}
	}
	defer pool.Close()

	engineClient, err := engine.NewClient(engine.ClientConfig{Addr: engineCfg.Addr, Audience: engineCfg.Audience})
	if err != nil {
		logger.ErrorContext(ctx, "엔진 연결 생성 실패", "error", err)
		return &loggedError{err: err}
	}
	// 버전 감시는 runCtx로 돌리고, 어떤 경로로 반환하든 연결을 닫기 전에 멈추고 끝나기를 기다립니다.
	runCtx, cancelRun := context.WithCancel(ctx)
	versions := engine.NewVersions(engineClient, logger)
	var watchers sync.WaitGroup
	watchers.Go(func() { versions.Run(runCtx, versionRefreshInterval) })
	defer func() {
		cancelRun()
		watchers.Wait()
		if err := engineClient.Close(); err != nil {
			logger.WarnContext(context.WithoutCancel(ctx), "엔진 연결 닫기 실패", "error", err)
		}
	}()
	fortuneService := fortune.NewService(engineClient, versions, fortune.NewPostgresCache(pool), logger)
	contents := content.NewStore(pool, clock.System{}, logger)
	// 같은 권한 저장소 하나가 근거 열람 판정(fortune)과 getMe·getEntitlements·listPurchases 응답에 쓰입니다.
	// 구매 목록이 기간 상품을 알아보도록 결제 동기화(newBillingParts)와 같은 상품 목록을 넘깁니다.
	entitlements := billing.NewStore(pool, clock.System{}, billing.AdFreeCatalog(billingCfg.AdFreeProductIDs))
	readings := newReadings(contents, fortuneService, entitlements, logger, clock.System{})

	// 외부 제공자 호출(로그인 제공자·App Check)이 이 client 하나를 나눠 씁니다.
	providerHTTP := newProviderHTTPClient()

	// 프로젝트 번호가 없으면(APP_ENV=local) 검증기를 두지 않아 App Check operation이 503입니다.
	var appCheck httpapi.AppCheckVerifier
	if appCheckCfg.ProjectNumber != "" {
		verifier, err := provider.NewAppCheck(provider.AppCheckConfig{
			ProjectNumber: appCheckCfg.ProjectNumber,
			HTTPClient:    providerHTTP,
			Clock:         clock.System{},
		})
		if err != nil {
			logger.ErrorContext(ctx, "App Check 검증기 생성 실패", "error", err)
			return &loggedError{err: err}
		}
		appCheck = verifier
	}

	billingParts := newBillingParts(billingCfg, pool, providerHTTP, billingURLs{}, clock.System{}, logger)

	handler, err := newServer(settings, serverDeps{
		Pool:         pool,
		Charts:       fortuneService,
		Lunar:        engineClient,
		BirthHour:    engineClient,
		Previews:     readings,
		Readings:     readings,
		Days:         readings,
		Contents:     contents,
		Entitlements: entitlements,
		Ledger:       entitlements,
		Billing:      billingParts,
		Logger:       logger,
		Clock:        clock.System{},
		HTTP:         providerHTTP,
		// 비워 두면 provider가 실제 제공자 주소를 씁니다.
		Providers: providerURLs{},
		TestLogin: testLogin,
		AppCheck:  appCheck,
		ProxyHops: proxyHops,
		AppConfig: httpapi.AppConfig{MinIOS: appVersions.MinIOS, MinAndroid: appVersions.MinAndroid},
	})
	if err != nil {
		logger.ErrorContext(ctx, "서버 조립 실패", "error", err)
		return &loggedError{err: err}
	}

	var listenConfig net.ListenConfig
	listener, err := listenConfig.Listen(ctx, "tcp", net.JoinHostPort("", strconv.Itoa(cfg.Port)))
	if err != nil {
		logger.ErrorContext(ctx, "포트 열기 실패", "port", cfg.Port, "error", err)
		return &loggedError{err: err}
	}

	// 엔진 주소는 남기지 않고 연결 방식만 남깁니다.
	engineMode := "h2c"
	if engineCfg.Audience != "" {
		engineMode = "TLS"
	}
	logger.InfoContext(ctx, "서버 시작", "port", cfg.Port, "env", cfg.Env, "engine", engineMode)
	if err := serveHTTP(ctx, listener, handler, logger); err != nil {
		logger.ErrorContext(ctx, "서버 종료 오류", "error", err)
		return &loggedError{err: err}
	}
	logger.InfoContext(ctx, "서버 종료")
	return nil
}

// authSettings는 AuthConfig의 키를 파싱하고 값을 검증한 결과입니다.
// 문자열 설정(제공자 ID 등)은 config에 그대로 두고, 파싱이 필요한 키만 따로 담습니다.
type authSettings struct {
	config config.AuthConfig
	// signing은 access token 발급 키이고, previousSigning은 키 교체 중 검증에만 쓰는 이전 키입니다(없으면 비어 있음).
	signing         token.SigningKey
	previousSigning []token.SigningKey
	// box는 제공자 토큰(Apple refresh token)을 암호화·복호화합니다.
	box *secretbox.Box
	// applePrivate는 Apple client secret(ES256 JWT)을 서명하는 .p8 키입니다.
	applePrivate *ecdsa.PrivateKey
	// appLink는 Apple 웹 콜백의 redirect 주소, 안내 페이지, assetlinks.json에 쓰는 Android App Link 설정입니다.
	appLink httpapi.AppLinkConfig
}

// parseAuthSettings는 키를 파싱하고 App Link 설정을 검증합니다. 실패하면 문제가 된 환경 변수 이름을 담은 오류를 돌려줍니다.
// 오류 문구에는 설정 값을 넣지 않습니다(url.Parse 오류처럼 값을 담는 오류는 감싸지 않습니다).
func parseAuthSettings(cfg config.AuthConfig) (authSettings, error) {
	signing, err := token.ParseSigningKey(cfg.JWTKeyID, cfg.JWTKeyPEM)
	if err != nil {
		return authSettings{}, fmt.Errorf("JWT_SIGNING_KEY: %w", err)
	}
	var previousSigning []token.SigningKey
	if cfg.JWTPreviousKeyID != "" {
		previous, err := token.ParseSigningKey(cfg.JWTPreviousKeyID, cfg.JWTPreviousKeyPEM)
		if err != nil {
			return authSettings{}, fmt.Errorf("JWT_PREVIOUS_KEY: %w", err)
		}
		previousSigning = append(previousSigning, previous)
	}

	box, err := parseTokenBox(cfg.TokenKeyID, cfg.TokenKey, cfg.TokenPreviousKeyID, cfg.TokenPreviousKey)
	if err != nil {
		return authSettings{}, err
	}

	appleKey, err := parseApplePrivateKey(cfg.AppleKeyID, cfg.ApplePrivateKeyPEM)
	if err != nil {
		return authSettings{}, err
	}

	appLink, err := parseAppLink(cfg)
	if err != nil {
		return authSettings{}, err
	}

	return authSettings{
		config:          cfg,
		signing:         signing,
		previousSigning: previousSigning,
		box:             box,
		applePrivate:    appleKey.Private,
		appLink:         appLink,
	}, nil
}

// parseTokenBox는 제공자 token 암호화 키(와 교체 중인 이전 키)로 secretbox를 만듭니다. 오류에는 변수 이름만 담습니다.
func parseTokenBox(keyID, key, previousKeyID, previousKey string) (*secretbox.Box, error) {
	boxKey, err := secretbox.ParseKey(keyID, key)
	if err != nil {
		return nil, fmt.Errorf("TOKEN_ENCRYPTION_KEY: %w", err)
	}
	var previousBoxKeys []secretbox.Key
	if previousKeyID != "" {
		previous, err := secretbox.ParseKey(previousKeyID, previousKey)
		if err != nil {
			return nil, fmt.Errorf("TOKEN_PREVIOUS_KEY: %w", err)
		}
		previousBoxKeys = append(previousBoxKeys, previous)
	}
	box, err := secretbox.New(boxKey, previousBoxKeys)
	if err != nil {
		return nil, fmt.Errorf("TOKEN_ENCRYPTION_KEY·TOKEN_PREVIOUS_KEY: %w", err)
	}
	return box, nil
}

// parseApplePrivateKey는 Apple .p8 키를 읽습니다. .p8도 PKCS8 PEM의 P-256 EC 키라 access token 서명 키와 같은 규칙입니다.
func parseApplePrivateKey(keyID, pem string) (token.SigningKey, error) {
	key, err := token.ParseSigningKey(keyID, pem)
	if err != nil {
		return token.SigningKey{}, fmt.Errorf("APPLE_PRIVATE_KEY: %w", err)
	}
	return key, nil
}

// androidPackagePattern은 Android 패키지 이름 형식입니다. 점으로 나눈 조각이 둘 이상이고,
// 조각마다 영문자로 시작해 영문자·숫자·밑줄만 씁니다.
var androidPackagePattern = regexp.MustCompile(`^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$`)

// certSHA256Pattern은 서명 인증서 SHA-256 지문 형식입니다. 32바이트를 대문자 hex 두 자리씩 콜론으로 잇습니다.
var certSHA256Pattern = regexp.MustCompile(`^[0-9A-F]{2}(:[0-9A-F]{2}){31}$`)

// parseAppLink는 Android App Link 설정을 검증해 httpapi.AppLinkConfig로 만듭니다.
// 오류 문구에는 변수 이름만 담고 값은 담지 않습니다.
func parseAppLink(cfg config.AuthConfig) (httpapi.AppLinkConfig, error) {
	// Apple 웹 콜백이 이 주소의 /auth/apple로 redirect하므로 path가 없어야 하고, App Link는 https만 됩니다.
	base, ok := parseHTTPSURL(cfg.AppLinkBase)
	if !ok || (base.Path != "" && base.Path != "/") || base.RawQuery != "" || base.Fragment != "" || base.User != nil {
		return httpapi.AppLinkConfig{}, errors.New("APP_LINK_BASE는 path·query가 없는 https URL이어야 합니다")
	}
	if !androidPackagePattern.MatchString(cfg.AndroidAppPackage) {
		return httpapi.AppLinkConfig{}, errors.New("ANDROID_APP_PACKAGE는 Android 패키지 이름 형식(예 app.myungli)이어야 합니다")
	}
	var certs []string
	for _, cert := range strings.Split(cfg.AndroidCertSHA256, ",") {
		cert = strings.TrimSpace(cert)
		if !certSHA256Pattern.MatchString(cert) {
			return httpapi.AppLinkConfig{}, errors.New("ANDROID_CERT_SHA256은 쉼표로 나눈 SHA-256 지문(AA:BB:… 대문자 32바이트)이어야 합니다")
		}
		certs = append(certs, cert)
	}
	if _, ok := parseHTTPSURL(cfg.AndroidStoreURL); !ok {
		return httpapi.AppLinkConfig{}, errors.New("ANDROID_STORE_URL은 host가 있는 https URL이어야 합니다")
	}
	return httpapi.AppLinkConfig{
		Base:       base,
		Package:    cfg.AndroidAppPackage,
		CertSHA256: certs,
		StoreURL:   cfg.AndroidStoreURL,
	}, nil
}

// parseHTTPSURL은 raw가 host가 있는 https URL이면 해석 결과를 돌려줍니다.
// url.Parse 오류는 값을 담으므로 감싸지 않고 성공 여부만 돌려줍니다.
func parseHTTPSURL(raw string) (*url.URL, bool) {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.Host == "" {
		return nil, false
	}
	return u, true
}

// newProviderHTTPClient는 외부 제공자 호출에 쓰는 운영용 http.Client를 만듭니다.
// 호출 한 번의 상한(providerHTTPTimeout)을 client에도 둬, provider의 호출별 deadline이 빠진 경로도 묶입니다.
func newProviderHTTPClient() *http.Client {
	return &http.Client{Timeout: providerHTTPTimeout}
}

// providerURLs는 제공자 엔드포인트 주소입니다. 빈 값은 provider의 기본값(실제 제공자 주소)을 씁니다.
// 테스트는 providertest 대역 주소를 넣습니다.
type providerURLs struct {
	KakaoJWKS, KakaoUnlink             string
	AppleJWKS, AppleToken, AppleRevoke string
	LineJWKS, GoogleJWKS               string
}

// serverDeps는 newServer가 바깥에서 받는 의존성입니다.
type serverDeps struct {
	// Pool은 서비스와 헬스 체크가 쓰는 DB 연결입니다.
	Pool *pgxpool.Pool
	// Charts는 프로필 저장 때 출생 정보를 엔진으로 검증하는 의존성입니다(fortune.Service).
	Charts profile.ChartChecker
	// Lunar는 음력 변환 operation이 부르는 엔진입니다(engine.Client).
	Lunar httpapi.LunarConverter
	// BirthHour는 시진 확인 operation이 부르는 엔진입니다(engine.Client).
	BirthHour httpapi.BirthHourChecker
	// Previews는 비로그인 미리보기의 화면 묶음입니다(fortune.Views). 비어 있으면 미리보기는 503입니다.
	Previews httpapi.PreviewService
	// AppCheck은 비로그인 operation의 App Check 토큰 검증기입니다(provider.AppCheck). 비어 있으면 그 operation은 503입니다.
	AppCheck httpapi.AppCheckVerifier
	// ProxyHops는 클라이언트 IP를 X-Forwarded-For 오른쪽에서 몇 번째로 볼지 정합니다(TRUSTED_PROXY_HOPS).
	ProxyHops int
	// AppConfig는 getAppConfig가 돌려주는 최소 앱 버전입니다.
	AppConfig httpapi.AppConfig
	// Readings는 운세 operation의 화면 묶음입니다(fortune.Views). 비어 있으면 운세 operation은 503입니다.
	Readings httpapi.Readings
	// Contents는 용어 사전과 문장 반응의 콘텐츠 저장소입니다(content.Store). 비어 있으면 그 operation과 getDaily는 503입니다.
	Contents httpapi.Contents
	// Entitlements는 getMe·getEntitlements가 쓰는 권한 판정입니다(billing.Store). 비어 있으면 getMe·getEntitlements는 503입니다.
	Entitlements httpapi.EntitlementService
	// Ledger는 listPurchases가 쓰는 구매 장부 조회입니다(billing.Store). 비어 있으면 listPurchases는 503입니다.
	Ledger httpapi.PurchaseLister
	// Billing은 구매 복원·RevenueCat webhook·보상형 광고 콜백의 의존성입니다. 필드가 비면 그 operation은 각자 정한 오류로 답합니다.
	Billing billingParts
	// Days는 일기를 처음 쓸 때 같이 적는 그날 엔진 결과의 기록을 만듭니다(fortune.Views). 비어 있으면 일기 operation은 503입니다.
	Days   diary.Days
	Logger *slog.Logger
	Clock  clock.Clock
	// HTTP는 모든 외부 제공자 호출이 나눠 쓰는 client입니다.
	HTTP      *http.Client
	Providers providerURLs
	// TestLogin은 staging 테스트 로그인 설정입니다(S24). prod 빌드에서는 빈 타입이고, 비어 있으면 켜지 않습니다.
	TestLogin testLoginSettings
}

// billingURLs는 결제 외부 서비스의 주소입니다. 빈 값은 실제 주소를 씁니다. 테스트는 httptest 대역 주소를 넣습니다.
type billingURLs struct {
	RevenueCat string
	AdMobKeys  string
}

// billingParts는 결제 관련 operation의 의존성 묶음입니다.
// 필드는 인터페이스라, 값이 없을 때는 nil *T를 넣지 않고 비워 둬야 핸들러의 nil 검사가 동작합니다.
type billingParts struct {
	Purchases      httpapi.PurchaseRestorer
	Webhooks       httpapi.RevenueCatWebhooks
	RewardVerifier httpapi.RewardVerifier
	Rewards        httpapi.RewardGranter
	// Sync는 계정 합치기가 합치기 전에 B의 결제를 동기화하는 데 씁니다. 결제 설정이 없으면 비어 있습니다.
	Sync merge.PurchaseSyncer
}

// newBillingParts는 결제 의존성을 조립합니다.
// 구매 복원과 webhook은 RevenueCat 설정이 모두 있을 때만 조립하고(없으면 APP_ENV=local이며 503·500 경로),
// AdMob 검증기와 보상 처리는 설정과 무관하게 늘 조립합니다.
func newBillingParts(cfg config.BillingConfig, pool *pgxpool.Pool, httpClient *http.Client, urls billingURLs, clk clock.Clock, logger *slog.Logger) billingParts {
	parts := billingParts{
		RewardVerifier: billing.NewRewardVerifier(billing.RewardVerifierConfig{KeysURL: urls.AdMobKeys, HTTPClient: httpClient, Clock: clk}),
		Rewards:        billing.NewRewards(pool, clk, logger),
	}
	if !cfg.Configured() {
		return parts
	}
	source := billing.NewRevenueCat(billing.RevenueCatConfig{
		ProjectID:  cfg.RevenueCatProjectID,
		APIKey:     cfg.RevenueCatAPIKey,
		HTTPClient: httpClient,
		BaseURL:    urls.RevenueCat,
	})
	syncer := billing.NewSyncer(pool, source, billing.SyncConfig{
		Catalog:        billing.AdFreeCatalog(cfg.AdFreeProductIDs),
		ProductionOnly: cfg.ProductionOnly,
		Logger:         logger,
	}, clk)
	parts.Purchases = syncer
	parts.Sync = syncer
	parts.Webhooks = billing.NewWebhooks(pool, syncer, cfg.RevenueCatWebhookAuth, clk, logger)
	return parts
}

// newReadings는 운세 화면 묶음을 조립합니다. 문장 틀과 슬롯 명세는 시드 버전마다 DB(seed 명령이 넣음, P4-7)에서 읽습니다.
// 근거 열람 권한(D60 insight)은 insight가 판정합니다.
func newReadings(store *content.Store, service *fortune.Service, insight fortune.Insight, logger *slog.Logger, clk clock.Clock) *fortune.Views {
	return fortune.NewViews(service, store, content.NewRenderer(logger), insight, clk, logger)
}

// newGrantProviders는 로그인 허가를 취소하는 제공자(카카오 unlink, Apple revoke) 클라이언트를 만듭니다.
// serve와 job retention이 같은 설정으로 조립합니다.
func newGrantProviders(settings authSettings, urls providerURLs, httpClient *http.Client, clk clock.Clock) (*provider.Kakao, *provider.Apple, error) {
	cfg := settings.config
	kakao, err := provider.NewKakao(provider.KakaoConfig{
		AppKey:    cfg.KakaoAppKey,
		AdminKey:  cfg.KakaoAdminKey,
		JWKSURL:   urls.KakaoJWKS,
		UnlinkURL: urls.KakaoUnlink,
		HTTP:      httpClient,
		Clock:     clk,
	})
	if err != nil {
		return nil, nil, fmt.Errorf("provider kakao: %w", err)
	}
	apple, err := provider.NewApple(provider.AppleConfig{
		TeamID:         cfg.AppleTeamID,
		KeyID:          cfg.AppleKeyID,
		PrivateKey:     settings.applePrivate,
		BundleID:       cfg.AppleBundleID,
		ServicesID:     cfg.AppleServicesID,
		WebRedirectURI: cfg.AppleWebRedirectURI,
		JWKSURL:        urls.AppleJWKS,
		TokenURL:       urls.AppleToken,
		RevokeURL:      urls.AppleRevoke,
		HTTP:           httpClient,
		Clock:          clk,
	})
	if err != nil {
		return nil, nil, fmt.Errorf("provider apple: %w", err)
	}
	return kakao, apple, nil
}

// newServer는 인증·계정·프로필 서비스와 계약 라우트를 조립해 http.Handler를 만듭니다.
//
// 의존 방향은 핸들러(httpapi.API) → 서비스(auth·account) → provider·DB입니다.
// bearer 라우트는 BearerAuth가 access token을 검증하고 계정 접근 상태(지운 계정, 동의)를 확인한 뒤 핸들러로 넘깁니다.
func newServer(settings authSettings, deps serverDeps) (http.Handler, error) {
	cfg := settings.config

	access, err := token.NewAccessIssuer(settings.signing, settings.previousSigning, deps.Clock)
	if err != nil {
		return nil, fmt.Errorf("access token 발급기: %w", err)
	}
	kakao, apple, err := newGrantProviders(settings, deps.Providers, deps.HTTP, deps.Clock)
	if err != nil {
		return nil, err
	}

	line, err := provider.NewLINE(provider.LINEConfig{
		ChannelID: cfg.LineChannelID,
		JWKSURL:   deps.Providers.LineJWKS,
		HTTP:      deps.HTTP,
		Clock:     deps.Clock,
	})
	if err != nil {
		return nil, fmt.Errorf("provider line: %w", err)
	}
	google, err := provider.NewGoogle(provider.GoogleConfig{
		ClientIDs: cfg.GoogleClientIDs,
		JWKSURL:   deps.Providers.GoogleJWKS,
		HTTP:      deps.HTTP,
		Clock:     deps.Clock,
	})
	if err != nil {
		return nil, fmt.Errorf("provider google: %w", err)
	}

	// 허가 취소 대기 행은 commit 뒤 한 번 시도하고, 실패하면 job retention이 다시 시도합니다(S106).
	revocations := auth.NewRevocations(deps.Pool, kakao, apple, settings.box, deps.Clock, deps.Logger)
	authService := auth.NewService(deps.Pool, auth.ServiceDeps{
		Kakao:   kakao,
		Line:    line,
		Google:  google,
		Apple:   apple,
		Access:  access,
		Box:     settings.box,
		Clock:   deps.Clock,
		Logger:  deps.Logger,
		Revoker: revocations,
	})
	accountService := account.NewService(deps.Pool, revocations, deps.Clock, deps.Logger)

	profileService := profile.NewService(deps.Pool, deps.Charts, deps.Clock)
	// 계정 합치기는 B의 증명 검증을 인증 서비스에, 프로필 요약을 프로필 서비스에 맡기고, 합치기 전에 B의 결제를 동기화하며,
	// B를 지운 뒤 허가 취소를 시도합니다(S110·S111).
	mergeService := merge.NewService(deps.Pool, merge.Deps{
		Proofs:    authService,
		Profiles:  profileService,
		Purchases: deps.Billing.Sync,
		Revoker:   revocations,
		Clock:     deps.Clock,
		Logger:    deps.Logger,
	})

	// 계약(내장 spec)으로 요청을 검증하고, 아직 구현하지 않은 operation은 501로 답합니다.
	spec, err := gen.GetSpec()
	if err != nil {
		return nil, fmt.Errorf("계약 읽기: %w", err)
	}
	// 이용약관·개인정보 처리방침은 바이너리에 내장한 원문입니다(D80).
	legalDocs, err := legal.Load()
	if err != nil {
		return nil, err
	}
	httpDeps := httpapi.Deps{Logger: deps.Logger, Clock: deps.Clock, DB: deps.Pool}
	routes := httpapi.Routes{
		Spec:         spec,
		Validate:     httpapi.ValidateRequests(spec, deps.Logger),
		Authenticate: httpapi.BearerAuth(access, accountService, deps.Logger),
		// Idempotency-Key는 일정 만들기, 일기 만들기, 계정 합치기에 적용합니다. registerDevice는 P8에서 더합니다.
		// 계정 합치기는 토큰이 일회용이라 같은 키의 재전송에 저장한 첫 응답(A의 Me)을 돌려줍니다(S111).
		Idempotency: httpapi.Idempotency(httpapi.NewPgIdempotencyStore(deps.Pool), deps.Clock, deps.Logger, "createSchedule", "createDiary", "mergeAccounts"),
		// 미리보기·시진 확인·음력 변환은 클라이언트 IP별 분당 30회입니다(P6-1). 키는 operation + IP입니다.
		RateLimit: httpapi.RateLimit(ratelimit.New(deps.Pool, deps.Clock), deps.ProxyHops, publicRateLimit, time.Minute, "createPreview", "getBirthHour", "convertLunarDate"),
	}
	// 검증기가 없으면 nil로 두어 App Check operation이 503입니다(nil 인터페이스를 RequireAppCheck에 넘기지 않음).
	if deps.AppCheck != nil {
		routes.AppCheck = httpapi.RequireAppCheck(deps.AppCheck, deps.Logger)
	}
	api := &httpapi.API{
		Auth:      authService,
		Accounts:  accountService,
		Profiles:  profileService,
		Merges:    mergeService,
		Lunar:     deps.Lunar,
		BirthHour: deps.BirthHour,
		Readings:  deps.Readings,
		Contents:  deps.Contents,
		Schedules: schedule.NewService(schedule.NewStore(deps.Pool)),
		DB:        deps.Pool,
		Logger:    deps.Logger,
		AppLink:   settings.appLink,
		AppConfig: deps.AppConfig,
		Legal:     legalDocs,
	}
	// Previews가 없으면 미리보기를 조립하지 않아 503입니다(Readings·Contents와 같은 관례).
	if deps.Previews != nil {
		api.Previews = deps.Previews
		api.PreviewUsage = preview.NewUsage(deps.Pool)
	}
	// Days가 없으면 일기를 새로 쓸 수 없으므로 Readings·Contents처럼 조립하지 않아 일기 operation이 503입니다.
	if deps.Days != nil {
		api.Diaries = diary.NewService(diary.NewStore(deps.Pool), deps.Days, deps.Clock)
	}
	api.Entitlements = deps.Entitlements
	api.Ledger = deps.Ledger
	api.Purchases = deps.Billing.Purchases
	api.Webhooks = deps.Billing.Webhooks
	api.RewardVerifier = deps.Billing.RewardVerifier
	api.Rewards = deps.Billing.Rewards
	deps.TestLogin.enable(api, authService)
	return httpapi.NewHandler(httpDeps, func(mux *http.ServeMux) {
		httpapi.RegisterAPI(mux, api, httpDeps, routes)
	}), nil
}

// serveHTTP는 listener로 handler를 서비스합니다.
// ctx가 취소되면 Shutdown을 shutdownTimeout 안에서 호출해 처리 중인 요청을 끝까지 응답합니다.
func serveHTTP(ctx context.Context, listener net.Listener, handler http.Handler, logger *slog.Logger) error {
	server := &http.Server{
		Handler:           handler,
		ReadHeaderTimeout: readHeaderTimeout,
		ReadTimeout:       readTimeout,
		IdleTimeout:       idleTimeout,
		// net/http 내부 오류도 구조화 로그로 남깁니다.
		ErrorLog: slog.NewLogLogger(logger.Handler(), slog.LevelWarn),
	}

	serveErr := make(chan error, 1)
	go func() { serveErr <- server.Serve(listener) }()

	select {
	case err := <-serveErr:
		// Shutdown 전에 Serve가 끝나는 것은 시작 실패 같은 비정상 종료입니다.
		return fmt.Errorf("serve: %w", err)
	case <-ctx.Done():
	}

	// ctx는 이미 취소됐으므로 종료 제한 시간은 새 ctx에서 시작합니다.
	shutdownCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), shutdownTimeout)
	defer cancel()
	logger.InfoContext(shutdownCtx, "종료 신호 수신, 처리 중인 요청을 마칩니다")
	if err := server.Shutdown(shutdownCtx); err != nil {
		// 제한 시간 안에 끝나지 않은 연결은 강제로 닫습니다.
		_ = server.Close()
		return fmt.Errorf("shutdown: %w", err)
	}
	if err := <-serveErr; !errors.Is(err, http.ErrServerClosed) {
		return fmt.Errorf("serve: %w", err)
	}
	return nil
}
