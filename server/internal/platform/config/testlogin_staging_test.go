//go:build staging

package config

import (
	"strings"
	"testing"
)

func TestLoadTestLogin(t *testing.T) {
	strong := strings.Repeat("s", minTestLoginSecretBytes)
	t.Run("비면 오류", func(t *testing.T) {
		for _, value := range []string{"", " \n"} {
			_, err := LoadTestLogin(fakeEnv(map[string]string{"TEST_LOGIN_SECRET": value}))
			if err == nil || !strings.Contains(err.Error(), "TEST_LOGIN_SECRET") {
				t.Errorf("LoadTestLogin(%q) error = %v, want TEST_LOGIN_SECRET 오류", value, err)
			}
		}
	})
	t.Run("32바이트보다 짧으면 오류이고 값은 담지 않음", func(t *testing.T) {
		short := strong[:minTestLoginSecretBytes-1]
		_, err := LoadTestLogin(fakeEnv(map[string]string{"TEST_LOGIN_SECRET": short}))
		if err == nil || !strings.Contains(err.Error(), "TEST_LOGIN_SECRET") {
			t.Fatalf("LoadTestLogin() error = %v, want TEST_LOGIN_SECRET 오류", err)
		}
		if strings.Contains(err.Error(), short) {
			t.Errorf("오류 문구에 값이 들어 있습니다: %v", err)
		}
	})
	t.Run("정상 값은 공백을 지워 그대로", func(t *testing.T) {
		cfg, err := LoadTestLogin(fakeEnv(map[string]string{"TEST_LOGIN_SECRET": " " + strong + "\n"}))
		if err != nil || cfg.Secret != strong {
			t.Errorf("LoadTestLogin() = %+v, %v", cfg, err)
		}
	})
}

func TestLoadTestLogin_AppEnv(t *testing.T) {
	strong := strings.Repeat("s", minTestLoginSecretBytes)
	for _, appEnv := range []string{"", "local", "staging"} {
		if _, err := LoadTestLogin(fakeEnv(map[string]string{"APP_ENV": appEnv, "TEST_LOGIN_SECRET": strong})); err != nil {
			t.Errorf("LoadTestLogin(APP_ENV=%q) error = %v, want nil", appEnv, err)
		}
	}
	_, err := LoadTestLogin(fakeEnv(map[string]string{"APP_ENV": "prod", "TEST_LOGIN_SECRET": strong}))
	if err == nil || !strings.Contains(err.Error(), "APP_ENV") || !strings.Contains(err.Error(), "prod") {
		t.Fatalf("LoadTestLogin(APP_ENV=prod) error = %v, want APP_ENV 오류", err)
	}
	if strings.Contains(err.Error(), strong) {
		t.Errorf("오류 문구에 비밀이 들어 있습니다: %v", err)
	}
}
