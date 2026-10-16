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

// ErrSelectionConflict는 같은 선택 기록을 다른 요청이 다른 메시지 키로 먼저 기록했을 때 돌려줍니다.
// 계정 lock이 있으면 생기지 않는 방어용 오류입니다.
var ErrSelectionConflict = errors.New("다른 요청이 같은 선택 기록을 다른 메시지 키로 먼저 기록했습니다")

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
// 순환 차례 읽기→기록→넘기기와 돌봄 개수 세기가 같은 계정의 다른 요청(다른 날짜·다른 지문 포함)과 섞이면
// 두 요청이 같은 차례를 읽어 같은 유형을 고르거나 상한을 함께 넘을 수 있어서 계정 단위로 묶습니다.
// 트랜잭션이 끝나면 자동으로 풀립니다.
//
// 키 도출: 두 int4 키 형식 (selectionLockClass, hashtext(계정 id 문자열))을 씁니다.
//   - PostgreSQL은 bigint 키 하나 형식과 int4 키 둘 형식을 서로 다른 lock으로 다룹니다(pg_locks.objsubid가 1과 2로 다름).
//     이 저장소의 다른 advisory lock인 시드 적재(seedLockID)와 goose migration session lock은 bigint 형식이라 겹치지 않습니다.
//   - 첫 키 selectionLockClass는 이 용도를 뜻하는 고정값이라, 두 int4 형식을 쓰는 다른 lock이 생겨도 다른 첫 키를 쓰면 겹치지 않습니다.
//   - 둘째 키는 32비트 해시라 서로 다른 계정이 같은 값을 가질 수 있습니다. 그때는 두 계정이 잠시 차례로 기다릴 뿐 결과는 같습니다.
const selectionLockSQL = "SELECT pg_advisory_xact_lock($1::int4, hashtext($2::text))"

