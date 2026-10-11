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
