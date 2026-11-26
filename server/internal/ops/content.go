package ops

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/june20516/myungli-diary/server/internal/ops/opsdb"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// ErrContentTarget은 열람 대상이 날짜와 항목 id 중 정확히 하나가 아니거나 날짜가 달력에 없을 때입니다.
var ErrContentTarget = errors.New("열람 대상은 날짜와 항목 id 중 정확히 하나여야 하고 날짜는 달력에 있어야 합니다")

// 감사 target의 열람 종류입니다.
const (
	kindDiary    = "diary"
	kindSchedule = "schedule"
	kindProfile  = "profile"
)

// ContentTarget은 열람할 범위입니다. Date와 ID 중 정확히 하나만 값이 있어야 합니다.
// 계정 전체나 날짜 범위로는 열 수 없습니다.
type ContentTarget struct {
	AccountID uuid.UUID
	Date      *profile.LocalDate
	ID        *uuid.UUID
}

// ViewRequest는 일기와 일정 열람 요청입니다.
type ViewRequest struct {
	Target  ContentTarget
	Purpose Purpose
	Reason  string
}

// DiaryView는 일기 열람 결과입니다. DeletedCount는 지웠거나 본문을 비운 일기 개수이고 본문은 담지 않습니다.
// Tags는 그날 기록(날짜 기록)의 태그입니다. 날짜 기록이 없거나 연 일기가 없으면 빈 목록입니다.
type DiaryView struct {
	Entries      []DiaryEntry
	DeletedCount int
	Tags         []string
}

