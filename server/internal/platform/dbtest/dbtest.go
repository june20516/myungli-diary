// Package dbtest는 DB를 쓰는 테스트에 격리된 PostgreSQL 데이터베이스를 줍니다.
//
// 테스트 프로세스(패키지)마다 컨테이너 하나를 띄우고, migration을 적용한 template DB를 만듭니다.
// 테스트마다 그 template에서 새 DB를 복제하므로, 테스트끼리 데이터가 섞이지 않고 migration을 반복하지 않습니다.
// 컨테이너는 testcontainers의 reaper가 테스트 프로세스가 끝난 뒤 정리합니다.
package dbtest

import (
	"context"
	"fmt"
	"net/url"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"

	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

const (
	image        = "postgres:17-alpine"
	adminDB      = "postgres"
	templateDB   = "myungli_template"
	user         = "myungli"
	password     = "myungli"
	setupTimeout = 3 * time.Minute
)

// shared는 패키지 안의 모든 테스트가 나눠 쓰는 컨테이너 상태입니다.
type shared struct {
	// baseURL은 데이터베이스 이름이 비어 있는 연결 주소입니다.
	baseURL *url.URL
	// adminPool은 CREATE·DROP DATABASE를 실행하는 관리용 연결입니다.
	adminPool *pgxpool.Pool
}

var (
	setupOnce  sync.Once
	setupState shared
	setupErr   error

	databaseSeq atomic.Int64
)

// NewURL은 migration이 적용된 빈 데이터베이스를 만들어 연결 주소를 반환합니다.
// serve처럼 주소를 받아 직접 연결하는 코드를 시험할 때 씁니다. 데이터베이스는 t.Cleanup에서 지워집니다.
func NewURL(t testing.TB) string {
	t.Helper()

	setupOnce.Do(func() { setupState, setupErr = setup() })
	if setupErr != nil {
		t.Fatalf("테스트 DB 준비 실패: %v", setupErr)
	}

	ctx, cancel := context.WithTimeout(context.Background(), setupTimeout)
	defer cancel()

	name := fmt.Sprintf("test_%d", databaseSeq.Add(1))
	if _, err := setupState.adminPool.Exec(ctx, fmt.Sprintf("CREATE DATABASE %s TEMPLATE %s", name, templateDB)); err != nil {
		t.Fatalf("테스트 DB 생성: %v", err)
	}
	t.Cleanup(func() {
		dropCtx, dropCancel := context.WithTimeout(context.Background(), setupTimeout)
		defer dropCancel()
		if _, err := setupState.adminPool.Exec(dropCtx, fmt.Sprintf("DROP DATABASE IF EXISTS %s WITH (FORCE)", name)); err != nil {
			t.Errorf("테스트 DB 삭제: %v", err)
		}
	})
	return setupState.databaseURL(name)
}

// New는 migration이 적용된 빈 데이터베이스를 만들어 연결 풀을 반환합니다.
// 풀과 데이터베이스는 t.Cleanup에서 정리됩니다.
func New(t testing.TB) *pgxpool.Pool {
	t.Helper()

	// Cleanup은 나중에 등록된 것부터 실행되므로, 풀(나중 등록)이 먼저 닫히고 그다음 DB가 지워집니다.
	databaseURL := NewURL(t)

	ctx, cancel := context.WithTimeout(context.Background(), setupTimeout)
	defer cancel()
	pool, err := postgres.Open(ctx, databaseURL)
	if err != nil {
		t.Fatalf("테스트 DB 연결: %v", err)
	}
	t.Cleanup(pool.Close)
	return pool
}

// setup은 컨테이너를 띄우고 migration을 적용한 template DB를 만듭니다.
func setup() (shared, error) {
	ctx, cancel := context.WithTimeout(context.Background(), setupTimeout)
	defer cancel()

	container, err := tcpostgres.Run(ctx, image,
		tcpostgres.WithDatabase(adminDB),
		tcpostgres.WithUsername(user),
		tcpostgres.WithPassword(password),
		tcpostgres.BasicWaitStrategies(),
	)
	if err != nil {
		return shared{}, fmt.Errorf("컨테이너 시작(Docker가 켜져 있어야 합니다): %w", err)
	}
	// 정리는 testcontainers reaper에 맡깁니다. 실패 경로에서만 직접 끕니다.
	var adminPool *pgxpool.Pool
	terminateOnError := func(err error) (shared, error) {
		if adminPool != nil {
			adminPool.Close()
		}
		_ = testcontainers.TerminateContainer(container)
		return shared{}, err
	}

	rawURL, err := container.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		return terminateOnError(fmt.Errorf("연결 주소: %w", err))
	}
	baseURL, err := url.Parse(rawURL)
	if err != nil {
		return terminateOnError(fmt.Errorf("연결 주소 파싱: %w", err))
	}
	state := shared{baseURL: baseURL}

	adminPool, err = postgres.Open(ctx, state.databaseURL(adminDB))
	if err != nil {
		return terminateOnError(fmt.Errorf("관리용 연결: %w", err))
	}
	state.adminPool = adminPool
	if _, err := state.adminPool.Exec(ctx, "CREATE DATABASE "+templateDB); err != nil {
		return terminateOnError(fmt.Errorf("template DB 생성: %w", err))
	}

	// template으로 복제하려면 template DB에 열린 연결이 없어야 하므로 migration 뒤 풀을 닫습니다.
	templatePool, err := postgres.Open(ctx, state.databaseURL(templateDB))
	if err != nil {
		return terminateOnError(fmt.Errorf("template DB 연결: %w", err))
	}
	defer templatePool.Close()
	if err := postgres.Migrate(ctx, templatePool, "up"); err != nil {
		return terminateOnError(fmt.Errorf("template DB migration: %w", err))
	}
	return state, nil
}

// databaseURL은 baseURL에 데이터베이스 이름을 붙인 연결 주소를 만듭니다.
func (s shared) databaseURL(database string) string {
	u := *s.baseURL
	u.Path = "/" + database
	return u.String()
}
