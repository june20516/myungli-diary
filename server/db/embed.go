// Package db는 데이터베이스 migration 파일을 바이너리에 포함합니다.
package db

import "embed"

// Migrations는 goose migration SQL 파일입니다.
//
//go:embed migrations/*.sql
var Migrations embed.FS
