-- +goose Up
-- IP별 요청 한도 표입니다. 고정 1분 창마다 키별 요청 수를 셉니다.
-- key는 "<operation>:<IP의 SHA-256 hex>"라 IP 원문을 남기지 않습니다. window_start는 창의 시작 시각(분 단위 내림)입니다.
-- 시스템 데이터라 지난 창은 물리적으로 지웁니다(정리는 retention 작업 몫입니다).
CREATE TABLE rate_limits (
    key          text        NOT NULL,
    window_start timestamptz NOT NULL,
    count        integer     NOT NULL,
    PRIMARY KEY (key, window_start),
    CONSTRAINT rate_limits_count_positive CHECK (count > 0)
);

-- 지난 창 정리(DELETE ... WHERE window_start < $1)가 표 전체를 훑지 않게 합니다.
CREATE INDEX rate_limits_window_start_idx ON rate_limits (window_start);

-- +goose Down
DROP TABLE rate_limits;
