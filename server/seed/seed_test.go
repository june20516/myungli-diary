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
}
