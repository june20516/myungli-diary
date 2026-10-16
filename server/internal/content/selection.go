package content

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/june20516/myungli-diary/server/internal/content/contentdb"
	"github.com/june20516/myungli-diary/server/internal/platform/postgres"
	"github.com/june20516/myungli-diary/server/seed"
)

// ErrSelectionNotFound는 (계정, 날짜, 슬롯, 사주 지문)의 선택 기록이 없을 때 돌려줍니다.
var ErrSelectionNotFound = errors.New("문장 선택 기록이 없습니다")

// 문장 유형 슬롯(seed.RotationType)의 variant 값입니다.
const (
	VariantAdvice = "advice"
	VariantState  = "state"
	VariantCare   = "care"
)

// 순환 차례입니다. 끝 다음은 처음으로 돌아갑니다.
var (
	// typeCycle은 총운 슬롯의 문장 유형 순서입니다(D57①). 새 사용자는 advice부터입니다.
	typeCycle = []string{VariantAdvice, VariantState, VariantCare}
	// variantCycle은 변주 슬롯(가이드 질문)의 순서입니다.
	variantCycle = []string{"1", "2"}
)

// 돌봄 상한(W14)입니다. 같은 사용자에게 care 문장이 이 개수를 넘지 않습니다. 개수는 (날짜, 슬롯)마다 하나로 셉니다.
const (
	dailyCareCap  = 2
	weeklyCareCap = 7
	// careWindowDays는 주간 상한을 세는 기간(오늘 포함)입니다.
	careWindowDays = 7
)

// selectionLockSQL은 한 계정의 선택을 트랜잭션 하나씩 차례로 하게 하는 advisory lock입니다.
// 순환 차례 읽기→기록→넘기기와 돌봄 개수 세기가 같은 계정의 다른 요청과 섞이면
// 두 요청이 같은 차례를 쓰거나 상한을 함께 넘을 수 있어서 계정 단위로 묶습니다.
// 트랜잭션이 끝나면 자동으로 풀립니다. 해시가 다른 lock과 겹쳐도 잠시 더 기다릴 뿐 결과는 같습니다.
const selectionLockSQL = "SELECT pg_advisory_xact_lock(hashtextextended('daily_selections:' || $1::text, 0))"

// SlotRequest는 한 슬롯에 대해 엔진 결과가 정한 메시지 키입니다.
type SlotRequest struct {
	Slot       string
	MessageKey string
}

// Selection은 한 슬롯에 고른 문장 틀입니다. (Slot, MessageKey, Variant)와 SeedVersion으로 문장 틀을 찾습니다.
// ID는 daily_selections 행 번호이고 문장 반응이 가리킵니다.
type Selection struct {
	ID          int64
	Slot        string
	MessageKey  string
	Variant     string
	SeedVersion string
}

