// Package config는 환경 변수에서 server 설정을 읽고 검증합니다.
package config

import (
	"errors"
	"fmt"
	"log/slog"
	"net/url"
	"regexp"
	"slices"
	"strconv"
	"strings"
)

// 기본값입니다.
const (
	defaultEnv      = "local"
	defaultPort     = 8080
	defaultLogLevel = "info"
)

// Config는 server 실행 설정입니다.
type Config struct {
	// Env는 실행 환경(local·staging·prod)입니다.
	Env string
	// Port는 HTTP 서버가 듣는 포트입니다. Cloud Run이 PORT로 넣어 줍니다.
	Port int
	// DatabaseURL은 PostgreSQL 연결 문자열입니다. 필요한 명령만 RequireDatabase로 검사합니다.
	DatabaseURL string
	// CloudSQLInstance는 Cloud SQL 연결 이름(project:region:instance, CLOUD_SQL_INSTANCE)입니다.
	// 있으면 Cloud SQL Go connector와 IAM DB 인증으로 붙고 DATABASE_URL의 host는 쓰지 않습니다(S121).
	CloudSQLInstance string
	// LogLevel은 로그 최소 수준입니다.
	LogLevel slog.Level
	// GCPProjectID는 GCP 프로젝트 ID입니다.
	GCPProjectID string
}

// validEnvs는 허용되는 APP_ENV 값입니다.
var validEnvs = map[string]bool{"local": true, "staging": true, "prod": true}

// logLevels는 허용되는 LOG_LEVEL 값과 그 수준입니다.
var logLevels = map[string]slog.Level{
	"debug": slog.LevelDebug,
	"info":  slog.LevelInfo,
	"warn":  slog.LevelWarn,
	"error": slog.LevelError,
}

