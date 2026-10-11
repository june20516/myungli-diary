// Package config는 환경 변수에서 server 설정을 읽고 검증합니다.
package config

import (
	"errors"
	"fmt"
	"log/slog"
	"strconv"
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
		Env:          orDefault(getenv("APP_ENV"), defaultEnv),
		DatabaseURL:  getenv("DATABASE_URL"),
		GCPProjectID: getenv("GOOGLE_CLOUD_PROJECT"),
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
