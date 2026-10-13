package token

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
)

// refreshTokenBytes는 refresh token의 난수 길이(256비트)입니다.
const refreshTokenBytes = 32

// NewRefreshToken은 256비트 난수 refresh token(base64url, 패딩 없음)과 그 SHA-256을 돌려줍니다.
// 원문은 클라이언트에만 주고, DB에는 hash만 저장합니다.
func NewRefreshToken() (raw string, hash []byte, err error) {
	buf := make([]byte, refreshTokenBytes)
	if _, err := rand.Read(buf); err != nil {
		return "", nil, fmt.Errorf("refresh token 난수 생성: %w", err)
	}
	raw = base64.RawURLEncoding.EncodeToString(buf)
	return raw, HashRefreshToken(raw), nil
}

// HashRefreshToken은 refresh token 원문의 SHA-256을 돌려줍니다.
func HashRefreshToken(raw string) []byte {
	sum := sha256.Sum256([]byte(raw))
	return sum[:]
}
