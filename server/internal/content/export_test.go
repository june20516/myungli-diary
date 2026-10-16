package content

import "github.com/google/uuid"

// SelectionLockForTest는 Select가 accountID에 거는 계정 lock과 같은 lock을 거는 SQL과 인자를 돌려줍니다.
// 테스트가 이 lock을 먼저 쥐어 Select들이 실제로 lock을 기다리는지 확인할 때 씁니다.
func SelectionLockForTest(accountID uuid.UUID) (sql string, args []any) {
	return selectionLockSQL, []any{selectionLockClass, accountID.String()}
}

// SelectionLockClassForTest는 계정 lock의 첫 키입니다. pg_locks.classid에 이 값이 보입니다.
const SelectionLockClassForTest = selectionLockClass

// SetFlightHookForTest는 호출이 로드 flight(문장 틀·슬롯 명세)에 들어갈 때마다 hook(flight 키)을 부르게 합니다.
// 다른 호출이 같은 flight에 합류한 것을 관찰한 뒤 취소하는 테스트에 씁니다. Store를 쓰기 전에 부릅니다.
func SetFlightHookForTest(s *Store, hook func(key string)) { s.onFlight = hook }
