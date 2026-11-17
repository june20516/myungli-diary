package billing

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestAdFreeCatalog(t *testing.T) {
	catalog := AdFreeCatalog(map[string]string{"prod_a": "ad_free_1m", "prod_b": "ad_free_1m"})

	want := Product{Months: 1, Entitlements: []Entitlement{AdFree, Insight}, StoreProductID: "ad_free_1m"}
	assert.Equal(t, want, catalog["prod_a"])
	assert.Equal(t, want, catalog["prod_b"])
	assert.Len(t, catalog, 2)
	_, ok := catalog["c"]
	assert.False(t, ok, "목록 밖 상품은 없어야 합니다")
}
