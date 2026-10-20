package billing

import (
	"context"
	"crypto/ecdsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/clock"
)

const (
	// defaultAdMobKeysURL은 AdMob SSV 공개 키 목록 주소입니다.
	defaultAdMobKeysURL = "https://www.gstatic.com/admob/reward/verifier-keys.json"
	// adMobKeysTTL은 받은 키를 쓰는 최대 시간입니다(문서가 24시간을 넘기지 말라고 권함, P7-11).
	adMobKeysTTL = 24 * time.Hour
	// adMobUnknownKeyRefetch는 모르는 key_id 때문에 키 서버를 다시 부르는 최소 간격입니다.
	adMobUnknownKeyRefetch = time.Minute
	// rewardTimestampTolerance는 콜백 timestamp와 현재 시각의 허용 차이입니다(과거·미래 모두).
	rewardTimestampTolerance = time.Hour
	// signatureMarker는 서명 대상의 끝을 알리는 쿼리 조각입니다. 서명 대상에는 이 앞까지만 들어갑니다.
	signatureMarker = "&signature="
)

var (
	// ErrRewardSignature는 서명 또는 콜백 형식이 올바르지 않다는 뜻입니다(알 수 없는 key_id 포함).
	ErrRewardSignature = errors.New("보상 콜백 서명이 올바르지 않습니다")
	// ErrRewardExpired는 콜백 timestamp가 현재 시각에서 1시간 넘게 벗어났다는 뜻입니다.
	ErrRewardExpired = errors.New("보상 콜백이 만료되었습니다")
	// ErrRewardKeysUnavailable은 AdMob 공개 키 목록을 받지 못했다는 뜻입니다.
	ErrRewardKeysUnavailable = errors.New("AdMob 공개 키를 받을 수 없습니다")
)

// RewardCallback은 서명이 검증된 보상형 광고 콜백의 값입니다.
type RewardCallback struct {
	TransactionID string
	// UserID는 없을 수 있습니다(빈 문자열).
	UserID     string
	AdUnit     string
	RewardItem string
	Timestamp  time.Time
}

// RewardVerifierConfig는 RewardVerifier 설정입니다.
type RewardVerifierConfig struct {
	// KeysURL이 비면 운영 주소입니다(테스트에서 바꿉니다).
	KeysURL string
	// HTTPClient가 nil이면 http.DefaultClient입니다.
	HTTPClient *http.Client
	Clock      clock.Clock
}

// RewardVerifier는 AdMob 보상형 광고 SSV 콜백의 서명을 검증합니다.
type RewardVerifier struct {
	keysURL string
	client  *http.Client
	clk     clock.Clock

	mu        sync.Mutex
	keys      map[uint64]*ecdsa.PublicKey
	fetchedAt time.Time // keys를 마지막으로 받은 시각. 0이면 아직 받지 않음
}

// NewRewardVerifier는 검증기를 만듭니다.
func NewRewardVerifier(cfg RewardVerifierConfig) *RewardVerifier {
	client := cfg.HTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	keysURL := cfg.KeysURL
	if keysURL == "" {
		keysURL = defaultAdMobKeysURL
	}
	return &RewardVerifier{keysURL: keysURL, client: client, clk: cfg.Clock}
}

// Verify는 원본 쿼리 문자열(디코딩·재정렬하지 않은 것)의 서명을 검증하고 콜백 값을 돌려줍니다.
// 서명 대상은 첫 "&signature=" 앞까지의 바이트 그대로입니다. 서명이 맞은 뒤에 timestamp를 검사합니다.
func (v *RewardVerifier) Verify(ctx context.Context, rawQuery string) (RewardCallback, error) {
	boundary := strings.Index(rawQuery, signatureMarker)
	if boundary <= 0 {
		return RewardCallback{}, ErrRewardSignature
	}
	message := rawQuery[:boundary]

	// signature와 key_id는 서명 대상 뒤에 이 순서로 붙습니다.
	tail, err := url.ParseQuery(rawQuery[boundary+1:])
	if err != nil {
		return RewardCallback{}, ErrRewardSignature
	}
	signature, err := decodeRewardSignature(tail.Get("signature"))
	if err != nil {
		return RewardCallback{}, ErrRewardSignature
	}
	keyID, err := strconv.ParseUint(tail.Get("key_id"), 10, 64)
	if err != nil {
		return RewardCallback{}, ErrRewardSignature
	}

	key, err := v.publicKey(ctx, keyID)
	if err != nil {
		return RewardCallback{}, err
	}
	digest := sha256.Sum256([]byte(message))
	if !ecdsa.VerifyASN1(key, digest[:], signature) {
		return RewardCallback{}, ErrRewardSignature
	}

	// 서명이 맞은 부분에서만 값을 꺼냅니다.
	values, err := url.ParseQuery(message)
	if err != nil {
		return RewardCallback{}, ErrRewardSignature
	}
	transactionID := values.Get("transaction_id")
	if transactionID == "" {
		return RewardCallback{}, ErrRewardSignature
	}
	timestamp, err := parseRewardTimestamp(values.Get("timestamp"))
	if err != nil {
		return RewardCallback{}, ErrRewardSignature
	}
	if diff := v.clk.Now().Sub(timestamp); diff > rewardTimestampTolerance || diff < -rewardTimestampTolerance {
		return RewardCallback{}, ErrRewardExpired
	}
	return RewardCallback{
		TransactionID: transactionID,
		UserID:        values.Get("user_id"),
		AdUnit:        values.Get("ad_unit"),
		RewardItem:    values.Get("reward_item"),
		Timestamp:     timestamp,
	}, nil
}