// DiaryEntry는 열람한 일기 한 편입니다.
type DiaryEntry struct {
	ID        uuid.UUID
	Date      profile.LocalDate
	Body      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// ScheduleView는 일정 열람 결과입니다. DeletedCount는 지웠거나 본문을 비운 일정 개수입니다.
type ScheduleView struct {
	Entries      []ScheduleEntry
	DeletedCount int
}

// ScheduleEntry는 열람한 일정 한 건입니다. Time은 "HH:MM"이고 종일 일정이면 nil입니다.
type ScheduleEntry struct {
	ID     uuid.UUID
	Date   profile.LocalDate
	AllDay bool
	Time   *string
	Title  string
	Memo   *string
}

// ProfileView는 계산 오류 문의 확인용 프로필입니다. 값이 없는 칸은 nil입니다.
// BirthTime은 "HH:MM"입니다. 알림 설정, 출생 정보 해시, 익명화 시각은 담지 않습니다.
type ProfileView struct {
	Honorific        *string
	Language         string
	CurrentTimezone  string
	Calendar         *string
	IsLeapMonth      *bool
	BirthDate        *profile.LocalDate
	BirthTimeStatus  *string
	BirthTime        *string
	Gender           *string
	BirthTimezone    *string
	BirthPlaceStatus *string
	BirthCityID      *string
	Longitude        *float64
}

// listTarget은 일기와 일정 열람 감사 행의 target입니다. 연 항목의 id와 개수만 남기고 본문은 남기지 않습니다.
type listTarget struct {
	// AccountID는 계정이 없어도 어떤 id를 시도했는지 남기려고 항상 넣습니다.
	AccountID uuid.UUID   `json:"accountId"`
	Kind      string      `json:"kind"`
	Date      string      `json:"date,omitempty"`
	ID        *uuid.UUID  `json:"id,omitempty"`
	IDs       []uuid.UUID `json:"ids"`
	Count     int         `json:"count"`
}

// profileTarget은 프로필 열람 감사 행의 target입니다. 연 프로필 수만 남깁니다.
type profileTarget struct {
	AccountID uuid.UUID `json:"accountId"`
	Kind      string    `json:"kind"`
	Count     int       `json:"count"`
}

// viewInput은 검사를 마친 열람 요청입니다.
type viewInput struct {
	AccountID uuid.UUID
	Purpose   Purpose
	Reason    string
}

// ViewDiary는 날짜 또는 일기 id로 좁혀 살아 있는 일기를 엽니다.
// 조회와 감사 행 쓰기가 한 트랜잭션이라, 감사 행이 커밋되지 않으면 본문을 돌려주지 않습니다.
// 다른 계정의 id는 빈 결과이고 감사 행은 남습니다. 계정이 없으면 감사 행을 남기고 ErrAccountNotFound입니다.
func (s *Service) ViewDiary(ctx context.Context, actor Actor, req ViewRequest) (DiaryView, error) {
	in, err := validateView(actor, req)
	if err != nil {
		return DiaryView{}, err
	}
	target := req.Target
	var view DiaryView
	err = s.runView(ctx, actor, in, listTargetOf(kindDiary, target), func(q *opsdb.Queries) ([]uuid.UUID, bool, error) {
		view = DiaryView{Entries: []DiaryEntry{}, Tags: []string{}}
		entries, deleted, err := loadDiaries(ctx, q, target)
		if err != nil {
			return nil, false, err
		}
		view.Entries, view.DeletedCount = entries, deleted
		if len(entries) > 0 {
			tags, err := q.GetOpsDiaryDayTags(ctx, opsdb.GetOpsDiaryDayTagsParams{AccountID: target.AccountID, Date: profile.PgDate(entries[0].Date)})
			if err != nil && !errors.Is(err, pgx.ErrNoRows) {
				return nil, false, fmt.Errorf("날짜 기록 태그 조회: %w", err)
			}
			if tags != nil {
				view.Tags = tags
			}
		}
		ids := make([]uuid.UUID, 0, len(entries))
		for _, entry := range entries {
			ids = append(ids, entry.ID)
		}
		return ids, true, nil
	})
	if err != nil {
		return DiaryView{}, err
	}
	return view, nil
}

// loadDiaries는 날짜 또는 id로 좁힌 살아 있는 일기와 지운 일기 개수를 읽습니다.
func loadDiaries(ctx context.Context, q *opsdb.Queries, target ContentTarget) ([]DiaryEntry, int, error) {
	entries := []DiaryEntry{}
	var (
		deleted int64
		err     error
	)
	if target.Date != nil {
		date := profile.PgDate(*target.Date)
		var rows []opsdb.ListOpsDiariesByDateRow
		if rows, err = q.ListOpsDiariesByDate(ctx, opsdb.ListOpsDiariesByDateParams{AccountID: target.AccountID, Date: date}); err == nil {
			for _, row := range rows {
				entries = append(entries, toDiaryEntry(row.ID, row.Date.Time, row.Body, row.CreatedAt, row.UpdatedAt))
			}
			deleted, err = q.CountOpsDeletedDiariesByDate(ctx, opsdb.CountOpsDeletedDiariesByDateParams{AccountID: target.AccountID, Date: date})
		}
	} else {
		params := opsdb.ListOpsDiariesByIDParams{AccountID: target.AccountID, ID: *target.ID}
		var rows []opsdb.ListOpsDiariesByIDRow
		if rows, err = q.ListOpsDiariesByID(ctx, params); err == nil {
			for _, row := range rows {
				entries = append(entries, toDiaryEntry(row.ID, row.Date.Time, row.Body, row.CreatedAt, row.UpdatedAt))
			}
			deleted, err = q.CountOpsDeletedDiariesByID(ctx, opsdb.CountOpsDeletedDiariesByIDParams(params))
		}
	}
	if err != nil {
		return nil, 0, fmt.Errorf("일기 조회: %w", err)
	}
	return entries, int(deleted), nil
}

func toDiaryEntry(id uuid.UUID, date time.Time, body string, createdAt, updatedAt time.Time) DiaryEntry {
	return DiaryEntry{
		ID: id, Date: profile.LocalDate{Year: date.Year(), Month: int(date.Month()), Day: date.Day()},
		Body: body, CreatedAt: createdAt, UpdatedAt: updatedAt,
	}
}

// ViewSchedule은 날짜 또는 일정 id로 좁혀 살아 있는 일정을 엽니다. 감사와 오류 규칙은 ViewDiary와 같습니다.
func (s *Service) ViewSchedule(ctx context.Context, actor Actor, req ViewRequest) (ScheduleView, error) {
	in, err := validateView(actor, req)
	if err != nil {
		return ScheduleView{}, err
	}
	target := req.Target
	var view ScheduleView
	err = s.runView(ctx, actor, in, listTargetOf(kindSchedule, target), func(q *opsdb.Queries) ([]uuid.UUID, bool, error) {
		view = ScheduleView{Entries: []ScheduleEntry{}}
		entries, deleted, err := loadSchedules(ctx, q, target)
		if err != nil {
			return nil, false, err
		}
		view.Entries, view.DeletedCount = entries, deleted
		ids := make([]uuid.UUID, 0, len(entries))
		for _, entry := range entries {
			ids = append(ids, entry.ID)
		}
		return ids, true, nil
	})
	if err != nil {
		return ScheduleView{}, err
	}
	return view, nil
}

// loadSchedules는 날짜 또는 id로 좁힌 살아 있는 일정과 지운 일정 개수를 읽습니다.
func loadSchedules(ctx context.Context, q *opsdb.Queries, target ContentTarget) ([]ScheduleEntry, int, error) {
	entries := []ScheduleEntry{}
	var (
		deleted int64
		err     error
	)
	if target.Date != nil {
		date := profile.PgDate(*target.Date)
		var rows []opsdb.ListOpsSchedulesByDateRow
		if rows, err = q.ListOpsSchedulesByDate(ctx, opsdb.ListOpsSchedulesByDateParams{AccountID: target.AccountID, Date: date}); err == nil {
			for _, row := range rows {
				entries = append(entries, toScheduleEntry(row.ID, row.Date, row.AllDay, row.Time, row.Title, row.Memo))
			}
			deleted, err = q.CountOpsDeletedSchedulesByDate(ctx, opsdb.CountOpsDeletedSchedulesByDateParams{AccountID: target.AccountID, Date: date})
		}
	} else {
		params := opsdb.ListOpsSchedulesByIDParams{AccountID: target.AccountID, ID: *target.ID}
		var rows []opsdb.ListOpsSchedulesByIDRow
		if rows, err = q.ListOpsSchedulesByID(ctx, params); err == nil {
			for _, row := range rows {
				entries = append(entries, toScheduleEntry(row.ID, row.Date, row.AllDay, row.Time, row.Title, row.Memo))
			}
			deleted, err = q.CountOpsDeletedSchedulesByID(ctx, opsdb.CountOpsDeletedSchedulesByIDParams(params))
		}
	}
	if err != nil {
		return nil, 0, fmt.Errorf("일정 조회: %w", err)
	}
	return entries, int(deleted), nil
}

func toScheduleEntry(id uuid.UUID, date pgtype.Date, allDay bool, at pgtype.Time, title string, memo pgtype.Text) ScheduleEntry {
	entry := ScheduleEntry{ID: id, Date: profile.LocalDateFromPg(date), AllDay: allDay, Title: title, Time: formatClock(at)}
	if memo.Valid {
		entry.Memo = &memo.String
	}
	return entry
}

// formatClock은 DB time 값을 "HH:MM"으로 바꿉니다. NULL이면 nil입니다.
func formatClock(t pgtype.Time) *string {
	local := profile.LocalTimeFromPg(t)
	if local == nil {
		return nil
	}
	text := fmt.Sprintf("%02d:%02d", local.Hour, local.Minute)
	return &text
}

// ViewProfile은 계산 오류 문의 확인용으로 프로필(호칭, 출생 정보)을 엽니다. 감사 규칙은 ViewDiary와 같습니다.
// 계정이나 프로필 행이 없으면 감사 행을 남기고 ErrAccountNotFound입니다.
func (s *Service) ViewProfile(ctx context.Context, actor Actor, accountID uuid.UUID, purpose Purpose, reason string) (ProfileView, error) {
	in, err := validateViewInput(actor, accountID, purpose, reason)
	if err != nil {
		return ProfileView{}, err
	}
	var view ProfileView
	err = s.runView(ctx, actor, in, func(opened []uuid.UUID) any {
		return profileTarget{AccountID: accountID, Kind: kindProfile, Count: len(opened)}
	}, func(q *opsdb.Queries) ([]uuid.UUID, bool, error) {
		view = ProfileView{}
		row, err := q.GetOpsProfile(ctx, accountID)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, false, nil
		}
		if err != nil {
			return nil, false, fmt.Errorf("프로필 조회: %w", err)
		}
		view = toProfileView(row)
		return []uuid.UUID{accountID}, true, nil
	})
	if err != nil {
		return ProfileView{}, err
	}
	return view, nil
}

