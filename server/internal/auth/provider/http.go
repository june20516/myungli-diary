package provider

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
)

// maxResponseBytes는 제공자 응답 본문을 읽는 상한입니다. 정상 응답은 수 KB 이하입니다.
const maxResponseBytes = 1 << 20

// formResponse는 form POST 호출의 결과입니다. 본문은 분류에만 쓰고 오류 문구·로그에 넣지 않습니다.
type formResponse struct {
	status int
	body   []byte
}

// postForm은 form을 application/x-www-form-urlencoded로 POST하고 응답 상태와 본문을 돌려줍니다.
// 호출마다 requestTimeout deadline을 둡니다. 요청을 보내지 못했거나 응답을 끝까지 읽지 못하면
// (연결 실패, timeout 포함) ErrUnavailable로 감싸 돌려줍니다.
// name은 오류 문구에 쓰는 호출 이름(예: "Apple token")입니다.
func postForm(ctx context.Context, client *http.Client, name, endpoint string, form url.Values, header http.Header) (formResponse, error) {
	ctx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return formResponse{}, fmt.Errorf("%s: 요청 생성 실패: %w", name, err)
	}
	for key, values := range header {
		for _, v := range values {
			req.Header.Add(key, v)
		}
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		// url.Error 문구에는 요청 URL만 들어가고 form 값은 들어가지 않습니다.
		return formResponse{}, fmt.Errorf("%w: %s: 요청 실패: %w", ErrUnavailable, name, err)
	}
	defer closeBody(resp.Body)

	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes))
	if err != nil {
		return formResponse{}, fmt.Errorf("%w: %s: 응답 읽기 실패: %w", ErrUnavailable, name, err)
	}
	return formResponse{status: resp.StatusCode, body: body}, nil
}

// isTransientStatus는 잠시 뒤 다시 시도하면 될 수 있는 응답 상태(5xx, 429)인지 알려 줍니다.
func isTransientStatus(status int) bool {
	return status >= http.StatusInternalServerError || status == http.StatusTooManyRequests
}

// isSuccessStatus는 2xx 응답인지 알려 줍니다.
func isSuccessStatus(status int) bool {
	return status >= 200 && status < 300
}

// closeBody는 응답 본문을 닫습니다. 다 읽은 본문을 닫다 난 오류는 결과에 영향이 없어 버립니다.
func closeBody(body io.Closer) {
	if err := body.Close(); err != nil {
		return
	}
}
