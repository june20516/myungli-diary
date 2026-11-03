package profile

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/profile/profiledb"
)

// ListNotifyProfiles는 알림을 켰고(notify_status = enabled) 활성 기기가 있는 활동 계정의 프로필을
// 계정 id가 after보다 큰 것부터 limit개 돌려줍니다. 첫 페이지는 after에 uuid.Nil을 넘깁니다(P8-4).
func ListNotifyProfiles(ctx context.Context, db profiledb.DBTX, after uuid.UUID, limit int32) ([]ActiveProfile, error) {
	rows, err := profiledb.New(db).ListNotifyProfiles(ctx, profiledb.ListNotifyProfilesParams{After: after, PageSize: limit})
	if err != nil {
		return nil, fmt.Errorf("알림 프로필 조회: %w", err)
	}
	profiles := make([]ActiveProfile, 0, len(rows))
	for _, row := range rows {
		profiles = append(profiles, ActiveProfile{AccountID: row.Profile.AccountID, Profile: profileFromRow(row.Profile)})
	}
	return profiles, nil
}
