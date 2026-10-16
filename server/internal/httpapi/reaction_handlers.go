package httpapi

import (
	"context"
	"errors"
	"time"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// PutReaction은 그날 그 슬롯에 보인 문장에 반응을 남깁니다. 같은 요청을 다시 보내도 결과가 같습니다.
// 오류는 daySelection을 따릅니다.
func (a *API) PutReaction(ctx context.Context, req gen.PutReactionRequestObject) (gen.PutReactionResponseObject, error) {
	sel, err := a.daySelection(ctx, req.Date, req.Slot)
	if err != nil {
		return nil, err
	}
	err = a.Contents.PutReaction(ctx, sel.ID, string(req.Body.Reaction))
	if errors.Is(err, content.ErrSelectionNotFound) {
		return nil, newError(problem.ReactionNotFound, "Reaction not found")
	}
	if err != nil {
		return nil, err
	}
	return gen.PutReaction204Response{}, nil
}

// DeleteReaction은 남긴 반응을 지웁니다(soft delete). 반응이 없어도 204입니다. 오류는 daySelection을 따릅니다.
func (a *API) DeleteReaction(ctx context.Context, req gen.DeleteReactionRequestObject) (gen.DeleteReactionResponseObject, error) {
	sel, err := a.daySelection(ctx, req.Date, req.Slot)
	if err != nil {
		return nil, err
	}
	if err := a.Contents.DeleteReaction(ctx, sel.ID); err != nil {
		return nil, err
	}
	return gen.DeleteReaction204Response{}, nil
}

// daySelection은 반응을 남길 선택 기록을 찾습니다. (계정, 날짜, 슬롯, 현재 프로필의 사주 지문)의 기록입니다.
// 프로필이 없으면 409 profile.required, 반응할 수 없는 슬롯이거나 기록이 없으면 404 reaction.not_found입니다.
// 지문이 바뀌기 전의 옛 기록은 지금 화면에 보이지 않으므로 찾지 않습니다.
func (a *API) daySelection(ctx context.Context, date gen.Date, slot string) (content.Selection, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return content.Selection{}, errNoAccount
	}
	if a.Contents == nil {
		return content.Selection{}, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	p, err := a.Profiles.Get(ctx, id)
	if err != nil {
		return content.Selection{}, err
	}
	if !content.Reactable(slot) {
		return content.Selection{}, newError(problem.ReactionNotFound, "Reaction not found")
	}
	day := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, time.UTC)
	sel, err := a.Contents.SelectionFor(ctx, id, day, slot, profile.BirthHash(p.Birth))
	if errors.Is(err, content.ErrSelectionNotFound) {
		return content.Selection{}, newError(problem.ReactionNotFound, "Reaction not found")
	}
	if err != nil {
		return content.Selection{}, err
	}
	return sel, nil
}

// dailyReactions는 오늘 화면의 반응할 수 있는 슬롯마다 남긴 활성 반응을 한 번에 읽어 슬롯 id -> 반응으로 돌려줍니다.
func (a *API) dailyReactions(ctx context.Context, view fortune.DailyView) (map[string]string, error) {
	slotOf := make(map[int64]string, len(view.SelectionIDs))
	ids := make([]int64, 0, len(view.SelectionIDs))
	for slot, id := range view.SelectionIDs {
		if content.Reactable(slot) {
			slotOf[id] = slot
			ids = append(ids, id)
		}
	}
	reactions := map[string]string{}
	if len(ids) == 0 {
		return reactions, nil
	}
	byID, err := a.Contents.ActiveReactions(ctx, ids)
	if err != nil {
		return nil, err
	}
	for id, reaction := range byID {
		if slot, ok := slotOf[id]; ok {
			reactions[slot] = reaction
		}
	}
	return reactions, nil
}
