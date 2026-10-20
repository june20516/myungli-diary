package httpapi

import (
	"context"
	"time"

	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/preview"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// 미리보기 요청 본문에서 검증 위반이 가리키는 위치(JSON Pointer)입니다.
const (
	pointerPreviewBirth    = "/birth"
	pointerPreviewTimezone = "/currentTimezone"
)

// previewReleaseTimeout은 응답을 못 준 미리보기의 선점을 푸는 데 기다리는 최대 시간입니다.
const previewReleaseTimeout = 5 * time.Second

// PreviewService는 미리보기 핸들러가 쓰는 화면 묶음입니다. *fortune.Views가 만족합니다.
type PreviewService interface {
	Preview(ctx context.Context, b profile.Birth, currentTimezone, lang string) (fortune.PreviewView, error)
}

var _ PreviewService = (*fortune.Views)(nil)

// PreviewUsage는 설치별 1회 사용 기록입니다. *preview.Usage가 만족합니다.
type PreviewUsage interface {
	Claim(ctx context.Context, installationID string) (bool, error)
	Release(ctx context.Context, installationID string) error
}

var _ PreviewUsage = (*preview.Usage)(nil)

// CreatePreview는 로그인 없이 오늘의 총운 미리보기를 한 번 돌려줍니다. 입력은 저장하지 않고 설치 id의 SHA-256만 1회 기록에 남깁니다.
// 언어는 Accept-Language, 날짜는 currentTimezone의 오늘이며 evidenceAccess는 늘 locked입니다.
// 출생 정보·시간대 검증 실패는 선점 전에 422로 끝냅니다. 선점 뒤 엔진·렌더 실패로 응답을 못 주면 선점을 풀어 같은 설치가 다시 쓰게 합니다(P6-4).
// 이미 쓴 설치는 403 preview.used, 활성 콘텐츠 시드가 없거나 Previews·PreviewUsage가 조립되지 않았으면 503 service.unavailable입니다.
// App Check는 register.go가 operation 단위로 감쌉니다.
func (a *API) CreatePreview(ctx context.Context, req gen.CreatePreviewRequestObject) (gen.CreatePreviewResponseObject, error) {
	if a.Previews == nil || a.PreviewUsage == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	body := *req.Body
	birth, err := toBirth(body.Birth)
	if err != nil {
		return nil, err
	}
	birth, err = profile.ValidateBirth(birth, pointerPreviewBirth)
	if err != nil {
		return nil, err
	}
	if err := profile.ValidateTimezone(body.CurrentTimezone, pointerPreviewTimezone); err != nil {
		return nil, err
	}

	claimed, err := a.PreviewUsage.Claim(ctx, body.InstallationId)
	if err != nil {
		return nil, err
	}
	if !claimed {
		return nil, newError(problem.PreviewUsed, "Preview already used")
	}
	delivered := false
	defer func() {
		if !delivered {
			a.releasePreview(ctx, body.InstallationId)
		}
	}()

	view, err := a.Previews.Preview(ctx, birth, body.CurrentTimezone, LanguageFrom(ctx))
	if err != nil {
		return nil, profile.EngineBirthViolation(err, pointerPreviewBirth)
	}
	out, err := toPreview(view)
	if err != nil {
		return nil, err
	}
	delivered = true
	return gen.CreatePreview200JSONResponse(out), nil
}

// releasePreview는 응답을 못 준 요청의 선점을 풉니다. 연결이 끊겨 ctx가 취소돼도 풀 수 있게 취소를 떼어 냅니다(멱등 미들웨어와 같은 이유).
// 실패는 응답에 영향을 주지 않으므로 로그만 남깁니다(설치 id는 남기지 않습니다).
func (a *API) releasePreview(ctx context.Context, installationID string) {
	detached, cancel := context.WithTimeout(context.WithoutCancel(ctx), previewReleaseTimeout)
	defer cancel()
	if err := a.PreviewUsage.Release(detached, installationID); err != nil && a.Logger != nil {
		a.Logger.ErrorContext(detached, "미리보기 선점 해제 실패", "error", err)
	}
}
