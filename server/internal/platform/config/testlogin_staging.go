//go:build staging

package config

import (
	"errors"
	"fmt"
)

// minTestLoginSecretBytes는 TEST_LOGIN_SECRET의 최소 길이입니다. 추측 공격을 막을 만큼의 길이(256비트 난수의 원문 길이)로 둡니다.
const minTestLoginSecretBytes = 32

// TestLoginConfig는 staging 테스트 로그인(S24, spec §13.2) 설정입니다. build tag staging에만 있습니다.
type TestLoginConfig struct {
	// Secret은 요청 헤더 X-Test-Login-Secret과 비교하는 비밀입니다.
	Secret string
}

// testLoginEnvs는 테스트 로그인이 든 staging 빌드가 시작할 수 있는 APP_ENV 값입니다.
var testLoginEnvs = map[string]bool{"local": true, "staging": true}

// LoadTestLogin은 getenv로 TEST_LOGIN_SECRET을 읽습니다. staging 빌드에서는 필수이고 32바이트 이상이어야 합니다.
// APP_ENV가 local·staging이 아니면(prod) 테스트 로그인이 든 바이너리가 prod에 배포된 것이라 오류입니다.
// 값은 앞뒤 공백을 지운 뒤 씁니다. 오류에 APP_ENV 값은 담지만 비밀은 담지 않습니다.
func LoadTestLogin(getenv func(string) string) (TestLoginConfig, error) {
	getenv = trimmedEnv(getenv)
	if env := orDefault(getenv("APP_ENV"), defaultEnv); !testLoginEnvs[env] {
		return TestLoginConfig{}, fmt.Errorf("staging 빌드(테스트 로그인 포함)는 APP_ENV가 local 또는 staging이어야 합니다: APP_ENV=%q", env)
	}
	secret := getenv("TEST_LOGIN_SECRET")
	switch {
	case secret == "":
		return TestLoginConfig{}, errors.New("TEST_LOGIN_SECRET이 필요합니다(staging 빌드)")
	case len(secret) < minTestLoginSecretBytes:
		return TestLoginConfig{}, fmt.Errorf("TEST_LOGIN_SECRET은 %d바이트 이상이어야 합니다", minTestLoginSecretBytes)
	}
	return TestLoginConfig{Secret: secret}, nil
}
