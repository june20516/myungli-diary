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

// LoadTestLogin은 getenv로 TEST_LOGIN_SECRET을 읽습니다. staging 빌드에서는 필수이고 32바이트 이상이어야 합니다.
// 값은 앞뒤 공백을 지운 뒤 씁니다. 오류에는 변수 이름만 담고 값은 담지 않습니다.
func LoadTestLogin(getenv func(string) string) (TestLoginConfig, error) {
	secret := trimmedEnv(getenv)("TEST_LOGIN_SECRET")
	switch {
	case secret == "":
		return TestLoginConfig{}, errors.New("TEST_LOGIN_SECRET이 필요합니다(staging 빌드)")
	case len(secret) < minTestLoginSecretBytes:
		return TestLoginConfig{}, fmt.Errorf("TEST_LOGIN_SECRET은 %d바이트 이상이어야 합니다", minTestLoginSecretBytes)
	}
	return TestLoginConfig{Secret: secret}, nil
}
