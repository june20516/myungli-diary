// Package api는 REST API v1 계약(openapi.yaml)과 그 생성 설정을 담습니다.
// 생성 코드는 internal/httpapi/gen에 있습니다.
package api

//go:generate go tool oapi-codegen -config oapi-codegen.yaml openapi.yaml
