-- +goose Up
-- 일기 한 편마다 쓸 때 고른 오늘의 질문입니다(#806 ⑤, S140). 모양은 diary_days.guide_question과 같은 [{"text","term"}]입니다.
-- 고르지 않고 쓴 편과 이 열 전에 쓴 편은 NULL이고, 그때는 그날 첫 편 때 보인 날짜 기록의 질문(diary_days.guide_question)을 씁니다.
ALTER TABLE diaries ADD COLUMN guide_question jsonb;

-- +goose Down
ALTER TABLE diaries DROP COLUMN guide_question;
