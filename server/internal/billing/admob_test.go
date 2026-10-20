package billing

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/clock/clocktest"
)

// int32를 넘는 실제 형태의 key_id입니다.
const testRewardKeyID uint64 = 3335741209

var rewardNow = time.Date(2026, 10, 20, 12, 0, 0, 0, time.UTC)

// rewardKeyServer는 AdMob 키 서버를 흉내 냅니다. 요청 횟수를 세고 응답을 바꿀 수 있습니다.
type rewardKeyServer struct {
	*httptest.Server
	calls  atomic.Int32
	status atomic.Int32
	body   atomic.Value // string
}

func newRewardKeyServer(t *testing.T, body string) *rewardKeyServer {
	t.Helper()
	s := &rewardKeyServer{}
	s.status.Store(http.StatusOK)
	s.body.Store(body)
	s.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		s.calls.Add(1)
		w.WriteHeader(int(s.status.Load()))
		_, _ = w.Write([]byte(s.body.Load().(string)))
	}))
	t.Cleanup(s.Close)
	return s
}

func newRewardPrivateKey(t *testing.T) *ecdsa.PrivateKey {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	return key
}

// rewardKeysJSON은 실제 응답 형태({"keys":[{"keyId":숫자,"pem":...,"base64":...}]})의 JSON을 만듭니다.
func rewardKeysJSON(t *testing.T, entries map[uint64]any) string {
	t.Helper()
	type entry struct {
		KeyID  uint64 `json:"keyId"`
		PEM    string `json:"pem"`
		Base64 string `json:"base64"`
	}
	var list []entry
	for id, pub := range entries {
		der, err := x509.MarshalPKIXPublicKey(pub)
		if err != nil {
			t.Fatal(err)
		}
		list = append(list, entry{KeyID: id, PEM: "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----", Base64: base64.StdEncoding.EncodeToString(der)})
	}
	out, err := json.Marshal(map[string]any{"keys": list})
	if err != nil {
		t.Fatal(err)
	}
	return string(out)
}

