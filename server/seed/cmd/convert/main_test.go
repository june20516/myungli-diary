package main

import (
	"bytes"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// basic 트리에는 en 원고가 일부만 있어 빠진 원고가 있습니다.
const basicDir = "../../convert/testdata/basic"

func TestRun_StrictExitCode(t *testing.T) {
	tests := []struct {
		name     string
		extra    []string
		wantCode int
	}{
		{"strict 아님: 빠진 것이 있어도 0", nil, 0},
		{"strict: 빠진 것이 있으면 1", []string{"-strict"}, 1},
		{"필수 플래그 없음: 1", []string{"-strict=false", "-writing", ""}, 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			out := filepath.Join(t.TempDir(), "content.json")
			args := append([]string{"-writing", basicDir, "-out", out}, tt.extra...)
			var stderr bytes.Buffer
			assert.Equal(t, tt.wantCode, run(args, &stderr), stderr.String())
		})
	}
}

func TestRun_StrictPassesWhenNothingMissing(t *testing.T) {
	out := filepath.Join(t.TempDir(), "content.json")
	var stderr bytes.Buffer
	args := []string{"-writing", "../../convert/testdata/complete", "-out", out, "-strict"}
	assert.Equal(t, 0, run(args, &stderr), stderr.String())
}
