package cli

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"net"
	"net/http"
	"strconv"
	"testing"
	"time"
)

func TestServe_GracefulShutdown(t *testing.T) {
	started := make(chan struct{})
	handler := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		close(started)
		time.Sleep(2 * time.Second)
		w.WriteHeader(http.StatusOK)
	})
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen: %v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	logger := slog.New(slog.NewJSONHandler(io.Discard, nil))

	serveDone := make(chan error, 1)
	go func() { serveDone <- serveHTTP(ctx, listener, handler, logger) }()

	statusCh := make(chan int, 1)
	go func() {
		resp, err := http.Get("http://" + listener.Addr().String() + "/slow")
		if err != nil {
			statusCh <- -1
			return
		}
		resp.Body.Close()
		statusCh <- resp.StatusCode
	}()

	<-started
	cancel()

	select {
	case err := <-serveDone:
		t.Fatalf("처리 중인 요청이 끝나기 전에 serve가 반환됨: %v", err)
	case <-time.After(500 * time.Millisecond):
	}
	if status := <-statusCh; status != http.StatusOK {
		t.Errorf("진행 중이던 요청 status = %d, want 200", status)
	}
	select {
	case err := <-serveDone:
		if err != nil {
			t.Errorf("serve 오류 = %v, want nil", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("요청이 끝난 뒤에도 serve가 반환되지 않았습니다")
	}
}

func TestRun_ServeStartsWithoutDatabaseURLAndStopsOnCancel(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	env := map[string]string{"PORT": freePort(t)}
	var stdout, stderr bytes.Buffer

	done := make(chan int, 1)
	go func() {
		done <- Run(ctx, []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
	}()

	time.Sleep(300 * time.Millisecond)
	cancel()

	select {
	case code := <-done:
		if code != 0 {
			t.Errorf("종료 코드 = %d, stderr = %q", code, stderr.String())
		}
	case <-time.After(5 * time.Second):
		t.Fatal("ctx 취소 뒤 serve가 종료되지 않았습니다")
	}
}

// freePort는 지금 비어 있는 포트 번호를 돌려줍니다.
func freePort(t *testing.T) string {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen: %v", err)
	}
	defer listener.Close()
	return strconv.Itoa(listener.Addr().(*net.TCPAddr).Port)
}