// signRewardQuery는 message를 서명해 "message&signature=…&key_id=…" 원본 쿼리를 만듭니다.
func signRewardQuery(t *testing.T, key *ecdsa.PrivateKey, keyID uint64, message string, pad bool) string {
	t.Helper()
	digest := sha256.Sum256([]byte(message))
	sig, err := ecdsa.SignASN1(rand.Reader, key, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	encoding := base64.RawURLEncoding
	if pad {
		encoding = base64.URLEncoding
	}
	return fmt.Sprintf("%s&signature=%s&key_id=%d", message, encoding.EncodeToString(sig), keyID)
}

func rewardMessage(timestamp string) string {
	return "ad_network=5450213213286189855&ad_unit=1234&custom_data=a%2Fb+c&reward_amount=1&reward_item=insight" +
		"&timestamp=" + timestamp + "&transaction_id=tx-1&user_id=0b6f0c2e-1111-4222-8333-444455556666"
}

func rewardTimestampMillis(at time.Time) string { return fmt.Sprint(at.UnixMilli()) }

type rewardFixture struct {
	key    *ecdsa.PrivateKey
	server *rewardKeyServer
	clk    *clocktest.Fake
	verify *RewardVerifier
}

func newRewardFixture(t *testing.T) *rewardFixture {
	t.Helper()
	key := newRewardPrivateKey(t)
	server := newRewardKeyServer(t, rewardKeysJSON(t, map[uint64]any{testRewardKeyID: &key.PublicKey}))
	clk := clocktest.New(rewardNow)
	return &rewardFixture{
		key: key, server: server, clk: clk,
		verify: NewRewardVerifier(RewardVerifierConfig{KeysURL: server.URL, Clock: clk}),
	}
}

func (f *rewardFixture) signed(t *testing.T, message string) string {
	t.Helper()
	return signRewardQuery(t, f.key, testRewardKeyID, message, false)
}

func TestReward_정상_콜백_값을_푼다(t *testing.T) {
	f := newRewardFixture(t)
	query := f.signed(t, rewardMessage(rewardTimestampMillis(rewardNow)))

	got, err := f.verify.Verify(context.Background(), query)
	if err != nil {
		t.Fatalf("Verify 실패: %v", err)
	}
	want := RewardCallback{
		TransactionID: "tx-1", UserID: "0b6f0c2e-1111-4222-8333-444455556666",
		AdUnit: "1234", RewardItem: "insight", Timestamp: rewardNow,
	}
	if got != want {
		t.Fatalf("콜백 = %+v, want %+v", got, want)
	}
}

func TestReward_user_id와_custom_data가_없어도_통과한다(t *testing.T) {
	f := newRewardFixture(t)
	message := "ad_network=1&ad_unit=1234&reward_amount=1&reward_item=insight&timestamp=" +
		rewardTimestampMillis(rewardNow) + "&transaction_id=tx-2"
	got, err := f.verify.Verify(context.Background(), f.signed(t, message))
	if err != nil {
		t.Fatalf("Verify 실패: %v", err)
	}
	if got.UserID != "" || got.TransactionID != "tx-2" {
		t.Fatalf("콜백 = %+v", got)
	}
}

func TestReward_인코딩된_원본_쿼리는_통과하고_재인코딩한_쿼리는_실패한다(t *testing.T) {
	f := newRewardFixture(t)
	message := rewardMessage(rewardTimestampMillis(rewardNow))
	query := f.signed(t, message)
	if _, err := f.verify.Verify(context.Background(), query); err != nil {
		t.Fatalf("원본 쿼리 실패: %v", err)
	}
	// custom_data=a%2Fb+c 를 같은 값의 다른 인코딩(a/b%20c)으로 바꾼 쿼리입니다.
	reencoded := strings.Replace(query, "custom_data=a%2Fb+c", "custom_data=a/b%20c", 1)
	if reencoded == query {
		t.Fatal("테스트 전제가 어긋났습니다")
	}
	if _, err := f.verify.Verify(context.Background(), reencoded); !errors.Is(err, ErrRewardSignature) {
		t.Fatalf("err = %v, want ErrRewardSignature", err)
	}
}

func TestReward_서명_패딩은_있어도_없어도_통과한다(t *testing.T) {
	for _, pad := range []bool{false, true} {
		f := newRewardFixture(t)
		// 패딩이 실제로 붙도록 서명 길이가 3의 배수가 아닐 때까지 반복합니다.
		verified := false
		for range 50 {
			query := signRewardQuery(t, f.key, testRewardKeyID, rewardMessage(rewardTimestampMillis(rewardNow)), pad)
			if pad && !strings.Contains(query, "=&key_id") {
				continue
			}
			if _, err := f.verify.Verify(context.Background(), query); err != nil {
				t.Fatalf("pad=%v 실패: %v", pad, err)
			}
			verified = true
			break
		}
		if !verified {
			t.Fatalf("pad=%v 서명을 만들지 못했습니다", pad)
		}
	}
}

func TestReward_형식이_틀린_쿼리는_서명_오류다(t *testing.T) {
	f := newRewardFixture(t)
	good := f.signed(t, rewardMessage(rewardTimestampMillis(rewardNow)))
	sigStart := strings.Index(good, "&signature=") + len("&signature=")

	flipped := []byte(good)
	if flipped[sigStart+10] == 'A' {
		flipped[sigStart+10] = 'B'
	} else {
		flipped[sigStart+10] = 'A'
	}

	cases := map[string]string{
		"서명 한 바이트 바뀜":    string(flipped),
		"key_id 없음":      good[:strings.Index(good, "&key_id=")],
		"signature 없음":   rewardMessage(rewardTimestampMillis(rewardNow)) + "&key_id=3335741209",
		"signature가 맨 앞": "signature=" + good[sigStart:],
		"빈 쿼리":           "",
		"메시지가 바뀜":        strings.Replace(good, "reward_amount=1", "reward_amount=9", 1),
		"key_id가 숫자 아님":  good[:strings.Index(good, "&key_id=")] + "&key_id=abc",
		"서명 패딩이 3개 이상":   good[:strings.Index(good, "&key_id=")] + "===&key_id=3335741209",
		"서명이 base64 아님":  strings.Replace(good, good[sigStart:sigStart+4], "!!!!", 1),
	}
	for name, query := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := f.verify.Verify(context.Background(), query); !errors.Is(err, ErrRewardSignature) {
				t.Fatalf("err = %v, want ErrRewardSignature", err)
			}
		})
	}
}

