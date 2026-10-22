// Package diary는 일기(한 날짜 여러 편, D83)를 저장하고 읽는 저장소를 둡니다.
package diary

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/diary/diarydb"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

// MaxEntriesPerDay는 한 날짜에 살아 있을 수 있는 일기의 최대 편수입니다(D83 ②). 만들기와 되살리기에만 겁니다.
const MaxEntriesPerDay = 10

var (
	// ErrNotFound는 (복원할 때는 지운 것을 포함해) 그 일기가 없거나 내용을 비웠거나 남의 것일 때 돌려줍니다.
	ErrNotFound = errors.New("일기를 찾을 수 없습니다")
	// ErrDayFull은 그 날짜에 살아 있는 일기가 이미 MaxEntriesPerDay편일 때 돌려줍니다.
	ErrDayFull = errors.New("그 날짜의 일기가 가득 찼습니다")
	// ErrDayRecordMissing은 날짜 기록 없이 일기를 만들려는데 그 날짜 기록이 없을 때 돌려줍니다.
	ErrDayRecordMissing = errors.New("그 날짜의 날짜 기록이 없습니다")
)

// Entry는 일기 한 편입니다.
// AllTags·Featured·GuideQuestion·RulesetVersion은 그날 첫 편을 쓸 때 본 엔진 결과와 질문의 기록(날짜 기록)이고, 같은 날 일기에 똑같이 붙습니다.
type Entry struct {
	ID             uuid.UUID
	Date           profile.LocalDate
	Body           string
	AllTags        []string
	Featured       []fortune.FeaturedTag
	GuideQuestion  []render.Segment // 질문이 없으면 비어 있습니다(DB에는 NULL).
	RulesetVersion string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// Cursor는 목록 keyset의 위치입니다. 마지막으로 본 일기의 (날짜, 작성 시각, id)입니다.
type Cursor struct {
	Date      profile.LocalDate
	CreatedAt time.Time
	ID        uuid.UUID
}

// ListQuery는 목록 조건입니다. 포인터 필드는 nil이면 조건을 걸지 않습니다.
// From·To는 포함 범위이고, After는 그 Cursor 다음 일기부터 보는 keyset 커서입니다.
// 순서는 날짜 역순, 같은 날짜 안에서는 작성 순(created_at, id)입니다.
type ListQuery struct {
	From, To *profile.LocalDate
	Tag      *string
	After    *Cursor
	Limit    int
}

// Store는 PostgreSQL 일기 저장소입니다.
type Store struct {
	pool *pgxpool.Pool
}

// NewStore는 연결 풀 위에 저장소를 만듭니다.
func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// DayExists는 그 날짜의 날짜 기록이 있는지 알려 줍니다. 일기를 다 지워도 날짜 기록은 남습니다.
func (s *Store) DayExists(ctx context.Context, accountID uuid.UUID, date profile.LocalDate) (bool, error) {
	exists, err := diarydb.New(s.pool).DiaryDayExists(ctx, diarydb.DiaryDayExistsParams{AccountID: accountID, Date: profile.PgDate(date)})
	if err != nil {
		return false, fmt.Errorf("날짜 기록 확인: %w", err)
	}
	return exists, nil
}

// CreateEntry는 date에 일기를 한 편 만듭니다. 한 트랜잭션에서 날짜 기록 넣기, 날짜 잠금, 편수 확인, 일기 넣기 순으로 처리합니다(spec §2.4).
// record가 있으면 날짜 기록이 없을 때 그것을 적고, 이미 있으면 먼저 넣은 기록을 그대로 둡니다.
// record가 nil인데 날짜 기록이 없으면 ErrDayRecordMissing, 그 날짜에 살아 있는 일기가 이미 MaxEntriesPerDay편이면 ErrDayFull입니다.
func (s *Store) CreateEntry(ctx context.Context, accountID uuid.UUID, date profile.LocalDate, body string, record *fortune.DayRecord) (Entry, error) {
	id, err := uuid.NewV7()
	if err != nil {
		return Entry{}, fmt.Errorf("일기 ID 생성: %w", err)
	}
	var entry Entry
	err = postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := diarydb.New(tx)
		pgDate := profile.PgDate(date)
		if record != nil {
			params, err := newDayParams(accountID, date, record)
			if err != nil {
				return err
			}
			if err := q.InsertDiaryDay(ctx, params); err != nil {
				return fmt.Errorf("날짜 기록 저장: %w", err)
			}
		}
		if err := lockAndCheckRoom(ctx, q, accountID, pgDate); err != nil {
			return err
		}
		row, err := q.InsertDiary(ctx, diarydb.InsertDiaryParams{ID: id, AccountID: accountID, Date: pgDate, Body: body})
		if err != nil {
			return fmt.Errorf("일기 저장: %w", err)
		}
		entry, err = toEntry(diarydb.GetDiaryRow(row))
		return err
	})
	if err != nil {
		return Entry{}, err
	}
	return entry, nil
}

