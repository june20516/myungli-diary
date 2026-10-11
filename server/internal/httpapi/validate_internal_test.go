package httpapi

import "testing"

func TestJSONPointer_EscapesTildeAndSlash(t *testing.T) {
	cases := []struct {
		segments []string
		want     string
	}{
		{nil, ""},
		{[]string{"birth", "date", "day"}, "/birth/date/day"},
		{[]string{"a/b"}, "/a~1b"},
		{[]string{"m~n"}, "/m~0n"},
		// ~를 먼저 바꿔야 "~1"이 "/"로 오해되지 않습니다(RFC 6901 §4).
		{[]string{"~1"}, "/~01"},
		{[]string{"items", "0"}, "/items/0"},
	}
	for _, tc := range cases {
		if got := jsonPointer(tc.segments); got != tc.want {
			t.Errorf("jsonPointer(%q) = %q, want %q", tc.segments, got, tc.want)
		}
	}
}
