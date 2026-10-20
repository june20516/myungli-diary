package billing

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

const (
	testIOSProduct     = "test.ad_free.month"
	testAndroidProduct = "test.ad_free.month.android"
)

var testProducts = map[string]bool{testIOSProduct: true, testAndroidProduct: true}

func utc(year int, month time.Month, day, hour int) time.Time {
	return time.Date(year, month, day, hour, 0, 0, 0, time.UTC)
}

// pair는 구매 하나가 만드는 두 행(ad_free, insight)입니다.
func pair(ref string, starts, expires time.Time) []Grant {
	return []Grant{
		{Entitlement: AdFree, Source: SourceAdFreePass, SourceRef: ref, StartsAt: starts, ExpiresAt: expires},
		{Entitlement: Insight, Source: SourceAdFreePass, SourceRef: ref, StartsAt: starts, ExpiresAt: expires},
	}
}

func purchase(id string, at time.Time) Purchase {
	return Purchase{ID: id, ProductID: testIOSProduct, PurchasedAt: at, Production: true}
}

func concat(groups ...[]Grant) []Grant {
	var out []Grant
	for _, g := range groups {
		out = append(out, g...)
	}
	return out
}

func TestAddMonth(t *testing.T) {
	tests := []struct {
		name string
		in   time.Time
		want time.Time
	}{
		{"같은 날 같은 시각", time.Date(2026, 1, 15, 10, 0, 0, 0, time.UTC), time.Date(2026, 2, 15, 10, 0, 0, 0, time.UTC)},
		{"1월 31일은 2월 마지막 날", time.Date(2026, 1, 31, 10, 30, 5, 0, time.UTC), time.Date(2026, 2, 28, 10, 30, 5, 0, time.UTC)},
		{"윤년 1월 31일은 2월 29일", time.Date(2028, 1, 31, 0, 0, 0, 0, time.UTC), time.Date(2028, 2, 29, 0, 0, 0, 0, time.UTC)},
		{"3월 31일은 4월 30일", time.Date(2026, 3, 31, 23, 59, 59, 0, time.UTC), time.Date(2026, 4, 30, 23, 59, 59, 0, time.UTC)},
		{"12월 31일은 다음 해 1월 31일", time.Date(2026, 12, 31, 8, 0, 0, 0, time.UTC), time.Date(2027, 1, 31, 8, 0, 0, 0, time.UTC)},
		{"UTC가 아닌 입력은 UTC 달력으로", time.Date(2026, 2, 1, 1, 0, 0, 0, time.FixedZone("KST", 9*3600)), time.Date(2026, 2, 28, 16, 0, 0, 0, time.UTC)},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := addMonth(tt.in)
			assert.True(t, got.Equal(tt.want), "got %v, want %v", got, tt.want)
			assert.Equal(t, time.UTC, got.Location())
		})
	}
}

