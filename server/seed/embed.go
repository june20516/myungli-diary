package seed

import (
	_ "embed"
	"fmt"
)

// contentJSON은 go generate로 만든 내장 시드입니다.
//
//go:embed data/content.json
var contentJSON []byte

// Load는 바이너리에 내장된 시드를 읽습니다.
func Load() (Seed, error) {
	s, err := Parse(contentJSON)
	if err != nil {
		return Seed{}, fmt.Errorf("내장 시드: %w", err)
	}
	return s, nil
}
