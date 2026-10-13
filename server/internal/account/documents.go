package account

// Document는 사용자가 동의해야 하는 약관 문서의 종류입니다.
type Document string

const (
	// Terms는 이용약관입니다.
	Terms Document = "terms"
	// Privacy는 개인정보 처리방침입니다.
	Privacy Document = "privacy"
)

// CurrentDocuments는 지금 유효한 문서별 버전입니다.
// 문서 버전을 올리는 일은 이 값을 바꾸는 코드 변경과 배포입니다. 올리면 이전 버전에만 동의한
// 계정은 다시 동의해야 합니다(Access.ConsentRequired가 true가 됩니다).
//
// 전역 변수이므로 테스트에서 바꿔 끼울 때는 t.Parallel을 쓰지 말고 끝나면 원복해야 합니다.
var CurrentDocuments = map[Document]string{Terms: "1", Privacy: "1"}
