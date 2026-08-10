ALTER TABLE users
    ADD COLUMN auth_valid_after TIMESTAMPTZ NOT NULL DEFAULT '1970-01-01 00:00:00+00';

CREATE TABLE auth_access_revocations (
    jti TEXT PRIMARY KEY,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auth_access_revocations_expiry
    ON auth_access_revocations (expires_at);
