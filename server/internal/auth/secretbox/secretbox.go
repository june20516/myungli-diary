// Package secretbox는 DB에 저장할 비밀값(예: Apple refresh token)을 AES-256-GCM으로 암호화합니다.
package secretbox

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
)

const keySize = 32 // AES-256

// Key는 keyID가 붙은 32바이트 대칭 키입니다.
type Key struct {
	ID    string
	Bytes []byte
}

// ParseKey는 표준 base64 문자열을 읽어 Key로 만듭니다. 32바이트가 아니면 오류입니다.
func ParseKey(id, base64Std string) (Key, error) {
	b, err := base64.StdEncoding.DecodeString(base64Std)
	if err != nil {
		return Key{}, fmt.Errorf("비밀값 키 %q: base64 해석 실패: %w", id, err)
	}
	if len(b) != keySize {
		return Key{}, fmt.Errorf("비밀값 키 %q: %d바이트, 32바이트여야 합니다", id, len(b))
	}
	return Key{ID: id, Bytes: b}, nil
}

// Box는 current 키로 암호화하고 current·previous 키로 복호화합니다.
type Box struct {
	currentID string
	aeads     map[string]cipher.AEAD // keyID -> AEAD
}

// New는 Box를 만듭니다. 키는 ParseKey를 거친 32바이트여야 합니다.
func New(current Key, previous []Key) *Box {
	b := &Box{currentID: current.ID, aeads: make(map[string]cipher.AEAD, len(previous)+1)}
	for _, k := range append([]Key{current}, previous...) {
		// 키 길이는 ParseKey가 보장하므로 여기서 실패하면 프로그래밍 오류입니다.
		block, err := aes.NewCipher(k.Bytes)
		if err != nil {
			panic(fmt.Sprintf("secretbox: 잘못된 키 %q: %v", k.ID, err))
		}
		aead, err := cipher.NewGCM(block)
		if err != nil {
			panic(fmt.Sprintf("secretbox: GCM 생성 실패 %q: %v", k.ID, err))
		}
		b.aeads[k.ID] = aead
	}
	return b
}

// Seal은 plaintext를 current 키로 암호화합니다.
// ciphertext는 nonce(12바이트) || GCM 출력이고, 복호화에 필요한 keyID를 함께 돌려줍니다.
func (b *Box) Seal(plaintext []byte) (ciphertext []byte, keyID string, err error) {
	aead := b.aeads[b.currentID]
	nonce := make([]byte, aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, "", fmt.Errorf("nonce 생성: %w", err)
	}
	// Seal의 첫 인자(dst)가 nonce이므로 결과는 nonce || 암호문이 됩니다.
	return aead.Seal(nonce, nonce, plaintext, nil), b.currentID, nil
}

// Open은 keyID에 해당하는 키로 ciphertext를 복호화합니다.
// 모르는 keyID, 짧은 입력, 변조된 입력은 오류입니다.
func (b *Box) Open(ciphertext []byte, keyID string) ([]byte, error) {
	aead, ok := b.aeads[keyID]
	if !ok {
		return nil, errors.New("알 수 없는 비밀값 keyID")
	}
	if len(ciphertext) < aead.NonceSize() {
		return nil, errors.New("암호문이 너무 짧습니다")
	}
	nonce, sealed := ciphertext[:aead.NonceSize()], ciphertext[aead.NonceSize():]
	plain, err := aead.Open(nil, nonce, sealed, nil)
	if err != nil {
		return nil, errors.New("복호화 실패")
	}
	return plain, nil
}
