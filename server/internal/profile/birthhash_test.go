package profile

import (
	"encoding/hex"
	"testing"

	"github.com/stretchr/testify/assert"
)

func hashBirth() Birth {
	return Birth{
		Calendar:    CalendarSolar,
		Date:        LocalDate{Year: 1990, Month: 5, Day: 7},
		TimeStatus:  TimeKnown,
		Time:        &LocalTime{Hour: 9, Minute: 5},
		Gender:      "female",
		Timezone:    "Asia/Seoul",
		PlaceStatus: PlaceCity,
		CityID:      seoulID,
		Longitude:   ptr(126.978),
	}
}

func hashHex(b Birth) string {
	h := BirthHash(b)
	return hex.EncodeToString(h[:])
}

func TestCanonicalBirth(t *testing.T) {
	assert.Equal(t, "v1|solar|0|1990-05-07|09:05|female|Asia/Seoul|126.978", canonicalBirth(hashBirth()))

	b := hashBirth()
	b.Calendar = CalendarLunar
	b.IsLeapMonth = true
	b.TimeStatus = TimeUnknown
	b.Time = nil
	b.Gender = "male"
	b.PlaceStatus = PlaceSkipped
	b.CityID = ""
	b.Longitude = nil
	assert.Equal(t, "v1|lunar|1|1990-05-07|-|male|Asia/Seoul|-", canonicalBirth(b))
}

func TestBirthHash_StableAndSensitive(t *testing.T) {
	base := hashHex(hashBirth())
	assert.Equal(t, base, hashHex(hashBirth()))
	// 정규형 "v1|solar|0|1990-05-07|09:05|female|Asia/Seoul|126.978"의 SHA-256(shasum으로 따로 확인)입니다.
	assert.Equal(t, "f661277e7028232cc80f9703cb308b49b93928d50673d30ca20dbdefafa30d06", base)

	tests := []struct {
		name   string
		mutate func(b *Birth)
	}{
		{"성별", func(b *Birth) { b.Gender = "male" }},
		{"윤달", func(b *Birth) { b.Calendar = CalendarLunar; b.IsLeapMonth = true }},
		{"경도", func(b *Birth) { b.Longitude = ptr(139.69) }},
		{"경도 없음", func(b *Birth) { b.Longitude = nil }},
		{"시각", func(b *Birth) { b.Time = &LocalTime{Hour: 9, Minute: 6} }},
		{"시간대", func(b *Birth) { b.Timezone = "Asia/Tokyo" }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			b := hashBirth()
			tt.mutate(&b)
			assert.NotEqual(t, base, hashHex(b))
		})
	}

	sameLongitude := hashBirth()
	sameLongitude.CityID = "9999999"
	assert.Equal(t, base, hashHex(sameLongitude), "도시 id는 해시에 들어가지 않습니다")
}

func TestBirthHash_UnknownTimeIgnoresStaleTime(t *testing.T) {
	stale := hashBirth()
	stale.TimeStatus = TimeUnknown // Time이 남아 있어도 정규형은 "-"
	clean := stale
	clean.Time = nil

	assert.Equal(t, "v1|solar|0|1990-05-07|-|female|Asia/Seoul|126.978", canonicalBirth(stale))
	assert.Equal(t, hashHex(clean), hashHex(stale))
}
