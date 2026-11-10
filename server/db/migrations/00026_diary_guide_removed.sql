-- +goose Up
-- 일기 한 편에서 가이드 질문을 뗐는지입니다(D116, #927, S149). true면 그 편에는 질문이 붙지 않고,
-- 날짜 기록의 기본 질문(diary_days.guide_question)으로도 채우지 않습니다. 이 열 전에 쓴 편은 false입니다.
ALTER TABLE diaries ADD COLUMN guide_question_removed boolean NOT NULL DEFAULT false;
ALTER TABLE diaries ADD CONSTRAINT diaries_guide_removed_without_choice
    CHECK (NOT guide_question_removed OR guide_question IS NULL);

-- +goose Down
ALTER TABLE diaries DROP COLUMN guide_question_removed;