func toProfileView(row opsdb.GetOpsProfileRow) ProfileView {
	view := ProfileView{
		Honorific:        textPtr(row.Honorific),
		Language:         row.Language,
		CurrentTimezone:  row.CurrentTimezone,
		Calendar:         textPtr(row.Calendar),
		BirthTimeStatus:  textPtr(row.BirthTimeStatus),
		BirthTime:        formatClock(row.BirthTime),
		Gender:           textPtr(row.Gender),
		BirthTimezone:    textPtr(row.BirthTimezone),
		BirthPlaceStatus: textPtr(row.BirthPlaceStatus),
		BirthCityID:      textPtr(row.BirthCityID),
	}
	if row.IsLeapMonth.Valid {
		view.IsLeapMonth = &row.IsLeapMonth.Bool
	}
	if row.BirthYear.Valid && row.BirthMonth.Valid && row.BirthDay.Valid {
		view.BirthDate = &profile.LocalDate{Year: int(row.BirthYear.Int16), Month: int(row.BirthMonth.Int16), Day: int(row.BirthDay.Int16)}
	}
	if row.Longitude.Valid {
		view.Longitude = &row.Longitude.Float64
	}
	return view
}

func textPtr(t pgtype.Text) *string {
	if !t.Valid {
		return nil
	}
	return &t.String
}

