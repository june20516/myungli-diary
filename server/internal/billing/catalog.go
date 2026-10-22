package billing

// Product는 상품 하나가 주는 기간과 권한입니다(spec §5.1 상품 목록).
type Product struct {
	// Months는 구매 한 건이 주는 사용 기간(개월)입니다.
	Months int
	// Entitlements는 구매 한 건이 함께 주는 권한입니다.
	Entitlements []Entitlement
}

// Catalog는 RevenueCat 상품 id로 찾는 상품 목록입니다. 목록에 없는 상품은 사용 구간을 만들지 않습니다.
type Catalog map[string]Product

// AdFreeCatalog는 광고 제거권 상품 id마다 1개월, ad_free·insight 권한을 주는 목록을 만듭니다(D60 ③, D61).
func AdFreeCatalog(productIDs []string) Catalog {
	catalog := make(Catalog, len(productIDs))
	for _, id := range productIDs {
		catalog[id] = Product{Months: 1, Entitlements: []Entitlement{AdFree, Insight}}
	}
	return catalog
}
