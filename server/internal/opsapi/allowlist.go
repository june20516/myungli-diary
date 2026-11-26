package opsapi

import "strings"

// Allowlist는 운영 명령을 실행할 수 있는 운영자 메일 집합입니다(Secret OPS_OPERATORS).
// 비어 있으면 누구도 허용하지 않습니다.
type Allowlist struct {
	emails map[string]struct{}
}

// ParseAllowlist는 쉼표로 구분한 메일 목록을 읽습니다.
// 각 항목은 앞뒤 공백을 지우고 소문자로 바꾸며, 빈 항목은 버립니다.
func ParseAllowlist(raw string) Allowlist {
	emails := make(map[string]struct{})
	for _, item := range strings.Split(raw, ",") {
		if email := normalizeEmail(item); email != "" {
			emails[email] = struct{}{}
		}
	}
	return Allowlist{emails: emails}
}

// Allows는 메일이 허용 목록에 있는지 돌려줍니다. 비교는 공백 제거와 소문자 기준입니다.
func (a Allowlist) Allows(email string) bool {
	normalized := normalizeEmail(email)
	if normalized == "" {
		return false
	}
	_, ok := a.emails[normalized]
	return ok
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}
