package fortune_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/june20516/myungli-diary/server/internal/fortune"
)

// TestTagPolarity는 태그 길흉 표가 엔진 spec §7.7 표(15키)와 같은지 고정합니다.
// 원본: core/docs/specs/2026-10-10-myungli-engine-design.md §7.7 "해시태그".
func TestTagPolarity(t *testing.T) {
	want := map[string]fortune.Polarity{
		"tag.big_change":             fortune.PolarityBad,
		"tag.clash":                  fortune.PolarityBad,
		"tag.harmony":                fortune.PolarityGood,
		"tag.ten_god_rush.bigyeop":   fortune.PolarityNeutral,
		"tag.ten_god_rush.siksang":   fortune.PolarityGood,
		"tag.ten_god_rush.jaeseong":  fortune.PolarityGood,
		"tag.ten_god_rush.gwanseong": fortune.PolarityBad,
		"tag.ten_god_rush.inseong":   fortune.PolarityGood,
		"tag.cheoneul_gwiin":         fortune.PolarityGood,
		"tag.dohwa":                  fortune.PolarityGood,
		"tag.yeokma":                 fortune.PolarityNeutral,
		"tag.hwagae":                 fortune.PolarityNeutral,
		"tag.gongmang":               fortune.PolarityBad,
		"tag.yongsin_day":            fortune.PolarityGood,
		"tag.gwiin_day":              fortune.PolarityGood,
	}
	assert.Len(t, want, 15)
	for key, polarity := range want {
		got, ok := fortune.TagPolarity(key)
		assert.True(t, ok, key)
		assert.Equal(t, polarity, got, key)
	}
	for _, key := range []string{"tag.unknown", "dohwa", ""} {
		_, ok := fortune.TagPolarity(key)
		assert.False(t, ok, key)
	}
}

func TestPolarity_Values(t *testing.T) {
	assert.Equal(t, "good", string(fortune.PolarityGood))
	assert.Equal(t, "bad", string(fortune.PolarityBad))
	assert.Equal(t, "neutral", string(fortune.PolarityNeutral))
}
