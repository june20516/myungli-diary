package merge

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/merge/mergedb"
)

// remainingDays는 권한마다 남은 길이를 먼저 더한 뒤 일 단위로 한 번 올립니다(구간마다 올리지 않음).
func TestRemainingDays(t *testing.T) {
	now := time.Date(2026, 10, 23, 9, 0, 0, 0, time.UTC)
	halfDay := 12 * time.Hour
	grant := func(entitlement billing.Entitlement, startsAt, expiresAt time.Time) mergedb.ListRemainingPassGrantsRow {
		return mergedb.ListRemainingPassGrantsRow{Entitlement: string(entitlement), StartsAt: startsAt, ExpiresAt: expiresAt}
	}
	tests := []struct {
		name   string
		grants []mergedb.ListRemainingPassGrantsRow
		want   map[billing.Entitlement]int
	}{
		{
			name: "5일 12시간 구간 둘은 합 11일(구간별 올림이면 12)",
			grants: []mergedb.ListRemainingPassGrantsRow{
				grant(billing.AdFree, now.Add(-day), now.Add(5*day+halfDay)),
				grant(billing.AdFree, now.Add(5*day+halfDay), now.Add(11*day)),
			},
			want: map[billing.Entitlement]int{billing.AdFree: 11},
		},
		{
			name:   "정확히 n일 대기 구간은 n일",
			grants: []mergedb.ListRemainingPassGrantsRow{grant(billing.AdFree, now.Add(3*day), now.Add(10*day))},
			want:   map[billing.Entitlement]int{billing.AdFree: 7},
		},
		{
			name:   "사용 중 구간은 지금부터 세고, 1초라도 남으면 하루로 올립니다",
			grants: []mergedb.ListRemainingPassGrantsRow{grant(billing.Insight, now.Add(-10*day), now.Add(2*day+time.Second))},
			want:   map[billing.Entitlement]int{billing.Insight: 3},
		},
		{
			name: "권한마다 따로 셉니다",
			grants: []mergedb.ListRemainingPassGrantsRow{
				grant(billing.AdFree, now, now.Add(4*day)),
				grant(billing.Insight, now, now.Add(halfDay)),
			},
			want: map[billing.Entitlement]int{billing.AdFree: 4, billing.Insight: 1},
		},
		{name: "구간이 없으면 빈 표", grants: nil, want: map[billing.Entitlement]int{}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, remainingDays(tt.grants, now))
		})
	}
}
