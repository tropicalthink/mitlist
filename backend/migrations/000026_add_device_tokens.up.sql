CREATE TABLE device_tokens (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform    TEXT        NOT NULL CHECK (platform IN ('android', 'ios')),
    token       TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, token)
);

CREATE INDEX device_tokens_user_id_idx ON device_tokens (user_id);
