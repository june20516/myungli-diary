package httpapi

import (
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
)

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

// 계약의 date-time 필드는 모두 응답 쪽이라, 이 패키지 init이 등록한 date-time format 검사를 스키마로 직접 확인합니다.
// 정규식만으로는 통과하는 없는 날짜도 format 위반이어야 하고, fieldErrorsOf가 code "format"으로 바꿔야 합니다.
func TestDateTimeFormat_RejectsNonexistentDate(t *testing.T) {
	schema := openapi3.NewDateTimeSchema()
	cases := []struct {
		value   string
		wantErr bool
	}{
		{"2026-10-13T09:00:00Z", false},
		{"2026-10-13T18:00:00+09:00", false},
		{"2026-02-30T10:00:00Z", true},
		{"2026-10-13T25:00:00Z", true},
		{"2026-10-13", true},
	}
	for _, tc := range cases {
		err := schema.VisitJSON(tc.value)
		if (err != nil) != tc.wantErr {
			t.Errorf("VisitJSON(%q) error = %v, wantErr %v", tc.value, err, tc.wantErr)
			continue
		}
		if !tc.wantErr {
			continue
		}
		got := fieldErrorsOf(err, "/at", true)
		if len(got) != 1 || got[0].Code != "format" {
			t.Errorf("fieldErrorsOf(%q) = %+v, want code format 하나", tc.value, got)
		}
	}
}
