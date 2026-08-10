UPDATE oauth_accounts SET access_token = NULL, refresh_token = NULL;

ALTER TABLE oauth_accounts
    DROP COLUMN access_token,
    DROP COLUMN refresh_token,
    DROP COLUMN expires_at;
