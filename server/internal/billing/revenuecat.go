package billing

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

const (
	// defaultRevenueCatURL은 RevenueCat REST API 주소입니다.
	defaultRevenueCatURL = "https://api.revenuecat.com"
	// requestTimeout은 RevenueCat 호출 한 번에 주는 최대 시간입니다.
	requestTimeout = 10 * time.Second
	// maxResponseBytes는 응답 본문을 읽는 상한입니다(auth/provider와 같은 값).
	maxResponseBytes = 1 << 20
	// purchasesPageSize는 구매 목록 한 페이지의 항목 수입니다(v2 상한 100).
	purchasesPageSize = 100
	// maxPurchasePages는 한 번의 조회에서 따라가는 페이지 상한입니다. 끝없는 페이지를 막습니다.
	maxPurchasePages = 20
)

// ErrProviderUnavailable은 RevenueCat을 부를 수 없다는 뜻입니다(연결 실패, timeout, 5xx, 429, 형식이 틀린 응답).
// 401·403 같은 설정 문제는 이 오류로 감싸지 않고 그대로 드러냅니다.
var ErrProviderUnavailable = errors.New("RevenueCat을 사용할 수 없습니다")

// Purchase는 RevenueCat이 알려 준 구매 한 건입니다.
type Purchase struct {
	ID        string
	ProductID string
	// Store는 RevenueCat 스토어 이름입니다(app_store, play_store 등).
	Store       string
	PurchasedAt time.Time
	// Refunded는 환불된 구매인지 나타냅니다(status가 refunded).
	Refunded bool
	// Production은 production 환경 구매인지 나타냅니다(false면 sandbox).
	Production bool
}

// RevenueCatConfig는 RevenueCat 클라이언트 설정입니다.
type RevenueCatConfig struct {
	ProjectID string
	// APIKey는 REST v2 secret key입니다.
	APIKey     string
	HTTPClient *http.Client
	// BaseURL이 비면 https://api.revenuecat.com입니다(테스트에서 바꿉니다).
	BaseURL string
}

// RevenueCat은 RevenueCat REST v2 클라이언트입니다.
type RevenueCat struct {
	projectID string
	apiKey    string
	client    *http.Client
	baseURL   string
}

// NewRevenueCat은 클라이언트를 만듭니다. HTTPClient가 nil이면 http.DefaultClient를 씁니다.
func NewRevenueCat(cfg RevenueCatConfig) *RevenueCat {
	client := cfg.HTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	baseURL := cfg.BaseURL
	if baseURL == "" {
		baseURL = defaultRevenueCatURL
	}
	return &RevenueCat{projectID: cfg.ProjectID, apiKey: cfg.APIKey, client: client, baseURL: baseURL}
}

// purchasesPage는 구매 목록 응답에서 쓰는 필드입니다. 모르는 필드는 무시합니다.
type purchasesPage struct {
	Items []struct {
		ID          string `json:"id"`
		ProductID   string `json:"product_id"`
		PurchasedAt int64  `json:"purchased_at"`
		Status      string `json:"status"`
		Environment string `json:"environment"`
	} `json:"items"`
	NextPage *string `json:"next_page"`
}

// Purchases는 고객의 구매 목록을 모두 받아 돌려줍니다. 고객이 없으면(404) 빈 목록입니다.
// 오류 문구에는 API 키를 넣지 않습니다.
func (r *RevenueCat) Purchases(ctx context.Context, customerID string) ([]Purchase, error) {
	var purchases []Purchase
	startingAfter := ""
	for range maxPurchasePages {
		page, found, err := r.fetchPage(ctx, customerID, startingAfter)
		if err != nil {
			return nil, err
		}
		if !found {
			// 404는 첫 페이지에서만 구매 없음입니다. 이어 받던 중이면 부분 목록으로 권한을 계산하지 않도록 장애로 봅니다.
			if startingAfter != "" {
				return nil, fmt.Errorf("%w: 다음 페이지를 찾을 수 없습니다", ErrProviderUnavailable)
			}
			return nil, nil
		}
		for _, item := range page.Items {
			purchases = append(purchases, Purchase{
				ID:          item.ID,
				ProductID:   item.ProductID,
				PurchasedAt: time.UnixMilli(item.PurchasedAt).UTC(),
				Refunded:    item.Status == "refunded",
				Production:  item.Environment == "production",
			})
		}
		// next_page의 정확한 형태가 문서로 확정되지 않아, 값이 있으면 다음 페이지가 있다고만 보고
		// 마지막 item의 id를 starting_after로 보냅니다(경로를 따라가 다른 호스트로 요청하는 일을 막음).
		if page.NextPage == nil || *page.NextPage == "" || len(page.Items) == 0 {
			return purchases, nil
		}
		startingAfter = page.Items[len(page.Items)-1].ID
		if startingAfter == "" {
			// 커서가 없으면 첫 페이지를 다시 받게 되므로 형식 오류로 봅니다.
			return nil, fmt.Errorf("%w: 마지막 구매의 id가 없습니다", ErrProviderUnavailable)
		}
	}
	return nil, fmt.Errorf("RevenueCat 구매 목록이 %d페이지를 넘었습니다", maxPurchasePages)
}

// fetchPage는 구매 목록 한 페이지를 받습니다. found가 false면 고객이 없는 것입니다(404).
// 오류 문구에 API 키·응답 본문을 넣지 않습니다(호출자가 로그에 그대로 남김).
func (r *RevenueCat) fetchPage(ctx context.Context, customerID, startingAfter string) (page purchasesPage, found bool, err error) {
	ctx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	query := url.Values{"limit": {strconv.Itoa(purchasesPageSize)}}
	if startingAfter != "" {
		query.Set("starting_after", startingAfter)
	}
	endpoint := r.baseURL + "/v2/projects/" + url.PathEscape(r.projectID) +
		"/customers/" + url.PathEscape(customerID) + "/purchases?" + query.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return purchasesPage{}, false, fmt.Errorf("RevenueCat 요청 생성 실패: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Accept", "application/json")

	resp, err := r.client.Do(req)
	if err != nil {
		// url.Error 문구에는 요청 URL만 들어가고 헤더(키)는 들어가지 않습니다.
		return purchasesPage{}, false, fmt.Errorf("%w: 요청 실패: %w", ErrProviderUnavailable, err)
	}
	defer func() { _ = resp.Body.Close() }()

	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes))
	if err != nil {
		return purchasesPage{}, false, fmt.Errorf("%w: 응답 읽기 실패: %w", ErrProviderUnavailable, err)
	}

	switch {
	case resp.StatusCode == http.StatusNotFound:
		return purchasesPage{}, false, nil
	case resp.StatusCode >= http.StatusInternalServerError || resp.StatusCode == http.StatusTooManyRequests:
		return purchasesPage{}, false, fmt.Errorf("%w: 상태 %d", ErrProviderUnavailable, resp.StatusCode)
	case resp.StatusCode < 200 || resp.StatusCode >= 300:
		// 401·403 등은 설정 문제라 ErrProviderUnavailable로 감싸지 않습니다. 본문은 문구에 넣지 않습니다.
		return purchasesPage{}, false, fmt.Errorf("RevenueCat 구매 목록 요청이 거절되었습니다: 상태 %d", resp.StatusCode)
	}

	if err := json.Unmarshal(body, &page); err != nil || page.Items == nil {
		return purchasesPage{}, false, fmt.Errorf("%w: 응답 형식이 올바르지 않습니다", ErrProviderUnavailable)
	}
	return page, true, nil
}
