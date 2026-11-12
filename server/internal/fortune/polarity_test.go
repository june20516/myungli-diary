package fortune_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/fortune"
)

// TestTagPolarity는 태그 길흉 표가 엔진 spec §7.7 표와 같은지 고정합니다. tag.big_change는 옛 규칙 버전 기록을 읽으려고 남긴 키입니다.
// 원본: core/docs/specs/2026-10-10-myungli-engine-design.md §7.7 "해시태그".
func TestTagPolarity(t *testing.T) {
	want := map[string]fortune.Polarity{
		"tag.big_change":             fortune.PolarityBad,
		"tag.clash":                  fortune.PolarityBad,
		"tag.clash_day_branch":       fortune.PolarityBad,
		"tag.clash_month_branch":     fortune.PolarityBad,
		"tag.harmony":                fortune.PolarityGood,
		"tag.ten_god_rush.bigyeop":   fortune.PolarityNeutral,
		"tag.ten_god_rush.siksang":   fortune.PolarityGood,
		"tag.ten_god_rush.jaeseong":  fortune.PolarityGood,
		"tag.ten_god_rush.gwanseong": fortune.PolarityBad,
		"tag.ten_god_rush.inseong":   fortune.PolarityGood,
		"tag.cheoneul_gwiin":         fortune.PolarityGood,
		"tag.dohwa":                  fortune.PolarityNeutral, // D125 개정(#1083)
		"tag.yeokma":                 fortune.PolarityNeutral,
		"tag.hwagae":                 fortune.PolarityNeutral,
		"tag.gongmang":               fortune.PolarityBad,
		"tag.gosin":                  fortune.PolarityBad,
		"tag.gwasuk":                 fortune.PolarityBad,
		"tag.wonjin":                 fortune.PolarityBad,
		"tag.yongsin_day":            fortune.PolarityGood,
		"tag.gwiin_day":              fortune.PolarityGood,
	}
	assert.Len(t, want, 20)
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

// TestTagPolarity_CoversEngineTagKeys는 엔진 계약(core/message_keys.json)의 태그 키가 모두 길흉 표에 있는지 봅니다.
// 표에 없는 태그가 오면 오늘 화면과 일기 저장이 실패하므로, 엔진 규칙 버전을 따라잡을 때 놓치지 않게 합니다(#821).
func TestTagPolarity_CoversEngineTagKeys(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("..", "..", "..", "core", "message_keys.json"))
	require.NoError(t, err)
	var keys []string
	require.NoError(t, json.Unmarshal(raw, &keys))

	var tagKeys int
	for _, key := range keys {
		if !strings.HasPrefix(key, fortune.TagPrefix) {
			continue
		}
		tagKeys++
		_, ok := fortune.TagPolarity(key)
		assert.True(t, ok, "엔진 태그 키 %s의 길흉이 표에 없습니다", key)
	}
	assert.Positive(t, tagKeys)
}
