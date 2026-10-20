package billing

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

const testAPIKey = "sk_test_secret_key"

// newTestRevenueCat은 handler를 서버로 띄우고 그 주소를 쓰는 클라이언트를 만듭니다.
func newTestRevenueCat(t *testing.T, handler http.HandlerFunc) *RevenueCat {
	t.Helper()
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)
	return NewRevenueCat(RevenueCatConfig{ProjectID: "proj_test", APIKey: testAPIKey, BaseURL: server.URL})
}

func TestRevenueCat_Purchases_요청_모양과_해석(t *testing.T) {
	var mu sync.Mutex
	var gotPath, gotQuery, gotAuth string
	client := newTestRevenueCat(t, func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		gotPath, gotQuery, gotAuth = r.URL.EscapedPath(), r.URL.RawQuery, r.Header.Get("Authorization")
		_, _ = w.Write([]byte(`{"object":"list","next_page":null,"items":[
			{"id":"pur_1","product_id":"test.ad_free.month","purchased_at":1760918400123,"status":"owned","environment":"production","unknown":{"a":1}},
			{"id":"pur_2","product_id":"test.other","purchased_at":1760918400000,"status":"refunded","environment":"sandbox"}]}`))
	})

	got, err := client.Purchases(context.Background(), "cust-1")
	if err != nil {
		t.Fatalf("Purchases() error = %v", err)
	}
	mu.Lock()
	defer mu.Unlock()
	if gotPath != "/v2/projects/proj_test/customers/cust-1/purchases" || gotQuery != "limit=100" {
		t.Errorf("요청 = %s?%s, want 경로와 limit=100", gotPath, gotQuery)
	}
	if gotAuth != "Bearer "+testAPIKey {
		t.Errorf("Authorization = %q, want Bearer 키", gotAuth)
	}
	if len(got) != 2 {
		t.Fatalf("구매 %d건, want 2건", len(got))
	}
	first := got[0]
	if first.ID != "pur_1" || first.ProductID != "test.ad_free.month" || first.Refunded || !first.Production {
		t.Errorf("첫 구매 = %+v", first)
	}
	if want := time.UnixMilli(1760918400123).UTC(); !first.PurchasedAt.Equal(want) || first.PurchasedAt.Location() != time.UTC {
		t.Errorf("PurchasedAt = %v, want UTC %v", first.PurchasedAt, want)
	}
	if second := got[1]; !second.Refunded || second.Production {
		t.Errorf("둘째 구매 = %+v, want 환불·sandbox", second)
	}
}

func TestRevenueCat_Purchases_다음_페이지는_starting_after로_이어_받음(t *testing.T) {
	var mu sync.Mutex
	var queries []string
	client := newTestRevenueCat(t, func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		queries = append(queries, r.URL.RawQuery)
		mu.Unlock()
		if r.URL.Query().Get("starting_after") == "" {
			_, _ = w.Write([]byte(`{"items":[{"id":"pur_1","product_id":"p","purchased_at":1,"status":"owned","environment":"production"}],"next_page":"/v2/other?x=1"}`))
			return
		}
		_, _ = w.Write([]byte(`{"items":[{"id":"pur_2","product_id":"p","purchased_at":2,"status":"owned","environment":"production"}],"next_page":null}`))
	})

	got, err := client.Purchases(context.Background(), "cust-1")
	if err != nil || len(got) != 2 || got[0].ID != "pur_1" || got[1].ID != "pur_2" {
		t.Fatalf("Purchases() = %+v, %v, want 두 페이지의 구매 2건", got, err)
	}
	if len(queries) != 2 || queries[1] != "limit=100&starting_after=pur_1" {
		t.Errorf("요청 쿼리 = %v, want 둘째에 starting_after=pur_1", queries)
	}
}

func TestRevenueCat_Purchases_페이지_상한을_넘으면_오류(t *testing.T) {
	var calls atomic.Int32
	client := newTestRevenueCat(t, func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		_, _ = w.Write([]byte(`{"items":[{"id":"pur_x","product_id":"p","purchased_at":1,"status":"owned","environment":"production"}],"next_page":"more"}`))
	})

	_, err := client.Purchases(context.Background(), "cust-1")
	if err == nil || errors.Is(err, ErrProviderUnavailable) {
		t.Errorf("error = %v, want ErrProviderUnavailable이 아닌 오류", err)
	}
	if int(calls.Load()) != maxPurchasePages {
		t.Errorf("요청 %d번, want %d번", calls.Load(), maxPurchasePages)
	}
}

func TestRevenueCat_Purchases_빈_next_page_항목이_없으면_멈춤(t *testing.T) {
	var calls atomic.Int32
	client := newTestRevenueCat(t, func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		_, _ = w.Write([]byte(`{"items":[],"next_page":"more"}`))
	})

	got, err := client.Purchases(context.Background(), "cust-1")
	if err != nil || len(got) != 0 || calls.Load() != 1 {
		t.Errorf("Purchases() = %+v, %v (요청 %d번), want 빈 목록, nil, 1번", got, err, calls.Load())
	}
}