func TestReward_transaction_id가_없으면_서명_오류다(t *testing.T) {
	f := newRewardFixture(t)
	message := "ad_unit=1&timestamp=" + rewardTimestampMillis(rewardNow)
	if _, err := f.verify.Verify(context.Background(), f.signed(t, message)); !errors.Is(err, ErrRewardSignature) {
		t.Fatalf("err = %v, want ErrRewardSignature", err)
	}
}

func TestReward_모르는_key_id는_한_번_다시_받고_없으면_서명_오류다(t *testing.T) {
	f := newRewardFixture(t)
	other := newRewardPrivateKey(t)
	query := signRewardQuery(t, other, 42, rewardMessage(rewardTimestampMillis(rewardNow)), false)

	// 처음 요청은 캐시를 채우느라 1번 받고, 1분이 지나기 전이라 다시 받지 않습니다.
	if _, err := f.verify.Verify(context.Background(), query); !errors.Is(err, ErrRewardSignature) {
		t.Fatalf("err = %v", err)
	}
	if got := f.server.calls.Load(); got != 1 {
		t.Fatalf("키 서버 호출 = %d, want 1", got)
	}

	// 1분 안의 모르는 key_id는 키 서버를 부르지 않습니다.
	f.clk.Advance(59 * time.Second)
	if _, err := f.verify.Verify(context.Background(), query); !errors.Is(err, ErrRewardSignature) {
		t.Fatalf("err = %v", err)
	}
	if got := f.server.calls.Load(); got != 1 {
		t.Fatalf("1분 안 키 서버 호출 = %d, want 1", got)
	}

	// 1분이 지나면 한 번 다시 받고, 그래도 없으면 서명 오류입니다.
	f.clk.Advance(2 * time.Second)
	if _, err := f.verify.Verify(context.Background(), query); !errors.Is(err, ErrRewardSignature) {
		t.Fatalf("err = %v", err)
	}
	if got := f.server.calls.Load(); got != 2 {
		t.Fatalf("1분 뒤 키 서버 호출 = %d, want 2", got)
	}
}

func TestReward_새_키가_추가되면_다시_받아_통과한다(t *testing.T) {
	f := newRewardFixture(t)
	if _, err := f.verify.Verify(context.Background(), f.signed(t, rewardMessage(rewardTimestampMillis(rewardNow)))); err != nil {
		t.Fatal(err)
	}
	newKey := newRewardPrivateKey(t)
	f.server.body.Store(rewardKeysJSON(t, map[uint64]any{testRewardKeyID: &f.key.PublicKey, 7: &newKey.PublicKey}))
	f.clk.Advance(2 * time.Minute)

	query := signRewardQuery(t, newKey, 7, rewardMessage(rewardTimestampMillis(f.clk.Now())), false)
	if _, err := f.verify.Verify(context.Background(), query); err != nil {
		t.Fatalf("새 키 검증 실패: %v", err)
	}
}

func TestReward_키_서버_실패는_keys_unavailable이다(t *testing.T) {
	cases := map[string]func(f *rewardFixture){
		"500":     func(f *rewardFixture) { f.server.status.Store(http.StatusInternalServerError) },
		"깨진 JSON": func(f *rewardFixture) { f.server.body.Store("{not json") },
		"연결 실패":   func(f *rewardFixture) { f.server.Close() },
	}
	for name, breakServer := range cases {
		t.Run(name, func(t *testing.T) {
			f := newRewardFixture(t)
			breakServer(f)
			_, err := f.verify.Verify(context.Background(), f.signed(t, rewardMessage(rewardTimestampMillis(rewardNow))))
			if !errors.Is(err, ErrRewardKeysUnavailable) {
				t.Fatalf("err = %v, want ErrRewardKeysUnavailable", err)
			}
		})
	}
}

