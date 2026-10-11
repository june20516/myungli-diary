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
	release := make(chan struct{})
	handler := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		close(started)
		<-release
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

	// 요청이 아직 처리 중이므로 serve는 반환하지 않아야 합니다.
	select {
	case err := <-serveDone:
		t.Fatalf("처리 중인 요청이 끝나기 전에 serve가 반환됨: %v", err)
	case <-time.After(200 * time.Millisecond):
	}

	close(release)

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
	defer cancel()
	env := map[string]string{"PORT": freePort(t)}
	var stdout, stderr bytes.Buffer

	done := make(chan int, 1)
	finished := make(chan struct{})
	go func() {
		defer close(finished)
		done <- Run(ctx, []string{"serve"}, func(key string) string { return env[key] }, &stdout, &stderr)
	}()

	// 테스트가 어떻게 끝나든 Run goroutine이 남지 않게 취소하고 종료를 기다립니다.
	t.Cleanup(func() {
		cancel()
		select {
		case <-finished:
		case <-time.After(5 * time.Second):
			t.Error("Run goroutine이 종료되지 않았습니다")
		}
	})

	waitForHealthz(t, "http://127.0.0.1:"+env["PORT"]+"/healthz")
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

// waitForHealthz는 url이 200을 줄 때까지 짧은 간격으로 확인합니다. 5초 안에 안 되면 실패합니다.
func waitForHealthz(t *testing.T, url string) {
	t.Helper()
	client := &http.Client{Timeout: 500 * time.Millisecond}
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		resp, err := client.Get(url)
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return
			}
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("%s가 5초 안에 200을 주지 않았습니다", url)
}