// lockAndCheckRoom은 그 날짜의 날짜 기록 행을 잠그고(같은 날짜의 만들기·되살리기가 줄을 섭니다) 일기를 더 둘 자리가 있는지 확인합니다.
// 날짜 기록이 없으면 ErrDayRecordMissing, 자리가 없으면 ErrDayFull입니다.
func lockAndCheckRoom(ctx context.Context, q *diarydb.Queries, accountID uuid.UUID, date pgtype.Date) error {
	_, err := q.LockDiaryDay(ctx, diarydb.LockDiaryDayParams{AccountID: accountID, Date: date})
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrDayRecordMissing
	}
	if err != nil {
		return fmt.Errorf("날짜 잠금: %w", err)
	}
	live, err := q.CountLiveDiaries(ctx, diarydb.CountLiveDiariesParams{AccountID: accountID, Date: date})
	if err != nil {
		return fmt.Errorf("일기 편수 확인: %w", err)
	}
	if live >= MaxEntriesPerDay {
		return ErrDayFull
	}
	return nil
}

// Get은 살아 있는 일기를 날짜 기록과 함께 돌려줍니다. 없거나 남의 것이면 ErrNotFound입니다.
func (s *Store) Get(ctx context.Context, accountID, id uuid.UUID) (Entry, error) {
	row, err := diarydb.New(s.pool).GetDiary(ctx, diarydb.GetDiaryParams{ID: id, AccountID: accountID})
	if errors.Is(err, pgx.ErrNoRows) {
		return Entry{}, ErrNotFound
	}
	if err != nil {
		return Entry{}, fmt.Errorf("일기 조회: %w", err)
	}
	return toEntry(row)
}

// UpdateBody는 살아 있는 일기의 본문만 바꿉니다. 날짜 기록과 생성 시각은 그대로입니다.
// 살아 있는 일기가 없거나 남의 것이면 ErrNotFound입니다.
func (s *Store) UpdateBody(ctx context.Context, accountID, id uuid.UUID, body string) (Entry, error) {
	row, err := diarydb.New(s.pool).UpdateDiaryBody(ctx, diarydb.UpdateDiaryBodyParams{ID: id, AccountID: accountID, Body: body})
	if errors.Is(err, pgx.ErrNoRows) {
		return Entry{}, ErrNotFound
	}
	if err != nil {
		return Entry{}, fmt.Errorf("일기 본문 수정: %w", err)
	}
	return toEntry(diarydb.GetDiaryRow(row))
}

// Delete는 일기를 지운 것으로 표시합니다(soft delete). 살아 있는 일기가 없거나 남의 것이면 ErrNotFound입니다.
func (s *Store) Delete(ctx context.Context, accountID, id uuid.UUID) error {
	n, err := diarydb.New(s.pool).SoftDeleteDiary(ctx, diarydb.SoftDeleteDiaryParams{ID: id, AccountID: accountID})
	if err != nil {
		return fmt.Errorf("일기 삭제: %w", err)
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// Restore는 지운 일기를 되살립니다. 이미 살아 있으면 상한을 보지 않고 그대로 돌려줍니다.
// 대상 행을 먼저 잠그므로 같은 일기의 동시 되살리기·지우기는 줄을 섭니다.
// 없거나 남의 것이거나 내용을 비웠으면 ErrNotFound, 되살리면 그 날짜가 MaxEntriesPerDay편을 넘으면 ErrDayFull입니다.
func (s *Store) Restore(ctx context.Context, accountID, id uuid.UUID) (Entry, error) {
	var entry Entry
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := diarydb.New(tx)
		state, err := q.GetDiaryState(ctx, diarydb.GetDiaryStateParams{ID: id, AccountID: accountID})
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return fmt.Errorf("일기 상태 조회: %w", err)
		}
		if state.ContentPurgedAt != nil {
			return ErrNotFound
		}
		if state.DeletedAt != nil {
			if err := lockAndCheckRoom(ctx, q, accountID, state.Date); err != nil {
				return err
			}
			if err := q.UndeleteDiary(ctx, diarydb.UndeleteDiaryParams{ID: id, AccountID: accountID}); err != nil {
				return fmt.Errorf("일기 복원: %w", err)
			}
		}
		row, err := q.GetDiary(ctx, diarydb.GetDiaryParams{ID: id, AccountID: accountID})
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound // 방어: 행을 잠갔으므로 보통 오지 않습니다.
		}
		if err != nil {
			return fmt.Errorf("일기 조회: %w", err)
		}
		entry, err = toEntry(row)
		return err
	})
	if err != nil {
		return Entry{}, err
	}
	return entry, nil
}