func TestReward_24시간_뒤_다시_받고_실패하면_오래된_키를_쓰지_않는다(t *testing.T) {
	f := newRewardFixture(t)
	ctx := context.Background()
	if _, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(rewardTimestampMillis(rewardNow)))); err != nil {
		t.Fatal(err)
	}

	// 24시간 안에는 캐시를 씁니다.
	f.clk.Advance(24*time.Hour - time.Second)
	if _, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(rewardTimestampMillis(f.clk.Now())))); err != nil {
		t.Fatal(err)
	}
	if got := f.server.calls.Load(); got != 1 {
		t.Fatalf("24시간 안 호출 = %d, want 1", got)
	}

	// 24시간이 지나면 다시 받습니다.
	f.clk.Advance(time.Second)
	if _, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(rewardTimestampMillis(f.clk.Now())))); err != nil {
		t.Fatal(err)
	}
	if got := f.server.calls.Load(); got != 2 {
		t.Fatalf("24시간 뒤 호출 = %d, want 2", got)
	}

	// 또 24시간 뒤 받기가 실패하면 오래된 키로 통과시키지 않습니다.
	f.server.status.Store(http.StatusServiceUnavailable)
	f.clk.Advance(24 * time.Hour)
	_, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(rewardTimestampMillis(f.clk.Now()))))
	if !errors.Is(err, ErrRewardKeysUnavailable) {
		t.Fatalf("err = %v, want ErrRewardKeysUnavailable", err)
	}
}

func TestReward_timestamp_단위와_만료(t *testing.T) {
	f := newRewardFixture(t)
	ctx := context.Background()
	at := func(d time.Duration) time.Time { return rewardNow.Add(d) }

	t.Run("13자리 ms", func(t *testing.T) {
		got, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(fmt.Sprint(at(-30*time.Minute).UnixMilli()))))
		if err != nil || !got.Timestamp.Equal(at(-30*time.Minute)) {
			t.Fatalf("got = %+v, err = %v", got, err)
		}
	})
	t.Run("16자리 µs", func(t *testing.T) {
		got, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(fmt.Sprint(at(-30*time.Minute).UnixMicro()))))
		if err != nil || !got.Timestamp.Equal(at(-30*time.Minute)) {
			t.Fatalf("got = %+v, err = %v", got, err)
		}
	})
	t.Run("정확히 1시간 전은 통과", func(t *testing.T) {
		if _, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(fmt.Sprint(at(-time.Hour).UnixMilli())))); err != nil {
			t.Fatalf("err = %v", err)
		}
	})
	for name, d := range map[string]time.Duration{"61분 전": -61 * time.Minute, "61분 뒤": 61 * time.Minute} {
		t.Run(name, func(t *testing.T) {
			_, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(fmt.Sprint(at(d).UnixMilli()))))
			if !errors.Is(err, ErrRewardExpired) {
				t.Fatalf("err = %v, want ErrRewardExpired", err)
			}
		})
	}
	for name, ts := range map[string]string{
		"14자리": "12345678901234", "15자리": "123456789012345", "17자리": "12345678901234567",
		"숫자 아님": "abc", "빈 값": "", "음수": "-1234567890123",
	} {
		t.Run("형식 오류 "+name, func(t *testing.T) {
			_, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(ts)))
			if !errors.Is(err, ErrRewardSignature) {
				t.Fatalf("err = %v, want ErrRewardSignature", err)
			}
		})
	}
}

func TestReward_만료_검사는_서명_검증_뒤다(t *testing.T) {
	f := newRewardFixture(t)
	other := newRewardPrivateKey(t)
	old := fmt.Sprint(rewardNow.Add(-3 * time.Hour).UnixMilli())
	query := signRewardQuery(t, other, testRewardKeyID, rewardMessage(old), false)
	if _, err := f.verify.Verify(context.Background(), query); !errors.Is(err, ErrRewardSignature) {
		t.Fatalf("err = %v, want ErrRewardSignature", err)
	}
}

func TestReward_EC가_아닌_키_항목은_무시한다(t *testing.T) {
	ecKey := newRewardPrivateKey(t)
	rsaKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	server := newRewardKeyServer(t, rewardKeysJSON(t, map[uint64]any{
		testRewardKeyID: &ecKey.PublicKey,
		99:              &rsaKey.PublicKey,
	}))
	verifier := NewRewardVerifier(RewardVerifierConfig{KeysURL: server.URL, Clock: clocktest.New(rewardNow)})

	message := rewardMessage(rewardTimestampMillis(rewardNow))
	if _, err := verifier.Verify(context.Background(), signRewardQuery(t, ecKey, testRewardKeyID, message, false)); err != nil {
		t.Fatalf("EC 키 검증 실패: %v", err)
	}
	// RSA 항목은 버려지므로 그 key_id는 모르는 키입니다.
	if _, err := verifier.Verify(context.Background(), signRewardQuery(t, ecKey, 99, message, false)); !errors.Is(err, ErrRewardSignature) {
		t.Fatalf("err = %v, want ErrRewardSignature", err)
	}
}