// Load는 getenv로 환경 변수를 읽어 Config를 만듭니다. 빈 값은 기본값으로 취급합니다.
// 잘못된 값은 모두 모아 errors.Join으로 한 번에 돌려줍니다.
func Load(getenv func(string) string) (Config, error) {
	cfg := Config{
		Env:              orDefault(getenv("APP_ENV"), defaultEnv),
		DatabaseURL:      getenv("DATABASE_URL"),
		CloudSQLInstance: getenv("CLOUD_SQL_INSTANCE"),
		GCPProjectID:     getenv("GOOGLE_CLOUD_PROJECT"),
	}

	var errs []error

	if !validEnvs[cfg.Env] {
		errs = append(errs, fmt.Errorf("APP_ENV은 local, staging, prod 중 하나여야 합니다: %q", cfg.Env))
	}

	port, err := parsePort(orDefault(getenv("PORT"), strconv.Itoa(defaultPort)))
	if err == nil {
		cfg.Port = port
	} else {
		errs = append(errs, err)
	}

	rawLevel := orDefault(getenv("LOG_LEVEL"), defaultLogLevel)
	level, ok := logLevels[rawLevel]
	if ok {
		cfg.LogLevel = level
	} else {
		errs = append(errs, fmt.Errorf("LOG_LEVEL은 debug, info, warn, error 중 하나여야 합니다: %q", rawLevel))
	}

	if err := errors.Join(errs...); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

// RequireDatabase는 DATABASE_URL이 설정되어 있는지 검사합니다. DB를 쓰는 명령이 시작 전에 호출합니다.
func (c Config) RequireDatabase() error {
	if c.DatabaseURL == "" {
		return errors.New("DATABASE_URL이 설정되지 않았습니다")
	}
	return nil
}

// parsePort는 1~65535 사이의 정수 포트를 읽습니다.
func parsePort(raw string) (int, error) {
	port, err := strconv.Atoi(raw)
	if err != nil || port < 1 || port > 65535 {
		return 0, fmt.Errorf("PORT는 1~65535 사이의 정수여야 합니다: %q", raw)
	}
	return port, nil
}

// orDefault는 value가 비어 있으면 fallback을 돌려줍니다.
func orDefault(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

// AuthConfig는 인증에 쓰는 키와 제공자 설정입니다. 값의 형식(PEM, base64 등)은 읽는 쪽이 파싱하며,
// 여기서는 필수 값이 채워져 있는지만 검사합니다. 로컬 실행도 같은 규칙이고 대체 값을 만들지 않습니다.
type AuthConfig struct {
	// JWTKeyID·JWTKeyPEM은 access token 서명 키(ES256, PKCS8 PEM)의 ID와 값입니다.
	JWTKeyID, JWTKeyPEM string
	// JWTPreviousKeyID·JWTPreviousKeyPEM은 키 교체 기간에 검증만 하는 이전 서명 키입니다(선택, 둘이 함께).
	JWTPreviousKeyID, JWTPreviousKeyPEM string
	// TokenKeyID·TokenKey는 제공자 토큰을 암호화하는 AES-256 키(base64)의 ID와 값입니다.
	TokenKeyID, TokenKey string
	// TokenPreviousKeyID·TokenPreviousKey는 복호화만 하는 이전 암호 키입니다(선택, 둘이 함께).
	TokenPreviousKeyID, TokenPreviousKey string
	// KakaoAppKey는 카카오 앱 키(id_token 검증의 audience)이고, KakaoAdminKey는 unlink 호출용 어드민 키입니다.
	KakaoAppKey, KakaoAdminKey string
	// LineChannelID는 LINE Login 채널 ID(id_token 검증의 audience)입니다.
	LineChannelID string
	// GoogleClientIDs는 Google id_token의 audience로 받는 OAuth client ID 목록입니다(GOOGLE_CLIENT_IDS, 쉼표 구분).
	GoogleClientIDs []string
	// AppleTeamID·AppleKeyID·ApplePrivateKeyPEM은 Apple client secret(ES256 JWT)을 만드는 재료입니다.
	AppleTeamID, AppleKeyID, ApplePrivateKeyPEM string
	// AppleBundleID는 앱 로그인의 audience이고, AppleServicesID는 웹 로그인의 audience입니다.
	AppleBundleID, AppleServicesID string
	// AppleWebRedirectURI는 Apple이 웹 로그인 결과(form_post)를 보내는 server 주소입니다.
	AppleWebRedirectURI string
	// AppLinkBase는 Android App Link 주소(https, path 없음)입니다. Apple 웹 콜백은 이 주소의 /auth/apple로
	// 교환 코드를 넘기고, 같은 도메인이 안내 페이지와 /.well-known/assetlinks.json을 내줍니다.
	AppLinkBase string
	// AndroidAppPackage는 App Link를 받을 Android 앱의 패키지 이름입니다(assetlinks.json, intent 링크).
	AndroidAppPackage string
	// AndroidCertSHA256은 Android 앱 서명 인증서의 SHA-256 지문을 쉼표로 이은 값입니다(assetlinks.json).
	AndroidCertSHA256 string
	// AndroidStoreURL은 앱이 설치되지 않았을 때 안내 페이지가 보내는 스토어 주소입니다.
	AndroidStoreURL string
}

// LoadAuth는 getenv로 인증 설정을 읽습니다. 값은 앞뒤 공백(줄바꿈 포함)을 지운 뒤 쓰므로 공백뿐인 값은 빈 값입니다.
// 필수 값이 빈 변수와 이전 키의 짝 오류를 모두 모아 errors.Join으로 돌려줍니다. 오류에는 변수 이름만 담고 값은 담지 않습니다.
func LoadAuth(getenv func(string) string) (AuthConfig, error) {
	// Secret Manager에서 넣은 값에 끝 줄바꿈이 붙는 일이 흔해 공백을 지웁니다.
	getenv = trimmedEnv(getenv)
	var missing []string
	require := func(name string) string {
		value := getenv(name)
		if value == "" {
			missing = append(missing, name)
		}
		return value
	}

	cfg := AuthConfig{
		JWTKeyID:            require("JWT_SIGNING_KEY_ID"),
		JWTKeyPEM:           require("JWT_SIGNING_KEY"),
		JWTPreviousKeyID:    getenv("JWT_PREVIOUS_KEY_ID"),
		JWTPreviousKeyPEM:   getenv("JWT_PREVIOUS_KEY"),
		TokenKeyID:          require("TOKEN_ENCRYPTION_KEY_ID"),
		TokenKey:            require("TOKEN_ENCRYPTION_KEY"),
		TokenPreviousKeyID:  getenv("TOKEN_PREVIOUS_KEY_ID"),
		TokenPreviousKey:    getenv("TOKEN_PREVIOUS_KEY"),
		KakaoAppKey:         require("KAKAO_APP_KEY"),
		KakaoAdminKey:       require("KAKAO_ADMIN_KEY"),
		LineChannelID:       require("LINE_CHANNEL_ID"),
		GoogleClientIDs:     splitList(require("GOOGLE_CLIENT_IDS")),
		AppleTeamID:         require("APPLE_TEAM_ID"),
		AppleKeyID:          require("APPLE_KEY_ID"),
		ApplePrivateKeyPEM:  require("APPLE_PRIVATE_KEY"),
		AppleBundleID:       require("APPLE_BUNDLE_ID"),
		AppleServicesID:     require("APPLE_SERVICES_ID"),
		AppleWebRedirectURI: require("APPLE_WEB_REDIRECT_URI"),
		AppLinkBase:         require("APP_LINK_BASE"),
		AndroidAppPackage:   require("ANDROID_APP_PACKAGE"),
		AndroidCertSHA256:   require("ANDROID_CERT_SHA256"),
		AndroidStoreURL:     require("ANDROID_STORE_URL"),
	}

	// 쉼표뿐인 값처럼 항목이 하나도 남지 않으면 비어 있는 것으로 봅니다.
	if len(cfg.GoogleClientIDs) == 0 && !slices.Contains(missing, "GOOGLE_CLIENT_IDS") {
		missing = append(missing, "GOOGLE_CLIENT_IDS")
	}

	var errs []error
	if len(missing) > 0 {
		errs = append(errs, fmt.Errorf("필수 인증 설정이 없습니다: %s", strings.Join(missing, ", ")))
	}
	errs = append(errs,
		requirePair("JWT_PREVIOUS_KEY_ID", cfg.JWTPreviousKeyID, "JWT_PREVIOUS_KEY", cfg.JWTPreviousKeyPEM),
		requirePair("TOKEN_PREVIOUS_KEY_ID", cfg.TokenPreviousKeyID, "TOKEN_PREVIOUS_KEY", cfg.TokenPreviousKey),
	)
	if err := errors.Join(errs...); err != nil {
		return AuthConfig{}, err
	}
	return cfg, nil
}

// RevocationConfig는 허가 취소 재시도 job(retention)이 쓰는 설정입니다. serve의 AuthConfig 중
// 카카오 unlink, Apple revoke, 저장한 Apple refresh token 복호화에 필요한 값만 담습니다.
type RevocationConfig struct {
	// TokenKeyID·TokenKey는 Apple refresh token 암호화 키이고, 이전 키는 키 교체 중 복호화에만 씁니다(없으면 비어 있음).
	TokenKeyID, TokenKey                 string
	TokenPreviousKeyID, TokenPreviousKey string
	// KakaoAdminKey는 카카오 unlink의 Admin 키입니다.
	KakaoAdminKey string
	// AppleTeamID·AppleKeyID·ApplePrivateKeyPEM은 Apple revoke의 client_secret을 서명합니다.
	AppleTeamID, AppleKeyID, ApplePrivateKeyPEM string
}

// LoadRevocation은 getenv로 허가 취소 재시도 설정을 읽습니다. 규칙은 LoadAuth와 같습니다:
// 값의 앞뒤 공백을 지우고, 필수 값이 빈 변수와 이전 키의 짝 오류를 모아 errors.Join으로 돌려주며, 오류에는 변수 이름만 담습니다.
// JWT 서명 키처럼 이 job이 쓰지 않는 값은 읽지 않습니다.
func LoadRevocation(getenv func(string) string) (RevocationConfig, error) {
	getenv = trimmedEnv(getenv)
	var missing []string
	require := func(name string) string {
		value := getenv(name)
		if value == "" {
			missing = append(missing, name)
		}
		return value
	}

	cfg := RevocationConfig{
		TokenKeyID:         require("TOKEN_ENCRYPTION_KEY_ID"),
		TokenKey:           require("TOKEN_ENCRYPTION_KEY"),
		TokenPreviousKeyID: getenv("TOKEN_PREVIOUS_KEY_ID"),
		TokenPreviousKey:   getenv("TOKEN_PREVIOUS_KEY"),
		KakaoAdminKey:      require("KAKAO_ADMIN_KEY"),
		AppleTeamID:        require("APPLE_TEAM_ID"),
		AppleKeyID:         require("APPLE_KEY_ID"),
		ApplePrivateKeyPEM: require("APPLE_PRIVATE_KEY"),
	}

	var errs []error
	if len(missing) > 0 {
		errs = append(errs, fmt.Errorf("필수 허가 취소 설정이 없습니다: %s", strings.Join(missing, ", ")))
	}
	errs = append(errs, requirePair("TOKEN_PREVIOUS_KEY_ID", cfg.TokenPreviousKeyID, "TOKEN_PREVIOUS_KEY", cfg.TokenPreviousKey))
	if err := errors.Join(errs...); err != nil {
		return RevocationConfig{}, err
	}
	return cfg, nil
}

// trimmedEnv는 getenv가 돌려주는 값의 앞뒤 공백을 지우는 getenv를 만듭니다.
func trimmedEnv(getenv func(string) string) func(string) string {
	return func(name string) string { return strings.TrimSpace(getenv(name)) }
}

// requirePair는 선택 항목인 이전 키의 ID와 값이 둘 다 있거나 둘 다 없는지 검사합니다.
func requirePair(idName, id, valueName, value string) error {
	if (id == "") != (value == "") {
		return fmt.Errorf("%s와 %s는 함께 설정해야 합니다", idName, valueName)
	}
	return nil
}

// EngineConfig는 명리 엔진 연결 설정입니다.
type EngineConfig struct {
	// Addr는 엔진 gRPC 주소(host:port)입니다.
	Addr string
	// Audience는 엔진 Cloud Run 서비스의 https URL입니다. 비어 있으면 인증 없는 h2c(로컬)로 연결합니다.
	Audience string
}

// LoadEngine은 getenv로 엔진 설정을 읽습니다. ENGINE_ADDR는 필수이고 ENGINE_AUDIENCE는 있으면 https URL이어야 합니다.
// APP_ENV가 local(기본값)이 아니면 ENGINE_AUDIENCE도 필수입니다. 배포 환경의 엔진은 IAM 인증을 요구하기 때문입니다(S121).
// 오류에는 변수 이름만 담고 값은 담지 않습니다.
func LoadEngine(getenv func(string) string) (EngineConfig, error) {
	getenv = trimmedEnv(getenv)
	cfg := EngineConfig{Addr: getenv("ENGINE_ADDR"), Audience: getenv("ENGINE_AUDIENCE")}

	var errs []error
	if cfg.Addr == "" {
		errs = append(errs, errors.New("ENGINE_ADDR가 필요합니다"))
	}
	switch {
	case cfg.Audience == "" && orDefault(getenv("APP_ENV"), defaultEnv) != defaultEnv:
		errs = append(errs, errors.New("ENGINE_AUDIENCE가 필요합니다(APP_ENV가 local일 때만 비워 둘 수 있습니다)"))
	case cfg.Audience != "" && !isHTTPSURL(cfg.Audience):
		errs = append(errs, errors.New("ENGINE_AUDIENCE는 https URL이어야 합니다"))
	}
	if err := errors.Join(errs...); err != nil {
		return EngineConfig{}, err
	}
	return cfg, nil
}

// isHTTPSURL은 raw가 scheme이 https이고 host가 있는 URL인지 검사합니다.
func isHTTPSURL(raw string) bool {
	parsed, err := url.Parse(raw)
	return err == nil && parsed.Scheme == "https" && parsed.Host != ""
}

// AppCheckConfig는 Firebase App Check 검증 설정입니다.
type AppCheckConfig struct {
	// ProjectNumber는 Firebase 프로젝트 번호(숫자)입니다. APP_ENV가 local이면 비어 있을 수 있고,
	// 그때 App Check operation은 검증할 수 없어 503으로 답합니다.
	ProjectNumber string
}

// LoadAppCheck는 getenv로 App Check 설정을 읽습니다. FIREBASE_PROJECT_NUMBER는 APP_ENV가 local(기본값)이 아니면 필수이고,
// 값이 있으면 숫자만이어야 합니다(auth/provider/appcheck.go의 isDigits와 같은 검사). 오류에는 변수 이름만 담고 값은 담지 않습니다.
func LoadAppCheck(getenv func(string) string) (AppCheckConfig, error) {
	getenv = trimmedEnv(getenv)
	env := orDefault(getenv("APP_ENV"), defaultEnv)
	number := getenv("FIREBASE_PROJECT_NUMBER")

	switch {
	case number == "" && env != defaultEnv:
		return AppCheckConfig{}, errors.New("FIREBASE_PROJECT_NUMBER가 필요합니다(APP_ENV가 local일 때만 비워 둘 수 있습니다)")
	case number != "" && strings.Trim(number, "0123456789") != "":
		return AppCheckConfig{}, errors.New("FIREBASE_PROJECT_NUMBER는 숫자만으로 된 프로젝트 번호여야 합니다")
	}
	return AppCheckConfig{ProjectNumber: number}, nil
}

// defaultTrustedProxyHops는 TRUSTED_PROXY_HOPS의 기본값입니다(Cloud Run 앞단 하나).
const defaultTrustedProxyHops = 1

// LoadTrustedProxyHops는 getenv로 TRUSTED_PROXY_HOPS를 읽습니다. 클라이언트 IP를 X-Forwarded-For의
// 오른쪽에서 몇 번째 값으로 볼지 정합니다. 실제 프록시 수보다 크거나 0이면 모든 클라이언트가 프록시 주소(RemoteAddr) 하나를
// 키로 함께 써서 전체가 분당 한도에 묶이니 배포 구성과 맞춰야 합니다. 비어 있으면 1이고 0 이상 정수만 받습니다. 오류에는 변수 이름만 담고 값은 담지 않습니다.
func LoadTrustedProxyHops(getenv func(string) string) (int, error) {
	raw := orDefault(trimmedEnv(getenv)("TRUSTED_PROXY_HOPS"), strconv.Itoa(defaultTrustedProxyHops))
	hops, err := strconv.Atoi(raw)
	if err != nil || hops < 0 {
		return 0, errors.New("TRUSTED_PROXY_HOPS는 0 이상의 정수여야 합니다")
	}
	return hops, nil
}

// defaultMinAppVersion은 최소 앱 버전의 기본값입니다(강제 업데이트 없음, P6-10).
const defaultMinAppVersion = "0.0.0"

// semverPattern은 MAJOR.MINOR.PATCH 숫자 형식입니다(앞자리 0 없음, 접두어·사전 배포 표기 없음).
var semverPattern = regexp.MustCompile(`^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$`)

// AppVersionConfig는 플랫폼별 최소 앱 버전(getAppConfig)입니다.
type AppVersionConfig struct {
	MinIOS, MinAndroid string
}

// LoadAppVersions는 getenv로 APP_MIN_VERSION_IOS·APP_MIN_VERSION_ANDROID를 읽습니다. 비어 있으면 0.0.0이고,
// MAJOR.MINOR.PATCH 숫자 형식이 아니면 오류입니다(P6-10). 오류에는 변수 이름만 담고 값은 담지 않습니다.
func LoadAppVersions(getenv func(string) string) (AppVersionConfig, error) {
	getenv = trimmedEnv(getenv)
	var errs []error
	read := func(name string) string {
		raw := orDefault(getenv(name), defaultMinAppVersion)
		if !semverPattern.MatchString(raw) {
			errs = append(errs, fmt.Errorf("%s는 MAJOR.MINOR.PATCH 숫자 형식이어야 합니다", name))
		}
		return raw
	}
	cfg := AppVersionConfig{MinIOS: read("APP_MIN_VERSION_IOS"), MinAndroid: read("APP_MIN_VERSION_ANDROID")}
	if err := errors.Join(errs...); err != nil {
		return AppVersionConfig{}, err
	}
	return cfg, nil
}

// BillingConfig는 결제(RevenueCat) 설정입니다.
type BillingConfig struct {
	// RevenueCatProjectID는 RevenueCat 프로젝트 id입니다(REST v2 경로에 씁니다).
	RevenueCatProjectID string
	// RevenueCatAPIKey는 RevenueCat REST v2 secret key입니다. 로그·오류에 남기지 않습니다.
	RevenueCatAPIKey string
	// RevenueCatWebhookAuth는 webhook Authorization 헤더와 비교할 값 전체입니다(예: "Bearer <난수>").
	RevenueCatWebhookAuth string
	// AdFreeProductIDs는 광고 제거권으로 치는 RevenueCat 상품 id(prod…) 목록입니다(스토어마다 하나, S124). 목록 밖 상품은 무시합니다.
	AdFreeProductIDs []string
	// ProductionOnly가 true면 production 환경 구매만 셉니다(APP_ENV가 prod일 때, P7-2).
	ProductionOnly bool
}

// Configured는 결제 동기화에 필요한 네 값이 모두 있는지 알려 줍니다.
func (c BillingConfig) Configured() bool {
	return c.RevenueCatProjectID != "" && c.RevenueCatAPIKey != "" && c.RevenueCatWebhookAuth != "" && len(c.AdFreeProductIDs) > 0
}

// empty는 결제 값 넷이 모두 비어 있는지 알려 줍니다.
func (c BillingConfig) empty() bool {
	return c.RevenueCatProjectID == "" && c.RevenueCatAPIKey == "" && c.RevenueCatWebhookAuth == "" && len(c.AdFreeProductIDs) == 0
}

// LoadBilling은 getenv로 결제 설정을 읽습니다. REVENUECAT_PROJECT_ID·REVENUECAT_API_KEY·REVENUECAT_WEBHOOK_AUTH·
// AD_FREE_PRODUCT_IDS(쉼표 목록)는 APP_ENV가 local(기본값)이 아니면 모두 필수입니다(P7-16).
// staging은 넷 다 비어 있을 때만 결제를 끈 채(Configured false) 통과합니다(#654). 일부만 비면 설정 실수로 보고 오류입니다.
// 오류에는 변수 이름만 담고 값은 담지 않습니다.
func LoadBilling(getenv func(string) string) (BillingConfig, error) {
	getenv = trimmedEnv(getenv)
	env := orDefault(getenv("APP_ENV"), defaultEnv)

	cfg := BillingConfig{
		RevenueCatProjectID:   getenv("REVENUECAT_PROJECT_ID"),
		RevenueCatAPIKey:      getenv("REVENUECAT_API_KEY"),
		RevenueCatWebhookAuth: getenv("REVENUECAT_WEBHOOK_AUTH"),
		AdFreeProductIDs:      splitList(getenv("AD_FREE_PRODUCT_IDS")),
		ProductionOnly:        env == "prod",
	}

	billingOff := env == defaultEnv || (env == "staging" && cfg.empty())
	if !billingOff {
		var missing []string
		for _, required := range []struct {
			name    string
			present bool
		}{
			{"REVENUECAT_PROJECT_ID", cfg.RevenueCatProjectID != ""},
			{"REVENUECAT_API_KEY", cfg.RevenueCatAPIKey != ""},
			{"REVENUECAT_WEBHOOK_AUTH", cfg.RevenueCatWebhookAuth != ""},
			{"AD_FREE_PRODUCT_IDS", len(cfg.AdFreeProductIDs) > 0},
		} {
			if !required.present {
				missing = append(missing, required.name)
			}
		}
		if len(missing) > 0 {
			return BillingConfig{}, fmt.Errorf("%s가 필요합니다(APP_ENV가 local일 때만 비워 둘 수 있습니다)", strings.Join(missing, ", "))
		}
	}
	return cfg, nil
}

// splitList는 쉼표 목록을 나눠 앞뒤 공백을 지우고 빈 항목을 뺍니다.
func splitList(raw string) []string {
	var items []string
	for _, item := range strings.Split(raw, ",") {
		if item = strings.TrimSpace(item); item != "" {
			items = append(items, item)
		}
	}
	return items
}
