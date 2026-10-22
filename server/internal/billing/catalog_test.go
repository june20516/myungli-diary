package billing

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestAdFreeCatalog(t *testing.T) {
	catalog := AdFreeCatalog([]string{"a", "b"})

	want := Product{Months: 1, Entitlements: []Entitlement{AdFree, Insight}}
	assert.Equal(t, want, catalog["a"])
	assert.Equal(t, want, catalog["b"])
	assert.Len(t, catalog, 2)
	_, ok := catalog["c"]
	assert.False(t, ok, "목록 밖 상품은 없어야 합니다")
}
