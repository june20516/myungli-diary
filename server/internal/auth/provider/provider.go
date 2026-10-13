// Package provider는 외부 로그인 제공자(카카오·Apple)와의 연동을 담당합니다.
//
// 맡는 일은 다음과 같습니다.
//   - 제공자가 발급한 id_token 검증(서명·iss·aud·exp·nonce)
//   - Apple authorization code 교환과 refresh token revoke
//   - 카카오 연결 끊기(unlink)
//
// 모든 실패는 두 sentinel 오류 중 하나로 분류합니다.
//   - ErrUnavailable: 제공자 쪽 장애(연결 실패, timeout, 5xx, 429, JWKS 조회 실패).
//     사용자가 다시 로그인해도 소용없고, 잠시 뒤 재시도하면 됩니다(HTTP 503).
//   - ErrTokenInvalid: 사용자가 낸 토큰·code 자체가 틀렸습니다(HTTP 401 계열).
//
// 우리 설정이 틀려 제공자가 거절한 경우(예: Apple invalid_client, 카카오 admin key 오류)는
// 어느 쪽도 아닌 일반 오류로 돌려줍니다. 재시도도 재로그인도 해결책이 아니라 서버 오류이기 때문입니다.
//
// 필수 설정이 빠지면 NewKakao·NewApple이 오류를 돌려줍니다.
//
// 오류 문구에는 id_token·code·refresh token·nonce·subject·제공자 응답 본문을 넣지 않습니다.
// 상태 코드와 제공자의 오류 코드(예: invalid_grant)만 넣습니다.
package provider

import (
	"fmt"
	"strings"
	"time"
)

// requestTimeout은 제공자로 나가는 HTTP 호출 한 번에 주는 최대 시간입니다.
const requestTimeout = 5 * time.Second

// Identity는 검증을 통과한 id_token에서 꺼낸 사용자 식별 정보입니다.
type Identity struct {
	// Subject는 제공자 안에서 사용자를 가리키는 고유 id(sub claim)입니다. 로그에 남기지 않습니다.
	Subject string
}

// requiredField는 비어 있으면 안 되는 설정 값 하나입니다.
type requiredField struct {
	name  string
	empty bool
}

// checkRequired는 비어 있는 필수 설정의 이름을 모아 오류로 돌려줍니다. 값 자체는 오류 문구에 넣지 않습니다.
// 설정 누락을 시작할 때 드러내야, 운영 중 로그인 실패가 토큰 오류(401)로 가려지지 않습니다.
func checkRequired(name string, fields ...requiredField) error {
	var missing []string
	for _, f := range fields {
		if f.empty {
			missing = append(missing, f.name)
		}
	}
	if len(missing) == 0 {
		return nil
	}
	return fmt.Errorf("%s 설정: 필수 값이 비어 있습니다: %s", name, strings.Join(missing, ", "))
}
