package profile

import "testing"

func TestLocalDate_AddDays(t *testing.T) {
	cases := []struct {
		from LocalDate
		days int
		want LocalDate
	}{
		{LocalDate{2026, 9, 5}, 1, LocalDate{2026, 9, 6}},
		{LocalDate{2026, 12, 31}, 1, LocalDate{2027, 1, 1}},
		{LocalDate{2028, 3, 1}, -1, LocalDate{2028, 2, 29}},
		{LocalDate{2026, 11, 4}, 0, LocalDate{2026, 11, 4}},
	}
	for _, c := range cases {
		if got := c.from.AddDays(c.days); got != c.want {
			t.Errorf("%v.AddDays(%d) = %v, want %v", c.from, c.days, got, c.want)
		}
	}
}
