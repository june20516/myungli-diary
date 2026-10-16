package seed_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/seed"
)

func TestLoad_EmbeddedSeedParses(t *testing.T) {
	s, err := seed.Load()
	require.NoError(t, err)
	assert.NotEmpty(t, s.Version)
	assert.NotEmpty(t, s.Templates)

	// 내장 파일의 Version은 내용에서 다시 계산한 값과 같아야 합니다(손으로 고친 시드를 잡습니다).
	want := s
	require.NoError(t, want.Normalize())
	assert.Equal(t, want.Version, s.Version)
}
