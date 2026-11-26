package opsapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/billing"
	"github.com/june20516/myungli-diary/server/internal/ops"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// command는 요청 본문 하나를 처리해 응답 값을 돌려줍니다.
type command func(ctx context.Context, svc *ops.Service, actor ops.Actor, body []byte) (any, error)

// commands는 경로별 명령입니다. 경로에는 사유, 목적, 날짜, 계정 id가 들어가지 않습니다.
func commands() map[string]command {
	return map[string]command{
		"/ops/v1/accounts:show":    showAccount,
		"/ops/v1/grants":           grant,
		"/ops/v1/grants:revoke":    revoke,
		"/ops/v1/content:diary":    viewDiary,
		"/ops/v1/content:schedule": viewSchedule,
		"/ops/v1/content:profile":  viewProfile,
		"/ops/v1/audit:list":       listAudit,
	}
}

// commandHandler는 본문을 읽어 명령을 실행하고 결과나 오류를 JSON으로 씁니다.
func commandHandler(deps Deps, run command) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			var tooLarge *http.MaxBytesError
			if errors.As(err, &tooLarge) {
				writeError(w, newAPIError(http.StatusRequestEntityTooLarge, codeInvalidInput, "요청 본문은 64 KiB 이하여야 합니다"))
				return
			}
			writeError(w, inputErrorf("요청 본문을 읽을 수 없습니다"))
			return
		}
		result, err := run(r.Context(), deps.Service, actorFrom(r.Context()), body)
		if err != nil {
			apiErr, ok := classify(err)
			if !ok {
				deps.Logger.ErrorContext(r.Context(), "ops 내부 오류", "kind", errorKind(err))
				apiErr = newAPIError(http.StatusInternalServerError, codeInternal, internalMessage)
			}
			writeError(w, apiErr)
			return
		}
		payload, err := json.Marshal(result)
		if err != nil {
			deps.Logger.ErrorContext(r.Context(), "ops 응답 직렬화 실패", "kind", errorKind(err))
			writeError(w, newAPIError(http.StatusInternalServerError, codeInternal, internalMessage))
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "no-store")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(append(payload, '\n'))
	})
}

// decodeBody는 본문을 JSON 객체 하나로 읽습니다. 알 수 없는 칸, 객체가 아닌 값, 뒤따르는 값은 거절합니다.
// 오류 문구에는 요청 값을 담지 않습니다.
func decodeBody[T any](body []byte) (T, error) {
	var req T
	trimmed := bytes.TrimSpace(body)
	if len(trimmed) == 0 || trimmed[0] != '{' {
		return req, inputErrorf("요청 본문은 JSON 객체 하나여야 합니다")
	}
	dec := json.NewDecoder(bytes.NewReader(trimmed))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		return req, inputErrorf("요청 본문 형식이 올바르지 않습니다(알 수 없는 칸이나 잘못된 값 형식)")
	}
	if _, err := dec.Token(); !errors.Is(err, io.EOF) {
		return req, inputErrorf("요청 본문은 JSON 객체 하나여야 합니다")
	}
	return req, nil
}

// parseAccountID는 선택 계정 id를 읽습니다. 비어 있으면 uuid.Nil입니다.
func parseAccountID(raw string) (uuid.UUID, error) {
	if raw == "" {
		return uuid.Nil, nil
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, inputErrorf("accountId는 uuid여야 합니다")
	}
	return id, nil
}

// requireAccountID는 필수 계정 id를 읽습니다.
func requireAccountID(raw string) (uuid.UUID, error) {
	id, err := parseAccountID(raw)
	if err != nil {
		return uuid.Nil, err
	}
	if id == uuid.Nil {
		return uuid.Nil, inputErrorf("accountId가 필요합니다")
	}
	return id, nil
}

type showAccountRequest struct {
	AccountID        string `json:"accountId"`
	StoreTransaction string `json:"storeTransaction"`
	Reason           string `json:"reason"`
}

func showAccount(ctx context.Context, svc *ops.Service, actor ops.Actor, body []byte) (any, error) {
	req, err := decodeBody[showAccountRequest](body)
	if err != nil {
		return nil, err
	}
	accountID, err := parseAccountID(req.AccountID)
	if err != nil {
		return nil, err
	}
	return svc.AccountSummary(ctx, actor, ops.AccountKey{AccountID: accountID, StoreTransaction: req.StoreTransaction}, req.Reason)
}

type grantRequest struct {
	AccountID   string `json:"accountId"`
	Entitlement string `json:"entitlement"`
	Days        int    `json:"days"`
	Until       string `json:"until"`
	Reason      string `json:"reason"`
}

