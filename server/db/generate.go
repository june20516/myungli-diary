package db

// sqlc가 queries/*.sql과 migrations를 읽어 internal/auth/authdb, internal/account/accountdb, internal/profile/profiledb, internal/fortune/cachedb, internal/content/contentdb, internal/diary/diarydb, internal/schedule/scheduledb, internal/httpapi/idempotencydb를 만듭니다.
// 도구 버전은 go.mod의 tool 지시어로 고정합니다.
//
//go:generate go tool sqlc generate -f sqlc.yaml
