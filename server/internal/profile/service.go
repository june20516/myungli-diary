package profile

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/gen/enginev1"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/profile/honorific"
	"github.com/june20516/myungli-diary/server/internal/profile/profiledb"
)

// ErrNotFound는 프로필이 없거나 익명화되었을 때 돌려줍니다.
var ErrNotFound = errors.New("profile not found")

// ChartChecker는 출생 정보를 엔진으로 검증하는 의존성입니다. fortune.Service가 만족합니다.
type ChartChecker interface {
	Chart(ctx context.Context, b Birth, asOf LocalDate) (*enginev1.ChartResponse, error)
}

// Patch는 일부 필드만 바꾸는 요청입니다. nil은 바꾸지 않음을 뜻합니다.
// Birth와 Notification은 필드 단위가 아니라 통째로 교체합니다.
type Patch struct {
	Honorific       *string
	Language        *string
	CurrentTimezone *string
	Birth           *Birth
	Notification    *Notification
}

// Saved는 저장된 프로필과 호칭 정규화 경고입니다.
type Saved struct {
	Profile  Profile
	Warnings []honorific.Code
}

// Service는 프로필 저장·수정·조회를 맡습니다.
type Service struct {
	queries *profiledb.Queries
	charts  ChartChecker
	clock   clock.Clock
}

// NewService는 Service를 만듭니다.
func NewService(pool *pgxpool.Pool, charts ChartChecker, clk clock.Clock) *Service {
	return &Service{queries: profiledb.New(pool), charts: charts, clock: clk}
}

// Get은 프로필을 돌려줍니다. 없거나 익명화되었으면 ErrNotFound입니다.
func (s *Service) Get(ctx context.Context, accountID uuid.UUID) (Profile, error) {
	p, _, err := s.load(ctx, accountID)
	return p, err
}

// Exists는 익명화되지 않은 프로필이 있는지 알려 줍니다.
func (s *Service) Exists(ctx context.Context, accountID uuid.UUID) (bool, error) {
	_, _, err := s.load(ctx, accountID)
	if errors.Is(err, ErrNotFound) {
		return false, nil
	}
	return err == nil, err
}

// Put은 프로필을 만들거나 통째로 바꿉니다. 익명화된 계정은 되살리지 않고 ErrNotFound입니다.
func (s *Service) Put(ctx context.Context, accountID uuid.UUID, p Profile) (Saved, error) {
	var storedHash []byte // 새 등록이면 nil이라 항상 엔진을 부릅니다.
	row, err := s.loadRow(ctx, accountID)
	switch {
	case errors.Is(err, ErrNotFound):
	case err != nil:
		return Saved{}, err
	case row.AnonymizedAt != nil:
		return Saved{}, ErrNotFound
	default:
		storedHash = row.BirthHash
	}
	return s.save(ctx, accountID, p, storedHash, true)
}

// Patch는 저장된 프로필 위에 요청 값을 합쳐 저장합니다. 프로필이 없으면 ErrNotFound입니다.
func (s *Service) Patch(ctx context.Context, accountID uuid.UUID, patch Patch) (Saved, error) {
	stored, storedHash, err := s.load(ctx, accountID)
	if err != nil {
		return Saved{}, err
	}
	merged := stored
	if patch.Language != nil {
		merged.Language = *patch.Language
	}
	if patch.Honorific != nil {
		merged.Honorific = *patch.Honorific
	}
	if patch.CurrentTimezone != nil {
		merged.CurrentTimezone = *patch.CurrentTimezone
	}
	if patch.Birth != nil {
		merged.Birth = *patch.Birth
	}
	if patch.Notification != nil {
		merged.Notification = *patch.Notification
	}

	// 호칭 규칙은 언어마다 다르므로, 언어만 바뀌어도 저장된 호칭을 새 언어로 다시 검사합니다.
	recheck := patch.Honorific != nil || merged.Language != stored.Language
	saved, err := s.save(ctx, accountID, merged, storedHash, recheck)
	if err != nil {
		return Saved{}, err
	}
	if patch.Honorific == nil {
		saved.Warnings = nil
	}
	return saved, nil
}

