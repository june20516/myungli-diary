package config

import (
	"log/slog"
	"strings"
	"testing"
)

// fakeEnv는 주어진 맵을 환경 변수처럼 돌려주는 getenv를 만듭니다.
func fakeEnv(vars map[string]string) func(string) string {
	return func(key string) string { return vars[key] }
}

func TestLoad_Defaults(t *testing.T) {
	cfg, err := Load(fakeEnv(nil))
	if err != nil {
		t.Fatalf("Load() error = %v, want nil", err)
	}
	if cfg.Env != "local" {
		t.Errorf("Env = %q, want %q", cfg.Env, "local")
	}
	if cfg.Port != 8080 {
		t.Errorf("Port = %d, want 8080", cfg.Port)
	}
	if cfg.LogLevel != slog.LevelInfo {
		t.Errorf("LogLevel = %v, want %v", cfg.LogLevel, slog.LevelInfo)
	}
	if cfg.DatabaseURL != "" {
		t.Errorf("DatabaseURL = %q, want empty", cfg.DatabaseURL)
	}
	if cfg.GCPProjectID != "" {
		t.Errorf("GCPProjectID = %q, want empty", cfg.GCPProjectID)
	}
}

func TestLoad_ReadsAllValues(t *testing.T) {
	cfg, err := Load(fakeEnv(map[string]string{
		"APP_ENV":              "prod",
		"PORT":                 "9090",
		"DATABASE_URL":         "postgres://db",
		"LOG_LEVEL":            "debug",
		"GOOGLE_CLOUD_PROJECT": "myungli-prod",
	}))
	if err != nil {
		t.Fatalf("Load() error = %v, want nil", err)
	}
	if cfg.Env != "prod" || cfg.Port != 9090 || cfg.DatabaseURL != "postgres://db" ||
		cfg.LogLevel != slog.LevelDebug || cfg.GCPProjectID != "myungli-prod" {
		t.Errorf("Load() = %+v, want values from environment", cfg)
	}
}

func TestLoad_InvalidEnv(t *testing.T) {
	_, err := Load(fakeEnv(map[string]string{"APP_ENV": "dev"}))
	if err == nil || !strings.Contains(err.Error(), "APP_ENV") {
		t.Fatalf("Load() error = %v, want error mentioning APP_ENV", err)
	}
}

func TestLoad_InvalidPort(t *testing.T) {
	for _, port := range []string{"0", "65536", "-1", "abc", "80.5"} {
		_, err := Load(fakeEnv(map[string]string{"PORT": port}))
		if err == nil || !strings.Contains(err.Error(), "PORT") {
			t.Errorf("PORT=%q: Load() error = %v, want error mentioning PORT", port, err)
		}
	}
}

func TestLoad_ValidPortBoundaries(t *testing.T) {
	for _, port := range []struct {
		raw  string
		want int
	}{{"1", 1}, {"65535", 65535}} {
		cfg, err := Load(fakeEnv(map[string]string{"PORT": port.raw}))
		if err != nil {
			t.Fatalf("PORT=%q: Load() error = %v, want nil", port.raw, err)
		}
		if cfg.Port != port.want {
			t.Errorf("PORT=%q: Port = %d, want %d", port.raw, cfg.Port, port.want)
		}
	}
}

func TestLoad_InvalidLogLevel(t *testing.T) {
	_, err := Load(fakeEnv(map[string]string{"LOG_LEVEL": "verbose"}))
	if err == nil || !strings.Contains(err.Error(), "LOG_LEVEL") {
		t.Fatalf("Load() error = %v, want error mentioning LOG_LEVEL", err)
	}
}

func TestLoad_LogLevelIsCaseSensitive(t *testing.T) {
	_, err := Load(fakeEnv(map[string]string{"LOG_LEVEL": "INFO"}))
	if err == nil || !strings.Contains(err.Error(), "LOG_LEVEL") {
		t.Fatalf("Load() error = %v, want error for uppercase LOG_LEVEL", err)
	}
}

func TestLoad_EmptyPortUsesDefault(t *testing.T) {
	cfg, err := Load(fakeEnv(map[string]string{"PORT": ""}))
	if err != nil {
		t.Fatalf("Load() error = %v, want nil", err)
	}
	if cfg.Port != 8080 {
		t.Errorf("Port = %d, want 8080", cfg.Port)
	}
}

