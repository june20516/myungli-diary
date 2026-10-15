package city

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestEmbeddedSizeUnder4MiB(t *testing.T) {
	assert.Less(t, len(embeddedData), 4<<20)
}
