package httpapi

import (
	"context"
	"net/http"
	"sort"
	"strconv"
	"strings"
)

// defaultLanguage는 Accept-Language에 지원 언어가 없을 때 쓰는 언어입니다(P6-7).
const defaultLanguage = "en"

// supportedLanguages는 지원 언어(주 태그)입니다.
var supportedLanguages = map[string]bool{"ko": true, "en": true, "ja": true}

type languageContextKey struct{}

// languageRange는 Accept-Language의 항목 하나입니다.
type languageRange struct {
	primary string
	quality float64
}

// PickLanguage는 Accept-Language 값(RFC 9110 q값)에서 지원 언어(ko·en·ja) 중 첫째를 고릅니다.
// 주 태그로 비교하고(ko-KR → ko), q=0 항목과 q값이 잘못된 항목은 건너뜁니다. 맞는 것이 없으면 en입니다.
func PickLanguage(acceptLanguage string) string {
	var ranges []languageRange
	for _, item := range strings.Split(acceptLanguage, ",") {
		parts := strings.Split(item, ";")
		tag := strings.ToLower(strings.TrimSpace(parts[0]))
		primary, _, _ := strings.Cut(tag, "-")
		if !supportedLanguages[primary] {
			continue
		}
		quality, ok := parseQuality(parts[1:])
		if !ok || quality == 0 {
			continue
		}
		ranges = append(ranges, languageRange{primary: primary, quality: quality})
	}
	// 안정 정렬이라 q값이 같으면 헤더에서 앞선 항목이 먼저입니다.
	sort.SliceStable(ranges, func(i, j int) bool { return ranges[i].quality > ranges[j].quality })
	if len(ranges) == 0 {
		return defaultLanguage
	}
	return ranges[0].primary
}

// parseQuality는 항목의 매개변수에서 q값을 읽습니다. q가 없으면 1이고, 0~1 밖이거나 숫자가 아니면 ok=false입니다.
func parseQuality(params []string) (quality float64, ok bool) {
	for _, param := range params {
		name, value, found := strings.Cut(strings.TrimSpace(param), "=")
		if !found || !strings.EqualFold(strings.TrimSpace(name), "q") {
			continue
		}
		quality, err := strconv.ParseFloat(strings.TrimSpace(value), 64)
		if err != nil || quality < 0 || quality > 1 {
			return 0, false
		}
		return quality, true
	}
	return 1, true
}

// withRequestLanguage는 Accept-Language로 고른 언어를 요청 context에 넣습니다.
// bearer 요청 핸들러는 이 값이 아니라 프로필 language를 씁니다.
func withRequestLanguage(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		language := PickLanguage(r.Header.Get("Accept-Language"))
		ctx := context.WithValue(r.Context(), languageContextKey{}, language)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// LanguageFrom은 withRequestLanguage가 넣은 요청 언어를 돌려줍니다. 없으면 en입니다.
func LanguageFrom(ctx context.Context) string {
	if language, ok := ctx.Value(languageContextKey{}).(string); ok {
		return language
	}
	return defaultLanguage
}
