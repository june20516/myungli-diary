package opsapi_test

import (
	"testing"

	"github.com/june20516/myungli-diary/server/internal/opsapi"
)

func TestAllowlist_Normalizes(t *testing.T) {
	list := opsapi.ParseAllowlist(" Op@Example.com ,x@y.z")

	for _, email := range []string{"op@example.com", "OP@EXAMPLE.COM", " x@y.z "} {
		if !list.Allows(email) {
			t.Errorf("Allows(%q) = false, want true", email)
		}
	}
	if list.Allows("other@example.com") {
		t.Error("목록에 없는 메일을 허용했습니다")
	}
}

func TestAllowlist_EmptyRejectsEveryone(t *testing.T) {
	for _, raw := range []string{"", "  ", ",, ,"} {
		list := opsapi.ParseAllowlist(raw)
		if list.Allows("") || list.Allows("op@example.com") {
			t.Errorf("ParseAllowlist(%q)가 누군가를 허용했습니다", raw)
		}
	}
}
