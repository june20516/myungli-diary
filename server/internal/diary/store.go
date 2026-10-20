// Package diary는 일기(하루 1편)를 저장하고 읽는 저장소를 둡니다.
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
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/content/render"
	"github.com/june20516/myungli-diary/server/internal/diary/diarydb"
	"github.com/june20516/myungli-diary/server/internal/fortune"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/internal/profile"
)

var (
	// ErrNotFound는 그 날짜에 (복원할 때는 지운) 일기가 없을 때 돌려줍니다.
	ErrNotFound = errors.New("일기를 찾을 수 없습니다")
	// ErrDateTaken은 복원하려는 날짜에 이미 살아 있는 일기가 있을 때 돌려줍니다.
	ErrDateTaken = errors.New("그 날짜에 이미 일기가 있습니다")
)

// uniqueViolation은 PostgreSQL의 unique 위반 SQLSTATE입니다.
const uniqueViolation = "23505"

// Entry는 일기 한 편입니다.
// AllTags·Featured·GuideQuestion·RulesetVersion은 처음 쓸 때 본 그날 엔진 결과와 질문의 기록입니다.
type Entry struct {
	Date           profile.LocalDate
	Body           string
	AllTags        []string
	Featured       []fortune.FeaturedTag
	GuideQuestion  []render.Segment // 질문이 없으면 비어 있습니다(DB에는 NULL).
	RulesetVersion string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// ListQuery는 목록 조건입니다. 포인터 필드는 nil이면 조건을 걸지 않습니다.
// From·To는 포함 범위이고, Before는 그 날짜보다 앞 일기만 보는 keyset 커서입니다.
type ListQuery struct {
	From, To *profile.LocalDate
	Tag      *string
	Before   *profile.LocalDate
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

// Get은 그 날짜의 살아 있는 일기를 돌려줍니다. 없으면 ErrNotFound입니다.
func (s *Store) Get(ctx context.Context, accountID uuid.UUID, date profile.LocalDate) (Entry, error) {
	row, err := diarydb.New(s.pool).GetDiary(ctx, diarydb.GetDiaryParams{AccountID: accountID, Date: profile.PgDate(date)})
	if errors.Is(err, pgx.ErrNoRows) {
		return Entry{}, ErrNotFound
	}
	if err != nil {
		return Entry{}, fmt.Errorf("일기 조회: %w", err)
	}
	return toEntry(row)
}

// Upsert는 그날 일기가 없으면 e대로 만들고(created가 true), 있으면 본문만 바꿉니다.
// 이미 있는 일기의 태그·질문·규칙 버전·생성 시각은 처음 값을 유지하므로 e의 그 필드는 쓰지 않습니다.
// 동시 호출은 DB의 partial unique 인덱스가 하나의 행으로 모읍니다.
func (s *Store) Upsert(ctx context.Context, accountID uuid.UUID, e Entry) (Entry, bool, error) {
	featured, guide, err := encodeJSON(e)
	if err != nil {
		return Entry{}, false, err
	}
	id, err := uuid.NewV7()
	if err != nil {
		return Entry{}, false, fmt.Errorf("일기 ID 생성: %w", err)
	}
	allTags := e.AllTags
	if allTags == nil {
		allTags = []string{}
	}
	row, err := diarydb.New(s.pool).UpsertDiary(ctx, diarydb.UpsertDiaryParams{
		ID:             id,
		AccountID:      accountID,
		Date:           profile.PgDate(e.Date),
		Body:           e.Body,
		AllTags:        allTags,
		FeaturedTags:   featured,
		GuideQuestion:  guide,
		RulesetVersion: e.RulesetVersion,
	})
	if err != nil {
		return Entry{}, false, fmt.Errorf("일기 저장: %w", err)
	}
	entry, err := toEntry(fromUpsertRow(row))
	return entry, row.Created, err
}

// UpdateBody는 그 날짜의 살아 있는 일기의 본문만 바꿉니다. 태그·질문·규칙 버전·생성 시각은 그대로입니다.
// 살아 있는 일기가 없으면 ErrNotFound입니다.
func (s *Store) UpdateBody(ctx context.Context, accountID uuid.UUID, date profile.LocalDate, body string) (Entry, error) {
	row, err := diarydb.New(s.pool).UpdateDiaryBody(ctx, diarydb.UpdateDiaryBodyParams{AccountID: accountID, Date: profile.PgDate(date), Body: body})
	if errors.Is(err, pgx.ErrNoRows) {
		return Entry{}, ErrNotFound
	}
	if err != nil {
		return Entry{}, fmt.Errorf("일기 본문 수정: %w", err)
	}
	return toEntry(diarydb.GetDiaryRow(row))
}

// Delete는 그 날짜의 일기를 지운 것으로 표시합니다(soft delete). 살아 있는 일기가 없으면 ErrNotFound입니다.
func (s *Store) Delete(ctx context.Context, accountID uuid.UUID, date profile.LocalDate) error {
	n, err := diarydb.New(s.pool).SoftDeleteDiary(ctx, diarydb.SoftDeleteDiaryParams{AccountID: accountID, Date: profile.PgDate(date)})
	if err != nil {
		return fmt.Errorf("일기 삭제: %w", err)
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// Restore는 그 날짜에 지운 일기 중 가장 늦게 지운 것을 되살립니다.
// 그날 살아 있는 일기가 있으면 ErrDateTaken, 지운 일기가 없으면 ErrNotFound입니다.
func (s *Store) Restore(ctx context.Context, accountID uuid.UUID, date profile.LocalDate) (Entry, error) {
	var entry Entry
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		q := diarydb.New(tx)
		pgDate := profile.PgDate(date)
		alive, err := q.LiveDiaryExists(ctx, diarydb.LiveDiaryExistsParams{AccountID: accountID, Date: pgDate})
		if err != nil {
			return fmt.Errorf("살아 있는 일기 확인: %w", err)
		}
		if alive {
			return ErrDateTaken
		}
		row, err := q.RestoreLatestDeletedDiary(ctx, diarydb.RestoreLatestDeletedDiaryParams{AccountID: accountID, Date: pgDate})
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
			// 살아 있는 일기 확인과 복원 사이에 같은 날짜 일기가 새로 생긴 경쟁을 막는 방어 경로입니다.
			// 두 문장 사이에 끼어들게 만들 수 없어 테스트하지 않습니다.
			return ErrDateTaken
		}
		if err != nil {
			return fmt.Errorf("일기 복원: %w", err)
		}
		entry, err = toEntry(diarydb.GetDiaryRow(row))
		return err
	})
	if err != nil {
		return Entry{}, err
	}
	return entry, nil
}

// List는 날짜 역순으로 살아 있는 일기를 q.Limit편까지 돌려줍니다.
func (s *Store) List(ctx context.Context, accountID uuid.UUID, q ListQuery) ([]Entry, error) {
	if q.Limit <= 0 || q.Limit > math.MaxInt32 {
		return nil, fmt.Errorf("일기 목록 Limit이 범위를 벗어났습니다: %d", q.Limit)
	}
	params := diarydb.ListDiariesParams{
		AccountID:  accountID,
		FromDate:   profile.PgDateOrNull(q.From),
		ToDate:     profile.PgDateOrNull(q.To),
		BeforeDate: profile.PgDateOrNull(q.Before),
		RowLimit:   int32(q.Limit), // 위에서 범위를 검사했습니다.
	}
	if q.Tag != nil {
		params.Tag = pgtype.Text{String: *q.Tag, Valid: true}
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

// encodeJSON은 e의 길흉 태그와 가이드 질문을 jsonb 값으로 바꿉니다. 질문이 비어 있으면 guide는 nil(NULL)입니다.
func encodeJSON(e Entry) (featured, guide []byte, err error) {
	tags := make([]featuredJSON, len(e.Featured))
	for i, t := range e.Featured {
		tags[i] = featuredJSON{Key: t.Key, Polarity: string(t.Polarity)}
	}
	if featured, err = json.Marshal(tags); err != nil {
		return nil, nil, fmt.Errorf("대표 태그 직렬화: %w", err)
	}
	if len(e.GuideQuestion) == 0 {
		return featured, nil, nil
	}
	segments := make([]segmentJSON, len(e.GuideQuestion))
	for i, seg := range e.GuideQuestion {
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

// fromUpsertRow는 Upsert가 돌려준 행을 다른 조회와 같은 모양으로 맞춥니다. 일기 열이 늘면 여기서 옮깁니다.
func fromUpsertRow(row diarydb.UpsertDiaryRow) diarydb.GetDiaryRow {
	return diarydb.GetDiaryRow{
		ID: row.ID, AccountID: row.AccountID, Date: row.Date, Body: row.Body, AllTags: row.AllTags,
		FeaturedTags: row.FeaturedTags, GuideQuestion: row.GuideQuestion, RulesetVersion: row.RulesetVersion,
		CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt,
	}
}
