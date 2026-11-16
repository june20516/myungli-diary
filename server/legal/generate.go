package legal

// 내장 문서(data/legal.json)를 원문 docs/legal/<언어>/<이름>.md에서 다시 만듭니다. server 디렉터리에서 `go generate ./legal/`로 실행합니다.
//go:generate go run ./cmd/convert -legal ../../docs/legal -out data/legal.json
