-- Long-lived integration credentials are scoped to explicit households and
-- API domains. Only a SHA-256 digest is persisted; the raw secret is shown
-- once at creation time.
CREATE TABLE integration_credentials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    token_prefix TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    group_ids UUID[] NOT NULL DEFAULT '{}',
    scopes TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    last_used_ip TEXT,
    last_user_agent TEXT
);
CREATE INDEX idx_integration_credentials_user ON integration_credentials(user_id, created_at DESC);
CREATE INDEX idx_integration_credentials_active ON integration_credentials(token_hash) WHERE revoked_at IS NULL;