func grant(ctx context.Context, svc *ops.Service, actor ops.Actor, body []byte) (any, error) {
	req, err := decodeBody[grantRequest](body)
	if err != nil {
		return nil, err
	}
	accountID, err := requireAccountID(req.AccountID)
	if err != nil {
		return nil, err
	}
	grantReq := ops.GrantRequest{
		AccountID: accountID, Kind: billing.OperatorKind(req.Entitlement), Days: req.Days, Reason: req.Reason,
	}
	if req.Until != "" {
		if grantReq.ExpiresAt, err = time.Parse(time.RFC3339, req.Until); err != nil {
			return nil, inputErrorf("until은 RFC 3339 시각이어야 합니다")
		}
	}
	return svc.Grant(ctx, actor, grantReq)
}

type revokeRequest struct {
	AccountID string `json:"accountId"`
	GrantID   int64  `json:"grantId"`
	Reason    string `json:"reason"`
}

func revoke(ctx context.Context, svc *ops.Service, actor ops.Actor, body []byte) (any, error) {
	req, err := decodeBody[revokeRequest](body)
	if err != nil {
		return nil, err
	}
	accountID, err := requireAccountID(req.AccountID)
	if err != nil {
		return nil, err
	}
	if req.GrantID <= 0 {
		return nil, inputErrorf("grantId는 양수여야 합니다")
	}
	return svc.Revoke(ctx, actor, ops.RevokeRequest{AccountID: accountID, GrantID: req.GrantID, Reason: req.Reason})
}

type viewRequest struct {
	AccountID string `json:"accountId"`
	Date      string `json:"date"`
	ID        string `json:"id"`
	Purpose   string `json:"purpose"`
	Reason    string `json:"reason"`
}

// toViewRequest는 일기와 일정 열람 본문을 Service 요청으로 바꿉니다. 날짜와 id 중 하나만 있어야 하는 검사는 Service가 합니다.
func toViewRequest(body []byte) (ops.ViewRequest, error) {
	req, err := decodeBody[viewRequest](body)
	if err != nil {
		return ops.ViewRequest{}, err
	}
	accountID, err := requireAccountID(req.AccountID)
	if err != nil {
		return ops.ViewRequest{}, err
	}
	purpose, err := ops.ParsePurpose(req.Purpose)
	if err != nil {
		return ops.ViewRequest{}, err
	}
	target := ops.ContentTarget{AccountID: accountID}
	if req.Date != "" {
		parsed, err := time.Parse(time.DateOnly, req.Date)
		if err != nil {
			return ops.ViewRequest{}, inputErrorf("date는 YYYY-MM-DD여야 합니다")
		}
		target.Date = &profile.LocalDate{Year: parsed.Year(), Month: int(parsed.Month()), Day: parsed.Day()}
	}
	if req.ID != "" {
		id, err := uuid.Parse(req.ID)
		if err != nil {
			return ops.ViewRequest{}, inputErrorf("id는 uuid여야 합니다")
		}
		target.ID = &id
	}
	return ops.ViewRequest{Target: target, Purpose: purpose, Reason: req.Reason}, nil
}

func viewDiary(ctx context.Context, svc *ops.Service, actor ops.Actor, body []byte) (any, error) {
	req, err := toViewRequest(body)
	if err != nil {
		return nil, err
	}
	return svc.ViewDiary(ctx, actor, req)
}

func viewSchedule(ctx context.Context, svc *ops.Service, actor ops.Actor, body []byte) (any, error) {
	req, err := toViewRequest(body)
	if err != nil {
		return nil, err
	}
	return svc.ViewSchedule(ctx, actor, req)
}

type viewProfileRequest struct {
	AccountID string `json:"accountId"`
	Purpose   string `json:"purpose"`
	Reason    string `json:"reason"`
}

func viewProfile(ctx context.Context, svc *ops.Service, actor ops.Actor, body []byte) (any, error) {
	req, err := decodeBody[viewProfileRequest](body)
	if err != nil {
		return nil, err
	}
	accountID, err := requireAccountID(req.AccountID)
	if err != nil {
		return nil, err
	}
	purpose, err := ops.ParsePurpose(req.Purpose)
	if err != nil {
		return nil, err
	}
	return svc.ViewProfile(ctx, actor, accountID, purpose, req.Reason)
}

type listAuditRequest struct {
	AccountID string `json:"accountId"`
	Since     string `json:"since"`
	Limit     int    `json:"limit"`
	Reason    string `json:"reason"`
}

func listAudit(ctx context.Context, svc *ops.Service, actor ops.Actor, body []byte) (any, error) {
	req, err := decodeBody[listAuditRequest](body)
	if err != nil {
		return nil, err
	}
	accountID, err := parseAccountID(req.AccountID)
	if err != nil {
		return nil, err
	}
	filter := ops.AuditFilter{Limit: req.Limit}
	if accountID != uuid.Nil {
		filter.AccountID = &accountID
	}
	if req.Since != "" {
		since, err := time.Parse(time.DateOnly, req.Since)
		if err != nil {
			return nil, inputErrorf("since는 YYYY-MM-DD(UTC)여야 합니다")
		}
		filter.Since = &since
	}
	return svc.AuditList(ctx, actor, filter, req.Reason)
}
