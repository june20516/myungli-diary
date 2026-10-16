package fortune

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// TestNoticeCode_AllProtoValuesMapToContract는 proto NoticeCode의 모든 값(UNSPECIFIED 제외)이 계약 enum 값이 되는지,
// UNSPECIFIED와 모르는 번호는 false인지 확인합니다. 안내 코드는 httpapi가 아니라 여기서 계약 값으로 바뀝니다.
func TestNoticeCode_AllProtoValuesMapToContract(t *testing.T) {
	values := enginev1.NoticeCode(0).Descriptor().Values()
	for i := range values.Len() {
		v := values.Get(i)
		code, ok := noticeCode(enginev1.NoticeCode(v.Number()))
		if v.Number() == 0 {
			assert.False(t, ok, "UNSPECIFIED는 계약 값이 아닙니다")
			continue
		}
		if assert.True(t, ok, string(v.Name())) {
			assert.True(t, gen.NoticeCode(code).Valid(), "%s -> %q가 계약 enum에 없습니다", v.Name(), code)
		}
	}
	_, ok := noticeCode(enginev1.NoticeCode(999))
	assert.False(t, ok, "모르는 번호")
}
