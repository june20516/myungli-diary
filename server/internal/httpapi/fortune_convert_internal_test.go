package httpapi

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/reflect/protoreflect"

	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// TestConvertTag_AllFifteenTags는 계약 Tag 변환이 fortune 길흉 표의 15키를 접두어를 떼고 그대로 옮기는지 고정합니다.
// 표 자체의 값은 fortune.TestTagPolarity가 고정합니다.
func TestConvertTag_AllFifteenTags(t *testing.T) {
	want := map[string]gen.TagPolarity{
		"tag.big_change":             gen.TagPolarityBad,
		"tag.clash":                  gen.TagPolarityBad,
		"tag.harmony":                gen.TagPolarityGood,
		"tag.ten_god_rush.bigyeop":   gen.TagPolarityNeutral,
		"tag.ten_god_rush.siksang":   gen.TagPolarityGood,
		"tag.ten_god_rush.jaeseong":  gen.TagPolarityGood,
		"tag.ten_god_rush.gwanseong": gen.TagPolarityBad,
		"tag.ten_god_rush.inseong":   gen.TagPolarityGood,
		"tag.cheoneul_gwiin":         gen.TagPolarityGood,
		"tag.dohwa":                  gen.TagPolarityGood,
		"tag.yeokma":                 gen.TagPolarityNeutral,
		"tag.hwagae":                 gen.TagPolarityNeutral,
		"tag.gongmang":               gen.TagPolarityBad,
		"tag.yongsin_day":            gen.TagPolarityGood,
		"tag.gwiin_day":              gen.TagPolarityGood,
	}
	assert.Len(t, want, 15)

	for key, polarity := range want {
		var c converter
		got := c.tag(key)
		require.NoError(t, c.err, key)
		assert.Equal(t, key[len("tag."):], got.Key)
		assert.Equal(t, polarity, got.Polarity)
	}
}

func TestConvertTag_UnknownKeyIsError(t *testing.T) {
	for _, key := range []string{"tag.unknown", "big_change", ""} {
		var c converter
		c.tag(key)
		assert.Error(t, c.err, key)
	}
}

// enumCase는 proto enum 하나와 그 계약 enum으로 바꾸는 함수입니다.
type enumCase struct {
	name    string
	values  protoreflect.EnumValueDescriptors
	convert func(c *converter, n protoreflect.EnumNumber)
}

// convertCase는 proto enum 타입 E를 계약 enum T로 바꾸는 enumCase를 만듭니다.
func convertCase[E interface {
	~int32
	protoreflect.Enum
}, T contractEnum](name string) enumCase {
	var zero E
	return enumCase{
		name:   name,
		values: zero.Descriptor().Values(),
		convert: func(c *converter, n protoreflect.EnumNumber) {
			enumValue[T](c, E(n))
		},
	}
}

// TestEnumValue_AllProtoValuesMapToContract는 proto enum의 모든 값(UNSPECIFIED 제외)이
// 접두어를 떼고 소문자로 바꾼 계약 enum 값이 되는지, UNSPECIFIED와 모르는 번호는 오류인지 확인합니다.
func TestEnumValue_AllProtoValuesMapToContract(t *testing.T) {
	cases := []enumCase{
		convertCase[enginev1.Stem, gen.Stem]("Stem"),
		convertCase[enginev1.Branch, gen.Branch]("Branch"),
		convertCase[enginev1.Element, gen.FiveElement]("FiveElement"),
		convertCase[enginev1.ElementRole, gen.ElementRole]("ElementRole"),
		convertCase[enginev1.TenGod, gen.TenGod]("TenGod"),
		convertCase[enginev1.TwelveStage, gen.TwelveStage]("TwelveStage"),
		convertCase[enginev1.Shinsal, gen.ShinsalKind]("ShinsalKind"),
		convertCase[enginev1.Position, gen.Position]("Position"),
		convertCase[enginev1.Direction8, gen.Direction]("Direction"),
		convertCase[enginev1.DayKind, gen.DayKind]("DayKind"),
		convertCase[enginev1.StrengthLevel, gen.StrengthLevel]("StrengthLevel"),
		convertCase[enginev1.YongsinMethod, gen.YongsinMethod]("YongsinMethod"),
		convertCase[enginev1.LuckLevel, gen.LuckLevel]("LuckLevel"),
		convertCase[enginev1.RelationKind, gen.RelationKind]("RelationKind"),
		convertCase[enginev1.SolarTermKind, gen.SolarTermKind]("SolarTermKind"),
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			for i := range tc.values.Len() {
				v := tc.values.Get(i)
				var c converter
				tc.convert(&c, v.Number())
				if v.Number() == 0 {
					assert.Error(t, c.err, "UNSPECIFIED는 계약 값이 아닙니다")
					continue
				}
				assert.NoError(t, c.err, string(v.Name()))
			}
			var c converter
			tc.convert(&c, 999)
			assert.Error(t, c.err, "모르는 번호")
		})
	}
}

func TestEnumValue_StripsPrefixAndLowercases(t *testing.T) {
	var c converter
	assert.Equal(t, gen.BranchShin, enumValue[gen.Branch](&c, enginev1.Branch_BRANCH_SHIN))
	assert.Equal(t, gen.ElementRoleTonggwan, enumValue[gen.ElementRole](&c, enginev1.ElementRole_ELEMENT_ROLE_TONGGWAN))
	assert.Equal(t, gen.JohuNeutral, enumValue[gen.YongsinMethod](&c, enginev1.YongsinMethod_YONGSIN_METHOD_JOHU_NEUTRAL))
	assert.Equal(t, gen.Ne, enumValue[gen.Direction](&c, enginev1.Direction8_DIRECTION8_NE))
	require.NoError(t, c.err)
}
