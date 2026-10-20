//go:build staging

package auth

import (
	"context"
	"errors"
	"regexp"
)

// ErrTestLabelInvalid는 테스트 로그인 label이 영숫자 1~32자가 아니라는 뜻입니다.
var ErrTestLabelInvalid = errors.New("테스트 로그인 label 형식이 틀렸습니다")

// testLabelPattern은 테스트 로그인 label 형식(영숫자 1~32자)입니다(spec §13.2).
var testLabelPattern = regexp.MustCompile(`^[A-Za-z0-9]{1,32}$`)

// ValidTestLabel은 label이 테스트 로그인 형식(영숫자 1~32자)인지 알려 줍니다.
func ValidTestLabel(label string) bool {
	return testLabelPattern.MatchString(label)
}

// LoginTest는 staging E2E용 테스트 로그인입니다(S24, spec §13.2). build tag staging에만 있어 prod 바이너리에는 없습니다.
// 외부 제공자 검증만 건너뛰고, provider test·subject label로 카카오·Apple 로그인과 같은 트랜잭션(계정 찾기·만들기,
// 삭제 대기 복구와 이전 세션 폐기, 새 refresh family 발급)을 거칩니다. label은 로그에 남기지 않습니다(subject와 같은 취급).
func (s *Service) LoginTest(ctx context.Context, label string) (LoginResult, error) {
	if !ValidTestLabel(label) {
		return LoginResult{}, ErrTestLabelInvalid
	}
	return s.login(ctx, providerTest, fixedTarget(label, nil))
}
