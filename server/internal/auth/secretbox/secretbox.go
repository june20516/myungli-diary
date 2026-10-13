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
	if id == "" {
		return Key{}, errors.New("비밀값 키: id가 비어 있습니다")
	}
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

// New는 Box를 만듭니다.
// 빈 ID, current를 포함한 중복 ID, 길이가 32바이트가 아닌 키는 오류입니다.
// (중복을 허용하면 이전 키로 암호화하면서 current ID를 붙여 영구히 복호화할 수 없게 됩니다.)
func New(current Key, previous []Key) (*Box, error) {
	b := &Box{currentID: current.ID, aeads: make(map[string]cipher.AEAD, len(previous)+1)}
	for _, k := range append([]Key{current}, previous...) {
		if k.ID == "" {
			return nil, errors.New("비밀값 키: id가 비어 있습니다")
		}
		if _, dup := b.aeads[k.ID]; dup {
			return nil, fmt.Errorf("비밀값 키 %q: id가 중복됩니다", k.ID)
		}
		if len(k.Bytes) != keySize {
			return nil, fmt.Errorf("비밀값 키 %q: %d바이트, 32바이트여야 합니다", k.ID, len(k.Bytes))
		}
		block, err := aes.NewCipher(k.Bytes)
		if err != nil {
			return nil, fmt.Errorf("비밀값 키 %q: AES 생성 실패", k.ID)
		}
		aead, err := cipher.NewGCM(block)
		if err != nil {
			return nil, fmt.Errorf("비밀값 키 %q: GCM 생성 실패", k.ID)
		}
		b.aeads[k.ID] = aead
	}
	return b, nil
}

// Seal은 plaintext를 current 키로 암호화합니다.
// aad(associated data)는 암호문에 묶이는 비밀이 아닌 문맥(예: 행 id)이며, Open에 같은 값을 줘야 합니다.
// ciphertext는 nonce(12바이트) || GCM 출력이고, 복호화에 필요한 keyID를 함께 돌려줍니다.
func (b *Box) Seal(plaintext, aad []byte) (ciphertext []byte, keyID string, err error) {
	aead := b.aeads[b.currentID]
	nonce := make([]byte, aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, "", fmt.Errorf("nonce 생성: %w", err)
	}
	// Seal의 첫 인자(dst)가 nonce이므로 결과는 nonce || 암호문이 됩니다.
	return aead.Seal(nonce, nonce, plaintext, aad), b.currentID, nil
}

// Open은 keyID에 해당하는 키로 ciphertext를 복호화합니다.
// 모르는 keyID, 짧은 입력, 변조된 입력, 다른 aad는 오류입니다.
func (b *Box) Open(ciphertext []byte, keyID string, aad []byte) ([]byte, error) {
	aead, ok := b.aeads[keyID]
	if !ok {
		return nil, errors.New("알 수 없는 비밀값 keyID")
	}
	if len(ciphertext) < aead.NonceSize() {
		return nil, errors.New("암호문이 너무 짧습니다")
	}
	nonce, sealed := ciphertext[:aead.NonceSize()], ciphertext[aead.NonceSize():]
	plain, err := aead.Open(nil, nonce, sealed, aad)
	if err != nil {
		return nil, errors.New("복호화 실패")
	}
	return plain, nil
}
