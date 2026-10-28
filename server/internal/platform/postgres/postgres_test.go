package postgres_test

import (
	"context"
	"net"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/june20516/myungli-diary/server/internal/platform/dbtest"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
)

func TestOpen_UnreachableFailsFast(t *testing.T) {
	start := time.Now()
	pool, err := postgres.Open(context.Background(), "postgres://u:p@127.0.0.1:1/x")
	if err == nil {
		pool.Close()
		t.Fatal("연결할 수 없는 주소인데 오류가 없습니다")
	}
	if elapsed := time.Since(start); elapsed > 6*time.Second {
		t.Errorf("실패까지 %v 걸렸습니다, want 6초 이내", elapsed)
	}
}

func TestOpen_ErrorDoesNotLeakPassword(t *testing.T) {
	_, err := postgres.Open(context.Background(), "postgres://u:s3cr3t-pw@127.0.0.1:1/x")
	if err == nil {
		t.Fatal("오류가 없습니다")
	}
	if strings.Contains(err.Error(), "s3cr3t-pw") {
		t.Errorf("오류 메시지에 비밀번호가 포함됨: %q", err.Error())
	}
}

func TestOpen_InvalidURLDoesNotLeakPassword(t *testing.T) {
	_, err := postgres.Open(context.Background(), "postgres://u:s3cr3t-pw@host:notaport/x")
	if err == nil {
		t.Fatal("오류가 없습니다")
	}
	if strings.Contains(err.Error(), "s3cr3t-pw") {
		t.Errorf("오류 메시지에 비밀번호가 포함됨: %q", err.Error())
	}
}

func TestDBTest_IsolatedDatabases(t *testing.T) {
	names := make([]string, 2)
	for i := range names {
		pool := dbtest.New(t)
		if err := pool.QueryRow(context.Background(), "SELECT current_database()").Scan(&names[i]); err != nil {
			t.Fatalf("current_database: %v", err)
		}
	}
	if names[0] == names[1] {
		t.Errorf("두 테스트 DB 이름이 같습니다: %q", names[0])
	}
}

func TestDBTest_ChangesInOneDatabaseAreInvisibleToAnother(t *testing.T) {
	ctx := context.Background()
	first, second := dbtest.New(t), dbtest.New(t)

	if _, err := first.Exec(ctx, "CREATE TABLE only_in_first (id int)"); err != nil {
		t.Fatalf("테이블 생성: %v", err)
	}
	var exists bool
	if err := second.QueryRow(ctx, "SELECT to_regclass('only_in_first') IS NOT NULL").Scan(&exists); err != nil {
		t.Fatalf("조회: %v", err)
	}
	if exists {
		t.Error("한 DB에서 만든 테이블이 다른 DB에서 보입니다")
	}
}

// tcpDialer는 instance 이름을 기록하고 테스트 DB 주소로 TCP 연결을 이어 주는 Cloud SQL dialer 대역입니다.
type tcpDialer struct {
	addr      string
	mu        sync.Mutex
	instances []string
}

func (d *tcpDialer) Dial(ctx context.Context, instance string) (net.Conn, error) {
	d.mu.Lock()
	d.instances = append(d.instances, instance)
	d.mu.Unlock()
	return (&net.Dialer{}).DialContext(ctx, "tcp", d.addr)
}

// Cloud SQL 연결은 DATABASE_URL의 host가 아니라 dialer로 instance에 붙습니다.
func TestOpenWithDialer_DialsInstance(t *testing.T) {
	databaseURL := dbtest.NewURL(t)
	parsed, err := url.Parse(databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	dialer := &tcpDialer{addr: parsed.Host}
	// host를 닿지 않는 주소로 바꿔도 dialer로 붙어야 합니다.
	parsed.Host = "127.0.0.1:1"

	pool, err := postgres.OpenWithDialer(context.Background(), parsed.String(), "p:asia-northeast3:myungli-pg", dialer.Dial)
	if err != nil {
		t.Fatalf("OpenWithDialer() error = %v", err)
	}
	defer pool.Close()

	dialer.mu.Lock()
	defer dialer.mu.Unlock()
	if len(dialer.instances) == 0 || dialer.instances[0] != "p:asia-northeast3:myungli-pg" {
		t.Errorf("dialer instances = %v", dialer.instances)
	}
}