func TestReward_키_서버_장애_중에는_호출을_억제한다(t *testing.T) {
	ctx := context.Background()

	t.Run("캐시가 있고 모르는 key_id 재조회가 실패하면 1분 안에는 다시 부르지 않는다", func(t *testing.T) {
		f := newRewardFixture(t)
		if _, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(rewardTimestampMillis(rewardNow)))); err != nil {
			t.Fatal(err)
		}
		f.server.status.Store(http.StatusInternalServerError)
		f.clk.Advance(2 * time.Minute)
		unknown := signRewardQuery(t, newRewardPrivateKey(t), 42, rewardMessage(rewardTimestampMillis(f.clk.Now())), false)

		// 재조회가 실패로 끝나면 503 쪽 오류입니다.
		if _, err := f.verify.Verify(ctx, unknown); !errors.Is(err, ErrRewardKeysUnavailable) {
			t.Fatalf("첫 요청 err = %v, want ErrRewardKeysUnavailable", err)
		}
		if got := f.server.calls.Load(); got != 2 {
			t.Fatalf("호출 = %d, want 2", got)
		}
		// 1분 안의 두 번째는 키 서버를 부르지 않고 서명 오류입니다.
		f.clk.Advance(30 * time.Second)
		if _, err := f.verify.Verify(ctx, unknown); !errors.Is(err, ErrRewardSignature) {
			t.Fatalf("두 번째 err = %v, want ErrRewardSignature", err)
		}
		if got := f.server.calls.Load(); got != 2 {
			t.Fatalf("두 번째 뒤 호출 = %d, want 2", got)
		}
	})

	t.Run("캐시가 없을 때 첫 조회 실패 뒤 10초 안에는 부르지 않고 10초 뒤에는 다시 부른다", func(t *testing.T) {
		f := newRewardFixture(t)
		f.server.status.Store(http.StatusInternalServerError)
		query := f.signed(t, rewardMessage(rewardTimestampMillis(rewardNow)))

		if _, err := f.verify.Verify(ctx, query); !errors.Is(err, ErrRewardKeysUnavailable) {
			t.Fatalf("err = %v", err)
		}
		f.clk.Advance(9 * time.Second)
		if _, err := f.verify.Verify(ctx, query); !errors.Is(err, ErrRewardKeysUnavailable) {
			t.Fatalf("err = %v", err)
		}
		if got := f.server.calls.Load(); got != 1 {
			t.Fatalf("10초 안 호출 = %d, want 1", got)
		}

		f.clk.Advance(time.Second)
		if _, err := f.verify.Verify(ctx, query); !errors.Is(err, ErrRewardKeysUnavailable) {
			t.Fatalf("err = %v", err)
		}
		if got := f.server.calls.Load(); got != 2 {
			t.Fatalf("10초 뒤 호출 = %d, want 2", got)
		}
	})

	t.Run("장애가 풀리면 10초 뒤 정상으로 돌아온다", func(t *testing.T) {
		f := newRewardFixture(t)
		f.server.status.Store(http.StatusInternalServerError)
		_, _ = f.verify.Verify(ctx, f.signed(t, rewardMessage(rewardTimestampMillis(rewardNow))))
		f.server.status.Store(http.StatusOK)
		f.clk.Advance(10 * time.Second)
		if _, err := f.verify.Verify(ctx, f.signed(t, rewardMessage(rewardTimestampMillis(f.clk.Now())))); err != nil {
			t.Fatalf("err = %v", err)
		}
	})
}

func TestReward_Clock이_nil이면_System_시계를_쓴다(t *testing.T) {
	key := newRewardPrivateKey(t)
	server := newRewardKeyServer(t, rewardKeysJSON(t, map[uint64]any{testRewardKeyID: &key.PublicKey}))
	verifier := NewRewardVerifier(RewardVerifierConfig{KeysURL: server.URL})
	query := signRewardQuery(t, key, testRewardKeyID, rewardMessage(rewardTimestampMillis(time.Now())), false)
	if _, err := verifier.Verify(context.Background(), query); err != nil {
		t.Fatalf("err = %v", err)
	}
}