// validateView는 DB에 붙기 전에 실행자, 사유, 목적, 열람 대상을 검사합니다.
func validateView(actor Actor, req ViewRequest) (viewInput, error) {
	in, err := validateViewInput(actor, req.Target.AccountID, req.Purpose, req.Reason)
	if err != nil {
		return viewInput{}, err
	}
	if err := validateContentTarget(req.Target); err != nil {
		return viewInput{}, err
	}
	return in, nil
}

// validateViewInput은 실행자, 사유, 목적을 검사합니다. 프로필 열람은 좁힐 날짜나 id가 없어 이 검사만 합니다.
func validateViewInput(actor Actor, accountID uuid.UUID, purpose Purpose, reason string) (viewInput, error) {
	if err := validateActor(actor); err != nil {
		return viewInput{}, err
	}
	cleaned, err := ValidateReason(reason)
	if err != nil {
		return viewInput{}, err
	}
	checked, err := ParsePurpose(string(purpose))
	if err != nil {
		return viewInput{}, err
	}
	return viewInput{AccountID: accountID, Purpose: checked, Reason: cleaned}, nil
}

// validateContentTarget은 날짜와 id 중 정확히 하나만 있고 날짜가 달력에 있는지 검사합니다.
func validateContentTarget(t ContentTarget) error {
	if (t.Date == nil) == (t.ID == nil) {
		return ErrContentTarget
	}
	if t.Date != nil {
		d := *t.Date
		if got := time.Date(d.Year, time.Month(d.Month), d.Day, 0, 0, 0, 0, time.UTC); got.Year() != d.Year || int(got.Month()) != d.Month || got.Day() != d.Day {
			return ErrContentTarget
		}
	}
	return nil
}

// listTargetOf는 열람한 항목 id로 일기와 일정의 감사 target을 만드는 함수를 돌려줍니다.
func listTargetOf(kind string, t ContentTarget) func([]uuid.UUID) any {
	return func(opened []uuid.UUID) any {
		target := listTarget{AccountID: t.AccountID, Kind: kind, ID: t.ID, IDs: opened, Count: len(opened)}
		if target.IDs == nil {
			target.IDs = []uuid.UUID{}
		}
		if t.Date != nil {
			target.Date = fmt.Sprintf("%04d-%02d-%02d", t.Date.Year, t.Date.Month, t.Date.Day)
		}
		return target
	}
}

// runView는 계정 확인, 열람, 감사 행 쓰기를 한 트랜잭션에서 합니다.
// load는 연 항목 id와 대상을 찾았는지를 돌려줍니다. 계정이 없으면 load를 부르지 않습니다.
// 대상을 못 찾아도 감사 행은 커밋하고 그 뒤에 ErrAccountNotFound를 돌려줍니다.
func (s *Service) runView(ctx context.Context, actor Actor, in viewInput, targetOf func([]uuid.UUID) any,
	load func(q *opsdb.Queries) ([]uuid.UUID, bool, error)) error {
	auditID := uuid.New()
	notFound := false
	err := s.inTx(ctx, func(tx pgx.Tx) error {
		q := opsdb.New(tx)
		notFound = false
		var accountID *uuid.UUID
		if _, err := q.GetOpsAccount(ctx, in.AccountID); err == nil {
			accountID = &in.AccountID
		} else if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("계정 조회: %w", err)
		}

		var opened []uuid.UUID
		if accountID != nil {
			ids, found, err := load(q)
			if err != nil {
				return err
			}
			opened, notFound = ids, !found
		} else {
			notFound = true
		}

		purpose := in.Purpose
		return recordTx(ctx, tx, auditID, s.clk.Now(), Entry{
			Actor: actor, Action: ActionContentView, AccountID: accountID, Purpose: &purpose, Reason: in.Reason,
			Target: targetOf(opened),
		})
	})
	switch {
	case err != nil:
		return err
	case notFound:
		return ErrAccountNotFound
	}
	return nil
}
