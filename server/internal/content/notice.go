package content

import "github.com/june20516/myungli-diary/server/internal/content/render"

// Notice는 엔진 안내(ResponseMeta.notices) 하나의 응답 형태입니다.
//
// Code는 계약 NoticeCode 값(proto 이름에서 NOTICE_CODE_ 접두어를 떼고 소문자로 바꾼 것, 예 "time_unknown")입니다.
// Text는 안내 문구입니다. writing에 안내 문구 슬롯이 아직 없어 지금은 늘 빈(nil이 아닌) 조각 배열이고,
// app은 Code로 자기 문구를 씁니다(계약 Notice 설명).
type Notice struct {
	Code string
	Text []render.Segment
}
