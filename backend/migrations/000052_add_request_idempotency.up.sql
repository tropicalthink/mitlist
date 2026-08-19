CREATE TABLE request_idempotency (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'processing' CHECK (state IN ('processing', 'completed')),
    response_status INTEGER,
    response_content_type TEXT,
    response_body BYTEA,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
    PRIMARY KEY (user_id, idempotency_key),
    CHECK (char_length(idempotency_key) BETWEEN 1 AND 128)
);

CREATE INDEX idx_request_idempotency_expires_at
    ON request_idempotency(expires_at);
