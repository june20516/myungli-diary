package profile

import (
	"crypto/sha256"
	"fmt"
	"strconv"
)

// BirthHash는 엔진 결과 캐시 키와 문장 선택 기록 지문에 쓰는 출생 해시입니다.
// 호칭·현재 시간대·도시 id는 넣지 않습니다(경도로 충분).
func BirthHash(b Birth) [32]byte {
	return sha256.Sum256([]byte(canonicalBirth(b)))
}

// canonicalBirth는 해시 입력인 정규형입니다. 앞의 버전 접두어로 형식을 바꿀 여지를 남깁니다.
func canonicalBirth(b Birth) string {
	leap := "0"
	if b.IsLeapMonth {
		leap = "1"
	}
	clock := "-"
	if b.TimeStatus == TimeKnown && b.Time != nil {
		clock = fmt.Sprintf("%02d:%02d", b.Time.Hour, b.Time.Minute)
	}
	longitude := "-"
	if b.Longitude != nil {
		longitude = strconv.FormatFloat(*b.Longitude, 'f', -1, 64)
	}
	return "v1|" + string(b.Calendar) + "|" + leap + "|" +
		fmt.Sprintf("%04d-%02d-%02d", b.Date.Year, b.Date.Month, b.Date.Day) + "|" +
		clock + "|" + b.Gender + "|" + b.Timezone + "|" + longitude
}