func TestAdFreeGrants(t *testing.T) {
	jan10 := utc(2026, 1, 10, 9)
	feb10 := utc(2026, 2, 10, 9)
	mar10 := utc(2026, 3, 10, 9)
	apr10 := utc(2026, 4, 10, 9)

	tests := []struct {
		name           string
		purchases      []Purchase
		productionOnly bool
		want           []Grant
	}{
		{
			name:      "구매 없음",
			purchases: nil,
			want:      nil,
		},
		{
			name:      "구매 하나는 같은 기간의 두 행",
			purchases: []Purchase{purchase("p1", jan10)},
			want:      pair("p1", jan10, feb10),
		},
		{
			name:      "만료 전 재구매는 직전 만료에서 시작(D61)",
			purchases: []Purchase{purchase("p1", jan10), purchase("p2", utc(2026, 1, 25, 0))},
			want:      concat(pair("p1", jan10, feb10), pair("p2", feb10, mar10)),
		},
		{
			name:      "만료 뒤 재구매는 구매일에서 시작",
			purchases: []Purchase{purchase("p1", jan10), purchase("p2", utc(2026, 3, 1, 0))},
			want:      concat(pair("p1", jan10, feb10), pair("p2", utc(2026, 3, 1, 0), utc(2026, 4, 1, 0))),
		},
		{
			name:      "만료 시각에 재구매하면 끊김 없이 이어짐",
			purchases: []Purchase{purchase("p1", jan10), purchase("p2", feb10)},
			want:      concat(pair("p1", jan10, feb10), pair("p2", feb10, mar10)),
		},
		{
			name: "섞인 입력은 구매일 순, 같은 구매일은 id 순",
			purchases: []Purchase{
				purchase("c", utc(2026, 2, 1, 0)),
				purchase("b", jan10),
				purchase("a", jan10),
			},
			want: concat(pair("a", jan10, feb10), pair("b", feb10, mar10), pair("c", mar10, apr10)),
		},
		{
			name: "환불 구매는 빼고 다시 이어 붙임",
			purchases: []Purchase{
				purchase("p1", jan10),
				{ID: "p2", ProductID: testIOSProduct, PurchasedAt: utc(2026, 1, 20, 0), Refunded: true, Production: true},
				purchase("p3", utc(2026, 1, 25, 0)),
			},
			want: concat(pair("p1", jan10, feb10), pair("p3", feb10, mar10)),
		},
		{
			name: "목록 밖 상품은 제외, 다른 플랫폼 상품은 포함",
			purchases: []Purchase{
				{ID: "other", ProductID: "test.something.else", PurchasedAt: jan10, Production: true},
				{ID: "android", ProductID: testAndroidProduct, PurchasedAt: jan10, Production: true},
			},
			want: pair("android", jan10, feb10),
		},
		{
			name: "productionOnly면 sandbox 제외",
			purchases: []Purchase{
				{ID: "sandbox", ProductID: testIOSProduct, PurchasedAt: utc(2026, 1, 1, 0), Production: false},
				purchase("prod", jan10),
			},
			productionOnly: true,
			want:           pair("prod", jan10, feb10),
		},
		{
			name: "productionOnly가 아니면 sandbox도 셈",
			purchases: []Purchase{
				{ID: "sandbox", ProductID: testIOSProduct, PurchasedAt: utc(2026, 1, 1, 0), Production: false},
				purchase("prod", jan10),
			},
			want: concat(pair("sandbox", utc(2026, 1, 1, 0), utc(2026, 2, 1, 0)), pair("prod", utc(2026, 2, 1, 0), utc(2026, 3, 1, 0))),
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := adFreeGrants(tt.purchases, testProducts, tt.productionOnly)

			assert.Len(t, got, len(tt.want))
			for i := range tt.want {
				if i >= len(got) {
					break
				}
				assert.Equal(t, tt.want[i].Entitlement, got[i].Entitlement, "행 %d", i)
				assert.Equal(t, tt.want[i].Source, got[i].Source, "행 %d", i)
				assert.Equal(t, tt.want[i].SourceRef, got[i].SourceRef, "행 %d", i)
				assert.True(t, tt.want[i].StartsAt.Equal(got[i].StartsAt), "행 %d starts: got %v, want %v", i, got[i].StartsAt, tt.want[i].StartsAt)
				assert.True(t, tt.want[i].ExpiresAt.Equal(got[i].ExpiresAt), "행 %d expires: got %v, want %v", i, got[i].ExpiresAt, tt.want[i].ExpiresAt)
			}
		})
	}
}

func TestAdFreeGrants_DoesNotReorderInput(t *testing.T) {
	purchases := []Purchase{purchase("b", utc(2026, 2, 1, 0)), purchase("a", utc(2026, 1, 1, 0))}

	adFreeGrants(purchases, testProducts, false)

	assert.Equal(t, "b", purchases[0].ID, "입력 slice 순서를 바꾸지 않음")
}
