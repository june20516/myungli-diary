package diary

// NewServiceWith는 테스트가 Store 대신 entryStore 대역으로 Service를 만들게 엽니다.
var NewServiceWith = newServiceWith

// EntryStore는 테스트 대역이 만족해야 하는 Service의 저장소 의존입니다.
type EntryStore = entryStore