func TestRevenueCat_Purchases_404는_구매_없음(t *testing.T) {
	client := newTestRevenueCat(t, func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, `{"type":"resource_missing"}`, http.StatusNotFound)
	})

	got, err := client.Purchases(context.Background(), "cust-1")
	if err != nil || len(got) != 0 {
		t.Errorf("Purchases() = %+v, %v, want 빈 목록, nil", got, err)
	}
}

func TestRevenueCat_Purchases_장애는_ErrProviderUnavailable(t *testing.T) {
	cases := map[string]http.HandlerFunc{
		"500":      func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusInternalServerError) },
		"503":      func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusServiceUnavailable) },
		"429":      func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusTooManyRequests) },
		"형식 오류":    func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte(`not json`)) },
		"items 없음": func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte(`{"object":"list"}`)) },
		"시각 형식 오류": func(w http.ResponseWriter, r *http.Request) {
			_, _ = w.Write([]byte(`{"items":[{"id":"a","purchased_at":"x"}]}`))
		},
	}
	for name, handler := range cases {
		t.Run(name, func(t *testing.T) {
			client := newTestRevenueCat(t, handler)
			if _, err := client.Purchases(context.Background(), "cust-1"); !errors.Is(err, ErrProviderUnavailable) {
				t.Errorf("error = %v, want ErrProviderUnavailable", err)
			}
		})
	}

	t.Run("연결 실패", func(t *testing.T) {
		server := httptest.NewServer(http.NotFoundHandler())
		baseURL := server.URL
		server.Close()
		client := NewRevenueCat(RevenueCatConfig{ProjectID: "p", APIKey: testAPIKey, BaseURL: baseURL})
		_, err := client.Purchases(context.Background(), "cust-1")
		if !errors.Is(err, ErrProviderUnavailable) {
			t.Errorf("error = %v, want ErrProviderUnavailable", err)
		}
		if err != nil && strings.Contains(err.Error(), testAPIKey) {
			t.Errorf("오류 문구에 키가 있습니다: %v", err)
		}
	})
}

func TestRevenueCat_Purchases_인증_오류는_설정_문제(t *testing.T) {
	for _, status := range []int{http.StatusUnauthorized, http.StatusForbidden} {
		client := newTestRevenueCat(t, func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(status)
			_, _ = w.Write([]byte(`{"echo":"Bearer ` + testAPIKey + `"}`))
		})
		_, err := client.Purchases(context.Background(), "cust-1")
		if err == nil || errors.Is(err, ErrProviderUnavailable) {
			t.Errorf("status %d error = %v, want ErrProviderUnavailable이 아닌 오류", status, err)
			continue
		}
		if strings.Contains(err.Error(), testAPIKey) {
			t.Errorf("오류 문구에 키가 있습니다: %v", err)
		}
	}
}

func TestRevenueCat_Purchases_customer_id는_경로에서_escape(t *testing.T) {
	var mu sync.Mutex
	var gotPath string
	client := newTestRevenueCat(t, func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		gotPath = r.URL.EscapedPath()
		mu.Unlock()
		_, _ = w.Write([]byte(`{"items":[]}`))
	})

	if _, err := client.Purchases(context.Background(), "a/b?c#d"); err != nil {
		t.Fatalf("Purchases() error = %v", err)
	}
	mu.Lock()
	defer mu.Unlock()
	if want := "/v2/projects/proj_test/customers/a%2Fb%3Fc%23d/purchases"; gotPath != want {
		t.Errorf("경로 = %s, want %s", gotPath, want)
	}
}

func TestRevenueCat_Purchases_마지막_항목_id가_비면_형식_오류(t *testing.T) {
	var calls atomic.Int32
	client := newTestRevenueCat(t, func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		_, _ = w.Write([]byte(`{"items":[{"id":"","product_id":"p","purchased_at":1,"status":"owned","environment":"production"}],"next_page":"more"}`))
	})

	_, err := client.Purchases(context.Background(), "cust-1")
	if !errors.Is(err, ErrProviderUnavailable) || calls.Load() != 1 {
		t.Errorf("error = %v (요청 %d번), want ErrProviderUnavailable과 1번", err, calls.Load())
	}
}

func TestRevenueCat_Purchases_둘째_페이지_404는_장애(t *testing.T) {
	client := newTestRevenueCat(t, func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("starting_after") == "" {
			_, _ = w.Write([]byte(`{"items":[{"id":"pur_1","product_id":"p","purchased_at":1,"status":"owned","environment":"production"}],"next_page":"more"}`))
			return
		}
		http.NotFound(w, r)
	})

	got, err := client.Purchases(context.Background(), "cust-1")
	if !errors.Is(err, ErrProviderUnavailable) || got != nil {
		t.Errorf("Purchases() = %+v, %v, want nil, ErrProviderUnavailable", got, err)
	}
}