// loadRow는 행을 그대로 읽습니다. 행이 없으면 ErrNotFound입니다.
func (s *Service) loadRow(ctx context.Context, accountID uuid.UUID) (profiledb.Profile, error) {
	row, err := s.queries.GetProfile(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return profiledb.Profile{}, ErrNotFound
	}
	if err != nil {
		return profiledb.Profile{}, fmt.Errorf("프로필 조회: %w", err)
	}
	return row, nil
}

// load는 익명화되지 않은 프로필과 저장된 출생 해시를 읽습니다. 익명화된 행은 없는 것으로 봅니다.
func (s *Service) load(ctx context.Context, accountID uuid.UUID) (Profile, []byte, error) {
	row, err := s.loadRow(ctx, accountID)
	if err != nil {
		return Profile{}, nil, err
	}
	if row.AnonymizedAt != nil {
		return Profile{}, nil, ErrNotFound
	}
	return profileFromRow(row), row.BirthHash, nil
}

// save는 검증하고, 출생 정보가 바뀐 경우에만 엔진을 부른 뒤 저장합니다.
// 읽기·엔진 호출·upsert를 한 트랜잭션에 묶지 않습니다. 엔진 호출이 최대 수 초 걸리므로
// 그 동안 DB 연결과 락을 쥐지 않기 위해서입니다. 동시 요청이 엔진을 두 번 불러도 정확성에는 문제가 없고,
// upsert는 ON CONFLICT라 둘 다 성공합니다.
func (s *Service) save(ctx context.Context, accountID uuid.UUID, p Profile, storedHash []byte, normalizeHonorific bool) (Saved, error) {
	var warnings []honorific.Code
	if normalizeHonorific {
		result := honorific.Normalize(p.Language, p.Honorific)
		if result.Rejected != honorific.None {
			return Saved{}, &ValidationError{
				Violation: HonorificRejected,
				Honorific: result.Rejected,
				Fields:    []FieldViolation{{Field: "/honorific"}},
			}
		}
		p.Honorific = result.Value
		warnings = result.Warnings
	}
	if err := ValidateTimezone(p.CurrentTimezone, "/currentTimezone"); err != nil {
		return Saved{}, err
	}
	birth, err := ValidateBirth(p.Birth, "/birth")
	if err != nil {
		return Saved{}, err
	}
	p.Birth = birth
	if err := ValidateNotification(p.Notification, "/notification"); err != nil {
		return Saved{}, err
	}

	hash := BirthHash(birth)
	if !bytesEqual(storedHash, hash[:]) {
		if err := s.checkBirthWithEngine(ctx, birth, p.CurrentTimezone); err != nil {
			return Saved{}, err
		}
	}

	row, err := s.queries.UpsertProfile(ctx, upsertParams(accountID, p, hash))
	if err != nil {
		return Saved{}, fmt.Errorf("프로필 저장: %w", err)
	}
	return Saved{Profile: profileFromRow(row), Warnings: warnings}, nil
}

// checkBirthWithEngine은 엔진이 출생 정보를 계산할 수 있는지 확인합니다.
func (s *Service) checkBirthWithEngine(ctx context.Context, b Birth, timezone string) error {
	loc, err := time.LoadLocation(timezone) // ValidateTimezone을 이미 통과한 이름입니다.
	if err != nil {
		return fmt.Errorf("시간대 로드: %w", err)
	}
	now := s.clock.Now().In(loc)
	asOf := LocalDate{Year: now.Year(), Month: int(now.Month()), Day: now.Day()}

	_, err = s.charts.Chart(ctx, b, asOf)
	switch {
	case errors.Is(err, engine.ErrInvalidArgument):
		return newViolation(BirthInvalid, "/birth", NoStatusRule)
	case errors.Is(err, engine.ErrOutOfRange):
		return newViolation(BirthOutOfRange, "/birth/date", NoStatusRule)
	default:
		return err
	}
}

func bytesEqual(a, b []byte) bool {
	return len(a) == len(b) && string(a) == string(b)
}

