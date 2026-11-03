package fortune

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/profile"
)

// ErrEmptyPushBody는 그날 총운 머리 문장을 렌더하지 못해 알림 본문이 비었다는 뜻입니다.
var ErrEmptyPushBody = errors.New("알림 본문이 비었습니다")

// PushBody는 date의 아침 알림 본문입니다(IA system-push.morning.body, D62).
// 오늘 화면과 같은 선택 기록(알림이 그날 첫 요청이면 여기서 정해짐)의 총운 머리 문장을 호칭 없이 렌더하고,
// 용어 토큰은 표시 글자만 이어 평문으로 만듭니다(잠금 화면에 보이므로 호칭을 쓰지 않음, S13).
func (v *Views) PushBody(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (string, error) {
	p.Honorific = ""
	view, err := v.Daily(ctx, accountID, p, date)
	if err != nil {
		return "", err
	}
	var b strings.Builder
	for _, segment := range view.Texts[SlotFortuneHead].Text {
		b.WriteString(segment.Text)
	}
	body := strings.TrimSpace(b.String())
	if body == "" {
		return "", ErrEmptyPushBody
	}
	return body, nil
}