// selectionLockClass는 selectionLockSQL의 첫 키입니다("sel"의 ASCII).
const selectionLockClass int32 = 0x73656c

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
//   - 순환 차례부터 순서대로 후보를 보며 막히지 않은 첫 후보를 고릅니다. 막는 규칙은 두 가지이고 상한이 우선입니다.
//     ① 돌봄 상한(W14): care인데, 지금 고르는 (date, 슬롯)을 뺀 care 기록이 date 하루 2개 이상이거나
//     date까지 최근 7일 7개 이상. 같은 호출에서 앞 슬롯이 고른 care도 셉니다.
//     ② 같은 날 다른 지문 회피: 같은 (계정, date, 슬롯)에 지문이 다른 기록이 쓴 variant.
//     같은 날 다시 고른 문장이 앞 문장과 같은 유형이 되지 않게 합니다.
//     ①·② 모두로 막히지 않은 후보가 없으면 ②만 풀고 다시 차례부터 보아 ①에 걸리지 않은 첫 후보를 고릅니다
//     (advice·state·변주에는 상한이 없으므로 늘 있습니다). rotation_state는 실제로 고른 것의 다음으로 넘깁니다.
//   - 상한의 기준일은 date 인자입니다. 지난 날짜를 다시 고르면 그 날까지의 7일과 그 날 하루로 셉니다.
//   - 메시지 키가 바뀌어 기록을 바꾸면 그 기록의 활성 반응을 soft delete합니다. 반응은 옛 문장에 남긴 것이기 때문입니다.
//
// date는 날짜 부분(date 자신의 시간대 기준 연·월·일)만 씁니다. 모든 슬롯을 한 트랜잭션에서 처리하므로
// 하나라도 실패하면 아무것도 기록하지 않습니다. 활성 시드가 없으면 ErrNoActiveSeed입니다.
func (s *Store) Select(ctx context.Context, accountID uuid.UUID, date time.Time, birthHash [32]byte,
	reqs []SlotRequest, slots map[string]seed.Slot,
) ([]Selection, error) {
	if err := validateRequests(reqs, slots); err != nil {
		return nil, err
	}
	sel := selector{accountID: accountID, today: toDate(date), birthHash: birthHash[:], slots: slots, now: s.clock.Now()}

	var out []Selection
	err := postgres.InTx(ctx, s.pool, func(tx pgx.Tx) error {
		// InTx가 fn을 다시 실행할 수 있으므로 결과를 처음부터 다시 채웁니다.
		out = make([]Selection, 0, len(reqs))
		if _, err := tx.Exec(ctx, selectionLockSQL, selectionLockClass, accountID.String()); err != nil {
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
	// now는 반응 soft delete에 남기는 시각입니다.
	now time.Time
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
		// (이긴 쪽이 이미 넘겼습니다). 계정 lock(selectionLockSQL)이 있으면 닿지 않는 방어입니다.
		// lock이 바뀌거나 lock 없이 기록하는 경로가 생겨도 unique 제약과 이 재읽기로 결과가 하나로 맞습니다.
		winner, err := q.GetSelection(ctx, key)
		if err != nil {
			return Selection{}, fmt.Errorf("먼저 기록된 선택 다시 읽기: %w", err)
		}
		if winner.MessageKey != r.MessageKey {
			return Selection{}, ErrSelectionConflict
		}
		return selectionFromRow(r.Slot, winner), nil
	}
	if err != nil {
		return Selection{}, fmt.Errorf("기록: %w", err)
	}
	if found {
		// 같은 행이 이제 새 문장을 가리키므로, 옛 문장에 남긴 반응이 새 문장에 붙지 않게 지웁니다.
		if err := q.SoftDeleteReactions(ctx, contentdb.SoftDeleteReactionsParams{DeletedAt: &sel.now, SelectionID: id}); err != nil {
			return Selection{}, fmt.Errorf("옛 반응 정리: %w", err)
		}
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
	var cycle []string
	switch rotation := sel.slots[r.Slot].Rotation; rotation {
	case seed.RotationNone:
		return seed.VariantSingle, "", nil
	case seed.RotationVariant:
		cycle = variantCycle
	case seed.RotationType:
		cycle = typeCycle
	default:
		return "", "", fmt.Errorf("모르는 순환 방식입니다: %q", rotation)
	}

	turn, err := sel.turn(ctx, q, r.MessageKey, cycle)
	if err != nil {
		return "", "", err
	}
	sameDay, err := q.ListOtherHashVariants(ctx, contentdb.ListOtherHashVariantsParams{
		AccountID: sel.accountID, Date: sel.today, Slot: r.Slot, BirthHash: sel.birthHash,
	})
	if err != nil {
		return "", "", fmt.Errorf("같은 날 다른 지문 기록 조회: %w", err)
	}

	// 먼저 상한과 같은 날 회피를 모두 지키는 후보를 찾고, 없으면 회피만 풀어 상한만 지킵니다(상한이 우선).
	for _, avoid := range [][]string{sameDay, nil} {
		chosen, ok, err := sel.firstAllowed(ctx, q, r.Slot, cycle, turn, avoid)
		if err != nil {
			return "", "", err
		}
		if ok {
			return chosen, after(cycle, chosen), nil
		}
	}
	// 상한이 있는 것은 care 하나뿐이라, 순환에 두 개 이상 후보가 있으면 여기에 오지 않습니다.
	return "", "", fmt.Errorf("고를 수 있는 variant가 없습니다: %s", r.Slot)
}

// firstAllowed는 turn부터 cycle을 한 바퀴 돌며, avoid에 없고 돌봄 상한에 걸리지 않는 첫 후보를 돌려줍니다.
func (sel selector) firstAllowed(ctx context.Context, q *contentdb.Queries, slot string, cycle []string, turn string, avoid []string) (string, bool, error) {
	start := slices.Index(cycle, turn)
	for i := range cycle {
		candidate := cycle[(start+i)%len(cycle)]
		if slices.Contains(avoid, candidate) {
			continue
		}
		if candidate == VariantCare {
			capped, err := sel.careCapped(ctx, q, slot)
			if err != nil {
				return "", false, err
			}
			if capped {
				continue
			}
		}
		return candidate, true, nil
	}
	return "", false, nil
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
// 상한은 "이번에 care를 고른 뒤의 (날짜, 슬롯) 개수"가 넘는지로 봅니다. 그래서 지금 고르는 (오늘, 슬롯)은 세지 않습니다.
// (날짜, 슬롯)마다 하나로 세므로(S23) 이번에 care를 골라도 그 자리의 개수는 많아야 하나이고, 이미 있는 그 자리의 기록을
// 세면 자기 자신 때문에 막힙니다. 예를 들어 메시지 키가 바뀌어 지금 care인 기록을 다시 고르면, 바뀔 그 기록은 세지 않습니다.
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
