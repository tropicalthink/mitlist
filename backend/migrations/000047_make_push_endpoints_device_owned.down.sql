ALTER TABLE device_tokens
    DROP CONSTRAINT IF EXISTS device_tokens_token_key;
ALTER TABLE device_tokens
    ADD CONSTRAINT device_tokens_user_id_token_key UNIQUE (user_id, token);

ALTER TABLE push_subscriptions
    DROP CONSTRAINT IF EXISTS push_subscriptions_endpoint_key;
ALTER TABLE push_subscriptions
    ADD CONSTRAINT push_subscriptions_user_id_endpoint_key UNIQUE (user_id, endpoint);