func TestLoad_CollectsAllErrors(t *testing.T) {
	_, err := Load(fakeEnv(map[string]string{"APP_ENV": "dev", "PORT": "0", "LOG_LEVEL": "verbose"}))
	if err == nil {
		t.Fatal("Load() error = nil, want joined error")
	}
	for _, name := range []string{"APP_ENV", "PORT", "LOG_LEVEL"} {
		if !strings.Contains(err.Error(), name) {
			t.Errorf("Load() error = %q, want it to mention %s", err, name)
		}
	}
}

func TestRequireDatabase(t *testing.T) {
	if err := (Config{}).RequireDatabase(); err == nil {
		t.Error("RequireDatabase() with empty DatabaseURL error = nil, want error")
	}
	if err := (Config{DatabaseURL: "postgres://db"}).RequireDatabase(); err != nil {
		t.Errorf("RequireDatabase() with DatabaseURL error = %v, want nil", err)
	}
}

// requiredAuthVars는 LoadAuth가 반드시 요구하는 환경 변수 이름입니다.
var requiredAuthVars = []string{
	"JWT_SIGNING_KEY_ID", "JWT_SIGNING_KEY",
	"TOKEN_ENCRYPTION_KEY_ID", "TOKEN_ENCRYPTION_KEY",
	"KAKAO_APP_KEY", "KAKAO_ADMIN_KEY",
	"APPLE_TEAM_ID", "APPLE_KEY_ID", "APPLE_PRIVATE_KEY", "APPLE_BUNDLE_ID",
	"APPLE_SERVICES_ID", "APPLE_WEB_REDIRECT_URI",
	"APP_LINK_BASE", "ANDROID_APP_PACKAGE", "ANDROID_CERT_SHA256", "ANDROID_STORE_URL",
}

// completeAuthEnv는 필수 변수를 모두 채운 환경을 만듭니다. 값은 "v-<이름>"입니다.
func completeAuthEnv() map[string]string {
	env := make(map[string]string, len(requiredAuthVars))
	for _, name := range requiredAuthVars {
		env[name] = "v-" + name
	}
	return env
}

func TestLoadAuth_ReadsAllValues(t *testing.T) {
	env := completeAuthEnv()
	env["JWT_PREVIOUS_KEY_ID"] = "jwt-prev-id"
	env["JWT_PREVIOUS_KEY"] = "jwt-prev"
	env["TOKEN_PREVIOUS_KEY_ID"] = "tok-prev-id"
	env["TOKEN_PREVIOUS_KEY"] = "tok-prev"

	cfg, err := LoadAuth(fakeEnv(env))
	if err != nil {
		t.Fatalf("LoadAuth() error = %v, want nil", err)
	}
	//nolint:gosec // 환경 변수 이름을 흉내 낸 테스트 값이며 실제 자격 증명이 아닙니다
	want := AuthConfig{
		JWTKeyID: "v-JWT_SIGNING_KEY_ID", JWTKeyPEM: "v-JWT_SIGNING_KEY",
		JWTPreviousKeyID: "jwt-prev-id", JWTPreviousKeyPEM: "jwt-prev",
		TokenKeyID: "v-TOKEN_ENCRYPTION_KEY_ID", TokenKey: "v-TOKEN_ENCRYPTION_KEY",
		TokenPreviousKeyID: "tok-prev-id", TokenPreviousKey: "tok-prev",
		KakaoAppKey: "v-KAKAO_APP_KEY", KakaoAdminKey: "v-KAKAO_ADMIN_KEY",
		AppleTeamID: "v-APPLE_TEAM_ID", AppleKeyID: "v-APPLE_KEY_ID",
		ApplePrivateKeyPEM: "v-APPLE_PRIVATE_KEY", AppleBundleID: "v-APPLE_BUNDLE_ID",
		AppleServicesID:     "v-APPLE_SERVICES_ID",
		AppleWebRedirectURI: "v-APPLE_WEB_REDIRECT_URI",
		AppLinkBase:         "v-APP_LINK_BASE",
		AndroidAppPackage:   "v-ANDROID_APP_PACKAGE",
		AndroidCertSHA256:   "v-ANDROID_CERT_SHA256",
		AndroidStoreURL:     "v-ANDROID_STORE_URL",
	}
	if cfg != want {
		t.Errorf("LoadAuth() = %+v, want %+v", cfg, want)
	}
}

