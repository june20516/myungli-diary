package enginev1_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
)

func TestEngineServiceDescriptor(t *testing.T) {
	require.Equal(t, "myungli.engine.v1.MyungliEngine", enginev1.MyungliEngine_ServiceDesc.ServiceName)

	methods := make([]string, 0, len(enginev1.MyungliEngine_ServiceDesc.Methods))
	for _, method := range enginev1.MyungliEngine_ServiceDesc.Methods {
		methods = append(methods, method.MethodName)
	}
	assert.ElementsMatch(t,
		[]string{"GetChart", "GetDaily", "GetMonthCalendar", "GetBirthHour", "GetInfo", "ConvertLunarDate"},
		methods)
}
