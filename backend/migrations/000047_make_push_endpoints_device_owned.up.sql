-- A browser push endpoint or FCM token identifies one physical client. If a
-- shared device changes accounts, ownership must move to the new account rather
-- than leaving the same delivery capability attached to both users.
WITH ranked AS (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY endpoint ORDER BY created_at DESC, id DESC) AS rn
    FROM push_subscriptions
)
DELETE FROM push_subscriptions
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

ALTER TABLE push_subscriptions
    DROP CONSTRAINT IF EXISTS push_subscriptions_user_id_endpoint_key;
ALTER TABLE push_subscriptions
    ADD CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint);

WITH ranked AS (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY token ORDER BY created_at DESC, id DESC) AS rn
    FROM device_tokens
)
DELETE FROM device_tokens
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

ALTER TABLE device_tokens
    DROP CONSTRAINT IF EXISTS device_tokens_user_id_token_key;
ALTER TABLE device_tokens
    ADD CONSTRAINT device_tokens_token_key UNIQUE (token);
