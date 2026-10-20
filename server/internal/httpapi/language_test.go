package httpapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestPickLanguage(t *testing.T) {
	tests := []struct {
		name   string
		header string
		want   string
	}{
		{"빈 값", "", "en"},
		{"지역 태그는 주 태그로", "ko-KR,ko;q=0.9,en;q=0.8", "ko"},
		{"지원하지 않는 언어는 건너뜀", "fr;q=1, ja;q=0.5", "ja"},
		{"q값 순서", "ja;q=0.3, en;q=0.7", "en"},
		{"와일드카드", "*", "en"},
		{"q=0은 제외", "ko;q=0", "en"},
		{"잘못된 q값 항목은 무시", "ko;q=x", "en"},
		{"잘못된 항목 뒤의 유효 항목", "ko;q=x, ja;q=0.4", "ja"},
		{"q 같으면 앞선 항목", "ja, ko", "ja"},
		{"대소문자 무시", "KO-kr", "ko"},
		{"NaN은 무효", "ko;q=NaN, ja;q=0.9", "ja"},
		{"지수 표기는 무효", "ko;q=1e-1", "en"},
		{"소수 넷째 자리는 무효", "ko;q=0.1234", "en"},
		{"1 초과는 무효", "ko;q=1.001", "en"},
		{"부호는 무효", "ko;q=+0.5", "en"},
		{"세미콜론 앞 공백", "ko ; q=0.9", "ko"},
		{"대문자 Q", "ko;Q=0.9", "ko"},
		{"같은 q면 앞선 항목(사전순 뒤)", "ko;q=0.5, ja;q=0.5", "ko"},
		{"같은 q면 앞선 항목(사전순 앞)", "ko;q=0.5, en;q=0.5", "ko"},
		{"세 항목", "en;q=0.2, ja;q=0.8, ko;q=0.8", "ja"},
		{"범위를 벗어난 q값 무시", "ko;q=2, ja;q=0.5", "ja"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := PickLanguage(tt.header); got != tt.want {
				t.Errorf("PickLanguage(%q) = %q, want %q", tt.header, got, tt.want)
			}
		})
	}
}

func TestRequestLanguageMiddleware(t *testing.T) {
	var got string
	handler := withRequestLanguage(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		got = LanguageFrom(r.Context())
	}))

	req := httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/", nil)
	req.Header.Add("Accept-Language", "en;q=0.5")
	req.Header.Add("Accept-Language", "ja")
	handler.ServeHTTP(httptest.NewRecorder(), req)
	if got != "ja" {
		t.Errorf("LanguageFrom = %q, want ja", got)
	}
}

func TestLanguageFromDefault(t *testing.T) {
	req := httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/", nil)
	if got := LanguageFrom(req.Context()); got != "en" {
		t.Errorf("middleware 없이 LanguageFrom = %q, want en", got)
	}
}
