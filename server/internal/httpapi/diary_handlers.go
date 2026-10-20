package httpapi

import (
	"context"
	"encoding/base64"
	"errors"
	"time"

	"github.com/google/uuid"
	openapi_types "github.com/oapi-codegen/runtime/types"
	"golang.org/x/text/unicode/norm"

	"github.com/june20516/myungli-diary/server/internal/diary"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/internal/httpapi/problem"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// 일기 목록 쪽 크기 기본값과 요약 본문(excerpt)의 길이(code point)입니다. 계약 listDiaries·DiarySummary와 같습니다.
const (
	defaultDiaryLimit = 30
	excerptLength     = 100
)

// 일기 operation 오류가 가리키는 field입니다(계약 FieldError.field).
const (
	fieldDiaryDate   = "date"
	fieldDiaryCursor = "cursor"
)

// PutDiary는 그날 일기 본문을 저장합니다. 새로 만들면 201, 고치면 200입니다.
// 프로필이 없으면 409 profile.required, 오늘 이후 날짜면 422 diary.future_date,
// D41 지원 범위 밖이면 422 date.out_of_range입니다.
func (a *API) PutDiary(ctx context.Context, req gen.PutDiaryRequestObject) (gen.PutDiaryResponseObject, error) {
	id, err := a.diaryAccountID(ctx)
	if err != nil {
		return nil, err
	}
	p, err := a.Profiles.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	entry, created, err := a.Diaries.Put(ctx, id, p, localDateOf(req.Date), req.Body.Body)
	if err != nil {
		return nil, outOfRangeError(err, fieldDiaryDate)
	}
	body, err := toDiary(entry)
	if err != nil {
		return nil, err
	}
	if created {
		return gen.PutDiary201JSONResponse(body), nil
	}
	return gen.PutDiary200JSONResponse(body), nil
}

// GetDiary는 그날 일기를 돌려줍니다. 없으면 404 diary.not_found입니다.
func (a *API) GetDiary(ctx context.Context, req gen.GetDiaryRequestObject) (gen.GetDiaryResponseObject, error) {
	id, err := a.diaryAccountID(ctx)
	if err != nil {
		return nil, err
	}
	entry, err := a.Diaries.Get(ctx, id, localDateOf(req.Date))
	if err != nil {
		return nil, err
	}
	body, err := toDiary(entry)
	if err != nil {
		return nil, err
	}
	return gen.GetDiary200JSONResponse(body), nil
}

// DeleteDiary는 그날 일기를 지웁니다(soft delete). 없으면 404 diary.not_found입니다.
func (a *API) DeleteDiary(ctx context.Context, req gen.DeleteDiaryRequestObject) (gen.DeleteDiaryResponseObject, error) {
	id, err := a.diaryAccountID(ctx)
	if err != nil {
		return nil, err
	}
	if err := a.Diaries.Delete(ctx, id, localDateOf(req.Date)); err != nil {
		return nil, err
	}
	return gen.DeleteDiary204Response{}, nil
}

// RestoreDiary는 그날 지운 일기를 되살립니다. 그날 살아 있는 일기가 있으면 409 diary.date_taken,
// 지운 일기가 없으면 404 diary.not_found입니다.
func (a *API) RestoreDiary(ctx context.Context, req gen.RestoreDiaryRequestObject) (gen.RestoreDiaryResponseObject, error) {
	id, err := a.diaryAccountID(ctx)
	if err != nil {
		return nil, err
	}
	entry, err := a.Diaries.Restore(ctx, id, localDateOf(req.Date))
	if err != nil {
		return nil, err
	}
	body, err := toDiary(entry)
	if err != nil {
		return nil, err
	}
	return gen.RestoreDiary200JSONResponse(body), nil
}

// ListDiaries는 날짜 내림차순으로 일기 요약을 돌려줍니다. 쪽 크기보다 하나 더 받아 다음 쪽 여부를 정합니다(P5-6).
// 해석할 수 없는 cursor는 400 request.invalid(field cursor)이고, from > to는 빈 목록입니다(P5-7).
func (a *API) ListDiaries(ctx context.Context, req gen.ListDiariesRequestObject) (gen.ListDiariesResponseObject, error) {
	id, err := a.diaryAccountID(ctx)
	if err != nil {
		return nil, err
	}
	query := diary.ListQuery{Tag: req.Params.Tag, Limit: defaultDiaryLimit}
	if req.Params.Limit != nil {
		query.Limit = *req.Params.Limit
	}
	// 계약 검증이 limit을 1~100으로 보장하지만, 아래 entries[pageSize-1]이 panic하지 않게 한 번 더 막습니다.
	if query.Limit < 1 {
		query.Limit = defaultDiaryLimit
	}
	pageSize := query.Limit
	query.Limit++
	if req.Params.From != nil {
		from := localDateOf(*req.Params.From)
		query.From = &from
	}
	if req.Params.To != nil {
		to := localDateOf(*req.Params.To)
		query.To = &to
	}
	if req.Params.Cursor != nil {
		before, err := decodeDiaryCursor(*req.Params.Cursor)
		if err != nil {
			return nil, fieldError(problem.RequestInvalid, fieldDiaryCursor)
		}
		query.Before = &before
	}
	if query.From != nil && query.To != nil && query.From.After(*query.To) {
		return gen.ListDiaries200JSONResponse(gen.DiaryList{Items: []gen.DiarySummary{}}), nil
	}

	entries, err := a.Diaries.List(ctx, id, query)
	if err != nil {
		return nil, err
	}
	var nextCursor *string
	if len(entries) > pageSize {
		entries = entries[:pageSize]
		cursor := encodeDiaryCursor(entries[pageSize-1].Date)
		nextCursor = &cursor
	}
	items := make([]gen.DiarySummary, 0, len(entries))
	for _, e := range entries {
		item, err := toDiarySummary(e)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return gen.ListDiaries200JSONResponse(gen.DiaryList{Items: items, NextCursor: nextCursor}), nil
}

// diaryAccountID는 일기 operation 공통 앞부분으로, 인증된 계정 id를 돌려줍니다.
// Diaries가 조립되지 않은 것은 조립 실수이므로 운세와 같게 503으로 드러냅니다.
func (a *API) diaryAccountID(ctx context.Context) (uuid.UUID, error) {
	id, _, ok := AccountFrom(ctx)
	if !ok {
		return uuid.Nil, errNoAccount
	}
	if a.Diaries == nil {
		return uuid.Nil, newError(problem.ServiceUnavailable, "Service unavailable")
	}
	return id, nil
}

// localDateOf는 계약 날짜를 도메인 달력 날짜로 바꿉니다.
func localDateOf(d openapi_types.Date) profile.LocalDate {
	return profile.LocalDate{Year: d.Year(), Month: int(d.Month()), Day: d.Day()}
}

// encodeDiaryCursor는 마지막 항목의 날짜(YYYY-MM-DD)를 패딩 없는 base64url로 감쌉니다. 클라이언트에는 불투명 문자열입니다.
func encodeDiaryCursor(d profile.LocalDate) string {
	return base64.RawURLEncoding.EncodeToString([]byte(dateString(d)))
}

// decodeDiaryCursor는 encodeDiaryCursor의 역입니다. 형식이 틀리거나 실제로 없는 날짜면 오류입니다.
func decodeDiaryCursor(s string) (profile.LocalDate, error) {
	raw, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return profile.LocalDate{}, errors.New("cursor가 base64url이 아닙니다")
	}
	t, err := time.Parse(time.DateOnly, string(raw))
	if err != nil {
		return profile.LocalDate{}, errors.New("cursor가 날짜가 아닙니다")
	}
	return profile.LocalDate{Year: t.Year(), Month: int(t.Month()), Day: t.Day()}, nil
}

// dateString은 달력 날짜를 YYYY-MM-DD로 적습니다.
func dateString(d profile.LocalDate) string {
	return time.Date(d.Year, time.Month(d.Month), d.Day, 0, 0, 0, 0, time.UTC).Format(time.DateOnly)
}

// toDiary는 일기 한 편을 계약 Diary로 옮깁니다. 가이드 질문이 없으면 필드를 생략합니다.
func toDiary(e diary.Entry) (gen.Diary, error) {
	c := &converter{}
	out := gen.Diary{
		Body:           e.Body,
		CreatedAt:      e.CreatedAt,
		Date:           contractDate(e.Date),
		GuideQuestion:  optionalText(e.GuideQuestion),
		RulesetVersion: e.RulesetVersion,
		Tags: gen.DayTags{
			All:      nonNil(e.AllTags),
			Featured: featuredTags(c, e),
		},
		UpdatedAt: e.UpdatedAt,
	}
	if c.err != nil {
		return gen.Diary{}, c.err
	}
	return out, nil
}

// toDiarySummary는 목록의 일기 한 편을 요약으로 옮깁니다.
func toDiarySummary(e diary.Entry) (gen.DiarySummary, error) {
	c := &converter{}
	out := gen.DiarySummary{
		Date:         contractDate(e.Date),
		Excerpt:      excerpt(e.Body),
		FeaturedTags: featuredTags(c, e),
	}
	if c.err != nil {
		return gen.DiarySummary{}, c.err
	}
	return out, nil
}

// featuredTags는 대표 태그를 계약 Tag로 옮깁니다. 길흉이 계약 값이 아니면 c에 오류를 남깁니다(저장된 값이 깨진 경우).
func featuredTags(c *converter, e diary.Entry) []gen.Tag {
	return convertAll(e.Featured, func(t fortune.FeaturedTag) gen.Tag {
		return gen.Tag{Key: t.Key, Polarity: contractValue[gen.TagPolarity](c, "Tag.polarity", string(t.Polarity))}
	})
}

// excerpt는 본문 앞 100 code point를 NFC로 합쳐 돌려줍니다(P5-8).
func excerpt(body string) string {
	runes := []rune(norm.NFC.String(body))
	if len(runes) > excerptLength {
		runes = runes[:excerptLength]
	}
	return string(runes)
}

// nonNil은 nil slice를 빈 slice로 바꿔 JSON에서 null 대신 []로 나가게 합니다.
func nonNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

// contractDate는 달력 날짜를 계약 날짜로 바꿉니다.
func contractDate(d profile.LocalDate) openapi_types.Date {
	return openapi_types.Date{Time: time.Date(d.Year, time.Month(d.Month), d.Day, 0, 0, 0, 0, time.UTC)}
}