// decodeRewardSignature는 base64url 서명을 풉니다. 패딩은 있어도 없어도 받습니다(P7-12).
func decodeRewardSignature(value string) ([]byte, error) {
	if value == "" {
		return nil, ErrRewardSignature
	}
	return base64.RawURLEncoding.DecodeString(strings.TrimRight(value, "="))
}

// parseRewardTimestamp는 숫자 13자리 이하를 ms, 16자리를 µs로 읽습니다(P7-13). 그 밖의 형식은 오류입니다.
func parseRewardTimestamp(value string) (time.Time, error) {
	if value == "" || len(value) > 16 || (len(value) > 13 && len(value) != 16) {
		return time.Time{}, ErrRewardSignature
	}
	for _, r := range value {
		if r < '0' || r > '9' {
			return time.Time{}, ErrRewardSignature
		}
	}
	number, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return time.Time{}, ErrRewardSignature
	}
	if len(value) == 16 {
		return time.UnixMicro(number).UTC(), nil
	}
	return time.UnixMilli(number).UTC(), nil
}

// publicKey는 key_id의 공개 키를 돌려줍니다. 캐시는 24시간 유지하고, 모르는 key_id는
// 마지막으로 받은 지 1분이 지났을 때만 다시 받습니다. 만료된 캐시를 다시 받지 못하면 오래된 키를 쓰지 않습니다(P7-11).
func (v *RewardVerifier) publicKey(ctx context.Context, keyID uint64) (*ecdsa.PublicKey, error) {
	v.mu.Lock()
	defer v.mu.Unlock()

	now := v.clk.Now()
	if v.keys == nil || now.Sub(v.fetchedAt) >= adMobKeysTTL {
		if err := v.refreshLocked(ctx, now); err != nil {
			return nil, err
		}
	}
	if key, ok := v.keys[keyID]; ok {
		return key, nil
	}
	if now.Sub(v.fetchedAt) < adMobUnknownKeyRefetch {
		return nil, ErrRewardSignature
	}
	if err := v.refreshLocked(ctx, now); err != nil {
		return nil, err
	}
	if key, ok := v.keys[keyID]; ok {
		return key, nil
	}
	return nil, ErrRewardSignature
}

// adMobKeysResponse는 키 목록 응답에서 쓰는 필드입니다. keyId는 int32를 넘는 JSON 숫자입니다.
type adMobKeysResponse struct {
	Keys []struct {
		KeyID  uint64 `json:"keyId"`
		Base64 string `json:"base64"`
	} `json:"keys"`
}

// refreshLocked는 키 서버에서 키를 받아 캐시를 바꿉니다. 실패하면 캐시를 건드리지 않습니다.
// 호출자가 v.mu를 잡고 있어야 합니다.
func (v *RewardVerifier) refreshLocked(ctx context.Context, now time.Time) error {
	ctx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, v.keysURL, nil)
	if err != nil {
		return fmt.Errorf("%w: 요청 생성 실패: %w", ErrRewardKeysUnavailable, err)
	}
	req.Header.Set("Accept", "application/json")
	resp, err := v.client.Do(req)
	if err != nil {
		return fmt.Errorf("%w: 요청 실패: %w", ErrRewardKeysUnavailable, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%w: 상태 %d", ErrRewardKeysUnavailable, resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes))
	if err != nil {
		return fmt.Errorf("%w: 응답 읽기 실패: %w", ErrRewardKeysUnavailable, err)
	}
	var parsed adMobKeysResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return fmt.Errorf("%w: 응답 형식이 올바르지 않습니다", ErrRewardKeysUnavailable)
	}

	keys := make(map[uint64]*ecdsa.PublicKey, len(parsed.Keys))
	for _, entry := range parsed.Keys {
		der, err := base64.StdEncoding.DecodeString(entry.Base64)
		if err != nil {
			continue
		}
		parsedKey, err := x509.ParsePKIXPublicKey(der)
		if err != nil {
			continue
		}
		// EC 키만 씁니다. 다른 종류의 키 항목은 버립니다.
		if ecKey, ok := parsedKey.(*ecdsa.PublicKey); ok {
			keys[entry.KeyID] = ecKey
		}
	}
	v.keys = keys
	v.fetchedAt = now
	return nil
}
