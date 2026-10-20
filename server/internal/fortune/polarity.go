package fortune

import "strings"

// Polarity는 태그의 길흉입니다. 값은 계약 TagPolarity와 같습니다.
type Polarity string

const (
	PolarityGood    Polarity = "good"
	PolarityBad     Polarity = "bad"
	PolarityNeutral Polarity = "neutral"
)

// TagPrefix는 엔진 태그 키의 앞부분입니다. 계약 Tag.key는 이 접두어를 뗀 glossary `tag` 범주의 키입니다.
const TagPrefix = "tag."

// TagContractKey는 엔진 태그 키에서 접두어를 뗍니다.
func TagContractKey(key string) string {
	return strings.TrimPrefix(key, TagPrefix)
}

// tagPolarity는 태그 키 → 길흉입니다(P4-6). proto에 길흉이 없어 server가 고정 표로 둡니다.
// 원본: core/docs/specs/2026-10-10-myungli-engine-design.md §7.7 "해시태그" 표의 길흉 열(15키).
// 길=good, 흉=bad, 중립=neutral입니다.
var tagPolarity = map[string]Polarity{
	// 1. 합·충
	"tag.big_change": PolarityBad,
	"tag.clash":      PolarityBad,
	"tag.harmony":    PolarityGood,
	// 2. 십성 쏠림: 관성=흉, 재성·인성·식상=길, 비겁=중립
	"tag.ten_god_rush.bigyeop":   PolarityNeutral,
	"tag.ten_god_rush.siksang":   PolarityGood,
	"tag.ten_god_rush.jaeseong":  PolarityGood,
	"tag.ten_god_rush.gwanseong": PolarityBad,
	"tag.ten_god_rush.inseong":   PolarityGood,
	// 3. 신살: 귀인·도화=길, 역마·화개=중립, 공망=흉
	"tag.cheoneul_gwiin": PolarityGood,
	"tag.dohwa":          PolarityGood,
	"tag.yeokma":         PolarityNeutral,
	"tag.hwagae":         PolarityNeutral,
	"tag.gongmang":       PolarityBad,
	// 보조
	"tag.yongsin_day": PolarityGood,
	"tag.gwiin_day":   PolarityGood,
}

// TagPolarity는 엔진 태그 키(접두어 포함)의 길흉입니다. 표에 없는 키는 false입니다.
func TagPolarity(key string) (Polarity, bool) {
	polarity, ok := tagPolarity[key]
	return polarity, ok
}