// List는 날짜 역순(같은 날짜는 작성 순)으로 살아 있는 일기를 q.Limit편까지 돌려줍니다.
func (s *Store) List(ctx context.Context, accountID uuid.UUID, q ListQuery) ([]Entry, error) {
	if q.Limit <= 0 || q.Limit > math.MaxInt32 {
		return nil, fmt.Errorf("일기 목록 Limit이 범위를 벗어났습니다: %d", q.Limit)
	}
	params := diarydb.ListDiariesParams{
		AccountID: accountID,
		FromDate:  profile.PgDateOrNull(q.From),
		ToDate:    profile.PgDateOrNull(q.To),
		RowLimit:  int32(q.Limit), // 위에서 범위를 검사했습니다.
	}
	if q.Tag != nil {
		params.Tag = pgtype.Text{String: *q.Tag, Valid: true}
	}
	if q.After != nil {
		params.AfterDate = profile.PgDate(q.After.Date)
		params.AfterCreatedAt = &q.After.CreatedAt
		params.AfterID = uuid.NullUUID{UUID: q.After.ID, Valid: true}
	}
	rows, err := diarydb.New(s.pool).ListDiaries(ctx, params)
	if err != nil {
		return nil, fmt.Errorf("일기 목록 조회: %w", err)
	}
	entries := make([]Entry, 0, len(rows))
	for _, row := range rows {
		entry, err := toEntry(diarydb.GetDiaryRow(row))
		if err != nil {
			return nil, err
		}
		entries = append(entries, entry)
	}
	return entries, nil
}

// featuredJSON·segmentJSON은 jsonb에 적는 모양입니다. term은 없으면 생략합니다.
type featuredJSON struct {
	Key      string `json:"key"`
	Polarity string `json:"polarity"`
}

type segmentJSON struct {
	Text string `json:"text"`
	Term string `json:"term,omitempty"`
}

// newDayParams는 날짜 기록을 InsertDiaryDay 인자로 바꿉니다. 질문이 비어 있으면 guide는 NULL입니다.
func newDayParams(accountID uuid.UUID, date profile.LocalDate, r *fortune.DayRecord) (diarydb.InsertDiaryDayParams, error) {
	featured, guide, err := encodeJSON(r)
	if err != nil {
		return diarydb.InsertDiaryDayParams{}, err
	}
	allTags := r.AllTags
	if allTags == nil {
		allTags = []string{}
	}
	return diarydb.InsertDiaryDayParams{
		AccountID:      accountID,
		Date:           profile.PgDate(date),
		AllTags:        allTags,
		FeaturedTags:   featured,
		GuideQuestion:  guide,
		RulesetVersion: r.RulesetVersion,
	}, nil
}

// encodeJSON은 r의 길흉 태그와 가이드 질문을 jsonb 값으로 바꿉니다. 질문이 비어 있으면 guide는 nil(NULL)입니다.
func encodeJSON(r *fortune.DayRecord) (featured, guide []byte, err error) {
	tags := make([]featuredJSON, len(r.Featured))
	for i, t := range r.Featured {
		tags[i] = featuredJSON{Key: t.Key, Polarity: string(t.Polarity)}
	}
	if featured, err = json.Marshal(tags); err != nil {
		return nil, nil, fmt.Errorf("대표 태그 직렬화: %w", err)
	}
	if len(r.GuideQuestion) == 0 {
		return featured, nil, nil
	}
	segments := make([]segmentJSON, len(r.GuideQuestion))
	for i, seg := range r.GuideQuestion {
		segments[i] = segmentJSON{Text: seg.Text, Term: seg.Term}
	}
	if guide, err = json.Marshal(segments); err != nil {
		return nil, nil, fmt.Errorf("가이드 질문 직렬화: %w", err)
	}
	return featured, guide, nil
}

// toEntry는 조회한 행을 Entry로 바꿉니다. 일기 본문은 오류 메시지에 담지 않습니다.
func toEntry(row diarydb.GetDiaryRow) (Entry, error) {
	var tags []featuredJSON
	if err := json.Unmarshal(row.FeaturedTags, &tags); err != nil {
		return Entry{}, fmt.Errorf("대표 태그 해석: %w", err)
	}
	featured := make([]fortune.FeaturedTag, len(tags))
	for i, t := range tags {
		featured[i] = fortune.FeaturedTag{Key: t.Key, Polarity: fortune.Polarity(t.Polarity)}
	}
	var guide []render.Segment
	if row.GuideQuestion != nil {
		var segments []segmentJSON
		if err := json.Unmarshal(row.GuideQuestion, &segments); err != nil {
			return Entry{}, fmt.Errorf("가이드 질문 해석: %w", err)
		}
		guide = make([]render.Segment, len(segments))
		for i, seg := range segments {
			guide[i] = render.Segment{Text: seg.Text, Term: seg.Term}
		}
	}
	return Entry{
		ID:             row.ID,
		Date:           profile.LocalDateFromPg(row.Date),
		Body:           row.Body,
		AllTags:        row.AllTags,
		Featured:       featured,
		GuideQuestion:  guide,
		RulesetVersion: row.RulesetVersion,
		CreatedAt:      row.CreatedAt,
		UpdatedAt:      row.UpdatedAt,
	}, nil
}