func TestLoadAuth_ReportsAllMissingRequired(t *testing.T) {
	if len(requiredAuthVars) != 16 {
		t.Fatalf("필수 변수 표 = %d개, want 16", len(requiredAuthVars))
	}
	_, err := LoadAuth(fakeEnv(nil))
	if err == nil {
		t.Fatal("LoadAuth() error = nil, want error")
	}
	for _, name := range requiredAuthVars {
		if !strings.Contains(err.Error(), name) {
			t.Errorf("오류에 %s가 없습니다: %v", name, err)
		}
	}
	// 대체된 옛 변수는 더 이상 요구하지 않습니다.
	if strings.Contains(err.Error(), "APPLE_CALLBACK_DEEPLINK") {
		t.Errorf("오류에 쓰지 않는 APPLE_CALLBACK_DEEPLINK가 있습니다: %v", err)
	}
}

func TestLoadAuth_WhitespaceOnlyIsMissing(t *testing.T) {
	env := completeAuthEnv()
	env["KAKAO_APP_KEY"] = " \n\t "
	env["JWT_PREVIOUS_KEY_ID"] = "  "
	env["JWT_PREVIOUS_KEY"] = "k"

	_, err := LoadAuth(fakeEnv(env))
	if err == nil {
		t.Fatal("LoadAuth() error = nil, want error")
	}
	for _, name := range []string{"KAKAO_APP_KEY", "JWT_PREVIOUS_KEY_ID"} {
		if !strings.Contains(err.Error(), name) {
			t.Errorf("오류에 %s가 없습니다: %v", name, err)
		}
	}
}

func TestLoadAuth_TrimsValues(t *testing.T) {
	env := completeAuthEnv()
	env["APPLE_TEAM_ID"] = "  TEAM01\n"

	cfg, err := LoadAuth(fakeEnv(env))
	if err != nil {
		t.Fatalf("LoadAuth() error = %v, want nil", err)
	}
	if cfg.AppleTeamID != "TEAM01" {
		t.Errorf("AppleTeamID = %q, want %q", cfg.AppleTeamID, "TEAM01")
	}
}

func TestLoadAuth_PreviousKeyNeedsBothIDAndValue(t *testing.T) {
	tests := []struct {
		name string
		set  map[string]string
		want string
	}{
		{"JWT 값만", map[string]string{"JWT_PREVIOUS_KEY": "k"}, "JWT_PREVIOUS_KEY_ID"},
		{"JWT ID만", map[string]string{"JWT_PREVIOUS_KEY_ID": "id"}, "JWT_PREVIOUS_KEY"},
		{"TOKEN 값만", map[string]string{"TOKEN_PREVIOUS_KEY": "k"}, "TOKEN_PREVIOUS_KEY_ID"},
		{"TOKEN ID만", map[string]string{"TOKEN_PREVIOUS_KEY_ID": "id"}, "TOKEN_PREVIOUS_KEY"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := completeAuthEnv()
			for k, v := range tt.set {
				env[k] = v
			}
			_, err := LoadAuth(fakeEnv(env))
			if err == nil || !strings.Contains(err.Error(), tt.want) {
				t.Errorf("LoadAuth() error = %v, want %s 언급", err, tt.want)
			}
		})
	}
}

func TestLoadAuth_ErrorDoesNotContainValues(t *testing.T) {
	env := completeAuthEnv()
	env["JWT_PREVIOUS_KEY"] = "secret-value-xyz"
	delete(env, "KAKAO_APP_KEY")
	_, err := LoadAuth(fakeEnv(env))
	if err == nil {
		t.Fatal("LoadAuth() error = nil, want error")
	}
	if strings.Contains(err.Error(), "secret-value-xyz") || strings.Contains(err.Error(), "v-APPLE") {
		t.Errorf("오류에 환경 변수 값이 들어 있습니다: %v", err)
	}
}

