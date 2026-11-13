package fortune

import (
	"strings"

	enginev1 "github.com/june20516/myungli-diary/server/internal/gen/enginev1"
)

// 행운 색, 방위, 숫자의 관계 문장 슬롯입니다(D130, writing W78). core 메시지 키가 아니라 writing 식별자 키이고,
// server가 같은 판정의 relation 매개변수로 고릅니다. relation이 SAME이거나 없으면 core 키 문장(SlotColor 등)을 그대로 씁니다.
const (
	SlotColorRelation     = "daily.color_relation"
	SlotDirectionRelation = "daily.direction_relation"
	SlotNumberRelation    = "daily.number_relation"
)

// relationParam은 바탕 오행에서 본 결과 오행의 관계 매개변수입니다(core C44). 값은 SAME, MO, JA, CHEO, GWI입니다.
const relationParam = "relation"

// colorRelations는 색 관계 문장 키의 끝마디입니다. SAME은 core 키 문장이라 없습니다.
var colorRelations = map[string]string{"MO": "mo", "JA": "ja", "CHEO": "cheo", "GWI": "gwi"}

// relationKey는 카드 슬롯 slot의 판정 j에 쓸 관계 문장 슬롯과 키를 돌려줍니다. 관계 문장을 쓰지 않는 판정이면 false입니다.
// 슬롯 명세의 select를 따릅니다.
//   - 색: 카드 하나인 날 color.<날의 성격>의 relation이 MO, JA, CHEO, GWI면 color.<날의 성격>.<소문자>. 색이 둘인 날(color.balance.*, color.source.*)은 쓰지 않음
//   - 방위: direction.day_kind.ordinary의 relation이 MO(희신 방위)면 direction.day_kind.ordinary.mo
//   - 숫자: number.<날의 성격>의 relation이 SAME이 아니면 number.<날의 성격>.related
//
// 모르는 relation 값(core가 나중에 더한 값)은 core 키 문장으로 둡니다.
func relationKey(slot string, j *enginev1.Judgment) (string, string, bool) {
	relation := j.GetParams()[relationParam].GetText()
	if relation == "" || relation == "SAME" {
		return "", "", false
	}
	key := j.GetMessageKey()
	switch slot {
	case SlotColor:
		suffix, ok := colorRelations[relation]
		if !ok || strings.HasPrefix(key, "color.balance.") || strings.HasPrefix(key, "color.source.") {
			return "", "", false
		}
		return SlotColorRelation, key + "." + suffix, true
	case SlotDirection:
		if key != "direction.day_kind.ordinary" || relation != "MO" {
			return "", "", false
		}
		return SlotDirectionRelation, key + ".mo", true
	case SlotNumber:
		if _, ok := colorRelations[relation]; !ok {
			return "", "", false
		}
		return SlotNumberRelation, key + ".related", true
	}
	return "", "", false
}