// timeOfDay는 시:분을 DB time 값으로 바꿉니다. nil이면 NULL입니다.
func timeOfDay(t *LocalTime) pgtype.Time {
	if t == nil {
		return pgtype.Time{}
	}
	micros := int64(t.Hour*60+t.Minute) * int64(time.Minute/time.Microsecond)
	return pgtype.Time{Microseconds: micros, Valid: true}
}

// localTime은 DB time 값을 시:분으로 바꿉니다. NULL이면 nil입니다.
func localTime(t pgtype.Time) *LocalTime {
	if !t.Valid {
		return nil
	}
	minutes := int(t.Microseconds / int64(time.Minute/time.Microsecond))
	return &LocalTime{Hour: minutes / 60, Minute: minutes % 60}
}

// smallint는 출생 날짜의 한 구성요소를 smallint 열 값으로 바꿉니다.
// 날짜는 엔진 검증을 통과했거나 저장된 값이라 범위 안이고, 범위 밖이면 DB CHECK가 막습니다.
func smallint(v int) int16 {
	return int16(v) //nolint:gosec // 위 이유로 오버플로가 일어나지 않습니다.
}

func upsertParams(accountID uuid.UUID, p Profile, hash [32]byte) profiledb.UpsertProfileParams {
	b := p.Birth
	params := profiledb.UpsertProfileParams{
		AccountID:        accountID,
		Honorific:        pgtype.Text{String: p.Honorific, Valid: true},
		Language:         p.Language,
		CurrentTimezone:  p.CurrentTimezone,
		Calendar:         pgtype.Text{String: string(b.Calendar), Valid: true},
		IsLeapMonth:      pgtype.Bool{Bool: b.IsLeapMonth, Valid: true},
		BirthYear:        pgtype.Int2{Int16: smallint(b.Date.Year), Valid: true},
		BirthMonth:       pgtype.Int2{Int16: smallint(b.Date.Month), Valid: true},
		BirthDay:         pgtype.Int2{Int16: smallint(b.Date.Day), Valid: true},
		BirthTimeStatus:  pgtype.Text{String: string(b.TimeStatus), Valid: true},
		BirthTime:        timeOfDay(b.Time),
		Gender:           pgtype.Text{String: b.Gender, Valid: true},
		BirthTimezone:    pgtype.Text{String: b.Timezone, Valid: true},
		BirthPlaceStatus: pgtype.Text{String: string(b.PlaceStatus), Valid: true},
		NotifyStatus:     string(p.Notification.Status),
		NotifyTime:       timeOfDay(p.Notification.Time),
		BirthHash:        hash[:],
	}
	if b.PlaceStatus == PlaceCity {
		params.BirthCityID = pgtype.Text{String: b.CityID, Valid: true}
		if b.Longitude != nil {
			params.Longitude = pgtype.Float8{Float64: *b.Longitude, Valid: true}
		}
	}
	return params
}

func profileFromRow(r profiledb.Profile) Profile {
	b := Birth{
		Calendar:    Calendar(r.Calendar.String),
		IsLeapMonth: r.IsLeapMonth.Bool,
		Date: LocalDate{
			Year:  int(r.BirthYear.Int16),
			Month: int(r.BirthMonth.Int16),
			Day:   int(r.BirthDay.Int16),
		},
		TimeStatus:  TimeStatus(r.BirthTimeStatus.String),
		Time:        localTime(r.BirthTime),
		Gender:      r.Gender.String,
		Timezone:    r.BirthTimezone.String,
		PlaceStatus: PlaceStatus(r.BirthPlaceStatus.String),
	}
	if r.BirthCityID.Valid {
		b.CityID = r.BirthCityID.String
	}
	if r.Longitude.Valid {
		longitude := r.Longitude.Float64
		b.Longitude = &longitude
	}
	return Profile{
		Honorific:       r.Honorific.String,
		Language:        r.Language,
		CurrentTimezone: r.CurrentTimezone,
		Birth:           b,
		Notification: Notification{
			Status: NotifyStatus(r.NotifyStatus),
			Time:   localTime(r.NotifyTime),
		},
	}
}
