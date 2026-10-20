package legal

import (
	_ "embed"
	"fmt"
)

// legalJSON은 go generate로 만든 내장 문서입니다.
//
//go:embed data/legal.json
var legalJSON []byte

// Load는 바이너리에 내장된 문서를 읽습니다.
func Load() (Documents, error) {
	docs, err := Parse(legalJSON)
	if err != nil {
		return Documents{}, fmt.Errorf("내장 법적 문서: %w", err)
	}
	return docs, nil
}
