package provider

import (
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"

	"github.com/coreos/go-oidc/v3/oidc"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

// 이 파일은 카카오·Apple이 함께 쓰는 id_token 검증을 담습니다.
//
// go-oidc(v3.21)를 쓰되, 장애와 토큰 오류를 가르기 위해 두 가지를 덧댑니다.
//
//  1. IDTokenVerifier.Verify는 KeySet 오류를 %v로 감싸 원인 오류를 잃습니다(errors.Is로 찾을 수 없음).
//     그래서 KeySet을 감싼 recordingKeySet이 원래 오류를 먼저 보고, JWKS 조회 실패면
//     요청 ctx에 둔 기록 칸(verifyRecord)에 남깁니다. Verify가 끝난 뒤 이 칸을 보고 분류합니다.
//  2. go-oidc의 RemoteKeySet은 JWKS 응답이 2xx가 아니면 타입 없는 오류를 만들고, 그 문구에 응답 본문을 넣습니다.
//     그래서 JWKS용 http.Client의 Transport(jwksTransport)가 2xx가 아닌 응답, 읽기 실패, JSON이 아닌 본문을
//     타입 있는 jwksFetchError로 바꿔, 본문 없이 원인을 errors.As로 찾을 수 있게 합니다.
//
// RemoteKeySet은 JWKS를 요청 ctx가 아니라 생성할 때 받은 ctx(oidc.ClientContext로 client를 실은 것)로 받아 옵니다.
// 그래서 요청 deadline이 JWKS 호출 자체를 끊지 못하므로, JWKS client에 따로 Timeout(requestTimeout)을 둡니다.
// 요청 쪽은 deadline이 지나면 JWKS 결과를 기다리지 않고 ctx 오류로 돌아옵니다.

// jwksFetchError는 JWKS를 받아 오지 못했음을 뜻합니다. 응답 본문은 담지 않습니다.
type jwksFetchError struct {
	reason string
	err    error
}

func (e *jwksFetchError) Error() string {
	if e.err != nil {
		return "JWKS 조회 실패: " + e.reason + ": " + e.err.Error()
	}
	return "JWKS 조회 실패: " + e.reason
}

func (e *jwksFetchError) Unwrap() error { return e.err }

// jwksTransport는 JWKS 응답을 검사해, 쓸 수 없는 응답을 jwksFetchError로 바꾸는 RoundTripper입니다.
type jwksTransport struct {
	base http.RoundTripper
}

// RoundTrip은 base로 요청을 보내고, 실패나 2xx가 아닌 응답, 읽을 수 없거나 JSON이 아닌 본문을 오류로 바꿉니다.
// 정상 응답은 본문을 메모리로 읽어 다시 담아 돌려줍니다.
func (t jwksTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	resp, err := t.base.RoundTrip(req)
	if err != nil {
		return nil, &jwksFetchError{reason: "요청 실패", err: err}
	}
	if !isSuccessStatus(resp.StatusCode) {
		closeBody(resp.Body)
		return nil, &jwksFetchError{reason: fmt.Sprintf("상태 %d", resp.StatusCode)}
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes))
	closeBody(resp.Body)
	if err != nil {
		return nil, &jwksFetchError{reason: "응답 읽기 실패", err: err}
	}
	if !json.Valid(body) {
		return nil, &jwksFetchError{reason: "JSON이 아닌 응답"}
	}
	resp.Body = io.NopCloser(bytes.NewReader(body))
	resp.ContentLength = int64(len(body))
	return resp, nil
}

// newJWKSClient는 주입받은 client를 바탕으로 JWKS 전용 client를 만듭니다.
// 원본 client는 건드리지 않고 복사본에 jwksTransport와 Timeout을 씌웁니다.
func newJWKSClient(base *http.Client) *http.Client {
	jwksClient := *base
	transport := base.Transport
	if transport == nil {
		transport = http.DefaultTransport
	}
	jwksClient.Transport = jwksTransport{base: transport}
	jwksClient.Timeout = requestTimeout
	return &jwksClient
}

// isJWKSFailure는 KeySet 오류가 JWKS를 받아 오지 못해서 난 것인지 판별합니다.
//   - jwksFetchError: jwksTransport가 만든 오류(연결 실패, 2xx 아님, 본문 이상)
//   - url.Error: http.Client 단계의 실패(client Timeout 등)
//   - context 오류: 요청 deadline이 지나 JWKS 결과를 기다리지 않고 돌아온 경우
func isJWKSFailure(err error) bool {
	var fetchErr *jwksFetchError
	var urlErr *url.Error
	return errors.As(err, &fetchErr) ||
		errors.As(err, &urlErr) ||
		errors.Is(err, context.DeadlineExceeded) ||
		errors.Is(err, context.Canceled)
}

