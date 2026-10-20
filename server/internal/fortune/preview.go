package fortune

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// dayKindCategory는 용어 사전에서 날의 성격 이름이 든 범주입니다(glossary.value_name의 day_kind.<값>).
const dayKindCategory = "day_kind"

// PreviewView는 비로그인 미리보기 하나의 묶음입니다. 계정이 없어 근거는 늘 잠겨 있고(근거를 렌더하지 않음) 선택 기록도 남기지 않습니다.
type PreviewView struct {
	Response *enginev1.DailyResponse
	// Head는 총운 문장입니다. 원고가 없으면 Text가 빈 조각 배열입니다.
	Head content.SlotText
	// Tag는 총운 보조 문장입니다. 엔진이 보조 판정을 줬고 원고가 있을 때만 있습니다.
	Tag *content.SlotText
	// DayKindName은 활성 시드 용어 사전의 날의 성격 이름입니다.
	DayKindName string
	Notices     []content.Notice
	// Date는 currentTimezone 기준 오늘입니다.
	Date profile.LocalDate
}

// Preview는 currentTimezone 기준 오늘의 미리보기 묶음을 만듭니다. 입력(출생 정보)은 검증을 마친 값이어야 합니다.
//
// 계정이 없어 순환 기록이 없으므로 총운 문장은 advice 유형(새 사용자 첫 차례)에 호칭 없이 활성 시드로 렌더하고,
// 선택 기록(daily_selections)은 남기지 않습니다(P6-5). 날의 성격 이름이 용어 사전에 없으면 enum 값을 대신 쓰지 않고
// 오류로 드러냅니다(P6-6). 활성 시드가 없으면 content.ErrNoActiveSeed, 엔진 오류는 그대로 돌려줍니다.
func (v *Views) Preview(ctx context.Context, b profile.Birth, currentTimezone, lang string) (PreviewView, error) {
	version, err := v.store.Active(ctx)
	if err != nil {
		return PreviewView{}, err
	}
	date, err := v.today(currentTimezone)
	if err != nil {
		return PreviewView{}, err
	}
	response, err := v.service.Daily(ctx, b, date, currentTimezone)
	if err != nil {
		return PreviewView{}, err
	}
	fortunes := response.GetFortune()
	if len(fortunes) == 0 {
		return PreviewView{}, errors.New("엔진 데일리 응답에 총운 판정이 없습니다")
	}
	name, err := v.dayKindName(ctx, version, lang, response.GetKind())
	if err != nil {
		return PreviewView{}, err
	}
	tpl, err := v.store.Templates(ctx, version, lang)
	if err != nil {
		return PreviewView{}, err
	}

	view := PreviewView{Response: response, DayKindName: name, Date: date, Notices: v.renderNotices(ctx, tpl, response.GetMeta())}
	// 총운 문장은 계약에서 필수라 원고가 없으면 빈 문장으로 채웁니다(로그는 Renderer가 남김).
	head, ok := v.renderer.Slot(ctx, tpl, SlotFortuneHead, content.VariantAdvice, fortunes[0], "", false)
	if !ok {
		head = emptyText(SlotFortuneHead, fortunes[0].GetMessageKey(), content.VariantAdvice)
	}
	view.Head = head
	if len(fortunes) > 1 {
		// 보조 문장은 계약에서 선택 필드라 원고가 없으면 뺍니다(로그는 Renderer가 남김).
		if tag, ok := v.renderer.Slot(ctx, tpl, SlotFortuneTag, content.VariantAdvice, fortunes[1], "", false); ok {
			view.Tag = &tag
		}
	}
	return view, nil
}

// dayKindName은 용어 사전의 날의 성격 이름입니다. 이름이 없으면 원고 누락이라 오류입니다(P6-6).
func (v *Views) dayKindName(ctx context.Context, version, lang string, kind enginev1.DayKind) (string, error) {
	value := strings.ToLower(strings.TrimPrefix(kind.String(), "DAY_KIND_"))
	glossary, err := v.store.Glossary(ctx, version, lang)
	if err != nil {
		return "", err
	}
	name, ok := glossary.Values[dayKindCategory][value]
	if !ok || name == "" {
		return "", fmt.Errorf("용어 사전에 %s.%s 이름이 없습니다(시드 %s, 언어 %s)", dayKindCategory, value, version, lang)
	}
	return name, nil
}
