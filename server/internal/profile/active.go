package profile

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/profile/profiledb"
)

// ActiveProfile은 활동 계정 하나의 프로필입니다.
type ActiveProfile struct {
	AccountID uuid.UUID
	Profile   Profile
}

// ListActiveProfiles는 status가 active이고 last_active_at이 activeSince 이후(같은 시각 포함)인 계정의 프로필을
// 계정 id가 after보다 큰 것부터 limit개 돌려줍니다. 첫 페이지는 after에 uuid.Nil을 넘깁니다(P8-3).
func ListActiveProfiles(ctx context.Context, db profiledb.DBTX, activeSince time.Time, after uuid.UUID, limit int32) ([]ActiveProfile, error) {
	rows, err := profiledb.New(db).ListActiveProfiles(ctx, profiledb.ListActiveProfilesParams{
		ActiveSince: activeSince,
		After:       after,
		PageSize:    limit,
	})
	if err != nil {
		return nil, fmt.Errorf("활동 프로필 조회: %w", err)
	}
	profiles := make([]ActiveProfile, 0, len(rows))
	for _, row := range rows {
		profiles = append(profiles, ActiveProfile{AccountID: row.Profile.AccountID, Profile: profileFromRow(row.Profile)})
	}
	return profiles, nil
}
