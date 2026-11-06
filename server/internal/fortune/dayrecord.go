package fortune

import (
	"context"
	"errors"
	"fmt"
	"slices"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// FeaturedTag는 대표 태그 하나의 키(접두어를 뗀 계약 키)와 길흉입니다.
type FeaturedTag struct {
	Key      string
	Polarity Polarity
}

// DayRecord는 일기에 같이 적는 그날 엔진 결과의 기록입니다(D47·D59④).
type DayRecord struct {
	// AllTags는 그날 모든 태그의 계약 키입니다. 없으면 빈 배열입니다.
	AllTags []string
	// Featured는 대표 태그(0~2개)입니다. 없으면 빈 배열입니다.
	Featured       []FeaturedTag
	RulesetVersion string
	// GuideQuestion은 렌더한 가이드 질문(daily.guide)입니다. 원고가 없어 문장이 비면 nil입니다.
	GuideQuestion []render.Segment
	// DayKind는 그날 날의 성격의 계약 값입니다(예 gwiin_day). 사주 정보를 고쳐도 기록은 그대로입니다(D90 ①).
	DayKind string
}

// recordedDayKinds는 날짜 기록에 적을 수 있는 날의 성격입니다. 계약 DayKind와 migration 00018의 CHECK와 같습니다.
var recordedDayKinds = []string{"gwiin_day", "yongsin_day", "gisin_day", "ordinary_day"}

// DayRecord는 date의 그날 기록을 만듭니다. 오늘 화면 묶음(Daily)에서 뽑으므로 그날 선택 기록이 없으면 이때 남습니다.
// 전체 태그나 대표 태그가 길흉 표에 없거나 날의 성격이 계약 값이 아니면 엔진 계약 위반이라 오류입니다.
func (v *Views) DayRecord(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate) (DayRecord, error) {
	daily, err := v.Daily(ctx, accountID, p, date)
	if err != nil {
		return DayRecord{}, err
	}
	response := daily.Response
	dayKind := dayKindValue(response.GetKind())
	if !slices.Contains(recordedDayKinds, dayKind) {
		return DayRecord{}, fmt.Errorf("엔진 날의 성격 %q를 모릅니다", response.GetKind())
	}

	allTags := make([]string, 0, len(response.GetAllTags()))
	for _, key := range response.GetAllTags() {
		if _, ok := TagPolarity(key); !ok {
			return DayRecord{}, fmt.Errorf("엔진 태그 키 %q의 길흉을 모릅니다", key)
		}
		allTags = append(allTags, TagContractKey(key))
	}
	featured := make([]FeaturedTag, 0, len(response.GetFeaturedTags()))
	for _, key := range response.GetFeaturedTags() {
		polarity, ok := TagPolarity(key)
		if !ok {
			return DayRecord{}, fmt.Errorf("엔진 태그 키 %q의 길흉을 모릅니다", key)
		}
		featured = append(featured, FeaturedTag{Key: TagContractKey(key), Polarity: polarity})
	}

	// 원고가 없는 필수 슬롯은 빈 조각 배열이라, 기록에서는 없는 것(nil)으로 바꿉니다.
	var guide []render.Segment
	if text := daily.Texts[SlotGuide].Text; len(text) > 0 {
		guide = text
	}
	return DayRecord{
		AllTags:        allTags,
		Featured:       featured,
		RulesetVersion: response.GetMeta().GetRulesetVersion(),
		GuideQuestion:  guide,
		DayKind:        dayKind,
	}, nil
}

// ErrGuideChoiceNotFound는 고른 오늘의 질문(키, 변주)이 그날 후보(DailyView.GuideCandidates)에 없을 때 돌려줍니다.
var ErrGuideChoiceNotFound = errors.New("고른 오늘의 질문이 그날 후보에 없습니다")

// GuideChoice는 date의 오늘의 질문 후보 가운데 (messageKey, variant)가 맞는 질문의 렌더된 문장을 돌려줍니다(S140).
// 후보는 오늘 화면과 같은 묶음(Daily)에서 뽑으므로 app이 받은 후보와 같습니다. 맞는 후보가 없으면 ErrGuideChoiceNotFound,
// 맞는 후보의 원고가 비어 있으면 nil입니다(기본 질문처럼 기록하지 않음).
func (v *Views) GuideChoice(ctx context.Context, accountID uuid.UUID, p profile.Profile, date profile.LocalDate, messageKey, variant string) ([]render.Segment, error) {
	daily, err := v.Daily(ctx, accountID, p, date)
	if err != nil {
		return nil, err
	}
	for _, candidate := range daily.GuideCandidates {
		if candidate.MessageKey != messageKey || candidate.Variant != variant {
			continue
		}
		if len(candidate.Text) == 0 {
			return nil, nil
		}
		return candidate.Text, nil
	}
	return nil, ErrGuideChoiceNotFound
}
