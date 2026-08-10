ALTER TABLE oauth_accounts
    ADD COLUMN access_token TEXT,
    ADD COLUMN refresh_token TEXT,
    ADD COLUMN expires_at TIMESTAMPTZ;
