package httpapi

import (
	"context"
	"net/http"

	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// RawRequest는 strict 핸들러가 생성 타입으로 받지 못하는 원본 요청 값입니다(P7-10).
// webhook은 Authorization을 직접 검증하고(계약에 security·parameter로 적지 않음), AdMob SSV는 원본 쿼리 바이트로 서명을 검증합니다.
type RawRequest struct {
	Authorization string
	RawQuery      string
}

// rawRequestKey는 RawRequest를 담는 context key입니다.
type rawRequestKey struct{}

// RawRequestFrom은 withRawRequest가 넣은 RawRequest를 돌려줍니다. 대상 operation이 아니면 빈 값입니다.
func RawRequestFrom(ctx context.Context) RawRequest {
	raw, _ := ctx.Value(rawRequestKey{}).(RawRequest)
	return raw
}

// withRawRequest는 operations(계약 표기 operationId, 예 "revenuecatWebhook")에서만 RawRequest를 ctx에 넣는 strict middleware입니다.
// 생성 코드는 operationID를 Go 이름("RevenuecatWebhook")으로 넘기므로 contractOperationID로 계약 표기에 맞춰 비교합니다.
// 다른 operation의 핸들러는 Authorization 원문을 읽을 수 없게 그대로 둡니다.
func withRawRequest(operations ...string) gen.StrictMiddlewareFunc {
	targets := make(map[string]bool, len(operations))
	for _, operation := range operations {
		targets[operation] = true
	}
	return func(next gen.StrictHandlerFunc, operationID string) gen.StrictHandlerFunc {
		if !targets[contractOperationID(operationID)] {
			return next
		}
		return func(ctx context.Context, w http.ResponseWriter, r *http.Request, request any) (any, error) {
			raw := RawRequest{Authorization: r.Header.Get("Authorization"), RawQuery: r.URL.RawQuery}
			return next(context.WithValue(ctx, rawRequestKey{}, raw), w, r, request)
		}
	}
}
