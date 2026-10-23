-- +goose Up
-- 계정 합치기(S111)는 B의 일기·일정을 account_id만 바꿔 A로 옮깁니다. 옮기는 것은 사용자가 고친 것이 아니므로
-- 수정 시각(updated_at)을 그대로 두도록, account_id가 바뀌는 UPDATE에는 set_updated_at trigger를 부르지 않습니다.
-- account_id를 바꾸는 UPDATE는 합치기뿐입니다. 다른 표의 set_updated_at trigger는 그대로입니다.
DROP TRIGGER diaries_set_updated_at ON diaries;
CREATE TRIGGER diaries_set_updated_at BEFORE UPDATE ON diaries
    FOR EACH ROW WHEN (OLD.account_id IS NOT DISTINCT FROM NEW.account_id) EXECUTE FUNCTION set_updated_at();

DROP TRIGGER schedules_set_updated_at ON schedules;
CREATE TRIGGER schedules_set_updated_at BEFORE UPDATE ON schedules
    FOR EACH ROW WHEN (OLD.account_id IS NOT DISTINCT FROM NEW.account_id) EXECUTE FUNCTION set_updated_at();

-- +goose Down
DROP TRIGGER schedules_set_updated_at ON schedules;
CREATE TRIGGER schedules_set_updated_at BEFORE UPDATE ON schedules
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER diaries_set_updated_at ON diaries;
CREATE TRIGGER diaries_set_updated_at BEFORE UPDATE ON diaries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
