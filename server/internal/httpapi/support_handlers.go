package httpapi

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/support"
)

// InquirySubmitter는 문의 접수 핸들러가 쓰는 서비스입니다. *support.Service가 만족합니다.
type InquirySubmitter interface {
	Submit(ctx context.Context, accountID uuid.UUID, in support.Inquiry) error
}

var _ InquirySubmitter = (*support.Service)(nil)

// CreateInquiry는 앱 안 문의를 운영 메일함으로 보내고 204입니다(D102, S134).
// 한도 초과는 429와 Retry-After, 메일을 보낼 수 없으면 503입니다. Idempotency-Key는 멱등 미들웨어가 다룹니다.
// 문의 내용과 답장 주소는 로그에 남기지 않습니다.
func (a *API) CreateInquiry(ctx context.Context, req gen.CreateInquiryRequestObject) (gen.CreateInquiryResponseObject, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return nil, errNoAccount
	}
	if a.Inquiries == nil {
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	err := a.Inquiries.Submit(ctx, id, support.Inquiry{
		Message:     req.Body.Message,
		ReplyEmail:  string(req.Body.ReplyEmail),
		AppVersion:  req.Body.AppVersion,
		OS:          req.Body.Os,
		DeviceModel: req.Body.DeviceModel,
		Language:    LanguageFrom(ctx),
	})
	var limited *support.RateLimitedError
	switch {
	case err == nil:
		return gen.CreateInquiry204Response{}, nil
	case errors.As(err, &limited):
		out := newError(problem.RateLimited, "Too many requests")
		out.RetryAfter = ceilSeconds(limited.RetryAfter)
		return nil, out
	case errors.Is(err, support.ErrInvalidReplyEmail):
		out := newError(problem.RequestInvalid, "Request does not match the contract")
		out.Errors = []problem.FieldError{{Field: "/replyEmail", Code: "format"}}
		return nil, out
	case errors.Is(err, support.ErrUnavailable):
		// 원인(발송 서비스 응답)은 운영자가 알아야 하므로 남깁니다. 오류 문구에는 문의 내용이 들어가지 않습니다.
		a.logger().ErrorContext(ctx, "문의 메일을 보내지 못했습니다", "accountId", id, "error", err.Error())
		return nil, newError(problem.ServiceUnavailable, "Service unavailable")
	default:
		return nil, err
	}
}