// Select는 (계정, 날짜, 사주 지문)의 슬롯마다 문장 틀을 고르고 기록합니다. 결과는 reqs 순서입니다.
//
//   - 같은 (계정, 날짜, 슬롯, 지문)의 기록이 있고 메시지 키가 같으면 그 기록을 그대로 돌려줍니다(시드 버전도 그대로).
//   - 기록이 없으면 새로 골라 넣고, 메시지 키가 달라졌으면 새로 골라 그 기록을 바꿉니다.
//     새로 고를 때만 rotation_state를 한 칸 넘깁니다. 지문이 다른 옛 기록은 건드리지 않습니다.
//   - 순환: seed.RotationType은 advice → state → care, seed.RotationVariant는 1 → 2,
//     seed.RotationNone은 seed.VariantSingle이고 rotation_state를 쓰지 않습니다.
//   - 돌봄 상한: 차례가 care인데, 지금 고르는 (오늘, 슬롯)을 뺀 care 기록이 오늘 2개 이상이거나
//     최근 7일(오늘 포함) 7개 이상이면 care를 건너뛰고 다음 차례(advice)를 고릅니다.
//     rotation_state는 실제로 고른 것의 다음(state)으로 넘깁니다. 같은 호출에서 앞 슬롯이 고른 care도 셉니다.
//
// date는 날짜 부분(date 자신의 시간대 기준 연·월·일)만 씁니다. 모든 슬롯을 한 트랜잭션에서 처리하므로
// 하나라도 실패하면 아무것도 기록하지 않습니다. 활성 시드가 없으면 ErrNoActiveSeed입니다.
func (s *Store) Select(ctx context.Context, accountID uuid.UUID, date time.Time, birthHash [32]byte,
	reqs []SlotRequest, slots map[string]seed.Slot,
) ([]Selection, error) {
	if err := validateRequests(reqs, slots); err != nil {
		return nil, err
	}
	sel := selector{accountID: accountID, today: toDate(date), birthHash: birthHash[:], slots: slots}

	var out []Selection
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		// InTx가 fn을 다시 실행할 수 있으므로 결과를 처음부터 다시 채웁니다.
		out = make([]Selection, 0, len(reqs))
		if _, err := tx.Exec(ctx, selectionLockSQL, accountID.String()); err != nil {
			return fmt.Errorf("선택 잠금: %w", err)
		}
		q := contentdb.New(tx)
		version, err := q.GetActiveSeed(ctx)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNoActiveSeed
		}
		if err != nil {
			return fmt.Errorf("활성 시드 조회: %w", err)
		}
		for _, r := range reqs {
			got, err := sel.selectSlot(ctx, q, version, r)
			if err != nil {
				return fmt.Errorf("슬롯 %s 선택: %w", r.Slot, err)
			}
			out = append(out, got)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// SelectionFor는 (계정, 날짜, 슬롯, 사주 지문)의 선택 기록을 돌려줍니다. 없으면 ErrSelectionNotFound입니다.
func (s *Store) SelectionFor(ctx context.Context, accountID uuid.UUID, date time.Time, slot string, birthHash [32]byte) (Selection, error) {
	row, err := s.queries.GetSelection(ctx, contentdb.GetSelectionParams{
		AccountID: accountID, Date: toDate(date), Slot: slot, BirthHash: birthHash[:],
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return Selection{}, ErrSelectionNotFound
	}
	if err != nil {
		return Selection{}, fmt.Errorf("선택 기록 조회: %w", err)
	}
	return selectionFromRow(slot, row), nil
}

// validateRequests는 트랜잭션을 열기 전에 요청을 검사합니다. 슬롯은 정의에 있어야 하고 한 번씩만 나와야 합니다.
func validateRequests(reqs []SlotRequest, slots map[string]seed.Slot) error {
	seen := make(map[string]bool, len(reqs))
	for _, r := range reqs {
		if _, ok := slots[r.Slot]; !ok {
			return fmt.Errorf("정의에 없는 슬롯입니다: %s", r.Slot)
		}
		if seen[r.Slot] {
			return fmt.Errorf("같은 슬롯을 두 번 요청했습니다: %s", r.Slot)
		}
		seen[r.Slot] = true
	}
	return nil
}

// selector는 Select 한 번의 공통 값을 묶습니다.
type selector struct {
	accountID uuid.UUID
	today     pgtype.Date
	birthHash []byte
	slots     map[string]seed.Slot
}

// selectSlot은 슬롯 하나의 기록을 다시 쓰거나 새로 고릅니다.
func (sel selector) selectSlot(ctx context.Context, q *contentdb.Queries, version string, r SlotRequest) (Selection, error) {
	key := contentdb.GetSelectionParams{AccountID: sel.accountID, Date: sel.today, Slot: r.Slot, BirthHash: sel.birthHash}
	existing, err := q.GetSelection(ctx, key)
	found := err == nil
	switch {
	case found && existing.MessageKey == r.MessageKey:
		return selectionFromRow(r.Slot, existing), nil
	case !found && !errors.Is(err, pgx.ErrNoRows):
		return Selection{}, fmt.Errorf("기록 조회: %w", err)
	}

	variant, next, err := sel.choose(ctx, q, r)
	if err != nil {
		return Selection{}, err
	}

	var id int64
	if found {
		id, err = q.UpdateSelection(ctx, contentdb.UpdateSelectionParams{
			ID: existing.ID, OldMessageKey: existing.MessageKey,
			MessageKey: r.MessageKey, Variant: variant, SeedVersion: version,
		})
	} else {
		id, err = q.InsertSelection(ctx, contentdb.InsertSelectionParams{
			AccountID: sel.accountID, Date: sel.today, Slot: r.Slot, BirthHash: sel.birthHash,
			MessageKey: r.MessageKey, Variant: variant, SeedVersion: version,
		})
	}
	if errors.Is(err, pgx.ErrNoRows) {
		// 다른 요청이 먼저 같은 기록을 넣거나 바꿨습니다. 그 결과를 다시 읽어 쓰고, 순환은 넘기지 않습니다
		// (이긴 쪽이 이미 넘겼습니다). 계정 잠금 아래에서는 생기지 않지만, 잠금 없이 쓰는 경로가 생겨도 결과가 맞게 둡니다.
		winner, err := q.GetSelection(ctx, key)
		if err != nil {
			return Selection{}, fmt.Errorf("먼저 기록된 선택 다시 읽기: %w", err)
		}
		return selectionFromRow(r.Slot, winner), nil
	}
	if err != nil {
		return Selection{}, fmt.Errorf("기록: %w", err)
	}

	if next != "" {
		if err := q.SetRotation(ctx, contentdb.SetRotationParams{
			AccountID: sel.accountID, MessageKey: r.MessageKey, NextVariant: next,
		}); err != nil {
			return Selection{}, fmt.Errorf("순환 상태 기록: %w", err)
		}
	}
	return Selection{ID: id, Slot: r.Slot, MessageKey: r.MessageKey, Variant: variant, SeedVersion: version}, nil
}

// choose는 새로 고를 variant와, rotation_state에 남길 다음 차례를 돌려줍니다.
// 순환이 없는 슬롯은 next가 ""이고 rotation_state를 쓰지 않습니다.
func (sel selector) choose(ctx context.Context, q *contentdb.Queries, r SlotRequest) (variant, next string, err error) {
	switch rotation := sel.slots[r.Slot].Rotation; rotation {
	case seed.RotationNone:
		return seed.VariantSingle, "", nil
	case seed.RotationVariant:
		turn, err := sel.turn(ctx, q, r.MessageKey, variantCycle)
		if err != nil {
			return "", "", err
		}
		return turn, after(variantCycle, turn), nil
	case seed.RotationType:
		turn, err := sel.turn(ctx, q, r.MessageKey, typeCycle)
		if err != nil {
			return "", "", err
		}
		if turn == VariantCare {
			capped, err := sel.careCapped(ctx, q, r.Slot)
			if err != nil {
				return "", "", err
			}
			if capped {
				turn = after(typeCycle, turn)
			}
		}
		return turn, after(typeCycle, turn), nil
	default:
		return "", "", fmt.Errorf("모르는 순환 방식입니다: %q", rotation)
	}
}

// turn은 메시지 키의 지금 차례를 돌려줍니다. 기록이 없거나 이 순환에 없는 값이면 처음 차례입니다.
func (sel selector) turn(ctx context.Context, q *contentdb.Queries, messageKey string, cycle []string) (string, error) {
	next, err := q.GetRotation(ctx, contentdb.GetRotationParams{AccountID: sel.accountID, MessageKey: messageKey})
	if errors.Is(err, pgx.ErrNoRows) {
		return cycle[0], nil
	}
	if err != nil {
		return "", fmt.Errorf("순환 상태 조회: %w", err)
	}
	if !slices.Contains(cycle, next) {
		return cycle[0], nil
	}
	return next, nil
}

// careCapped는 이 슬롯에 care를 고르면 돌봄 상한을 넘는지 알려 줍니다.
// 지금 고르는 (오늘, 슬롯)은 세지 않습니다. 그 자리에 다른 지문의 care가 이미 있어도 (날짜, 슬롯)마다 하나로 세므로
// 이번에 care를 골라도 개수가 늘지 않기 때문입니다.
func (sel selector) careCapped(ctx context.Context, q *contentdb.Queries, slot string) (bool, error) {
	counts, err := q.CountCare(ctx, contentdb.CountCareParams{
		AccountID: sel.accountID,
		Today:     sel.today,
		WeekStart: pgtype.Date{Time: sel.today.Time.AddDate(0, 0, -(careWindowDays - 1)), Valid: true},
		Slot:      slot,
	})
	if err != nil {
		return false, fmt.Errorf("돌봄 개수 조회: %w", err)
	}
	return counts.TodayCount >= dailyCareCap || counts.WeekCount >= weeklyCareCap, nil
}

// after는 cycle에서 v 다음 차례를 돌려줍니다. 끝이면 처음으로 돌아갑니다.
func after(cycle []string, v string) string {
	i := slices.Index(cycle, v)
	return cycle[(i+1)%len(cycle)]
}

// toDate는 t의 날짜 부분(t 자신의 시간대 기준)을 DB date 값으로 바꿉니다.
func toDate(t time.Time) pgtype.Date {
	y, m, d := t.Date()
	return pgtype.Date{Time: time.Date(y, m, d, 0, 0, 0, 0, time.UTC), Valid: true}
}

func selectionFromRow(slot string, row contentdb.GetSelectionRow) Selection {
	return Selection{ID: row.ID, Slot: slot, MessageKey: row.MessageKey, Variant: row.Variant, SeedVersion: row.SeedVersion}
}