func TestLoadEngine(t *testing.T) {
	t.Run("ENGINE_ADDR가 없으면 오류", func(t *testing.T) {
		_, err := LoadEngine(fakeEnv(nil))
		if err == nil || !strings.Contains(err.Error(), "ENGINE_ADDR가 필요합니다") {
			t.Fatalf("LoadEngine() error = %v, want ENGINE_ADDR 오류", err)
		}
	})
	t.Run("ENGINE_AUDIENCE가 https가 아니면 오류이고 값은 담지 않음", func(t *testing.T) {
		_, err := LoadEngine(fakeEnv(map[string]string{"ENGINE_ADDR": "h:443", "ENGINE_AUDIENCE": "http://x"}))
		if err == nil || !strings.Contains(err.Error(), "ENGINE_AUDIENCE") {
			t.Fatalf("LoadEngine() error = %v, want ENGINE_AUDIENCE 오류", err)
		}
		if strings.Contains(err.Error(), "http://x") {
			t.Errorf("오류 문구에 값이 들어 있습니다: %v", err)
		}
	})
	t.Run("ENGINE_AUDIENCE에 host가 없으면 오류", func(t *testing.T) {
		for _, audience := range []string{"https://", "https:///path", "engine.run.app"} {
			_, err := LoadEngine(fakeEnv(map[string]string{"ENGINE_ADDR": "h:443", "ENGINE_AUDIENCE": audience}))
			if err == nil || !strings.Contains(err.Error(), "ENGINE_AUDIENCE") {
				t.Errorf("LoadEngine(audience=%q) error = %v, want ENGINE_AUDIENCE 오류", audience, err)
			}
		}
	})
	t.Run("정상 값은 그대로", func(t *testing.T) {
		cfg, err := LoadEngine(fakeEnv(map[string]string{"ENGINE_ADDR": "engine.run.app:443", "ENGINE_AUDIENCE": "https://engine.run.app"}))
		if err != nil {
			t.Fatalf("LoadEngine() error = %v, want nil", err)
		}
		if cfg != (EngineConfig{Addr: "engine.run.app:443", Audience: "https://engine.run.app"}) {
			t.Errorf("LoadEngine() = %+v", cfg)
		}
	})
	t.Run("audience 없이도 정상", func(t *testing.T) {
		cfg, err := LoadEngine(fakeEnv(map[string]string{"ENGINE_ADDR": "localhost:50051"}))
		if err != nil || cfg.Audience != "" || cfg.Addr != "localhost:50051" {
			t.Errorf("LoadEngine() = %+v, %v", cfg, err)
		}
	})
}

func TestLoadAppCheck(t *testing.T) {
	t.Run("APP_ENV가 local이면 비어 있어도 됨", func(t *testing.T) {
		for _, env := range []map[string]string{nil, {"APP_ENV": "local"}} {
			cfg, err := LoadAppCheck(fakeEnv(env))
			if err != nil || cfg.ProjectNumber != "" {
				t.Errorf("LoadAppCheck(%v) = %+v, %v, want 빈 값과 nil 오류", env, cfg, err)
			}
		}
	})
	t.Run("staging·prod에서 비면 오류", func(t *testing.T) {
		for _, appEnv := range []string{"staging", "prod"} {
			_, err := LoadAppCheck(fakeEnv(map[string]string{"APP_ENV": appEnv}))
			if err == nil || !strings.Contains(err.Error(), "FIREBASE_PROJECT_NUMBER") {
				t.Errorf("LoadAppCheck(APP_ENV=%s) error = %v, want FIREBASE_PROJECT_NUMBER 오류", appEnv, err)
			}
		}
	})
	t.Run("숫자만이 아니면 오류이고 값은 담지 않음", func(t *testing.T) {
		for _, number := range []string{"12ab", "projects/123", "-1", "1 2"} {
			_, err := LoadAppCheck(fakeEnv(map[string]string{"APP_ENV": "prod", "FIREBASE_PROJECT_NUMBER": number}))
			if err == nil || !strings.Contains(err.Error(), "FIREBASE_PROJECT_NUMBER") {
				t.Errorf("LoadAppCheck(%q) error = %v, want FIREBASE_PROJECT_NUMBER 오류", number, err)
				continue
			}
			if strings.Contains(err.Error(), number) {
				t.Errorf("오류 문구에 값이 들어 있습니다: %v", err)
			}
		}
	})
	t.Run("local에서도 값이 있으면 숫자만이어야 함", func(t *testing.T) {
		_, err := LoadAppCheck(fakeEnv(map[string]string{"FIREBASE_PROJECT_NUMBER": "abc"}))
		if err == nil {
			t.Error("LoadAppCheck() error = nil, want 오류")
		}
	})
	t.Run("정상 값은 공백을 지워 그대로", func(t *testing.T) {
		cfg, err := LoadAppCheck(fakeEnv(map[string]string{"APP_ENV": "prod", "FIREBASE_PROJECT_NUMBER": " 123456789012\n"}))
		if err != nil || cfg.ProjectNumber != "123456789012" {
			t.Errorf("LoadAppCheck() = %+v, %v", cfg, err)
		}
	})
}
