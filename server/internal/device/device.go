// Package device는 아침 알림을 받을 기기(FCM 토큰)를 등록하고 해제합니다(S92, S119).
package device

import (
	"errors"

	"github.com/google/uuid"
)

// Platform은 기기 종류입니다. 계약 DevicePlatform과 같은 값입니다.
type Platform string

const (
	PlatformIOS     Platform = "ios"
	PlatformAndroid Platform = "android"
)

// MaxActivePerAccount는 계정당 활성 기기 상한입니다(S92). 넘으면 가장 오래 보지 못한 기기부터 비활성으로 바꿉니다.
const MaxActivePerAccount = 10

// ErrNotFound는 해제할 기기가 없거나 요청한 계정의 기기가 아닐 때입니다.
var ErrNotFound = errors.New("알림 기기를 찾을 수 없습니다")

// Device는 등록된 기기입니다.
type Device struct {
	ID       uuid.UUID
	Platform Platform
}