// verifyRecord는 Verify 호출 하나 동안 KeySet이 겪은 일을 남기는 칸입니다.
// go-oidc는 KeySet을 Verify와 같은 고루틴에서 부르므로 잠금이 필요 없습니다.
type verifyRecord struct {
	keySetFailed bool // 서명 검증 단계에서 실패했는지
	jwksFailed   bool // 그 실패가 JWKS 조회 실패인지
}

type verifyRecordKey struct{}

// recordingKeySet은 go-oidc KeySet을 감싸, 서명 검증 실패의 원인을 요청 ctx의 verifyRecord에 남깁니다.
type recordingKeySet struct {
	inner oidc.KeySet
}

// VerifySignature는 inner에 검증을 맡기고, 실패하면 원인을 기록한 뒤 오류를 그대로 돌려줍니다.
func (k recordingKeySet) VerifySignature(ctx context.Context, jwt string) ([]byte, error) {
	payload, err := k.inner.VerifySignature(ctx, jwt)
	if err != nil {
		if record, ok := ctx.Value(verifyRecordKey{}).(*verifyRecord); ok {
			record.keySetFailed = true
			record.jwksFailed = isJWKSFailure(err)
		}
		return nil, err
	}
	return payload, nil
}

// newKeySet은 jwksURL에서 공개 키를 받아 캐시하는 KeySet을 만듭니다.
// 처음 보는 kid가 오면 JWKS를 다시 받습니다(go-oidc RemoteKeySet 동작).
func newKeySet(client *http.Client, jwksURL string) oidc.KeySet {
	ctx := oidc.ClientContext(context.Background(), newJWKSClient(client))
	return recordingKeySet{inner: oidc.NewRemoteKeySet(ctx, jwksURL)}
}

// newVerifier는 RS256 서명만 받는 id_token 검증기를 만듭니다. exp 판정 시각은 clk에서 읽습니다.
func newVerifier(issuer, audience string, keySet oidc.KeySet, clk clock.Clock) *oidc.IDTokenVerifier {
	return oidc.NewVerifier(issuer, keySet, &oidc.Config{
		ClientID:             audience,
		SupportedSigningAlgs: []string{oidc.RS256},
		Now:                  clk.Now,
	})
}

// verifyIDToken은 id_token을 검증하고 nonce가 hex(sha256(rawNonce))와 같은지 확인합니다.
// name은 오류 문구에 쓰는 제공자 이름입니다.
func verifyIDToken(ctx context.Context, verifier *oidc.IDTokenVerifier, name, idToken, rawNonce string) (Identity, error) {
	ctx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()
	record := &verifyRecord{}
	ctx = context.WithValue(ctx, verifyRecordKey{}, record)

	token, err := verifier.Verify(ctx, idToken)
	switch {
	case err == nil:
	case record.jwksFailed:
		// 원인 문구에 JWKS 응답 본문이 섞일 수 있어 go-oidc 오류 문구는 넣지 않습니다.
		return Identity{}, fmt.Errorf("%w: %s id_token: JWKS를 받아 오지 못했습니다", ErrUnavailable, name)
	case record.keySetFailed:
		return Identity{}, fmt.Errorf("%w: %s id_token: 서명 검증 실패", ErrTokenInvalid, name)
	default:
		// 서명 이후 단계(iss·aud·exp·claim 해석)의 go-oidc 문구는 설정 값과 시각만 담고 토큰 원문은 담지 않습니다.
		return Identity{}, fmt.Errorf("%w: %s id_token: %w", ErrTokenInvalid, name, err)
	}

	if !nonceMatches(token.Nonce, rawNonce) {
		return Identity{}, fmt.Errorf("%w: %s id_token: nonce 불일치", ErrTokenInvalid, name)
	}
	if token.Subject == "" {
		return Identity{}, fmt.Errorf("%w: %s id_token: sub가 비어 있습니다", ErrTokenInvalid, name)
	}
	return Identity{Subject: token.Subject}, nil
}

// nonceMatches는 토큰의 nonce claim이 hex(sha256(rawNonce))와 같은지 상수 시간으로 비교합니다.
// app은 nonce 원문을 server로 보내고, 제공자에는 그 해시를 넘깁니다. 그래서 탈취한 id_token만으로는
// 원문을 알 수 없어 재사용할 수 없습니다.
func nonceMatches(tokenNonce, rawNonce string) bool {
	if tokenNonce == "" || rawNonce == "" {
		return false
	}
	sum := sha256.Sum256([]byte(rawNonce))
	want := hex.EncodeToString(sum[:])
	return subtle.ConstantTimeCompare([]byte(tokenNonce), []byte(want)) == 1
}
