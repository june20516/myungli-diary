-- +goose Up
-- 날짜 기록에 그날 첫 편을 쓸 때 본 날의 성격을 함께 적습니다(D90 ①, S116). 사주 정보를 고쳐도 바꾸지 않습니다.
-- 이 열 전에 만든 날짜 기록은 채우지 않고 NULL로 둡니다(운영 데이터 없음). NULL이면 응답에서 Diary.dayKind를 생략합니다.
ALTER TABLE diary_days
    ADD COLUMN day_kind text CHECK (day_kind IN ('gwiin_day', 'yongsin_day', 'gisin_day', 'ordinary_day'));

-- +goose Down
ALTER TABLE diary_days DROP COLUMN day_kind;
