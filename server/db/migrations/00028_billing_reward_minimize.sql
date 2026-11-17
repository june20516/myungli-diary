-- +goose Up
-- 결제 webhook 본문과 보상 콜백 쿼리 원문을 통째로 두지 않고 회계와 분쟁 대응, 부정 수령 방지에 필요한 칸만 남깁니다(D137 ③, #1249, S164).

-- billing_events.payload는 {"event": {...}}에 허용한 event 칸만 둡니다. 칸 목록은 billing.billingRecordFields와 같습니다.
-- 고객 속성(subscriber_attributes), 별칭(aliases), 국가, 수수료와 세율, 제안 정보 같은 나머지 칸은 지웁니다.
UPDATE billing_events
SET payload = jsonb_build_object('event', (
    SELECT coalesce(jsonb_object_agg(field.key, field.value), '{}'::jsonb)
    FROM jsonb_each(CASE WHEN jsonb_typeof(payload -> 'event') = 'object' THEN payload -> 'event' ELSE '{}'::jsonb END) AS field
    WHERE field.key IN (
        'id', 'type', 'event_timestamp_ms', 'environment', 'store',
        'app_user_id', 'original_app_user_id', 'transferred_from', 'transferred_to',
        'product_id', 'entitlement_ids', 'period_type', 'purchased_at_ms', 'expiration_at_ms',
        'transaction_id', 'original_transaction_id',
        'price', 'currency', 'price_in_purchased_currency',
        'cancel_reason', 'expiration_reason'
    )
));

-- reward_events는 원본 쿼리(raw_query) 대신 서명된 콜백 시각(callback_at)과 출처(source)만 둡니다.
-- 거래 id, 계정, 광고 단위, 보상 항목은 이미 열로 있습니다. source test는 staging 테스트 보상입니다(S131).
ALTER TABLE reward_events
    ADD COLUMN callback_at timestamptz,
    ADD COLUMN source text;

-- SSV timestamp는 epoch 밀리초입니다. 읽지 못하는 행은 받은 시각으로 채웁니다.
UPDATE reward_events
SET callback_at = coalesce(
        to_timestamp(substring(raw_query FROM '(?:^|&)timestamp=([0-9]{1,15})(?:&|$)')::bigint / 1000.0),
        received_at),
    source = CASE WHEN raw_query ~ '(?:^|&)test_reward=1(?:&|$)' THEN 'test' ELSE 'ssv' END;

ALTER TABLE reward_events
    ALTER COLUMN callback_at SET NOT NULL,
    ALTER COLUMN source SET NOT NULL,
    ADD CONSTRAINT reward_events_source_check CHECK (source IN ('ssv', 'test')),
    DROP COLUMN raw_query;

-- +goose Down
-- 지운 원문은 되살릴 수 없습니다. 열 모양만 되돌리고 raw_query는 빈 문자열로 둡니다.
ALTER TABLE reward_events
    ADD COLUMN raw_query text NOT NULL DEFAULT '',
    DROP COLUMN callback_at,
    DROP COLUMN source;
ALTER TABLE reward_events ALTER COLUMN raw_query DROP DEFAULT;
